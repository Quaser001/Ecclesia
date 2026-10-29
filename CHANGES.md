# CalFit — Change Log

Each entry records a focused improvement, the files touched, and the reason, so you can review before shipping to Play Store.

---

## 2026-10-27 — Prescription suggestions (off by default)

Profile → Prescription: photograph a prescription, Gemini transcribes it, the app proposes conditions and allergies, and the user ticks what to add. Plan: `docs/superpowers/plans/2026-10-27-prescription-suggestions.md`.

- **Backend:** `POST /api/v1/profile/prescription-suggestions` (auth required). Gemini only transcribes (`GeminiProvider.analyze_prescription`); `services/prescription_service.py` maps text to `HealthCondition` deterministically. Medicine-based matches are marked `inferred_from_medicine`.
- **Privacy:** photo and extracted text are never stored, saved to history, or logged (tests enforce this). No medicines are stored. Disabled unless `PRESCRIPTION_AI_ENABLED=true`; separate cap `PRESCRIPTION_DAILY_CAP=5`. Do not enable before Gemini is on the paid tier.
- **Edge cases covered:** "NKDA"/"nil" is not an allergy; drug allergies are not offered as food allergies; text on the page cannot add a condition; items already on the profile are not re-suggested; unreadable photo returns an empty result, never invented items.
- **Flutter:** consent sheet (once), camera/gallery picker, review screen with nothing pre-ticked, saved through the existing profile update; the picker's temp file is deleted afterwards.
- **Independent review (fresh reviewer) fixed in this change:** the label JSON parser logged up to 200 characters of model output, and the provider logged exception text. The prescription path now has its own non-logging parser and logs only exception class names, with tests against the REAL provider. Also fixed: negated/history/non-systemic diagnoses ("No hypertension", "Family history of…", "pulmonary hypertension") are no longer suggested; "NKFA"/"none known"-style entries and drug allergies mislabelled as food are no longer offered (a fixed non-food allergen list is the rule; only items the model labels *food* are offered); a malformed model reply is now a 502 and tries the next model instead of saying "not a prescription"; confirming merges onto the *current* profile so edits made during the read are kept; Anaemia and Prediabetes chips added so suggested conditions can be removed; response text no longer printed to logcat.
- **Deferred minors:** blurry-photo case doesn't set `insufficient_data`; photo is uploaded before the feature-off check (app should hide the card); the daily counter is spent by failed requests; `scan_usage` keeps per-day `rx:` rows; double-tap can start two flows; Indian shorthand like "DM"/"K/C/O DM" isn't matched; `is_prescription` model default is `True`; a few test gaps (post-read size check, real limiter, `_scanPrescription` widget test); unscaled camera original may remain in the picker cache (check on device).
- **Tests:** backend 188 pass; Flutter 19 pass. The live Gemini call has not been exercised with a real key.

---

## 2026-10-27 — Security audit fixes: signed device tokens, upload path traversal

From the OWASP review of the API and Flutter client.

- **Path traversal fixed.** `LocalStorageProvider.upload_image` now resolves the destination and refuses anything outside `uploads/<bucket>/`. Previously a crafted `user_id` form field could write outside the uploads folder.
- **Authentication added.** The client no longer chooses its `user_id`. `POST /api/v1/auth/device` mints a server-generated id plus an HMAC-signed bearer token (`AUTH_SECRET_KEY`, >= 32 chars). `/profile` and `/scans*` take the id only from the verified token. Missing secret returns 503, never an open API.
- **Registration capped** at `DEVICE_TOKEN_DAILY_CAP_PER_IP` (default 20) per client IP per UTC day, so new identities cannot be minted to dodge the scan quota. The counter is per-process; use an edge limit (Cloud Armor) for multi-instance deployments.
- **Flutter:** `ApiService` registers on first use, stores the token (`AuthTokenStore`), sends it on every call, and re-registers once on a 401. `DeviceIdService` is now vestigial.
- **Existing data:** history keyed by old client-made ids is not linked to the new server-issued ids.
- **Setup required:** add `AUTH_SECRET_KEY` to `apps/api/.env` (see `.env.example`) and to Secret Manager for deploys.
- Tests: `test_device_tokens.py`, `test_auth_endpoints.py`, `test_storage_safety.py`, `test_api_endpoints.py` updated; Flutter `api_service_auth_test.dart`.

---

## 2026-10-27 — Live Supabase database, durable scan quota, first-scan fix

Set up the hosted database and fixed three bugs that would only have appeared
once the app left the laptop. Every one of them was invisible locally.

### Live Supabase project
- Project `calfit` created in `ap-south-1` (Mumbai), URL `https://trmohgpjtldwxbpoqvpn.supabase.co`.
  - **Superseded (2026-10-29):** the app uses the Singapore project `CalFit` (`rxqsyksydnmwtslfvwll`). This one held only a test identity and is being deleted.
- Schema applied, plus the migrations below. 12 knowledge-base rows seeded.
- The `alternatives` rows from `002_seed_dev_data.sql` were deliberately NOT
  seeded: they are labelled "DEV DATA: Example entry", and a real user would
  have seen "Lower-Sodium Instant Noodles Example" presented as a
  recommendation. That breaks the no-fake-data rule in agents.md.
- Row Level Security is on for every table with no policies, so the public
  anon key gives access to nothing. The backend uses the service_role key,
  which bypasses RLS. If the anon key ever leaks, the database stays shut.

### Bug 1 — the first scan of every new user would have failed
`scans.user_id` has a foreign key to `profiles.user_id`, but nothing created a
profile row. A fresh install has no profile until the user opens the profile
screen, so the first scan violated the constraint. SQLite does not enforce
foreign keys by default, which is why this passed locally and would only have
failed in production. Worse, `_persist_scan` swallows exceptions with a
warning, so the scan would have vanished with no error shown to the user.
- `ensure_profile_exists(user_id)` added to the provider interface and to both
  providers; called in `_persist_scan` before the insert. Idempotent, and
  tested not to overwrite a profile the user has already filled in.
- Verified against the live database: the insert is rejected without the
  profile row and succeeds with it.
- Files: `providers/interfaces.py`, `providers/supabase_provider.py`,
  `providers/local_db_provider.py`, `orchestration/scan_graph.py`

### Bug 2 — schema drift on `avoid_caffeine`
The caffeine sensitivity flag was added to the profile model and to the SQLite
provider, but never to the Postgres schema, so `upsert_profile` would have
failed against Supabase. Added as migration 003.

### Bug 3 — `CREATE EXTENSION pgvector` does not exist
The extension is named `vector`. As written, `001_schema.sql` fails on the
first statement against a fresh Supabase project, so nobody could have run it.
Fixed, and the `ivfflat` index is now commented out with a note: built on an
empty table it has no useful centroids, so it should be created after the
knowledge table holds embeddings.

