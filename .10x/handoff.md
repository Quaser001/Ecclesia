# Handoff

**From:** the 2026-10-30 (second) session — commit `32bdb2a`, pushed to `origin/main`:
- **Subscription paywall page** (`apps/mobile/lib/features/subscription/`): three tiers (Free 4/day · Plus 10/day ₹199/mo · Pro 20/day ₹249/mo), monthly/annual toggle, one-CTA Hick's-Law layout, honest `ComingSoonSubscriptionService` stub (no fake success), debug-only entry at the bottom of Settings. 5 new widget tests.
- **Free scan cap 50 → 4/day** (`DAILY_SCAN_CAP`). Failed scans already don't count. Paid-tier caps (10/20) wait on entitlement.
- **Play-console-checklist Data-safety fixes** (processor transfers aren't "sharing"; added crash-logs data type).
- **Located the exact Gemini quota rows** (deferred by founder) and **adopted Hick's Law app-wide** (one obvious action per screen).
- Full detail, and the precise next-step instructions, are in `status.md` (top three dated sections).
**Earlier (2026-10-30, first):** crash reporting (item 5), release keystore + signed bundle (item 6), Play Console checklist, erasure-race + `/client-errors` hardening (commit `3c70511`).
**Earlier (2026-10-29):** Keystore token move; mobile security audit; DPDP Rules check + consent notice; migrations 010–012; production-readiness review; scan-reliability fixes.
**To:** the next chat. Read `status.md` first (it has the live detail), then this file.

## Start here — ordered for the next session
The founder drives consoles; the agent prepares, guides, verifies, and edits code. Commit/push only when asked; never print `.env` values; Supabase changes need the migration shown and approval first.

1. **Reduce app languages to English + Hindi** (founder asked 2026-10-30). Remove Assamese/Bangla/Khasi: delete `lib/l10n/app_as.arb|app_bn.arb|app_kha.arb` + their generated `app_localizations_as|bn|kha.dart`; trim `supportedLanguages` in `lib/l10n/l10n.dart` to en+hi; re-run `flutter gen-l10n`; then `flutter analyze && flutter test` (the settings "app shell renders in <name>" loop auto-adjusts; grep for stray `as`/`bn`/`kha`). Exact steps in `status.md`.

2. **Privacy policy (blocks Play).** Fill the 4 blanks in BOTH `apps/mobile/assets/legal/privacy_policy.md` and `docs/PRIVACY_POLICY.md` (keep identical — `privacy_policy_copy_test.dart` enforces it): publisher legal name + address, contact email, grievance officer name + email, and the cross-ref on line 106. Founder supplies the facts (ask; don't invent). Then **host at a public URL** — a *small separate public repo* via GitHub Pages (do NOT make the monorepo public: `docs/DEPLOY_CLOUD_RUN.md` has project IDs/service account). The app shows the bundled copy already (no `url_launcher`), so only Play needs the URL. Rebuild `app-release.aab` after editing (the policy is a bundled asset). Consider tightening launch-time hedging ("when launched", "will run in India", "draft") to present tense — show the founder first.

3. **Dodo payments — groundwork built (2026-10-30), test mode, not yet turned on.** Viability settled: India = User Choice Billing only, so Dodo can't be the sole in-app path; founder chose **D→A** (web checkout + in-app entitlement, least Play risk). Backend done: `/billing/checkout|webhook|status`, entitlements + idempotency, tier-aware scan cap behind `BILLING_ENABLED` (off by default). Full detail + the exact founder steps are in `status.md` (top section) and `.10x/reviews/2026-10-30-dodo-play-billing-viability.md`. **Next, to turn it on (founder-driven):** apply **migration 013** (show + approve first); create the 4 Dodo products + a **test** API key + webhook secret (don't paste the key in chat); set the `DODO_*` vars + `BILLING_ENABLED=true`; point the webhook at a public URL; and on the first test purchase **confirm `metadata.user_id` comes back on the webhook**. Real/live billing still waits on **Google sign-in (item 8)** (re-key entitlements to the Google account — ADR-008). App-side `SubscriptionService` + a checkout-URL opener (`url_launcher`, a new dep) is a **debug-only** follow-up. Confirm annual prices (still 10× monthly placeholders).

4. **Still pending from before (founder actions, guided):**
   - **Back up the keystore** (`apps/mobile/android/calfit-upload.jks` + `key.properties`) to two safe places — lose it and you can never update the app on Play.
   - **Rotate every key exposed in chat** (Gemini, Groq, Cerebras, Supabase service-role, `AUTH_SECRET_KEY`). Do `AUTH_SECRET_KEY` **before any tester installs** — it logs out every phone and orphans the 31 scans (`docs/DEPLOY_CLOUD_RUN.md` §1; re-pin Cloud Run to the new version after).
   - **Gemini quota cap** — exact editable rows are in `status.md` (paid tier 1 per-model request limits; set ~60/min, ~1000/day). Deferred by founder.
   - **Make cap=4 live** — the running service still has `DAILY_SCAN_CAP=50`: `gcloud run services update calfit-api --region=asia-south1 --update-env-vars DAILY_SCAN_CAP=4`.
   - **Play Console (item 7):** store-listing assets (icon 512×512 done; phone screenshots with a *demo* profile not real health data; feature graphic 1024×500), then the Data safety / health / content-rating forms from `.10x/play-console-checklist.md`, then upload the AAB to closed testing (12 testers, 14 days).

5. **Queued after launch prep:** Supabase Pro (item 4, dashboard — also backups), Google sign-in (item 8), payments wiring (item 9).

**DPDP:** `.10x/reviews/2026-10-29-dpdp-rules.md` — duties from 13 May 2027; open: breach notice, access log, the Rule 8(3) lawyer question. **Rules for every edit:** `agents.md` (loaded via `CLAUDE.md`).

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
