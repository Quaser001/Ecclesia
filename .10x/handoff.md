# Handoff

**From:** the 2026-10-29 session. It covered:
- the Keystore token move;
- the mobile security audit;
- the DPDP Rules check and the consent notice;
- migrations 010–012;
- the production-readiness review;
- the scan-reliability fixes.
**To:** the next chat. Start by reading `status.md`, then this file.

## Start here
1. **What's next:** `.10x/reviews/2026-10-29-production-readiness.md`, the ticked checklist. Its "Order of work" is the plan. Items 1–3, 5 and 6 are done (Cloud Run deployed 2026-10-29, crash reporting and release keystore added 2026-10-30; details in `status.md`). Next is: Supabase Pro (item 4, founder does in dashboard), Play Console (item 7), then Google sign-in (item 8), then payments (item 9). Still pending from item 3: Gemini quota cap (GCP Console), and optional `--min-instances 1`. **Back up the keystore** (`calfit-upload.jks` + `key.properties`) to two safe places before anything else.
2. **DPDP:** `.10x/reviews/2026-10-29-dpdp-rules.md`. The duties apply from 13 May 2027. Open items: the breach notice, seeing whose data was accessed, and the Rule 8(3) question for a lawyer.
3. **Rules for every edit:** `agents.md` sections 5–6 (loaded through `CLAUDE.md`).

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
- **Live scan check:**
  - with a throwaway identity, register, then `POST /api/v1/consent`, then scan;
  - every scan route answers 428 until the person agrees to the notice;
  - send an `Idempotency-Key` (UUID) to make retries safe.
- **"Waiting For Debugger" on the phone:** run `adb shell am clear-debug-app`.
- **Phone not seen by adb:** check the cable, choose "File transfer", and allow USB debugging. Windows showing "POCO M4 Pro" but adb seeing nothing means debugging isn't allowed yet.
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
- **Supabase changes:** show the migration and ask before applying it to the live project. Record it in `status.md`.
- **Never tick the consent box for the founder.** It's their consent.
- **Only synthetic prescriptions,** and never to the free Gemini tier.
- **On Pro:** keep multi-agent workflows small (about 4–6 agents); reuse earlier results.
- **The founder is new to app development.** Explain the why briefly, in plain words.
