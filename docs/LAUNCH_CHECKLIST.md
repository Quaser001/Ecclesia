# CalFit — Launch Checklist

Tracks everything between where the project is now and a cloud-hosted app
running on real phones with no laptop involved.

Last updated: 2026-10-28

Legend: `[x]` done · `[ ]` left · **BLOCKER** = nothing downstream works without it

---

## Done

### Database (Supabase)
- [x] Supabase project `rxqsyksydnmwtslfvwll` live in **Singapore** (`ap-southeast-1`) — `https://rxqsyksydnmwtslfvwll.supabase.co`. Replaces the earlier `calfit` project.
- [x] Migrations 001–006 applied (dev seed data skipped): `profiles`, `knowledge`, `scans`, `scan_findings`, `alternatives`, `scan_usage`
- [x] Row Level Security on every table with no policies — the publishable key opens nothing; the backend uses the secret (`service_role`) key, which bypasses RLS
- [x] `increment_scan_usage()` locked to `service_role`
- [x] 12 knowledge-base rows copied from the old project
- [x] Private storage bucket `calfit-scans` (migration 006): 10 MB limit, image types only, no public access
- [x] Backend running against it locally: profile writes, the quota counter and photo uploads verified end to end
- [x] Tests can no longer write to the live project, whatever `.env` holds (`tests/conftest.py`)
- [x] Earlier scan history imported into the phone account and corrected (31 scans, each with its photo)

### Backend
- [x] Signed per-device tokens (`v1.<id>.<hmac>`) issued by `POST /api/v1/auth/device`; a client-supplied `user_id` is ignored, so one phone cannot read another's data
- [x] Path traversal in local uploads closed
- [x] Profile row created before the first scan insert (`scans.user_id` foreign key)
- [x] Daily scan cap backed by Postgres, atomic, shared across Cloud Run instances
- [x] Upload size rejected from `content-length` before the body is buffered
- [x] CORS restricted to a configured list, no wildcard
- [x] Reviewable rule catalog with sources and evidence tiers; allergen match is a hard stop
- [x] Extraction prompt is transcription-only with an injection guard; explanations are grounding-checked
- [x] Food-database values converted from per 100 g/ml to the label's serving before scoring
- [x] Product matcher rejects loose matches (one shared word, category-only, brand-only)
- [x] Scans with nothing to judge return "insufficient data" instead of a score
- [x] Prescription reading built, ships **off** (`PRESCRIPTION_AI_ENABLED=false`)
- [x] Only `data/food.db` (product data, no user data) goes into the image; `.gcloudignore` keeps `.env`, `data/calfit.db` and scan photos off the Cloud Build upload
- [x] 220 tests passing

### Mobile
- [x] Registers once per install and sends the bearer token on every request
- [x] Medical disclaimer on the scan result screen
- [x] Release signing wired to `android/key.properties`, falling back to debug when absent
- [x] Cleartext HTTP allowed only to `localhost`, `127.0.0.1` and `10.0.2.2`; anything else must be HTTPS
- [x] Runs on a physical phone over USB (`adb reverse tcp:8000 tcp:8000`)

### Repository and docs
- [x] On GitHub: `github.com/Quaser001/Ecclesia`
- [x] `docs/DEPLOY_CLOUD_RUN.md` — deployment runbook, including `AUTH_SECRET_KEY` and the prescription flags
- [x] `docs/GEMINI_BILLING.md`, `docs/PRIVACY_POLICY.md` (draft), `docs/RELEASE_SIGNING.md`

---

## Left — to get it running in the cloud

### 1. Credentials and billing
- [ ] **BLOCKER** Rotate keys that have been exposed: Gemini, Groq and Cerebras (they sat in `apps/api/.env` for several sessions), and the old `calfit` project's secret key (it appeared in session output). Delete the old `calfit` Supabase project if nothing uses it.
- [ ] **BLOCKER** Google Cloud project with billing on; install the gcloud CLI.
- [ ] Gemini billing (see `docs/GEMINI_BILLING.md`). Product-label scans can run on the free tier while testing; it allows ~20 requests/day and may train on what it receives. Switch to paid, with a spend cap, before anyone else uses the app.
- [ ] **Decide the data region.** The database is in Singapore, but `PRIVACY_POLICY.md` says data stays in India. Either move to a Mumbai (`ap-south-1`) Supabase project or correct the policy.

