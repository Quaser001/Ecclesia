"""GET /scans/{id} and GET /insights: owner-only reads of stored scans."""

from __future__ import annotations

import json

import pytest
from httpx import ASGITransport, AsyncClient

from src.config.dependencies import get_supabase_provider
from src.main import app
from src.providers.local_db_provider import LocalDBProvider


@pytest.fixture
def db(tmp_path):
    provider = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    app.dependency_overrides[get_supabase_provider] = lambda: provider
    yield provider
    app.dependency_overrides.clear()


async def _store_scan(db, user_id, scan_id, score=42, suitability="fair"):
    await db.ensure_profile_exists(user_id)
    await db.save_scan({
        "scan_id": scan_id,
        "user_id": user_id,
        "scanned_at": "2026-10-27T09:00:00+00:00",
        "product_name": "Amul Lassi",
        "brand": "Amul",
        "category": "dairy drinks",
        "score": score,
        "suitability": suitability,
        "image_url": None,
        "product_json": json.dumps({"brand": "Amul", "product_name": "Amul Lassi",
                                    "extraction_confidence": 0.9}),
        "score_json": json.dumps({
            "score": score, "suitability": suitability, "risk_level": "moderate",
            "findings": [{"rule_id": "R-SUGAR", "severity": "alert",
                          "title": "Very high sugar", "detail": "14.5 g per serving"}],
            "rules_applied": ["R-SUGAR"],
        }),
        "explanation": "Evaluated with a health score of 42/100.",
    })


async def _client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def test_scan_detail_returns_the_full_stored_result(db, make_device):
    user_id, headers = make_device()
    await _store_scan(db, user_id, "s-1")

    async with await _client() as client:
        r = await client.get("/api/v1/scans/s-1", headers=headers)

    assert r.status_code == 200
    body = r.json()
    assert body["scan_id"] == "s-1"
    assert body["product"]["product_name"] == "Amul Lassi"
    assert body["score_result"]["score"] == 42
    assert body["score_result"]["findings"][0]["title"] == "Very high sugar"
    assert body["explanation"].startswith("Evaluated")


async def test_scan_detail_is_owner_only(db, make_device):
    owner, _ = make_device()
    _, other_headers = make_device()
    await _store_scan(db, owner, "s-1")

    async with await _client() as client:
        r = await client.get("/api/v1/scans/s-1", headers=other_headers)

    assert r.status_code == 404  # never reveal that someone else's scan exists


async def test_scan_detail_needs_a_token(db):
    async with await _client() as client:
        r = await client.get("/api/v1/scans/s-1")
    assert r.status_code == 401


async def test_history_route_is_not_shadowed_by_the_detail_route(db, make_device):
    user_id, headers = make_device()
    await _store_scan(db, user_id, "s-1")

    async with await _client() as client:
        r = await client.get("/api/v1/scans/history", headers=headers)

    assert r.status_code == 200
    assert [row["scan_id"] for row in r.json()] == ["s-1"]


async def test_insights_cover_only_the_callers_scans(db, make_device):
    me, headers = make_device()
    other, _ = make_device()
    await _store_scan(db, me, "mine", score=42, suitability="fair")
    await _store_scan(db, other, "theirs", score=95, suitability="excellent")

    async with await _client() as client:
        r = await client.get("/api/v1/insights", headers=headers)

    assert r.status_code == 200
    body = r.json()
    assert body["total_scans"] == 1
    assert body["average_score"] == 42
    assert body["top_flags"][0]["rule_id"] == "R-SUGAR"
    assert len(body["weekly"]) == 8


async def test_insights_need_a_token(db):
    async with await _client() as client:
        r = await client.get("/api/v1/insights")
    assert r.status_code == 401
