"""Front-of-pack identification: which real product, and when to ask the user.

Fixtures are shaped like the real Open Food Facts search hits for "amul
lassi" (28 Oct 2026): three Amul lassis that differ in sugar, plus lassis
from other brands that must never be offered for an Amul pack.
"""

from __future__ import annotations

import pytest

from src.domain.models import ProductObservation
from src.domain.nutrient_levels import is_drink
from src.repositories.off_mapping import map_off_product
from src.services.identification import (
    IdStatus,
    decide,
    message_for,
    observation_from_product,
    parse_quantity,
    rank,
    read_as,
    search_query,
)


def _hit(code, name, brands, quantity, sugars, kcal=88, fat=2.0, salt=0.07, cats=(), india=True):
    return {
        "code": code, "product_name": name, "brands": brands, "quantity": quantity,
        "countries_tags": ["en:india"] if india else [],
        "categories_tags": list(cats),
        "nutriments": {"energy-kcal_100g": kcal, "sugars_100g": sugars, "fat_100g": fat,
                       **({"salt_100g": salt} if salt is not None else {})},
    }


HITS = [
    _hit("8901262202046", "Amul Lassi", ["Amul"], None, 22.5, kcal=142, fat=4, salt=0.13,
         cats=["en:beverages"]),
    _hit("8901262151696", "Amul Lassi 180ml tpk", ["Amul"], "250 ml", 14,
         cats=["en:fermented-milk-drinks", "en:drinkable-yogurts"]),
    _hit("8901262200189", "Lassi", ["Amul"], "200mL", 14.5,
         cats=["en:fermented-milk-drinks", "en:drinkable-yogurts", "en:lassi"]),
    _hit("5029617001045", "Nomadic", ["Lassi"], None, 9.6, salt=None, india=False),
    _hit("5901104007283", "Lassi", ["Planton"], None, 5.0, india=False),
    _hit("8906027713935", "Lassi", None, None, 16, salt=None),
]


def _candidates():
    products = [map_off_product(h, "2026-10-28", for_lookup=True) for h in HITS]
    assert all(products), "every fixture must map for a lookup"
    return [(p, "open_food_facts") for p in products]


def _pack(**kw):
    base = dict(brand="Amul", product_name="Lassi", identity_confidence=0.92)
    base.update(kw)
    return ProductObservation(**base)


def test_the_pack_size_picks_the_one_real_product():
    obs = _pack(net_quantity="200 ml", mrp="Rs 20")
    ident = decide(obs, rank(obs, _candidates()))
    assert ident.status is IdStatus.CONFIDENT
    assert ident.chosen.code == "8901262200189"
    assert ident.read_as == "Amul Lassi 200 ml"


def test_without_a_size_the_user_chooses_among_amul_lassis_only():
    obs = _pack()
    ident = decide(obs, rank(obs, _candidates()))
    assert ident.status is IdStatus.CHOOSE
    assert {o.code for o in ident.options} == {"8901262202046", "8901262151696", "8901262200189"}
    assert all(o.brand == "Amul" for o in ident.options)


def test_a_less_sure_reading_asks_to_confirm():
    obs = _pack(net_quantity="200 ml", identity_confidence=0.6)
    ident = decide(obs, rank(obs, _candidates()))
    assert ident.status is IdStatus.CONFIRM and len(ident.options) == 1


@pytest.mark.parametrize("obs", [
    _pack(identity_confidence=0.3),
    _pack(product_name=None),
])
def test_an_unreadable_name_asks_for_a_retake(obs):
    assert decide(obs, rank(obs, _candidates())).status is IdStatus.RETAKE


def test_missing_confidence_is_unknown_not_zero():
    obs = _pack(net_quantity="200 ml", identity_confidence=None)
    assert decide(obs, rank(obs, _candidates())).status is IdStatus.CONFIDENT


def test_another_brand_is_never_offered():
    obs = _pack(brand="Mother Dairy")
    ident = decide(obs, rank(obs, _candidates()))
    assert ident.status is IdStatus.NOT_FOUND and ident.options == []
    assert "Mother Dairy Lassi" in message_for(ident)


def test_a_failed_lookup_is_not_reported_as_not_found():
    ident = decide(_pack(), [], lookup_failed=True)
    assert ident.status is IdStatus.UNAVAILABLE
    assert "couldn't reach" in message_for(ident)


def test_the_chosen_product_keeps_provenance_and_the_pack_details():
    obs = _pack(net_quantity="200 ml", mrp="Rs 20", visible_claims=["No preservatives"],
                category=None)
    product, source = rank(obs, _candidates())[0]
    scanned = observation_from_product(product, source, obs)
    assert scanned.data_source == "open_food_facts"
    assert scanned.source_code == "8901262200189" and scanned.source_date == "2026-10-28"
    assert scanned.nutrition.serving_size_g == 100 and scanned.nutrition.sugars_g == 14.5
    assert scanned.mrp == "Rs 20" and scanned.visible_claims == ["No preservatives"]
    # Lassi is a drink: per-100 ml levels, and only drinks as alternatives.
    assert is_drink(scanned.category, scanned.product_name)


def test_missing_sodium_stays_missing():
    no_salt = map_off_product(HITS[5], "2026-10-28", for_lookup=True)
    assert no_salt.nutrition.sodium_mg is None
    assert no_salt.nutrition.sodium_confidence is False


def test_the_import_still_refuses_what_a_lookup_accepts():
    # food.db keeps its strict rules: India only, a CalFit category, sodium known.
    assert map_off_product(HITS[3], "2026-10-28") is None
    assert map_off_product(HITS[5], "2026-10-28") is None


@pytest.mark.parametrize("text,ml", [
    ("200 ml", 200), ("200mL", 200), ("1 L", 1000), ("52 g", 52), ("1.5 kg", 1500),
    ("Amul Lassi 180ml tpk", 180), ("Rs 20", None), (None, None),
])
def test_parse_quantity(text, ml):
    assert parse_quantity(text) == ml


def test_one_search_query_without_sizes_or_repeats():
    obs = _pack(product_name="Amul Lassi", variant="Rose", net_quantity="200 ml")
    assert search_query(obs) == "Amul Lassi Rose"
    assert read_as(obs) == "Amul Lassi Rose 200 ml"
    assert read_as(_pack(brand="Sting", product_name="STING")) == "STING"
