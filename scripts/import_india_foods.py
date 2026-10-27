"""Build CalFit's India food database from Open Food Facts.

Fetches products sold in India for each CalFit category (see
apps/api/src/domain/food_taxonomy.py), keeps those with complete core
nutrition, and writes apps/api/data/food.db. The new file is built beside
the old one and only replaces it when the import finishes.

Data: Open Food Facts (https://world.openfoodfacts.org), Open Database
Licence (ODbL). Credit it wherever products are shown.

Usage (from the repository root):
    .venv/Scripts/python.exe -I scripts/import_india_foods.py [--max-pages 6]
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter
from datetime import date
from pathlib import Path

API_DIR = Path(__file__).resolve().parent.parent / "apps" / "api"
sys.path.insert(0, str(API_DIR))

from src.domain.food_taxonomy import CATEGORIES  # noqa: E402
from src.repositories.off_mapping import map_off_product  # noqa: E402
from src.repositories.product_repository import ProductRepository  # noqa: E402

SEARCH_URL = "https://search.openfoodfacts.org/search"
USER_AGENT = "CalFit/0.1 (+https://github.com/Quaser001/Ecclesia)"
FIELDS = ",".join([
    "code", "product_name", "product_name_en", "brands", "countries_tags",
    "categories_tags", "ingredients_text", "ingredients_text_en", "ingredients_tags",
    "allergens_tags",
    "nutriments", "serving_size", "image_front_small_url", "image_small_url",
])
PAGE_SIZE = 100


def fetch_page(tag: str, page: int) -> dict:
    query = f'countries_tags:"en:india" AND categories_tags:"{tag}"'
    url = SEARCH_URL + "?" + urllib.parse.urlencode(
        {"q": query, "page": page, "page_size": PAGE_SIZE, "fields": FIELDS}
    )
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return json.load(resp)
        except Exception as exc:  # network hiccup: back off and retry
            if attempt == 2:
                raise
            print(f"  retry {tag} p{page}: {type(exc).__name__}")
            time.sleep(3 * (attempt + 1))
    return {}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-pages", type=int, default=6, help="pages of 100 per tag")
    args = parser.parse_args()

    out = API_DIR / "data" / "food.db"
    tmp = out.with_suffix(".db.new")
    tmp.unlink(missing_ok=True)
    repo = ProductRepository(str(tmp))
    today = date.today().isoformat()

    seen: set[str] = set()
    kept: Counter[str] = Counter()
    skipped = 0
    for category in CATEGORIES.values():
        for tag in category.off_tags:
            page = 1
            while page <= args.max_pages:
                data = fetch_page(tag, page)
                hits = data.get("hits") or []
                for hit in hits:
                    code = str(hit.get("code") or "")
                    if not code or code in seen:
                        continue
                    seen.add(code)
                    product = map_off_product(hit, imported_at=today)
                    if product is None:
                        skipped += 1
                        continue
                    repo.save_product(product)
                    kept[product.calfit_category] += 1
                print(f"{category.key:26} {tag:28} page {page}/{data.get('page_count', 1)}: "
                      f"{len(hits)} hits")
                if page >= int(data.get("page_count") or 1):
                    break
                page += 1
                time.sleep(1)  # be polite to a free service
            time.sleep(1)

    total = sum(kept.values())
    if total < 100:
        tmp.unlink(missing_ok=True)
        sys.exit(f"Only {total} products imported; keeping the existing food.db.")

    conn = sqlite3.connect(tmp)
    try:
        conn.execute("VACUUM")
    finally:
        conn.close()  # `with sqlite3.connect()` commits but does not close
    # OneDrive briefly locks a freshly written file while it uploads it.
    for attempt in range(12):
        try:
            tmp.replace(out)
            break
        except PermissionError:
            if attempt == 11:
                raise
            time.sleep(5)
    print(f"\nImported {total} products ({skipped} skipped for missing data) into {out}")
    for key, n in sorted(kept.items(), key=lambda kv: -kv[1]):
        print(f"  {CATEGORIES[key].label:28} {n}")


if __name__ == "__main__":
    main()
