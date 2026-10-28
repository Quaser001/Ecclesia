"""A scan with nothing to judge must say so, not score "excellent".

The rules only subtract points for problems they can see. A front-of-pack
photo with no nutrition panel, no ingredients and no database match gives them
nothing to see, so the product used to score 100. For a peanut-allergic user
that reads as "safe" when nothing was checked.
"""

from __future__ import annotations

from src.domain.models import (
    HealthCondition,
    NutritionInfo,
    ProductObservation,
    UserProfile,
)
from src.orchestration.scan_graph import ScanState, build_scan_graph
from src.providers.local_db_provider import LocalDBProvider
from src.repositories.product_repository import FoodProduct


class _Gemini:
    def __init__(self, product: ProductObservation) -> None:
        self._product = product

    async def analyze_photo(self, photo_bytes, mime_type="image/jpeg"):
        return self._product

    async def generate_explanation(self, messages):
        return "explanation"


class _Storage:
    async def upload_image(self, bucket, path, data, content_type):
        return f"https://example.test/{path}"


class _Repo:
    def __init__(self, match: FoodProduct | None) -> None:
        self._match = match

    def match_product(self, name, brand, category):
        return self._match

    def search_by_words(self, words, limit=200):
        return []

    def find_candidates_by_category(self, *args, **kwargs):
        return []


FRONT_ONLY = ProductObservation(
    product_name="KitKat Delights Dark",
    brand="Nestle",
    category="chocolate",
    extraction_confidence=0.8,
)


async def _run(tmp_path, product, profile, match=None) -> ScanState:
    db = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    await db.upsert_profile(profile)
    graph = build_scan_graph(_Gemini(product), db, _Storage(), "b", product_repo=_Repo(match))
    out = await graph.ainvoke(ScanState(user_id=profile.user_id, photo_bytes=b"img"))
    return ScanState(**out) if isinstance(out, dict) else out


async def test_front_label_only_with_no_match_is_insufficient(tmp_path):
    profile = UserProfile(user_id="u", health_conditions=[HealthCondition.DIABETES_TYPE_1])
    state = await _run(tmp_path, FRONT_ONLY, profile)

    assert state.insufficient_data is True
    assert state.score_result.suitability.value != "excellent"
    assert "back of the pack" in (state.pipeline_message or "")


async def test_peanut_allergy_never_gets_excellent_from_no_data(tmp_path):
    profile = UserProfile(user_id="u", allergies=["peanut"])
    state = await _run(tmp_path, FRONT_ONLY, profile)

    assert state.insufficient_data is True
    assert state.score_result.score == 0


async def test_a_front_of_pack_calorie_badge_alone_is_not_enough(tmp_path):
    """Many fronts print only "75 kcal per serving"; no sugar, sodium, fat or
    allergen rule can judge anything from that."""
    product = FRONT_ONLY.model_copy(
        update={"nutrition": NutritionInfo(serving_size_g=15.7, calories_kcal=82.0)}
    )
    profile = UserProfile(user_id="u", health_conditions=[HealthCondition.DIABETES_TYPE_1])
    state = await _run(tmp_path, product, profile)

    assert state.insufficient_data is True


async def test_ingredients_alone_are_enough_to_score(tmp_path):
    product = FRONT_ONLY.model_copy(update={"ingredients": ["sugar", "cocoa butter", "milk solids"]})
    profile = UserProfile(user_id="u", health_conditions=[HealthCondition.DIABETES_TYPE_1])
    state = await _run(tmp_path, product, profile)

    assert state.insufficient_data is False
    assert state.score_result.score < 100


async def test_a_database_match_supplies_the_missing_data(tmp_path):
    match = FoodProduct(code="1", product_name="KitKat Delights Dark", brand="Nestle",
                        nutrition=NutritionInfo(sugars_g=45.0, sugar_confidence=True))
    profile = UserProfile(user_id="u", health_conditions=[HealthCondition.DIABETES_TYPE_1])
    state = await _run(tmp_path, FRONT_ONLY, profile, match=match)

    assert state.insufficient_data is False
    assert state.product.nutrition.sugars_g == 45.0
