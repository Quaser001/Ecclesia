"""Delete-my-data edge cases: the prescription counter, and a storage that
never empties."""

from __future__ import annotations

from types import SimpleNamespace

import pytest

from src.providers.local_db_provider import LocalDBProvider
from src.providers.supabase_provider import SupabaseStorageProvider


async def test_delete_keeps_todays_counters_so_the_caps_dont_reset(tmp_path):
    """The token still works after a delete: wiping today's counters would
    let one token scan 50, delete, scan 50 more, and so on."""
    db = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    await db.increment_scan_usage("me")
    await db.increment_scan_usage("rx:me")
    await db.increment_scan_usage("rx:someone-else")
    with db._get_connection() as conn:
        conn.executemany(
            "INSERT INTO scan_usage (user_id, usage_date, scan_count) VALUES (?, ?, 3)",
            [("me", "2026-01-01"), ("rx:me", "2026-01-01")])
        conn.commit()

    await db.delete_user_data("me")

    with db._get_connection() as conn:
        left = {tuple(r) for r in conn.execute(
            "SELECT user_id, usage_date < '2026-06-01' FROM scan_usage")}
    assert left == {("me", 0), ("rx:me", 0), ("rx:someone-else", 0)}  # past days gone


class _StuckBucket:
    """Lists the same file forever and claims to remove nothing."""

    async def list(self, prefix, options):
        return [{"name": "a.jpg"}]

    async def remove(self, paths):
        return []


async def test_supabase_delete_folder_never_loops_forever():
    storage = SupabaseStorageProvider(url="https://x.supabase.co", key="k")
    storage._client = SimpleNamespace(storage=SimpleNamespace(from_=lambda b: _StuckBucket()))
    with pytest.raises(RuntimeError):
        await storage.delete_folder("calfit-scans", "scans/me")


async def test_supabase_delete_folder_refuses_the_bucket_root():
    storage = SupabaseStorageProvider(url="https://x.supabase.co", key="k")
    for bad in ("", "/", "scans/../../"):
        with pytest.raises(ValueError):
            await storage.delete_folder("calfit-scans", bad)
