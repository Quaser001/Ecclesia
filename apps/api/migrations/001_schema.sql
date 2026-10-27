-- CalFit Database Schema — Migration 001
-- Run this in your Supabase SQL editor or via psql
-- Requires the pgvector extension

-- ---------------------------------------------------------------------------
-- Enable extensions
-- ---------------------------------------------------------------------------
-- The extension is named `vector`, not `pgvector`. Using the wrong name
-- makes this whole migration fail on a fresh Supabase project.
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ---------------------------------------------------------------------------
-- profiles
-- Stores user health profiles for personalized evaluation
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profiles (
    user_id        TEXT PRIMARY KEY,
    name           TEXT,
    -- Arrays of enum values stored as text[]
    health_conditions    TEXT[] DEFAULT '{}',
    allergies            TEXT[] DEFAULT '{}',
    dietary_preferences  TEXT[] DEFAULT '{}',
    health_goals         TEXT[] DEFAULT '{}',
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- knowledge
-- CalFit knowledge base: ingredients, nutrients, condition-relevance facts
-- product_data and general_knowledge are kept in the same table,
-- distinguished by the source column
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge (
    id             BIGSERIAL PRIMARY KEY,
    topic          TEXT NOT NULL,
    content        TEXT NOT NULL,
    relevance_tags TEXT[] DEFAULT '{}',
    source         TEXT NOT NULL DEFAULT 'calfit_knowledge_base',
    -- Optional: vector embedding for semantic search
    embedding      vector(768),
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Vector similarity index. Deliberately NOT created here: an ivfflat index
-- built on an empty table has no useful centroids. Create it once the
-- knowledge table actually holds embeddings:
--   CREATE INDEX knowledge_embedding_idx
--       ON knowledge USING ivfflat (embedding vector_cosine_ops)
--       WITH (lists = 50);

-- GIN index for tag-based queries
CREATE INDEX IF NOT EXISTS knowledge_tags_idx
    ON knowledge USING gin (relevance_tags);

-- ---------------------------------------------------------------------------
-- scans
-- Persists each product scan result
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS scans (
    scan_id        TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::TEXT,
    user_id        TEXT NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    scanned_at     TIMESTAMPTZ DEFAULT NOW(),
    product_name   TEXT,
    brand          TEXT,
    category       TEXT,
    score          INTEGER NOT NULL DEFAULT 0 CHECK (score BETWEEN 0 AND 100),
    suitability    TEXT NOT NULL,
    image_url      TEXT,
    -- Full JSON payloads for replay/debugging
    product_json   JSONB,
    score_json     JSONB,
    explanation    TEXT,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS scans_user_id_idx ON scans(user_id);
CREATE INDEX IF NOT EXISTS scans_scanned_at_idx ON scans(scanned_at DESC);

-- ---------------------------------------------------------------------------
-- scan_findings
-- Individual findings triggered during a scan (normalized for querying)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS scan_findings (
    id             BIGSERIAL PRIMARY KEY,
    scan_id        TEXT NOT NULL REFERENCES scans(scan_id) ON DELETE CASCADE,
    rule_id        TEXT NOT NULL,
    severity       TEXT NOT NULL,
    title          TEXT NOT NULL,
    detail         TEXT NOT NULL,
    nutrient       TEXT,
    score_impact   INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS scan_findings_scan_id_idx ON scan_findings(scan_id);

-- ---------------------------------------------------------------------------
-- alternatives
-- Stores verified product alternatives from the knowledge base
-- (separate from criteria-guidance which is generated inline)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS alternatives (
    id             BIGSERIAL PRIMARY KEY,
    name           TEXT NOT NULL,
    brand          TEXT,
    category       TEXT NOT NULL,
    reason         TEXT NOT NULL,
    health_tags    TEXT[] DEFAULT '{}',
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS alternatives_category_idx ON alternatives(category);
CREATE INDEX IF NOT EXISTS alternatives_health_tags_idx ON alternatives USING gin (health_tags);
