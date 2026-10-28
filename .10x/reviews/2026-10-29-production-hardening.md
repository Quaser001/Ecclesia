# Review: production hardening (2026-10-29)

**Roles:** QA and Security. **Spec:** `specs/2026-10-29-production-hardening.md`.

## How it was checked

**Audit (2026-10-28 run, reused):**
- 8 reviewers, each covering one dimension, produced 87 raw findings, which merged into 48 distinct issues.

**Verification:**
- 5 issues were upheld 3/3 in the first run.
- 1 was checked by hand: pip-audit on `uv.lock` (clean).
- 42 went to 4 batched skeptics, one per code area.
- Result: 47 upheld, 1 refuted (AJ: dash execs the last command, so SIGTERM reaches uvicorn).

**Fixes:**
- Every fix-now item has a test.
- Of the 54 new backend tests, these were mutation-checked: putting the old behaviour back made each test fail, and the code was then restored:
  - A: an empty profile was scored instead of returning a 503;
  - AX: the cola scored 10/10;
  - B: the quota counters were wiped;
  - Q (checked by reasoning only): the endpoint answered on the AI Studio tier.

**Re-audit:**
- 2 diff-only reviewers checked the changes and found 6 problems; all are fixed and tested.
- The biggest: a Gemini 400 (a corrupt photo) had become "AI unavailable".
- The others:
  - a chunked over-limit body got a 400, not a 413;
  - the lazy client creation could race;
  - the deploy doc's prescription step would now fail to start;
  - profile builds lost cleartext to the local dev server;
  - a prescription 503 read as a server outage.

**Live:**
- Smoke suites: 24/24 and 15/15 against real Supabase.
- `check_config` found the Gemini key invalid (401).
- A real scan returns 503 "AI service unavailable" after **1** Gemini call. The old code made 6 calls and said "take a clearer photo".

## Results

| Suite | Before | After |
|---|---|---|
| Backend pytest | 450 | **504** pass |
| App `flutter test` | 59 | **63** pass |
| `flutter analyze` | clean | clean |
| mypy (`apps/api/.venv`) | 111 errors | 105 (none new) |
| pip-audit on `uv.lock` | 0 vulns | 0 vulns |

## Not verified

- **Docker image build:** Docker isn't installed on this machine. The uv pin now matches the lock (0.11.18, lock revision 3); the first real build is still to come.
- **On-device check of the app changes:** the phone is disconnected.
- **Photo scans end to end:** blocked by the invalid Gemini key. The 503 path itself was verified live.
- **Khasi strings:** the two new error strings need the pending native review.