### Daily scan cap is now durable
`InMemoryStore` resets on every restart and is not shared between Cloud Run
instances, so a user could take `cap * instances` scans a day and a redeploy
cleared everyone's count. Added `SupabaseCounterStore`, backed by a
`scan_usage` table and an atomic `increment_scan_usage()` function that
returns the post-increment count in one round trip, so two concurrent scans
cannot both be told they are under the cap.
- `CounterStore.increment` and `ScanLimiter.check_and_increment` are now
  async; the endpoint awaits them. `InMemoryStore` is kept for tests and for
  local runs with no database configured.
- `get_scan_limiter` picks the database-backed store whenever Supabase is
  configured.
- The database owns the UTC date, so a caller-supplied day is ignored by the
  DB store. Trusting one clock avoids a free extra scan around midnight when
  instances disagree.
- Files: `services/rate_limit.py`, `config/dependencies.py`, `api/v1/scans.py`

### Security fix found by the Supabase advisor
`increment_scan_usage` was created as `SECURITY DEFINER` in the public schema,
which made it callable over `/rest/v1/rpc` by anyone holding the public anon
key — enough to burn through another user's daily allowance. `EXECUTE` is now
revoked from `public`, `anon` and `authenticated`, and granted only to
`service_role`. Migration 005.

### Mobile
- `DeviceIdService` wrote the new device id without awaiting it. If the write
  did not land before the app was killed, the next launch minted a different
  id and the user silently lost their scan history. Now awaited.

### Tests
76 pass. New: `tests/test_profile_bootstrap.py` (profile row created before the
scan insert, idempotent, does not overwrite real data, local quota counter) and
a rewritten `tests/test_rate_limit.py` (async, plus the database-backed store
and its day-handling contract).

### Migrations added
- `003_profile_avoid_caffeine.sql`
- `004_rls_and_scan_usage.sql`
- `005_lock_down_quota_function.sql`

Numbering note: these were applied to the live project earlier in the session
under slightly different names; each file records which.

### Docs
- Added `docs/LAUNCH_CHECKLIST.md`: everything done and everything left between
  here and a cloud-hosted app running on a phone with the laptop closed, grouped
  by what each item blocks.
- `docs/DEPLOY_CLOUD_RUN.md` section 6 was made stale by the quota change today
  (it described the cap as in-process). Rewritten, and the note about
  `--max-instances` affecting quota correctness removed, since the counter now
  lives in Postgres.

### Left for you
- Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (dashboard → Settings →
  API). Until then the backend silently uses local SQLite.
- Three probe rows from the foreign-key test are still in the live database
  (`scan_id = 'fk-probe'`, `user_id = 'device-with-no-profile'`); the cleanup
  was not approved in-session. SQL to remove them is in the session notes.
- A free Supabase project pauses after a week idle and must be restored by hand.
- The exposed API keys in `apps/api/.env` still need rotating.

---

## Session boundary — 2026-10-26 end of day

### Where we are
- **Backend**: FastAPI + LangGraph + Gemini. Local SQLite at `apps/api/data/calfit.db` is the live backend; profile data (incl. `avoid_caffeine`) round-trips end-to-end. Supabase provider is wired and ready; it switches on automatically when `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` land in `.env`. **81 tests pass.**
- **Mobile**: Flutter 3.41 Android app. Anonymous device UUID persisted on first launch; "not medical advice" dialog gates onboarding; branded splash + adaptive launcher icon in place; release-signing scaffold wired into Gradle; first-scan result screen footers the disclaimer. **`flutter analyze` clean, 2 widget tests pass.**
- **Verified in-browser** on Flutter web with the API: Home dashboard loads, Profile persists ("Asef"), navigation works, CORS correct for localhost at any port.
- **Deploy docs**: `docs/DEPLOY_CLOUD_RUN.md` (asia-south1), `docs/RELEASE_SIGNING.md`, `docs/GEMINI_BILLING.md`, `docs/PRIVACY_POLICY.md` (DPDP Act 2023).

### What's blocking next
- Supabase credentials — you'll provide; local SQLite covers us until then.
- Play Store developer pass — you'll buy; signing config and privacy policy are ready.
- **No git repo yet** — the project is not under version control.

### For the next session
1. **Set up GitHub repo.** `git init` at `C:\Users\asef6\OneDrive\Desktop\CalFit`, verify the existing `.gitignore` catches `.env`, `apps/mobile/android/key.properties`, `*.jks`, the SQLite file, and build outputs. Scrub for any already-committed secrets (there is no history, so this is just a pre-flight on the first commit). First commit, then push to a private GitHub repo.
2. **Rotate the three exposed keys** (`GEMINI_API_KEY`, `GROQ_API_KEY`, `CEREBRAS_API_KEY`) before anything is pushed, in case `.env` was ever outside the ignore pattern.
3. **Supabase schema**: draft `supabase/migrations/001_init.sql` with `profiles`, `scans`, `knowledge` tables matching the Pydantic models (including `avoid_caffeine`), plus device-id-based RLS; apply when the project is created.
4. **End-to-end scan**: with Gemini and Supabase both live, run one real product photo through the pipeline from the Android device.
5. **Evaluation set**: fill in the first 10 rows of `apps/api/data/eval/labeled_products.csv` with real Indian products.

### Nothing is running
API uvicorn and Flutter web dev servers were started briefly for in-browser QA this session; both are stopped now. The SQLite database file at `apps/api/data/calfit.db` persists.

---

## 2026-10-26 (late evening) — Local-storage profile fallback + API wiring

"The API's not working and the dashboard says it can't reach it." Diagnosis:
1. The API process from the earlier session was already stopped; "can't reach your dashboard" is the Home screen's error state (`home_screen.dart:122`), not an app bug.
2. `avoid_caffeine` was added to `UserProfile` and `UserProfileRequest` earlier, but was never persisted — the PUT /profile endpoint silently dropped it, the SQLite schema didn't know about it, and the Supabase provider didn't send it either.

### Local SQLite is now the real MVP backend
- `apps/api/src/providers/local_db_provider.py` — the `profiles` table gains `avoid_caffeine INTEGER NOT NULL DEFAULT 0`. An additive `ALTER TABLE ... ADD COLUMN` runs on boot, inside a `try/except sqlite3.OperationalError`, so a pre-existing `data/calfit.db` from the last session picks it up without losing rows.
- `_row_to_profile` reads the new column with `try/except (IndexError, KeyError)` so a row from the old schema still loads (returns `avoid_caffeine=False`) instead of throwing.
- `upsert_profile` now writes `avoid_caffeine` and keeps the ON CONFLICT update list in sync.
- `apps/api/src/api/v1/profiles.py` — the PUT endpoint actually passes `body.avoid_caffeine` into the saved `UserProfile`. This was the hole.
- `apps/api/src/providers/supabase_provider.py` — mirrored for the Supabase path: `avoid_caffeine` added to the row payload in `upsert_profile`, and `_row_to_profile` reads it back with a `False` default so a Supabase column that hasn't been migrated yet still returns a usable profile.

