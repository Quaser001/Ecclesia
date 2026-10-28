"""The Open Food Facts client: mapping, caching, and failure that says so."""

from __future__ import annotations

import httpx
import pytest

from src.providers.food_lookup import LookupUnavailable, OpenFoodFactsLookup

LASSI = {
    "code": "8901262200189", "product_name": "Lassi", "brands": ["Amul"], "quantity": "200mL",
    "countries_tags": ["en:india"], "categories_tags": ["en:lassi"],
    "nutriments": {"energy-kcal_100g": 88.5, "sugars_100g": 14.5, "fat_100g": 2.1,
                   "salt_100g": 0.075},
}


def _client(handler):
    calls = []

    def wrapped(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        return handler(request)

    return httpx.AsyncClient(transport=httpx.MockTransport(wrapped)), calls


async def test_search_maps_hits_sends_only_the_query_and_caches():
    client, calls = _client(lambda r: httpx.Response(200, json={"hits": [LASSI, {"code": "x"}]}))
    lookup = OpenFoodFactsLookup("CalFit/test", client=client)
    first = await lookup.search("Amul Lassi")
    again = await lookup.search("amul  lassi")
    assert [p.code for p in first] == ["8901262200189"]  # the unusable hit is dropped
    assert first[0].quantity == "200mL" and first[0].nutrition.sodium_mg == 30.0
    assert again == first and len(calls) == 1  # cached: one request for both
    assert calls[0].url.params["q"] == "Amul Lassi"
    assert calls[0].headers["user-agent"] == "CalFit/test"


async def test_get_by_code():
    client, calls = _client(lambda r: httpx.Response(
        200, json={"status": 1, "product": {k: v for k, v in LASSI.items() if k != "code"}}))
    product = await OpenFoodFactsLookup("CalFit/test", client=client).get("8901262200189")
    assert product.code == "8901262200189" and product.nutrition.sugars_g == 14.5
    assert calls[0].url.path.endswith("/product/8901262200189")


async def test_unknown_code_is_none_and_bad_codes_never_leave_the_server():
    client, calls = _client(lambda r: httpx.Response(200, json={"status": 0}))
    lookup = OpenFoodFactsLookup("CalFit/test", client=client)
    assert await lookup.get("0000000000000") is None
    assert await lookup.get("../../etc/passwd") is None
    assert len(calls) == 1


@pytest.mark.parametrize("handler", [
    lambda r: httpx.Response(503),
    lambda r: httpx.Response(429),
    lambda r: (_ for _ in ()).throw(httpx.ConnectTimeout("slow")),
])
async def test_outages_are_unavailable_not_empty(handler):
    client, _ = _client(handler)
    with pytest.raises(LookupUnavailable):
        await OpenFoodFactsLookup("CalFit/test", client=client).search("Amul Lassi")
