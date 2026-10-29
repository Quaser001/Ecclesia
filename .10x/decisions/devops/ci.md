# DevOps: CI (2026-10-29)

**Workflow:** `.github/workflows/ci.yml`. **Status:** written and simulated locally, not yet run on GitHub (not pushed).

## What it does
- **Backend job:** uv 0.11.18 (same as `uv.lock` and the Dockerfile).
  - `uv sync --frozen`
  - `ruff check src tests --select F,E9` (real-bug rules only)
  - `pytest -q`
  - `pip-audit` on the exported lock (what ships, not a dev venv)
- **App job:** Flutter 3.41.9 stable, then `flutter pub get`, `analyze`, `test`.
- **Triggers:** push to `main` and every pull request. Read-only token. A newer push cancels the stale run. Time limits are 15 and 20 minutes.
- **Deploys:** none from CI. Deploying stays a manual step (`cloud-run-deploy.md`) until Cloud Run exists.

## Options weighed
| Option | Why / why not |
|---|---|
| **GitHub Actions (chosen)** | Free for this repo, lives next to the code, needs no cloud account |
| Google Cloud Build | Waits on GCP billing; better when deploys are automated |
| Local pre-push script | Leaves no shared record and is easy to skip |

## Found while building it
- 2 tests passed only because of the developer's `.env` (a real Gemini key). `tests/conftest.py` now blanks the AI settings for every test, so a laptop behaves like CI. Those tests use a stand-in provider.
- The CI run was simulated on a clean copy of the repo, without `.env` and with a fresh venv from the lock. Results: ruff clean, 506 tests pass, pip-audit 0.
- The app job ran locally (66 tests, analyze clean), but not on a clean copy.

## Rollback
Delete or disable `.github/workflows/ci.yml`. It touches nothing outside GitHub.

## Later
- Pin actions to commit SHAs, with Dependabot to update them.
- Path filters, if runs get slow.
- Widen ruff and mypy as the existing 105 mypy errors are paid down.
