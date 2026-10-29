-- Migration 010: proof of consent (DPDP Act s.6(10), Rules r.3).
--
-- One row each time a person agrees to the privacy notice shown in the app:
-- which notice version, that they said they are 18 or older, and when. The
-- server refuses to save a health profile, score a scan or read a
-- prescription for a user without an un-withdrawn row for the current
-- version (src/services/consent.py).
--
-- "Delete my data" does not delete these rows; it sets withdrawn_at. A row
-- holds no health data (an id, a version, a yes and two times), and it is the
-- record that the processing before the delete was consented to.
-- RLS on with no policies: only the backend's service_role key can reach it.

CREATE TABLE IF NOT EXISTS consents (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id          TEXT NOT NULL,
    notice_version   TEXT NOT NULL CHECK (length(notice_version) BETWEEN 1 AND 32),
    adult_confirmed  BOOLEAN NOT NULL CHECK (adult_confirmed),
    agreed_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    withdrawn_at     TIMESTAMPTZ
);

-- The gate's lookup: "does this user have a live consent for this version?"
CREATE INDEX IF NOT EXISTS consents_user_live
    ON consents (user_id, notice_version)
    WHERE withdrawn_at IS NULL;

ALTER TABLE consents ENABLE ROW LEVEL SECURITY;
