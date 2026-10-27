-- Migration 004 — lock down direct client access, add the daily scan quota
-- Applied to the live project as migration `002_rls_and_scan_usage`.

-- The Flutter app never talks to Postgres directly: it goes through the
-- FastAPI backend, which uses the service_role key (service_role bypasses
-- RLS). Enabling RLS with no policies therefore denies every anon and
-- authenticated request while leaving the backend working. If the public
-- anon key ever leaks, the database stays shut.
ALTER TABLE profiles      ENABLE ROW LEVEL SECURITY;
ALTER TABLE knowledge     ENABLE ROW LEVEL SECURITY;
ALTER TABLE scans         ENABLE ROW LEVEL SECURITY;
ALTER TABLE scan_findings ENABLE ROW LEVEL SECURITY;
ALTER TABLE alternatives  ENABLE ROW LEVEL SECURITY;

-- Daily scan counter. Counts ATTEMPTS, not saved scans: an unreadable label
-- still costs a Gemini call, so it must count against the quota.
CREATE TABLE IF NOT EXISTS scan_usage (
    user_id     TEXT NOT NULL,
    usage_date  DATE NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC')::DATE,
    scan_count  INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, usage_date)
);

ALTER TABLE scan_usage ENABLE ROW LEVEL SECURITY;

-- Atomically increment today's count and return the new value. Returning the
-- post-increment count lets the caller reject the request without a separate
-- read, so two concurrent scans cannot both slip through the cap.
CREATE OR REPLACE FUNCTION increment_scan_usage(p_user_id TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    INSERT INTO scan_usage (user_id, usage_date, scan_count)
    VALUES (p_user_id, (NOW() AT TIME ZONE 'UTC')::DATE, 1)
    ON CONFLICT (user_id, usage_date)
    DO UPDATE SET scan_count = scan_usage.scan_count + 1
    RETURNING scan_count INTO v_count;

    RETURN v_count;
END;
$$;
