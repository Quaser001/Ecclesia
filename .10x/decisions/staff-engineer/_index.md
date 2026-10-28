# Staff Engineer: cross-cutting

Confirmed by the founder on 2026-10-28.

## Standards in force
- **`AGENTS.md`** (repo root) is the project rulebook: inspect first, deterministic logic, Pydantic everywhere, provider ABCs, provenance, no secrets in the client, tests for every logic change.
- **Layering:**
  - Route handlers stay thin; logic lives in `domain/` (pure) and `services/`.
  - `rule_catalog.py` is the single reviewable source of thresholds, citations and curve heights.
- **Logging:** ids, timings and outcomes only. Never photos, label text, profile, explanations, raw exception text or user ids. Enforced by `tests/test_observability.py`; `httpx`/`httpcore` are kept at WARNING.
- **Tests never touch live services:** Supabase keys are blanked and the Open Food Facts lookup is disabled in `conftest.py`; fakes are injected through `app.dependency_overrides`.
- **Scores are integer tenths;** shown via `format_score` (API) and `formatScore` (app).
- **Translations:** edit the ARB files without reformatting (append or replace single lines), then run `flutter gen-l10n`.

## Environment quirks (Windows dev machine)
- **Git Bash rewrites `/sdcard/...` paths:** use `MSYS_NO_PATHCONV=1`.
- **PowerShell `>` corrupts binary output:** save on the phone and `adb pull` instead.
- **A USB blip clears `adb reverse`:** re-run `adb reverse tcp:8000 tcp:8000`.
- **MIUI blocks injected taps** unless "USB debugging (Security settings)" is on.
- **Use the real app,** `apps/mobile`. Never build from `_stale_nested_copy`.

Feature files: none yet.
