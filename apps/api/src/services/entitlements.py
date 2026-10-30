"""Entitlements: what a user's subscriptions entitle them to.

Deterministic (agents.md §2): the webhook writes subscription rows through the
provider; this reads them and decides the tier and the daily scan cap. Product
ids map to tiers via settings, so the LLM and the provider never decide money.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from src.config.settings import settings
from src.domain.billing import (
    EntitlementRow,
    Tier,
    highest_active_tier,
    scan_cap_for,
)
from src.providers.interfaces import SupabaseProvider
from src.providers.payments import BillingEvent

logger = logging.getLogger(__name__)

# The outcome of applying one webhook event, for logging/tests. None of these
# are errors (a DB failure raises instead, so Dodo retries).
APPLIED = "applied"
DUPLICATE = "duplicate"
UNLINKED = "unlinked"
UNKNOWN_PRODUCT = "unknown_product"
IGNORED = "ignored"


def _plan_period_products() -> dict[tuple[str, str], str]:
    """(plan_id, period) -> Dodo product id, from settings. Blank ids omitted."""
    mapping = {
        ("plus", "monthly"): settings.DODO_PRODUCT_PLUS_MONTHLY,
        ("plus", "annual"): settings.DODO_PRODUCT_PLUS_ANNUAL,
        ("pro", "monthly"): settings.DODO_PRODUCT_PRO_MONTHLY,
        ("pro", "annual"): settings.DODO_PRODUCT_PRO_ANNUAL,
    }
    return {k: v for k, v in mapping.items() if v}


def _product_tiers() -> dict[str, Tier]:
    """Dodo product id -> tier, reversed from settings. Blank ids omitted."""
    pairs = [
        (settings.DODO_PRODUCT_PLUS_MONTHLY, Tier.PLUS),
        (settings.DODO_PRODUCT_PLUS_ANNUAL, Tier.PLUS),
        (settings.DODO_PRODUCT_PRO_MONTHLY, Tier.PRO),
        (settings.DODO_PRODUCT_PRO_ANNUAL, Tier.PRO),
    ]
    return {pid: tier for pid, tier in pairs if pid}


def cap_for_tier(tier: Tier) -> int:
    return scan_cap_for(
        tier,
        free_cap=settings.DAILY_SCAN_CAP,
        plus_cap=settings.PLUS_SCAN_CAP,
        pro_cap=settings.PRO_SCAN_CAP,
    )


class EntitlementService:
    def __init__(self, supabase: SupabaseProvider) -> None:
        self._db = supabase

    def product_id_for(self, plan_id: str, period: str) -> str | None:
        """The Dodo product to check out for a (plan, period), or None if unset."""
        return _plan_period_products().get((plan_id, period))

    async def tier_for(self, user_id: str) -> Tier:
        """The user's current tier from their stored subscriptions.

        A failed read raises (ADR-006): we never quietly treat a lookup error as
        "free" and let a paying user be capped, nor the reverse.
        """
        rows = await self._db.get_entitlements(user_id)
        entitlements: list[EntitlementRow] = []
        for row in rows:
            tier_value = row.get("tier")
            if tier_value not in Tier._value2member_map_:
                continue
            entitlements.append(
                EntitlementRow(
                    tier=Tier(tier_value),
                    status=row.get("status") or "",
                    period_end=_parse_dt(row.get("period_end")),
                )
            )
        return highest_active_tier(entitlements, datetime.now(timezone.utc))

    async def apply(self, event: BillingEvent) -> str:
        """Apply one verified webhook event. Returns an outcome string.

        Not about a subscription -> ignored. No linked user -> unlinked (caller
        logs it). A product we don't recognise -> unknown_product (we won't
        guess a tier). Otherwise the provider applies it idempotently and in
        order, and we report applied/duplicate.
        """
        if not event.external_subscription_id:
            return IGNORED
        if not event.user_id:
            return UNLINKED
        tier = _product_tiers().get(event.product_id or "")
        if tier is None:
            return UNKNOWN_PRODUCT
        changed = await self._db.apply_billing_event(
            webhook_id=event.event_id,
            event_type=event.event_type,
            user_id=event.user_id,
            subscription_id=event.external_subscription_id,
            customer_id=event.external_customer_id,
            tier=tier.value,
            status=event.status or "",
            period_end=event.period_end,
            event_at=event.occurred_at,
        )
        return APPLIED if changed else DUPLICATE


def _parse_dt(value: object) -> datetime | None:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
