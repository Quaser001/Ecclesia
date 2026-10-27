"""LocalDBProvider — the Supabase-less MVP backend.

Covers the fields that were added after the initial schema (currently
`avoid_caffeine`), including the ALTER-based migration for a pre-existing
database file.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from src.domain.models import HealthCondition, UserProfile
from src.providers.local_db_provider import LocalDBProvider


@pytest.fixture
def db_path(tmp_path: Path) -> str:
    return str(tmp_path / "calfit.db")


async def test_round_trip_profile_with_avoid_caffeine(db_path: str):
    provider = LocalDBProvider(db_path=db_path)
    saved = await provider.upsert_profile(
        UserProfile(
            user_id="u1",
            name="Asef",
            health_conditions=[HealthCondition.ANAEMIA],
            avoid_caffeine=True,
        )
    )
    assert saved.avoid_caffeine is True
    loaded = await provider.get_profile("u1")
    assert loaded is not None
    assert loaded.name == "Asef"
    assert loaded.avoid_caffeine is True
    assert HealthCondition.ANAEMIA in loaded.health_conditions


async def test_upsert_flips_avoid_caffeine(db_path: str):
    provider = LocalDBProvider(db_path=db_path)
    await provider.upsert_profile(UserProfile(user_id="u1", avoid_caffeine=True))
    await provider.upsert_profile(UserProfile(user_id="u1", avoid_caffeine=False))
    loaded = await provider.get_profile("u1")
    assert loaded is not None and loaded.avoid_caffeine is False


async def test_migration_adds_column_to_pre_existing_db(tmp_path: Path):
    """A DB file that pre-dates `avoid_caffeine` must still load, not crash."""
    db_path = tmp_path / "old.db"
    # Build the schema as it was before avoid_caffeine was added.
    with sqlite3.connect(db_path) as conn:
        conn.execute(
            """
            CREATE TABLE profiles (
                user_id TEXT PRIMARY KEY,
                name TEXT,
                health_conditions TEXT,
                allergies TEXT,
                dietary_preferences TEXT,
                health_goals TEXT,
                created_at TEXT,
                updated_at TEXT
            )
            """
        )
        conn.execute(
            "INSERT INTO profiles (user_id, name, health_conditions, allergies,"
            " dietary_preferences, health_goals, created_at, updated_at)"
            " VALUES ('legacy', 'Old User', '[]', '[]', '[]', '[]', '2026-01-01T00:00:00+00:00', '2026-01-01T00:00:00+00:00')"
        )
        conn.commit()

    # Opening the provider must perform the ALTER and leave the old row intact.
    provider = LocalDBProvider(db_path=str(db_path))
    loaded = await provider.get_profile("legacy")
    assert loaded is not None
    assert loaded.name == "Old User"
    assert loaded.avoid_caffeine is False
