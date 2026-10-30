"""Payment provider boundary.

Checkout and webhook verification live behind an interface so the rest of the
app never imports Dodo directly (agents.md §2). A concrete provider
(`DodoPaymentProvider`) creates a hosted checkout and verifies + parses the
provider's webhooks into a provider-agnostic `BillingEvent`.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from collections.abc import Mapping
from datetime import datetime

from pydantic import BaseModel


class PaymentError(Exception):
    """A payment call went wrong in a way the route turns into a 5xx."""


class PaymentNotConfigured(PaymentError):
    """The provider's keys aren't set. The route answers 503, never a fake success."""


class WebhookVerificationError(PaymentError):
    """A webhook's signature, headers or timestamp didn't check out.

    Grants nothing (ADR-006): an unverified webhook is treated as hostile, not
    as a quietly-ignored no-op.
    """


class CheckoutSession(BaseModel):
    """What the app needs to send the user to the provider's hosted checkout."""

    checkout_url: str
    session_id: str = ""


class BillingEvent(BaseModel):
    """A verified, parsed subscription webhook, reduced to what we store.

    Provider-agnostic on purpose: the entitlement layer never sees Dodo's shape.
    """

    # The provider's unique id for this delivery (Standard Webhooks `webhook-id`).
    # Used to make processing idempotent across retries.
    event_id: str
    # e.g. "subscription.active", "subscription.cancelled".
    event_type: str
    # The provider's event timestamp, used to apply events in order (a late
    # "active" must never undo a newer "cancelled").
    occurred_at: datetime
    # None when the event isn't about a subscription we track.
    external_subscription_id: str | None = None
    external_customer_id: str | None = None
    # Our own user_id, echoed back from the metadata we set at checkout.
    user_id: str | None = None
    # The provider's product id, mapped back to a tier by the entitlement layer.
    product_id: str | None = None
    # The subscription's status and when its paid period ends.
    status: str | None = None
    period_end: datetime | None = None


class PaymentProvider(ABC):
    """External payments (checkout + webhook verification)."""

    @abstractmethod
    async def create_checkout(
        self, *, product_id: str, user_id: str, return_url: str | None = None
    ) -> CheckoutSession:
        """Start a hosted subscription checkout for one product.

        `user_id` is attached as metadata so the webhook can tell whose
        entitlement to grant. Raises `PaymentNotConfigured` if keys are missing,
        `PaymentError` on any provider error.
        """
        ...

    @abstractmethod
    def verify_and_parse(
        self, raw_body: bytes, headers: Mapping[str, str]
    ) -> BillingEvent:
        """Verify a webhook's signature over the RAW body and parse it.

        Must be given the exact bytes received — re-serialized JSON won't match
        the signature. Raises `WebhookVerificationError` on any failure.
        """
        ...
