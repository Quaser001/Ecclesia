# SDE: production hardening (2026-10-29)

**Spec:** `specs/2026-10-29-production-hardening.md`. **ADR:** 006. **Status:** built, tested, not committed.

## New modules (backend `apps/api/src/`)
- `body_limit.py`: ASGI middleware. It caps a body before any route parses it: 413, counted even without Content-Length. It also refuses uploads with no bearer token (401).
- `services/image_bytes.py`: works out the photo's type from its bytes. It strips a JPEG's EXIF/XMP/IPTC but keeps the orientation. Pure Python, with no image library.
- `services/client_ip.py`: reads the client IP from the last `TRUSTED_PROXY_HOPS` entries of X-Forwarded-For.
- `check_config.py`: `python -m src.check_config` checks that each key and service actually works.

## Behaviour changes
- **`ServiceUnavailable`** (`providers/interfaces.py`) becomes a 503 with `Retry-After` and request_id. Raised on:
  - a Gemini outage, a bad key or a 401/403;
  - a profile that failed to load.
- **Gemini:**
  - 25 s timeout and output caps on every call;
  - fallback models are 2.5-flash and 2.5-flash-lite only;
  - 401/403 and key errors stop at once;
  - a 400 from every model counts as the photo's problem and returns `insufficient_data`.
- **`ScanResponse.saved`:** false when the save failed, and the orphan photo is removed.
- **Settings:** `APP_ENV`, `TRUSTED_PROXY_HOPS`, `GEMINI_PAID_TIER_CONFIRMED`, `GEMINI_TIMEOUT_SECONDS`, `config_problems()`, `validate_for_production()` (run in the lifespan). Removed the unused `GEMINI_API_KEYS` and `DEFAULT_USER_ID`.
- **Providers:** shared per process (`dependencies._shared_instance`), with a lock on lazy client creation. In production, local fallbacks raise.
- **RULE-010C-SUGAR-HIGH:** weight loss or obesity, sugar > 12 g per serving (WHO). Skipped when the diabetes sugar rule already applies. It has its own curve, `sugar-weight`.
- **Delete my data** keeps today's `scan_usage` rows, so the caps don't reset.
- **Profile request limits:** name 80; allergies up to 30 entries of 1–60 characters; enum lists capped.
- **Logs:** exception type only, everywhere touched. Unhandled errors log the type and file:line.

## App (`apps/mobile`)
- **401 handling:** a 401 on a scan (submit or confirm) is never retried on the new identity. It throws `ApiErrorKind.profileReset`, and scans stay refused until the profile is saved (`AuthTokenStore.profileResetPending`).
- **Release builds:** they need `API_BASE_URL`, and cleartext is limited to the debug and profile network configs.
- **Backup:** `allowBackup=false` plus `data_extraction_rules.xml`.
- **Error logging:** the body is never logged.
- **Errors and consent:**
  - a prescription 429 has its own error kind;
  - a 503 from it is the generic error;
  - "Delete my data" also forgets the prescription consent.
- **New strings:** `errorProfileReset` and `errorPrescriptionLimit` in all 5 ARB files (Khasi needs review).

## Tech debt left
- Graph still compiled per request. It is cheap, but could be cached.
- The registration counter is still in memory per instance; Postgres would need care with storing IP addresses.
- Pre-existing ruff and mypy findings: 105 mypy errors, mostly `= None` defaults on dependency parameters.
