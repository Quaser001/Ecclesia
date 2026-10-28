# Architect: cross-cutting

Confirmed by the founder on 2026-10-28.

## Components
```
Flutter app ──HTTPS + device token──> FastAPI (apps/api/src)
   api/v1/*            route handlers only (validation, auth, HTTP errors)
   orchestration/      LangGraph scan pipeline (scan_graph.py)
   domain/             pure logic: models, rule_catalog, scoring_rules,
                       score_formula, nutrient_levels, food_taxonomy, identity
   services/           identification, alternatives, explanation, insights,
                       serving_memory, nutrition_merge, rate_limit, body_metrics
   providers/          interfaces + Gemini, Supabase (DB + storage), local
                       SQLite, Open Food Facts lookup
   repositories/       food.db access + Open Food Facts mapping
   observability.py    request ids, JSON logs, per-scan trace
```

## Boundaries and rules (from AGENTS.md)
- **The LLM reads and explains only. It never scores, decides or invents products.** Gemini output is parsed into Pydantic models; unknown stays None.
- **Every external service sits behind an ABC** in `providers/interfaces.py` or `providers/food_lookup.py`.
- **Missing data stays missing.** No fake fallbacks: failures are reported as failures.

## Main data flow (scan)
1. **analyze_photo:** Gemini reads the label (temperature 0, fixed seed, model fallback chain).
2. **validate_extraction:** the confidence gate. It is skipped for front-only photos.
3. **match_product:** strict match against food.db.
4. **check_scoreable:** anything to score? If not → **identify_product** (food.db, then one Open Food Facts search, then the decision: confident, confirm, choose, retake, not_found or unavailable).
5. **apply_serving_memory**
6. **retrieve_knowledge**
7. **load_profile**
8. **score_product:** rules plus formula.
9. **generate_explanation:** Gemini, then the grounding guard, with a rule-based fallback.
10. **find_alternatives:** same category, drinks for drinks.
11. **upload_image:** private bucket.
12. **persist**, then one `scan.completed` log line.

`POST /scans/confirm` enters at step 5 with a product the server fetches again by code.

## Failure modes handled
- **Gemini down:** the model fallback chain, then a clear "couldn't read" message.
- **Open Food Facts down:** status UNAVAILABLE, never shown as "not found".
- **Explanation fails the grounding check:** the rule-based explanation is used instead.
- **A rule crashes:** the score is capped at 7.9.
- **Storage upload fails:** this doesn't block the scan.

Feature files: `scan-pipeline.md`, `scoring-formula.md`, `front-of-pack-identification.md`. ADRs 001–005.
