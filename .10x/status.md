# Status

**Updated:** 2026-10-29
**Snapshot:** `main` = `origin/main` at `b4c6c3b` (plus this handoff commit). CI is green: secret scan, backend, app.
**Tests:** backend 520 (pytest), app 93 (`flutter test`), `flutter analyze` clean.

## Done on 2026-10-29: four scan-reliability fixes and security headers
- **Label numbers sanity-checked:** `src/domain/nutrition_plausibility.py`. Impossible values become unknown; contradictions make the scan insufficient data. It passes the founder's 31 real scans.
- **One 35 s deadline per scan,** with the explanation skipped when time is short: `SCAN_DEADLINE_SECONDS`, `EXPLANATION_MIN_SECONDS`.
- **A failed scan gives its count back.** **Migration 012 (`refund_scan_usage`) is NOT applied yet**; until then refunds are logged and skipped.
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

## Done on 2026-10-29 (uncommitted): DPDP Rules check
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

## Done on 2026-10-29 (committed): "tabs don't load" + mobile audit
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

## Waiting on the founder
- [ ] **GitHub settings:**
  - install the CodeRabbit app;
  - branch protection on `main` (PR plus green CI);
  - secret scanning with push protection.
- [ ] **Rotate the earlier-exposed keys** (Gemini, Groq, Cerebras, old Supabase secret), then every 90 days.
- [ ] **AI plan:** buy Vertex AI (asia-south1), then request zero data retention. Prescriptions stay refused until `GEMINI_BACKEND=vertex` or `GEMINI_PAID_TIER_CONFIRMED=true`.
- [ ] **Real photo-scan test on the phone:** after the new key.
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
