# CalFit — Launch Checklist

Tracks everything between where the project is now and a cloud-hosted app
running on real phones with no laptop involved.

Last updated: 2026-10-27

Legend: `[x]` done · `[ ]` left · **BLOCKER** = nothing downstream works without it

---

## Done

### Database
- [x] Supabase project `calfit` live in `ap-south-1` (Mumbai) — `https://trmohgpjtldwxbpoqvpn.supabase.co`
- [x] Schema applied (`profiles`, `knowledge`, `scans`, `scan_findings`, `alternatives`, `scan_usage`)
- [x] Row Level Security on every table with no policies — the public anon key opens nothing; the backend uses `service_role`, which bypasses RLS
- [x] 12 knowledge-base rows seeded (general nutritional science)
- [x] `001_schema.sql` fixed — it said `CREATE EXTENSION pgvector`, but the extension is named `vector`, so the migration failed on its first line against a fresh project
- [x] `avoid_caffeine` added to the Postgres schema (migration 003) — it existed in the model and in SQLite but not in Postgres, so saving a profile to Supabase failed
- [x] `increment_scan_usage()` locked to `service_role` (migration 005) — as a `SECURITY DEFINER` function in the public schema it was callable over `/rest/v1/rpc` by anyone holding the anon key

### Backend
- [x] Per-device anonymous identity replaces the hardcoded `dev-user-001`
- [x] Profile row created before the first scan insert — `scans.user_id` has a foreign key to `profiles.user_id`, and SQLite doesn't enforce foreign keys, so the first scan of every new user would have failed only in production
- [x] Daily scan cap backed by Postgres, atomic, survives restarts and works across Cloud Run instances
- [x] Upload size rejected from `content-length` before the body is buffered
- [x] CORS restricted to a configured list, no wildcard
- [x] Reviewable rule catalog with sources and evidence tiers; anaemia rules added; hypotension dropped
- [x] Allergen synonym vocabulary with whole-word matching; allergen match is a hard stop
- [x] Extraction prompt is transcription-only with an injection guard; explanation output is grounding-checked before the user sees it
- [x] `uv.lock` regenerated
- [x] 76 tests passing

### Mobile
- [x] Medical disclaimer on the scan result screen
- [x] `DeviceIdService` generates and persists a UUIDv4 on first launch
- [x] Release signing wired to `android/key.properties`, falling back to debug when absent
- [x] `flutter pub get` run (`pubspec.lock` committed)
- [x] Adaptive launcher icon and branded splash background

### Docs
- [x] `docs/DEPLOY_CLOUD_RUN.md` — deployment runbook
- [x] `docs/GEMINI_BILLING.md` — billing and spend caps
- [x] `docs/PRIVACY_POLICY.md` — draft covering health data under the DPDP Act
- [x] `docs/RELEASE_SIGNING.md` — keystore instructions
- [x] `apps/api/Dockerfile` and `.dockerignore`
- [x] `apps/api/scripts/run_eval.py` — accuracy harness (no labelled data yet)

---

## Left — to get it running in the cloud

### 1. Credentials and billing
- [ ] **BLOCKER** Rotate the exposed keys in `apps/api/.env` (Gemini, Groq, Cerebras). They have been in the repo for several sessions.
- [ ] **BLOCKER** Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (Supabase dashboard → Settings → API). Until both are set the backend silently falls back to local SQLite — and you won't notice, because everything still works.
- [ ] Confirm it's really using Postgres: run one scan, then check the `scans` table has a row.
- [ ] **BLOCKER** Switch Gemini to paid billing and set a spend cap (see `docs/GEMINI_BILLING.md`). The free tier allows ~20 requests/day and trains on what you send, so it cannot carry health data.
- [ ] Delete the three probe rows left from the foreign-key test:
      ```sql
      DELETE FROM scans      WHERE scan_id = 'fk-probe';
      DELETE FROM scan_usage WHERE user_id = 'device-with-no-profile';
      DELETE FROM profiles   WHERE user_id = 'device-with-no-profile';
      ```

### 1b. Prescription reading (ships OFF)
- [ ] **BLOCKER for enabling it** Confirm the Gemini key is on the paid, no-training tier (see `docs/GEMINI_BILLING.md`) before setting `PRESCRIPTION_AI_ENABLED=true`. Prescriptions must never reach the free tier.
- [ ] Legal review of the in-app consent text (`prescription_consent.dart`) and privacy policy section 2.4.
- [ ] Decide whether prescription reading belongs in the first Play Store release, or ships later behind the flag.
- [ ] Manually test with a synthetic prescription (never a real one): consent appears once, suggestions need ticking, nothing saved before confirming, backend log contains no health text.
- [ ] Add `PRESCRIPTION_AI_ENABLED` and `PRESCRIPTION_DAILY_CAP` to the Cloud Run env alongside the other settings.

