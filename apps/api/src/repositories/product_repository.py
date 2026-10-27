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

from src.domain.food_taxonomy import classify_text, flavours_of
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
    # CalFit's own category key (see src/domain/food_taxonomy.py) and flavour
    # tags; filled from the name and categories when not given.
    calfit_category: Optional[str] = None
    flavours: list[str] = Field(default_factory=list)
    imported_at: Optional[str] = None  # ISO date the record was fetched


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
            # Additive columns: older files gain them without losing rows.
            for column in ("calfit_category TEXT", "flavours TEXT", "imported_at TEXT"):
                try:
                    cursor.execute(f"ALTER TABLE food_products ADD COLUMN {column}")
                except sqlite3.OperationalError:
                    pass
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_products_calfit_category "
                "ON food_products(calfit_category)"
            )
            conn.commit()

    def save_product(self, p: FoodProduct) -> None:
        category = p.calfit_category or classify_text(" ".join(p.categories), p.product_name)
        flavours = p.flavours or flavours_of(p.product_name)
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT OR REPLACE INTO food_products (
                    code, product_name, brand, categories, ingredients_text,
                    ingredients, serving_size, allergens, image_url,
                    calories_kcal, total_fat_g, saturated_fat_g, trans_fat_g,
                    cholesterol_mg, sodium_mg, total_carbs_g, dietary_fiber_g,
                    sugars_g, added_sugars_g, protein_g, source, data_confidence,
                    calfit_category, flavours, imported_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                category,
                json.dumps(flavours),
                p.imported_at,
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

    def find_by_calfit_category(
        self, calfit_category: str, limit: int = 300
    ) -> list[FoodProduct]:
        """Every product in one CalFit category (see food_taxonomy)."""
        with self._get_connection() as conn:
            rows = conn.execute(
                "SELECT * FROM food_products WHERE calfit_category = ? LIMIT ?",
                (calfit_category, limit),
            ).fetchall()
        return [_row_to_product(r) for r in rows]

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
        calfit_category=_optional(row, "calfit_category"),
        flavours=_parse_list(_optional(row, "flavours")),
        imported_at=_optional(row, "imported_at"),
    )


def _optional(row: sqlite3.Row, column: str) -> Any:
    """A column that older database files may not have."""
    try:
        return row[column]
    except (IndexError, KeyError):
        return None
