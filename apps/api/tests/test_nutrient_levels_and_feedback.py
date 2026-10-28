"""Traffic-light nutrient levels and "was this right?" feedback on scans."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

import pytest
from httpx import ASGITransport, AsyncClient

from src.config.dependencies import get_supabase_provider
from src.domain.models import NutritionInfo, ProductObservation, ScanResponse, ScoreResult
from src.domain.nutrient_levels import Level, is_drink, nutrient_levels
from src.main import app
from src.providers.local_db_provider import LocalDBProvider


def _levels(**kw):
    base = dict(serving_size_g=100, fat_g=None, saturated_fat_g=None, sugars_g=None,
                sodium_mg=None, category=None, name=None)
    base.update(kw)
    return {lv.nutrient: lv for lv in nutrient_levels(**base)}


# --- levels -------------------------------------------------------------------


@pytest.mark.parametrize("sugars,expected", [
    (5.0, Level.LOW),      # at the low limit is still low
    (5.1, Level.MEDIUM),
    (22.5, Level.MEDIUM),  # at the high limit is still medium
    (22.6, Level.HIGH),
])
def test_food_sugar_thresholds(sugars, expected):
    assert _levels(sugars_g=sugars, name="Parle-G biscuits")["sugars"].level is expected


def test_drinks_use_the_stricter_per_100ml_table():
    # 11 g sugar per 100 ml is medium for a drink; the same per 100 g is medium
    # for food too, but 12 g is high for a drink and only medium for food.
    drink = _levels(sugars_g=12, name="Thums Up cola")["sugars"]
    food = _levels(sugars_g=12, name="Marie biscuit")["sugars"]
    assert (drink.level, drink.basis) == (Level.HIGH, "100ml")
    assert (food.level, food.basis) == (Level.MEDIUM, "100g")


def test_values_are_rescaled_from_the_serving_to_per_100():
    # A 250 ml can with 27.5 g sugar is 11 g per 100 ml.
    lv = _levels(serving_size_g=250, sugars_g=27.5, name="Sting energy drink")["sugars"]
    assert lv.per_100 == 11.0 and lv.level is Level.MEDIUM


def test_salt_comes_from_sodium():
    # 600 mg sodium per 100 g = 1.5 g salt: the top of "medium" for food.
    lv = _levels(sodium_mg=600, name="Aloo bhujia namkeen")["salt"]
    assert lv.per_100 == 1.5 and lv.level is Level.MEDIUM
    assert _levels(sodium_mg=620, name="Aloo bhujia namkeen")["salt"].level is Level.HIGH


def test_unknown_serving_size_shows_nothing_rather_than_guessing():
    assert nutrient_levels(serving_size_g=None, fat_g=30, saturated_fat_g=10, sugars_g=40,
                           sodium_mg=900, category=None, name="Chips") == []


def test_missing_nutrients_are_left_out():
    assert set(_levels(fat_g=10, name="Chips")) == {"fat"}


@pytest.mark.parametrize("name,drink", [
    ("Amul Kool flavoured milk", True),
    ("Kwality Walls ice cream", False),
    ("Real fruit juice", True),
    ("Maggi noodles", False),
])
def test_is_drink(name, drink):
    assert is_drink(None, name) is drink


def test_scan_response_carries_the_levels():
    resp = ScanResponse(
        user_id="u",
        product=ProductObservation(
            product_name="Lays Classic Salted chips",
            nutrition=NutritionInfo(serving_size_g=30, total_fat_g=10.5, sugars_g=0.3),
        ),
        score_result=ScoreResult(score=50, suitability="fair", risk_level="moderate"),
        explanation="",
    )
    out = {lv["nutrient"]: lv for lv in resp.model_dump(mode="json")["nutrient_levels"]}
    assert out["fat"] == {"nutrient": "fat", "per_100": 35.0, "unit": "g",
                          "basis": "100g", "level": "high"}
    assert out["sugars"]["level"] == "low"


# --- feedback -----------------------------------------------------------------


@pytest.fixture
def db(tmp_path):
    provider = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    app.dependency_overrides[get_supabase_provider] = lambda: provider
    yield provider
    app.dependency_overrides.clear()


async def _scan(db, user_id, scan_id):
    await db.ensure_profile_exists(user_id)
    await db.save_scan({
        "scan_id": scan_id, "user_id": user_id,
        "scanned_at": datetime.now(timezone.utc).isoformat(),
        "product_name": "P", "brand": "B", "category": "c", "score": 40,
        "suitability": "fair", "image_url": None, "product_json": "{}",
        "score_json": json.dumps({"score": 40, "suitability": "fair", "risk_level": "low",
                                  "findings": [], "rules_applied": []}),
        "explanation": "",
    })


def _client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def test_feedback_is_saved_and_the_latest_answer_wins(db, make_device):
    me, h = make_device()
    await _scan(db, me, "s1")
    async with _client() as c:
        r1 = await c.post("/api/v1/scans/s1/feedback", headers=h,
                          json={"accurate": False, "issues": ["wrong_nutrition", "wrong_nutrition"]})
        assert r1.status_code == 204
        assert (await db.get_feedback_summary())["issues"]["wrong_nutrition"] == 1
        r2 = await c.post("/api/v1/scans/s1/feedback", headers=h,
                          json={"accurate": True, "issues": ["score_unfair"]})
        assert r2.status_code == 204
    summary = await db.get_feedback_summary()
    # One answer per scan; a "yes" drops the issues it was sent with.
    assert summary["total"] == 1 and summary["accurate"] == 1
    assert sum(summary["issues"].values()) == 0
    assert summary["accuracy_rate"] == 1.0


async def test_feedback_on_someone_elses_scan_is_a_404(db, make_device):
    owner, _ = make_device()
    _, other_headers = make_device()
    await _scan(db, owner, "theirs")
    async with _client() as c:
        r = await c.post("/api/v1/scans/theirs/feedback", headers=other_headers,
                         json={"accurate": False, "issues": ["wrong_product"]})
    assert r.status_code == 404
    assert (await db.get_feedback_summary())["total"] == 0


async def test_unknown_issues_are_rejected(db, make_device):
    me, h = make_device()
    await _scan(db, me, "s1")
    async with _client() as c:
        r = await c.post("/api/v1/scans/s1/feedback", headers=h,
                         json={"accurate": False, "issues": ["my blood sugar is 300"]})
    assert r.status_code == 422


async def test_feedback_needs_a_device_token(db):
    async with _client() as c:
        r = await c.post("/api/v1/scans/s1/feedback", json={"accurate": True})
    assert r.status_code == 401


async def test_deleting_my_data_removes_my_feedback(db, make_device):
    me, h = make_device()
    await _scan(db, me, "s1")
    await db.save_scan_feedback(me, "s1", False, ["missed_allergen"])
    await db.delete_user_data(me)
    assert (await db.get_feedback_summary())["total"] == 0


async def test_summary_since_ignores_older_answers(db, make_device):
    me, _ = make_device()
    await _scan(db, me, "s1")
    await db.save_scan_feedback(me, "s1", True, [])
    later = datetime.now(timezone.utc) + timedelta(minutes=1)
    assert (await db.get_feedback_summary(since=later))["total"] == 0
    assert (await db.get_feedback_summary())["accuracy_rate"] == 1.0
