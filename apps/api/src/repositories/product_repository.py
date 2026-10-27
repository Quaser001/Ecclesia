"""Product Repository for local food product storage and matching."""

from __future__ import annotations

import json
import logging
import re
import sqlite3
import unicodedata
from pathlib import Path
from typing import Any, Optional
from pydantic import BaseModel, Field

from src.domain.models import NutritionInfo, ProductObservation

logger = logging.getLogger(__name__)


def get_food_db_path() -> str:
    """Path of the food product database (Open Food Facts subset).

    Kept apart from `data/calfit.db`, the local dev store of profiles and
    scans, so the container can ship the product data without anyone's
    health details. This file is committed and copied into the image.
    """
    return str(Path(__file__).resolve().parent.parent.parent / "data" / "food.db")


class FoodProduct(BaseModel):
    """Normalized food product record stored in CalFit database."""

    code: str
    product_name: str
    brand: Optional[str] = None
    categories: list[str] = Field(default_factory=list)
    ingredients_text: Optional[str] = None
    ingredients: list[str] = Field(default_factory=list)
    nutrition: NutritionInfo = Field(default_factory=NutritionInfo)
    serving_size: Optional[str] = None
    allergens: list[str] = Field(default_factory=list)
    image_url: Optional[str] = None
    source: str = "open_food_facts"
    data_confidence: float = 1.0


