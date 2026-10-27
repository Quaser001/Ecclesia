"""
Per-user daily scan cap.

A single user — or a bot pretending to be one — can run up the Gemini bill
very quickly in a free app. This service enforces a soft cap per user per
UTC day. Two stores are available. `SupabaseCounterStore` keeps the count in
Postgres, so it survives restarts and is shared across Cloud Run instances --
use it in any real deployment. `InMemoryStore` is process-local: a restart
wipes the count and each instance counts separately, so a user could get
`cap * instances` scans a day. It is fine for tests and local runs.
"""

from __future__ import annotations

import threading
from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import date, datetime, timezone
from typing import TYPE_CHECKING

if TYPE_CHECKING:  # pragma: no cover - import cycle guard
    from src.providers.interfaces import SupabaseProvider


class RateLimitExceeded(Exception):
    """Raised when a user has reached today's cap."""

    def __init__(self, user_id: str, cap: int) -> None:
        super().__init__(f"user {user_id} reached daily scan cap of {cap}")
        self.user_id = user_id
        self.cap = cap


class CounterStore(ABC):
    @abstractmethod
    async def increment(self, user_id: str, day: date) -> int:
        """Increment and return the new count for (user_id, day)."""


class InMemoryStore(CounterStore):
    """Thread-safe, process-local counter.

    One Python process holds one dict. Fine for a single-instance deployment
    and for tests. Not shared across replicas — see module docstring.
    """

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._counts: dict[tuple[str, date], int] = {}

    async def increment(self, user_id: str, day: date) -> int:
        key = (user_id, day)
        with self._lock:
            n = self._counts.get(key, 0) + 1
            self._counts[key] = n
            self._prune_old(day)
            return n

    def _prune_old(self, today: date) -> None:
        # Keep today only. The cap resets at UTC midnight, so yesterday's
        # counters are dead weight.
        stale = [k for k in self._counts if k[1] != today]
        for k in stale:
            del self._counts[k]


class SupabaseCounterStore(CounterStore):
    """Durable counter backed by the `scan_usage` table.

    The increment happens in one atomic statement inside Postgres, so two
    concurrent scans can never both be told they are under the cap. The
    database decides the UTC day, which is why `day` is ignored here: the DB
    is the single source of truth, and trusting one clock avoids a user
    getting a free extra scan around midnight when instances disagree.
    """

    def __init__(self, provider: "SupabaseProvider") -> None:
        self._provider = provider

    async def increment(self, user_id: str, day: date) -> int:
        return await self._provider.increment_scan_usage(user_id)


@dataclass(frozen=True)
class ScanLimiter:
    """Enforces the daily scan cap."""

    cap: int
    store: CounterStore

    async def check_and_increment(self, user_id: str, now: datetime | None = None) -> int:
        if not user_id:
            # Never fail-open on an empty id — count it against a shared bucket
            # so misconfigured clients don't bypass the cap.
            user_id = "__anonymous__"
        today = (now or datetime.now(timezone.utc)).date()
        count = await self.store.increment(user_id, today)
        if count > self.cap:
            raise RateLimitExceeded(user_id, self.cap)
        return count
