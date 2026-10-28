# ADR-003: Identify front-of-pack photos from real products, then confirm or choose

**Status:** Accepted: decided during development; recorded and confirmed 2026-10-28
**Date:** 2026-10-28
**Feature:** front-of-pack-real-product-identification
**Author:** 10x-Team (Architect + Staff Engineer)

## Context
Front photos have no nutrition panel, so the old pipeline refused them. Founder request: identify the product, confirm or offer the top 2–3, retake if unsure, look up data from the database or online.

## Decision
Gemini reads identity fields plus `identity_confidence`. Options are ranked deterministically from food.db, then one Open Food Facts search (brand must match, pack size narrows). The user confirms or chooses; `/scans/confirm` re-fetches by code.

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| Ask Gemini for its top-3 guesses | Matches the founder's wording | Invites invented products; breaks AGENTS.md | Real-products-only rule |

## Consequences
### Positive
- No invented products; provenance stored; lookup outages reported honestly.
### Negative / Risks
- Open Food Facts allows about 10 searches/min per IP. Mitigated by a cache, one search per scan, and importing more into food.db.

## Dependencies
- `AGENTS.md`; related ADRs in `.10x/adrs/`.
