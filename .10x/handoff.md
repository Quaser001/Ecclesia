# Handoff

**From:** Production hardening (2026-10-29). **To:** the founder (review and commit), then DevOps (deploy).

- **What changed:** 47 audited issues were verified, and the fix-now set was implemented. See `specs/2026-10-29-production-hardening.md`, ADR-006, and `reviews/2026-10-29-production-hardening.md`.
- **New rules for everyone (ADR-006):**
  - Production fails loudly at startup.
  - A failed dependency is a 503, never a quiet fallback.
  - Scoring never runs on a profile that failed to load.
- **Run from `apps/api/.venv`,** which matches `uv.lock`. The root `.venv` is stale: it has FastAPI 0.141 and holds all 22 known vulnerabilities, and it can be deleted.
- **Check every key works:** `cd apps/api && .venv/Scripts/python.exe -m src.check_config`. On 2026-10-29 it reports the Gemini key as invalid.

- **Sources of truth:**
  - `AGENTS.md` (rules);
  - `docs/MARKET_READY_CHECKLIST.md` (progress and decisions);
  - `docs/SCORING_FORMULA.md`, `docs/AI_PROVIDER_OPTIONS.md`, `docs/EVALS_AND_OBSERVABILITY.md`, `docs/DEPLOY_CLOUD_RUN.md`, `docs/PRIVACY_POLICY.md`;
  - `docs/BUILDER_NOTES.md` (lessons).
- **Architecture:** `decisions/architect/_index.md` and ADRs 001–005.
- **Run locally:** see `decisions/devops/cloud-run-deploy.md`. Phone: the founder's Android (find its serial with `adb devices`; not recorded in the repo).
- **Never touch the founder's real account** (its id is in the founder's local notes, not the repo) without explicit approval. Use throwaway accounts.
- **Discovery findings were confirmed by the founder** on 2026-10-28. New features start with a brainstorm and an ADR before code.
