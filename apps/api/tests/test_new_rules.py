"""
Tests for the rule-catalog rewrite:
- Findings carry a source citation and an evidence tier.
- Anaemia rules fire only for anaemic users.
- 'May contain' is an alert, not a declared allergen.
- Caffeine sensitivity is a user-toggle, flagged as `sensitivity` tier.
- extraction_confidence below the gate returns insufficient-data.
"""

from __future__ import annotations

import pytest

from src.domain.models import (
    EvidenceTier,
    FindingSeverity,
    HealthCondition,
    NutritionInfo,
    ProductObservation,
    UserProfile,
)
from src.domain.rule_catalog import MIN_EXTRACTION_CONFIDENCE, RULE_CATALOG, rule
from src.domain.scoring_rules import calculate_score


# ---------------------------------------------------------------------------
# Catalog shape
# ---------------------------------------------------------------------------


def test_catalog_rule_ids_are_unique():
    ids = [r.rule_id for r in RULE_CATALOG]
    assert len(ids) == len(set(ids))


def test_catalog_lookup_round_trips():
    for spec in RULE_CATALOG:
        assert rule(spec.rule_id) is spec


# ---------------------------------------------------------------------------
# Every finding carries source + evidence tier
# ---------------------------------------------------------------------------


def test_findings_carry_source_and_tier():
    product = ProductObservation(
        product_name="Salty Snack",
        ingredients=["wheat flour", "salt", "palm oil"],
        nutrition=NutritionInfo(sodium_mg=900, saturated_fat_g=10),
    )
    profile = UserProfile(
        user_id="u",
        health_conditions=[HealthCondition.HYPERTENSION, HealthCondition.HIGH_CHOLESTEROL],
    )
    result = calculate_score(product, profile)

    assert result.findings, "expected findings for high-sodium / high-sat-fat product"
    for f in result.findings:
        assert f.source, f"finding {f.rule_id} missing source citation"
        assert f.evidence_tier in (EvidenceTier.STRONG, EvidenceTier.SENSITIVITY), (
            f"finding {f.rule_id} has an invalid tier"
        )


# ---------------------------------------------------------------------------
# "May contain" cross-contact — alert, not a hard stop
# ---------------------------------------------------------------------------


def test_may_contain_triggers_alert_not_hard_stop():
    product = ProductObservation(
        product_name="Dark Chocolate",
        ingredients=["cocoa mass", "sugar", "cocoa butter"],
        allergens_declared=[],
        may_contain=["peanut", "tree nut"],
    )
    profile = UserProfile(user_id="u", allergies=["peanut"])
    result = calculate_score(product, profile)

    may_findings = [f for f in result.findings if f.rule_id == "RULE-001D-ALLERGY-MAY-CONTAIN"]
    assert len(may_findings) == 1
    assert may_findings[0].severity == FindingSeverity.ALERT

    # Score should be penalised but NOT capped at the hard-stop ceiling of 15,
    # because 'may contain' is a cross-contact warning, not a declared allergen.
    assert result.score > 15
    assert result.score < 100


def test_may_contain_without_matching_allergy_is_silent():
    product = ProductObservation(
        product_name="Oat Biscuit",
        ingredients=["oats", "sugar", "oil"],
        may_contain=["peanut"],
    )
    profile = UserProfile(user_id="u", allergies=["milk"])
    result = calculate_score(product, profile)
    assert not any(f.rule_id.startswith("RULE-001") for f in result.findings)


# ---------------------------------------------------------------------------
# Anaemia rules
# ---------------------------------------------------------------------------


def test_anaemia_rules_dormant_for_non_anaemic_users():
    product = ProductObservation(
        product_name="Fortified Flour",
        ingredients=["+F fortified wheat flour", "iron (as ferrous fumarate)"],
        nutrition=NutritionInfo(iron_mg=5.0),
    )
    profile = UserProfile(user_id="u")
    result = calculate_score(product, profile)
    assert not any(f.rule_id.startswith("RULE-011") for f in result.findings)


def test_anaemia_fortified_product_scores_better():
    product = ProductObservation(
        product_name="Fortified Flour",
        ingredients=["+F fortified wheat flour"],
        nutrition=NutritionInfo(iron_mg=5.0),
    )
    profile = UserProfile(
        user_id="u", health_conditions=[HealthCondition.ANAEMIA]
    )
    result = calculate_score(product, profile)
    rule_ids = {f.rule_id for f in result.findings}
    assert "RULE-011A-ANAEMIA-IRON-RICH" in rule_ids
    assert "RULE-011B-ANAEMIA-FORTIFIED" in rule_ids
    # Iron-rich + fortified = negative impact = bonus. Nothing bad in the
    # product, so score should rise above 100-cap neutral.
    assert result.score == 100


