"""Are the nutrition numbers read off a label physically possible?

Gemini transcribes the label; it can misread a digit, a column or a unit
(kJ for kcal, a "per 100 g" column under a 30 g serving). Pydantic accepts any
float, and the rules would then score the misread label with confidence. This
module catches what can be caught without guessing (AGENTS.md: unknown stays
unknown):

* A value that is impossible on its own (negative, or absurdly large for any
  food) is dropped: that one field becomes unknown.
* Numbers that are each possible but contradict each other (sugars above
  total carbs, macros heavier than the serving, energy far from
  4·protein + 4·carbs + 9·fat) mean we can't tell which one is wrong, so the
  whole read is unreliable and the scan is "insufficient data".

Tolerances are generous on purpose: labels round, fibre and polyols carry
less energy, and a liquid's ml isn't exactly its grams. Refusing a good label
costs a retake; scoring a bad one can mislead someone with a condition.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from src.domain.models import NutritionInfo

# Gram fields that are parts of the serving's mass.
_MASS_G = ("total_fat_g", "saturated_fat_g", "trans_fat_g", "total_carbs_g",
           "dietary_fiber_g", "sugars_g", "added_sugars_g", "protein_g")
_ALL = _MASS_G + ("calories_kcal", "cholesterol_mg", "sodium_mg", "iron_mg", "vitamin_c_mg",
                  "serving_size_g")

# Above these no single serving of any food goes (a 5 L can at the top end).
_ABSOLUTE_MAX = {
    "serving_size_g": 5000.0,
    "calories_kcal": 5000.0,
    "cholesterol_mg": 5000.0,
    "sodium_mg": 50_000.0,
    "iron_mg": 500.0,
    "vitamin_c_mg": 10_000.0,
    **{f: 5000.0 for f in _MASS_G},
}

_CONFIDENCE_FLAG = {"sodium_mg": "sodium_confidence", "sugars_g": "sugar_confidence",
                    "total_fat_g": "fat_confidence"}

# Part of a whole may exceed it by rounding only.
_PART_SLACK_RATIO, _PART_SLACK_G = 1.05, 0.5
# ml are not grams; syrups are denser than water.
_MASS_SLACK_RATIO, _MASS_SLACK_G = 1.10, 1.0
# Pure fat is 9 kcal/g; anything denser is a misread (often kJ in kcal).
_MAX_KCAL_PER_G = 9.5
# Pure salt is ~39 % sodium.
_MAX_SODIUM_MG_PER_G = 400.0
# Energy vs 4P + 4C + 9F: outside this ratio AND this many kcal apart.
_ENERGY_RATIO = (0.6, 1.5)
_ENERGY_MIN_GAP_KCAL = 30.0


@dataclass
class PlausibilityResult:
    nutrition: NutritionInfo
    dropped: list[str] = field(default_factory=list)  # fields made unknown
    contradictions: list[str] = field(default_factory=list)  # → insufficient data

    @property
    def reliable(self) -> bool:
        return not self.contradictions


def check_nutrition(n: NutritionInfo) -> PlausibilityResult:
    values = {f: getattr(n, f) for f in _ALL}
    dropped: list[str] = []
    for f, v in values.items():
        if v is not None and (v < 0 or v > _ABSOLUTE_MAX[f] or v != v):  # v != v: NaN
            values[f] = None
            dropped.append(f)
    if values["serving_size_g"] == 0:
        values["serving_size_g"] = None
        dropped.append("serving_size_g")

    contradictions: list[str] = []

    def part_of(part: str, whole: str) -> None:
        p, w = values[part], values[whole]
        if p is not None and w is not None and p > w * _PART_SLACK_RATIO + _PART_SLACK_G:
            contradictions.append(f"{part} > {whole}")

    part_of("saturated_fat_g", "total_fat_g")
    part_of("trans_fat_g", "total_fat_g")
    part_of("sugars_g", "total_carbs_g")
    part_of("added_sugars_g", "sugars_g")
    part_of("added_sugars_g", "total_carbs_g")
    sat, trans, fat = values["saturated_fat_g"], values["trans_fat_g"], values["total_fat_g"]
    if sat is not None and trans is not None and fat is not None \
            and sat + trans > fat * _PART_SLACK_RATIO + _PART_SLACK_G:
        contradictions.append("saturated + trans fat > total fat")

    serving = values["serving_size_g"]
    if serving is not None:
        macros = [values[f] for f in ("total_fat_g", "total_carbs_g", "protein_g")]
        known = sum(m for m in macros if m is not None)
        if known > serving * _MASS_SLACK_RATIO + _MASS_SLACK_G:
            contradictions.append("fat + carbs + protein weigh more than the serving")
        kcal = values["calories_kcal"]
        if kcal is not None and kcal > serving * _MAX_KCAL_PER_G + 5:
            contradictions.append("more energy than the serving's mass can hold")
        sodium = values["sodium_mg"]
        if sodium is not None and sodium > serving * _MAX_SODIUM_MG_PER_G:
            contradictions.append("more sodium than the serving's mass can hold")

    kcal = values["calories_kcal"]
    fat, carbs, protein = values["total_fat_g"], values["total_carbs_g"], values["protein_g"]
    if None not in (kcal, fat, carbs, protein):
        expected = 4 * protein + 4 * carbs + 9 * fat
        low, high = _ENERGY_RATIO
        if abs(kcal - expected) > _ENERGY_MIN_GAP_KCAL and not (low * expected <= kcal <= high * expected):
            contradictions.append("energy doesn't match 4·protein + 4·carbs + 9·fat")

    update: dict[str, object] = {f: values[f] for f in dropped}
    for f, flag in _CONFIDENCE_FLAG.items():
        if f in dropped:
            update[flag] = False  # a value we threw away was not "clearly read"
    cleaned = n.model_copy(update=update) if update else n
    return PlausibilityResult(nutrition=cleaned, dropped=dropped, contradictions=contradictions)
