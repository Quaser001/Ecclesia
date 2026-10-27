"""Delete-my-data edge cases: the prescription counter, and a storage that
never empties."""

from __future__ import annotations

from types import SimpleNamespace

import pytest

from src.providers.local_db_provider import LocalDBProvider
from src.providers.supabase_provider import SupabaseStorageProvider


async def test_prescription_counter_is_deleted_too(tmp_path):
    db = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    await db.increment_scan_usage("me")
    await db.increment_scan_usage("rx:me")
    await db.increment_scan_usage("rx:someone-else")

    await db.delete_user_data("me")

    with db._get_connection() as conn:
        left = {r[0] for r in conn.execute("SELECT user_id FROM scan_usage")}
    assert left == {"rx:someone-else"}


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
