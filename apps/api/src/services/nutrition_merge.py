"""Merge label nutrition with a local food-database reference row.

Label values follow the extraction contract: per serving, with
`serving_size_g` set (100 when the label only had a per-100 column).
Database rows are imported from Open Food Facts' `_100g` fields, so they are
per 100 g/ml. Copying them across unchanged mixes the two bases, and the
per-serving scoring rules then misjudge every enriched product (a 250 ml can
read as 100 ml).
"""

from __future__ import annotations

from src.domain.models import NutritionInfo

_NUTRIENT_FIELDS = (
    "calories_kcal",
    "total_fat_g",
    "saturated_fat_g",
    "trans_fat_g",
    "cholesterol_mg",
    "sodium_mg",
    "total_carbs_g",
    "dietary_fiber_g",
    "sugars_g",
    "added_sugars_g",
    "protein_g",
    "iron_mg",
    "vitamin_c_mg",
)


def merge_reference_nutrition(label: NutritionInfo, per_100: NutritionInfo) -> NutritionInfo:
    """Fill gaps in `label` from `per_100`, converted to the label's basis.

    - Label serving size known: database values are scaled by serving/100.
    - Serving size unknown and no label numbers: use the database values as
      they are and record the basis as 100 g/ml.
    - Serving size unknown but some label numbers: their basis is unknown, so
      nothing is filled; missing values stay missing rather than mixing bases.
    Values read from the label always win.
    """
    label_has_numbers = any(getattr(label, f) is not None for f in _NUTRIENT_FIELDS)

    if label.serving_size_g:
        serving, factor = label.serving_size_g, label.serving_size_g / 100
    elif not label_has_numbers:
        serving, factor = 100.0, 1.0
    else:
        return label

    update: dict[str, float | bool] = {"serving_size_g": serving}
    filled: set[str] = set()
    for field in _NUTRIENT_FIELDS:
        ref = getattr(per_100, field)
        if getattr(label, field) is None and ref is not None:
            update[field] = round(ref * factor, 3)
            filled.add(field)

    # A confidence flag can only come from the database for a value it supplied.
    update["sodium_confidence"] = label.sodium_confidence or (
        "sodium_mg" in filled and per_100.sodium_confidence
    )
    update["sugar_confidence"] = label.sugar_confidence or (
        "sugars_g" in filled and per_100.sugar_confidence
    )
    update["fat_confidence"] = label.fat_confidence or (
        "total_fat_g" in filled and per_100.fat_confidence
    )
    return label.model_copy(update=update)
