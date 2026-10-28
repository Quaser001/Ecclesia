"""Turn one Open Food Facts record into a CalFit food-database product.

Rules (AGENTS.md: provenance kept, missing data stays missing):
- Only products sold in India (`countries_tags` contains `en:india`).
- Only per-100 g/ml values (`*_100g`). Unsuffixed nutriment keys can be per
  serving, so they are never used.
- Sodium and cholesterol are stored per 100 g in **grams** by Open Food
  Facts; CalFit stores milligrams, so they are multiplied by 1000. When
  sodium is missing it is derived from salt (sodium = salt / 2.5).
- A product needs energy, sugars, fat and sodium (or salt) to be useful for
  scoring and comparison; anything less is skipped, not half-filled.
- Every product must fall into a CalFit category (food_taxonomy).
- Physically impossible values (more than 100 g of anything per 100 g, more
  than 900 kcal, more sodium than pure salt, more saturated than total fat)
  mean the record is wrong, so the product is skipped.
- Ingredients come from the label text when present, otherwise from
  `ingredients_tags` (the search service returns only the tags).
"""

from __future__ import annotations

import re
from typing import Any

from src.domain.food_taxonomy import classify_off_tags, classify_text, flavours_of
from src.domain.models import NutritionInfo
from src.repositories.product_repository import FoodProduct

_CORE = ("energy-kcal_100g", "sugars_100g", "fat_100g")
_GRAM_FIELDS = ("fat_100g", "saturated-fat_100g", "trans-fat_100g", "carbohydrates_100g",
                "sugars_100g", "fiber_100g", "proteins_100g", "salt_100g")
MAX_KCAL_100G = 900  # pure fat is ~900 kcal per 100 g
MAX_SODIUM_G_100G = 39.4  # pure salt
# Categories where salt is part of the recipe, so zero sodium is an error.
_SALTY_CATEGORIES = {"chips", "namkeen", "instant_noodles", "ketchup_sauces"}


def _implausible(n: dict[str, Any]) -> bool:
    if any((_num(n, k) or 0) > 100 for k in _GRAM_FIELDS):
        return True
    if (_num(n, "energy-kcal_100g") or 0) > MAX_KCAL_100G:
        return True
    if (_num(n, "sodium_100g") or 0) > MAX_SODIUM_G_100G:
        return True
    fat, sat = _num(n, "fat_100g"), _num(n, "saturated-fat_100g")
    return fat is not None and sat is not None and sat > fat + 0.5


def _num(nutriments: dict[str, Any], key: str) -> float | None:
    value = nutriments.get(key)
    try:
        f = float(value)
    except (TypeError, ValueError):
        return None
    return f if f >= 0 else None


def _ingredients(text: str) -> list[str]:
    parts = re.split(r"[,;\n]", text.replace("(", ",").replace(")", ","))
    cleaned = [p.strip(" .*-•:") for p in parts]
    return [p for p in cleaned if 1 < len(p) < 80][:40]


def map_off_product(
    hit: dict[str, Any],
    imported_at: str,
    *,
    for_lookup: bool = False,
) -> FoodProduct | None:
    """Map one Open Food Facts record, or None when it isn't usable.

    `for_lookup` is the live search for a scanned product: it keeps products
    outside CalFit's categories and without sodium (the scan can still be
    scored on what is known) and doesn't insist on India in `countries_tags`,
    which is often missing. The import into food.db keeps the strict rules.
    """
    if not for_lookup and "en:india" not in (hit.get("countries_tags") or []):
        return None
    name = (hit.get("product_name_en") or hit.get("product_name") or "").strip()
    if not name:
        return None
    category = classify_off_tags(hit.get("categories_tags"))
    if category is None and not for_lookup:
        return None

    n = hit.get("nutriments") or {}
    if any(_num(n, k) is None for k in _CORE) or _implausible(n):
        return None
    sodium_g = _num(n, "sodium_100g")
    if sodium_g is None and _num(n, "salt_100g") is not None:
        sodium_g = _num(n, "salt_100g") / 2.5
    if sodium_g is None and not for_lookup:
        return None
    if sodium_g == 0 and category in _SALTY_CATEGORIES:
        return None  # e.g. masala noodles listed with no sodium: a data-entry error
    cholesterol_g = _num(n, "cholesterol_100g")

    nutrition = NutritionInfo(
        calories_kcal=_num(n, "energy-kcal_100g"),
        total_fat_g=_num(n, "fat_100g"),
        saturated_fat_g=_num(n, "saturated-fat_100g"),
        trans_fat_g=_num(n, "trans-fat_100g"),
        cholesterol_mg=round(cholesterol_g * 1000, 1) if cholesterol_g is not None else None,
        sodium_mg=round(sodium_g * 1000, 1) if sodium_g is not None else None,
        total_carbs_g=_num(n, "carbohydrates_100g"),
        dietary_fiber_g=_num(n, "fiber_100g"),
        sugars_g=_num(n, "sugars_100g"),
        added_sugars_g=_num(n, "added-sugars_100g"),
        protein_g=_num(n, "proteins_100g"),
        sodium_confidence=sodium_g is not None,
        sugar_confidence=True,
        fat_confidence=True,
    )

    brands = hit.get("brands")
    if isinstance(brands, list):
        brand = brands[0].strip() if brands else None
    else:
        brand = (brands or "").split(",")[0].strip() or None

    ingredients_text = (hit.get("ingredients_text_en") or hit.get("ingredients_text") or "").strip()
    if ingredients_text:
        ingredients = _ingredients(ingredients_text)
    else:
        ingredients = [t.split(":", 1)[-1].replace("-", " ")
                       for t in hit.get("ingredients_tags") or []][:40]
    allergens = [t.split(":", 1)[-1] for t in hit.get("allergens_tags") or []]

    return FoodProduct(
        code=str(hit["code"]),
        product_name=name,
        brand=brand,
        categories=[t.split(":", 1)[-1].replace("-", " ") for t in hit.get("categories_tags") or []],
        ingredients_text=ingredients_text or None,
        ingredients=ingredients,
        nutrition=nutrition,
        serving_size=hit.get("serving_size"),
        quantity=(hit.get("quantity") or None),
        allergens=allergens,
        image_url=hit.get("image_front_small_url") or hit.get("image_small_url"),
        source="open_food_facts",
        data_confidence=0.9 if ingredients else 0.75,
        calfit_category=category or classify_text(
            " ".join(hit.get("categories_tags") or []).replace("en:", " ").replace("-", " "), name),
        flavours=flavours_of(name),
        imported_at=imported_at,
    )
