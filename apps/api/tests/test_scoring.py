"""
Tests for the deterministic scoring service.

Critical test: same product + different health profiles = different results.
"""

from __future__ import annotations

import pytest

from src.domain.models import (
    FindingSeverity,
    NutritionInfo,
    ProductObservation,
    RiskLevel,
    SuitabilityStatus,
    UserProfile,
)
import src.domain.scoring_rules as scoring_rules
from src.domain.scoring_rules import calculate_score
from src.services.scoring_service import ScoringService


# ---------------------------------------------------------------------------
# Critical test: same product, different profiles → different scores
# ---------------------------------------------------------------------------


def test_same_product_different_profiles_yields_different_scores(
    instant_noodle_product, healthy_profile, diabetic_profile, hypertensive_profile
):
    """
    CRITICAL: The same product must produce different scores for different health profiles.
    This verifies personalization is working and the LLM is not driving scoring.
    """
    svc = ScoringService()

    healthy_score = svc.score(instant_noodle_product, healthy_profile)
    diabetic_score = svc.score(instant_noodle_product, diabetic_profile)
    hypertensive_score = svc.score(instant_noodle_product, hypertensive_profile)

    # All three should be different
    assert healthy_score.score > diabetic_score.score or healthy_score.score > hypertensive_score.score, (
        "A high-sodium, wheat-based product should score worse for diabetic/hypertensive profiles"
    )

    # Hypertensive user should get a worse score on a 1400mg sodium product
    assert hypertensive_score.score < healthy_score.score, (
        f"Hypertensive score ({hypertensive_score.score}) should be lower than "
        f"healthy score ({healthy_score.score}) for a 1400mg sodium product"
    )

    # Rules applied should differ between profiles
    assert set(healthy_score.rules_applied) != set(hypertensive_score.rules_applied)


# ---------------------------------------------------------------------------
# Hypertension rule tests
# ---------------------------------------------------------------------------


def test_very_high_sodium_triggers_critical_finding_for_hypertension(
    instant_noodle_product, hypertensive_profile
):
    """1400mg sodium + hypertension = critical finding, significant score reduction."""
    result = calculate_score(instant_noodle_product, hypertensive_profile)

    critical_findings = [f for f in result.findings if f.severity == FindingSeverity.CRITICAL]
    assert len(critical_findings) >= 1, "Should have at least one critical finding"

    sodium_findings = [f for f in result.findings if "sodium" in (f.nutrient_or_ingredient or "")]
    assert len(sodium_findings) >= 1, "Should have a sodium-specific finding"
    assert result.score < 80, f"Score should be significantly reduced, got {result.score}"


def test_low_sodium_product_no_hypertension_penalty(hypertensive_profile):
    """A low-sodium product should not trigger the hypertension rule."""
    low_sodium_product = ProductObservation(
        product_name="Low Sodium Soup",
        ingredients=["water", "vegetables", "salt"],
        nutrition=NutritionInfo(sodium_mg=150, sodium_confidence=True),
    )
    result = calculate_score(low_sodium_product, hypertensive_profile)

    sodium_findings = [f for f in result.findings if "sodium" in (f.nutrient_or_ingredient or "")]
    assert len(sodium_findings) == 0, "Low sodium should not trigger hypertension rule"
    assert result.score >= 90, f"Low sodium product should score well, got {result.score}"


# ---------------------------------------------------------------------------
# Diabetes rule tests
# ---------------------------------------------------------------------------


def test_high_sugar_triggers_diabetes_finding(sugary_drink_product, diabetic_profile):
    """28g sugar + diabetes = critical or alert finding."""
    result = calculate_score(sugary_drink_product, diabetic_profile)

    sugar_findings = [f for f in result.findings if "sugar" in (f.nutrient_or_ingredient or "")]
    assert len(sugar_findings) >= 1, "Should have a sugar finding for diabetic profile"
    assert result.score < 70, f"High sugar product should score poorly for diabetic, got {result.score}"


def test_high_sugar_no_penalty_for_healthy_user(sugary_drink_product, healthy_profile):
    """A high-sugar product should not trigger diabetes rules for a healthy user."""
    result = calculate_score(sugary_drink_product, healthy_profile)

    diabetes_rules = [r for r in result.rules_applied if "sugar_diabetes" in r or "SUGAR" in r]
    # The general sodium rule might fire, but not the diabetes-specific one
    assert "_rule_high_sugar_diabetes" not in result.rules_applied, (
        "Diabetes sugar rule should NOT apply to healthy users"
    )


