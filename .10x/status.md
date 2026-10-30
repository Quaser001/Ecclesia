# Status

**Updated:** 2026-10-30
**Snapshot:** `main` = `origin/main` at `3c70511` (pushed 2026-10-30). CI not checked since the push. Untracked `apps/mobile/devtools_options.yaml` is an auto-generated Flutter file, deliberately left uncommitted.
**Tests:** backend 614 (pytest), app 99 (`flutter test`), `flutter analyze` clean. (Pre-existing CI lint nit, not from the billing work: unused `import pytest` in `tests/test_client_errors.py` trips `ruff --select F,E9` — one-line fix when someone's in there.)
**Live Supabase (Singapore `rxqsyksydnmwtslfvwll`):** migrations 001–012 applied (010 consents, 011 rls_auto_enable lockdown, 012 refund_scan_usage). There's no tracking table, so record each migration here.
**Live Cloud Run (Mumbai `asia-south1`):** `https://calfit-api-661871935612.asia-south1.run.app` — GCP project `gen-lang-client-0252924706` ("aaa1"), service account `calfit-api@gen-lang-client-0252924706.iam.gserviceaccount.com`, image tag `e569254`, revision `calfit-api-00001-9rs`. Health, 401 and device-token smoke tests passed. Secrets in Secret Manager: GEMINI_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, AUTH_SECRET_KEY (pinned to version 1).
**Founder's phone:** runs the consent-notice build (not the latest, which adds `Idempotency-Key`). Install the latest with `adb install -r` next time it's plugged in.

## Done on 2026-10-30: Dodo billing groundwork — backend, test mode (founder chose D→A)
- **Viability settled first** (`.10x/reviews/2026-10-30-dodo-play-billing-viability.md`): in India, Google allows only **User Choice Billing** — Dodo can't be the sole in-app billing path; it must run *alongside* Play Billing with 24 h reporting (Path B). Founder chose **D→A**: build provider-agnostic test-mode groundwork now, aim at **web checkout + in-app entitlement unlock** (Path A, least Play-policy risk). Keep any app-side checkout button **debug-only** — an in-app link-out to a web checkout is what Play forbids outside UCB, and Path A still needs Google sign-in (item 8) to know who's buying.
- **Built (backend only, test mode, no new dependency):**
  - `PaymentProvider` interface + `DodoPaymentProvider` (`src/providers/payments.py`, `dodo_provider.py`). Checkout = plain httpx POST to `/checkouts`; webhook verification = **Standard Webhooks** HMAC-SHA256 done with the stdlib (no svix/sdk).
  - Routes (`src/api/v1/billing.py`): `POST /billing/checkout` (auth → returns a Dodo checkout URL, user_id in metadata), `POST /billing/webhook` (unauthenticated by design — signature is the auth; verified over the **raw** body; idempotent on `webhook-id`; ordered by event timestamp; a bad signature grants nothing; a DB failure 500s so Dodo retries), `GET /billing/status` (the app's tier + daily cap).
  - Deterministic tier rule in `src/domain/billing.py` (pure: only `status == "active"` and an un-lapsed `next_billing_date` is entitled; highest active tier wins across multiple subs). `EntitlementService` in `src/services/entitlements.py` maps Dodo `product_id` ↔ tier from settings.
  - Storage: `entitlements` (one row **per subscription**, PK = Dodo subscription_id) + `billing_webhook_events` (idempotency ledger) in both providers; the atomic insert-ledger-then-guarded-upsert is a Postgres RPC (`apply_billing_event`, migration 013) and a mirrored SQLite transaction.
  - Scan cap is now tier-aware (`get_scan_limiter`): **off by default** (`BILLING_ENABLED=false`) → everyone on the free `DAILY_SCAN_CAP`, no extra DB read; on → Plus=10/Pro=20 from the entitlement. A failed entitlement read raises (ADR-006), never a silent free fallback.
  - `delete_my_data` now drops the profile's entitlement rows (stops *us* honouring the sub). **It does NOT cancel the subscription at Dodo** — founder decision whether to also call Dodo's cancel API on erasure.
  - Settings + `.env.example`: `BILLING_ENABLED`, `DODO_MODE`, `DODO_API_KEY`, `DODO_WEBHOOK_SECRET`, `DODO_RETURN_URL`, four `DODO_PRODUCT_*` ids, `PLUS_SCAN_CAP=10`, `PRO_SCAN_CAP=20`. Keys are **server-side only** (never in the Flutter app, never in chat — they go on the rotate list if they ever are).
  - Tests: `tests/test_billing.py` (tier rule, Standard Webhooks verify incl. tamper/stale/empty-secret, idempotency, out-of-order, two-subs, cap wiring) + `tests/test_billing_api.py` (routes). **Backend 614 pass; ruff `--select F,E9` clean on the new files.** Nothing committed.
- **Migration 013 is NOT applied** (`apps/api/migrations/013_entitlements.sql`). Show the founder, get approval, apply to the live Singapore project, then record it here (no migration table).
- **Founder actions to turn it on (test mode first):**
  1. Apply migration 013 (above). Dry-run it once inside `BEGIN; … ROLLBACK;` first to confirm it's clean, then for real.
  2. In the Dodo dashboard: create 4 products (Plus/Pro × monthly/annual) and copy their ids; create a **test** API key and the webhook signing secret. Put the ids + `DODO_API_KEY` + `DODO_WEBHOOK_SECRET` + `DODO_RETURN_URL` in `.env` / Secret Manager; set `BILLING_ENABLED=true`. **Don't paste the key in chat.**
  3. Point Dodo's test webhook at a **public** URL (not `127.0.0.1`) — a tunnel locally, or the deployed Cloud Run service.
  4. On the **first test purchase, verify the webhook payload against the checklist** in the review doc (`metadata.user_id` echoed — the link depends on it; `product_id` location; status literally `"active"`; `next_billing_date`; the `whsec_` secret branch if everything 401s; `subscription_data.metadata` accepted). Built from Dodo's docs, which don't pin every field.
- **Erasure caveat (founder decision):** `delete_my_data` drops the entitlement rows, but the device token still works, so a renewal webhook after a delete would recreate the row — and it does not cancel the sub at Dodo, so charges continue. Decide: cancel at Dodo on erasure, and/or ignore webhooks for deleted users.
- **Still gated:** real/live billing waits on **Google sign-in (item 8)** — an entitlement keyed to a per-profile Keystore token is lost with the phone and can't cover family profiles (ADR-008); migration 013 has a note to re-key to the Google account id. Privacy policy still blocks the Play listing (handoff item 2). App-side real `SubscriptionService` + a URL opener (`url_launcher` — a new dep, agents.md §1/§5) is a separate, debug-only follow-up.

## Done on 2026-10-30: subscription paywall page built; tiered plan decided; free cap = 4
- **Subscription model (founder, 2026-10-30):** Free = 4 scans/day; **Plus = 10/day @ ₹199/mo**; **Pro = 20/day @ ₹249/mo**; monthly + annual. Prescription reading and advanced insights are **paid-tier only**. Payments via **Dodo** (India allows alternative billing alongside Play Billing, −4% service fee, with reporting requirements — confirm Dodo supports Google Play India alternative-billing reporting before committing). Real billing + tiered enforcement wait on Google sign-in (item 8): a subscription needs durable identity (ADR-008: family profiles can't be linked server-side).
- **Paywall page built** (`apps/mobile/lib/features/subscription/`): `subscription_plan.dart` (plans as data, prices in Dart — annual = 10× monthly placeholder, confirm with founder), `subscription_service.dart` (interface + `ComingSoonSubscriptionService` stub that throws `SubscriptionUnavailable` — **no fake success**, ADR-006), `subscription_screen.dart` (Hick's Law: one FilledButton CTA, recommended plan highlighted, monthly/annual toggle, fine print, SafeArea + scroll). Entry: **debug-only** tile at the bottom of Settings (`kDebugMode`), so release testers never see a dead button. New l10n keys in `app_en.arb` (`sub*`), regenerated with `flutter gen-l10n` (other locales fall back to English). Tests: `test/subscription_screen_test.dart` (5). **flutter analyze clean; flutter test 104 pass; backend 575 (rate_limit re-verified 8).** Nothing committed.
- **NEXT (founder asked 2026-10-30, deferred to avoid a half-broken l10n tree near the usage limit): reduce languages to English + Hindi only.** Remove Assamese/Bangla/Khasi: delete `lib/l10n/app_as.arb|app_bn.arb|app_kha.arb` and their generated `app_localizations_as|bn|kha.dart`; trim `supportedLanguages` in `lib/l10n/l10n.dart` to en+hi; re-run `flutter gen-l10n`; then `flutter analyze && flutter test` (the `settings_and_body_test.dart` "app shell renders in <name>" loop auto-adjusts to `supportedLanguages`; grep for stray `as`/`bn`/`kha` refs). Note: the DPDP/consent work mentioned Khasi translations — fine to drop for now per founder.
- **Hick's Law is an app-wide rule now** (founder): one obvious main action per screen. Saved as a memory; a screen-by-screen audit is a good separate read-only pass.
- **`DAILY_SCAN_CAP` default 50 → 20 → 4** (`apps/api/src/config/settings.py`). 4 is the free tier. Paid tiers (10/20) are display-only until entitlement exists. The app-level spend backstop while the Gemini quota cap is deferred.
- **"Failed scans don't count" was already the behavior** — `_Charge.refunded_on_failure()` in `apps/api/src/api/v1/scans.py` refunds a scan that errors on our side or upstream (timeout, 5xx, bad file, product-not-found). A scan that *ran* but found too little on the label still counts (it cost a real Gemini call); that's deliberate and tested (`test_scan_refund.py::test_a_label_with_too_little_on_it_still_counts`).
- `docs/DEPLOY_CLOUD_RUN.md` updated (deploy env var and §6 cost note). New test pins the default: `test_rate_limit.py::test_shipped_default_cap_is_20_successful_scans`. **Backend 575 pass.**
- **Not yet live:** the running Cloud Run service still has env var `DAILY_SCAN_CAP=50`, which overrides the code default. To make 4 take effect in production (no rebuild needed):
  `gcloud run services update calfit-api --region=asia-south1 --update-env-vars DAILY_SCAN_CAP=4`
  The Flutter app needs no change — it shows the cap from the server's 429 message (`exc.cap`).
- Not committed (founder commits when ready).

## Deferred 2026-10-30: Gemini quota cap — exact editable rows found (founder will set later)
Confirmed in GCP Console (project aaa1): **AI Studio → Usage shows project aaa1 on "Tier 1"** (first paid tier — so paid billing is active; the old free-tier usage predates the upgrade). The console *can* cap paid spend — the editable rows were located. Path: **IAM & Admin → Quotas & System Limits**, filter chips `Service: Gemini API` + `paid tier` + `Request limit per model` + `the paid tier 1`. All rows show **Adjustable: Yes** (select row → **Edit Quotas** → new value → Submit; verify on the **Increase Requests** tab or by re-reading Value).
- **`Request limit per model per minute for a project in the paid tier 1`** → `model: gemini-2.5-flash` = **1,000** (default); `model: gemini-3.5-flash-lite` = **4,000**. Cap both to **60**.
- **`Request limit per model per day for a project in the paid tier 1`** → set both models to **~1,000** (value not captured; the paid tier 2 row showed 100,000 for 2.5-flash, so tier 1 is lower).
- Same-named rows exist for **paid tier 2 and 3** — cap those two models there too if worried about an automatic tier bump (tier 2 needs far more spend than the ₹500 budget, so lower priority).
- The app calls `gemini-2.5-flash` (primary) and `gemini-3.5-flash-lite` (fallback) — `_FALLBACK_MODELS` in `apps/api/src/providers/gemini_provider.py`; cap whichever of the two the quota rows list.
- Note: `docs/GEMINI_BILLING.md` §3 says these limits are "per project" — they are actually **per model, per tier**. Correct that doc when revisiting.
- Deferred by the founder (2026-10-30): "set it up later, too much effort for a small thing." App-level `DAILY_SCAN_CAP` is the near-term backstop instead.

## Done on 2026-10-30: system-design hardening audit (scaling/reliability checklist)
Audited a 11-point system-design checklist against the codebase. Most items were already covered; two real bugs were found and fixed, the rest are docs or founder actions.
- **Narrowed to sub-second — delete-during-scan erasure race:** a scan runs up to 35 s after passing the consent gate. If the user ran "Delete my data" in that window, the scan would recreate the profile (`ensure_profile_exists`) and save a row behind the delete, and could upload a photo after `delete_folder` ran — deleted data came back. Fix: `ScanOrchestrator._persist_scan` now re-checks `has_consent` before saving (returns False → caller removes the photo); `delete_my_data` now deletes the DB first (its first step withdraws consent). This shrinks the window from ~35 s to the ~100 ms between the `has_consent` read and the `save_scan` commit; a delete landing in *that* gap can still recreate the row. Closing it fully needs an insert-if-consented RPC (a migration — show the founder and ask first). Test: `test_scan_refund.py::test_a_scan_is_not_saved_if_consent_is_withdrawn_mid_scan`.
- **Fixed — /client-errors log-bill risk:** the unauthenticated crash-report endpoint wrote a retained log line per call, bounded only by the loose 3000/hr per-IP request cap. Added `CLIENT_ERROR_DAILY_CAP_PER_IP=50`; reports over it are dropped (still 204) so they never reach the log. Test: `test_client_errors.py::test_reports_over_the_per_ip_cap_are_dropped_without_logging`.
- **Rollback runbook added** to `docs/DEPLOY_CLOUD_RUN.md` §7: `gcloud run services update-traffic` to a prior revision, keep migrations additive, and the `CONSENT_NOTICE_VERSION` one-way-door trap.
- **Already covered (no change):** rate limiting (per-token + per-IP request cap, daily scan cap via atomic Postgres RPC, per-IP device-mint cap); no N+1 queries (batch reads throughout); race conditions (atomic upserts/RPCs, `scans.scan_id` is a PK so the idempotency retry is safe); background jobs (not viable on Cloud Run's request-scoped CPU, and every scan step feeds the response or the `saved` flag).
- **Founder actions still open (not code):** Gemini quota cap (the real spend backstop — GCP Console; the per-IP device/crash caps reset when Cloud Run scales to zero, so they don't bound spend); a second free Supabase project for dev so the laptop's service-role key stops hitting prod (also enables migrations-on-dev-first and "restore into a test project"); `pg_dump --schema=public` for backups (dump to a file outside OneDrive, match the pg_dump major to the server's Postgres, delete the dump after; a DB dump excludes Storage photos); revoke the Groq/Cerebras keys exposed in chat (not in Secret Manager → no prod spend, but revoke anyway). Already confirmed in status (not founder actions): `TRUSTED_PROXY_HOPS=1` and `--max-instances 3` are in the deploy config; the Gemini key bills to project aaa1, which the ₹500 budget covers. Webhook-based upgrades are N/A until payments exist (item 9).

## Done on 2026-10-30: Release keystore and signed app bundle (production-readiness item 6)
- **Upload keystore generated:** `apps/mobile/android/calfit-upload.jks` (RSA 2048, valid until 2054, alias `calfit-upload`).
- **SHA-256 fingerprint:** `7C:A7:0C:2C:CA:B7:E3:B6:98:0E:52:37:8D:61:90:0C:C4:49:AD:1A:23:F5:06:4E:97:C3:4E:15:4E:A0:0C:52`.
- **`key.properties` created** (gitignored). Gradle picks it up automatically for release builds.
- **App bundle built:** `build/app/outputs/bundle/release/app-release.aab` (47 MB), signed with the upload key, pointed at the live Cloud Run URL.
- **Not installed on the founder's phone** — a release-signed build can't install over the debug one without uninstalling first, which wipes the Keystore token and loses the 31 scans. Keep the phone on debug builds until accounts (item 8) can re-link identity.
- **Back up now:** copy `calfit-upload.jks` and `key.properties` to two safe places (password manager, USB drive, cloud vault). Losing the keystore means you can never update the app on Play. If it's lost after enrolling in Play App Signing, you can request an upload key reset in Play Console.
- **`isMinifyEnabled` is still `false`:** R8 code shrinking is off. Turn it on and test before launch (it can break plugins).

## Done on 2026-10-30: Crash reporting (production-readiness item 5)
- **Backend**: unhandled exceptions now log full stack frames (file, line, function) — never the exception message (can contain health data). `observability.py` `_frames()`.
- **Backend**: new `POST /api/v1/client-errors` endpoint. Accepts error type and frames from the app. No auth required (crashes during sign-in must be reportable). Pydantic-validated, bounded fields. Returns 204 always.
- **Mobile**: `ErrorReporter` in `lib/services/error_reporter.dart`. Hooks `FlutterError.onError` and `PlatformDispatcher.instance.onError` in release builds. Sends `error.runtimeType` and stack frames, never `error.toString()`. Capped at 5 reports per app run (a crash loop mustn't exhaust the 600 req/hr rate limit). Fire-and-forget with 5 s timeout.
- **No new dependency** — crashes go to Cloud Logging (already set up with 365-day retention). No Sentry, no Crashlytics, no consent bump needed.
- **Privacy policy already covers this** (sections 3, 4, 5): "status codes, timings and error types" on Google Cloud, 1-year retention.
- **Not covered**: native Android crashes (OOM, ANR) — Play's Android Vitals is the signal for those. Sentry or Crashlytics would need an exception to agents.md §5 plus a consent-notice bump; that's a separate decision.
- **Tests**: backend 8 new (`test_client_errors.py`), including a test that health data never appears in log output. App 5 new (`error_reporter_test.dart`).

## Done on 2026-10-29: Cloud Run deployment (production-readiness item 3)
- **API deployed** to Cloud Run at `https://calfit-api-661871935612.asia-south1.run.app` (Mumbai, `asia-south1`).
- **GCP project:** `gen-lang-client-0252924706` ("aaa1"), same project as the paid-tier Gemini key.
- **Infrastructure created:** Artifact Registry repo `calfit`, service account `calfit-api`, four secrets in Secret Manager.
- **Dockerfile fix:** removed `--mount=type=cache` (requires BuildKit, which Cloud Build's legacy builder doesn't support). Build-time caching is lost; each build re-downloads deps (~7 s). Not a problem.
- **Smoke tests passed:** `/health` → ok, `/api/v1/profile` → 401, `POST /api/v1/auth/device` → token issued.
- **`APP_ENV=production`**: local SQLite fallback disabled, `/docs` hidden, secrets required.
- **`PRESCRIPTION_AI_ENABLED=false`** in production (safe: prescriptions are off until explicitly enabled).
- **Log retention:** 365 days on the `_Default` bucket (DPDP Rules 6(1)(e), 8(3)).
- **Uptime check:** `calfit-api-health` checks `/health` every 5 minutes.
- **Budget alert:** ₹500/month with alerts at 50%, 90%, 100% actual and 100% forecasted.
- **Not yet done from item 3:** Gemini quota cap (set in GCP Console → IAM & Admin → Quotas: filter "Generative Language API", cap requests/min to 60 and requests/day to 5,000), `--min-instances 1` (adds ~₹1,000/month idle cost — optional).
- **Key rotation still pending:** all `.env` secrets exposed in chat history.

## Done on 2026-10-29: four scan-reliability fixes and security headers
- **Label numbers sanity-checked:** `src/domain/nutrition_plausibility.py`. Impossible values become unknown; contradictions make the scan insufficient data. It passes the founder's 31 real scans.
- **One 35 s deadline per scan,** with the explanation skipped when time is short: `SCAN_DEADLINE_SECONDS`, `EXPLANATION_MIN_SECONDS`.
- **A failed scan gives its count back.** **Migration 012 applied** to Supabase (2026-10-29, with approval); live check: 2 scans, refunds 1 → 0 → 0 (never below zero).
- **`Idempotency-Key` per photo** (app and server): a retry returns the saved scan. The local DB no longer overwrites on a duplicate id (it was `INSERT OR REPLACE`).
- **Security headers on every response** (`src/security_headers.py`).
- **New Gemini key in `.env`** (from the founder). Real scan of a synthetic label: 22 s end to end.
  - "Sodium 0.9 g" became 900 mg; peanut allergy scored 0; AI explanation used; a retry with the same key returned the same scan.
  - **Model:** `GEMINI_MODEL=gemini-2.5-flash` (4.7 s per label). `gemini-3.5-flash-lite` took 19.5 s (and once hung past 25 s), so it's last in the fallback list now. `gemini-2.5-flash-lite` returns 404 on this key and was removed.
- **Sodium unit:** the AI now reports the printed unit (`sodium_unit`), and grams are converted in code.
- **Database nutrition** is re-checked after merging; if it contradicts the label it isn't merged.
- **Note:** some old scans (8 Oct) hold sodium in grams labelled as mg, from before the unit fix. Old scans are never rescored (ADR-007).
- **Tests:** backend 563, app 94. **Rotate the Gemini key pasted in chat** with the other exposed keys.

## Done on 2026-10-29: consent notice (DPDP item A)
- **What:** a privacy notice with "I am 18 or older" and "I agree", per family profile, recorded on the server. Profile saves, scans and prescription reads answer 428 until there's a consent record.
- **Files:** app `lib/features/consent/consent_notice.dart`; server `src/services/consent.py`, `src/api/v1/consent.py`; `migrations/010_consents.sql`.
- **Tests:** backend `tests/test_consent.py` (8); app `test/consent_gate_test.dart` (6).
- **Migration 010 applied** to the Singapore project (`rxqsyksydnmwtslfvwll`, the one `.env` uses) on 2026-10-29, with approval.
  - Live check with a throwaway identity, all 9 steps passed: 428 before agreeing, 422 without 18+, 201 on agree, then a 200 profile save, delete withdraws, 428 again.
  - That throwaway left one withdrawn consent row.
- **On the founder's phone (2026-10-29):** installed over the old build with `adb install -r`.
  - The notice showed; the founder agreed on the phone.
  - Home then showed all 31 scans and the profile, and `consents` holds the founder's live row.
  - **If the phone shows "Waiting For Debugger"**, a developer setting was switched on. Clear it with `adb shell am clear-debug-app`.
  - There's no migration tracking, so record each migration here.
- **Migration 011 applied** (2026-10-29, with approval): `rls_auto_enable()` can no longer be run by anon or authenticated.
  - The `ensure_rls` event trigger still enables RLS on new tables: a probe table created and dropped in one step got RLS.
  - The advisor's two warnings about the function are gone. Left: the intended "RLS, no policies" note, and `vector` installed in public (low risk).
- **The old Mumbai project "calfit"** (`trmohgpjtldwxbpoqvpn`) is unused.
  - It holds one test identity from 27 Oct (1 profile, 1 scan) and an empty bucket.
  - The founder will delete it from the dashboard (Project Settings → General → Delete project).
  - The real project is "CalFit" in Singapore (`rxqsyksydnmwtslfvwll`).
- **Speed:** each gated request now makes one more Supabase round trip (about 0.2–1 s after an idle period). Watch it next to the timeout item.

## Done on 2026-10-29 DPDP Rules check
- **Review:** `.10x/reviews/2026-10-29-dpdp-rules.md`.
- **When it applies:** CalFit's duties start **13 May 2027** (Act ss.3–17, Rules 3 and 5–16).
- **Fixed today:**
  - adults only: the server and the app refuse a birth year under 18;
  - prescription consent can be withdrawn in Settings;
  - the policy now covers one-year logs, nomination, complaints to the Board, and breaches;
  - the deploy guide sets one-year log retention;
  - a test keeps the two policy copies identical.
- **Before launch:** see the review.
  - **A:** an onboarding consent notice with "I agree" and 18+, recorded on the server. The biggest gap; it needs a Supabase migration.
  - **D:** an in-app breach notice and a runbook.
  - **B:** a way to see whose data was accessed.
- **Founder and lawyer:**
  - **Rule 8(3):** keep health data a year after deletion, or logs only? Logs-only is in place now.
  - **Rule 9:** the contact person.
  - **Rule 6:** data processing agreements with Supabase and Google; Supabase backups.
- **Translations:** Khasi consent strings are in English until a speaker reviews them.

## Done on 2026-10-29 "tabs don't load" + mobile audit
- **Cause of "only Home loads":** the local server was stopped. Home kept what it had loaded; the other tabs had nothing to show.
  - The app now names this "Can't reach the CalFit server": `http.ClientException` maps to the network error kind.
  - Cold or idle requests to Supabase from this PC take about 1–5 s; one Insights call took 14 s, past the app's 10 s limit. Watch this; not fixed.
- **Audit, against five reported AI-built-app risks:**
  - No Supabase or third-party keys in the client: the app talks only to our API.
  - The unused per-phone `device_id` is removed and wiped from prefs.
  - One `setState` after an `await` without a `mounted` check (prescription photo) is fixed.
  - The scan photo box scales in landscape.
  - The backend returns 503 + `Retry-After` when Supabase or another upstream times out (`httpx.TransportError`), instead of a bare 500.
  - No deep links or client-side auth exist, so nothing to fix there. No iOS folder.
- **Rules:** `AGENTS.md` sections 5–6; `CLAUDE.md` imports it.
- Tests: app 84, backend 509. The latest APK is built but not yet installed (the phone was unplugged).

## Done on 2026-10-29 (Keystore)
- **Sign-in tokens moved to the Android Keystore** (`flutter_secure_storage` 11.2.0, `resetOnError: false`).
  - Interface: `lib/services/secret_store.dart`. Plain preferences now keep only a "signed in" marker.
  - Migration: the old single token and the tokens in the profiles list are written to the Keystore on first launch. Prefs drop the plain copy only when a later launch reads the same token back, because the plugin saves to disk lazily. If the Keystore refuses, the token stays in prefs and the next launch retries.
  - Dependabot ignores major versions of `flutter_secure_storage`: a major can drop the cipher the saved tokens use. Upgrade by hand, one major at a time, after a phone test.
  - If the Keystore loses a token, that profile goes to "save your profile again" (scans refused), never a silent new identity.
  - The old `PrefsAuthTokenStore` is deleted; `ApiService` now requires a token store.
  - Tests: `test/token_keystore_test.dart` (10). The debug APK builds.
  - **Upgrade tested on the founder's phone (2026-10-29, with approval):** prefs backed up first, installed with `adb install -r`.
    - Launch 1 wrote the token to the Keystore and kept the plain copy.
    - Launch 2 dropped the plain copy: `signed_in` is true and `reset_pending` false.
    - The same identity was in use: 31 scans and the profile intact.
    - Backup files deleted afterwards.
  - The emulator can't run on this PC (virtualization is off in BIOS).

## Done on 2026-10-28 and 29
- **Production hardening:** 47 audited issues. Spec `specs/2026-10-29-production-hardening.md`, review `reviews/2026-10-29-production-hardening.md`, ADR-006 "fail loudly".
- **Ratings are history:** each scan keeps the profile it was "scored for" (ADR-007). Old scans are never rescored.
- **Heart-health goal now checks sodium.** **Weight-loss sugar rule** RULE-010C.
- **Data/privacy audit** (`reviews/2026-10-29-data-privacy-audit.md`): Gemini no longer receives the health profile, only the findings for that product.
- **Family profiles, adults only** (ADR-008): one anonymous identity per person on the phone; switcher on Home.
- **CI** (`.github/workflows/ci.yml`): gitleaks secret scan; backend lint, tests and pip-audit; app analyze and tests.
- **Dependabot** (`.github/dependabot.yml`). **Request cap** on every route (`src/request_limit.py`).
- **RLS tested live** with the public key: reads nothing, writes refused.
- **History scrubbed** of the phone serial before pushing. A local branch `backup/pre-scrub-2026-10-29` still has the old history: never push it, delete when happy.

## Blocking
- [x] **New Gemini key in `apps/api/.env`** (2026-10-29). A real scan of a synthetic label passed end to end in 22 s.
  - `GEMINI_MODEL` is now `gemini-2.5-flash` (4.7 s on a label); `gemini-3.5-flash-lite` took 19.5 s and hung once.
  - The key was pasted into chat, so it's on the rotate list.
- [x] **Paid-tier Gemini key verified** (2026-10-29). `check_config` passes all five checks. `GEMINI_PAID_TIER_CONFIRMED=true` set.
  - The entire `.env` was read in this chat session, so **all keys** are on the rotate list: Gemini, Groq, Cerebras, Supabase service-role, and AUTH_SECRET_KEY.

## Waiting on the founder
- [ ] **GitHub settings:**
  - install the CodeRabbit app;
  - branch protection on `main` (PR plus green CI);
  - secret scanning with push protection.
- [ ] **Rotate ALL exposed keys (critical):** the entire `.env` was read in the 2026-10-29 chat session. Rotate: Gemini API key, Groq, Cerebras, Supabase service-role key, and AUTH_SECRET_KEY (careful: rotating AUTH_SECRET_KEY invalidates every phone token — see `DEPLOY_CLOUD_RUN.md`). Then every 90 days.
- [ ] **Delete the unused Mumbai Supabase project** "calfit" (`trmohgpjtldwxbpoqvpn`) from the dashboard.
- [x] **AI plan:** paid-tier Gemini key verified (2026-10-29). `GEMINI_PAID_TIER_CONFIRMED=true` set. Prescriptions are now allowed locally. Vertex AI is still an option for zero data retention.
- [ ] **Real photo-scan test on the phone** (a synthetic label already passed through the server in 22 s).
- [ ] **Try "Add family member" on the phone:** not exercised on a device yet.
- [ ] **Note:** the phone now runs the Keystore build, so an older build installed over it won't find the token.
- [ ] **Optional, touches the founder's account (needs approval):**
  - fill in `scored_for` on the 31 old scans;
  - strip GPS from their old photos.
- [ ] **Decide:**
  - child profiles (DPDP parental consent and child thresholds);
  - Nutri-Score layer;
  - the 7 stub scans;
  - the hard-stop diets;
  - deferred items: token expiry, retention job, transactional delete, composite index, migration tracking, image digests.
- [ ] **Reviews:** Khasi translations (several new strings); dietitian review of the curve heights.
- [ ] **Label 50–100 pack photos** for the label-reading accuracy test.

## Next engineering candidates

**Superseded by `.10x/reviews/2026-10-29-production-readiness.md`** ("Order of work"); the list below is kept for history.
1. **Prescriptions:** on-device text recognition and redaction before turning them on.
2. **Deploy to Cloud Run** (`APP_ENV=production`, `TRUSTED_PROXY_HOPS=1`, Cloud Armor in front).
3. **Google sign-in** (must link the family identities).
4. **Play Store:** Play Integrity in place of CAPTCHA, signing, listing.
5. **Pay down the 105 mypy errors.**
