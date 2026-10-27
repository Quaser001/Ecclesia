"""Insights per goal: which scans fit each of the user's goals, judged by the
same scoring rules (or one stated nutrient threshold), never guessed."""

from __future__ import annotations

import json
from datetime import date

from src.domain.models import HealthGoal
from src.services.insights_service import build_goal_insights, build_insights


def _row(scan_id, name, **nutrition):
    product = {"product_name": name, "brand": "B", "ingredients": nutrition.pop("ingredients", []),
               "nutrition": nutrition, "extraction_confidence": 0.9}
    return {
        "scan_id": scan_id, "scanned_at": "2026-10-27T09:00:00+00:00",
        "product_name": name, "brand": "B", "score": 50, "suitability": "fair",
        "score_json": json.dumps({"score": 50, "suitability": "fair", "risk_level": "low",
                                  "findings": [], "rules_applied": []}),
        "product_json": json.dumps(product),
    }


COLA = _row("cola", "Cola", sugars_g=27.0, calories_kcal=108, sodium_mg=10)
OATS = _row("oats", "Oats", sugars_g=1.0, calories_kcal=150, protein_g=5.0, sodium_mg=5,
            total_fat_g=2.5, saturated_fat_g=0.5)
NAMKEEN = _row("namkeen", "Bhujia", sugars_g=2.0, calories_kcal=280, sodium_mg=820,
               protein_g=11.0, total_fat_g=19.0, saturated_fat_g=8.0)
UNKNOWN = _row("blank", "Mystery")  # no nutrition at all


def _by_goal(out):
    return {g.goal: g for g in out}


def test_blood_sugar_goal_counts_sugary_scans_against_it():
    g = _by_goal(build_goal_insights([COLA, OATS, NAMKEEN], [HealthGoal.MANAGE_BLOOD_SUGAR]))
    sugar = g[HealthGoal.MANAGE_BLOOD_SUGAR]
    assert sugar.tracked
    assert (sugar.checked, sugar.fits) == (3, 2)
    assert sugar.main_issue  # the cola's sugar finding title


def test_heart_goal_flags_saturated_fat():
    """The heart-health goal uses the fat/cholesterol rules (RULE-004). The cola
    has no fat values, so it isn't counted either way."""
    g = _by_goal(build_goal_insights([COLA, OATS, NAMKEEN], [HealthGoal.HEART_HEALTH]))
    heart = g[HealthGoal.HEART_HEALTH]
    assert (heart.checked, heart.fits) == (2, 1)


def test_scans_without_the_needed_data_are_not_counted_as_fitting():
    g = _by_goal(build_goal_insights([COLA, UNKNOWN], [HealthGoal.MANAGE_BLOOD_SUGAR]))
    assert g[HealthGoal.MANAGE_BLOOD_SUGAR].checked == 1


def test_muscle_gain_uses_a_stated_protein_threshold():
    g = _by_goal(build_goal_insights([COLA, OATS, NAMKEEN], [HealthGoal.MUSCLE_GAIN]))
    muscle = g[HealthGoal.MUSCLE_GAIN]
    assert muscle.tracked
    assert (muscle.checked, muscle.fits) == (2, 1)  # cola has no protein value
    assert "10 g" in muscle.basis


def test_goals_without_a_rule_say_so_instead_of_inventing():
    g = _by_goal(build_goal_insights([COLA, OATS], [HealthGoal.IMPROVE_ENERGY]))
    energy = g[HealthGoal.IMPROVE_ENERGY]
    assert energy.tracked is False
    assert energy.checked == 0 and energy.fits == 0


def test_goals_follow_the_profile_order_and_only_its_goals():
    out = build_goal_insights([COLA], [HealthGoal.HEART_HEALTH, HealthGoal.WEIGHT_LOSS])
    assert [g.goal for g in out] == [HealthGoal.HEART_HEALTH, HealthGoal.WEIGHT_LOSS]


def test_build_insights_includes_goal_cards():
    out = build_insights([COLA, OATS], today=date(2026, 10, 28),
                         goals=[HealthGoal.MANAGE_BLOOD_SUGAR])
    assert [g.goal for g in out.goals] == [HealthGoal.MANAGE_BLOOD_SUGAR]
    assert build_insights([], today=date(2026, 10, 28),
                          goals=[HealthGoal.WEIGHT_LOSS]).goals[0].checked == 0
