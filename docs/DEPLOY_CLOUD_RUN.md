# Deploy the CalFit API to Cloud Run (asia-south1)

Target region is Mumbai (`asia-south1`), because our first users are in India. Secrets live in Google Secret Manager; nothing is baked into the image.

> **Where the data lives:** the API runs in Mumbai, but the database and photos live in the Supabase project `rxqsyksydnmwtslfvwll`, which is in **Singapore**. `PRIVACY_POLICY.md` says data stays in India. Move to a Mumbai Supabase project or correct the policy before anyone else uses the app.

## 0. One-time prerequisites

```bash
gcloud auth login
gcloud config set project <YOUR_PROJECT_ID>
gcloud config set run/region asia-south1

gcloud services enable run.googleapis.com \
                       artifactregistry.googleapis.com \
                       secretmanager.googleapis.com \
                       cloudbuild.googleapis.com
```

Create an Artifact Registry repo (one-time):

```bash
gcloud artifacts repositories create calfit \
  --repository-format=docker \
  --location=asia-south1 \
  --description="CalFit API images"
```

## 1. Put secrets in Secret Manager

Never commit these, never pass them with `--set-env-vars`. Use `--set-secrets`.

```bash
# Create the secrets (one-time per key).
printf '%s' "$GEMINI_KEY" | gcloud secrets create GEMINI_API_KEY --data-file=-
printf '%s' "$SUPABASE_URL" | gcloud secrets create SUPABASE_URL --data-file=-
printf '%s' "$SUPABASE_SERVICE_KEY" | gcloud secrets create SUPABASE_SERVICE_ROLE_KEY --data-file=-

# Device-token signing key (at least 32 characters). Without it every request
# gets 503 "authentication not configured" and the app cannot load anything.
python -c "import secrets; print(secrets.token_urlsafe(48), end='')" \
  | gcloud secrets create AUTH_SECRET_KEY --data-file=-
```

Rotate later with `gcloud secrets versions add <name> --data-file=-`. Cloud Run picks up a new version on the next revision.

**Do not rotate `AUTH_SECRET_KEY` casually.** Each phone's identity is a token signed with it. A new key makes every token invalid, so each app registers again as a brand-new user, and existing profiles and scan history stay attached to the old user IDs. Only rotate it if it leaks, and plan how to move users' data across.

## 2. Grant the Cloud Run service account access

Cloud Run uses the project's default compute service account unless you give it a dedicated one. Dedicated is better:

```bash
gcloud iam service-accounts create calfit-api \
  --display-name="CalFit API runtime"

PROJECT_ID=$(gcloud config get project)
SA="calfit-api@${PROJECT_ID}.iam.gserviceaccount.com"

for secret in GEMINI_API_KEY SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY AUTH_SECRET_KEY; do
  gcloud secrets add-iam-policy-binding $secret \
    --member="serviceAccount:${SA}" \
    --role="roles/secretmanager.secretAccessor"
done
```

## 3. Build and deploy

From `apps/api/`.

What gets uploaded and built:

- `gcloud builds submit` uploads the folder to a Cloud Storage bucket. `apps/api/.gcloudignore` keeps `.env` (API keys), `data/calfit.db` (the local dev store with real profiles and scan history) and `data/uploads/` (scan photos) off that upload. With a `.gcloudignore` present, gcloud ignores `.gitignore`, so anything new and sensitive must be added there.
- The image gets only `src/` and `data/food.db`, the Open Food Facts product subset (no user data). `tests/test_deploy_packaging.py` fails if the Dockerfile or either ignore file stops guaranteeing this.

```bash
IMAGE=asia-south1-docker.pkg.dev/${PROJECT_ID}/calfit/api:$(git rev-parse --short HEAD)

gcloud builds submit --tag "$IMAGE"

gcloud run deploy calfit-api \
  --image "$IMAGE" \
  --service-account "$SA" \
  --region asia-south1 \
  --allow-unauthenticated \
  --cpu 1 --memory 1Gi \
  --concurrency 20 \
  --max-instances 3 \
  --timeout 60s \
  --set-env-vars "CORS_ALLOWED_ORIGINS=https://calfit.app,https://staging.calfit.app" \
  --set-env-vars "DAILY_SCAN_CAP=4" \
  --set-env-vars "GEMINI_MODEL=gemini-2.5-flash" \
  --set-env-vars "DEVICE_TOKEN_DAILY_CAP_PER_IP=20" \
  --set-env-vars "PRESCRIPTION_AI_ENABLED=false" \
  --set-env-vars "PRESCRIPTION_DAILY_CAP=5" \
  --set-env-vars "LOG_FORMAT=json" \
  --set-env-vars "APP_ENV=production" \
  --set-env-vars "TRUSTED_PROXY_HOPS=1" \
  --set-secrets "GEMINI_API_KEY=GEMINI_API_KEY:latest" \
  --set-secrets "SUPABASE_URL=SUPABASE_URL:latest" \
  --set-secrets "SUPABASE_SERVICE_ROLE_KEY=SUPABASE_SERVICE_ROLE_KEY:latest" \
  --set-secrets "AUTH_SECRET_KEY=AUTH_SECRET_KEY:1"
```

