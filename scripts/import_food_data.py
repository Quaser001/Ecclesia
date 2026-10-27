"""
Import script for Open Food Facts dataset.

Fetches a curated subset of packaged foods (focusing on Indian & global products)
from Open Food Facts official search/download route and imports them into CalFit's local database.

Usage:
  python scripts/import_food_data.py
"""

from __future__ import annotations

import json
import logging
import sys
import time
from pathlib import Path

# Add apps/api to path so we can import from src
root_dir = Path(__file__).resolve().parent.parent
api_dir = root_dir / "apps" / "api"
sys.path.insert(0, str(api_dir))

import httpx
from src.domain.models import NutritionInfo
from src.providers.local_db_provider import LocalDBProvider, get_db_path
from src.repositories.product_repository import FoodProduct, ProductRepository

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# Useful categories for CalFit analysis & alternatives
TARGET_CATEGORIES = [
    "instant noodles",
    "biscuits",
    "beverages",
    "chips",
    "cereals",
    "chocolates",
    "yogurts",
    "dairy",
    "snacks",
    "sauces",
    "bread",
    "plant-based foods",
]

# Knowledge base seeds
SEED_KNOWLEDGE = [
    {
        "topic": "sodium",
        "content": "Sodium contributes to fluid retention and high blood pressure. Daily recommended limit is 1500-2300 mg.",
        "relevance_tags": ["sodium", "hypertension", "salt", "heart_disease"],
    },
    {
        "topic": "sugar",
        "content": "High sugar intake causes rapid blood glucose spikes and insulin resistance. Recommended daily limit is under 25-30g.",
        "relevance_tags": ["sugar", "diabetes", "sweeteners", "glucose"],
    },
    {
        "topic": "saturated_fat",
        "content": "Saturated fats raise LDL cholesterol levels and increase cardiovascular risk. Keep below 10% of total calories.",
        "relevance_tags": ["saturated_fat", "cholesterol", "palm_oil", "butter"],
    },
    {
        "topic": "gluten",
        "content": "Gluten is a protein in wheat, barley, and rye. For individuals with Celiac disease, gluten causes autoimmune small intestine damage.",
        "relevance_tags": ["gluten", "celiac_disease", "wheat", "barley", "flour"],
    },
    {
        "topic": "lactose",
        "content": "Lactose is milk sugar broken down by the lactase enzyme. Deficiency causes bloating, cramps, and diarrhea.",
        "relevance_tags": ["lactose", "lactose_intolerance", "milk", "dairy", "whey"],
    },
    {
        "topic": "instant noodles alternative",
        "content": "Look for whole grain, millet, or air-dried instant noodles with low sodium seasoning sachets and no palm oil.",
        "relevance_tags": ["instant noodles", "noodles", "alternative", "sodium"],
    },
    {
        "topic": "biscuits alternative",
        "content": "Choose whole grain, oat, or ragi biscuits with zero added sugar and no hydrogenated vegetable oils.",
        "relevance_tags": ["biscuits", "cookies", "alternative", "sugar"],
    },
]


def clean_number(val: any) -> float | None:
    if val is None:
        return None
    try:
        f = float(val)
        return f if f >= 0 else None
    except (ValueError, TypeError):
        return None


def parse_ingredients_list(text: str | None) -> list[str]:
    if not text:
        return []
    # Split by comma, semicolon, or bullet
    items = []
    for part in text.replace(";", ",").replace("\n", ",").split(","):
        cleaned = part.strip().strip(".*-•").strip()
        if len(cleaned) > 1 and len(cleaned) < 80:
            items.append(cleaned)
    return items[:30]


