"""What ships to Cloud Build and into the image must be the food database only.

`data/calfit.db` is the local dev store: it holds real profiles (health
conditions, allergies) and scan history, and `data/uploads/` holds scan
photos. `apps/api/.env` holds API keys. None of it may leave the machine on
`gcloud builds submit` or end up inside the container.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from src.providers.local_db_provider import get_db_path
from src.repositories.product_repository import ProductRepository, get_food_db_path

API_DIR = Path(__file__).resolve().parent.parent
FOOD_DB = API_DIR / "data" / "food.db"


def _ignore_lines(name: str) -> set[str]:
    path = API_DIR / name
    assert path.is_file(), f"{name} is missing"
    return {
        line.strip().rstrip("/")
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    }


def test_product_repository_reads_the_food_database_not_the_user_store():
    assert Path(get_food_db_path()) == FOOD_DB
    assert ProductRepository()._db_path == str(FOOD_DB)
    assert Path(get_db_path()).name == "calfit.db"  # LocalDBProvider unchanged


def test_food_database_holds_products_and_nothing_personal():
    assert FOOD_DB.is_file()
    con = sqlite3.connect(f"file:{FOOD_DB}?mode=ro", uri=True)
    tables = {r[0] for r in con.execute("select name from sqlite_master where type='table'")}
    assert tables == {"food_products"}
    assert con.execute("select count(*) from food_products").fetchone()[0] >= 400


def test_dockerfile_copies_only_the_food_database_from_data():
    dockerfile = (API_DIR / "Dockerfile").read_text(encoding="utf-8")
    data_copies = [ln for ln in dockerfile.splitlines()
                   if ln.strip().startswith("COPY") and "data" in ln]
    assert data_copies == ["COPY data/food.db ./data/food.db"]


def test_cloud_build_upload_excludes_secrets_and_personal_data():
    ignored = _ignore_lines(".gcloudignore")
    assert {".env", "data/calfit.db", "data/uploads", ".venv"} <= ignored


def test_docker_context_excludes_secrets_and_personal_data():
    ignored = _ignore_lines(".dockerignore")
    assert {".env", "data/calfit.db", "data/uploads"} <= ignored
