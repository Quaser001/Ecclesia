"""Label numbers that can't be true are never scored (readiness review C, row 1)."""

from __future__ import annotations

import pytest

from src.domain.models import HealthCondition, NutritionInfo, ProductObservation, UserProfile
from src.domain.nutrition_plausibility import check_nutrition
from tests.test_scan_data_gate import _run

# A real Indian biscuit label, per 30 g serving: must pass untouched.
GOOD = NutritionInfo(serving_size_g=30, calories_kcal=144, total_fat_g=6.0, saturated_fat_g=3.0,
                     trans_fat_g=0.1, total_carbs_g=20.4, sugars_g=7.5, added_sugars_g=7.0,
                     protein_g=2.1, sodium_mg=105, dietary_fiber_g=0.6,
                     sodium_confidence=True, sugar_confidence=True, fat_confidence=True)


def test_a_real_label_passes_untouched():
    r = check_nutrition(GOOD)
    assert r.reliable and r.dropped == [] and r.nutrition == GOOD


def test_zero_calorie_drink_passes():
    r = check_nutrition(NutritionInfo(serving_size_g=300, calories_kcal=0, total_fat_g=0,
                                      total_carbs_g=0, sugars_g=0, protein_g=0, sodium_mg=30))
    assert r.reliable and r.dropped == []


def test_rounding_on_small_numbers_is_not_a_contradiction():
    # 0.5 g sugar on a label that rounds carbs to 0: within slack.
    assert check_nutrition(NutritionInfo(total_carbs_g=0, sugars_g=0.5)).reliable


@pytest.mark.parametrize("field, value", [
    ("sugars_g", -3), ("sodium_mg", -10), ("calories_kcal", 99_999), ("total_fat_g", 12_000),
    ("sodium_mg", float("nan")),
])
def test_an_impossible_value_alone_becomes_unknown(field, value):
    r = check_nutrition(GOOD.model_copy(update={field: value}))
    assert getattr(r.nutrition, field) is None
    assert field in r.dropped


def test_a_dropped_value_loses_its_clearly_read_flag():
    r = check_nutrition(GOOD.model_copy(update={"sodium_mg": -5}))
    assert r.nutrition.sodium_mg is None and r.nutrition.sodium_confidence is False


@pytest.mark.parametrize("change, why", [
    ({"sugars_g": 45.0}, "sugars > total carbs"),
    ({"saturated_fat_g": 9.0}, "saturated fat > total fat"),
    ({"added_sugars_g": 15.0}, "added sugars > sugars"),
    ({"total_fat_g": 25.0, "total_carbs_g": 20.0, "saturated_fat_g": 3.0, "calories_kcal": 330},
     "macros heavier than the 30 g serving"),
    ({"calories_kcal": 602.0}, "kJ read as kcal (144 kcal = 602 kJ)"),
    ({"sodium_mg": 20_000.0}, "more sodium than 30 g can hold"),
])
def test_contradicting_numbers_make_the_read_unreliable(change, why):
    r = check_nutrition(GOOD.model_copy(update=change))
    assert not r.reliable, why


def test_per_100g_numbers_under_a_30g_serving_are_caught():
    # The model copied the 100 g column but kept the 30 g serving size.
    per_100 = GOOD.model_copy(update={"total_fat_g": 20, "total_carbs_g": 68, "protein_g": 7,
                                      "calories_kcal": 480, "sugars_g": 25, "added_sugars_g": 23,
                                      "saturated_fat_g": 10})
    assert not check_nutrition(per_100).reliable


async def test_a_contradicting_label_is_insufficient_data_not_a_score(tmp_path):
    product = ProductObservation(product_name="Choco bar", brand="X", extraction_confidence=0.95,
                                 ingredients=["sugar", "cocoa"],
                                 nutrition=GOOD.model_copy(update={"sugars_g": 45.0}))
    profile = UserProfile(user_id="u", health_conditions=[HealthCondition.DIABETES_TYPE_1])
    state = await _run(tmp_path, product, profile)
    assert state.insufficient_data is True
    assert "don't add up" in (state.pipeline_message or "")


async def test_an_impossible_value_is_dropped_and_the_rest_still_scored(tmp_path):
    product = ProductObservation(product_name="Biscuit", brand="X", extraction_confidence=0.95,
                                 ingredients=["wheat flour", "sugar"],
                                 nutrition=GOOD.model_copy(update={"sodium_mg": -40}))
    profile = UserProfile(user_id="u", health_conditions=[HealthCondition.HYPERTENSION])
    state = await _run(tmp_path, product, profile)
    assert state.insufficient_data is False
    assert state.product.nutrition.sodium_mg is None  # unknown, not a "low sodium" pass
