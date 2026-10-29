# Status

**Phase:** Production hardening implemented and verified (2026-10-29). It is **not committed**.
**Updated:** 2026-10-29 (ADR-007 ratings are history; heart-health goal now checks sodium; CI in progress)
**Snapshot:** working tree on `main`, from commit cf18218, which is local and not pushed.

**Verified on the final code:**
- Backend: 504 tests pass, 54 of them new.
- App: 63 tests pass, 4 of them new; `flutter analyze` is clean.
- Live smoke tests: 24/24 and 15/15.
- A live scan during a Gemini outage returns 503 with a clear message.

The spec is `specs/2026-10-29-production-hardening.md`, the review is `reviews/2026-10-29-production-hardening.md`, and the decision is ADR-006.

## Blocking right now
- [ ] **The Gemini key in `apps/api/.env` is invalid.** Google returns 401 "API key not valid", so every photo scan returns 503. Put a fresh key in `.env` yourself, then run `python -m src.check_config`.

## Waiting on the founder
- [ ] Review and commit the hardening pass.
- [ ] Before any push: cf18218 contains the phone serial and an id prefix in `.10x/handoff.md`. A new commit won't remove them from history.
- [ ] Prescriptions are now refused locally. `.env` has `PRESCRIPTION_AI_ENABLED=true` on the AI Studio tier, so the guard blocks it. Set `GEMINI_PAID_TIER_CONFIRMED=true` only after checking that billing is on.
- [ ] Decide the deferred hardening items listed in the spec: token expiry, retention, transactional delete, composite index, migration tracking, CI, image digests.
- [ ] Buy the AI plan: Vertex AI, asia-south1.
- [ ] Label 50–100 pack photos for the label-reading accuracy test.
- [ ] Get a Khasi review of the translations. Two new error strings were added.
- [x] Profile snapshot per scan: **decided 2026-10-29.** A rating is history; it keeps the profile it was scored for (ADR-007, built).
- [ ] Decide: Nutri-Score general layer; delete the 7 stub scans; vegetarian, vegan and halal as hard stops (built; confirm).
- [x] Rescoring old scans: **no** (ADR-007). New rules, like RULE-010C sugar and the heart-health sodium check, apply to new scans only.
- [ ] Optional: fill in `scored_for` on your 31 old scans. They were rescored on 2026-10-28 against "high cholesterol only". This touches your account, so it needs your approval.
- [ ] The photos already stored for your 31 scans may still hold GPS. New uploads are stripped. Re-processing old photos touches your account, so it needs your approval.

## Next engineering candidates
CI is written (`decisions/devops/ci.md`). It runs on GitHub after the next push. Next: deploy to Cloud Run (`APP_ENV=production`, `TRUSTED_PROXY_HOPS=1`), Google sign-in, Play Store release. The order is in `decisions/engineering-manager/_index.md`.
