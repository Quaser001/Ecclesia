"""Delete my data: profile, scans, photos and usage go; nobody else's do."""

from __future__ import annotations

import json

import pytest
from httpx import ASGITransport, AsyncClient

from src.config.dependencies import get_storage_provider, get_supabase_provider
from src.domain.models import UserProfile
from src.main import app
from src.providers.local_db_provider import LocalDBProvider, LocalStorageProvider


@pytest.fixture
def stores(tmp_path):
    db = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    storage = LocalStorageProvider(base_dir=str(tmp_path / "uploads"))
    app.dependency_overrides[get_supabase_provider] = lambda: db
    app.dependency_overrides[get_storage_provider] = lambda: storage
    yield db, storage, tmp_path / "uploads"
    app.dependency_overrides.clear()


async def _scan(db, storage, user_id, scan_id):
    await db.ensure_profile_exists(user_id)
    url = await storage.upload_image("calfit-scans", f"scans/{user_id}/{scan_id}.jpg", b"img", "image/jpeg")
    await db.save_scan({
        "scan_id": scan_id, "user_id": user_id, "scanned_at": "2026-10-27T09:00:00+00:00",
        "product_name": "X", "brand": "Y", "category": "c", "score": 50, "suitability": "fair",
        "image_url": url, "product_json": "{}",
        "score_json": json.dumps({"score": 50, "suitability": "fair", "risk_level": "low",
                                  "findings": [], "rules_applied": []}),
        "explanation": "",
    })
    await db.increment_scan_usage(user_id)


async def test_delete_removes_everything_of_mine_and_nothing_of_theirs(stores, make_device):
    db, storage, uploads = stores
    me, headers = make_device()
    other, _ = make_device()
    await db.upsert_profile(UserProfile(user_id=me, name="Me", allergies=["peanut"]))
    await _scan(db, storage, me, "mine")
    await _scan(db, storage, other, "theirs")

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        r = await client.delete("/api/v1/profile", headers=headers)
        assert r.status_code == 200
        assert r.json()["scans_deleted"] == 1

        after = (await client.get("/api/v1/profile", headers=headers)).json()
        history = (await client.get("/api/v1/scans/history", headers=headers)).json()

    assert after["name"] is None and after["allergies"] == []
    assert history == []
    assert await db.get_scan(other, "theirs") is not None
    assert not (uploads / "calfit-scans" / "scans" / me / "mine.jpg").exists()
    assert (uploads / "calfit-scans" / "scans" / other / "theirs.jpg").exists()


async def test_delete_needs_a_token(stores):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        r = await client.delete("/api/v1/profile")
    assert r.status_code == 401
