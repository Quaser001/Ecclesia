# DBA: calfit-data

Confirmed by the founder on 2026-10-28.

## Tables (live)
| Table | Purpose |
|---|---|
| `profiles` | conditions, allergies, diet, goals, body details |
| `scans` | one row per scored scan: `score` is integer tenths; `product_json`/`score_json` are JSON text in `jsonb` |
| `scan_usage` | daily scan counter (atomic `increment_scan_usage`); `rx:<user>` for prescriptions |
| `scan_feedback` | "Was this right?" (008); CHECK on known issues |
| `serving_memory` | user's serving size per product key (009) |
| `knowledge`, `alternatives`, `scan_findings` | legacy/knowledge; `scan_findings` unused |

## Access and storage
- **RLS is on with no policies everywhere.** Only the backend's service-role key can read or write. The Supabase linter's INFO notices about this are expected.
- **Private bucket `calfit-scans`:** photos at `scans/<user>/<id>.jpg`, served as one-hour signed links.

## Migrations
- **Applied live:** 001, 003–009.
- **002 (dev seed):** not applied live.

## Supabase advisor warnings
- `vector` extension sits in the public schema.
- `rls_auto_enable()` is Supabase's own event-trigger helper and can't be called as a normal function.

## Local data
- **`apps/api/data/food.db`** (SQLite): 764 products; ships in the image.
- **`apps/api/data/calfit.db`**: local dev store, git-ignored.
