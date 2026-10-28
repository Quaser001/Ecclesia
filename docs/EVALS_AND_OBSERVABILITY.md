# Evals and observability: how we know CalFit is right

A health app earns trust by being able to answer these questions with numbers, not opinions:

1. **Is it right?** Does it read labels correctly, score them by the rules, and never miss an allergen?
2. **Is it up?** Are scans succeeding, and fast enough?
3. **When it fails, why?** Which step failed, which model, for which kind of photo?

Evals answer the first question. Observability (logs and metrics) answers the other two.

## The four checks

| Check | What it measures | Where | When to run |
|---|---|---|---|
| Rule tests | Scoring, matching and nutrient levels give the exact expected answer | `apps/api/tests/` (pytest) | Every change; must pass before merge |
| Extraction eval | Gemini's label reading against hand-labelled photos: allergen recall, allergen precision, nutrition error | `scripts/run_eval.py --csv <labels.csv>` | Before switching model, prompt or AI provider |
| Grounding guard | Every AI explanation is checked against the findings before the user sees it; ungrounded text is replaced by the rule summary | `services/explanation_service.py`, counted in logs as `explanation` | Every scan, automatically |
| User feedback | "Was this result right?" on each scan | `scripts/eval_report.py --days 7` | Weekly, and before each release |

**Why the rule tests carry so much weight.** Scoring is deterministic, so a test gives a definite pass or fail. The AI only reads labels and writes explanations, which is why it needs the other three checks.

### The extraction eval, step by step

The script exists but needs labelled data:

1. Collect 50–100 product photos. Use real Indian packs, a mix of categories, and some blurry or angled shots on purpose.
2. Put them in `data/eval/photos/`.
3. For each photo, fill one row of the CSV by reading the pack yourself. Columns: product, allergens, may-contain, sodium, sugar, saturated fat.
4. Run `python -m scripts.run_eval --csv data/eval/labels.csv`.
5. Keep the report, and compare it with the next run.

Targets for launch:

- **Allergen recall at least 0.98.** A missed allergen is the worst failure.
- **Allergen precision at least 0.90.**
- **Sodium and sugar within 20% on at least 85% of rows.**

Re-run the eval whenever you change `GEMINI_MODEL`, the extraction prompt, or `GEMINI_BACKEND`. Moving to Vertex AI uses the same model, but verify it anyway.

### User feedback

- One answer per scan, from a fixed list of issues with no free text. Stored in `scan_feedback`, which is deleted with the user's data.
- `eval_report.py` exits with an error in two cases:
  - accuracy is below **85%** on at least 30 answers;
  - **any** "missed an allergen" report arrives.
- Treat a missed-allergen report like a bug report. Open that scan and find out why.

## What the server logs

Every request gets an id (`X-Request-ID`, returned in the response) that appears on every log line it causes. When a user reports a problem, that id finds everything that happened.

**One line per request** (`calfit.access`): method, route template (`/scans/{scan_id}`), status, duration.

**One line per scan** (`calfit.scan`, `event = scan.completed`):

| Field | Meaning |
|---|---|
| `outcome` | `scored` or `insufficient_data` (label unreadable) |
| `stage_ms` | Milliseconds for each pipeline step (`analyze_photo`, `match_product`, `score_product`, `generate_explanation`, ...) |
| `total_ms` | Whole scan |
| `model`, `model_attempts` | Which Gemini model read the label. Attempts above 1 means the main model failed and a fallback answered. |
| `explanation` | `llm` (passed the grounding guard), `fallback_ungrounded` (guard rejected it) or `fallback_error` (AI call failed) |
| `ai_backend` | `developer_api` or `vertex`. Lets you prove from logs that production uses the private plan. |
| `extraction_confidence`, `findings`, `alternatives`, `verified_alternatives`, `nutrient_levels`, `suitability`, `saved` | Shape of the result |

### Never logged

- Photos.
- Label text and product names tied to a person.
- Profile fields.
- Explanations.
- Raw exception text. Provider and database errors can echo the request, and the request holds health conditions. Only the error's type is logged.

Library logs follow the same rule. `httpx` and `httpcore` are kept at warnings only, because their INFO lines print Supabase URLs that contain user ids (`user_id=eq.<id>`). Uvicorn's own access log is off (`--no-access-log`) because it prints raw paths; `calfit.access` replaces it with route templates.

`tests/test_observability.py` runs a scan with a profile and fails if any of these appear in the log line. A pro treats logs as a data store: they are kept for weeks and read by more people than the database.

## Turning it on in production (Cloud Run)

1. **Use JSON logs.** Set `LOG_FORMAT=json`; it is already in `DEPLOY_CLOUD_RUN.md`. Cloud Logging then makes every field searchable, for example `jsonPayload.event="scan.completed" AND jsonPayload.outcome="insufficient_data"`.

2. **Create log-based metrics.** Use Logging → Log-based metrics, or `gcloud logging metrics create`:
   - `scan_count`: a counter on `jsonPayload.event="scan.completed"`, with label `outcome`.
   - `scan_latency`: a distribution on `jsonPayload.total_ms` for the same filter.
   - `explanation_fallbacks`: a counter on `jsonPayload.explanation!="llm"`.
   - `model_fallbacks`: a counter on `jsonPayload.model_attempts>1`.

3. **Create alerts.** Use Monitoring → Alerting, and send them to your email:

   | Alert | Fires when | Usually means |
   |---|---|---|
   | Scan failure rate | `insufficient_data` is over 30% of scans for 30 min | Model outage, quota exhausted, or a bad deploy |
   | Slow scans | p95 `total_ms` is over 15 s for 15 min | Model slowness; check `stage_ms.analyze_photo` |
   | Server errors | Any 5xx on `calfit.access` over 2% for 10 min | A bug, or Supabase is down |
   | Grounding fallbacks | `explanation_fallbacks` is over 20% of scans for 1 h | Prompt drift after a model change |

4. **Run the eval report weekly.** Run `python -m scripts.eval_report --days 7`, or schedule it later. Paste the numbers into the release notes.

## What the app could add later

- **Crash reporting**, with Firebase Crashlytics or Sentry. It catches app crashes the server never sees. It needs a new SDK, a privacy-policy line and a consent decision, so it is listed in the market checklist rather than added silently.
- **Sending `X-Request-ID` from the app**, so a "report a problem" screen can include it.
