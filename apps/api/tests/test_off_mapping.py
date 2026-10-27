"""Mapping an Open Food Facts record into the CalFit food database."""

from __future__ import annotations

from src.repositories.off_mapping import map_off_product

BASE = {
    "code": "8901491101837",
    "product_name": "Aloo Bhujia",
    "brands": ["Haldiram's"],
    "countries_tags": ["en:india"],
    "categories_tags": ["en:snacks", "en:salty-snacks", "en:namkeen"],
    "ingredients_text": "Gram flour, edible vegetable oil (palmolein), potato, salt, spices",
    "allergens_tags": ["en:gluten"],
    "nutriments": {
        "energy-kcal_100g": 586, "fat_100g": 40.1, "saturated-fat_100g": 15.8,
        "carbohydrates_100g": 43.2, "sugars_100g": 1.5, "proteins_100g": 11.6,
        "sodium_100g": 0.86, "fiber_100g": 4.2,
    },
}


def test_maps_per_100g_values_and_converts_sodium_grams_to_mg():
    p = map_off_product(BASE, imported_at="2026-10-28")
    assert p is not None
    assert p.nutrition.sodium_mg == 860  # OFF stores sodium per 100 g in grams
    assert p.nutrition.calories_kcal == 586
    assert p.nutrition.saturated_fat_g == 15.8
    assert p.nutrition.dietary_fiber_g == 4.2


def test_sodium_derived_from_salt_when_missing():
    hit = {**BASE, "nutriments": {**BASE["nutriments"], "sodium_100g": None, "salt_100g": 2.0}}
    assert map_off_product(hit, imported_at="2026-10-28").nutrition.sodium_mg == 800


def test_category_flavour_and_provenance():
    p = map_off_product({**BASE, "product_name": "Pudina Bhujia"}, imported_at="2026-10-28")
    assert p.calfit_category == "namkeen"
    assert p.flavours == ["mint"]
    assert p.source == "open_food_facts"
    assert p.imported_at == "2026-10-28"
    assert p.brand == "Haldiram's"
    assert p.allergens == ["gluten"]


def test_skips_products_without_the_core_nutrients():
    for missing in ("energy-kcal_100g", "sugars_100g", "fat_100g"):
        nutr = {k: v for k, v in BASE["nutriments"].items() if k != missing}
        assert map_off_product({**BASE, "nutriments": nutr}, imported_at="d") is None
    no_salt = {k: v for k, v in BASE["nutriments"].items() if k != "sodium_100g"}
    assert map_off_product({**BASE, "nutriments": no_salt}, imported_at="d") is None


def test_skips_non_indian_unnamed_or_unclassifiable_products():
    assert map_off_product({**BASE, "countries_tags": ["en:france"]}, imported_at="d") is None
    assert map_off_product({**BASE, "product_name": "  "}, imported_at="d") is None
    assert map_off_product({**BASE, "categories_tags": ["en:spices"]}, imported_at="d") is None


def test_never_falls_back_to_per_serving_values():
    nutr = {**BASE["nutriments"]}
    del nutr["sugars_100g"]
    nutr["sugars_serving"] = 3.0
    nutr["sugars"] = 3.0  # unsuffixed: may be per serving
    assert map_off_product({**BASE, "nutriments": nutr}, imported_at="d") is None


def test_ingredients_come_from_tags_when_the_text_is_missing():
    hit = {**BASE, "ingredients_text": None,
           "ingredients_tags": ["en:gram-flour", "en:palm-oil", "en:salt", "hi:masala"]}
    p = map_off_product(hit, imported_at="d")
    assert p.ingredients == ["gram flour", "palm oil", "salt", "masala"]


def test_physically_impossible_values_skip_the_product():
    """Open Food Facts is crowd-sourced; e.g. one Indian snack lists 738 g of
    sodium per 100 g. Pure salt is about 39 g sodium per 100 g."""
    bad = [
        {"sodium_100g": 738.4},
        {"sugars_100g": 140},
        {"fat_100g": 101},
        {"energy-kcal_100g": 1200},
        {"saturated-fat_100g": 45.0},  # more saturated fat than total fat (40.1)
    ]
    for patch in bad:
        hit = {**BASE, "nutriments": {**BASE["nutriments"], **patch}}
        assert map_off_product(hit, imported_at="d") is None, patch


def test_zero_sodium_in_an_inherently_salty_category_is_bad_data():
    hit = {**BASE, "nutriments": {**BASE["nutriments"], "sodium_100g": 0}}
    assert map_off_product(hit, imported_at="d") is None  # namkeen with no salt
    cola = {**BASE, "product_name": "Cola", "categories_tags": ["en:beverages", "en:sodas"],
            "nutriments": {**BASE["nutriments"], "sodium_100g": 0}}
    assert map_off_product(cola, imported_at="d") is not None  # plausible for a drink


def test_confidence_is_lower_without_ingredients():
    full = map_off_product(BASE, imported_at="d")
    bare = map_off_product({**BASE, "ingredients_text": ""}, imported_at="d")
    assert full.data_confidence > bare.data_confidence
