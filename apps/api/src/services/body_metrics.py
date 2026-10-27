"""Body measurements: BMI and its band. Pure arithmetic, no guessing.

BMI bands use the cut-offs recommended for Asian Indians, which are lower
than the WHO global ones because body-fat-related risk starts at a lower BMI:
under 18.5 underweight, 18.5-22.9 normal, 23-24.9 overweight, 25 and above
obese. Source: Misra A. et al., "Consensus statement for diagnosis of
obesity, abdominal obesity and the metabolic syndrome for Asian Indians",
JAPI 2009; WHO expert consultation, Lancet 2004.
"""

from __future__ import annotations

from typing import Literal

BmiCategory = Literal["underweight", "normal", "overweight", "obese"]


def bmi(height_cm: float | None, weight_kg: float | None) -> float | None:
    """BMI to one decimal, or None when either measurement is missing."""
    if not height_cm or not weight_kg:
        return None
    metres = height_cm / 100
    return round(weight_kg / (metres * metres), 1)


def bmi_category(value: float | None) -> BmiCategory | None:
    if value is None:
        return None
    if value < 18.5:
        return "underweight"
    if value < 23:
        return "normal"
    if value < 25:
        return "overweight"
    return "obese"
