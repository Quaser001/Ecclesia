"""Low / medium / high levels for fat, saturates, sugars and salt.

These are facts about the product per 100 g (or 100 ml for drinks), the same
for everyone. The personal verdict still comes from the scoring rules.

Thresholds are the UK Food Standards Agency front-of-pack guidance (2016),
which Open Food Facts also uses for its nutrient levels, so a scan and the
alternatives imported from Open Food Facts are judged alike. India has no
final front-of-pack standard yet; swap the tables here if FSSAI publishes one.

Label values are per serving (`serving_size_g`; 100 when the label only had a
per-100 column), so they are rescaled to per 100. If the serving size is
unknown, nothing is shown rather than guessing the basis.
"""

from __future__ import annotations

from enum import Enum
from typing import Literal, Optional

from pydantic import BaseModel

from src.domain.food_taxonomy import _has_word, _norm, classify_text

Nutrient = Literal["fat", "saturated_fat", "sugars", "salt"]


class Level(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class NutrientLevel(BaseModel):
    nutrient: Nutrient
    per_100: float
    unit: Literal["g"] = "g"
    basis: Literal["100g", "100ml"]
    level: Level


# (low at or below, high above) per 100 g / 100 ml.
_FOOD: dict[Nutrient, tuple[float, float]] = {
    "fat": (3.0, 17.5),
    "saturated_fat": (1.5, 5.0),
    "sugars": (5.0, 22.5),
    "salt": (0.3, 1.5),
}
_DRINK: dict[Nutrient, tuple[float, float]] = {
    "fat": (1.5, 8.75),
    "saturated_fat": (0.75, 2.5),
    "sugars": (2.5, 11.25),
    "salt": (0.3, 0.75),
}

_DRINK_CATEGORIES = {"energy_drinks", "soft_drinks", "fruit_juices"}
_MILK_DRINK_WORDS = ("milk", "milkshake", "shake", "lassi", "buttermilk", "chaas", "chaach",
                     "chhach", "mattha", "coffee", "drink", "smoothie")
_FROZEN_WORDS = ("ice cream", "icecream", "kulfi", "frozen", "cone", "sundae")


def is_drink(category: Optional[str], name: Optional[str]) -> bool:
    """Drinks use the per-100 ml table. Flavoured milk counts; ice cream doesn't."""
    calfit = classify_text(category, name)
    if calfit in _DRINK_CATEGORIES:
        return True
    if calfit == "flavoured_milk_ice_cream":
        text = f"{_norm(category)} {_norm(name)}"
        if any(_has_word(text, w) for w in _FROZEN_WORDS):
            return False
        return any(_has_word(text, w) for w in _MILK_DRINK_WORDS)
    return False


def _level(value: float, low_max: float, high_above: float) -> Level:
    if value <= low_max:
        return Level.LOW
    if value <= high_above:
        return Level.MEDIUM
    return Level.HIGH


def nutrient_levels(
    *,
    serving_size_g: Optional[float],
    fat_g: Optional[float],
    saturated_fat_g: Optional[float],
    sugars_g: Optional[float],
    sodium_mg: Optional[float],
    category: Optional[str],
    name: Optional[str],
) -> list[NutrientLevel]:
    """Levels for the nutrients the label states. Missing values are left out."""
    if not serving_size_g or serving_size_g <= 0:
        return []
    drink = is_drink(category, name)
    table = _DRINK if drink else _FOOD
    basis: Literal["100g", "100ml"] = "100ml" if drink else "100g"
    factor = 100.0 / serving_size_g
    salt_g = sodium_mg * 2.5 / 1000 if sodium_mg is not None else None
    values: dict[Nutrient, Optional[float]] = {
        "fat": fat_g,
        "saturated_fat": saturated_fat_g,
        "sugars": sugars_g,
        "salt": salt_g,
    }
    out: list[NutrientLevel] = []
    for nutrient, value in values.items():
        if value is None or value < 0:
            continue
        per_100 = value * factor
        low_max, high_above = table[nutrient]
        out.append(NutrientLevel(
            nutrient=nutrient,
            per_100=round(per_100, 2 if nutrient == "salt" else 1),
            basis=basis,
            level=_level(per_100, low_max, high_above),
        ))
    return out