class ProductRepository:
    """Repository for querying normalized food products from local database."""

    def __init__(self, db_path: str | None = None) -> None:
        self._db_path = db_path or get_food_db_path()
        self._init_db()

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self._db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self) -> None:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS food_products (
                    code TEXT PRIMARY KEY,
                    product_name TEXT NOT NULL,
                    brand TEXT,
                    categories TEXT,
                    ingredients_text TEXT,
                    ingredients TEXT,
                    serving_size TEXT,
                    allergens TEXT,
                    image_url TEXT,
                    calories_kcal REAL,
                    total_fat_g REAL,
                    saturated_fat_g REAL,
                    trans_fat_g REAL,
                    cholesterol_mg REAL,
                    sodium_mg REAL,
                    total_carbs_g REAL,
                    dietary_fiber_g REAL,
                    sugars_g REAL,
                    added_sugars_g REAL,
                    protein_g REAL,
                    source TEXT DEFAULT 'open_food_facts',
                    data_confidence REAL DEFAULT 1.0
                )
            """)
            # Create indexes for search
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_products_name ON food_products(product_name)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_products_brand ON food_products(brand)")
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_products_categories ON food_products(categories)")
            conn.commit()

        self._seed_default_products()

    def _seed_default_products(self) -> None:
        if self.count() > 0:
            return

        seed_products = [
            FoodProduct(
                code="0073296000010",
                product_name="Plain Non-Fat Greek Yogurt",
                brand="Chobani",
                categories=["yogurt", "dairy", "breakfast"],
                ingredients_text="Cultured nonfat milk, live active cultures",
                ingredients=["cultured nonfat milk", "live active cultures"],
                nutrition=NutritionInfo(
                    calories_kcal=90, total_fat_g=0, saturated_fat_g=0, trans_fat_g=0,
                    sodium_mg=55, total_carbs_g=6, sugars_g=4, protein_g=16
                ),
                source="open_food_facts",
            ),
            FoodProduct(
                code="073296000020",
                product_name="Unsweetened Oat Milk",
                brand="Oatly",
                categories=["plant milk", "dairy-free", "beverages"],
                ingredients_text="Oat base, water, oats, dipotassium phosphate",
                ingredients=["water", "oats", "dipotassium phosphate"],
                nutrition=NutritionInfo(
                    calories_kcal=90, total_fat_g=5, saturated_fat_g=0.5, trans_fat_g=0,
                    sodium_mg=100, total_carbs_g=9, sugars_g=2, protein_g=3
                ),
                source="open_food_facts",
            ),
            FoodProduct(
                code="001862710001",
                product_name="Low Sodium Organic Vegetable Soup",
                brand="Amy's",
                categories=["soup", "instant noodles", "canned food", "noodles"],
                ingredients_text="Organic tomatoes, organic carrots, organic green beans, organic onions, sea salt",
                ingredients=["organic tomatoes", "organic carrots", "organic green beans", "organic onions", "sea salt"],
                nutrition=NutritionInfo(
                    calories_kcal=140, total_fat_g=3, saturated_fat_g=0.5, trans_fat_g=0,
                    sodium_mg=290, total_carbs_g=22, sugars_g=3, protein_g=4
                ),
                source="open_food_facts",
            ),
            FoodProduct(
                code="004122000010",
                product_name="Whole Grain Sea Salt Almond Flour Crackers",
                brand="Simple Mills",
                categories=["biscuits", "snacks", "crackers"],
                ingredients_text="Nut and seed flour blend (almonds, sunflower seeds, flax seeds), tapioca starch, sea salt",
                ingredients=["almonds", "sunflower seeds", "flax seeds", "tapioca starch", "sea salt"],
                nutrition=NutritionInfo(
                    calories_kcal=150, total_fat_g=8, saturated_fat_g=0.5, trans_fat_g=0,
                    sodium_mg=180, total_carbs_g=17, sugars_g=1, protein_g=3
                ),
                source="open_food_facts",
            ),
            FoodProduct(
                code="007680800010",
                product_name="100% Whole Grain Spaghetti",
                brand="Barilla",
                categories=["pasta", "pantry"],
                ingredients_text="Whole durum wheat flour",
                ingredients=["whole durum wheat flour"],
                nutrition=NutritionInfo(
                    calories_kcal=200, total_fat_g=1.5, saturated_fat_g=0, trans_fat_g=0,
                    sodium_mg=0, total_carbs_g=39, sugars_g=2, protein_g=8
                ),
                source="open_food_facts",
            ),
            FoodProduct(
                code="890141400010",
                product_name="Kuch Kuch All-In-One Namkeen",
                brand="Bikaji",
                categories=["snacks", "namkeen", "biscuits"],
                ingredients_text="Gram flour, palmolein oil, peanuts, rice flakes, tapioca starch, salt, red chili, spices",
                ingredients=["gram flour", "palmolein oil", "peanuts", "rice flakes", "tapioca starch", "salt", "red chili powder", "spices"],
                nutrition=NutritionInfo(
                    calories_kcal=540, total_fat_g=34, saturated_fat_g=15, trans_fat_g=0,
                    sodium_mg=750, total_carbs_g=48, sugars_g=6, protein_g=10
                ),
                allergens=["peanuts"],
                source="open_food_facts",
            ),
            FoodProduct(
                code="890106300010",
                product_name="Good Day Cashew Butter Biscuits",
                brand="Britannia",
                categories=["biscuits", "snacks", "cookies"],
                ingredients_text="Refined wheat flour (maida), sugar, vegetable oil, cashew nuts, invert sugar syrup",
                ingredients=["refined wheat flour (maida)", "sugar", "vegetable oil", "cashew nuts", "invert sugar syrup"],
                nutrition=NutritionInfo(
                    calories_kcal=490, total_fat_g=21, saturated_fat_g=10, trans_fat_g=0,
                    sodium_mg=150, total_carbs_g=68, sugars_g=23.5, protein_g=7
                ),
                allergens=["wheat", "nuts"],
                source="open_food_facts",
            ),
        ]

        for prod in seed_products:
            self.save_product(prod)
        logger.info("Seeded %d default food products into local DB", len(seed_products))

    def save_product(self, p: FoodProduct) -> None:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT OR REPLACE INTO food_products (
                    code, product_name, brand, categories, ingredients_text,
                    ingredients, serving_size, allergens, image_url,
                    calories_kcal, total_fat_g, saturated_fat_g, trans_fat_g,
                    cholesterol_mg, sodium_mg, total_carbs_g, dietary_fiber_g,
                    sugars_g, added_sugars_g, protein_g, source, data_confidence
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                p.code,
                p.product_name,
                p.brand,
                json.dumps(p.categories),
                p.ingredients_text,
                json.dumps(p.ingredients),
                p.serving_size,
                json.dumps(p.allergens),
                p.image_url,
                p.nutrition.calories_kcal,
                p.nutrition.total_fat_g,
                p.nutrition.saturated_fat_g,
                p.nutrition.trans_fat_g,
                p.nutrition.cholesterol_mg,
                p.nutrition.sodium_mg,
                p.nutrition.total_carbs_g,
                p.nutrition.dietary_fiber_g,
                p.nutrition.sugars_g,
                p.nutrition.added_sugars_g,
                p.nutrition.protein_g,
                p.source,
                p.data_confidence,
            ))
            conn.commit()

    def count(self) -> int:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM food_products")
            return cursor.fetchone()[0]

    def find_by_code(self, code: str) -> Optional[FoodProduct]:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM food_products WHERE code = ?", (code,))
            row = cursor.fetchone()
            if row:
                return _row_to_product(row)
        return None

    def match_product(
        self,
        name: Optional[str] = None,
        brand: Optional[str] = None,
        category: Optional[str] = None,
    ) -> Optional[FoodProduct]:
        """Find the product the label names, or None when the match is not certain.

        A match fills in data the photo did not show, so a wrong one is
        fabricated data. `category` is accepted for callers but not used:
        sharing a category word says nothing about which product it is.
        """
        if not name:
            return None
        label_tokens = _tokens(name) | _tokens(brand)

        best_row, best_shared = None, 0
        with self._get_connection() as conn:
            for row in conn.execute("SELECT * FROM food_products"):
                shared = _match_strength(name, brand, row["product_name"], row["brand"], label_tokens)
                if shared > best_shared:
                    best_row, best_shared = row, shared

        return _row_to_product(best_row) if best_row is not None else None

    def find_candidates_by_category(
        self,
        category: Optional[str],
        exclude_code: Optional[str] = None,
        limit: int = 20,
    ) -> list[FoodProduct]:
        """Retrieve candidate products in the same or related category."""
        if not category:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT * FROM food_products LIMIT ?", (limit,))
                return [_row_to_product(r) for r in cursor.fetchall()]

        cat_clean = category.strip().lower()
        words = [w for w in cat_clean.replace(">", " ").replace("-", " ").replace(",", " ").split() if len(w) > 2]
        
        with self._get_connection() as conn:
            cursor = conn.cursor()
            clauses = ["LOWER(categories) LIKE ? OR LOWER(product_name) LIKE ?"]
            params = [f"%{cat_clean}%", f"%{cat_clean}%"]
            for w in words:
                clauses.append("LOWER(categories) LIKE ? OR LOWER(product_name) LIKE ?")
                params.extend([f"%{w}%", f"%{w}%"])
            
            where_sql = " OR ".join(clauses)
            query = f"SELECT * FROM food_products WHERE ({where_sql})"
            if exclude_code:
                query += " AND code != ?"
                params.append(exclude_code)
            query += " LIMIT ?"
            params.append(limit)

            cursor.execute(query, tuple(params))
            rows = cursor.fetchall()
            return [_row_to_product(r) for r in rows]


# Pack sizes and prices ("200ml", "375g", "20rs") and filler words do not
# identify a product.
_SIZE_TOKEN = re.compile(r"^\d+(?:\.\d+)?(?:ml|l|g|gm|gms|kg|rs|pcs)?$")
_FILLER = {"and", "the", "with", "for", "new", "pack", "des", "les", "von", "und"}


def _tokens(text: Optional[str]) -> set[str]:
    """Lower-case, accent-folded identifying words ("Nestlé" == "nestle", "Lay's" == "lays")."""
    if not text:
        return set()
    folded = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    folded = folded.replace("'", "")
    return {
        w for w in re.split(r"[^a-z0-9]+", folded)
        if len(w) >= 3 and w not in _FILLER and not _SIZE_TOKEN.match(w)
    }


def _match_strength(
    name: str,
    brand: Optional[str],
    row_name: str,
    row_brand: Optional[str],
    label_tokens: set[str],
) -> int:
    """Number of identifying words shared, or 0 when the row is not this product.

    - Brands, when both are known, must share a word.
    - The row's own name, minus its brand, must say something specific, and
      every one of those words must be on the label. "Good Day Butter
      Cookies" is not "Good Day Chocochip Cookies"; a row named just
      "Kurkure" could be any Kurkure.
    - The label's name must contribute a word beyond its brand ("STING" by
      Sting names no particular product).
    - At least two words in common overall: one shared word is not a match.
    """
    brand_words = _tokens(brand)
    row_brand_words = _tokens(row_brand)
    if brand_words and row_brand_words and not (brand_words & row_brand_words):
        return 0

    row_specific = _tokens(row_name) - row_brand_words
    if not row_specific or not row_specific <= label_tokens:
        return 0

    label_specific = _tokens(name) - brand_words
    if not (label_specific & row_specific):
        return 0

    shared = label_tokens & (_tokens(row_name) | row_brand_words)
    return len(shared) if len(shared) >= 2 else 0


def _row_to_product(row: sqlite3.Row) -> FoodProduct:
    def _parse_list(val: Any) -> list:
        if not val:
            return []
        if isinstance(val, list):
            return val
        try:
            return json.loads(val)
        except Exception:
            return [v.strip() for v in val.split(",") if v.strip()]

    nutrition = NutritionInfo(
        calories_kcal=row["calories_kcal"],
        total_fat_g=row["total_fat_g"],
        saturated_fat_g=row["saturated_fat_g"],
        trans_fat_g=row["trans_fat_g"],
        cholesterol_mg=row["cholesterol_mg"],
        sodium_mg=row["sodium_mg"],
        total_carbs_g=row["total_carbs_g"],
        dietary_fiber_g=row["dietary_fiber_g"],
        sugars_g=row["sugars_g"],
        added_sugars_g=row["added_sugars_g"],
        protein_g=row["protein_g"],
        sodium_confidence=row["sodium_mg"] is not None,
        sugar_confidence=row["sugars_g"] is not None,
        fat_confidence=row["total_fat_g"] is not None,
    )

    return FoodProduct(
        code=row["code"],
        product_name=row["product_name"],
        brand=row["brand"],
        categories=_parse_list(row["categories"]),
        ingredients_text=row["ingredients_text"],
        ingredients=_parse_list(row["ingredients"]),
        nutrition=nutrition,
        serving_size=row["serving_size"],
        allergens=_parse_list(row["allergens"]),
        image_url=row["image_url"],
        source=row["source"] or "open_food_facts",
        data_confidence=float(row["data_confidence"] or 1.0),
    )
