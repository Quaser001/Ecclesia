"""Billing: start a Dodo checkout, receive Dodo webhooks, report the tier.

The app never talks to Dodo (agents.md §5): it asks us for a checkout URL and
opens it. Dodo tells us about payments through the webhook, which we verify and
turn into an entitlement. The Dodo key and webhook secret stay server-side.
"""

from __future__ import annotations

import logging
from typing import Literal

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from src.config.auth import CurrentUserDep
from src.config.dependencies import PaymentProviderDep, SupabaseDep
from src.config.settings import settings
from src.providers.payments import (
    PaymentError,
    PaymentNotConfigured,
    WebhookVerificationError,
)
from src.services.entitlements import UNKNOWN_PRODUCT, UNLINKED, EntitlementService, cap_for_tier

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/billing", tags=["billing"])


class CheckoutRequest(BaseModel):
    plan_id: Literal["plus", "pro"]
    period: Literal["monthly", "annual"]


class CheckoutResponse(BaseModel):
    checkout_url: str


class BillingStatus(BaseModel):
    tier: str
    scans_per_day: int


def _require_billing_enabled() -> None:
    if not settings.BILLING_ENABLED:
        raise HTTPException(status_code=503, detail="Billing isn't available yet.")


@router.get("/status", response_model=BillingStatus, summary="This profile's current tier")
async def get_billing_status(user_id: CurrentUserDep, supabase: SupabaseDep = None) -> BillingStatus:
    """What the app shows: the tier and the daily scan cap it buys.

    Always answers (even with billing off) so the app can render the free tier
    without special-casing a 503.
    """
    from src.domain.billing import Tier

    tier = Tier.FREE
    if settings.BILLING_ENABLED:
        tier = await EntitlementService(supabase).tier_for(user_id)
    return BillingStatus(tier=tier.value, scans_per_day=cap_for_tier(tier))


@router.post("/checkout", response_model=CheckoutResponse, summary="Start a subscription checkout")
async def start_checkout(
    user_id: CurrentUserDep,
    body: CheckoutRequest,
    provider: PaymentProviderDep = None,
    supabase: SupabaseDep = None,
) -> CheckoutResponse:
    """Create a hosted Dodo checkout for the chosen plan and return its URL.

    The user_id is attached as metadata so the webhook can grant the right
    profile. We return only a URL — no keys ever reach the client.
    """
    _require_billing_enabled()
    product_id = EntitlementService(supabase).product_id_for(body.plan_id, body.period)
    if not product_id:
        # The plan exists in the app but no Dodo product is configured for it yet.
        raise HTTPException(status_code=503, detail="This plan isn't available for purchase yet.")
    try:
        session = await provider.create_checkout(
            product_id=product_id,
            user_id=user_id,
            return_url=settings.DODO_RETURN_URL or None,
        )
    except PaymentNotConfigured:
        raise HTTPException(status_code=503, detail="Billing isn't available yet.")
    except PaymentError:
        # Our config bug (wrong product id/key): a 500, not a fake success
        # (§6, ADR-006). A Dodo outage raises ServiceUnavailable, which main.py
        # turns into a 503 + Retry-After — not caught here.
        raise HTTPException(status_code=500, detail="Couldn't start checkout.")
    return CheckoutResponse(checkout_url=session.checkout_url)


@router.post("/webhook", summary="Dodo Payments webhook")
async def dodo_webhook(
    request: Request,
    provider: PaymentProviderDep = None,
    supabase: SupabaseDep = None,
) -> dict[str, bool]:
    """Verify a Dodo webhook and update the entitlement.

    Unauthenticated by design (Dodo has no bearer token); the Standard Webhooks
    signature is the auth. No consent gate. We verify over the RAW body, then
    parse. A verification failure grants nothing (ADR-006). A database failure
    propagates as a 500 so Dodo retries.
    """
    if not settings.BILLING_ENABLED or not settings.DODO_WEBHOOK_SECRET:
        # Fail closed: never verify a signature with an empty secret.
        raise HTTPException(status_code=503, detail="Billing webhook isn't configured.")

    raw = await request.body()
    try:
        event = provider.verify_and_parse(raw, request.headers)
    except WebhookVerificationError:
        # Type only; the body can carry account and payment details.
        logger.warning("Rejected an unverified Dodo webhook")
        raise HTTPException(status_code=401, detail="Invalid webhook signature.")

    outcome = await EntitlementService(supabase).apply(event)
    if outcome == UNLINKED:
        # A verified event with no user_id can't be granted. Log ids only (no
        # personal data) and 200 so Dodo stops retrying something we can't fix.
        logger.error(
            "Dodo webhook without a user_id: type=%s sub=%s",
            event.event_type,
            event.external_subscription_id,
        )
    elif outcome == UNKNOWN_PRODUCT:
        logger.error(
            "Dodo webhook for an unmapped product: type=%s product=%s",
            event.event_type,
            event.product_id,
        )
    return {"received": True}
