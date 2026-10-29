"""Consent to the privacy notice is recorded, and health data waits for it
(DPDP Act s.6, s.6(10), s.9; Rules r.3)."""

from __future__ import annotations

import io

import pytest
from httpx import ASGITransport, AsyncClient

from src.config.dependencies import get_supabase_provider
from src.main import app
from src.providers.local_db_provider import LocalDBProvider
from src.services.consent import CONSENT_NOTICE_VERSION

JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00"
AGREE = {"notice_version": CONSENT_NOTICE_VERSION, "adult_confirmed": True}


@pytest.fixture
def db(tmp_path, no_consent_override):
    provider = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    app.dependency_overrides[get_supabase_provider] = lambda: provider
    yield provider
    app.dependency_overrides.pop(get_supabase_provider, None)


def _client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def test_health_data_waits_for_consent(db, make_device):
    user_id, h = make_device()
    async with _client() as c:
        assert (await c.put("/api/v1/profile", headers=h, json={"allergies": ["peanut"]})).status_code == 428
        scan = await c.post("/api/v1/scans", headers=h, files={"photo": ("p.jpg", io.BytesIO(JPEG), "image/jpeg")})
        assert scan.status_code == 428
        rx = await c.post("/api/v1/profile/prescription-suggestions", headers=h,
                          files={"photo": ("p.jpg", io.BytesIO(JPEG), "image/jpeg")})
        assert rx.status_code == 428
        confirm = await c.post("/api/v1/scans/confirm", headers=h,
                               data={"product_code": "123", "source": "calfit_database"},
                               files={"photo": ("p.jpg", io.BytesIO(JPEG), "image/jpeg")})
        assert confirm.status_code == 428
    assert await db.get_profile(user_id) is None  # nothing was stored


async def test_agreeing_is_recorded_and_unlocks_the_profile(db, make_device):
    user_id, h = make_device()
    async with _client() as c:
        before = await c.get("/api/v1/consent", headers=h)
        assert before.json() == {"current_version": CONSENT_NOTICE_VERSION, "agreed": False}

        r = await c.post("/api/v1/consent", headers=h, json=AGREE)
        assert r.status_code == 201 and r.json()["notice_version"] == CONSENT_NOTICE_VERSION

        assert (await c.get("/api/v1/consent", headers=h)).json()["agreed"] is True
        assert (await c.put("/api/v1/profile", headers=h, json={"allergies": ["peanut"]})).status_code == 200
    assert await db.has_consent(user_id, CONSENT_NOTICE_VERSION)


async def test_consent_is_per_person(db, make_device):
    _, me = make_device()
    _, father = make_device()  # a family profile is its own identity
    async with _client() as c:
        await c.post("/api/v1/consent", headers=me, json=AGREE)
        assert (await c.get("/api/v1/consent", headers=father)).json()["agreed"] is False
        assert (await c.put("/api/v1/profile", headers=father, json={})).status_code == 428


async def test_no_consent_without_the_18_plus_box(db, make_device):
    _, h = make_device()
    async with _client() as c:
        r = await c.post("/api/v1/consent", headers=h, json={**AGREE, "adult_confirmed": False})
        assert r.status_code == 422
        assert (await c.get("/api/v1/consent", headers=h)).json()["agreed"] is False


async def test_agreeing_to_an_old_notice_is_refused(db, make_device):
    _, h = make_device()
    async with _client() as c:
        r = await c.post("/api/v1/consent", headers=h, json={**AGREE, "notice_version": "2020-01-01"})
        assert r.status_code == 409
        assert (await c.get("/api/v1/consent", headers=h)).json()["agreed"] is False


async def test_delete_my_data_withdraws_consent_but_keeps_the_record(db, make_device):
    user_id, h = make_device()
    async with _client() as c:
        await c.post("/api/v1/consent", headers=h, json=AGREE)
        assert (await c.delete("/api/v1/profile", headers=h)).status_code == 200
        assert (await c.get("/api/v1/consent", headers=h)).json()["agreed"] is False
        assert (await c.put("/api/v1/profile", headers=h, json={})).status_code == 428
    with db._get_connection() as conn:
        row = conn.execute("SELECT withdrawn_at FROM consents WHERE user_id = ?", (user_id,)).fetchone()
    assert row is not None and row["withdrawn_at"]  # proof of the earlier consent


async def test_consent_needs_a_signed_in_user(db):
    async with _client() as c:
        assert (await c.get("/api/v1/consent")).status_code == 401
        assert (await c.post("/api/v1/consent", json=AGREE)).status_code == 401


async def test_a_failed_consent_lookup_is_an_error_not_a_yes(db, make_device):
    _, h = make_device()

    async def broken(*_a):
        raise ConnectionError("db down")
    db.has_consent = broken
    async with _client() as c:
        r = await c.put("/api/v1/profile", headers=h, json={"allergies": ["peanut"]})
    assert r.status_code >= 500
