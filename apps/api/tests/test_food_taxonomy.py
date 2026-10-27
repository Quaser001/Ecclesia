"""CalFit's India food categories and flavour tags. Deterministic keyword rules."""

from __future__ import annotations

import pytest

from src.domain.food_taxonomy import (
    CATEGORIES,
    classify_off_tags,
    classify_text,
    flavours_of,
)


def test_twelve_launch_categories():
    assert set(CATEGORIES) == {
        "biscuits", "chips", "namkeen", "instant_noodles", "edible_oils", "chocolates",
        "soft_drinks", "energy_drinks", "breakfast_cereals", "fruit_juices",
        "flavoured_milk_ice_cream", "ketchup_sauces",
    }


@pytest.mark.parametrize(
    "tags, expected",
    [
        (["en:snacks", "en:salty-snacks", "en:crisps", "en:potato-crisps"], "chips"),
        (["en:snacks", "en:salty-snacks", "en:appetizers"], "namkeen"),
        (["en:snacks", "en:sweet-snacks", "en:biscuits", "en:chocolate-biscuits"], "biscuits"),
        (["en:snacks", "en:sweet-snacks", "en:chocolates", "en:milk-chocolates"], "chocolates"),
        (["en:beverages", "en:carbonated-drinks", "en:sodas", "en:energy-drinks"], "energy_drinks"),
        (["en:beverages", "en:carbonated-drinks", "en:sodas", "en:colas"], "soft_drinks"),
        (["en:fats", "en:vegetable-fats", "en:vegetable-oils", "en:sunflower-oils"], "edible_oils"),
        (["en:dairies", "en:frozen-desserts", "en:ice-creams"], "flavoured_milk_ice_cream"),
        (["en:groceries", "en:sauces", "en:ketchup"], "ketchup_sauces"),
        (["en:meals", "en:noodles", "en:instant-noodles"], "instant_noodles"),
        (["en:plant-based-foods", "en:fresh-vegetables"], None),
    ],
)
def test_classify_open_food_facts_tags(tags, expected):
    assert classify_off_tags(tags) == expected


@pytest.mark.parametrize(
    "category, name, expected",
    [
        ("namkeen", "Aloo Bhujia", "namkeen"),
        ("snacks", "Haldiram's Bhujia Sev", "namkeen"),
        ("instant noodles", "Maggi 2-Minute Masala", "instant_noodles"),
        ("cold drink", "Thums Up", "soft_drinks"),
        ("energy drink", "Sting", "energy_drinks"),
        ("chips", "Lay's Magic Masala", "chips"),
        ("biscuits", "Good Day Butter Cookies", "biscuits"),
        ("cooking oil", "Fortune Refined Sunflower Oil", "edible_oils"),
        ("chocolate", "Dairy Milk Silk", "chocolates"),
        (None, "Kissan Fresh Tomato Ketchup", "ketchup_sauces"),
        ("spices", "Everest Garam Masala", None),  # not a launch category
    ],
)
def test_classify_scanned_text(category, name, expected):
    assert classify_text(category, name) == expected


@pytest.mark.parametrize(
    "text, expected",
    [
        ("Lay's India's Magic Masala", {"masala"}),
        ("Lay's American Style Cream & Onion", {"cream_onion"}),
        ("Bingo Mad Angles Tomato Madness", {"tomato"}),
        ("Kurkure Chilli Chatka", {"chilli"}),
        ("Haldiram's Pudina Bhujia", {"mint"}),
        ("Good Day Cashew Cookies", {"nuts"}),
        ("Parle Hide & Seek Chocolate Chip", {"chocolate"}),
        ("Fortune Kachi Ghani Mustard Oil", {"mustard"}),
        ("Amul Kool Elaichi Milk", {"elaichi"}),
        ("Plain Rolled Oats", set()),
    ],
)
def test_flavour_tags(text, expected):
    assert set(flavours_of(text)) == expected
