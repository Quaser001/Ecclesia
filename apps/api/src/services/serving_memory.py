"""Serving sizes the user told us, remembered per product.

Many older scans have nutrition numbers but no serving size, so nobody knows
whether 6.8 g of sugar is per 100 ml or per can. CalFit does not guess: the
scan shows "Serving size unknown, check the pack", and the user can answer
two questions, how big one serving is and whether the label's numbers are
per 100 g/ml or per serving. That answer is stored for this product and used
on the next scan of it. Scores already given are never changed.
"""

from __future__ import annotations

from typing import Literal, Optional

from src.domain.models import NutritionInfo
from src.repositories.product_repository import _tokens
from src.services.nutrition_merge import _NUTRIENT_FIELDS

LabelBasis = Literal["per_100", "per_serving"]
MAX_SERVING = 5000.0  # g or ml; a 5 L can is the largest plausible serving


def product_key(brand: Optional[str], name: Optional[str]) -> Optional[str]:
    """Same product, same key: "Amul Lassi 200ml" and "amul lassi" match.

    Sizes, prices and filler words are dropped (see product_repository._tokens),
    so the remembered serving follows the product, not one pack's wording.
    """
    words = _tokens(brand) | _tokens(name)
    return " ".join(sorted(words)) or None


def has_values(n: NutritionInfo) -> bool:
    return any(getattr(n, f) is not None for f in _NUTRIENT_FIELDS)


def serving_unknown(n: NutritionInfo) -> bool:
    """Numbers without a basis: the case the "check the pack" note is for."""
    return n.serving_size_g is None and has_values(n)


def _scaled(n: NutritionInfo, factor: float, serving: float) -> NutritionInfo:
    update: dict[str, object] = {"serving_size_g": serving, "serving_size_source": "you"}
    for f in _NUTRIENT_FIELDS:
        v = getattr(n, f)
        if v is not None:
            update[f] = round(v * factor, 3)
    return n.model_copy(update=update)


def apply_serving(n: NutritionInfo, serving_g: float, basis: LabelBasis) -> NutritionInfo:
    """Put the label's numbers on the user's serving.

    - Basis unknown: the user's answer says what the numbers are.
    - Numbers per 100 g/ml (label column or database): scale to the serving.
    - The label printed its own serving size: the label wins, nothing changes.
    """
    if not has_values(n) or not (0 < serving_g <= MAX_SERVING):
        return n
    if n.serving_size_g is None:
        if basis == "per_serving":
            return n.model_copy(update={"serving_size_g": serving_g, "serving_size_source": "you"})
        return _scaled(n, serving_g / 100, serving_g)
    if n.serving_size_g == 100 and serving_g != 100:
        return _scaled(n, serving_g / 100, serving_g)
    return n
