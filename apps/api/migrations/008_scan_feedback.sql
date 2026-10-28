-- Migration 008: "Was this right?" answers on scan results.
--
-- One row per scan (the latest answer wins). No free text is stored, so no
-- health details can leak in. The answers feed the accuracy numbers in
-- scripts/eval_report.py. RLS on with no policies: only the backend's
-- service_role key can read or write, the same as every other table.

CREATE TABLE IF NOT EXISTS scan_feedback (
    scan_id     TEXT PRIMARY KEY REFERENCES scans(scan_id) ON DELETE CASCADE,
    user_id     TEXT NOT NULL,
    accurate    BOOLEAN NOT NULL,
    issues      TEXT[] NOT NULL DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT scan_feedback_issues_known CHECK (
        issues <@ ARRAY['wrong_product', 'wrong_nutrition', 'wrong_ingredients',
                        'missed_allergen', 'score_unfair', 'other']::TEXT[]
    )
);

CREATE INDEX IF NOT EXISTS scan_feedback_user_id_idx ON scan_feedback(user_id);
CREATE INDEX IF NOT EXISTS scan_feedback_created_at_idx ON scan_feedback(created_at);

ALTER TABLE scan_feedback ENABLE ROW LEVEL SECURITY;
