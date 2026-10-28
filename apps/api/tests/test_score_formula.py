"""The score out of 10: no cliffs, never rewarded for more, hard stops are 0.

These turn the complaint "scores are like 0, 25, 75" into checks: under the
old subtract-fixed-points engine, 5.9 g and 6.1 g of sugar were 10 points
apart and 6.1 g scored the same as 11.9 g.
"""

from __future__ import annotations

import pytest

from src.domain import scoring_rules
from src.domain.models import (
    DietaryPreference,
    FindingSeverity,
    HealthCondition,
    HealthGoal,
    NutritionInfo,
    ProductObservation,
    UserProfile,
)
from src.domain.rule_catalog import CURVE_FLOOR, SCORE_CURVES
from src.domain.score_formula import format_score
from src.domain.scoring_rules import calculate_score

# Which profile makes each curve's rule fire.
PROFILE_FOR_CURVE = {
    "sugar-blood-sugar": dict(health_conditions=[HealthCondition.DIABETES_TYPE_1]),
    "sodium-blood-pressure": dict(health_conditions=[HealthCondition.HYPERTENSION]),
    "satfat-cholesterol": dict(health_conditions=[HealthCondition.HIGH_CHOLESTEROL]),
    "cholesterol": dict(health_conditions=[HealthCondition.HIGH_CHOLESTEROL]),
    "trans-fat": dict(health_conditions=[HealthCondition.HIGH_CHOLESTEROL]),
    "sodium-kidney": dict(health_conditions=[HealthCondition.KIDNEY_DISEASE]),
    "carbs-keto": dict(dietary_preferences=[DietaryPreference.KETO]),
    "sugar-keto": dict(dietary_preferences=[DietaryPreference.KETO]),
    "calories-weight": dict(health_goals=[HealthGoal.WEIGHT_LOSS]),
    "fat-weight": dict(health_goals=[HealthGoal.WEIGHT_LOSS]),
    "sugar-weight": dict(health_goals=[HealthGoal.WEIGHT_LOSS]),
}


def _score(field: str, value: float, profile_kw: dict, **extra) -> int:
    product = ProductObservation(
        product_name="Test product",
        ingredients=["water"],
        nutrition=NutritionInfo(serving_size_g=100, **{field: value}, **extra),
        extraction_confidence=0.9,
    )
    return calculate_score(product, UserProfile(user_id="u", **profile_kw)).score


@pytest.mark.parametrize("curve", SCORE_CURVES, ids=lambda c: c.curve_id)
def test_no_cliff_at_any_threshold(curve):
    """Just below and just above every threshold score within 0.1 of each other."""
    profile = PROFILE_FOR_CURVE[curve.curve_id]
    for threshold, _ in curve.points:
        below = _score(curve.field, threshold * 0.999, profile)
        above = _score(curve.field, threshold * 1.001, profile)
        assert abs(below - above) <= 1, (curve.curve_id, threshold, below, above)


@pytest.mark.parametrize("curve", SCORE_CURVES, ids=lambda c: c.curve_id)
def test_the_curve_starts_where_its_rule_fires(curve):
    """At the first anchor nothing has fired yet; just above, its finding has."""
    profile = PROFILE_FOR_CURVE[curve.curve_id]
    start = curve.points[0][0]
    product = lambda v: ProductObservation(  # noqa: E731
        product_name="Test", ingredients=["water"],
        nutrition=NutritionInfo(serving_size_g=100, **{curve.field: v}), extraction_confidence=0.9)
    user = UserProfile(user_id="u", **profile)
    fired_at = {f.rule_id for f in calculate_score(product(start), user).findings}
    fired_above = {f.rule_id for f in calculate_score(product(start * 1.01), user).findings}
    assert not (fired_at & set(curve.rule_ids)), curve.curve_id
    assert fired_above & set(curve.rule_ids), curve.curve_id


@pytest.mark.parametrize("curve", SCORE_CURVES, ids=lambda c: c.curve_id)
def test_more_is_never_better(curve):
    profile = PROFILE_FOR_CURVE[curve.curve_id]
    top = curve.points[-1][0] * 1.5
    values = [top * i / 60 for i in range(61)]
    scores = [_score(curve.field, v, profile) for v in values]
    assert all(b <= a for a, b in zip(scores, scores[1:])), (curve.curve_id, scores)
    assert scores[-1] >= round(CURVE_FLOOR * 100)  # a measured excess alone never reaches 0


def test_the_old_cliff_is_gone():
    diabetic = PROFILE_FOR_CURVE["sugar-blood-sugar"]
    s59, s61, s119 = (_score("sugars_g", v, diabetic) for v in (5.9, 6.1, 11.9))
    assert abs(s59 - s61) <= 2          # was 10 points apart
    assert s119 < s61 - 15              # was the same score


def test_scores_are_not_restricted_to_a_few_values():
    diabetic = PROFILE_FOR_CURVE["sugar-blood-sugar"]
    distinct = {_score("sugars_g", v / 2, diabetic) for v in range(0, 80)}
    assert len(distinct) > 30


# --- hard stops ---------------------------------------------------------------


