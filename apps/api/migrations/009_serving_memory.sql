-- Migration 009: serving sizes users told us, remembered per product.
--
-- When a scan's label numbers have no serving size, the app asks the user how
-- big one serving is and whether the label's numbers are per 100 g/ml or per
-- serving. The answer is stored here (one row per user and product) and used
-- the next time they scan that product. Scores already given never change.
-- RLS on with no policies: only the backend's service_role key can reach it.

CREATE TABLE IF NOT EXISTS serving_memory (
    user_id         TEXT NOT NULL,
    product_key     TEXT NOT NULL,
    serving_size_g  NUMERIC NOT NULL CHECK (serving_size_g > 0 AND serving_size_g <= 5000),
    label_basis     TEXT NOT NULL CHECK (label_basis IN ('per_100', 'per_serving')),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, product_key)
);

ALTER TABLE serving_memory ENABLE ROW LEVEL SECURITY;