### Verified end-to-end in the browser
- Restarted uvicorn + a fresh Flutter web build on port 5002 (5000/5001 held by zombie Dart processes from earlier runs — port churn, not a bug).
- Home: "Good night, Asef" greeting (the name "Asef" was persisted from a prior session's PUT — proof the local SQLite round-trip works).
- Profile: avatar initial "A", subtitle "Signed in anonymously on this device" (last pass's UX fix, now visible), goals / conditions / diet rows render.
- Network: `GET /api/v1/profile?user_id=...` returns 200, `GET /api/v1/scans/history?user_id=...` returns 200. No console errors.
- The "can't reach your dashboard" state only appears when the API is actually down — Home's error branch kicks in and shows a Try again button, which is correct behaviour.

### Tests
- **New** `apps/api/tests/test_local_db.py` — 3 tests: round-trip profile with `avoid_caffeine=True` and anaemia condition; upsert flips the flag to false; opening a provider against a pre-`avoid_caffeine` DB file applies the ALTER migration and still loads the old row.
- `uv run pytest -q`: **81 passed** (78 → 81, no regressions).

### Behavioural note
No new dependencies. No mock data path added — the provider is a real SQLite file at `apps/api/data/calfit.db`. When `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` land in `.env`, the dependencies factory in `dependencies.py:get_supabase_provider` switches to the Supabase provider automatically; the local DB file remains on disk, untouched, as a backup.

---

## 2026-10-26 (evening) — Stand-alone groundwork + browser-driven QA

Goal: everything from priority #4 "make it standalone" that doesn't need the Supabase credentials you'll give me, plus the Play Store prerequisites that don't need the developer pass. Then: open the app in a browser, interact with it, fix what breaks.

### Anonymous device ID
- **New** `apps/mobile/lib/services/device_id_service.dart`. On first launch it generates a RFC-4122 v4 UUID with the platform's secure RNG, stores it in `SharedPreferences`, and `main.dart` passes that id into `BottomNavigation` instead of the hard-coded `dev-user-001`. Uninstall / clear-data wipes it; a `rotate()` method is there for a future settings "reset data" button, nothing calls it today.
- No new dependency — `shared_preferences` was already in `pubspec.yaml`.

### Server-side daily scan cap
- **New** `apps/api/src/services/rate_limit.py`. `ScanLimiter` + swappable `CounterStore`; ships with a thread-safe `InMemoryStore` (one Cloud Run instance = one dict, which is enough for MVP; a replica restart resets the counter early, which is safer than over-counting). `apps/api/src/api/v1/scans.py` now rejects scans with HTTP 429 above the cap, before reading the photo.
- `DAILY_SCAN_CAP=50` default, overridable via env.
- **New** `tests/test_rate_limit.py` — 4 tests: blocks after cap, isolates users, resets at UTC midnight, empty id falls into a shared bucket (never fail-open).

### "Not medical advice" disclaimer
- **New** `apps/mobile/lib/core/widgets/medical_disclaimer.dart`. One source of truth for the copy:
  - A **one-time first-launch dialog** ("A quick note before you start") shown from `BottomNavigation.initState` via `addPostFrameCallback`. Non-dismissible until the user taps "Got it". Ack flag persisted in `SharedPreferences`.
  - A `MedicalDisclaimerFooter` tile that sits under every scan result so the reader never forgets the frame.

### Dockerfile + Cloud Run deploy
- **New** `apps/api/Dockerfile`. Two-stage, `python:3.12-slim` base, pinned uv `0.4.30` from `ghcr.io/astral-sh/uv`, `uv sync --frozen --no-dev` reproducible from `uv.lock`. Non-root user, single worker, honours Cloud Run's `$PORT`.
- **New** `apps/api/.dockerignore` — keeps `.env`, caches, `tests/`, `data/eval/photos`, the SQLite dev DB out of the image.
- **New** `docs/DEPLOY_CLOUD_RUN.md` — step-by-step: enable APIs, Artifact Registry, Secret Manager for `GEMINI_API_KEY` / `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY`, dedicated service account, `gcloud run deploy` with `--max-instances 3` as a soft cost ceiling. Target region `asia-south1` (Mumbai).

### Release signing scaffold
- `apps/mobile/android/app/build.gradle.kts` now reads `android/key.properties` if present and signs the release build with it; falls back to debug so a fresh clone still builds. No new secrets committed — `key.properties` and `*.jks` are already gitignored.
- **New** `apps/mobile/android/key.properties.example` — the template to copy.
- **New** `docs/RELEASE_SIGNING.md` — `keytool` command, Play App Signing enrollment, pre-upload sanity checks.

### Privacy policy under DPDP Act 2023
- **New** `docs/PRIVACY_POLICY.md` — written for India's Digital Personal Data Protection Act 2023. Covers data types, sensitive personal data (health conditions, allergies), legal bases, processors (Gemini, Supabase, Cloud Run), 90-day retention for scans / 30-day for logs, your rights under §11-§15, Grievance Officer under §13. Two fields marked `_(fill in before Play Store submission)_`: the privacy contact email and the Grievance Officer. The policy also says plainly, at the end, "not medical advice".

### Branded splash + adaptive launcher icon
- **New** `apps/mobile/android/app/src/main/res/values/colors.xml` mirroring the Flutter brand palette (`calfit_bg_dark`, `calfit_verdict`, `calfit_ember`, `ic_launcher_background`).
- **New** `drawable/ic_calfit_mark.xml` — a vector mark: an ember "C" with a verdict-green leaf-tick inside. Reads as "food + check" without using an apple-and-leaf cliché.
- **New** `drawable/launch_background.xml` + `drawable-v21/launch_background.xml` — both now paint the brand dark colour and centre the mark, replacing the Flutter default (white or OS theme colour). No more white flash on cold start.
- **New** `mipmap-anydpi-v26/ic_launcher.xml` + `ic_launcher_round.xml` — adaptive icon for API 26+; older OS versions fall back to the existing PNG mipmaps the Flutter template already ships.

### Gemini paid billing + spend cap doc
- **New** `docs/GEMINI_BILLING.md` — step-by-step to move off the free tier (which trains on prompts), set a Cloud Billing budget alert, set a hard quota cap on the Generative Language API, rotate the key under the new paid project, and verify no free-tier fallback can route traffic.

### Browser QA — what broke, what was fixed
Opened the Flutter web build inside the in-app browser (`flutter run -d web-server --web-port 5001`) with the FastAPI running locally. Two bugs surfaced:

1. **CORS blocked every API call from the Flutter dev server.** Browsers compare origins exactly, so the dev CORS allow-list of `http://127.0.0.1` did not match `http://127.0.0.1:5000`. Fix in `apps/api/src/main.py`: when `CORS_ALLOWED_ORIGINS` is unset, use `allow_origin_regex=r"^http://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$"` instead of a port-less string list. Production still uses the strict explicit list.
   - **New** `tests/test_cors.py` — locks in: allows Flutter web dev port, allows any localhost port, allows the Android emulator alias, blocks `https://evil.example.com`.
2. **Profile screen displayed the raw device UUID** as the subtitle under "Add your name". Replaced with "Tap the pencil to introduce yourself" / "Signed in anonymously on this device" in `apps/mobile/lib/features/profile/profile_screen.dart`. The UUID is for the server, not the human.

Verified after the fix:
- First-launch disclaimer dialog shows and blocks until "Got it" is tapped.
- API calls return 200 (preflight `access-control-allow-origin: http://127.0.0.1:5000`).
- Device ID persists in `localStorage` (`flutter.calfit.device_id`), survives reload, is unique per browser profile.
- Navigation between Home / History / Profile / Scan all render; empty states copy is in good shape.

### Tests
- API: **78 passed** (4 new CORS + 4 new rate-limit + the 70 we already had, none regressed).
- Mobile: `flutter analyze` reports 2 pre-existing info-level items, `flutter test` is green.

### Known gaps for the next session
- Image upload on web — `image_picker` on web opens the browser's file picker but we didn't exercise an end-to-end scan in this round. Smoke-test with a real label photo once the Supabase + Gemini keys are plugged in.
- Minor layout crowding: on narrow viewports (~400px) the centred Scan FAB sits very close to the "History" nav label. Not blocking, but worth tightening when we revisit `bottom_navigation.dart`.
- The anonymous device id is still the only identifier. If someone replays another device's id, they see that device's scans. Needs real auth before "sign in" is anything more than a brand phrase.

---

## 2026-10-26 (afternoon) — Reviewable rule set + anaemia + extraction guards

Goal: let a dietitian audit every scoring threshold without reading Python, add the condition rules closest to our first users' lives, and close the three gaps the last pass flagged.

### Rule catalog — one reviewable source of truth
- **New** `apps/api/src/domain/rule_catalog.py`. One `RuleSpec` dataclass per threshold with: id, condition, nutrient/ingredient, threshold, unit, direction, severity, score impact, **source citation** (WHO sodium 2012, WHO sugars 2015, WHO trans-fat, AHA, FSSAI labelling/fortification, ICMR-NIN, NFHS-5, KDIGO, Codex), **evidence tier** (`strong` or `sensitivity`), title, detail template, and a free-text `notes` field for reviewer caveats. All rules in one list, in the order a dietitian would read them.
- `apps/api/src/domain/scoring_rules.py` now reads thresholds, titles, details, sources and tiers from the catalog instead of hard-coding them in the rule functions. The functions became thin filters on top of the catalog.
- Every `ScanFinding` now carries `source` and `evidence_tier` (new fields on the model). Users will see **why** a product was flagged, and the Flutter side can style `sensitivity` findings differently from medical ones.

### New rules
- **Anaemia / iron deficiency** (`RULE-011A..D`). Addresses the 57% of Indian women aged 15–49 anaemic in NFHS-5. Iron content ≥ 4 mg/serving earns a bonus; FSSAI +F iron fortification earns a smaller bonus; vitamin C in the ingredients adds an absorption note; tea / coffee / cocoa in a food gets a `WARNING` with the "one hour away" guidance, with `tea tree` carved out so it does not match. `WARNING` is deliberate — the magnitude is uncertain and we don't want to over-penalise.
- **Caffeine sensitivity** (`RULE-012`). User toggles `avoid_caffeine` on their profile. Infers from the ingredient list only (coffee, tea, guarana, cola nut, mate, kola nut, caffeine) because Indian labels rarely print caffeine in mg. Tier is `sensitivity`, severity is `INFO`, detail says plainly "not as a medical warning". Replaces the "period cramps" idea — a toggle serves both without being a medical claim.
- **May-contain cross-contact** (`RULE-001D`). New `ProductObservation.may_contain: list[str]` field. For a user allergic to peanut, a "may contain peanut" statement produces an `ALERT`, not a clear pass. It is NOT a hard stop — a cross-contact statement is not a declared ingredient — so the score drops but doesn't cap at 15. Extraction prompt was updated to populate the field; the Gemini provider now parses it.

### Removed
- No code for **hypotension** existed; confirmed it is not in `HealthCondition` and no rule referenced it. Nothing to remove, matches the engineering decision.

### Scored, not fabricated
- **Extraction confidence gate** in `apps/api/src/orchestration/scan_graph.py:node_validate_extraction`. Below `MIN_EXTRACTION_CONFIDENCE = 0.4` (declared in the catalog with the reason), the scan returns insufficient-data instead of a verdict. A confident "Not Suitable" or "Good" from a shaky read is the worst possible failure mode for a health app.
- **Gemini structured output**. `apps/api/src/providers/gemini_provider.py` now passes a JSON Schema (`_EXTRACTION_SCHEMA`) as `response_schema` to `GenerateContentConfig`. The old regex rescue parser stays as a fallback for responses that slip through.

### Model additions
- `HealthCondition.PREDIABETES` and `HealthCondition.ANAEMIA` added. Sugar rules now fire for prediabetes too.
- `NutritionInfo.iron_mg` and `NutritionInfo.vitamin_c_mg` added. The extraction prompt asks for them; the parser accepts them.
- `UserProfile.avoid_caffeine: bool` added. Non-medical sensitivity flag.
- `ScanFinding.source: str` and `ScanFinding.evidence_tier: EvidenceTier` added, defaulting to `strong`.

### Evaluation harness
- `apps/api/data/eval/labeled_products.csv` — a 30-row template to fill in by hand. One row per real Indian product with a photo, ground-truth ingredients, allergens, may-contain, and the four most important nutrition numbers.
- `apps/api/data/eval/README.md` — how to fill the sheet; the point is a human-labelled ground truth, not Gemini's own output.
- `apps/api/scripts/run_eval.py` — runs the pipeline over the CSV, reports **allergen recall** (the number that matters), allergen precision, mean absolute error on each nutrition field, and a disagreements list with one line per product × field that diverged from the label by more than 20%.

### Tests
- **New** `apps/api/tests/test_new_rules.py` — 12 tests covering: catalog uniqueness + round-trip, every finding has a source + tier, may-contain is an alert not a hard stop, may-contain without a matching allergy is silent, anaemia rules are dormant off, iron-rich fortified product scores at 100, tea triggers inhibitor, `tea tree` doesn't, amla fires the vitamin-C note, caffeine fires only when opted in, caffeine detail is grounded, prediabetes triggers the sugar rule, confidence gate rejects low confidence and accepts adequate confidence.
- Fixed two stale assertions in `tests/test_api_endpoints.py` that still used renamed rule IDs.
- 70 tests pass, 0 skipped.

### Mobile (small cleanup)
- Removed an unused `surface_card.dart` import in `apps/mobile/lib/features/scan/scan_screen.dart`. `flutter analyze` now reports 3 info-level items (unused underscore, unnecessary import, nothing user-facing). `flutter test` passes.

### Known gaps (next session)
- The CSV template is empty — you need to fill in real products and photos for the eval to produce numbers.
- `avoid_caffeine` is not yet surfaced on the Flutter profile screen.
- Rule-catalog `source` strings are short citations, not links. A later pass could point each at a public document.

### Secrets rotation needed
These keys in `apps/api/.env` were in the exposed set and still need rotating. Values intentionally not printed here.

- `GEMINI_API_KEY` — rotate at https://aistudio.google.com/apikey (delete the current key, create a new one, paste back).
- `GROQ_API_KEY` — rotate at https://console.groq.com/keys.
- `CEREBRAS_API_KEY` — rotate at https://cloud.cerebras.ai/platform/ (API keys section).
- `GROK_BASE_URL`, `GROK_VISION_MODEL`, `GROK_TEXT_MODEL`, `GROQ_BASE_URL`, `GROQ_TEXT_MODEL`, `CEREBRAS_BASE_URL`, `CEREBRAS_TEXT_MODEL`, `GEMINI_MODEL` — config, not secrets. No rotation.

Also check: `apps/api/.env` is in `.gitignore` (verified), but if a previous commit touched it, the git history still holds the old values and the above providers must still be rotated.

---

## 2026-10-26 — Accuracy and safety hardening (rules, prompts, guards)

Goal: make wrong or unsafe verdicts much harder to produce, and make every failure visible instead of silent.

### Scoring rules (`apps/api/src/domain/scoring_rules.py`)
- **Allergen match is now a hard stop.** Before, a matched allergen only subtracted 45-50 points, so a product containing the user's allergen could still read "Fair" (score ~50). Now any allergen match, and gluten for celiac disease, caps the score at 15 = Not Suitable.
- **Allergen synonyms.** Matching was a plain substring check, so milk-allergic users were not warned about casein, whey, ghee, paneer or curd, and peanut-allergic users were not warned about groundnut. Added a vocabulary for milk, peanut, tree nuts, wheat, gluten, soy, egg, fish, shellfish, sesame and mustard, including Indian names (maida, atta, suji, paneer, til, sarson).
- **Whole-word matching.** "nut" no longer matches nutmeg or coconut; "egg" no longer matches eggplant; coconut milk, cocoa butter and peanut butter no longer count as dairy.
- **Unreadable label is never "safe".** If the user has allergies and no ingredients or allergens could be read, a warning finding is added (RULE-001C) and the score drops.
- **Failed rules are visible.** A rule that raised an error was silently skipped. It now adds a visible "one check couldn't be completed" finding and the result can no longer score "excellent".
- **Sodium bug.** The "salty ingredients" fallback fired even when the label's sodium was known and low, so plain `salt` in any food penalised hypertensive users by 25 points. It now runs only when sodium could not be read.

### Extraction prompt and parser (`prompts/extraction.py`, `providers/gemini_provider.py`)
- Prompt rewritten as a transcription-only task: label text is treated as data (prompt-injection guard), unreadable values must be null, ingredients copied verbatim in printed order, allergens only from the "Contains" statement, "may contain" text kept in notes, values per serving (or per 100 g with a note).
- **Salt is no longer treated as sodium.** The parser used to copy a `salt` value into `sodium_mg`. Salt is now converted (1 g salt = 400 mg sodium) in code, never by the model.
- Missing extraction confidence used to default to 0.9; now 0.5, and values are clamped to 0-1.
- Per-nutrient confidence flags now respect the model's "unsure" answer instead of being true whenever a number exists.
- Extraction temperature 0.0; explanation 0.1. The prompt is passed as a system instruction.
- Gemini calls now use the async client, so one slow scan no longer blocks every other request.

### Explanation prompt and guard (`prompts/explanation.py`, `services/explanation_service.py`)
- Prompt rewritten: verdict is final, only facts inside tags may be used, never claim "safe" or "allergen-free", no medical advice, 2-3 sentences, label text is data.
- New guard `is_explanation_grounded`: the explanation is rejected (and the rule-based fallback is used) if it is empty, claims safety, uses medical-advice wording, or contains any number not in the verified facts.

### Tests
- Fixed three stale tests that were already failing (renamed rule IDs, a sugar threshold, and a low-sodium case now handled by the real fix above).
- Added tests for allergen synonyms, look-alike ingredients, hard stop, celiac, unreadable labels, failed rules, salt-to-sodium conversion, confidence handling and the explanation guard. 48 tests pass in a clean environment.

### Not done yet
- "May contain" is only kept in notes; it needs its own field and rule.
- No gate on `extraction_confidence` in `validate_extraction` (scan_graph.py).
- No labelled evaluation set measuring allergen recall on real Indian products.
- Gemini structured-output schema is not used yet.

---

## 2026-10-25 — Visual identity + premium polish (design pass)

The goal of this pass: stop looking AI-generated. The signs were specific — a nonexistent "Segoe UI" font, every surface wrapped in a 2021-style glass card, generic "Better food choices. A healthier you." marketing voice, three sales badges on the scan screen while the user is already scanning, a static jump-to-value score ring, and no haptics anywhere.

### 1. Real typography — Fraunces + Plus Jakarta Sans
- **Files:** `apps/mobile/lib/app/app_theme.dart`, `apps/mobile/pubspec.yaml` (added `google_fonts: ^6.2.1`)
- **Why:** The theme set `fontFamily: 'Segoe UI'`, which is a Windows system font and does not exist on Android. The app was silently falling back to Roboto on every device. Classic generated-code tell.
- **Change:** Two Google Fonts, one job each.
  - **Fraunces** (variable serif) is used *only* for verdict moments: the score number, product name on the result screen, greeting on home. Serif reads as "we considered this" — the exact feeling CalFit should give when it tells you a product does or doesn't fit your health profile.
  - **Plus Jakarta Sans** for everything UI: buttons, labels, body. Slightly warmer than Inter, less commodified. Not the Inter + Instrument-Serif combo that every generated app ships with.
  - Typography scale lives in `AppTheme.display(size, …)` and `AppTheme.ui(size, …)` so no screen ever reaches for a stray `TextStyle(fontSize: 11.5)` again.

### 2. New palette with a signature "ember" accent
- **File:** `apps/mobile/lib/core/constants/app_colors.dart`
- **Why:** The emerald-on-near-black combo in the old palette is the default AI-generated health app look. Also the old light theme's `#F3FAF7` was the generated "healthy pastel" tell.
- **Change:**
  - Deeper, less teal-tinted dark base (`#0A1512`) — reads as "focus," not "wellness vibe."
  - Primary green stays, but is renamed `verdict` and reserved for *good-fit* signals, so it means something when it appears.
  - **New signature `ember` (`#F59E3C`)** carries warnings and highlights. This is the move that separates CalFit from the sea of emerald-only apps.
  - Centralised score ramp: `AppColors.scoreColor(score)` is the single source for score colours. Every screen used to reach for its own `const Color(0xFFE77A67)` locally — now they call the ramp.

### 3. Animated score reveal (the hero moment)
- **File:** `apps/mobile/lib/core/widgets/health_score_ring.dart`
- **Why:** The old ring jumped straight to its final value with Material's default `CircularProgressIndicator`. Scanning a product is the single most important moment in the app and had zero ceremony.
- **Change:** Custom-painted ring; the value tweens from 0 → score over 900ms on an `easeOutCubic` curve. The number ticks up in sync. The number is set in Fraunces at ~36% of the ring's size, so a 196px hero ring gets a 70px numeral — big and considered. One premium moment, as the design brief calls for.

### 4. Replaced "glass cards" with quiet surface cards
- **Files:** `apps/mobile/lib/core/widgets/surface_card.dart` (new), `glass_card.dart` (kept as a shim that forwards to `SurfaceCard` so no existing import breaks)
- **Why:** The backdrop-blurred glass effect was on *every* surface — card, dialog, nav bar, feature badge. It made nothing feel special and made loading or scrolling janky on mid-range Androids like the Redmi Note 4.
- **Change:** A single flat elevated surface with a 1px hairline border. The score ring and the ember accent get to be the memorable things; everything else stays disciplined. "Spend your boldness in one place" (Chanel's advice, applied to UI).

### 5. Haptics on everything that deserves one
- **Files:** `scan_screen.dart`, `scan_result_screen.dart`, `history_screen.dart`, `profile_screen.dart`, `home_screen.dart`, `bottom_navigation.dart`
- **Why:** No haptic feedback anywhere was one of the clearest "feels like a web app" signals. Premium Android apps use `HapticFeedback` liberally and users don't consciously notice *until it's gone*.
- **Change:** `HapticFeedback.selectionClick()` on tab switches, nav icon taps, chip toggles. `HapticFeedback.mediumImpact()` when the scan POST fires. `HapticFeedback.lightImpact()` when the scan result lands and when a profile edit saves. Zero new packages — `HapticFeedback` is in the Flutter SDK.

### 6. Scan progress is a sentence, not a spinner
- **File:** `apps/mobile/lib/core/widgets/skeleton.dart` (new), used by `scan_screen.dart`
- **Why:** A scan takes 3–6 seconds. Showing just a `CircularProgressIndicator` with "Evaluating with CalFit AI…" leaves the user staring at nothing.
- **Change:** The scan button, while scanning, cycles through four honest status lines — "Reading the label", "Checking your profile", "Weighing the findings", "Finding alternatives" — with a 350ms fade/slide between them. Even though the server doesn't actually stream progress, the stepped message makes the wait feel intentional. The sequence is timed to match real pipeline latency.

### 7. Skeleton loaders replace spinners on dashboards
- **Files:** `home_screen.dart`, `history_screen.dart`, uses `Skeleton` from `widgets/skeleton.dart`
- **Why:** `Center(child: CircularProgressIndicator(...))` is the universal generated-app loading state. Premium apps show skeletons: outlines of the content you're about to see, so the layout doesn't jump when data lands.
- **Change:** Home shows a skeleton latest-scan card and skeleton recent-scan rows. History shows five skeleton rows. The shimmer uses the primary colour at low alpha to feel on-brand, not generic.

### 8. Removed sales badges from the scan screen
- **File:** `apps/mobile/lib/features/scan/scan_screen.dart`
- **Why:** Three badges — "Medical Rules · Deterministic fit", "Visual OCR · Label extraction", "Better Alternatives · Smarter choices" — were marketing copy aimed at a user who is already *inside the feature doing the thing*. Classic generated-code pattern of filling space with "features."
- **Change:** Gone. The scan screen now has: one honest headline ("Point the camera at a food label"), one honest subtitle, one image well, two source buttons, and one primary action. Nothing else.

### 9. Copy rewrite — interface voice, not marketing voice
- **Files:** everywhere a user-facing string lives.
- **Why:** The old copy was textbook AI marketing: "Better food choices. A healthier you.", "Personalized Health Evaluation", "Analyze Food Product", "Could Not Read Label", "Snap any label or packaging for instant suitability insights matched to your profile."
- **Change:**
  - Greeting lost the 🌿 emoji.
  - "Your Health Score" (which was actually just the *latest scan's* score) → `Latest scan · 2h` card. Honest.
  - "Analyze Food Product" button → "Scan this product".
  - "Could Not Read Label" → "We couldn't read this label" (interface voice).
  - "Scan Evaluation" title → "Scan result".
  - "Edit Allergies" subtitle → "Anything in these ingredients means we warn you."
  - "Scan History" title → "History". Section headers in history are now "Today" / "Yesterday" / "15 Oct 2026" instead of raw timestamps.
  - Profile section captions explain *why* each field matters: "We lower scores for products that aggravate these" / "Anything in these ingredients means we warn you."

### 10. Finding cards became editorial callouts
- **File:** `apps/mobile/lib/features/scan/scan_result_screen.dart`
- **Why:** Old findings were a coloured `ListTile` — leading icon, title, subtitle, "-25 pts" trailing. Generic. Didn't carry any of the authority a health finding needs.
- **Change:** Each finding is a callout block with: a severity pill ("Stop" / "Alert" / "Warning" / "Info") in the top-left, a subtle "−25 pts" chip in the top-right, title in Plus Jakarta Sans title size, concrete detail in body size. Severity colours all route through the ember/critical/verdict system so palette discipline holds across them.

### 11. Profile at a glance on home
- **File:** `apps/mobile/lib/features/home/home_screen.dart`
- **Why:** The old home had generic "Health Goals" and "Conditions" GlassCards that mostly showed "None Active" or an all-caps WORD. Didn't tell the returning user anything useful.
- **Change:** A "Your profile" section with pill-shaped chips colored by kind: conditions in ember, goals in verdict green, allergies in critical red. If nothing is set, a one-liner nudges the user to Profile instead of showing an empty card.

### 12. Nav bar quieter, scan FAB louder
- **File:** `apps/mobile/lib/navigation/bottom_navigation.dart`
- **Why:** The old bar used backdrop-blurred glass and gave the scan FAB the same visual weight as the tab icons. The whole bar was busy.
- **Change:** Flat surface, no blur. The scan FAB is the only element with chroma; tab icons are muted when inactive and switch to filled variants when active. A cross-fade between tab screens replaces the hard swap. Nav bar reads as *scaffolding*, scan button reads as *action*.

### 13. Day-grouped history
- **File:** `apps/mobile/lib/features/history/history_screen.dart`
- **Why:** The old list was a flat chronological stream with `2026-10-25 14:03` timestamps on every row — reads like a database export.
- **Change:** Grouped by day, with "Today" / "Yesterday" / "15 Oct 2026" headers. Row timestamps are now relative ("5m", "2h"). Tapping a row gives a selection haptic + a snackbar explaining the detail view is coming (since the backend endpoint isn't ready yet).

---

## Follow-ups

- **App icon** — the generic Flutter rocket is still the launcher icon. For Play Store this is the first visual the user sees; worth generating or commissioning. Simple serif "C" on verdict-green would carry forward the identity we just set.
- **Splash screen** — currently default. 10-minute fix: solid verdict background with the Fraunces "C" mark.
- **Scan detail from history** — needs backend `GET /scans/:id` endpoint. The history row is already wired to open it.
- **Hero animation** home-latest-scan → scan detail, once the above lands.
- **"Ask CalFit" chat** — the agentic feature I called out in the backend review. Post-MVP.
- **Backend small wins I called out but didn't execute:** parallel knowledge+profile load in the LangGraph, Gemini native structured outputs instead of regex JSON parsing, per-request profile cache.

---

## 2026-10-25 — Backend hardening pass (API + LangGraph)

### 🚨 Action items for you (not fixable in code)

**Rotate your API keys.** `apps/api/.env` contained live keys for Gemini, Groq, and Cerebras. `.env` is in root `.gitignore`, so this is only a problem if it was ever committed earlier. Check with:

    git log --all -- apps/api/.env

If anything shows up, rotate at each provider's console and either rewrite history with `git filter-repo` / BFG or create a fresh repo.

**Add authentication before Play Store.** Every endpoint still takes `user_id` from the request body/query — anyone can read anyone else's profile and scan history. Choose Supabase Auth (fits since you're already using Supabase), Firebase Anonymous Auth, or your own device-token scheme, then verify the token server-side and derive `user_id` from it instead of trusting the client.

### 1. Remove the silent fake fallback (violates `agents.md`)
- **Files:** `apps/api/src/orchestration/scan_graph.py`
- **Why:** `node_analyze_photo` and `node_validate_extraction` both substituted a hardcoded "Bikaji Kuch Kuch Namkeen" product when Gemini failed or the image was unreadable. This directly contradicts your own engineering rules — _"Missing data must remain None/unknown. Never silently return fake/mock data."_ — and made the Flutter `insufficientData` branch dead code.
- **Change:** When Gemini fails or extraction has no `product_name`/`brand`/`ingredients`, the graph routes to `assemble_insufficient`, which returns `insufficient_data=True` with a plain-English `pipeline_message` the Flutter screen already knows how to render. The Bikaji helper is gone. Insufficient-data responses are also no longer persisted into history (so empty placeholders don't accumulate).

### 2. Fix Gemini model names (the real reason the fallback kept firing)
- **Files:** `apps/api/src/config/settings.py`, `apps/api/src/providers/gemini_provider.py`
- **Why:** `gemini-3.1-flash-lite`, `gemini-3.5-flash-lite`, `gemini-3.8-flash` do not exist. The SDK was rejecting every call, which is almost certainly why the mocked product kept appearing in your scans.
- **Change:** Default model is now `gemini-2.5-flash`, with a real fallback list: `gemini-2.5-flash-lite`, `gemini-2.0-flash`, `gemini-2.0-flash-lite`, `gemini-1.5-flash`, `gemini-1.5-flash-8b`. Verify against https://ai.google.dev/gemini-api/docs/models before each deploy — Google rotates these.

### 3. Declare backend dependencies in `pyproject.toml`
- **File:** `apps/api/pyproject.toml`
- **Why:** The project section had no `dependencies` list. A fresh `uv sync` (or any environment created without the lockfile) would install nothing. The code imports fastapi, pydantic, pydantic-settings, python-multipart, langgraph, google-genai, supabase, httpx — none of them were declared.
- **Change:** Added `[project.dependencies]` with the full set and a `[dependency-groups] dev` with pytest/ruff/mypy.

### 4. Tighten CORS
- **Files:** `apps/api/src/main.py`, `apps/api/src/config/settings.py`
- **Why:** `allow_origins=["*"]` combined with `allow_credentials=True` is a browser-rejected combination (CORS spec) and a bad default for prod.
- **Change:** Dev defaults to `localhost`, `127.0.0.1`, `10.0.2.2`. Set `CORS_ALLOWED_ORIGINS=https://your.domain,https://admin.your.domain` in production env.

### 5. Guard scan upload size BEFORE reading into memory
- **File:** `apps/api/src/api/v1/scans.py`
- **Why:** The 10 MB check happened after `await photo.read()`. A 1 GB upload would fully buffer before being rejected — easy DoS vector.
- **Change:** Inspect the `Content-Length` header first, reject early, then double-check the actually-read byte count. Limit is now `settings.MAX_SCAN_UPLOAD_BYTES` so you can tune it per-env.

### 6. Replace deprecated `datetime.utcnow()`
- **Files:** `apps/api/src/domain/models.py`, `apps/api/src/providers/local_db_provider.py`, `apps/api/src/providers/supabase_provider.py`, `apps/api/src/orchestration/scan_graph.py`
- **Why:** `datetime.utcnow()` is deprecated in Python 3.12 and returns a naïve datetime (no timezone), which bites you when it goes through JSON serialization or Postgres timestamptz columns.
- **Change:** All replaced with `datetime.now(timezone.utc)`. A single `_utc_now()` helper lives in `models.py` for Pydantic default_factory.

### 7. Fix missing import in `alternative_service.py`
- **File:** `apps/api/src/services/alternative_service.py`
- **Why:** The file used `Any` in a type annotation (`product_repo: Any = None`) without importing it. Worked at runtime only because of `from __future__ import annotations`; broke `mypy` and would break on any eager-eval context.
- **Change:** Added `from typing import Any`.

### 8. Add logging config
- **File:** `apps/api/src/main.py`
- **Why:** Every module calls `logger = logging.getLogger(__name__)`, but no `basicConfig` is ever installed. Uvicorn gives you default INFO on its own, but direct imports or tests saw nothing.
- **Change:** `logging.basicConfig(level=INFO, format=...)` on startup.

---

## Follow-ups (open items)

- **Auth** — the biggest remaining gap for Play Store.
- **Rate limiting** on `/scans` — otherwise a single bad actor can burn your Gemini quota. SlowAPI (per-IP) is the quickest add; reverse-proxy level is cleaner for prod.
- **Vector search** for the knowledge base — your Supabase schema already has `pgvector` and an `ivfflat` index on `knowledge.embedding`, but the code only does tag matching. Post-MVP quality upgrade.
- **Tests** for the LangGraph pipeline — currently only `test_scoring.py` and basic endpoint tests exist. The orchestration path is untested.
- **Dependencies lock** — once you've bumped `pyproject.toml`, run `uv lock` so `uv.lock` reflects the declared deps.

---

## 2026-10-25 — Mobile MVP hardening pass (earlier today)

### 1. Fix broken widget test (launch blocker)
- **File:** `apps/mobile/test/widget_test.dart`
- **Why:** The test file imports `package:mobile/screens/result_screen.dart`, which doesn't exist. The real path is `features/scan/scan_result_screen.dart`. `flutter test` currently fails to compile, which also blocks any CI pre-launch check.
- **Change:** Rewritten against the real file paths, real class names (`ScanResultScreen`, `BottomNavigation`), and real labels used in the UI. Smoke-tests the result screen with mock data; the main-app test is kept minimal because the real app makes a network call on launch.

### 2. API service: platform-aware base URL + runtime override (launch blocker)
- **File:** `apps/mobile/lib/services/api_service.dart`
- **Why:**
  - `baseUrl` was hardcoded to `http://127.0.0.1:8000`. The Android emulator cannot reach the host via `127.0.0.1` — it needs `10.0.2.2`. A physical device cannot reach `127.0.0.1` at all.
  - `Content-Type` was hardcoded `image/jpeg`; a PNG or WebP upload is mis-labeled.
  - Only `/health` had a timeout; a stalled scan hangs the UI forever.
  - Raw `Exception('...status...body...')` leaked server internals.
- **Change:**
  - Introduced `ApiConfig` with `--dart-define=API_BASE_URL=...` override so staging/prod URLs can be injected at build time without a code change.
  - Platform-aware default: `10.0.2.2:8000` on Android, `127.0.0.1:8000` otherwise.
  - Content-type derived from filename extension (`jpg/jpeg → image/jpeg`, `png → image/png`, `webp → image/webp`).
  - 30 s timeout on scan submission, 10 s on profile/history.
  - Thin, typed `ApiException` with a user-facing `message`, so UI can show something readable instead of a stack trace.

### 3. Theme persistence across launches
- **Files:** `apps/mobile/lib/app/theme_controller.dart`, `apps/mobile/lib/main.dart`, `apps/mobile/pubspec.yaml`
- **Why:** `ThemeController` always starts in dark mode. On every app restart the user's choice was lost.
- **Change:** Added `shared_preferences` dependency, `ThemeController.init()` loads the saved preference, and `toggleTheme()` persists it. `main()` awaits `WidgetsFlutterBinding.ensureInitialized()` and `ThemeController.init()` before `runApp`.

### 4. Replace deprecated `withOpacity()` with `withValues(alpha:)`
- **Files:** every `.dart` file under `apps/mobile/lib/` that used `withOpacity`.
- **Why:** `Color.withOpacity()` is deprecated in current Flutter stable because it rounds alpha to 8 bits before the engine can take advantage of wider gamuts. The replacement is `withValues(alpha: x)`.
- **Change:** Mechanical rewrite. Behaviour is identical in sRGB.

### 5. Friendly error messages
- **Files:** `apps/mobile/lib/features/home/home_screen.dart`, `history_screen.dart`, `profile_screen.dart`, `scan_screen.dart`
- **Why:** `catch (e) { _error = e.toString(); }` surfaces raw stacks like `Exception: Failed to load profile: 500 ...` to the user.
- **Change:** A small `UserMessage.fromError(e)` helper maps common failures (connection refused, timeout, 4xx, 5xx) to a short human message. Technical detail is still logged via `debugPrint`.

### 6. Dynamic greeting
- **File:** `apps/mobile/lib/features/home/home_screen.dart`
- **Why:** `'Good Morning,'` was hardcoded in the home screen regardless of local time.
- **Change:** Picks Morning / Afternoon / Evening / Night from `DateTime.now().hour`.

### 7. Real relative scan time (no more mocked "2h")
- **File:** `apps/mobile/lib/features/home/home_screen.dart`
- **Why:** Every recent-scan row rendered the literal string `'2h'`. Launching with this would be obvious to any first-tester.
- **Change:** A `_relativeTime(DateTime)` formatter (`just now`, `5m`, `2h`, `3d`) from the real `scannedAt`.

### 8. "View All" and recent-scan taps wired up
- **File:** `apps/mobile/lib/features/home/home_screen.dart`, `apps/mobile/lib/navigation/bottom_navigation.dart`
- **Why:** The "View All" button on the home screen was a no-op; recent-scan rows were not tappable.
- **Change:** `HomeScreen` accepts an optional `onNavigateToHistory` callback that `BottomNavigation` wires to switching to tab index 1. Recent-scan rows now show a tap ripple and go to the history tab too (the fuller "open past scan detail" flow needs a backend `GET /scans/:id` endpoint; tracked for a follow-up).

### 9. Reasonable image compression on upload
- **File:** `apps/mobile/lib/features/scan/scan_screen.dart`
- **Why:** `imageQuality: 85` is good, but `maxWidth/maxHeight: 1600` still produces 500 KB–2 MB photos. On a slow mobile network the scan POST took forever.
- **Change:** Reduced to `maxWidth/Height: 1280` and `imageQuality: 80`, which keeps labels readable and typically cuts the payload to ~250 KB.

### 10. Android manifest: scope cleartext traffic to localhost only
- **File:** `apps/mobile/android/app/src/main/AndroidManifest.xml`, new `apps/mobile/android/app/src/main/res/xml/network_security_config.xml`
- **Why:** `android:usesCleartextTraffic="true"` applies to *all* domains — Play Store policy warns against this. The dev build needs cleartext only for the local backend.
- **Change:** Removed the global flag, added a `networkSecurityConfig` that permits cleartext for `10.0.2.2`, `127.0.0.1`, and `localhost` only. Production traffic must be HTTPS. A `release` build with no production URL set will fail-fast rather than silently talking to an emulator address.

---

## Follow-ups (mobile)

- **Backend endpoint `GET /scans/:id`** so history rows can open the full `ScanResultScreen`.
- **User authentication** — `dev-user-001` is hardcoded. For launch you need at minimum anonymous sign-in or your own device-ID token.
- **Crash reporting** — Firebase Crashlytics or Sentry, so you see field crashes.
- **Release signing config** in `android/app/build.gradle.kts` (currently signs release with the debug keystore).
- **App icon** — still the generic Flutter icon. Blocks a professional-looking Play Store listing.
- **`version:` bump** in `pubspec.yaml` before each Play Store upload.
