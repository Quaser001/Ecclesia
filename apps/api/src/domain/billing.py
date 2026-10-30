"""Subscription tiers and the pure entitlement rule.

Deterministic and database-free (agents.md §2): given the subscription rows we
have stored for a user and the current time, decide their tier. The webhook
writes rows; this decides what they mean. No LLM, no provider calls here.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from datetime import datetime
from enum import Enum


class Tier(str, Enum):
    FREE = "free"
    PLUS = "plus"
    PRO = "pro"


# Higher number = more scans. Used to pick the best of several subscriptions.
_RANK: dict[Tier, int] = {Tier.FREE: 0, Tier.PLUS: 1, Tier.PRO: 2}

# A Dodo subscription grants access only in this status. Everything else
# (on_hold, past_due, cancelled, failed, expired, paused, pending, or anything
# we don't recognise) grants nothing — fail safe. A status we've never seen is
# treated as "not active", never guessed into an entitlement.
ACTIVE_STATUS = "active"


@dataclass(frozen=True)
class EntitlementRow:
    """One stored subscription, reduced to what the tier rule needs."""

    tier: Tier
    status: str
    # When the current paid period ends (Dodo's next_billing_date). None means
    # we don't know, which counts as not entitled.
    period_end: datetime | None


def is_entitled(status: str, period_end: datetime | None, now: datetime) -> bool:
    """Active, and the paid period hasn't lapsed."""
    if status != ACTIVE_STATUS:
        return False
    if period_end is None:
        return False
    return period_end > now


def highest_active_tier(rows: Iterable[EntitlementRow], now: datetime) -> Tier:
    """The best tier among the user's currently-entitled subscriptions.

    Someone who bought Pro while Plus was still active is on Pro: a later Plus
    cancellation must not drop them to free. So we take the max over all
    entitled rows, never the newest row.
    """
    best = Tier.FREE
    for row in rows:
        if is_entitled(row.status, row.period_end, now) and _RANK[row.tier] > _RANK[best]:
            best = row.tier
    return best


def scan_cap_for(tier: Tier, *, free_cap: int, plus_cap: int, pro_cap: int) -> int:
    """Daily successful-scan cap for a tier."""
    return {Tier.FREE: free_cap, Tier.PLUS: plus_cap, Tier.PRO: pro_cap}[tier]
