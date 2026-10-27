"""POST /api/v1/profile/prescription-suggestions: behaviour and privacy guarantees."""

from __future__ import annotations

import io
import logging

import pytest
from httpx import ASGITransport, AsyncClient

from src.config.dependencies import (
    get_gemini_provider,
    get_prescription_limiter,
    get_storage_provider,
    get_supabase_provider,
)
from src.config.settings import settings
from src.domain.prescription import AllergyKind, PrescriptionObservation, StatedAllergy
from src.main import app
from src.providers.interfaces import GeminiProvider, StorageProvider
from src.providers.local_db_provider import LocalDBProvider
from src.services.rate_limit import InMemoryStore, ScanLimiter

URL = "/api/v1/profile/prescription-suggestions"
JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00"

SECRET_BITS = ["Metformin", "Type 2 diabetes", "Peanuts"]


class FakeGemini(GeminiProvider):
    def __init__(self, obs: PrescriptionObservation | None = None, error: Exception | None = None):
        self.obs = obs or PrescriptionObservation(
            diagnoses=["Type 2 diabetes"],
            medicines=["Metformin"],
            allergies=[StatedAllergy(name="Peanuts", kind=AllergyKind.FOOD)],
        )
        self.error = error
        self.calls = 0

    async def analyze_prescription(self, photo_bytes, mime_type="image/jpeg"):
        self.calls += 1
        if self.error:
            raise self.error
        return self.obs

    async def analyze_photo(self, photo_bytes, mime_type="image/jpeg"):
        raise AssertionError("scan path must not be used")

    async def generate_explanation(self, messages):
        raise AssertionError("explanations must not be used")


class SpyDB(LocalDBProvider):
    def __init__(self, path):
        super().__init__(db_path=path)
        self.writes: list[str] = []

    async def save_scan(self, scan_data):
        self.writes.append("save_scan")
        return await super().save_scan(scan_data)

    async def upsert_profile(self, profile):
        self.writes.append("upsert_profile")
        return await super().upsert_profile(profile)

    async def ensure_profile_exists(self, user_id):
        self.writes.append("ensure_profile_exists")
        return await super().ensure_profile_exists(user_id)


class SpyStorage(StorageProvider):
    def __init__(self):
        self.uploads = 0

    async def upload_image(self, bucket, path, data, content_type):
        self.uploads += 1
        return "x"

    async def delete_folder(self, bucket, prefix):
        return 0


@pytest.fixture
def enabled(monkeypatch):
    monkeypatch.setattr(settings, "PRESCRIPTION_AI_ENABLED", True)


@pytest.fixture
def env(tmp_path, auth_secret, enabled):
    db = SpyDB(str(tmp_path / "t.db"))
    storage = SpyStorage()
    gemini = FakeGemini()
    limiter = ScanLimiter(cap=100, store=InMemoryStore())
    app.dependency_overrides[get_supabase_provider] = lambda: db
    app.dependency_overrides[get_storage_provider] = lambda: storage
    app.dependency_overrides[get_gemini_provider] = lambda: gemini
    app.dependency_overrides[get_prescription_limiter] = lambda: limiter
    yield type("Env", (), {"db": db, "storage": storage, "gemini": gemini})
    app.dependency_overrides.clear()


@pytest.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


def _photo(data=JPEG, mime="image/jpeg"):
    return {"photo": ("rx.jpg", io.BytesIO(data), mime)}


async def test_disabled_by_default_returns_503(client, make_device, env, monkeypatch):
    monkeypatch.setattr(settings, "PRESCRIPTION_AI_ENABLED", False)
    _, h = make_device()
    r = await client.post(URL, files=_photo(), headers=h)
    assert r.status_code == 503
    assert "not enabled" in r.json()["detail"].lower()
    assert env.gemini.calls == 0


async def test_requires_auth(client, env):
    r = await client.post(URL, files=_photo())
    assert r.status_code == 401
    assert env.gemini.calls == 0


async def test_returns_suggestions_for_valid_photo(client, make_device, env):
    _, h = make_device()
    r = await client.post(URL, files=_photo(), headers=h)
    assert r.status_code == 200
    body = r.json()
    assert {c["condition"]: c["basis"] for c in body["conditions"]} == {
        "diabetes_type_2": "stated"
    }
    assert [a["name"] for a in body["allergies"]] == ["peanuts"]


async def test_rejects_non_image_and_oversized(client, make_device, env, monkeypatch):
    _, h = make_device()
    bad_type = await client.post(URL, files=_photo(b"hello", "text/plain"), headers=h)
    assert bad_type.status_code == 422

    monkeypatch.setattr(settings, "MAX_SCAN_UPLOAD_BYTES", 10)
    too_big = await client.post(URL, files=_photo(JPEG), headers=h)
    assert too_big.status_code == 413
    assert env.gemini.calls == 0


async def test_empty_upload_is_rejected(client, make_device, env):
    _, h = make_device()
    r = await client.post(URL, files=_photo(b""), headers=h)
    assert r.status_code == 422


async def test_daily_cap_returns_429_after_cap(client, make_device, env):
    limiter = ScanLimiter(cap=2, store=InMemoryStore())
    app.dependency_overrides[get_prescription_limiter] = lambda: limiter
    _, h = make_device()
    assert (await client.post(URL, files=_photo(), headers=h)).status_code == 200
    assert (await client.post(URL, files=_photo(), headers=h)).status_code == 200
    assert (await client.post(URL, files=_photo(), headers=h)).status_code == 429


async def test_already_on_profile_not_suggested(client, make_device, env):
    _, h = make_device()
    await client.put(
        URL.rsplit("/", 1)[0],
        json={"health_conditions": ["diabetes_type_2"], "allergies": ["peanuts"]},
        headers=h,
    )
    r = await client.post(URL, files=_photo(), headers=h)
    body = r.json()
    assert body["conditions"] == [] and body["allergies"] == []


async def test_not_a_prescription_photo_returns_insufficient(client, make_device, env):
    env.gemini.obs = PrescriptionObservation(is_prescription=False)
    _, h = make_device()
    r = await client.post(URL, files=_photo(), headers=h)
    assert r.status_code == 200
    assert r.json()["insufficient_data"] is True


async def test_nothing_is_stored(client, make_device, env):
    _, h = make_device()
    r = await client.post(URL, files=_photo(), headers=h)
    assert r.status_code == 200
    assert env.storage.uploads == 0
    assert env.db.writes == []
    history = await client.get("/api/v1/scans/history", headers=h)
    assert history.json() == []


async def test_no_health_content_in_logs(client, make_device, env, caplog):
    caplog.set_level(logging.DEBUG)
    _, h = make_device()
    r = await client.post(URL, files=_photo(), headers=h)
    assert r.status_code == 200
    for bit in SECRET_BITS:
        assert bit.lower() not in caplog.text.lower()


async def test_gemini_failure_is_a_502_not_fake_data(client, make_device, env, caplog):
    caplog.set_level(logging.DEBUG)
    env.gemini.error = RuntimeError("boom Metformin")
    _, h = make_device()
    r = await client.post(URL, files=_photo(), headers=h)
    assert r.status_code == 502
    body = r.json()
    assert "conditions" not in body
    assert "metformin" not in r.text.lower()
    assert "metformin" not in caplog.text.lower()
