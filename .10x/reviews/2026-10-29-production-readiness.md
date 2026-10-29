# Is CalFit production-grade and Play-Store-ready?

**Date:** 2026-10-29. **This replaces** the open items in `docs/LAUNCH_CHECKLIST.md` (some are out of date) and the "Next engineering candidates" in `.10x/status.md`.
**Verdict:** the engineering is strong for an MVP. It is **not launchable yet**. Three things block a launch:
1. the backend isn't deployed, and the Gemini key is invalid;
2. there's no durable account (a lost phone means lost data);
3. the Play Console steps haven't started.

There are also two code fixes worth doing before anyone else uses the app, both about the time budget: one scan can outlast the app's timeout, and a failed scan still uses up quota (see C).

Legend: [x] done and verified · [~] partly done · [ ] not done.
Must-haves for Play are marked **(Play)**; must-haves for a safe launch are marked **(Launch)**.

---

## A. Architecture: does the shape hold up?

**The shape today:**
- the phone app (Flutter, Android) talks only to the CalFit API (FastAPI, Cloud Run, Mumbai, when deployed);
- the API talks to Supabase (Postgres plus private storage, Singapore), Gemini (reading labels, writing explanations) and Open Food Facts;
- the app holds no third-party keys;
- scores come from a reviewable rule catalog, never from the AI;
- the AI only transcribes the label and words the explanation.

- [x] The client never holds secrets; every request goes through our API. Row-level security is on with no policies, so the public key opens nothing (tested live).
- [x] Deterministic scoring; the AI's output is parsed into Pydantic models and checked against the findings (ADR-001, ADR-006).
- [x] External services sit behind interfaces (`SupabaseProvider`, `StorageProvider`, `GeminiProvider`), so there's a local SQLite path for tests.
- [x] Fail loudly: an outage is a 503, never a made-up or empty result (ADR-006). Upstream timeouts are 503 with `Retry-After`.
- [x] Ratings are history: each scan keeps the profile it was scored for (ADR-007).
- [x] Family profiles are separate identities (ADR-008).
- [~] **Identity** is an anonymous, server-signed token per profile, kept in the Keystore. Durable for an install, lost with the phone (see F).
- [ ] **Staging environment:** there's only local and production. **(Launch)** Add a second Cloud Run service and Supabase project for testing releases.
- [ ] **Database migrations are applied by hand** with no tracking table (010 and 011 are recorded in `status.md`). **(Launch)** Adopt `supabase db push` or a `schema_migrations` table.
- [ ] **Supabase free tier:** it pauses after a week idle and has no backups. **(Launch)** Move to Pro before real users (Rules 6(1)(d) also expect backups).
- [ ] **Data region:** the database is in Singapore, the API in Mumbai. Every request crosses the border twice, about 70–100 ms each way. The policy discloses this. Decide whether to move Supabase to Mumbai before you have users; it's cheap now, painful later.

## B. Latency

**Measured from this PC to Supabase Singapore:**
- a warm query takes about 0.2 s;
- the first query after 15 s or more of quiet takes 1.2–1.8 s;
- a cold server start takes about 5 s;
- one request took 14 s.

- [x] Timeouts everywhere:
  - app: 10 s for light calls, 45 s for a scan;
  - Gemini: 25 s per model;
  - Open Food Facts: 6 s.
- [x] Lists are paged (history), tabs are kept alive, and refreshes happen in the background.
- [x] **A time budget for a whole scan** (built 2026-10-29: `SCAN_DEADLINE_SECONDS=35`, `EXPLANATION_MIN_SECONDS=8`). Was: The server's worst case is about 106 s (2 models × 25 s to read, 6 s lookup, 2 × 25 s to explain). The app gives up at 45 s, and then the server keeps going and saves a scan the person never sees. Fix:
  - give the request one overall deadline, about 35 s;
  - give each step whatever is left of it;
  - skip the AI explanation when time is short (the rule-summary fallback already exists).
- [ ] **Keep connections warm (Launch):**
  - Cloud Run `--min-instances 1` removes the 5 s cold start (roughly ₹1,000 a month idle; check the Cloud Run pricing calculator);
  - longer HTTP keep-alive to Supabase removes the 1 s reconnect after an idle period.
