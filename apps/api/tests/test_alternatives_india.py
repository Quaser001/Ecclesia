"""Alternatives: real products from the same category, similar taste, without
the thing that was flagged, and a better fit for this user."""

from __future__ import annotations

from src.domain.models import (
    HealthCondition,
    NutritionInfo,
    ProductObservation,
    UserProfile,
)
from src.domain.scoring_rules import calculate_score
from src.repositories.product_repository import FoodProduct
from src.services.alternative_service import AlternativeService


def _food(code, name, sodium, satfat=3.0, ingredients=(), allergens=(), brand="B"):
    return FoodProduct(
        code=code, product_name=name, brand=brand, categories=["namkeen"],
        ingredients=list(ingredients), allergens=list(allergens),
        nutrition=NutritionInfo(calories_kcal=500, total_fat_g=30, saturated_fat_g=satfat,
                                sugars_g=2, sodium_mg=sodium, protein_g=12),
        calfit_category="namkeen",
    )


class _Repo:
    def __init__(self, products):
        self.products = products

    def find_by_calfit_category(self, key, limit=300):
        return [p for p in self.products if p.calfit_category == key]


HYPERTENSIVE = UserProfile(user_id="u", health_conditions=[HealthCondition.HYPERTENSION])

# Scanned per 30 g serving: 258 mg sodium = 860 mg per 100 g.
SCANNED = ProductObservation(
    product_name="Masala Bhujia", brand="Haldiram's", category="namkeen",
    ingredients=["gram flour", "palmolein", "salt"],
    nutrition=NutritionInfo(serving_size_g=30, calories_kcal=176, total_fat_g=12,
                            saturated_fat_g=1.0, sugars_g=0.5, sodium_mg=258, protein_g=3.5),
    extraction_confidence=0.9,
)


def _find(products, profile=HYPERTENSIVE, product=SCANNED):
    score = calculate_score(product, profile)
    return AlternativeService().find(product, profile, score, product_repo=_Repo(products))


def test_suggests_a_less_salty_namkeen_from_the_database():
    alts = _find([_food("1", "Plain Moong Dal", sodium=300)])
    assert [a.name for a in alts] == ["Plain Moong Dal"]
    assert alts[0].type == "product" and alts[0].verified
    assert "65% less sodium" in alts[0].reason  # 300 vs 860 per 100 g
    assert "Namkeen" in alts[0].reason


def test_never_suggests_something_worse_on_the_flagged_nutrient():
    alts = _find([_food("1", "Pudina Bhujia", sodium=900), _food("2", "Sev", sodium=820)])
    assert all(a.type != "product" for a in alts)  # falls back to shopping guidance


def test_similar_flavour_ranks_first():
    alts = _find([
        _food("1", "Plain Moong Dal", sodium=250),
        _food("2", "Masala Chana Dal", sodium=450),
    ])
    assert [a.name for a in alts][:2] == ["Masala Chana Dal", "Plain Moong Dal"]
    assert "masala" in alts[0].reason.lower()


def test_skips_the_same_product_and_the_users_allergens():
    profile = UserProfile(user_id="u", health_conditions=[HealthCondition.HYPERTENSION],
                          allergies=["peanut"])
    alts = _find([
        _food("1", "Masala Bhujia", sodium=200, brand="Haldiram's"),  # same product
        _food("2", "Peanut Chikki Namkeen", sodium=200, ingredients=["peanuts"],
              allergens=["peanuts"]),
        _food("3", "Corn Flakes Mixture", sodium=300,
              ingredients=["corn flakes", "gram flour", "salt"]),
        _food("4", "Navratan Mixture", sodium=300),  # no ingredient list: can't check allergens
    ], profile=profile)
    assert [a.name for a in alts] == ["Corn Flakes Mixture"]


def test_only_the_same_category_is_searched():
    chips = _food("9", "Lay's Classic Salted", sodium=100)
    chips = chips.model_copy(update={"calfit_category": "chips"})
    alts = _find([chips])
    assert all(a.type != "product" for a in alts)


def test_unknown_category_falls_back_to_guidance():
    other = SCANNED.model_copy(update={"category": "spices", "product_name": "Garam Masala"})
    alts = _find([_food("1", "Plain Moong Dal", sodium=300)], product=other)
    assert all(a.type != "product" for a in alts)
