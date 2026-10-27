"""Tests for turning raw Gemini JSON into a ProductObservation."""

from __future__ import annotations

from src.providers.gemini_provider import _dict_to_product_observation


def test_salt_is_converted_to_sodium_not_copied():
    obs = _dict_to_product_observation({"nutrition": {"salt_g": 1.0}, "ingredients": ["salt"]})
    assert obs.nutrition.sodium_mg == 400.0


def test_explicit_sodium_wins_over_salt():
    obs = _dict_to_product_observation({"nutrition": {"sodium_mg": 120, "salt_g": 5}})
    assert obs.nutrition.sodium_mg == 120.0


def test_missing_confidence_is_not_treated_as_high():
    obs = _dict_to_product_observation({"product_name": "X"})
    assert obs.extraction_confidence == 0.5


def test_confidence_is_clamped():
    obs = _dict_to_product_observation({"extraction_confidence": 7})
    assert obs.extraction_confidence == 1.0


def test_model_reported_uncertain_sodium_is_respected():
    obs = _dict_to_product_observation({"nutrition": {"sodium_mg": 300, "sodium_confidence": False}})
    assert obs.nutrition.sodium_mg == 300.0
    assert obs.nutrition.sodium_confidence is False


def test_missing_value_has_no_confidence():
    obs = _dict_to_product_observation({"nutrition": {}})
    assert obs.nutrition.sodium_confidence is False
