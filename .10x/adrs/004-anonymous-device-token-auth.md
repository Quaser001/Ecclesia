# ADR-004: Anonymous HMAC device tokens for MVP auth

**Status:** Accepted: decided during development; recorded and confirmed 2026-10-28
**Date:** 2026-10-28
**Feature:** anonymous-device-token-auth
**Author:** 10x-Team (Architect + Staff Engineer)

## Context
The MVP needed per-user data without accounts or passwords.

## Decision
`POST /auth/device` issues `v1.<id>.<hmac>` signed with `AUTH_SECRET_KEY`. The client re-registers on a 401 (except for delete). Daily caps limit abuse.

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| Google sign-in now | Durable identity, cross-device | More setup; a consent flow | Decided for market; not built yet |

## Consequences
### Positive
- Zero-friction start; no passwords stored.
### Negative / Risks
- Data is tied to an install: uninstalling loses access. Google sign-in is planned.

## Dependencies
- `AGENTS.md`; related ADRs in `.10x/adrs/`.
