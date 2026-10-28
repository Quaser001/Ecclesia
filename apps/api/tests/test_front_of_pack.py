"""Front-of-pack scans end to end: identify, confirm or choose, remember servings.

The Amul Lassi case from real use (28 Oct 2026): a front photo of a ₹20 pack.
Gemini reads brand, name and size; the products come from a fake Open Food
Facts holding the real search results for "amul lassi".
"""

from __future__ import annotations

import io
import json
from datetime import datetime, timezone

import pytest
from httpx import ASGITransport, AsyncClient

from src.config.dependencies import (
    get_food_lookup,
    get_gemini_provider,
    get_storage_provider,
    get_supabase_provider,
)
from src.domain.models import NutritionInfo, ProductObservation, UserProfile
from src.main import app
from src.providers.food_lookup import FoodLookupProvider, LookupUnavailable
from src.providers.interfaces import GeminiProvider
from src.providers.local_db_provider import LocalDBProvider, LocalStorageProvider
from src.repositories.off_mapping import map_off_product
from src.repositories.product_repository import FoodProduct
from src.services.alternative_service import AlternativeService
from tests.test_identification import HITS

JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xd9"
AMUL_200 = "8901262200189"


def _front(**kw) -> ProductObservation:
    base = dict(brand="Amul", product_name="Lassi", net_quantity="200 ml", mrp="Rs 20",
                identity_confidence=0.92, extraction_confidence=0.0)
    base.update(kw)
    return ProductObservation(**base)


class _Gemini(GeminiProvider):
    def __init__(self, reading: ProductObservation) -> None:
        self.reading = reading
        self.photo_calls = 0

    async def analyze_photo(self, photo_bytes, mime_type="image/jpeg"):
        self.photo_calls += 1
        return self.reading

    async def analyze_prescription(self, photo_bytes, mime_type="image/jpeg"):
        raise NotImplementedError

    async def generate_explanation(self, messages):
        return "Lassi has added sugar."


class _Lookup(FoodLookupProvider):
    def __init__(self, down: bool = False) -> None:
        self.down = down
        self.searches: list[str] = []
        self.products = {p.code: p for p in
                         (map_off_product(h, "2026-10-28", for_lookup=True) for h in HITS)}

    async def search(self, query, limit=8):
        self.searches.append(query)
        if self.down:
            raise LookupUnavailable("down")
        return list(self.products.values())

    async def get(self, code):
        if self.down:
            raise LookupUnavailable("down")
        return self.products.get(code)


@pytest.fixture
def env(tmp_path):
    db = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    state = {"gemini": _Gemini(_front()), "lookup": _Lookup()}
    app.dependency_overrides[get_supabase_provider] = lambda: db
    app.dependency_overrides[get_storage_provider] = lambda: LocalStorageProvider(str(tmp_path / "up"))
    app.dependency_overrides[get_gemini_provider] = lambda: state["gemini"]
    app.dependency_overrides[get_food_lookup] = lambda: state["lookup"]
    yield db, state
    app.dependency_overrides.clear()


def _client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def _profile(c, h, user_id, **kw):
    body = {"user_id": user_id, "health_conditions": ["diabetes_type_1"], "allergies": ["peanut"]}
    body.update(kw)
    assert (await c.put("/api/v1/profile", headers=h, json=body)).status_code == 200


def _photo():
    return {"photo": ("lassi.jpg", io.BytesIO(JPEG), "image/jpeg")}


async def test_a_clear_front_photo_is_identified_scored_and_saved(env, make_device):
    db, state = env
    user_id, h = make_device()
    async with _client() as c:
        await _profile(c, h, user_id)
        r = (await c.post("/api/v1/scans", headers=h, files=_photo())).json()
        history = (await c.get("/api/v1/scans/history", headers=h)).json()

    assert r["insufficient_data"] is False
    assert r["identification"]["status"] == "confident"
    assert r["identification"]["chosen"]["code"] == AMUL_200
    assert r["product"]["data_source"] == "open_food_facts"
    assert r["product"]["source_code"] == AMUL_200
    assert r["product"]["nutrition"]["sugars_g"] == 14.5  # from Open Food Facts, per 100 ml
    sugar = next(lv for lv in r["nutrient_levels"] if lv["nutrient"] == "sugars")
    assert sugar["basis"] == "100ml" and sugar["level"] == "high"
    # No ingredient list in the record: a peanut-allergic user is told so.
    assert "RULE-001C-ALLERGY-UNVERIFIED" in {f["rule_id"] for f in r["score_result"]["findings"]}
    assert r["score_result"]["suitability"] != "excellent"
    assert state["lookup"].searches == ["Amul Lassi"]  # one search, no size words
    assert [x["scan_id"] for x in history] == [r["scan_id"]]


