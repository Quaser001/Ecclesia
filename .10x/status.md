# Status

**Updated:** 2026-10-29
**Snapshot:** `main` = `origin/main` at `b4c6c3b` (plus this handoff commit). CI is green: secret scan, backend, app.
**Tests:** backend 508 (pytest), app 72 (`flutter test`), `flutter analyze` clean.

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
2. **Token storage:** move to the Android Keystore (`flutter_secure_storage`).
3. **Deploy to Cloud Run** (`APP_ENV=production`, `TRUSTED_PROXY_HOPS=1`, Cloud Armor in front).
4. **Google sign-in** (must link the family identities).
5. **Play Store:** Play Integrity in place of CAPTCHA, signing, listing.
6. **Pay down the 105 mypy errors.**
