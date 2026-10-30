"""Billing HTTP routes: checkout, webhook, status.

The checkout and webhook use a fake payment provider (the signature crypto is
tested in test_billing.py); the bad-signature route test uses the real one.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
from datetime import datetime, timedelta, timezone

import pytest
from httpx import ASGITransport, AsyncClient

from src.config.dependencies import get_payment_provider, get_supabase_provider
from src.main import app
from src.providers.local_db_provider import LocalDBProvider
from src.providers.payments import BillingEvent, CheckoutSession, WebhookVerificationError

SOON = datetime.now(timezone.utc) + timedelta(days=20)


class FakePaymentProvider:
    def __init__(self, event: BillingEvent | None = None,
                 url: str = "https://pay.example/checkout") -> None:
        self._event = event
        self._url = url
        self.last_product_id: str | None = None

    async def create_checkout(self, *, product_id, user_id, return_url=None):
        self.last_product_id = product_id
        return CheckoutSession(checkout_url=self._url, session_id="sess_1")

    def verify_and_parse(self, raw_body, headers) -> BillingEvent:
        if self._event is None:
            raise WebhookVerificationError("no event")
        return self._event


def _client() -> AsyncClient:
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


@pytest.fixture
def db(tmp_path):
    provider = LocalDBProvider(db_path=str(tmp_path / "billing_api.db"))
    app.dependency_overrides[get_supabase_provider] = lambda: provider
    yield provider
    app.dependency_overrides.pop(get_supabase_provider, None)


@pytest.fixture
def billing_on(monkeypatch):
    from src.config.settings import settings

    monkeypatch.setattr(settings, "BILLING_ENABLED", True)
    monkeypatch.setattr(settings, "DODO_WEBHOOK_SECRET", "whsec_dGVzdC1zZWNyZXQ=")
    monkeypatch.setattr(settings, "DODO_API_KEY", "test-key")
    monkeypatch.setattr(settings, "DODO_PRODUCT_PLUS_MONTHLY", "prod_plus_m")
    monkeypatch.setattr(settings, "DODO_PRODUCT_PRO_MONTHLY", "prod_pro_m")
    monkeypatch.setattr(settings, "DAILY_SCAN_CAP", 4)
    monkeypatch.setattr(settings, "PRO_SCAN_CAP", 20)


def _use_provider(provider) -> None:
    app.dependency_overrides[get_payment_provider] = lambda: provider


@pytest.fixture(autouse=True)
def _clear_provider_override():
    yield
    app.dependency_overrides.pop(get_payment_provider, None)


# --- status ----------------------------------------------------------------


async def test_status_is_free_by_default(db, billing_on, make_device):
    _, h = make_device()
    async with _client() as c:
        r = await c.get("/api/v1/billing/status", headers=h)
    assert r.status_code == 200
    assert r.json() == {"tier": "free", "scans_per_day": 4}


async def test_status_needs_auth(db):
    async with _client() as c:
        assert (await c.get("/api/v1/billing/status")).status_code == 401


# --- checkout --------------------------------------------------------------


async def test_checkout_returns_a_url_from_the_server_mapped_product(db, billing_on, make_device):
    fake = FakePaymentProvider()
    _use_provider(fake)
    _, h = make_device()
    async with _client() as c:
        # The client sends plan_id/period and even tries to inject a product_id;
        # the server ignores it and maps the plan to its own product.
        r = await c.post("/api/v1/billing/checkout", headers=h,
                         json={"plan_id": "pro", "period": "monthly", "product_id": "evil"})
    assert r.status_code == 200
    assert r.json()["checkout_url"] == "https://pay.example/checkout"
    assert fake.last_product_id == "prod_pro_m"  # not "evil"


async def test_checkout_is_503_when_billing_off(db, make_device):
    _, h = make_device()
    async with _client() as c:
        r = await c.post("/api/v1/billing/checkout", headers=h,
                         json={"plan_id": "plus", "period": "monthly"})
    assert r.status_code == 503


async def test_checkout_needs_auth(db, billing_on):
    async with _client() as c:
        r = await c.post("/api/v1/billing/checkout",
                         json={"plan_id": "plus", "period": "monthly"})
    assert r.status_code == 401


async def test_checkout_rejects_an_unknown_plan(db, billing_on, make_device):
    _, h = make_device()
    async with _client() as c:
        r = await c.post("/api/v1/billing/checkout", headers=h,
                         json={"plan_id": "diamond", "period": "monthly"})
    assert r.status_code == 422  # not a Literal value


# --- webhook ---------------------------------------------------------------


def _event_for(user_id: str) -> BillingEvent:
    return BillingEvent(
        event_id="msg_api_1", event_type="subscription.active",
        occurred_at=datetime.now(timezone.utc),
        external_subscription_id="sub_api_1", external_customer_id="cus_1",
        user_id=user_id, product_id="prod_pro_m", status="active", period_end=SOON,
    )


async def test_a_verified_webhook_grants_the_tier_and_status_reflects_it(db, billing_on, make_device):
    user_id, h = make_device()
    _use_provider(FakePaymentProvider(event=_event_for(user_id)))
    async with _client() as c:
        hook = await c.post("/api/v1/billing/webhook", content=b"{}",
                            headers={"content-type": "application/json"})
        assert hook.status_code == 200 and hook.json() == {"received": True}
        status = await c.get("/api/v1/billing/status", headers=h)
    assert status.json() == {"tier": "pro", "scans_per_day": 20}


async def test_webhook_is_503_when_billing_off(db):
    async with _client() as c:
        r = await c.post("/api/v1/billing/webhook", content=b"{}")
    assert r.status_code == 503


async def test_webhook_is_503_with_an_empty_secret(db, make_device, monkeypatch):
    from src.config.settings import settings

    monkeypatch.setattr(settings, "BILLING_ENABLED", True)
    monkeypatch.setattr(settings, "DODO_WEBHOOK_SECRET", "")  # never verify with an empty key
    async with _client() as c:
        r = await c.post("/api/v1/billing/webhook", content=b"{}")
    assert r.status_code == 503


async def test_a_bad_signature_is_401(db, billing_on):
    # No provider override: the REAL DodoPaymentProvider verifies and rejects.
    # A current timestamp, so it fails on the signature compare (not staleness).
    ts = str(int(time.time()))
    async with _client() as c:
        r = await c.post("/api/v1/billing/webhook", content=b'{"type":"x"}',
                         headers={"webhook-id": "m1", "webhook-timestamp": ts,
                                  "webhook-signature": "v1,bm90LWEtcmVhbC1zaWc="})
    assert r.status_code == 401


# whsec_dGVzdC1zZWNyZXQ= -> base64 of "test-secret", the secret billing_on sets.
def _sign(body: bytes, wid: str, ts: str, secret: str = "whsec_dGVzdC1zZWNyZXQ=") -> str:
    key = base64.b64decode(secret[len("whsec_"):])
    signed = wid.encode() + b"." + ts.encode() + b"." + body
    return base64.b64encode(hmac.new(key, signed, hashlib.sha256).digest()).decode()


async def test_a_real_signed_webhook_grants_the_tier_end_to_end(db, billing_on, make_device):
    """The only test that proves the whole chain: raw bytes survive the body
    middleware, Starlette headers reach the verifier, the real HMAC checks out,
    and apply() grants the tier — no fakes."""
    user_id, h = make_device()
    body = json.dumps({
        "type": "subscription.active",
        "timestamp": "2026-10-30T12:00:00Z",
        "data": {
            "payload_type": "Subscription",
            "subscription_id": "sub_e2e",
            "status": "active",
            "product_id": "prod_pro_m",
            "next_billing_date": "2099-01-01T00:00:00Z",
            "metadata": {"user_id": user_id},
            "customer": {"customer_id": "cus_1"},
        },
    }).encode()
    wid, ts = "msg_e2e", str(int(time.time()))
    headers = {"webhook-id": wid, "webhook-timestamp": ts,
               "webhook-signature": f"v1,{_sign(body, wid, ts)}"}
    async with _client() as c:
        hook = await c.post("/api/v1/billing/webhook", content=body, headers=headers)
        assert hook.status_code == 200, hook.text
        status = await c.get("/api/v1/billing/status", headers=h)
    assert status.json() == {"tier": "pro", "scans_per_day": 20}