@pytest.mark.parametrize("product,profile", [
    (dict(allergens_declared=["peanut"], ingredients=["groundnut"]), dict(allergies=["peanut"])),
    (dict(ingredients=["chicken", "salt"]), dict(dietary_preferences=[DietaryPreference.VEGETARIAN])),
    (dict(ingredients=["wheat flour", "salt"]), dict(health_conditions=[HealthCondition.CELIAC_DISEASE])),
])
def test_hard_stops_are_exactly_zero(product, profile):
    obs = ProductObservation(product_name="X", nutrition=NutritionInfo(serving_size_g=100,
                                                                     sugars_g=1), **product)
    result = calculate_score(obs, UserProfile(user_id="u", **profile))
    assert result.score == 0 and result.suitability.value == "not_suitable"


def test_may_contain_is_a_warning_not_a_hard_stop():
    obs = ProductObservation(product_name="X", ingredients=["wheat"], may_contain=["peanut"],
                             nutrition=NutritionInfo(serving_size_g=100, sugars_g=1))
    score = calculate_score(obs, UserProfile(user_id="u", allergies=["peanut"])).score
    assert 0 < score < 60


# --- no dilution, and each finding's own cost ---------------------------------


def test_checks_that_dont_apply_change_nothing():
    sugary = dict(sugars_g=25.0)
    alone = _score("total_fat_g", 0.5, PROFILE_FOR_CURVE["sugar-blood-sugar"], **sugary)
    more = _score("total_fat_g", 0.5, dict(
        health_conditions=[HealthCondition.DIABETES_TYPE_1, HealthCondition.IBS,
                           HealthCondition.LACTOSE_INTOLERANCE]), **sugary)
    assert alone == more


def test_two_problems_multiply():
    both = dict(health_conditions=[HealthCondition.DIABETES_TYPE_1, HealthCondition.HYPERTENSION])
    sugar_only = _score("sugars_g", 12, PROFILE_FOR_CURVE["sugar-blood-sugar"], sodium_mg=50)
    salt_only = _score("sodium_mg", 800, PROFILE_FOR_CURVE["sodium-blood-pressure"], sugars_g=1)
    together = _score("sugars_g", 12, both, sodium_mg=800)
    assert together == round(sugar_only * salt_only / 100)  # 0.3 x 0.3 = 0.09


def test_each_finding_reports_what_it_cost():
    obs = ProductObservation(product_name="X", ingredients=["water"],
                             nutrition=NutritionInfo(serving_size_g=100, sugars_g=12, sodium_mg=800))
    user = UserProfile(user_id="u", health_conditions=[HealthCondition.DIABETES_TYPE_1,
                                                       HealthCondition.HYPERTENSION])
    result = calculate_score(obs, user)
    assert result.score == 9  # 10 x 0.3 x 0.3 = 0.9
    costs = {f.nutrient_or_ingredient: f.score_impact for f in result.findings}
    assert costs["sugars"] == 30 - 9   # without the sugar finding: 3.0
    assert costs["sodium"] == 30 - 9


def test_a_hard_stop_always_shows_its_full_cost():
    # Saturated fat alone would score 0.4; the allergen must not read as "-0.4".
    obs = ProductObservation(product_name="X", ingredients=["corn"], allergens_declared=["peanut"],
                             nutrition=NutritionInfo(serving_size_g=100, saturated_fat_g=12))
    user = UserProfile(user_id="u", allergies=["peanut"],
                       health_conditions=[HealthCondition.HIGH_CHOLESTEROL])
    result = calculate_score(obs, user)
    costs = {f.rule_id: f.score_impact for f in result.findings}
    assert result.score == 0
    assert costs["RULE-001A-ALLERGY-DECLARED"] == 100
    assert costs["RULE-004A-SATFAT-VERY-HIGH"] == 0  # the allergen already decides it


def test_a_crashed_check_costs_nothing_but_caps_below_excellent(monkeypatch):
    def broken(product, profile):
        raise RuntimeError("boom")
    monkeypatch.setattr(scoring_rules, "RULES", [broken, *scoring_rules.RULES])
    result = calculate_score(ProductObservation(product_name="X", ingredients=["water"]),
                             UserProfile(user_id="u"))
    assert result.score == 79
    error = next(f for f in result.findings if f.rule_id.startswith("RULE-ERROR-"))
    assert error.severity == FindingSeverity.WARNING


def test_iron_rich_food_helps_an_anaemic_user_but_never_past_ten():
    obs = ProductObservation(product_name="Spinach mix", ingredients=["spinach"],
                             nutrition=NutritionInfo(serving_size_g=100, iron_mg=6, sugars_g=12))
    anaemic_diabetic = UserProfile(user_id="u", health_conditions=[
        HealthCondition.ANAEMIA, HealthCondition.DIABETES_TYPE_1])
    diabetic = UserProfile(user_id="u", health_conditions=[HealthCondition.DIABETES_TYPE_1])
    assert calculate_score(obs, anaemic_diabetic).score > calculate_score(obs, diabetic).score
    anaemic = UserProfile(user_id="u", health_conditions=[HealthCondition.ANAEMIA])
    assert calculate_score(obs.model_copy(update={"nutrition": NutritionInfo(
        serving_size_g=100, iron_mg=6)}), anaemic).score == 100


@pytest.mark.parametrize("tenths,text", [(0, "0.0"), (63, "6.3"), (100, "10.0"), (7, "0.7")])
def test_format_score(tenths, text):
    assert format_score(tenths) == text
