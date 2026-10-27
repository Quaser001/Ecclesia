-- Migration 005 — restrict the quota function to the backend
-- Applied to the live project as migration `003_lock_down_quota_function`.
--
-- A SECURITY DEFINER function in the public schema is reachable over
-- /rest/v1/rpc with the public anon key. Left open, anyone could call it and
-- burn through another user's daily scan allowance.

REVOKE EXECUTE ON FUNCTION public.increment_scan_usage(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.increment_scan_usage(TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.increment_scan_usage(TEXT) FROM authenticated;
GRANT  EXECUTE ON FUNCTION public.increment_scan_usage(TEXT) TO service_role;
