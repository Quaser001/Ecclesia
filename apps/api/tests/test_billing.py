"""Billing core: the tier rule, webhook verification, entitlement application,
and the scan cap that an entitlement buys.

These test the logic without HTTP (see test_billing_api.py for the routes).
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
from datetime import datetime, timedelta, timezone

import pytest

from src.config.dependencies import get_scan_limiter
from src.domain.billing import (
    EntitlementRow,
    Tier,
    highest_active_tier,
    is_entitled,
    scan_cap_for,
)
from src.providers.dodo_provider import DodoPaymentProvider
from src.providers.local_db_provider import LocalDBProvider
from src.providers.payments import BillingEvent, WebhookVerificationError
from src.services.entitlements import (
    APPLIED,
    DUPLICATE,
    IGNORED,
    UNKNOWN_PRODUCT,
    UNLINKED,
    EntitlementService,
)

NOW = datetime(2026, 10, 30, 12, 0, tzinfo=timezone.utc)
SOON = NOW + timedelta(days=20)
PAST = NOW - timedelta(days=1)


# --- the pure tier rule (domain/billing.py) --------------------------------


def test_active_and_unlapsed_is_entitled():
    assert is_entitled("active", SOON, NOW) is True


@pytest.mark.parametrize("status", ["cancelled", "expired", "on_hold", "past_due", "", "weird"])
def test_only_active_status_is_entitled(status):
    assert is_entitled(status, SOON, NOW) is False


def test_a_lapsed_period_is_not_entitled():
    assert is_entitled("active", PAST, NOW) is False


def test_unknown_period_end_is_not_entitled():
    assert is_entitled("active", None, NOW) is False


def test_highest_active_tier_takes_the_best_entitled_row():
    rows = [
        EntitlementRow(Tier.PLUS, "active", SOON),
        EntitlementRow(Tier.PRO, "active", SOON),
    ]
    assert highest_active_tier(rows, NOW) is Tier.PRO


def test_a_cancelled_higher_tier_does_not_win():
    rows = [
        EntitlementRow(Tier.PLUS, "active", SOON),
        EntitlementRow(Tier.PRO, "cancelled", SOON),
    ]
    assert highest_active_tier(rows, NOW) is Tier.PLUS


def test_no_entitled_rows_is_free():
    rows = [EntitlementRow(Tier.PRO, "active", PAST)]
    assert highest_active_tier(rows, NOW) is Tier.FREE


def test_scan_cap_for_each_tier():
    assert scan_cap_for(Tier.FREE, free_cap=4, plus_cap=10, pro_cap=20) == 4
    assert scan_cap_for(Tier.PLUS, free_cap=4, plus_cap=10, pro_cap=20) == 10
    assert scan_cap_for(Tier.PRO, free_cap=4, plus_cap=10, pro_cap=20) == 20


# --- Standard Webhooks verification (providers/dodo_provider.py) -----------

SECRET = "whsec_" + base64.b64encode(b"a-test-signing-key-0123456789").decode()


def _sign(body: bytes, wid: str, ts: str, secret: str = SECRET) -> str:
    key = base64.b64decode(secret[len("whsec_"):])
    signed = wid.encode() + b"." + ts.encode() + b"." + body
    return base64.b64encode(hmac.new(key, signed, hashlib.sha256).digest()).decode()


def _provider(secret: str = SECRET) -> DodoPaymentProvider:
    return DodoPaymentProvider(
        api_key="", webhook_secret=secret, base_url="https://test.dodopayments.com"
    )


def _subscription_body(**over) -> bytes:
    payload = {
        "type": "subscription.active",
        "timestamp": "2026-10-30T12:00:00Z",
        "data": {
            "payload_type": "Subscription",
            "subscription_id": "sub_1",
            "status": "active",
            "product_id": "prod_plus_m",
            "next_billing_date": "2026-11-30T12:00:00Z",
            "metadata": {"user_id": "user-1"},
            "customer": {"customer_id": "cus_1"},
        },
    }
    payload["data"].update(over)
    return json.dumps(payload).encode()


def test_a_valid_signature_parses_the_event():
    body = _subscription_body()
    wid, ts = "msg_1", str(int(time.time()))
    headers = {"webhook-id": wid, "webhook-timestamp": ts,
               "webhook-signature": f"v1,{_sign(body, wid, ts)}"}
    event = _provider().verify_and_parse(body, headers)
    assert event.event_id == "msg_1"
    assert event.external_subscription_id == "sub_1"
    assert event.user_id == "user-1"
    assert event.product_id == "prod_plus_m"
    assert event.status == "active"
    assert event.period_end == datetime(2026, 11, 30, 12, 0, tzinfo=timezone.utc)


def test_a_tampered_body_is_rejected():
    body = _subscription_body()
    wid, ts = "msg_1", str(int(time.time()))
    sig = _sign(body, wid, ts)
    tampered = _subscription_body(status="active", product_id="prod_pro_m")
    headers = {"webhook-id": wid, "webhook-timestamp": ts, "webhook-signature": f"v1,{sig}"}
    with pytest.raises(WebhookVerificationError):
        _provider().verify_and_parse(tampered, headers)


def test_a_stale_timestamp_is_rejected():
    body = _subscription_body()
    wid, ts = "msg_1", str(int(time.time()) - 10 * 60)  # 10 minutes ago
    headers = {"webhook-id": wid, "webhook-timestamp": ts,
               "webhook-signature": f"v1,{_sign(body, wid, ts)}"}
    with pytest.raises(WebhookVerificationError):
        _provider().verify_and_parse(body, headers)


def test_missing_headers_are_rejected():
    with pytest.raises(WebhookVerificationError):
        _provider().verify_and_parse(_subscription_body(), {})


def test_an_empty_secret_never_verifies():
    body = _subscription_body()
    wid, ts = "msg_1", str(int(time.time()))
    headers = {"webhook-id": wid, "webhook-timestamp": ts,
               "webhook-signature": f"v1,{_sign(body, wid, ts)}"}
    with pytest.raises(WebhookVerificationError):
        _provider(secret="").verify_and_parse(body, headers)


def test_a_payment_event_is_not_treated_as_a_subscription():
    # payload_type Payment + a subscription_id present: must not become an
    # entitlement row (which would upsert a non-active status and drop to free).
    body = json.dumps({
        "type": "payment.succeeded",
        "timestamp": "2026-10-30T12:00:00Z",
        "data": {"payload_type": "Payment", "subscription_id": "sub_1",
                 "product_id": "prod_plus_m", "status": "succeeded",
                 "metadata": {"user_id": "user-1"}},
    }).encode()
    wid, ts = "m1", str(int(time.time()))
    headers = {"webhook-id": wid, "webhook-timestamp": ts,
               "webhook-signature": f"v1,{_sign(body, wid, ts)}"}
    event = _provider().verify_and_parse(body, headers)
    assert event.external_subscription_id is None


def test_a_missing_event_timestamp_is_rejected():
    body = json.dumps({"type": "subscription.active",
                       "data": {"payload_type": "Subscription", "subscription_id": "s"}}).encode()
    wid, ts = "m1", str(int(time.time()))
    headers = {"webhook-id": wid, "webhook-timestamp": ts,
               "webhook-signature": f"v1,{_sign(body, wid, ts)}"}
    with pytest.raises(WebhookVerificationError):
        _provider().verify_and_parse(body, headers)


# --- entitlement application (services/entitlements.py + LocalDB) ----------


@pytest.fixture
def billing_products(monkeypatch):
    """Map the two Dodo product ids used in these tests to tiers."""
    from src.config.settings import settings

    monkeypatch.setattr(settings, "DODO_PRODUCT_PLUS_MONTHLY", "prod_plus_m")
    monkeypatch.setattr(settings, "DODO_PRODUCT_PRO_MONTHLY", "prod_pro_m")
    monkeypatch.setattr(settings, "DAILY_SCAN_CAP", 4)
    monkeypatch.setattr(settings, "PLUS_SCAN_CAP", 10)
    monkeypatch.setattr(settings, "PRO_SCAN_CAP", 20)


@pytest.fixture
def db(tmp_path):
    return LocalDBProvider(db_path=str(tmp_path / "billing.db"))


def _event(*, event_id="msg_1", sub="sub_1", user="user-1", product="prod_plus_m",
           status="active", period_end=SOON, at=NOW, etype="subscription.active") -> BillingEvent:
    return BillingEvent(
        event_id=event_id, event_type=etype, occurred_at=at,
        external_subscription_id=sub, external_customer_id="cus_1",
        user_id=user, product_id=product, status=status, period_end=period_end,
    )


async def test_applying_an_active_plus_event_sets_the_tier(db, billing_products):
    svc = EntitlementService(db)
    assert await svc.apply(_event(product="prod_plus_m")) == APPLIED
    assert await svc.tier_for("user-1") is Tier.PLUS


async def test_a_duplicate_webhook_id_is_a_no_op(db, billing_products):
    svc = EntitlementService(db)
    assert await svc.apply(_event(event_id="dup")) == APPLIED
    assert await svc.apply(_event(event_id="dup")) == DUPLICATE
    assert await svc.tier_for("user-1") is Tier.PLUS


async def test_a_late_active_after_cancellation_stays_cancelled(db, billing_products):
    svc = EntitlementService(db)
    # The cancellation happened later in real time than the (now stale) active.
    await svc.apply(_event(event_id="e-cancel", status="cancelled",
                           at=NOW + timedelta(hours=2), etype="subscription.cancelled"))
    await svc.apply(_event(event_id="e-active-late", status="active", at=NOW))
    assert await svc.tier_for("user-1") is Tier.FREE


async def test_two_subscriptions_keep_the_higher_tier(db, billing_products):
    svc = EntitlementService(db)
    await svc.apply(_event(event_id="e1", sub="sub_plus", product="prod_plus_m"))
    await svc.apply(_event(event_id="e2", sub="sub_pro", product="prod_pro_m"))
    assert await svc.tier_for("user-1") is Tier.PRO
    # Cancelling the Pro one drops to Plus, not free.
    await svc.apply(_event(event_id="e3", sub="sub_pro", product="prod_pro_m",
                           status="cancelled", at=NOW + timedelta(hours=1)))
    assert await svc.tier_for("user-1") is Tier.PLUS


async def test_an_event_without_a_user_is_unlinked(db, billing_products):
    assert await EntitlementService(db).apply(_event(user=None)) == UNLINKED


async def test_an_unmapped_product_grants_nothing(db, billing_products):
    assert await EntitlementService(db).apply(_event(product="prod_unknown")) == UNKNOWN_PRODUCT
    assert await EntitlementService(db).tier_for("user-1") is Tier.FREE


async def test_a_non_subscription_event_is_ignored(db, billing_products):
    assert await EntitlementService(db).apply(_event(sub=None)) == IGNORED


# --- the scan cap the entitlement buys (get_scan_limiter wiring) -----------


@pytest.fixture
def billing_on(monkeypatch, billing_products):
    from src.config.settings import settings

    monkeypatch.setattr(settings, "BILLING_ENABLED", True)


async def test_free_user_gets_the_free_cap(db, billing_on, make_device):
    _, h = make_device()
    limiter = await get_scan_limiter(authorization=h["Authorization"], supabase=db)
    assert limiter.cap == 4


async def test_an_active_pro_entitlement_raises_the_cap(db, billing_on, make_device):
    user_id, h = make_device()
    await EntitlementService(db).apply(_event(user=user_id, sub="sub_pro", product="prod_pro_m"))
    limiter = await get_scan_limiter(authorization=h["Authorization"], supabase=db)
    assert limiter.cap == 20


async def test_billing_off_does_not_read_entitlements(db, make_device, monkeypatch):
    # Billing off must make NO entitlement read: if the read happened it would
    # blow up here, proving the property (not just that the cap is 4).
    from src.config.settings import settings

    monkeypatch.setattr(settings, "BILLING_ENABLED", False)
    _, h = make_device()

    async def boom(_self, _user_id):
        raise AssertionError("entitlements must not be read when billing is off")

    db.get_entitlements = boom.__get__(db, type(db))
    limiter = await get_scan_limiter(authorization=h["Authorization"], supabase=db)
    assert limiter.cap == settings.DAILY_SCAN_CAP


async def test_a_failed_entitlement_read_raises_not_free(db, billing_on, make_device):
    _, h = make_device()

    async def broken(_self, _user_id):
        raise ConnectionError("db down")

    db.get_entitlements = broken.__get__(db, type(db))
    with pytest.raises(ConnectionError):
        await get_scan_limiter(authorization=h["Authorization"], supabase=db)
