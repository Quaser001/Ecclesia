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
  --set-env-vars "DAILY_SCAN_CAP=50" \
  --set-env-vars "GEMINI_MODEL=gemini-2.5-flash" \
  --set-env-vars "DEVICE_TOKEN_DAILY_CAP_PER_IP=20" \
  --set-env-vars "PRESCRIPTION_AI_ENABLED=false" \
  --set-env-vars "PRESCRIPTION_DAILY_CAP=5" \
  --set-secrets "GEMINI_API_KEY=GEMINI_API_KEY:latest" \
  --set-secrets "SUPABASE_URL=SUPABASE_URL:latest" \
  --set-secrets "SUPABASE_SERVICE_ROLE_KEY=SUPABASE_SERVICE_ROLE_KEY:latest" \
  --set-secrets "AUTH_SECRET_KEY=AUTH_SECRET_KEY:latest"
```

`PRESCRIPTION_AI_ENABLED` stays `false` until the Gemini key is on the paid tier, which does not train on what it receives (see `docs/GEMINI_BILLING.md`). Prescriptions must never reach the free tier. Turning it on later only needs `gcloud run services update calfit-api --update-env-vars PRESCRIPTION_AI_ENABLED=true`.

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

- Daily scan cap: `DAILY_SCAN_CAP=50` per user. The counter lives in the Supabase `scan_usage` table and is incremented atomically, so it survives revision restarts and is shared across instances. (It used to be an in-process dict, which meant a redeploy cleared everyone's count and each replica counted separately — a user could take `cap * instances` scans a day.) The in-memory store is still used automatically when no Supabase credentials are configured, i.e. local runs only.
- Cloud Run idle revenue is zero; you only pay while a request is live.
- Set a Google Cloud **budget alert** at ~₹200/month and a **Gemini quota cap** (see `docs/GEMINI_BILLING.md`). Those two together are the real backstop.

`--max-instances 3` no longer affects quota correctness now that the counter is in Postgres; it stays as a cost guard.

## 7. Known gaps before shipping

- No auth yet. The anonymous device ID is the only identifier. If someone replays another user's id, they see that user's history. Fixing this needs real auth (Firebase or Supabase Auth) and is on the next-session list.
- Scan images are uploaded to Supabase storage. There is no retention policy. Decide one before Play Store.