def import_products() -> None:
    repo = ProductRepository()
    db_provider = LocalDBProvider()

    # Seed knowledge entries
    logger.info("Seeding CalFit knowledge base...")
    with db_provider._get_connection() as conn:
        cursor = conn.cursor()
        for entry in SEED_KNOWLEDGE:
            cursor.execute("""
                INSERT OR REPLACE INTO knowledge (topic, content, relevance_tags, source)
                VALUES (?, ?, ?, 'calfit_knowledge_base')
            """, (
                entry["topic"],
                entry["content"],
                json.dumps(entry["relevance_tags"]),
            ))
        conn.commit()

    logger.info("Fetching Open Food Facts dataset for development...")
    headers = {"User-Agent": "CalFitApp/1.0 (contact@calfit.local)"}
    client = httpx.Client(timeout=20.0, follow_redirects=True, headers=headers)

    imported_count = 0
    pages_per_category = 2  # 20 items per page * 2 pages = 40 items per category

    # 1. Fetch Indian products specifically
    logger.info("Fetching Indian country products...")
    for page in range(1, 4):
        try:
            url = f"https://world.openfoodfacts.net/api/v2/search?countries_tags_en=india&page={page}&page_size=30&fields=code,product_name,brands,categories,ingredients_text,nutriments,serving_size,allergens_tags,image_url"
            resp = client.get(url)
            if resp.status_code == 200:
                data = resp.json()
                products = data.get("products", [])
                for raw in products:
                    if _save_raw_product(repo, raw):
                        imported_count += 1
            time.sleep(0.5)
        except Exception as e:
            logger.warning("Error fetching Indian products page %d: %s", page, e)

    # 2. Fetch specific category products for rich alternative comparisons
    for cat in TARGET_CATEGORIES:
        logger.info("Fetching products for category '%s'...", cat)
        for page in range(1, pages_per_category + 1):
            try:
                url = f"https://world.openfoodfacts.net/api/v2/search?categories_tags_en={cat.replace(' ', '-')}&page={page}&page_size=20&fields=code,product_name,brands,categories,ingredients_text,nutriments,serving_size,allergens_tags,image_url"
                resp = client.get(url)
                if resp.status_code == 200:
                    data = resp.json()
                    products = data.get("products", [])
                    for raw in products:
                        if _save_raw_product(repo, raw):
                            imported_count += 1
                time.sleep(0.4)
            except Exception as e:
                logger.warning("Error fetching category '%s': %s", cat, e)

    total_in_db = repo.count()
    logger.info("Import completed successfully! Total products in local database: %d", total_in_db)


def _save_raw_product(repo: ProductRepository, raw: dict) -> bool:
    code = raw.get("code")
    product_name = raw.get("product_name")
    if not code or not product_name or not product_name.strip():
        return False

    brand = raw.get("brands")
    categories_raw = raw.get("categories") or ""
    categories = [c.strip() for c in categories_raw.split(",") if c.strip()]
    ingredients_text = raw.get("ingredients_text") or ""
    ingredients = parse_ingredients_list(ingredients_text)
    allergens = raw.get("allergens_tags") or []
    serving_size = raw.get("serving_size")
    image_url = raw.get("image_url")

    nutriments = raw.get("nutriments") or {}
    nutrition = NutritionInfo(
        calories_kcal=clean_number(nutriments.get("energy-kcal_100g") or nutriments.get("energy-kcal") or nutriments.get("energy_100g")),
        total_fat_g=clean_number(nutriments.get("fat_100g") or nutriments.get("fat")),
        saturated_fat_g=clean_number(nutriments.get("saturated-fat_100g") or nutriments.get("saturated-fat")),
        trans_fat_g=clean_number(nutriments.get("trans-fat_100g") or nutriments.get("trans-fat")),
        cholesterol_mg=clean_number(nutriments.get("cholesterol_100g") or nutriments.get("cholesterol")),
        sodium_mg=clean_number(nutriments.get("sodium_100g") or (float(nutriments.get("salt_100g", 0) or 0) * 400 if nutriments.get("salt_100g") else None)),
        total_carbs_g=clean_number(nutriments.get("carbohydrates_100g") or nutriments.get("carbohydrates")),
        dietary_fiber_g=clean_number(nutriments.get("fiber_100g") or nutriments.get("fiber")),
        sugars_g=clean_number(nutriments.get("sugars_100g") or nutriments.get("sugars")),
        added_sugars_g=clean_number(nutriments.get("added-sugars_100g")),
        protein_g=clean_number(nutriments.get("proteins_100g") or nutriments.get("proteins")),
        sodium_confidence=nutriments.get("sodium_100g") is not None or nutriments.get("salt_100g") is not None,
        sugar_confidence=nutriments.get("sugars_100g") is not None,
        fat_confidence=nutriments.get("fat_100g") is not None,
    )

    product = FoodProduct(
        code=str(code),
        product_name=product_name.strip(),
        brand=brand.strip() if brand else None,
        categories=categories,
        ingredients_text=ingredients_text.strip() if ingredients_text else None,
        ingredients=ingredients,
        nutrition=nutrition,
        serving_size=serving_size,
        allergens=allergens,
        image_url=image_url,
        source="open_food_facts",
        data_confidence=0.9 if ingredients or nutrition.calories_kcal else 0.6,
    )

    repo.save_product(product)
    return True


if __name__ == "__main__":
    import_products()
