"""Endpoint-level authentication and per-device data isolation."""

from __future__ import annotations

import io

import pytest
from httpx import ASGITransport, AsyncClient

from src.config.dependencies import get_gemini_provider, get_token_issue_limiter
from src.main import app
from src.services.rate_limit import InMemoryStore, ScanLimiter


@pytest.fixture
async def client():
    # A stand-in AI: routes that take a photo resolve the Gemini provider
    # before their own checks run, and tests have no real key (CI has no .env).
    app.dependency_overrides[get_gemini_provider] = lambda: object()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.pop(get_gemini_provider, None)


@pytest.fixture(autouse=True)
def _fresh_issue_limiter():
    limiter = ScanLimiter(cap=1000, store=InMemoryStore())
    app.dependency_overrides[get_token_issue_limiter] = lambda: limiter
    yield
    app.dependency_overrides.clear()


PROTECTED = [
    ("GET", "/api/v1/profile"),
    ("PUT", "/api/v1/profile"),
    ("GET", "/api/v1/scans/history"),
    ("POST", "/api/v1/scans"),
]


@pytest.mark.parametrize("method,path", PROTECTED)
async def test_protected_routes_reject_missing_token(client, auth_secret, method, path):
    r = await client.request(method, path)
    assert r.status_code == 401
    assert r.headers["www-authenticate"] == "Bearer"


@pytest.mark.parametrize("method,path", PROTECTED)
async def test_protected_routes_reject_forged_token(client, auth_secret, method, path):
    forged = {"Authorization": "Bearer v1." + "a" * 32 + "." + "0" * 64}
    r = await client.request(method, path, headers=forged)
    assert r.status_code == 401


async def test_non_bearer_scheme_is_rejected(client, auth_secret):
    r = await client.get("/api/v1/profile", headers={"Authorization": "Basic abc"})
    assert r.status_code == 401


async def test_register_device_returns_a_working_token(client, auth_secret):
    r = await client.post("/api/v1/auth/device")
    assert r.status_code == 200
    body = r.json()
    me = await client.get(
        "/api/v1/profile", headers={"Authorization": f"Bearer {body['token']}"}
    )
    assert me.status_code == 200
    assert me.json()["user_id"] == body["user_id"]


async def test_client_supplied_user_id_is_ignored(client, make_device):
    """Passing someone else's id in the query must not select their data."""
    victim_id, victim_headers = make_device()
    _, attacker_headers = make_device()

    await client.put(
        "/api/v1/profile",
        json={"name": "Victim", "allergies": ["peanut"]},
        headers=victim_headers,
    )

    r = await client.get(f"/api/v1/profile?user_id={victim_id}", headers=attacker_headers)
    assert r.status_code == 200
    assert r.json()["name"] != "Victim"
    assert r.json()["user_id"] != victim_id


async def test_devices_cannot_see_each_others_profile(client, make_device):
    _, a = make_device()
    _, b = make_device()
    await client.put("/api/v1/profile", json={"name": "Alice"}, headers=a)
    r = await client.get("/api/v1/profile", headers=b)
    assert r.json()["name"] is None


async def test_unconfigured_secret_fails_loudly_not_open(client, monkeypatch):
    from src.config.settings import settings

    monkeypatch.setattr(settings, "AUTH_SECRET_KEY", "")
    reg = await client.post("/api/v1/auth/device")
    assert reg.status_code == 503
    prot = await client.get("/api/v1/profile", headers={"Authorization": "Bearer v1.x.y"})
    assert prot.status_code in (401, 503)
    assert prot.status_code != 200


async def test_device_registration_is_capped_per_ip(client, auth_secret):
    limiter = ScanLimiter(cap=2, store=InMemoryStore())
    app.dependency_overrides[get_token_issue_limiter] = lambda: limiter
    assert (await client.post("/api/v1/auth/device")).status_code == 200
    assert (await client.post("/api/v1/auth/device")).status_code == 200
    assert (await client.post("/api/v1/auth/device")).status_code == 429


async def test_scan_upload_validation_still_runs_after_auth(client, make_device):
    _, headers = make_device()
    files = {"photo": ("x.txt", io.BytesIO(b"hello"), "text/plain")}
    r = await client.post("/api/v1/scans", files=files, headers=headers)
    assert r.status_code == 422