def test_anaemia_tea_inhibitor_flagged():
    product = ProductObservation(
        product_name="Masala Tea Mix",
        ingredients=["black tea", "sugar", "cardamom"],
    )
    profile = UserProfile(
        user_id="u", health_conditions=[HealthCondition.ANAEMIA]
    )
    result = calculate_score(product, profile)
    assert any(f.rule_id == "RULE-011D-ANAEMIA-INHIBITOR" for f in result.findings)


def test_tea_tree_is_not_an_iron_inhibitor():
    product = ProductObservation(
        product_name="Scalp Lotion Snack (fake)",
        ingredients=["tea tree oil"],
    )
    profile = UserProfile(
        user_id="u", health_conditions=[HealthCondition.ANAEMIA]
    )
    result = calculate_score(product, profile)
    assert not any(f.rule_id == "RULE-011D-ANAEMIA-INHIBITOR" for f in result.findings)


def test_vitamin_c_ingredient_gives_absorption_note():
    product = ProductObservation(
        product_name="Amla Candy",
        ingredients=["amla", "sugar"],
        nutrition=NutritionInfo(sugars_g=2.0),
    )
    profile = UserProfile(
        user_id="u", health_conditions=[HealthCondition.ANAEMIA]
    )
    result = calculate_score(product, profile)
    assert any(f.rule_id == "RULE-011C-ANAEMIA-VITAMIN-C" for f in result.findings)


# ---------------------------------------------------------------------------
# Caffeine sensitivity
# ---------------------------------------------------------------------------


def test_caffeine_only_fires_when_opted_in():
    product = ProductObservation(
        product_name="Cold Coffee",
        ingredients=["milk", "coffee", "sugar"],
    )
    off = UserProfile(user_id="u", avoid_caffeine=False)
    on = UserProfile(user_id="u", avoid_caffeine=True)

    assert not any(
        f.rule_id == "RULE-012-CAFFEINE-SENSITIVITY"
        for f in calculate_score(product, off).findings
    )
    hits = [
        f for f in calculate_score(product, on).findings
        if f.rule_id == "RULE-012-CAFFEINE-SENSITIVITY"
    ]
    assert len(hits) == 1
    assert hits[0].evidence_tier == EvidenceTier.SENSITIVITY
    assert hits[0].severity == FindingSeverity.INFO


def test_caffeine_sensitivity_detail_is_grounded():
    """The caffeine finding must not claim diagnosis / treatment / safety."""
    product = ProductObservation(
        product_name="Guarana Energy Drink",
        ingredients=["water", "sugar", "guarana extract"],
    )
    profile = UserProfile(user_id="u", avoid_caffeine=True)
    result = calculate_score(product, profile)
    hit = next(f for f in result.findings if f.rule_id == "RULE-012-CAFFEINE-SENSITIVITY")
    low = hit.detail.lower()
    for forbidden in ("diagnos", "treat", "cure", "is safe", "guaranteed"):
        assert forbidden not in low, f"caffeine detail should not say {forbidden!r}"


# ---------------------------------------------------------------------------
# Diabetes rule now also fires for prediabetes
# ---------------------------------------------------------------------------


def test_prediabetes_triggers_sugar_rule():
    product = ProductObservation(
        product_name="Sugary Cola",
        ingredients=["water", "sugar"],
        nutrition=NutritionInfo(sugars_g=25),
    )
    profile = UserProfile(
        user_id="u", health_conditions=[HealthCondition.PREDIABETES]
    )
    result = calculate_score(product, profile)
    assert any(f.rule_id == "RULE-003A-SUGAR-EXTREME" for f in result.findings)


# ---------------------------------------------------------------------------
# Extraction confidence gate
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_validate_extraction_rejects_low_confidence():
    from src.orchestration.scan_graph import ScanState, node_validate_extraction

    low = ProductObservation(
        product_name="Blurry Pack",
        ingredients=["something"],
        extraction_confidence=max(0.0, MIN_EXTRACTION_CONFIDENCE - 0.1),
    )
    state = ScanState(user_id="u", photo_bytes=b"", product=low)
    out = await node_validate_extraction(state)
    assert out["insufficient_data"] is True
    assert "confident" in (out.get("pipeline_message") or "").lower()


@pytest.mark.asyncio
async def test_validate_extraction_accepts_adequate_confidence():
    from src.orchestration.scan_graph import ScanState, node_validate_extraction

    ok = ProductObservation(
        product_name="Clean Pack",
        ingredients=["wheat flour", "sugar"],
        extraction_confidence=min(1.0, MIN_EXTRACTION_CONFIDENCE + 0.2),
    )
    state = ScanState(user_id="u", photo_bytes=b"", product=ok)
    out = await node_validate_extraction(state)
    assert out["insufficient_data"] is False
