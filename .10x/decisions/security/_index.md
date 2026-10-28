# Security: cross-cutting

Confirmed by the founder on 2026-10-28.

## In place
- **Auth:** anonymous device tokens `v1.<id>.<hmac>` signed with `AUTH_SECRET_KEY`; a 401 triggers re-registration. Daily caps: 50 scans per user, 20 new device ids per IP.
- **Earlier OWASP review:** the path-traversal fix in local storage and the RLS lockdown came out of it.
- **Photos:** private bucket, one-hour signed links, paths checked against `scans/<user>/`.
- **Secrets:** in Secret Manager on Cloud Run; none in the app; `.env` is git-ignored.
- **Logs:** no content, no error text, no user ids (enforced by tests).
- **Prescriptions:** off until the paid, no-training AI plan is in place; nothing from them is stored.
- **Confirm endpoint:** only a product code comes from the client; the data is fetched server-side.
- **Privacy policy (DPDP):** both copies are kept in sync. Open Food Facts lookups send only the product name.

- **Hardening pass (2026-10-29, ADR-006):**
  - production refuses to start misconfigured;
  - outages are 503s, and a profile that failed to load is never scored;
  - body-size and token-presence checks run before parsing; magic bytes are checked and JPEG location data stripped;
  - the per-IP registration cap reads the proxy-appended IP;
  - today's quota counters survive "Delete my data";
  - prescriptions need Vertex or a confirmed paid tier;
  - profile text is bounded;
  - app: no cloud backup of the token, no cleartext in release, no identity swap mid-scan, no error bodies in logs.

  Details: `reviews/2026-10-29-production-hardening.md`.

## Open
- **Gemini key in `apps/api/.env` is invalid** (401 on 2026-10-29): the founder must replace it.
- **Deferred:**
  - token expiry and revocation;
  - retention for abandoned identities;
  - transactional delete (SQL function);
  - per-token read limits.
- **Google sign-in not built.** Device tokens tie data to an install.
- **Free Gemini tier** must not see real users (Vertex plan not bought).
- **No crash reporting or consent flow.**
- **Privacy policy** still has blank contact and grievance-officer fields.
- **Advisor warning:** `vector` extension in the public schema.