async def test_several_matches_ask_the_user_and_nothing_is_saved(env, make_device):
    db, state = env
    state["gemini"].reading = _front(net_quantity=None)
    user_id, h = make_device()
    async with _client() as c:
        await _profile(c, h, user_id)
        r = (await c.post("/api/v1/scans", headers=h, files=_photo())).json()
        history = (await c.get("/api/v1/scans/history", headers=h)).json()

        assert r["insufficient_data"] is True
        assert r["identification"]["status"] == "choose"
        codes = [o["code"] for o in r["identification"]["options"]]
        assert len(codes) == 3 and AMUL_200 in codes
        assert all(o["brand"] == "Amul" for o in r["identification"]["options"])
        assert history == []

        # The user picks one: it is fetched again by code and scored.
        picked = await c.post("/api/v1/scans/confirm", headers=h, files=_photo(),
                              data={"product_code": AMUL_200, "source": "open_food_facts"})
        after = (await c.get("/api/v1/scans/history", headers=h)).json()

    assert picked.status_code == 200
    body = picked.json()
    assert body["insufficient_data"] is False
    assert body["identification"]["chosen"]["code"] == AMUL_200
    assert body["product"]["nutrition"]["sugars_g"] == 14.5
    assert state["gemini"].photo_calls == 1  # confirming doesn't re-read the photo
    assert [x["scan_id"] for x in after] == [body["scan_id"]]


async def test_a_doubtful_name_asks_for_a_retake(env, make_device):
    _, state = env
    state["gemini"].reading = _front(identity_confidence=0.2)
    _, h = make_device()
    async with _client() as c:
        r = (await c.post("/api/v1/scans", headers=h, files=_photo())).json()
    assert r["identification"]["status"] == "retake"
    assert "Retake" in r["pipeline_message"]
    assert state["lookup"].searches == []


async def test_an_offline_lookup_says_so(env, make_device):
    _, state = env
    state["lookup"].down = True
    _, h = make_device()
    async with _client() as c:
        r = (await c.post("/api/v1/scans", headers=h, files=_photo())).json()
        confirm = await c.post("/api/v1/scans/confirm", headers=h, files=_photo(),
                               data={"product_code": AMUL_200, "source": "open_food_facts"})
    assert r["identification"]["status"] == "unavailable"
    assert "couldn't reach" in r["pipeline_message"]
    assert confirm.status_code == 503


async def test_confirm_refuses_unknown_products_and_bad_sources(env, make_device):
    _, h = make_device()
    async with _client() as c:
        unknown = await c.post("/api/v1/scans/confirm", headers=h, files=_photo(),
                               data={"product_code": "123", "source": "open_food_facts"})
        bad = await c.post("/api/v1/scans/confirm", headers=h, files=_photo(),
                           data={"product_code": AMUL_200, "source": "made_up"})
    assert unknown.status_code == 404
    assert bad.status_code == 422


# --- serving size: note, answer, remembered next time --------------------------


async def _old_unknown_basis_scan(db, user_id, scan_id="old"):
    await db.ensure_profile_exists(user_id)
    await db.save_scan({
        "scan_id": scan_id, "user_id": user_id,
        "scanned_at": datetime.now(timezone.utc).isoformat(),
        "product_name": "Sting Energy Drink", "brand": "Sting", "category": "energy drink",
        "score": 75, "suitability": "good", "image_url": None,
        "product_json": ProductObservation(
            brand="Sting", product_name="Sting Energy Drink", category="energy drink",
            nutrition=NutritionInfo(sugars_g=6.8, calories_kcal=28),
            extraction_confidence=0.8).model_dump_json(),
        "score_json": json.dumps({"score": 75, "suitability": "good", "risk_level": "low",
                                  "findings": [], "rules_applied": []}),
        "explanation": "",
    })