- [ ] **Measure the real thing:** add request timing per route (the `duration_ms` log already exists) to a Cloud Monitoring dashboard, with an alert when p95 for a scan exceeds 20 s.
- [ ] **Load test once** before launch, for example 50 concurrent scans with a fake Gemini. It checks the instance limits and the Supabase connection pool.

## C. Fallbacks and "the craziest scenes"

Every row is a real way the live app can go wrong, and what CalFit does about it.

Each `[x]` names the test that proves it. `[~]` means built but not tested.

| Scenario | What happens today | Status |
|---|---|---|
| **Gemini misreads a number**: negative sugar, more fat than the serving weighs, kcal far from 4×protein + 4×carbs + 9×fat | an impossible value becomes unknown; numbers that contradict each other make the scan "insufficient data". It passes the 7 distinct real labels among the founder's 31 scans (run as a test). Sodium printed in grams is converted in code; database nutrition is re-checked after merging | [x] `test_nutrition_plausibility.py` (`src/domain/nutrition_plausibility.py`) |
| Gemini down, rate-limited (429), or slow | tries the next model, then a 503 "AI unavailable", never "take a clearer photo" | [x] `test_production_hardening.py` |
| Bad or revoked Gemini key | stops after the first model (401/403 fail the same everywhere) and returns 503 | [x] `test_production_hardening.py`, `test_gemini_backend.py` |
| Gemini returns malformed JSON or the wrong shape | schema-constrained output, then Pydantic validation; unusable output moves to the next model | [x] `test_production_hardening.py` |
| Gemini invents data, or the label has too little to judge | transcription-only prompt; unknown stays empty; too little gives "insufficient data", not a score | [x] `test_scan_data_gate.py` |
| A label contains text aimed at the AI ("ignore your instructions…") | injection guard in the label prompt; the score is rules, so injected text can't change it | [~] guarded, but tested only for prescriptions (`test_prescription_service.py`); add a label test |
| The AI explanation contradicts the findings | a grounding check rejects it; the rule-summary fallback is used | [x] `test_explanation_guard.py` |
| An allergen is present | hard stop, whatever else scores well | [x] `test_scoring.py`, `test_score_formula.py` |
| Photo is not a food, blurry or blank | no product read, so "insufficient data" or a database choice | [x] `test_scan_data_gate.py`, `test_front_of_pack.py` |
| A huge, wrong-type or fake image file | size checked before reading; real type sniffed from the bytes; GPS stripped from JPEGs | [x] `test_image_bytes.py`, `test_production_hardening.py` |
| Flood of requests or abuse | per-route request cap, daily scan cap per person, identity creation capped per IP | [x] `test_production_hardening.py`, `test_auth_endpoints.py` |
| The person's profile fails to load mid-scan | 503, never scored as an empty profile (no allergies) | [x] `test_production_hardening.py` |
| The token is rejected or lost | scans refused until the profile is saved again; never a silent new identity | [x] `api_service_hardening_test.dart`, `token_keystore_test.dart` |
| No network, or the server is down | "Can't reach the CalFit server", with Try again | [x] `api_service_hardening_test.dart` |
| Open Food Facts down or slow | 6 s timeout, a clear "unavailable", and the scan goes on with what's on the label | [x] `test_food_lookup.py`, `test_front_of_pack.py` |
| Supabase times out or drops | 503 with `Retry-After` and a request id | [x] `test_production_hardening.py` |
| Supabase rejects a query (PostgREST `APIError`) | a 500 with a request id: our bug, not an outage | [x] by design (`test_production_hardening.py` checks 500s carry the request id) |
| A scan takes longer than the app waits | one 35 s deadline per scan, inside the app's 45 s: past it, a 503 and nothing saved. The AI explanation is skipped when under 8 s remain | [x] `test_scan_deadline.py` |
| A scan fails (Gemini outage), or the file isn't a photo | the count is given back. A label with too little on it still counts (it cost an AI call) | [x] `test_scan_refund.py`. On Supabase it needs **migration 012** (`refund_scan_usage`); until then a refund is logged and skipped |
| Double tap, or retry after a lost reply | the app sends one `Idempotency-Key` per photo; a retry returns the saved scan, not run or counted again. The scan button is disabled while scanning | [x] `test_scan_refund.py`, `api_service_hardening_test.dart` |
| The app crashes in the field | **nobody finds out** | [ ] add crash reporting (D) |
| The same AI result for different photos (caching) | not cached, so every scan costs a Gemini call | [ ] later: cache by barcode or image hash |
| Spend runs away (a bug loop, or abuse) | daily cap per person; no project-wide limit | [ ] Gemini quota cap plus a Cloud budget alert (`GEMINI_BILLING.md`) |

