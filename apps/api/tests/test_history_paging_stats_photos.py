"""History paging, whole-history stats, and short-lived signed photo links."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

import pytest
from httpx import ASGITransport, AsyncClient

from src.api.v1.scans import photo_path
from src.config.dependencies import get_storage_provider, get_supabase_provider
from src.main import app
from src.providers.interfaces import StorageProvider
from src.providers.local_db_provider import LocalDBProvider

T0 = datetime(2026, 10, 1, 9, 0, tzinfo=timezone.utc)
BUCKET_URL = "https://x.supabase.co/storage/v1/object/public/calfit-scans/"


class _SigningStorage(StorageProvider):
    """Signs any path it is given; records what was asked."""

    def __init__(self):
        self.asked: list[str] = []

    async def upload_image(self, bucket, path, data, content_type):
        return BUCKET_URL + path

    async def delete_object(self, bucket, path):
        return None

    async def delete_folder(self, bucket, prefix):
        return 0

    async def signed_urls(self, bucket, paths, expires_in):
        self.asked.extend(paths)
        return {p: f"https://signed.example/{p}?token=abc&ttl={expires_in}" for p in paths}


@pytest.fixture
def env(tmp_path):
    db = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    storage = _SigningStorage()
    app.dependency_overrides[get_supabase_provider] = lambda: db
    app.dependency_overrides[get_storage_provider] = lambda: storage
    yield db, storage
    app.dependency_overrides.clear()


async def _scans(db, user_id, n, score=lambda i: 10 * i % 101):
    await db.ensure_profile_exists(user_id)
    for i in range(n):
        await db.save_scan({
            "scan_id": f"{user_id}-{i}", "user_id": user_id,
            "scanned_at": (T0 + timedelta(hours=i)).isoformat(),
            "product_name": f"P{i}", "brand": "B", "category": "c",
            "score": score(i), "suitability": "fair",
            "image_url": BUCKET_URL + f"scans/{user_id}/{user_id}-{i}.jpg",
            "product_json": "{}",
            "score_json": json.dumps({"score": score(i), "suitability": "fair",
                                      "risk_level": "low", "findings": [], "rules_applied": []}),
            "explanation": "",
        })


def _client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def test_history_pages_with_a_before_cursor(env, make_device):
    db, _ = env
    me, h = make_device()
    await _scans(db, me, 25)
    async with _client() as c:
        first = (await c.get("/api/v1/scans/history?limit=20", headers=h)).json()
        cursor = first[-1]["scanned_at"]
        rest = (await c.get("/api/v1/scans/history", params={"limit": 20, "before": cursor},
                            headers=h)).json()
    assert len(first) == 20 and len(rest) == 5
    ids = [r["scan_id"] for r in first + rest]
    assert len(set(ids)) == 25  # no duplicates, nothing skipped
    assert ids[0] == f"{me}-24" and ids[-1] == f"{me}-0"  # newest first


async def test_stats_cover_the_whole_history(env, make_device):
    db, _ = env
    me, h = make_device()
    other, _ = make_device()
    await _scans(db, me, 31, score=lambda i: i)  # scores 0..30
    await _scans(db, other, 3, score=lambda i: 99)
    async with _client() as c:
        stats = (await c.get("/api/v1/scans/stats", headers=h)).json()
    assert stats == {"total": 31, "average": 15, "best": 30}


async def test_stats_for_a_new_user(env, make_device):
    _, h = make_device()
    async with _client() as c:
        stats = (await c.get("/api/v1/scans/stats", headers=h)).json()
    assert stats == {"total": 0, "average": None, "best": None}


async def test_history_photos_are_short_lived_signed_links(env, make_device):
    db, storage = env
    me, h = make_device()
    await _scans(db, me, 2)
    async with _client() as c:
        rows = (await c.get("/api/v1/scans/history", headers=h)).json()
    assert all(r["image_url"].startswith("https://signed.example/scans/") for r in rows)
    assert all("ttl=3600" in r["image_url"] for r in rows)
    assert sorted(storage.asked) == sorted(f"scans/{me}/{me}-{i}.jpg" for i in range(2))


async def test_scan_detail_photo_is_signed_too(env, make_device):
    db, _ = env
    me, h = make_device()
    await _scans(db, me, 1)
    async with _client() as c:
        body = (await c.get(f"/api/v1/scans/{me}-0", headers=h)).json()
    assert body["image_url"].startswith("https://signed.example/scans/")


@pytest.mark.parametrize(
    "url, expected",
    [
        (BUCKET_URL + "scans/me/a.jpg", "scans/me/a.jpg"),
        (BUCKET_URL + "scans/me/a.jpg?x=1", "scans/me/a.jpg"),
        ("/uploads/calfit-scans/scans/me/a.jpg", "scans/me/a.jpg"),
        (BUCKET_URL + "scans/someone-else/a.jpg", None),  # never sign another user's photo
        (BUCKET_URL + "scans/me/../someone-else/a.jpg", None),
        (None, None),
        ("https://elsewhere.example/a.jpg", None),
    ],
)
def test_photo_path_only_returns_the_users_own_files(url, expected):
    assert photo_path(url, "me", "calfit-scans") == expected
