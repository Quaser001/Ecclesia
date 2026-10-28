"""Looking up a product online when it isn't in CalFit's food database.

Open Food Facts is the source: an open database with provenance (ODbL),
the same one food.db is imported from. Only a product name or barcode is
sent, never anything about the user.

Its search allows roughly 10 requests a minute per IP, and on Cloud Run
every user shares one IP. So: one search per scan, answers cached in memory
for a day, a short timeout, and a clear "unavailable" (LookupUnavailable)
that is never confused with "not found". Importing more products into
food.db (scripts/import_india_foods.py) is the real fix at scale.
"""

from __future__ import annotations

import logging
import time
from abc import ABC, abstractmethod
from collections import deque
from datetime import date
from typing import Any

import httpx

from src.repositories.off_mapping import map_off_product
from src.repositories.product_repository import FoodProduct

logger = logging.getLogger(__name__)

SEARCH_URL = "https://search.openfoodfacts.org/search"
PRODUCT_URL = "https://world.openfoodfacts.org/api/v2/product/{code}"
FIELDS = ",".join([
    "code", "product_name", "product_name_en", "brands", "countries_tags",
    "categories_tags", "ingredients_text", "ingredients_text_en", "ingredients_tags",
    "allergens_tags", "nutriments", "serving_size", "quantity",
    "image_front_small_url", "image_small_url",
])


class LookupUnavailable(Exception):
    """The online lookup could not be reached or answered with an error."""


class FoodLookupProvider(ABC):
    """Finds real products by name or barcode outside the local database."""

    @abstractmethod
    async def search(self, query: str, limit: int = 8) -> list[FoodProduct]:
        """Products matching the query. Raises LookupUnavailable on failure."""
        ...

    @abstractmethod
    async def get(self, code: str) -> FoodProduct | None:
        """One product by barcode, or None. Raises LookupUnavailable on failure."""
        ...


class OpenFoodFactsLookup(FoodLookupProvider):
    """Open Food Facts search and product APIs, with a small in-memory cache."""

    CACHE_SECONDS = 24 * 3600
    CACHE_MAX = 512
    # Open Food Facts allows about 10 searches a minute per IP, shared by
    # every user of this instance. Stay under it: past this, answer
    # "unavailable" at once rather than get the instance blocked.
    CALLS_PER_MINUTE = 8

    def __init__(self, user_agent: str, timeout: float = 6.0,
                 client: httpx.AsyncClient | None = None) -> None:
        self._headers = {"User-Agent": user_agent}
        self._timeout = timeout
        self._client = client
        self._cache: dict[str, tuple[float, Any]] = {}
        self._recent_calls: deque[float] = deque()

    def _take_call_slot(self) -> None:
        now = time.monotonic()
        while self._recent_calls and now - self._recent_calls[0] > 60:
            self._recent_calls.popleft()
        if len(self._recent_calls) >= self.CALLS_PER_MINUTE:
            raise LookupUnavailable("throttled")
        self._recent_calls.append(now)

    def _cached(self, key: str) -> tuple[bool, Any]:
        hit = self._cache.get(key)
        if hit and hit[0] > time.monotonic():
            return True, hit[1]
        return False, None

    def _store(self, key: str, value: Any) -> None:
        if len(self._cache) >= self.CACHE_MAX:
            self._cache.pop(next(iter(self._cache)))  # oldest first
        self._cache[key] = (time.monotonic() + self.CACHE_SECONDS, value)

    async def _get_json(self, url: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        self._take_call_slot()
        try:
            if self._client is not None:
                resp = await self._client.get(url, params=params, headers=self._headers,
                                              timeout=self._timeout)
            else:
                async with httpx.AsyncClient(timeout=self._timeout) as client:
                    resp = await client.get(url, params=params, headers=self._headers)
        except httpx.HTTPError as exc:
            logger.warning("Open Food Facts unreachable: %s", type(exc).__name__)
            raise LookupUnavailable from exc
        if resp.status_code == 404:
            return {}
        if resp.status_code != 200:
            logger.warning("Open Food Facts answered %s", resp.status_code)
            raise LookupUnavailable(f"status {resp.status_code}")
        try:
            return resp.json()
        except ValueError as exc:
            raise LookupUnavailable("not JSON") from exc

    async def search(self, query: str, limit: int = 8) -> list[FoodProduct]:
        query = " ".join(query.split())[:120]
        if not query:
            return []
        key = f"s:{query.lower()}:{limit}"
        found, value = self._cached(key)
        if found:
            return value
        data = await self._get_json(
            SEARCH_URL, {"q": query, "page_size": limit, "fields": FIELDS})
        today = date.today().isoformat()
        products = [p for hit in data.get("hits") or []
                    if (p := map_off_product(hit, today, for_lookup=True)) is not None]
        self._store(key, products)
        return products

    async def get(self, code: str) -> FoodProduct | None:
        code = code.strip()
        if not code.isdigit() or len(code) > 20:
            return None
        key = f"p:{code}"
        found, value = self._cached(key)
        if found:
            return value
        data = await self._get_json(PRODUCT_URL.format(code=code), {"fields": FIELDS})
        product = None
        if data.get("status") == 1 and isinstance(data.get("product"), dict):
            hit = {"code": code, **data["product"]}
            product = map_off_product(hit, date.today().isoformat(), for_lookup=True)
        self._store(key, product)
        return product
