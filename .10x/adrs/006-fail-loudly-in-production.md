# ADR-006: Fail loudly in production, never fall back silently

**Status:** Accepted
**Date:** 2026-10-29
**Feature:** production-hardening
**Author:** 10x-Team (Architect + Staff Engineer)

## Context

The audit found five places where a failure was turned into a normal-looking answer:

- A failed profile load scored the scan against an empty profile, so allergies were ignored.
- A Gemini outage was reported as "take a clearer photo".
- Missing Supabase settings switched production to a local SQLite file.
- A 401 made the app quietly start a new identity with no profile.
- A failed save still returned a scan id.

Each one is invisible in monitoring, and the first and fourth can produce a wrong health verdict. AGENTS.md already says "No Silent Fake Fallbacks". The code had drifted from that rule.

## Decision

1. **`APP_ENV` setting** (`development` by default, or `production`). In production, startup validates the config and refuses to start when any of these is true:
   - Supabase is missing;
   - `AUTH_SECRET_KEY` is missing or shorter than 32 characters;
   - Gemini isn't configured for the selected backend.

   The local SQLite, local storage and in-memory fallbacks stay available for development and tests only. In development they log one warning at startup.
2. **A failure in any input the score depends on stops the score.** The user gets an honest "couldn't load / try again" result, and nothing is saved. This applies to the profile and the label read.
3. **A dependency outage is an HTTP 503 with a plain message**, not a 200 that blames the user's photo.
4. **The client never silently changes identity.** If it must re-register, it sends the user back to profile setup first.
5. **Providers are created once per process and shared.** One Supabase client and one Gemini client per process. The LangGraph graph is compiled once.

## Alternatives considered

| Alternative | Pros | Cons | Why not |
|---|---|---|---|
| Keep the fallbacks; add alerts on log lines | No behaviour change | Users still get wrong verdicts while the alert fires | Safety issue, not only observability |
| Retry the profile load and then fall back | Fewer user-visible errors | Still scores without allergies when the retries fail | The fallback itself is the bug |
| Detect Cloud Run via `K_SERVICE` instead of `APP_ENV` | Zero config | Hidden coupling to one host; tests can't simulate it clearly | Explicit is clearer; the deploy doc sets `APP_ENV=production` |

## Consequences

- **Positive:**
  - Outages and misconfiguration are visible immediately, at startup or as 503s.
  - Scores are only ever computed from the real profile.
- **Negative:**
  - A user sees "try again" more often during a Supabase or Gemini blip, instead of a degraded result.
  - The deploy needs `APP_ENV=production`.
- **Risk:** a production deploy without `APP_ENV` gets development behaviour. Mitigation: the deploy doc sets it, and `check_config` prints which mode is active.

## Dependencies

- Builds on ADR-005 (provider interfaces).
- Constrains the future deploy and CI: both must set `APP_ENV=production`.
