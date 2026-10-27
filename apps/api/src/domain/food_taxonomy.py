"""CalFit's India-first food categories and flavour tags.

Alternatives must come from the same category and, ideally, taste alike, so
every product in the food database and every scanned product is placed in
one CalFit category and given flavour tags. All rules here are keyword and
tag lookups; nothing is inferred by a model.

Categories are matched from Open Food Facts category tags (for imported
products) or from the scanned label's category and name (for scans). Order
matters: more specific categories are checked first, so chocolate biscuits
are biscuits and energy drinks are not plain soft drinks.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass


@dataclass(frozen=True)
class Category:
    key: str
    label: str
    off_tags: tuple[str, ...]  # Open Food Facts tags that place a product here
    keywords: tuple[str, ...]  # words in a scanned label's category or name


# Checked in this order.
_ORDERED = (
    Category("energy_drinks", "Energy drinks",
             ("en:energy-drinks",),
             ("energy drink", "red bull", "sting", "monster", "hell energy")),
    Category("flavoured_milk_ice_cream", "Flavoured milk & ice cream",
             ("en:ice-creams", "en:frozen-desserts", "en:flavoured-milks", "en:milkshakes"),
             ("ice cream", "icecream", "kulfi", "frozen dessert", "flavoured milk",
              "flavored milk", "milkshake", "milk shake", "kool", "cold coffee")),
    Category("biscuits", "Biscuits & cookies",
             ("en:biscuits", "en:sweet-biscuits", "en:cookies", "en:crackers"),
             ("biscuit", "cookie", "cracker", "rusk", "marie", "digestive")),
    Category("chocolates", "Chocolates",
             ("en:chocolates", "en:milk-chocolates", "en:dark-chocolates",
              "en:chocolate-candies", "en:filled-chocolates"),
             ("chocolate", "dairy milk", "kitkat", "kit kat", "5 star", "munch", "perk",
              "silk", "galaxy", "snickers")),
    Category("chips", "Chips & crisps",
             ("en:crisps", "en:chips-and-fries", "en:potato-crisps", "en:corn-chips",
              "en:tortilla-chips"),
             ("chips", "crisps", "wafers", "nachos", "kurkure", "puffs", "mad angles")),
    Category("namkeen", "Namkeen & bhujia",
             ("en:namkeen", "en:indian-snacks", "en:salty-snacks", "en:appetizers"),
             ("namkeen", "bhujia", "bhujiya", "sev", "mixture", "chivda", "chiwda",
              "moong dal", "dalmoth", "mathri", "chakli", "khatta meetha", "aloo bhujia")),
    Category("instant_noodles", "Instant noodles",
             ("en:instant-noodles", "en:noodles", "en:instant-pasta"),
             ("noodle", "maggi", "yippee", "ramen", "top ramen", "cup noodle", "chowmein")),
    Category("edible_oils", "Cooking oils",
             ("en:vegetable-oils", "en:sunflower-oils", "en:mustard-oils", "en:rice-bran-oils",
              "en:groundnut-oils", "en:peanut-oils", "en:soybean-oils", "en:olive-oils"),
             ("cooking oil", "refined oil", "sunflower oil", "mustard oil", "groundnut oil",
              "rice bran oil", "soyabean oil", "soybean oil", "olive oil", "edible oil")),
    Category("soft_drinks", "Cold drinks",
             ("en:sodas", "en:colas", "en:carbonated-drinks", "en:soft-drinks",
              "en:lemonade"),
             ("cola", "cold drink", "soft drink", "soda", "thums up", "sprite", "fanta",
              "limca", "mirinda", "7up", "mountain dew", "maaza", "frooti", "appy fizz")),
    Category("fruit_juices", "Fruit juices",
             ("en:fruit-juices", "en:juices-and-nectars", "en:fruit-nectars",
              "en:fruit-based-beverages"),
             ("juice", "nectar", "fruit drink", "real fruit", "tropicana", "paper boat")),
    Category("breakfast_cereals", "Breakfast cereals",
             ("en:breakfast-cereals", "en:mueslis", "en:cornflakes", "en:rolled-oats",
              "en:granolas"),
             ("cereal", "cornflakes", "corn flakes", "muesli", "granola", "oats", "chocos")),
    Category("ketchup_sauces", "Ketchup & sauces",
             # Not en:condiments: spices and pickles live under it too.
             ("en:ketchup", "en:tomato-sauces", "en:sauces"),
             ("ketchup", "sauce", "chutney")),
)

CATEGORIES: dict[str, Category] = {c.key: c for c in _ORDERED}


def _norm(text: str | None) -> str:
    if not text:
        return ""
    folded = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return re.sub(r"\s+", " ", folded.replace("'", "").replace("&", " & ")).strip()


def _has_word(haystack: str, phrase: str) -> bool:
    return re.search(rf"(?<![a-z0-9]){re.escape(phrase)}s?(?![a-z0-9])", haystack) is not None


def classify_off_tags(tags: list[str] | None) -> str | None:
    """CalFit category for an Open Food Facts product, from its category tags."""
    present = set(tags or [])
    for cat in _ORDERED:
        if present & set(cat.off_tags):
            return cat.key
    return None


def classify_text(category: str | None, name: str | None) -> str | None:
    """CalFit category for a scanned label: its stated category first, then its name."""
    for text in (_norm(category), _norm(name)):
        if not text:
            continue
        for cat in _ORDERED:
            if any(_has_word(text, kw) for kw in cat.keywords):
                return cat.key
    return None


# Flavour tag -> phrases that indicate it (matched as whole words).
_FLAVOURS: dict[str, tuple[str, ...]] = {
    "masala": ("masala", "chatpata", "achari", "chaat"),
    "tomato": ("tomato", "tangy tomato"),
    "salted": ("salted", "classic salted", "plain salted", "salt"),
    "cream_onion": ("cream & onion", "cream and onion", "cream n onion", "cream onion",
                    "sour cream"),
    "chilli": ("chilli", "chili", "peri peri", "hot", "spicy", "chatka", "jalapeno"),
    "cheese": ("cheese", "cheesy"),
    "mint": ("pudina", "mint"),
    "lime": ("lime", "lemon", "nimbu", "limon"),
    "jeera": ("jeera", "zeera", "cumin"),
    "chocolate": ("chocolate", "choco", "cocoa", "chocochip"),
    "vanilla": ("vanilla",),
    "strawberry": ("strawberry",),
    "mango": ("mango", "aam"),
    "orange": ("orange",),
    "butter": ("butter",),
    "nuts": ("cashew", "kaju", "almond", "badam", "pista", "pistachio", "peanut", "nut"),
    "elaichi": ("elaichi", "cardamom"),
    "kesar": ("kesar", "saffron"),
    "coffee": ("coffee",),
    "cola": ("cola",),
    "honey": ("honey",),
    "coconut": ("coconut",),
    # Oil varieties: an alternative oil should be the same kind where possible.
    "sunflower": ("sunflower",),
    "mustard": ("mustard", "kachi ghani", "kacchi ghani"),
    "groundnut": ("groundnut",),
    "rice_bran": ("rice bran",),
    "soybean": ("soybean", "soyabean", "soya"),
    "olive": ("olive",),
}


def flavours_of(*texts: str | None) -> list[str]:
    """Flavour tags found in a product's name (and any other text passed)."""
    text = " ".join(_norm(t) for t in texts if t)
    found = [tag for tag, phrases in _FLAVOURS.items() if any(_has_word(text, p) for p in phrases)]
    # "salt" alone is in every savoury name's ingredients; only keep the
    # salted tag when no other savoury flavour was found.
    if "salted" in found and len(found) > 1:
        found.remove("salted")
    # "peanut" in groundnut oil is the oil type, not a nut flavour.
    if "groundnut" in found and "nuts" in found:
        found.remove("nuts")
    return found
