# Handoff

**From:** the 2026-10-28/29 session (production hardening, data audit, family profiles, CI).
**To:** the next chat. Start by reading `status.md`, then this file.

## Read first
- **Rules:** `AGENTS.md`.
- **Decisions:** ADRs 001–008, especially:
  - 006: fail loudly; no silent fallbacks;
  - 007: ratings are history;
  - 008: family profiles = separate identities.
- **Reviews:** `reviews/2026-10-29-production-hardening.md` and `reviews/2026-10-29-data-privacy-audit.md`.
- **Docs:** `docs/` (scoring formula, deploy, privacy policy; the app keeps an identical copy of the policy in `apps/mobile/assets/legal/`).

## How to run (Windows)
- **Python:** always use `apps/api/.venv`, which matches `uv.lock`. The root `.venv` is stale; don't use it.
- **Backend:** `cd apps/api && .venv/Scripts/python.exe -m uvicorn src.main:app --host 127.0.0.1 --port 8000 --no-access-log`.
- **Check that keys work:** `.venv/Scripts/python.exe -m src.check_config`.
- **Tests:**
  - backend: `.venv/Scripts/python.exe -m pytest -q`;
  - app: `cd apps/mobile && flutter analyze && flutter test`.
- **Phone:**
  - adb lives at `%LOCALAPPDATA%/Android/Sdk/platform-tools/adb.exe` (not on PATH);
  - prefix commands with `MSYS_NO_PATHCONV=1` in Git Bash;
  - run `adb reverse tcp:8000 tcp:8000` after every reconnect;
  - build with `flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8000`.
  - Taps work only with "USB debugging (Security settings)" on. Find the serial with `adb devices`.

## Working agreements with the founder
- **Commit and push only when asked.** Never push `backup/pre-scrub-*`.
- **Never print `.env` values**; the founder adds keys themselves.
- **Never modify the founder's own account or scans without explicit approval.** Use throwaway accounts.
- **Only synthetic prescriptions,** and never to the free Gemini tier.
- **On Pro:** keep multi-agent workflows small (about 4–6 agents); reuse earlier results.
- **The founder is new to app development.** Explain the why briefly, in plain words.
