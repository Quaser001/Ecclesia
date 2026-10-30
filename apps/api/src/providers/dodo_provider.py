"""Dodo Payments provider: hosted checkout + Standard Webhooks verification.

No SDK dependency (agents.md §1): checkout is a plain httpx POST, and webhook
verification is the Standard Webhooks scheme done with the standard library
(hmac/hashlib/base64). Dodo signs webhooks per https://standardwebhooks.com/.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import logging
import time
from collections.abc import Mapping
from datetime import datetime

import httpx

from src.providers.interfaces import ServiceUnavailable
from src.providers.payments import (
    BillingEvent,
    CheckoutSession,
    PaymentError,
    PaymentNotConfigured,
    WebhookVerificationError,
)

logger = logging.getLogger(__name__)

# Standard Webhooks allows a 5-minute clock skew between sender and receiver.
_TIMESTAMP_TOLERANCE_SECONDS = 5 * 60


class DodoPaymentProvider:
    """Talks to Dodo's REST API for checkout and verifies its webhooks."""

    def __init__(
        self,
        *,
        api_key: str,
        webhook_secret: str,
        base_url: str,
        timeout: float = 15.0,
    ) -> None:
        self._api_key = api_key
        self._webhook_secret = webhook_secret
        self._base_url = base_url.rstrip("/")
        self._timeout = timeout

    # --- checkout ----------------------------------------------------------

    async def create_checkout(
        self, *, product_id: str, user_id: str, return_url: str | None = None
    ) -> CheckoutSession:
        if not self._api_key:
            raise PaymentNotConfigured("DODO_API_KEY is not set")
        # Hosted checkout: the customer enters their email on Dodo's page, so we
        # send no customer object (we hold no email — identities are anonymous,
        # ADR-008). user_id rides in metadata so the webhook can link the grant.
        payload: dict[str, object] = {
            "product_cart": [{"product_id": product_id, "quantity": 1}],
            "metadata": {"user_id": user_id},
            "subscription_data": {"metadata": {"user_id": user_id}},
        }
        if return_url:
            payload["return_url"] = return_url
        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                resp = await client.post(
                    f"{self._base_url}/checkouts",
                    json=payload,
                    headers={"Authorization": f"Bearer {self._api_key}"},
                )
                resp.raise_for_status()
                data = resp.json()
        except httpx.HTTPStatusError as exc:
            # Log the status only; a body can carry account details. §6: a Dodo
            # 5xx is an upstream outage (503 + Retry-After via main.py); a 4xx is
            # our config (wrong product id or key), which stays a 500.
            status = exc.response.status_code
            logger.error("Dodo checkout failed: HTTP %s", status)
            if status >= 500:
                raise ServiceUnavailable("Dodo is temporarily unavailable") from exc
            raise PaymentError(f"Dodo rejected checkout (HTTP {status})") from exc
        # httpx.TransportError (timeout/drop) is left to propagate: main.py maps
        # it to a 503 with Retry-After, like any upstream outage.
        url = data.get("checkout_url")
        if not url:
            raise PaymentError("Dodo returned no checkout_url")
        return CheckoutSession(checkout_url=url, session_id=data.get("session_id") or "")

    # --- webhook verification ---------------------------------------------

    def verify_and_parse(
        self, raw_body: bytes, headers: Mapping[str, str]
    ) -> BillingEvent:
        if not self._webhook_secret:
            # Never verify with an empty key: an empty-key HMAC is forgeable.
            raise WebhookVerificationError("webhook secret not configured")

        webhook_id = _header(headers, "webhook-id")
        timestamp = _header(headers, "webhook-timestamp")
        signature = _header(headers, "webhook-signature")
        if not (webhook_id and timestamp and signature):
            raise WebhookVerificationError("missing webhook headers")

        _check_timestamp(timestamp)

        # Signed content is `{id}.{timestamp}.{raw body}` (bytes, body unparsed).
        signed = webhook_id.encode() + b"." + timestamp.encode() + b"." + raw_body
        key = _signing_key(self._webhook_secret)
        expected = base64.b64encode(hmac.new(key, signed, hashlib.sha256).digest()).decode()

        # The header is space-separated "v1,<base64sig>" entries; any match is ok.
        if not _any_signature_matches(signature, expected):
            raise WebhookVerificationError("signature mismatch")

        return _parse_event(raw_body, webhook_id)


def _header(headers: Mapping[str, str], name: str) -> str | None:
    # Starlette Headers are case-insensitive; a plain dict may not be.
    value = headers.get(name)
    if value is None and not isinstance(headers, dict):
        return None
    if value is None:
        for k, v in headers.items():
            if k.lower() == name:
                return v
    return value


def _signing_key(secret: str) -> bytes:
    # Standard Webhooks secrets are base64, prefixed "whsec_".
    if secret.startswith("whsec_"):
        return base64.b64decode(secret[len("whsec_"):])
    return secret.encode()


def _check_timestamp(timestamp: str) -> None:
    try:
        sent = int(timestamp)
    except ValueError as exc:
        raise WebhookVerificationError("bad webhook timestamp") from exc
    if abs(time.time() - sent) > _TIMESTAMP_TOLERANCE_SECONDS:
        raise WebhookVerificationError("webhook timestamp out of tolerance")


def _any_signature_matches(header_value: str, expected_b64: str) -> bool:
    for part in header_value.split():
        version, _, candidate = part.partition(",")
        if version == "v1" and hmac.compare_digest(candidate, expected_b64):
            return True
    return False


def _parse_event(raw_body: bytes, webhook_id: str) -> BillingEvent:
    try:
        body = json.loads(raw_body)
    except (ValueError, TypeError) as exc:
        raise WebhookVerificationError("webhook body is not JSON") from exc

    # The ordering guard needs a real event time; never invent one with now(),
    # which would let a timestamp-less event beat a newer stored one.
    occurred_at = _parse_dt(body.get("timestamp"))
    if occurred_at is None:
        raise WebhookVerificationError("missing or invalid event timestamp")

    event_type = str(body.get("type") or "")
    data = body.get("data") or {}
    metadata = data.get("metadata") or {}
    customer = data.get("customer") or {}
    user_id = metadata.get("user_id")

    # Only subscription events carry an entitlement. A payment/refund event that
    # happens to include a subscription_id must NOT be treated as one, or it
    # would upsert a non-"active" status and drop a paying user to free.
    is_subscription = (
        data.get("payload_type") == "Subscription" or event_type.startswith("subscription.")
    )

    return BillingEvent(
        event_id=webhook_id,
        event_type=event_type,
        occurred_at=occurred_at,
        external_subscription_id=data.get("subscription_id") if is_subscription else None,
        external_customer_id=customer.get("customer_id"),
        user_id=str(user_id) if user_id else None,
        product_id=data.get("product_id"),
        status=data.get("status"),
        period_end=_parse_dt(data.get("next_billing_date")),
    )


def _parse_dt(value: object) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        # Dodo sends ISO 8601; tolerate a trailing "Z".
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
