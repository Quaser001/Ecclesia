-- Migration 012: give back a scan that failed on our side.
--
-- The daily cap is taken before the work (increment_scan_usage, so two
-- concurrent scans can't both slip under it). When the scan then fails
-- because of us or an upstream service (a 5xx: Gemini down, a timeout), the
-- API calls this to give the scan back. Never below zero, today only.
-- Locked to service_role like increment_scan_usage (migration 005).

CREATE OR REPLACE FUNCTION refund_scan_usage(p_user_id TEXT)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE scan_usage
       SET scan_count = GREATEST(scan_count - 1, 0)
     WHERE user_id = p_user_id
       AND usage_date = (NOW() AT TIME ZONE 'UTC')::DATE
    RETURNING scan_count INTO v_count;
    RETURN COALESCE(v_count, 0);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.refund_scan_usage(TEXT) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.refund_scan_usage(TEXT) TO service_role;
