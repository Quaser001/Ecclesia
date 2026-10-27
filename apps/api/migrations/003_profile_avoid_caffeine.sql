-- Migration 003 — caffeine sensitivity flag
-- Applied to the live project as migration `004_profile_avoid_caffeine`.
--
-- This column was added to the profile model and to the SQLite provider but
-- never to the Postgres schema, so upsert_profile failed against Supabase.
-- It is a user-set sensitivity toggle, not a medical claim.

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS avoid_caffeine BOOLEAN NOT NULL DEFAULT FALSE;
