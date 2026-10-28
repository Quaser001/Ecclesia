"""Which real product is in a front-of-pack photo?

The model only reads the pack: brand, name, variant, pack size, price, and
how sure it is of the name (identity_confidence). Everything here is
deterministic, and the options shown to the user are always real products
from CalFit's food database or Open Food Facts, never names the model
suggested (AGENTS.md: real products only).

  - name not read, or read with low confidence -> RETAKE
  - no real product fits                        -> NOT_FOUND (or UNAVAILABLE
                                                   when the online lookup failed)
  - exactly one fits, name read confidently     -> CONFIDENT (go ahead, say which)
  - exactly one fits, name read less surely     -> CONFIRM ("Is this it?")
  - several fit                                 -> CHOOSE (top 3, user picks)

"Fits" means: same brand when a brand was read, at least one specific word of
the name in common, and, when the pack size was read and some candidates
list the same size, only those.
"""

from __future__ import annotations

import re
from typing import Optional

from src.domain.identity import Identification, IdStatus, ProductOption, Source
from src.domain.models import ProductObservation
from src.repositories.product_repository import FoodProduct, _tokens

# Name read clearly enough to go ahead without asking (one candidate only).
AUTO_CONFIDENCE = 0.8
# Below this the name reading isn't usable at all.
MIN_CONFIDENCE = 0.4
MAX_OPTIONS = 3

_QTY = re.compile(r"(\d+(?:[.,]\d+)?)\s*(ml|l|ltr|g|gm|gms|gram|grams|kg)\b", re.IGNORECASE)


def parse_quantity(text: Optional[str]) -> Optional[float]:
    """Pack size in g or ml ("200 ml" -> 200, "1 L" -> 1000), or None."""
    if not text:
        return None
    m = _QTY.search(text)
    if not m:
        return None
    value = float(m.group(1).replace(",", "."))
    unit = m.group(2).lower()
    return value * 1000 if unit in ("l", "ltr", "kg") else value


def _product_quantity(p: FoodProduct) -> Optional[float]:
    return parse_quantity(p.quantity) or parse_quantity(p.product_name)


def read_as(obs: ProductObservation) -> Optional[str]:
    """The pack as read, for messages: "Amul Lassi 200 ml"."""
    parts: list[str] = []
    name_has_brand = bool(obs.brand and obs.product_name
                          and _tokens(obs.brand) <= _tokens(obs.product_name))
    if name_has_brand:
        parts.append(obs.product_name)  # "Amul Lassi", not "Amul Amul Lassi"
    else:
        parts += [p for p in (obs.brand, obs.product_name) if p]
    if obs.variant and not _tokens(obs.variant) <= _tokens(" ".join(parts)):
        parts.append(obs.variant)
    if obs.net_quantity:
        parts.append(obs.net_quantity)
    text = " ".join(" ".join(parts).split())
    return text or None


def search_query(obs: ProductObservation) -> str:
    """One online search per scan: brand, name and variant, without sizes."""
    words: list[str] = []
    for part in (obs.brand, obs.product_name, obs.variant):
        for w in (part or "").split():
            if w.lower() not in (x.lower() for x in words) and not _QTY.fullmatch(w):
                words.append(w)
    return " ".join(words)


def rank(obs: ProductObservation,
         candidates: list[tuple[FoodProduct, Source]]) -> list[tuple[FoodProduct, Source]]:
    """Real products that fit what was read, best first, duplicates removed."""
    label_brand = _tokens(obs.brand)
    label_words = _tokens(obs.product_name) | _tokens(obs.variant) | label_brand
    label_specific = label_words - label_brand
    wanted_qty = parse_quantity(obs.net_quantity)

    scored: list[tuple[float, FoodProduct, Source]] = []
    seen: set[str] = set()
    for product, source in candidates:
        if product.code in seen:
            continue
        p_brand = _tokens(product.brand)
        p_name = _tokens(product.product_name)
        if label_brand and not (label_brand & (p_brand | p_name)):
            continue  # a brand was read and this product isn't that brand
        p_specific = p_name - p_brand - label_brand
        if label_specific and not (p_specific & label_specific):
            continue  # nothing specific in common ("lassi")
        shared = len(label_words & (p_name | p_brand))
        extra = len(p_specific - label_words)  # words the pack didn't show
        score = shared - 0.5 * extra
        seen.add(product.code)
        scored.append((score, product, source))

    if wanted_qty is not None:
        same_size = [s for s in scored
                     if (q := _product_quantity(s[1])) is not None and abs(q - wanted_qty) < 0.5]
        if same_size:
            scored = same_size

    scored.sort(key=lambda s: s[0], reverse=True)
    return [(p, src) for _, p, src in scored]