def test_hfcs_triggers_high_gi_finding_for_diabetic(diabetic_profile):
    """High-fructose corn syrup ingredient should trigger a high-GI finding."""
    hfcs_product = ProductObservation(
        product_name="Corn Syrup Snack",
        ingredients=["high fructose corn syrup", "wheat flour"],
        nutrition=NutritionInfo(sugars_g=2, sugar_confidence=True),  # Declared sugar below the nutrient rule's 3 g trigger
    )
    result = calculate_score(hfcs_product, diabetic_profile)

    hgi_findings = [f for f in result.findings if f.rule_id == "RULE-003E-HIGH-GI-INGREDIENTS"]
    assert len(hgi_findings) >= 1, "HFCS should trigger high-GI ingredient finding"


# ---------------------------------------------------------------------------
# Allergy conflict tests
# ---------------------------------------------------------------------------


def test_allergen_declared_triggers_critical_finding(peanut_product, allergic_profile):
    """Peanut in declared allergens + peanut allergy = critical finding."""
    result = calculate_score(peanut_product, allergic_profile)

    allergy_findings = [
        f for f in result.findings
        if "ALLERGY" in f.rule_id
    ]
    assert len(allergy_findings) >= 1, "Should have allergy finding"

    critical = [f for f in allergy_findings if f.severity == FindingSeverity.CRITICAL]
    assert len(critical) >= 1, "Allergen conflict should be critical severity"
    assert result.score <= 60, f"Allergy conflict should severely reduce score, got {result.score}"


def test_no_allergy_conflict_when_allergen_absent(allergic_profile):
    """A product without peanuts should not trigger allergy rule for peanut-allergic user."""
    safe_product = ProductObservation(
        product_name="Rice Cakes",
        ingredients=["brown rice", "salt"],
        allergens_declared=[],
        nutrition=NutritionInfo(sodium_mg=50),
    )
    result = calculate_score(safe_product, allergic_profile)

    allergy_findings = [f for f in result.findings if "ALLERGY" in f.rule_id]
    assert len(allergy_findings) == 0, "No allergy findings for peanut-free product"
    assert result.score >= 90


# ---------------------------------------------------------------------------
# Dietary preference tests
# ---------------------------------------------------------------------------


def test_vegan_violation_triggers_finding(vegan_violation_product, vegan_profile):
    """Chicken powder in a product triggers a vegan violation finding."""
    result = calculate_score(vegan_violation_product, vegan_profile)

    vegan_findings = [f for f in result.findings if f.rule_id == "RULE-009A-VEGAN"]
    assert len(vegan_findings) >= 1, "Should trigger vegan violation"
    assert result.score < 90


def test_vegan_rule_not_applied_to_healthy_user(vegan_violation_product, healthy_profile):
    """Vegan rule should NOT apply to users without vegan preference."""
    result = calculate_score(vegan_violation_product, healthy_profile)

    vegan_findings = [f for f in result.findings if f.rule_id == "RULE-009A-VEGAN"]
    assert len(vegan_findings) == 0, "Vegan rule should not apply to non-vegan users"


# ---------------------------------------------------------------------------
# Missing data handling
# ---------------------------------------------------------------------------


def test_missing_nutrition_data_handled_gracefully(hypertensive_profile):
    """Scoring should work even when all nutrition values are None."""
    sparse_product = ProductObservation(
        product_name="Unknown Product",
        ingredients=[],
        nutrition=NutritionInfo(),  # All None
    )
    result = calculate_score(sparse_product, hypertensive_profile)

    # Should not raise, should return a valid score
    assert 0 <= result.score <= 100
    # No findings expected since all values are None
    sodium_findings = [f for f in result.findings if "sodium" in (f.nutrient_or_ingredient or "")]
    assert len(sodium_findings) == 0


def test_empty_product_returns_valid_score(healthy_profile):
    """Completely empty product should produce a valid score without errors."""
    empty = ProductObservation()
    result = calculate_score(empty, healthy_profile)
    assert isinstance(result.score, int)
    assert 0 <= result.score <= 100


# ---------------------------------------------------------------------------
# Suitability thresholds
# ---------------------------------------------------------------------------


def test_score_100_is_excellent():
    """A product with no violations for a healthy user should score near 100."""
    from src.domain.models import HealthGoal
    profile = UserProfile(user_id="t", health_goals=[HealthGoal.MAINTAIN_WEIGHT])
    product = ProductObservation(
        product_name="Pure Water",
        ingredients=["water"],
        nutrition=NutritionInfo(sodium_mg=0, sugars_g=0, calories_kcal=0),
    )
    result = calculate_score(product, profile)
    assert result.score == 100
    assert result.suitability == SuitabilityStatus.EXCELLENT
    assert result.risk_level == RiskLevel.LOW