**Refund abuse (note):** a scan crafted to be slow gets its count back on timeout. Only the per-route request cap limits it; consider a daily cap on refunds.

**Fallback not built:** a second AI provider. The code has Groq and Cerebras settings but no wiring. Leave it out. A second provider doubles the privacy review (DPDP, and where the data goes); the 503 path is honest; and two Gemini models already back each other up.

## D. Observability and operations

- [x] Structured JSON logs with a request id and per-route timing; health data and error text never logged.
- [x] `/health` endpoint; `check_config` validates the keys at startup.
- [x] CI on every push: secret scan, backend lint and tests, app analyze and tests. Dependabot is on.
- [ ] **Crash reporting (Play, Launch).** Play's Android vitals shows crash rates, but not why. Add Sentry or Firebase Crashlytics. Either one is a processor under DPDP:
  - disclose it, and scrub health data;
  - it changes "who else handles it", so it's a new notice version (bump `CONSENT_NOTICE_VERSION` on both sides).
- [ ] **Uptime and alerting (Launch):** a Cloud Monitoring uptime check on `/health`, alerts on 5xx rate, p95 latency and Gemini 503s, sent to your email or phone.
- [ ] **Incident runbook** (DPDP review D): who decides, the Board's 72-hour report, the in-app notice.
- [ ] **One-year log retention:** `gcloud logging buckets update _Default --retention-days=365` (in `DEPLOY_CLOUD_RUN.md`).
- [ ] **Backups and a restore drill:** Supabase Pro has daily backups. Restore one once, to prove it works.

## E. Security

- [x] Tokens in the Android Keystore with `resetOnError: false`; no device id.
- [x] Signed tokens, IDOR closed (id only from the token), CORS locked down, request-size and request-rate caps.
- [x] HTTPS only, except localhost; cleartext limited by network config.
- [x] Secrets server-side only; history scrubbed; gitleaks in CI.
- [x] RLS tested with the public key; `rls_auto_enable()` locked down (migration 011).
- [ ] **Rotate the keys that were exposed earlier** (Gemini, Groq, Cerebras, the old Supabase secret). **(Launch)**
- [ ] **R8 code shrinking for release** (`isMinifyEnabled = false` today): a smaller APK and harder to reverse. Test it, because R8 can break plugins.
- [ ] **Play Integrity** on identity creation, so scripts can't mint identities and drain the Gemini budget. The per-IP cap is the only guard today.
- [ ] GitHub settings: branch protection, push protection, CodeRabbit (founder).
- [ ] Revoke the leftover backup branch `backup/pre-scrub-2026-10-29` once you're happy with the scrubbed history.

## F. Accounts: Supabase Auth plus Google sign-in (planned)

How it fits the current design:
- **Use native Google sign-in**: `google_sign_in`, then `supabase.auth.signInWithIdToken`. No browser redirect, so no deep link to handle. Use `linkIdentityWithIdToken` to link Google to an existing account.
- **The backend keeps issuing its own tokens.** On sign-in, the app sends the Supabase session JWT once to a new `/auth/link` endpoint. The server verifies it (Supabase JWKS), records `auth_user_id → CalFit user_id` for the current profile, and returns the same CalFit token.
  - A new phone that signs in with the same Google account gets that profile's token back.
  - No data moves. Existing anonymous users keep everything.
- **Family profiles:** each person signs in with their own Google account, or a profile stays anonymous on that phone.
  - Don't attach several family profiles to one Google account without a new ADR. It would let the server see that they share a household, which ADR-008 avoids on purpose.
- **Must-haves that come with accounts:**
  - [x] **(Play)** an in-app account deletion path: Settings → Delete my data.
  - [ ] **(Play)** register the SHA-1 fingerprints of **all three** signing keys in the Google OAuth client: debug, upload, and the **Play App Signing key** (Play Console → App integrity). Without the last, sign-in works in testing and fails in the store build.
  - [ ] **(Play)** a **web page where people can request deletion without the app**. Not built; needed once accounts exist, and asked for in the Data safety form.
  - [ ] Delete must also remove the Supabase Auth user and the link.
  - [ ] Policy, Data safety form and consent notice: add "email address (from Google)" as collected data. That is a new notice version: bump `CONSENT_NOTICE_VERSION` in `src/services/consent.py` and `lib/features/consent/consent_notice.dart`, and everyone is asked again.

