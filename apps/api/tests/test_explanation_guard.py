"""Tests for the guard that checks LLM explanations before users see them."""

from __future__ import annotations

from src.services.explanation_service import is_explanation_grounded

FACTS = "12 100\n- [CRITICAL] Allergen in Ingredients: Milk: Contains ingredient 'casein'\nSodium: 450 mg, Sugars: 6.5 g"


def test_accepts_explanation_using_only_known_numbers():
    text = "It contains casein, which matches your milk allergy. Sodium is 450 mg per serving."
    assert is_explanation_grounded(text, FACTS)


def test_rejects_invented_number():
    assert not is_explanation_grounded("It has 900 mg of sodium.", FACTS)


def test_rejects_safety_guarantee():
    assert not is_explanation_grounded("This product is safe for you.", FACTS)
    assert not is_explanation_grounded("It is allergen-free.", FACTS)


def test_rejects_medical_advice_wording():
    assert not is_explanation_grounded("This will help cure your condition.", FACTS)


def test_rejects_empty_text():
    assert not is_explanation_grounded("   ", FACTS)


def test_accepts_text_without_numbers():
    assert is_explanation_grounded("Contains casein, a milk protein. Please check the label.", FACTS)


def test_does_not_reject_words_that_merely_contain_cure():
    assert is_explanation_grounded("Please secure a clear photo of the label.", FACTS)