def test_combined_conditions_worse_score_than_single(
    instant_noodle_product, hypertensive_profile, combined_conditions_profile
):
    """A user with both diabetes and hypertension should score the instant noodle product worse."""
    hyp_result = calculate_score(instant_noodle_product, hypertensive_profile)
    combined_result = calculate_score(instant_noodle_product, combined_conditions_profile)

    assert combined_result.score <= hyp_result.score, (
        f"Combined conditions ({combined_result.score}) should score <= hypertension alone ({hyp_result.score})"
    )


# ---------------------------------------------------------------------------
# Allergy rigor: synonyms, hard stop, honesty about unreadable labels
# ---------------------------------------------------------------------------


def _profile(*allergies: str) -> UserProfile:
    return UserProfile(user_id="t", allergies=list(allergies))


@pytest.mark.parametrize(
    "allergy, ingredient",
    [
        ("Milk", "casein"),
        ("Milk", "Ghee"),
        ("Dairy", "paneer"),
        ("Peanuts", "groundnut oil"),
        ("Nuts", "cashew pieces"),
        ("Wheat", "maida"),
        ("Gluten", "barley malt extract"),
        ("Egg", "egg albumin"),
        ("Shellfish", "prawn powder"),
        ("Soy", "soya lecithin"),
    ],
)
def test_allergen_synonyms_are_caught(allergy, ingredient):
    product = ProductObservation(product_name="X", ingredients=[ingredient, "salt"])
    result = calculate_score(product, _profile(allergy))
    assert any(f.rule_id.startswith("RULE-001B") for f in result.findings), (
        f"{ingredient!r} should be flagged for a {allergy} allergy"
    )


@pytest.mark.parametrize(
    "allergy, ingredient",
    [
        ("Milk", "coconut milk"),
        ("Milk", "cocoa butter"),
        ("Milk", "peanut butter"),
        ("Nuts", "nutmeg"),
        ("Nuts", "coconut"),
        ("Egg", "eggplant"),
    ],
)
def test_lookalike_ingredients_are_not_flagged(allergy, ingredient):
    product = ProductObservation(product_name="X", ingredients=[ingredient, "water"])
    result = calculate_score(product, _profile(allergy))
    assert not any(f.rule_id.startswith(("RULE-001A", "RULE-001B")) for f in result.findings), (
        f"{ingredient!r} must not be flagged for a {allergy} allergy"
    )


def test_declared_generic_nuts_flags_peanut_allergy():
    product = ProductObservation(
        product_name="X", ingredients=["sugar"], allergens_declared=["nuts"]
    )
    result = calculate_score(product, _profile("Peanuts"))
    assert any(f.rule_id.startswith("RULE-001A") for f in result.findings)


def test_allergy_match_is_always_not_suitable(peanut_product, allergic_profile):
    result = calculate_score(peanut_product, allergic_profile)
    assert result.score <= 15
    assert result.suitability == SuitabilityStatus.NOT_SUITABLE


def test_celiac_gluten_is_not_suitable():
    from src.domain.models import HealthCondition

    profile = UserProfile(user_id="t", health_conditions=[HealthCondition.CELIAC_DISEASE])
    product = ProductObservation(product_name="Bread", ingredients=["wheat flour", "yeast"])
    result = calculate_score(product, profile)
    assert result.suitability == SuitabilityStatus.NOT_SUITABLE


def test_unreadable_label_is_not_called_safe_for_allergic_user():
    product = ProductObservation(product_name="Mystery Biscuit")  # no ingredients read
    result = calculate_score(product, _profile("Milk"))
    assert any(f.rule_id == "RULE-001C-ALLERGY-UNVERIFIED" for f in result.findings)
    assert result.score < 80


def test_failed_rule_is_visible_and_blocks_excellent(monkeypatch, healthy_profile):
    def boom(product, profile):
        raise ValueError("boom")

    monkeypatch.setattr(scoring_rules, "RULES", [boom])
    result = calculate_score(ProductObservation(product_name="Pure Water"), healthy_profile)
    assert any(f.rule_id.startswith("RULE-ERROR") for f in result.findings)
    assert result.score <= 79
    assert result.suitability != SuitabilityStatus.EXCELLENT
