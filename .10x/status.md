# Status

**Updated:** 2026-10-29
**Snapshot:** `main` = `origin/main` at `b4c6c3b` (plus this handoff commit). CI is green: secret scan, backend, app.
**Tests:** backend 508 (pytest), app 82 (`flutter test`), `flutter analyze` clean.

## Done on 2026-10-29 (uncommitted): "tabs don't load" + mobile audit
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
- [ ] **The Gemini key in `apps/api/.env` is invalid** (401). Every photo scan returns 503 until the founder replaces it. Check: `cd apps/api && .venv/Scripts/python.exe -m src.check_config`.

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
1. **Prescriptions:** on-device text recognition and redaction before turning them on.
2. **Deploy to Cloud Run** (`APP_ENV=production`, `TRUSTED_PROXY_HOPS=1`, Cloud Armor in front).
3. **Google sign-in** (must link the family identities).
4. **Play Store:** Play Integrity in place of CAPTCHA, signing, listing.
5. **Pay down the 105 mypy errors.**