def _option(p: FoodProduct, source: Source) -> ProductOption:
    return ProductOption(code=p.code, source=source, name=p.product_name, brand=p.brand,
                         quantity=p.quantity, image_url=p.image_url)


def decide(obs: ProductObservation,
           ranked: list[tuple[FoodProduct, Source]],
           lookup_failed: bool = False) -> Identification:
    reading = read_as(obs)
    conf = obs.identity_confidence
    if not obs.product_name or (conf is not None and conf < MIN_CONFIDENCE):
        return Identification(status=IdStatus.RETAKE, read_as=reading)
    if not ranked:
        status = IdStatus.UNAVAILABLE if lookup_failed else IdStatus.NOT_FOUND
        return Identification(status=status, read_as=reading)
    options = [_option(p, src) for p, src in ranked[:MAX_OPTIONS]]
    if len(ranked) == 1:
        if conf is None or conf >= AUTO_CONFIDENCE:
            return Identification(status=IdStatus.CONFIDENT, read_as=reading,
                                  options=options, chosen=options[0])
        return Identification(status=IdStatus.CONFIRM, read_as=reading, options=options)
    return Identification(status=IdStatus.CHOOSE, read_as=reading, options=options)


def observation_from_product(
    product: FoodProduct, source: Source, label: Optional[ProductObservation] = None
) -> ProductObservation:
    """The scan's product from a database record, keeping what the pack showed.

    Database nutrition is per 100 g/ml, so serving_size_g is 100. The pack's
    own claims, allergen statements and price are kept; ingredients and
    allergens come from the record when it has them, else from the pack.
    """
    label = label or ProductObservation()
    category = label.category or (product.categories[-1] if product.categories else None)
    return ProductObservation(
        brand=product.brand or label.brand,
        product_name=product.product_name,
        category=category,
        variant=label.variant,
        net_quantity=label.net_quantity or product.quantity,
        mrp=label.mrp,
        identity_confidence=label.identity_confidence,
        ingredients=product.ingredients or label.ingredients,
        nutrition=product.nutrition.model_copy(update={"serving_size_g": 100.0}),
        allergens_declared=product.allergens or label.allergens_declared,
        may_contain=label.may_contain,
        visible_claims=label.visible_claims,
        extraction_confidence=product.data_confidence,
        data_source=source,
        source_code=product.code,
        source_date=product.imported_at,
    )


_MESSAGES = {
    IdStatus.RETAKE: (
        "We couldn't make out which product this is. Retake the photo with the "
        "product name clearly in view, or photograph the back of the pack."
    ),
    IdStatus.NOT_FOUND: (
        "We read “{read}” but couldn't find its ingredients or nutrition in our "
        "database or on Open Food Facts. Photograph the back of the pack with the "
        "ingredients and nutrition table."
    ),
    IdStatus.UNAVAILABLE: (
        "We read “{read}” but couldn't reach the online product database just now. "
        "Try again in a minute, or photograph the back of the pack."
    ),
    IdStatus.CONFIRM: "Please confirm the product so we can check it for you.",
    IdStatus.CHOOSE: "Please pick the product so we can check it for you.",
}


def message_for(ident: Identification) -> Optional[str]:
    template = _MESSAGES.get(ident.status)
    return template.format(read=ident.read_as or "the product") if template else None