- `APP_ENV=production` makes the instance refuse to start when a secret is missing or weak. It also refuses the laptop fallbacks (local SQLite, local photo folder) and hides `/docs`. Before deploying, run `python -m src.check_config` against the same settings: it checks every key actually works.
- `TRUSTED_PROXY_HOPS=1` makes the per-IP registration cap use the phone's address that Cloud Run's front end appends to `X-Forwarded-For`. Without it, every install shares the front end's address.
- `AUTH_SECRET_KEY` is pinned to version `1`, not `latest`, so adding a secret version can't log every user out by accident (see "Do not rotate" above).

`PRESCRIPTION_AI_ENABLED` stays `false` until the Gemini key is on the paid tier, which does not train on what it receives (see `docs/GEMINI_BILLING.md`). Prescriptions must never reach the free tier. Turning it on later needs the paid tier confirmed as well, or `APP_ENV=production` refuses to start: after the billing check in `docs/GEMINI_BILLING.md`, run `gcloud run services update calfit-api --update-env-vars PRESCRIPTION_AI_ENABLED=true,GEMINI_PAID_TIER_CONFIRMED=true` (on Vertex, `GEMINI_BACKEND=vertex` replaces the confirmation). Run `python -m src.check_config` with the same settings first.

`--max-instances 3` is a soft safety cap for the free tier. Lift it once Gemini billing is on and we've seen real usage.

## 4. Point the Flutter app at it

Build the APK with the deployed URL baked in:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://calfit-api-<hash>-el.a.run.app
```

Grab the URL from the `gcloud run deploy` output. Keep the staging and prod URLs in a note somewhere outside git.

## 5. Health check and smoke

```bash
curl -s https://<url>/health
# {"status":"ok","service":"CalFit API"}

# Auth is configured: no token is refused, a new device gets a token.
curl -s -o /dev/null -w "%{http_code}\n" https://<url>/api/v1/profile
# 401   (503 here means AUTH_SECRET_KEY is missing)
curl -s -X POST https://<url>/api/v1/auth/device
# {"user_id":"...","token":"v1...."}
```

A scan smoke test needs a real image, so test it from a build on the device.

## 6. Cost ceiling

- Daily scan cap: `DAILY_SCAN_CAP=4` *successful* scans per user per UTC day (the free tier while starting out; paid tiers Plus=10 / Pro=20 aren't enforced until payments + entitlement exist). A scan that fails on our side or upstream is refunded and never counts; only a completed scan does (see the `_Charge` refund logic in `api/v1/scans.py`). The counter lives in the Supabase `scan_usage` table and is incremented atomically, so it survives revision restarts and is shared across instances. (It used to be an in-process dict, which meant a redeploy cleared everyone's count and each replica counted separately — a user could take `cap * instances` scans a day.) The in-memory store is still used automatically when no Supabase credentials are configured, i.e. local runs only.
- Cloud Run idle revenue is zero; you only pay while a request is live.
- Set a Google Cloud **budget alert** at ~₹200/month and a **Gemini quota cap** (see `docs/GEMINI_BILLING.md`). Those two together are the real backstop.

`--max-instances 3` no longer affects quota correctness now that the counter is in Postgres; it stays as a cost guard.

### Log retention: one year (DPDP Rules 6(1)(e), 8(3))

The DPDP Rules require keeping logs of processing for at least a year. Cloud Logging keeps 30 days by default, so raise the `_Default` bucket once:

```bash
gcloud logging buckets update _Default --location=global --retention-days=365
```

The logs hold no health data and no user id (see `src/observability.py`), so a year of them is safe to keep. Retention past 30 days is billed per GiB per month; at CalFit's volume that is small.

## 7. Rolling back a bad deploy

Every deploy creates a new Cloud Run **revision** and sends 100% of traffic to it. The old revisions are still there, so a rollback is just pointing traffic back — it takes seconds and needs no rebuild.

```bash
# 1. List revisions, newest first. Note the one that was good (the row below the bad one).
gcloud run revisions list --service=calfit-api --region=asia-south1

# 2. Send all traffic back to that revision.
gcloud run services update-traffic calfit-api \
  --region=asia-south1 \
  --to-revisions=calfit-api-00007-abc=100   # <- the good revision's exact name
```

To confirm: `gcloud run services describe calfit-api --region=asia-south1 --format='value(status.traffic)'`.

**"Does this change touch the database?"** — rolling back the *code* does not undo a *schema* change. So:

- **Keep every migration additive.** Add columns and tables; don't drop or rename in the same deploy as the code that stops using them. Then the previous revision still runs against the new schema, and a rollback is safe. Drop the old column in a later, separate migration once the rollback window has passed.
- **The consent-version trap.** If a deploy raised `CONSENT_NOTICE_VERSION` (in both the server and the app), rolling the *server* back to the old version will make the newer app builds unable to consent (they send the new version; the old server rejects it with 409). Treat a consent-version bump as a one-way door: fix forward instead of rolling back, or roll back the app build too.
- A data migration that already ran (rows changed, not just schema) is not undone by a traffic rollback. Have a reverse migration ready before you run a destructive one.

## 8. Known gaps before shipping

- Identity is an anonymous, server-signed token per profile (ADR-004, ADR-008), kept in the Android Keystore. There are no accounts, so a lost phone means a lost profile. Google sign-in is on the candidate list.
- Scan images are uploaded to Supabase storage. There is no retention policy. Decide one before Play Store.