### 2. Deploy the backend
- [ ] **BLOCKER** Create the Google Cloud project; enable Run, Artifact Registry, Secret Manager, Cloud Build
- [ ] Create the Artifact Registry repo `calfit` in `asia-south1`
- [ ] Put `GEMINI_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` in Secret Manager
- [ ] Create the `calfit-api` service account and grant it `secretAccessor` on each secret
- [ ] Build and deploy (`gcloud builds submit`, then `gcloud run deploy`)
- [ ] Note the deployed URL somewhere outside git
- [ ] Smoke test: `curl https://<url>/health` returns `{"status":"ok",...}`
- [ ] Set a Google Cloud budget alert (~₹200/month)

All commands are in `docs/DEPLOY_CLOUD_RUN.md`.

### 3. Get the app onto a phone, cable-free
- [ ] **BLOCKER** Generate the release keystore, then back it up somewhere you won't lose it — losing it means you can never update the app on Play Store
- [ ] Fill in `android/key.properties` from `key.properties.example`
- [ ] Confirm `key.properties` is gitignored
- [ ] Build: `flutter build apk --release --dart-define=API_BASE_URL=https://<deployed-url>`
- [ ] Install on your Redmi Note 4 via a Drive or WhatsApp link
- [ ] **End-to-end test with the laptop off**: scan three real labels and confirm history persists after a restart

Reaching the end of this section means it runs independently. Everything below is about being fit for other people.

---

## Left — before anyone else uses it

- [ ] Run `flutter analyze` and `flutter test` (never verified in this environment)
- [ ] Host `PRIVACY_POLICY.md` at a public URL — Play Store requires a live link
- [ ] Finish the app icon. The adaptive icon IS done (`ic_calfit_mark.xml`, `mipmap-anydpi-v26/ic_launcher.xml`, `launch_background.xml`, `colors.xml`), but `mipmap-*/ic_launcher.png` are still the default Flutter rocket. Adaptive icons only apply from Android 8 (API 26); Flutter's minSdk is 24, and **the Redmi Note 4 runs Android 7**, so your own test phone will still show the rocket. Generate the legacy PNGs for all five densities.
- [ ] Decide a retention policy for uploaded scan images. There is none, and they are photos of people's food tied to a device id.
- [ ] Note: a free Supabase project **pauses after a week of inactivity** and must be restored by hand. Fine while testing, not once people depend on it.

## Left — before Play Store

- [ ] Google Play developer account ($25, one-time)
- [ ] Complete the Play Data Safety form (you collect health data — answer it honestly)
- [ ] **Authentication.** The anonymous device id is the only identifier and it is sent from the client, so anyone who replays another user's id can read their scan history. This is a real privacy hole for health data and needs Supabase Auth or Firebase before a public launch.
- [ ] Internal testing track set up for testers

## Left — product quality

- [ ] Put 30+ labelled real Indian products through `scripts/run_eval.py` and record allergen recall. For a health app this is the single most convincing number you have — for users and for investors.
- [ ] Real `alternatives` data. The table is empty: the seed file's rows are labelled "DEV DATA: Example entry" and were deliberately not seeded, because a user would have seen "Lower-Sodium Instant Noodles Example" shown as a recommendation.
- [ ] Clinician or dietitian review of the rule catalog thresholds, especially the anaemia rules
- [ ] `GET /scans/:id` so tapping a history row opens the full result
- [ ] "May contain" allergen warnings as their own field and rule

---

## Repository

The project folder is **not** a git repository — nothing has ever been
committed, so no history and no leaked keys. A stale duplicate at
`CalFit/CalFit/` is a git repo pointing at `github.com/Suhail-0002/CalFit0002`;
it predates all current work and is now gitignored.

Three limits mean the first push has to be run from your own terminal:
- The Linux workspace on this machine will not start, so no shell here.
- This session's GitHub access only covers repos attached to it, so a new
  repo cannot be created from here.
- Files deeper than 7 folders (all of `android/app/src/main/res/**`) cannot be
  copied into the cloud container, so a push from there would silently omit
  your icons, styles and `network_security_config.xml`.

Commands are in the session notes. After the first push, attaching the repo
makes later changes pushable directly.

## Shortest path to a cloud-running app

1. Rotate keys
2. Set the two Supabase env vars, confirm a scan lands in Postgres
3. Gemini paid billing + spend cap
4. Deploy to Cloud Run, smoke test `/health`
5. Generate the keystore, build the signed APK with the deployed URL
6. Install on your phone, close the laptop, scan three labels

Steps 1–3 are account work only. Step 4 is the deploy runbook. Steps 5–6 are the proof.
