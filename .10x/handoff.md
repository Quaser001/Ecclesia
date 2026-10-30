# Handoff

**From:** the 2026-10-30 session. It covered (on top of the 2026-10-29 work below):
- crash reporting (production-readiness item 5) and the release keystore + signed bundle (item 6);
- a Play Console reference checklist (`.10x/play-console-checklist.md`);
- a system-design hardening audit: fixed the delete-during-scan erasure race and capped `/client-errors` logging, added a Cloud Run rollback runbook (commit `3c70511`, pushed).
**Earlier (2026-10-29):** the Keystore token move; the mobile security audit; the DPDP Rules check and consent notice; migrations 010–012; the production-readiness review; the scan-reliability fixes.
**To:** the next chat. Start by reading `status.md`, then this file.

## Start here — the next session is gcloud + Play Console
The work now is two things, both mostly in consoles the founder drives; the agent prepares, guides and verifies.

1. **gcloud — the spend backstop (pending from production-readiness item 3).**
   - **Gemini quota cap** — the real hard stop on the AI bill (the ₹500 budget only emails; the per-IP caps reset when Cloud Run scales to zero). GCP Console → IAM & Admin → Quotas → filter "Generative Language API" → cap requests/min ≈ 60 and requests/day ≈ 5,000. Bills to project `gen-lang-client-0252924706` ("aaa1"), which the budget covers.
   - `--min-instances 1` is optional (≈₹1,000/month idle) — skip for now. `--max-instances 3` and `TRUSTED_PROXY_HOPS=1` are already in the deploy config (`docs/DEPLOY_CLOUD_RUN.md`), so the caps are correctly per-phone.
   - Rollback runbook is in `docs/DEPLOY_CLOUD_RUN.md` §7 if a deploy goes bad.

2. **Play Console (production-readiness item 7).** The reference is **`.10x/play-console-checklist.md`** — Data safety answers, health declaration, content rating, and the store-listing text are all written there. Agent work that remains:
   - **Privacy policy blanks** in `apps/mobile/assets/legal/privacy_policy.md` and `docs/PRIVACY_POLICY.md`: publisher legal name, contact email, grievance officer name + email (founder supplies the facts; agent edits both copies so they stay identical).
   - **Host the policy at a public URL** (GitHub Pages is free — the repo is `Quaser001/Ecclesia`); Play needs the URL, and the app's Settings screen already links the bundled copy.
   - **Store-listing assets:** icon (512×512, already generated), phone screenshots, feature graphic (1024×500).
   - Then the founder fills the console forms and uploads `app-release.aab` to a closed-testing track (12 testers, 14 days).

3. **Still queued after that:** Supabase Pro (item 4, founder does in dashboard — also unlocks backups), then Google sign-in (item 8), then payments (item 9).

4. **Before any of it — two safety items that haven't been done:**
   - **Back up the keystore** (`apps/mobile/android/calfit-upload.jks` + `apps/mobile/android/key.properties`) to two safe places. Losing it means you can never update the app on Play.
   - **Rotate every key exposed in chat history** (Gemini, Groq, Cerebras, Supabase service-role, `AUTH_SECRET_KEY`) before launch. Note: rotating `AUTH_SECRET_KEY` invalidates every phone's token — see the warning in `docs/DEPLOY_CLOUD_RUN.md` §1.
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
