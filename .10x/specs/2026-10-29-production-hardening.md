# Production hardening pass (2026-10-29)

**Goal:** close the gaps that AI-assisted ("vibe-coded") apps typically ship with. Only fix problems that independent reviewers confirmed in the real code.

## How the findings were produced

**1. Research.** The checklist came from common vibe-coding failures:
- missing rate limits;
- keys in the client;
- missing server-side authorisation;
- silent fallbacks;
- OWASP API Top 10 (2023) and OWASP LLM Top 10 (2025): prompt injection, unbounded consumption, improper output handling;
- containers running as root, unpinned dependencies, Android backup and release settings.

**2. Audit.**
- 8 reviewers each took one dimension and produced 87 raw findings. These merged into 48 distinct issues.
- Verification:
  - 5 issues were already upheld 3/3 in the first run.
  - 1 was checked by hand: pip-audit run on `uv.lock`.
  - The other 42 went to batched skeptics, one per code area: 4 agents, about 322k tokens.
- 47 issues were upheld and 1 was refuted (AJ: dash execs the last command, so SIGTERM already reaches uvicorn).
- The first run hit the plan's session limit by verifying each finding with 3 separate agents (about 90). This pass reuses the finder output and verifies in batches.

**3. Fix, in priority order, test first** (see the table).

**4. Re-audit** the diff only, then run the full test suites and the live checks.

## Fix now

| Pri | Id | Problem (verified) | Fix |
|---|---|---|---|
| 1 | A | A failed profile load scores the scan with an **empty profile**, so an allergy can be missed | Don't score. Route to an "insufficient" result with a clear message, and don't save it |
| 1 | AX | Weight-loss rule reads sugar but never checks it: a 53 g sugar cola scores 10/10 | Add a sugar check with a cited threshold. Existing scans are not rescored without asking |
| 1 | Y | Gemini outage, bad key or exhausted quota → HTTP 200 "take a clearer photo" | Return 503 "temporarily unavailable" so the outage is visible |
| 1 | AP | App: any 401 silently swaps to a new, empty identity, losing allergies | Re-registering after a 401 also sends the user back to profile setup |
| 1 | Q | Prescriptions can go to the AI Studio tier, which may be free, when the flag is on | Only allowed with `GEMINI_BACKEND=vertex` or an explicit `GEMINI_PAID_TIER_CONFIRMED=true` |
| 1 | P, R, I | Missing Supabase config silently switches production to local SQLite; bad secrets only fail per request; docs public | `APP_ENV=production` fails at startup on missing or weak config, and hides /docs |
| 2 | B | "Delete my data" resets today's scan and prescription quota | Keep today's counters (they hold only an id, a date and a count) |
| 2 | C | Registration cap keyed on Cloud Run's proxy address | `TRUSTED_PROXY_HOPS`: read the client IP the proxy appended, never the client-supplied leftmost entry |
| 2 | D | Uploads are fully parsed before auth and the size check | ASGI body-size limit middleware (413) before routing |
| 2 | E | Profile name and allergies unbounded, copied into every prompt | Pydantic length and count limits |
| 2 | K | Gemini: no timeout, no output cap, and every error retried on 6 models (including retired ones) | Timeout, max output tokens, fall back only on retriable errors, current models only |
| 2 | N, M | Open Food Facts lookups unthrottled; uploads trusted by declared content type | Process-wide lookup throttle; magic-byte check |
| 3 | Z | Failed save still returns a scan_id that doesn't exist, and orphans the photo | `saved` flag in the response; delete the orphan photo |
| 3 | L, J | Model-written notes and explanations can claim "no milk" or "suits you" | Fixed message for unreadable photos; guard rejects allergen denials and fit claims that contradict the findings |
| 3 | T, AB | Supabase clients and the graph rebuilt per request; blocking sqlite on the event loop | Shared clients; product matching off the event loop |
| 3 | H, AA, G | Exception text in logs; plain 500s with no request id; non-ASCII token → 500 | Log type only; JSON 500 with request_id; 401 |
| 3 | S | Nothing checks that the keys actually work | `python -m src.check_config` checks every key, the tables and the bucket's privacy. A `/ready` probe is left for the deploy |
| 3 | AT, AS, AQ, AR, AV, AW | GPS EXIF stored; auto-backup copies the token; release can fall back to cleartext; error bodies logged; rx 429 shown as generic; consent survives delete | Strip EXIF; allowBackup off; release requires https; quiet logs; correct error kind; clear consent |
| 3 | AL | Knowledge query limits to 10 rows *before* filtering | Filter in the query |
| 4 | U, AH, AE, AF | Dockerfile uv 0.4.30 can't read the uv 0.11 lock; builds the project needlessly; docs inaccurate | Pin uv 0.11.18; `--no-install-project`; fix the docs |
| 4 | 42 | 22 vulnerabilities, but only in the stale root `.venv`; `uv.lock` audits clean | Run everything from `apps/api/.venv` |
| 4 | AZ, AY, BA, X, V, W | Stale "/100" text; auth test covers 4 routes; band drift; dead settings; wrong project in .env.example; personal ids in .10x | Small fixes plus an every-route auth test |

## Left for a decision (not built now; AGENTS.md scope rule)

- **F**, token expiry and revocation: needs a token version table or refresh tokens.
- **AN**, retention job for abandoned identities: needs a policy number. The privacy policy already says one will be added before launch.
- **AM**, transactional delete: needs a SQL function migration applied to live Supabase.
- **AO**, composite index: a migration applied to live Supabase.
- **AC**, migration tracking; CI; **AG**, image digests; **AI**, read-only app files in the image.
- **O**, per-token read limits (edge rate limiting at deploy); **AK**, stats via a database aggregate.
- **cf18218** (unpushed) contains the personal identifiers in `.10x/handoff.md`. A new commit won't remove them from history, so decide before pushing.

## Done means

- Every fix has a test that failed before it.
- Backend tests and `flutter test` / `flutter analyze` pass.
- The live smoke checks pass against the local backend.
- A diff-only re-audit finds no regressions.