## G. Payments (planned)

- **Digital features sold inside the app must use Google Play Billing** (Play's Payments policy). For India, Google also offers an alternative billing option alongside Play, with a service fee 4 percentage points lower. It needs extra work: PCI DSS for your processor, reporting, and enrolment. Start with Play Billing alone.
- **Must-haves:**
  - [ ] subscriptions in Play Console;
  - [ ] the `in_app_purchase` plugin in the app;
  - [ ] **server-side verification** of every purchase through the Play Developer API (never trust the app);
  - [ ] **Real-time Developer Notifications** (Pub/Sub) for renewals, cancellations and refunds;
  - [ ] an `entitlements` table the scan cap reads from;
  - [ ] restoring purchases on a new phone (needs F first);
  - [ ] a Play merchant account; GST registration if you cross the threshold;
  - [ ] an updated refund and cancellation text.
- **Order:** accounts (F) before payments. A purchase tied to an anonymous token is lost with the phone, and Play policy expects people to keep what they bought.

## H. Google Play submission

- [x] Targets API 36 (required for new apps and updates from 31 Aug 2026); min SDK 24.
- [x] 16 KB page alignment: all 10 native libraries pass `zipalign -P 16`.
- [x] Only the INTERNET permission; the camera goes through the system picker. No location, contacts or ads ID.
- [x] Privacy policy in the app; consent notice with 18+; in-app delete.
- [~] Privacy policy at a **public URL** (no PDF). **(Play)** Written, not hosted. Fill in the publisher name, contact and grievance officer (blanks today).
- [ ] **Release keystore**, generated and backed up twice. Losing it means you can never update the app. **(Play)** Then enrol in Play App Signing.
- [ ] **Upload an app bundle, not an APK. (Play)** New apps must use `.aab`: `flutter build appbundle --release --dart-define=API_BASE_URL=https://<deployed-url>`. The docs only show `flutter build apk`.
- [ ] Developer account. **(Play)** A new personal account must run a **closed test with at least 12 testers for 14 days in a row** before production. An organisation account (D-U-N-S) is exempt.
- [ ] **Health apps declaration** (App content). **(Play)** Answer for a nutrition and food-label app, not medical.
- [ ] **Data safety form. (Play)** Collected:
  - health info (profile), photos, app activity (scans), device id (the token);
  - shared with Google Gemini (processor) and Supabase (processor);
  - encrypted in transit; deletion available (in-app, plus the web link once accounts exist).
- [ ] Content rating questionnaire; target audience 18+; **not designed for children**. **(Play)**
- [ ] Store listing: icon (the legacy `mipmap` PNGs are still Flutter's default), screenshots, feature graphic, short and full description. **(Play)** Say "not medical advice" there too, and make no medical claims (Play's Health content policy).
- [ ] A release build tested on a real phone against the deployed server, with the laptop off and on mobile data. **(Launch)**
- [ ] Gemini on the paid, no-training tier (or Vertex) before any outside tester. **(Launch)**

## I. Quality

- [x] 520 backend tests, 93 app tests, analyzer clean, run in CI.
- [x] Accessibility tests (text scaling); 5 languages, Khasi pending review.
- [ ] **A label-accuracy test on 50–100 real Indian packs** (`scripts/run_eval.py`), with allergen recall measured. **(Launch)** It's the core promise.
- [ ] Dietitian review of the thresholds and Khasi translation review (founder).
- [ ] Reduce the 105 mypy errors (keeps typed code honest).

## J. A 20-point security list, checked against CalFit (2026-10-29)

| Item | CalFit |
|---|---|
| Hide API keys | [x] all keys on the server; the app holds none (`AGENTS.md` §5) |
| Purge Git secrets | [x] history scrubbed, gitleaks in CI. [ ] rotate the keys exposed earlier |
| Use the public DB key | [x] better: the app has **no** database key; only our server talks to Supabase |
| Enable RLS | [x] every table, no policies; the public key reads nothing (tested live) |
| Encrypt sensitive data | [x] TLS in transit; Supabase encrypts at rest; tokens in the Android Keystore. [ ] column-level encryption of health data: not done (optional) |
| Enforce server-side auth | [x] signed token on every route; consent gate on health-data routes |
| Lock record access | [x] user id only from the token; someone else's scan reads as 404; photo paths checked |
| Block field tampering | [x] Pydantic request models; the app can't set `user_id`, nutrition or score |
| Secure session cookies | n/a: no cookies (bearer tokens in the Keystore) |
| Hash passwords | n/a: no passwords. Google sign-in will go through Supabase Auth |
| Rate-limit login | [x] identity creation capped per IP; per-route request cap; daily scan cap |
| Bot protection | [~] the caps above. [ ] Play Integrity on identity creation (E) |
| Parameterise queries | [x] every SQL value is a `?` parameter or a PostgREST builder call (checked) |
| Validate all input | [x] Pydantic, size limits, image type sniffed from the bytes, label numbers sanity-checked |
| Escape user content | [x] Flutter `Text` doesn't render HTML; AI output is grounding-checked; prompts carry an injection guard |
| Restrict file uploads | [x] size before reading, real type sniffed, GPS stripped, private bucket |
| Trim API responses | [x] the AI's free-text notes are replaced by our own message; error bodies never echo data |
| Security headers | [x] added 2026-10-29: `nosniff`, `X-Frame-Options`, `Referrer-Policy`, `Cache-Control: no-store`, CSP, HSTS in production (`test_security_headers.py`) |
| Force HTTPS | [x] app allows cleartext only to localhost; Cloud Run is HTTPS-only; HSTS in production |
| Scan dependencies | [x] Dependabot (pip, pub, actions, docker) and pip-audit in CI |

---

## Order of work

1. ~~Plausibility checks~~ and 2. ~~time budget, refunds, idempotency key~~: **done 2026-10-29.** Apply migration 012 to Supabase so refunds work there.
3. **New Gemini key on the paid tier; rotate the old keys; deploy to Cloud Run** (min-instances 1, budget alert, log retention, uptime check).
4. **Supabase Pro** (backups, no pausing). Decide on Mumbai now if you're going to move.
5. **Crash reporting**, disclosed in the policy and the notice.
6. **Release keystore, signed app bundle, phone test on mobile data.**
   - **Your 31 scans:** a release-signed build can't install over the debug one, and uninstalling wipes the Keystore token.
   - So keep **your** phone on debug builds until accounts (step 8) can re-link your identity.
   - Or test the release build on a second phone or a fresh profile.
7. **Play Console:**
   - developer account;
   - host the policy;
   - Data safety, Health declaration, content rating;
   - listing;
   - closed test with 12 testers for 14 days. Start this clock early; it's the slowest step.
8. **Accounts:** Supabase Auth plus Google sign-in (F), with the web deletion page. Link your phone's identity first, then move to release builds.
9. **Payments:** Play Billing with server verification (G).

## Sources

- Play: [12 testers for 14 days](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- Play: [target API level](https://developer.android.com/google/play/requirements/target-sdk)
- Play: [account deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
- Play: [health content and services](https://support.google.com/googleplay/android-developer/answer/16679511?hl=en)
- Play: [user data](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)
- Play: [payments policy](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en)
- Play: [India billing](https://support.google.com/googleplay/android-developer/answer/13306652?hl=en)
- Play: [user choice billing](https://support.google.com/googleplay/android-developer/answer/13821247?hl=en)
- Supabase: [`linkIdentityWithIdToken`](https://supabase.com/docs/reference/dart/auth-linkidentitywithidtoken)
- Supabase: [native mobile auth](https://supabase.com/blog/native-mobile-auth.md)
- LLM reliability (timeouts, validation, fallbacks, circuit breakers): [OneUptime](https://oneuptime.com/blog/post/2025-09-01-production-llm-apps/view)
- LLM reliability: [DEV: guardrails in production](https://dev.to/cyclopt_dimitrisk/ai-guardrails-in-production-the-boring-engineering-that-makes-ai-features-actually-work-7gk)
- LLM reliability: [agent-patterns error handling](https://agent-patterns.readthedocs.io/en/stable/guides/error-handling.html)
