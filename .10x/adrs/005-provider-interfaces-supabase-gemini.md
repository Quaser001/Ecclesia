# ADR-005: External services behind provider interfaces (Supabase, Gemini/Vertex, Open Food Facts)

**Status:** Accepted: decided during development; recorded and confirmed 2026-10-28
**Date:** 2026-10-28
**Feature:** provider-interfaces-supabase-gemini
**Author:** 10x-Team (Architect + Staff Engineer)

## Context
AGENTS.md requires abstraction boundaries. Tests must never hit live services. The AI provider may change (Vertex).

## Decision
ABCs in `providers/interfaces.py` and `providers/food_lookup.py`, with Supabase and local SQLite implementations, Gemini via AI Studio or Vertex (`GEMINI_BACKEND`), and Open Food Facts. Dependencies are wired in `config/dependencies.py`.

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| Call SDKs directly in handlers | Less code | Untestable; vendor lock-in | Violates AGENTS.md |

## Consequences
### Positive
- Fakes in tests; switching to Vertex is a config change.
### Negative / Risks
- Each new method must be implemented in both providers and any test fakes.

## Dependencies
- `AGENTS.md`; related ADRs in `.10x/adrs/`.
