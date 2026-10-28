# DevOps: cloud-run-deploy

Confirmed by the founder on 2026-10-28.

- **Runbook:** `docs/DEPLOY_CLOUD_RUN.md` (asia-south1, Secret Manager, dedicated service account, `LOG_FORMAT=json`).
- **Dockerfile:** `apps/api/Dockerfile` (uvicorn, `--no-access-log`). `.gcloudignore` keeps personal data out of the image; only food.db ships.
- **Not done:**
  - the first deploy;
  - CI/CD;
  - a staged rollout or rollback plan beyond "redeploy the previous revision";
  - an Android release signing setup (`docs/RELEASE_SIGNING.md` describes it);
  - the Play Store listing.
- **Local development:**
  - backend: `uvicorn src.main:app --port 8000`;
  - phone: `adb reverse tcp:8000 tcp:8000`, then `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000`.
