"""match_product must only return a product it can stand behind.

A match fills in nutrition, ingredients and allergens the photo did not show,
so a wrong match is fabricated data. The old matcher accepted any single shared
word: "Milky bar" by Nestle matched "Nestlé dessert Noir" (dark chocolate) and
an unnamed Nestlé biscuit matched Oreo through the word "biscuits".
"""

from __future__ import annotations

import pytest

from src.domain.models import NutritionInfo
from src.repositories.product_repository import FoodProduct, ProductRepository

_ROWS = [
    ("8902080000227", "Sting Energy", "Sting", ["energy drinks"]),
    ("8901262200011", "Amul Lassi 200ml", "Amul", ["dairy drinks"]),
    ("8901063010000", "Good Day Butter Cookies", "Britannia", ["biscuits"]),
    ("7613035040823", "Nestlé dessert Noir", "Nestlé, NESTLE DESSERT, Tablettes", ["chocolate"]),
    ("7622201756697", "Oreo", "Cadbury", ["biscuits"]),
    ("8901491101000", "kurkure", "kurkure", ["snacks"]),
    ("8901058000000", "KitKat win gold", "Nestlé", ["chocolate"]),
]


@pytest.fixture
def repo(tmp_path):
    r = ProductRepository(str(tmp_path / "food.db"))
    for code, name, brand, cats in _ROWS:
        r.save_product(FoodProduct(code=code, product_name=name, brand=brand, categories=cats,
                                   nutrition=NutritionInfo(sugars_g=1.0)))
    return r


def _code(repo, name, brand, category=None):
    m = repo.match_product(name=name, brand=brand, category=category)
    return m.code if m else None


@pytest.mark.parametrize(
    "name, brand, expected",
    [
        ("Sting Energy Drink", "Sting", "8902080000227"),
        ("Amul Lassi 200ml", "Amul", "8901262200011"),
        ("Good Day Butter Cookies", "Britannia", "8901063010000"),
        ("KitKat Win Gold", "Nestle", "8901058000000"),  # accents folded
    ],
)
def test_specific_names_match(repo, name, brand, expected):
    assert _code(repo, name, brand) == expected


@pytest.mark.parametrize(
    "name, brand, category",
    [
        ("Milky bar", "Nestle", "chocolate"),            # brand-only overlap
        (None, "Nestlé", "biscuits"),                    # no name: category-only overlap
        ("Good Day Chocochip Cookies", "Britannia", "biscuits"),  # other variant
        ("Good Day Cashew Almond", "Britannia", "biscuits"),
        ("Masala Munch", "Kurkure, Pepsi", "snacks"),    # row name is just the brand
        ("STING", "Sting", "energy drink"),              # label name is just the brand
        ("KitKat", "Nestle", "chocolate"),               # one word against a variant
        ("Sting Energy", "Red Bull", "energy drink"),    # brands disagree
    ],
)
def test_loose_matches_are_rejected(repo, name, brand, category):
    assert _code(repo, name, brand, category) is None
