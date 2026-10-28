# SRE: cross-cutting

Confirmed by the founder on 2026-10-28.

- **Telemetry in code:**
  - `X-Request-ID` on every response;
  - `calfit.access` (route template, status, duration);
  - `calfit.scan` `scan.completed` (stage timings, model, attempts, explanation outcome, identification, AI backend, saved).
- **Proposed in `docs/EVALS_AND_OBSERVABILITY.md` (not created):**
  - **Metrics:** `scan_count`, `scan_latency`, `explanation_fallbacks`, `model_fallbacks`.
  - **Alerts:**
    - failure rate above 30% for 30 minutes;
    - p95 latency above 15 s;
    - 5xx above 2%;
    - grounding fallbacks above 20%.
- **SLOs:** not defined yet. Suggested start: 99% of scans finish under 15 s; 99.5% of API requests succeed.
- **Weekly check:** `python -m scripts.eval_report --days 7`.
