"""Tests for the per-user daily scan cap."""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

import pytest

from src.services.rate_limit import (
    CounterStore,
    InMemoryStore,
    RateLimitExceeded,
    ScanLimiter,
    SupabaseCounterStore,
)


async def test_limiter_blocks_after_cap_reached():
    limiter = ScanLimiter(cap=3, store=InMemoryStore())
    for i in range(3):
        assert await limiter.check_and_increment("u") == i + 1
    with pytest.raises(RateLimitExceeded):
        await limiter.check_and_increment("u")


async def test_limiter_counts_users_independently():
    limiter = ScanLimiter(cap=1, store=InMemoryStore())
    assert await limiter.check_and_increment("alice") == 1
    assert await limiter.check_and_increment("bob") == 1
    # Each user has their own bucket, and each is now at the cap.
    with pytest.raises(RateLimitExceeded):
        await limiter.check_and_increment("alice")
    with pytest.raises(RateLimitExceeded):
        await limiter.check_and_increment("bob")


async def test_limiter_resets_on_new_utc_day():
    limiter = ScanLimiter(cap=2, store=InMemoryStore())
    today = datetime(2026, 10, 26, 23, 50, tzinfo=timezone.utc)
    tomorrow = today + timedelta(hours=1)  # crosses UTC midnight
    await limiter.check_and_increment("u", now=today)
    await limiter.check_and_increment("u", now=today)
    with pytest.raises(RateLimitExceeded):
        await limiter.check_and_increment("u", now=today)
    # After midnight, the counter resets.
    assert await limiter.check_and_increment("u", now=tomorrow) == 1


async def test_empty_user_id_falls_into_shared_bucket():
    limiter = ScanLimiter(cap=1, store=InMemoryStore())
    await limiter.check_and_increment("")
    # A second empty id must not be fail-open.
    with pytest.raises(RateLimitExceeded):
        await limiter.check_and_increment("")


# ---------------------------------------------------------------------------
# Database-backed store
# ---------------------------------------------------------------------------


class _FakeProvider:
    """Stands in for SupabaseProvider.increment_scan_usage."""

    def __init__(self) -> None:
        self.counts: dict[str, int] = {}
        self.calls: list[str] = []

    async def increment_scan_usage(self, user_id: str) -> int:
        self.calls.append(user_id)
        self.counts[user_id] = self.counts.get(user_id, 0) + 1
        return self.counts[user_id]


async def test_db_store_is_a_counter_store():
    assert issubclass(SupabaseCounterStore, CounterStore)


async def test_db_store_enforces_the_cap():
    provider = _FakeProvider()
    limiter = ScanLimiter(cap=2, store=SupabaseCounterStore(provider))
    assert await limiter.check_and_increment("u") == 1
    assert await limiter.check_and_increment("u") == 2
    with pytest.raises(RateLimitExceeded):
        await limiter.check_and_increment("u")
    assert provider.calls == ["u", "u", "u"]


async def test_db_store_lets_the_database_decide_the_day():
    """The DB owns the UTC date, so a caller-supplied day must not shift it.

    If the store honoured the passed-in day, instances with skewed clocks
    could hand a user a free extra scan around midnight.
    """
    provider = _FakeProvider()
    store = SupabaseCounterStore(provider)
    assert await store.increment("u", date(2026, 1, 1)) == 1
    assert await store.increment("u", date(2026, 6, 1)) == 2
