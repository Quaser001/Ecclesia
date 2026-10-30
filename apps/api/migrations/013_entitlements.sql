-- Migration 013 — subscription entitlements (Dodo Payments)
--
-- NOT YET APPLIED. Show the founder and get approval before running it on the
-- live project, then record it in .10x/status.md (there is no migration table).
--
-- Two tables and one function. The backend (service_role) is the only writer;
-- the Flutter app never touches Postgres (agents.md §5). RLS is enabled with no
-- policies so anon/authenticated get nothing even if the public key leaks
-- (same pattern as migration 004). The ensure_rls event trigger (migration 011)
-- also enables RLS on these, but we enable it explicitly too.

-- One row per subscription (NOT per user): a person can hold more than one
-- (e.g. Pro bought while Plus is still active), and cancelling one must not
-- drop the other. The tier rule takes the highest still-active row.
CREATE TABLE IF NOT EXISTS entitlements (
    subscription_id TEXT PRIMARY KEY,          -- Dodo's subscription_id
    user_id         TEXT NOT NULL,             -- our per-profile id (see note below)
    tier            TEXT NOT NULL CHECK (tier IN ('plus', 'pro')),
    -- Dodo's status, stored verbatim. No CHECK on purpose: Dodo's status enum
    -- isn't fully documented, and a CHECK that rejected an unseen value would
    -- turn a webhook into a 500 and block processing. The code treats only
    -- 'active' as entitled and anything else as not — unknown fails safe.
    status          TEXT NOT NULL,
    period_end      TIMESTAMPTZ,               -- Dodo's next_billing_date
    customer_id     TEXT,
    -- The event timestamp last applied to this row. Guards ordering: a late
    -- 'active' must never overwrite a newer 'cancelled'.
    last_event_at   TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_entitlements_user ON entitlements (user_id);

ALTER TABLE entitlements ENABLE ROW LEVEL SECURITY;

-- Idempotency ledger: every webhook id we've processed. A retry (same id) is a
-- no-op. Carries no personal data, so it is kept even after a user is deleted
-- (so a late duplicate for them stays a no-op).
CREATE TABLE IF NOT EXISTS billing_webhook_events (
    webhook_id  TEXT PRIMARY KEY,
    event_type  TEXT,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE billing_webhook_events ENABLE ROW LEVEL SECURITY;

-- Record a verified webhook and apply it to the subscription, in ONE
-- transaction. Returns TRUE if the subscription row changed, FALSE for a
-- duplicate delivery or a stale (out-of-order) event. Never split into
-- mark-then-apply: a crash between them would drop a paid upgrade while making
-- Dodo's retries no-ops. SECURITY DEFINER + service_role only, like the scan
-- quota functions (migrations 005, 012).
CREATE OR REPLACE FUNCTION apply_billing_event(
    p_webhook_id      TEXT,
    p_event_type      TEXT,
    p_user_id         TEXT,
    p_subscription_id TEXT,
    p_customer_id     TEXT,
    p_tier            TEXT,
    p_status          TEXT,
    p_period_end      TIMESTAMPTZ,
    p_event_at        TIMESTAMPTZ
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rows INTEGER;
BEGIN
    -- Idempotency: a webhook id we've already recorded is a duplicate retry.
    INSERT INTO billing_webhook_events (webhook_id, event_type)
    VALUES (p_webhook_id, p_event_type)
    ON CONFLICT (webhook_id) DO NOTHING;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows = 0 THEN
        RETURN FALSE;
    END IF;

    -- Upsert the subscription, but only if this event is newer than the last
    -- one applied to it (ordering guard). A brand-new row always inserts.
    INSERT INTO entitlements
        (subscription_id, user_id, tier, status, period_end, customer_id, last_event_at)
    VALUES
        (p_subscription_id, p_user_id, p_tier, p_status, p_period_end, p_customer_id, p_event_at)
    ON CONFLICT (subscription_id) DO UPDATE SET
        user_id       = EXCLUDED.user_id,
        tier          = EXCLUDED.tier,
        status        = EXCLUDED.status,
        period_end    = EXCLUDED.period_end,
        customer_id   = EXCLUDED.customer_id,
        last_event_at = EXCLUDED.last_event_at,
        updated_at    = NOW()
    WHERE EXCLUDED.last_event_at > entitlements.last_event_at;
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    RETURN v_rows > 0;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.apply_billing_event(
    TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.apply_billing_event(
    TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ
) TO service_role;

-- NOTE on identity (ADR-008): user_id here is the per-profile device-token
-- subject. When Google sign-in lands (item 8), entitlements must be re-keyed
-- to the Google account id so a subscription survives a lost phone and can
-- cover family profiles. Store provider/subscription ids make that possible.
