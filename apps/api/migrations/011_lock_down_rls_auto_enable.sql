-- Migration 011: only the database itself may run rls_auto_enable().
--
-- Supabase's "enable RLS on new tables" helper: the event trigger
-- `ensure_rls` runs it after every CREATE TABLE in public. It was also
-- callable over the API with the public (anon) key, /rest/v1/rpc/
-- rls_auto_enable, which the security advisor flags. Event triggers don't
-- check EXECUTE when they fire, so revoking it keeps the trigger working.

REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;
