"""Local food-database values are per 100 g/ml; the scoring rules read per serving.

Open Food Facts rows are imported from the `_100g` fields. When a scan is
enriched from such a row, the numbers must be brought onto the label's serving
basis before the per-serving rules see them. A 250 ml Sting can (6.8 g sugar
per 100 ml) is 17 g of sugar, not 6.8 g.
"""

from __future__ import annotations

import pytest

from src.domain.models import (
    HealthCondition,
    NutritionInfo,
    ProductObservation,
    UserProfile,
)
from src.orchestration import scan_graph
from src.repositories.product_repository import FoodProduct
from src.services.nutrition_merge import merge_reference_nutrition
from src.services.scoring_service import ScoringService

STING_PER_100 = NutritionInfo(
    calories_kcal=28.0,
    total_fat_g=0.0,
    saturated_fat_g=0.0,
    sodium_mg=0.053,
    total_carbs_g=7.0,
    sugars_g=6.8,
    added_sugars_g=3.415,
    protein_g=0.0,
    sodium_confidence=True,
    sugar_confidence=True,
    fat_confidence=True,
)


def test_scales_per_100_values_to_the_label_serving():
    merged = merge_reference_nutrition(NutritionInfo(serving_size_g=250), STING_PER_100)

    assert merged.serving_size_g == 250
    assert merged.sugars_g == pytest.approx(17.0)
    assert merged.calories_kcal == pytest.approx(70.0)
    assert merged.total_carbs_g == pytest.approx(17.5)
    assert merged.sugar_confidence is True


def test_scales_down_for_a_small_serving():
    biscuit_per_100 = NutritionInfo(sugars_g=30.0, sodium_mg=400.0)
    merged = merge_reference_nutrition(NutritionInfo(serving_size_g=30), biscuit_per_100)

    assert merged.sugars_g == pytest.approx(9.0)
    assert merged.sodium_mg == pytest.approx(120.0)


def test_label_values_win_over_database_values():
    label = NutritionInfo(serving_size_g=250, sugars_g=27.0)
    merged = merge_reference_nutrition(label, STING_PER_100)

    assert merged.sugars_g == 27.0  # read from the label, not replaced
    assert merged.calories_kcal == pytest.approx(70.0)  # filled, scaled


def test_unknown_serving_and_no_label_numbers_uses_per_100_basis():
    merged = merge_reference_nutrition(NutritionInfo(), STING_PER_100)

    assert merged.serving_size_g == 100
    assert merged.sugars_g == 6.8


def test_unknown_serving_with_label_numbers_does_not_mix_bases():
    label = NutritionInfo(sugars_g=5.0)
    merged = merge_reference_nutrition(label, STING_PER_100)

    assert merged.sugars_g == 5.0
    assert merged.calories_kcal is None
    assert merged.serving_size_g is None
    assert merged.sugar_confidence is False


def test_missing_database_values_stay_missing():
    merged = merge_reference_nutrition(NutritionInfo(serving_size_g=250), NutritionInfo(sugars_g=6.8))

    assert merged.sodium_mg is None
    assert merged.protein_g is None


class _FakeRepo:
    def __init__(self, product: FoodProduct) -> None:
        self._product = product

    def match_product(self, name, brand, category):
        return self._product


async def test_match_node_scales_sting_and_scoring_flags_very_high_sugar():
    front_label_only = ProductObservation(
        brand="Sting",
        product_name="Sting Energy Drink",
        category="energy drink",
        nutrition=NutritionInfo(serving_size_g=250),
        extraction_confidence=0.8,
    )
    repo = _FakeRepo(
        FoodProduct(code="8902080000227", product_name="Sting Energy", brand="Sting",
                    nutrition=STING_PER_100)
    )

    state = scan_graph.ScanState(user_id="u", photo_bytes=b"", product=front_label_only)
    product = (await scan_graph.node_match_product(state, repo))["product"]

    assert product.nutrition.sugars_g == pytest.approx(17.0)
    result = ScoringService().score(
        product=product,
        profile=UserProfile(user_id="u", health_conditions=[HealthCondition.DIABETES_TYPE_1]),
    )
    assert any(f.rule_id == "RULE-003B-SUGAR-VERY-HIGH" for f in result.findings)
    assert result.score < 75