async def test_serving_size_is_remembered_and_old_scores_never_change(env, make_device):
    db, state = env
    user_id, h = make_device()
    await _old_unknown_basis_scan(db, user_id)
    async with _client() as c:
        await _profile(c, h, user_id, allergies=[])
        old = (await c.get("/api/v1/scans/old", headers=h)).json()
        assert old["serving_size_unknown"] is True

        saved = await c.put("/api/v1/scans/old/serving", headers=h,
                            json={"serving_size_g": 250, "label_basis": "per_100"})
        assert saved.status_code == 204
        assert (await c.get("/api/v1/scans/old", headers=h)).json()["score_result"]["score"] == 75

        # Next scan of the same product, again without a serving size on the label.
        state["gemini"].reading = ProductObservation(
            brand="Sting", product_name="STING Energy Drink 250ml", category="energy drink",
            ingredients=["water", "sugar", "caffeine"],
            nutrition=NutritionInfo(sugars_g=6.8, calories_kcal=28), extraction_confidence=0.9)
        new = (await c.post("/api/v1/scans", headers=h, files=_photo())).json()

    n = new["product"]["nutrition"]
    assert n["serving_size_g"] == 250 and n["serving_size_source"] == "you"
    assert n["sugars_g"] == 17.0  # 6.8 per 100 ml x 250 ml
    assert new["serving_size_unknown"] is False
    assert new["score_result"]["score"] < 75


@pytest.mark.parametrize("body", [
    {"serving_size_g": 0, "label_basis": "per_100"},
    {"serving_size_g": 99999, "label_basis": "per_100"},
    {"serving_size_g": 200, "label_basis": "per_pack"},
])
async def test_impossible_serving_answers_are_rejected(env, make_device, body):
    db, _ = env
    user_id, h = make_device()
    await _old_unknown_basis_scan(db, user_id)
    async with _client() as c:
        r = await c.put("/api/v1/scans/old/serving", headers=h, json=body)
    assert r.status_code == 422


async def test_serving_memory_is_private_and_deleted_with_my_data(env, make_device):
    db, _ = env
    owner, _ = make_device()
    other, other_h = make_device()
    await _old_unknown_basis_scan(db, owner)
    async with _client() as c:
        r = await c.put("/api/v1/scans/old/serving", headers=other_h,
                        json={"serving_size_g": 250, "label_basis": "per_100"})
    assert r.status_code == 404
    await db.save_serving_memory(owner, "drink energy sting", 250, "per_100")
    await db.delete_user_data(owner)
    assert await db.get_serving_memory(owner, "drink energy sting") is None


# --- deleting one scan --------------------------------------------------------


async def test_delete_one_scan(env, make_device):
    db, _ = env
    owner, h = make_device()
    _, other_h = make_device()
    await _old_unknown_basis_scan(db, owner)
    async with _client() as c:
        assert (await c.delete("/api/v1/scans/old", headers=other_h)).status_code == 404
        assert (await c.delete("/api/v1/scans/old", headers=h)).status_code == 204
        assert (await c.get("/api/v1/scans/old", headers=h)).status_code == 404
        assert (await c.delete("/api/v1/scans/old", headers=h)).status_code == 404


# --- alternatives: a drink is replaced by a drink -----------------------------


def test_lassi_alternatives_are_drinks_never_ice_cream():
    # Both candidates pass every other filter (low sugar, no sugar in the
    # ingredients), so only the drink check can keep the ice cream out.
    def product(code, name, cats, sugars):
        return FoodProduct(code=code, product_name=name, brand="Amul", categories=cats,
                           ingredients=["milk", "salt", "cumin"],
                           nutrition=NutritionInfo(sugars_g=sugars, calories_kcal=80,
                                                   total_fat_g=2, sodium_mg=40),
                           calfit_category="flavoured_milk_ice_cream")

    class _Repo:
        def find_by_calfit_category(self, category, limit=300):
            return [product("1", "Vanilla ice cream", ["ice creams"], 2.0),
                    product("2", "Masti Spiced Buttermilk", ["buttermilks"], 1.0)]

    lassi = ProductObservation(brand="Amul", product_name="Lassi", category="lassi",
                               ingredients=["milk", "sugar"],
                               nutrition=NutritionInfo(serving_size_g=100, sugars_g=14.5,
                                                       calories_kcal=88, total_fat_g=2.1,
                                                       sodium_mg=30))
    profile = UserProfile(user_id="u", health_conditions=["diabetes_type_1"])
    from src.domain.scoring_rules import calculate_score
    alts = AlternativeService().find(lassi, profile, calculate_score(lassi, profile),
                                     product_repo=_Repo())
    names = [a.name for a in alts if a.type == "product"]
    assert "Vanilla ice cream" not in names
    assert names == ["Masti Spiced Buttermilk"]