### 1b. Prescription reading (ships OFF)
- [ ] **BLOCKER for enabling it** Gemini key on the paid, no-training tier before setting `PRESCRIPTION_AI_ENABLED=true`. Prescriptions must never reach the free tier.
- [ ] Legal review of the in-app consent text (`prescription_consent.dart`) and privacy policy section 2.4.
- [ ] Decide whether it belongs in the first Play Store release.
- [ ] Manual test with a synthetic prescription only: consent appears once, nothing pre-ticked, nothing saved before confirming, backend log has no health text.

### 2. Deploy the backend
- [ ] Enable Run, Artifact Registry, Secret Manager, Cloud Build; create the Artifact Registry repo `calfit` in `asia-south1`
- [ ] Put `GEMINI_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` and a newly generated `AUTH_SECRET_KEY` in Secret Manager
- [ ] Create the `calfit-api` service account and grant it `secretAccessor` on each of the four secrets
- [ ] Build and deploy (`gcloud builds submit`, then `gcloud run deploy`)
- [ ] Note the deployed URL somewhere outside git
- [ ] Smoke test: `/health` returns ok, `/api/v1/profile` without a token returns **401** (503 means `AUTH_SECRET_KEY` is missing), `POST /api/v1/auth/device` returns a token
- [ ] Set a Google Cloud budget alert (~₹200/month)

All commands are in `docs/DEPLOY_CLOUD_RUN.md`.

### 3. Get the app onto the phone, cable-free
- [ ] **BLOCKER** Generate the release keystore and back it up somewhere you won't lose it — losing it means you can never update the app on the Play Store
- [ ] Fill in `android/key.properties` from `key.properties.example`; confirm it is gitignored
- [ ] Build: `flutter build apk --release --dart-define=API_BASE_URL=https://<deployed-url>`
- [ ] Install on the phone (Xiaomi 2201117PI). The release build is signed with a different key from the debug build, so Android requires uninstalling the debug app first. That wipes its stored token, and the release app registers as a **new user**: the current profile and 31 imported scans stay under the old ID (`d0ea3a51…`) and must be moved across if you want them.
- [ ] **End-to-end test with the laptop off**: on mobile data, scan three real labels (the back of the pack, with ingredients and nutrition) and confirm History survives an app restart

Reaching the end of this section means it runs independently. Everything below is about being fit for other people.

---

## Left — before anyone else uses it

- [ ] Photos in History: the bucket is private, so stored `image_url`s do not open. Serve short-lived signed URLs before showing photos.
- [ ] History shows only the 20 most recent scans; add paging.
- [ ] Host `PRIVACY_POLICY.md` at a public URL — Play Store requires a live link
- [ ] Legacy launcher PNGs: `mipmap-*/ic_launcher.png` are still the default Flutter icon; only Android 8+ shows the adaptive icon
- [ ] Retention policy for uploaded scan photos (there is none; they are tied to a user ID)
- [ ] A free Supabase project **pauses after a week of inactivity** and must be restored by hand. Fine while testing, not once people depend on it.

## Left — before Play Store

- [ ] Google Play developer account ($25, one-time)
- [ ] Play Data Safety form (you collect health data — answer it honestly)
- [ ] **Durable accounts.** Device tokens are anonymous and live only in the app's storage: reinstalling, clearing data or changing phones loses the account and its history. Add Supabase Auth (or similar) before payments or a public launch.
- [ ] Internal testing track for testers

## Left — product quality

- [ ] Pack size is not extracted, so a front-of-pack photo of a 250 ml can cannot be scaled to the whole can
- [ ] `alternative_service.py` compares food-database values (per 100 g) against per-serving limits
- [ ] `scripts/import_food_data.py` falls back to Open Food Facts fields that may be per serving when a `_100g` field is missing
- [ ] Put 30+ labelled real Indian products through `scripts/run_eval.py` and record allergen recall
- [ ] Real `alternatives` data (the table is empty on purpose; the seed rows were placeholders)
- [ ] Clinician or dietitian review of the rule catalog thresholds
- [ ] `GET /scans/:id` so tapping a history row opens the full result
- [ ] "May contain" allergen warnings as their own field and rule

---

## Shortest path to a cloud-running app

1. Rotate keys; set up Google Cloud billing and gcloud
2. Deploy to Cloud Run (four secrets), smoke test `/health` and auth
3. Generate the keystore, build the signed APK with the deployed URL
4. Install on your phone, close the laptop, scan three labels
