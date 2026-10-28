# ADR-002: Score out of 10 as a product of desirability factors

**Status:** Accepted: decided during development; recorded and confirmed 2026-10-28
**Date:** 2026-10-28
**Feature:** multiplicative-desirability-score
**Author:** 10x-Team (Architect + Staff Engineer)

## Context
The old engine subtracted fixed points per rule, which caused cliffs at thresholds and pile-ups at 0, 25 and 75. The founder asked for a real formula, out of 10.

## Decision
score = 10 × ∏ d_i. Measured nutrients use piecewise-linear curves through the cited thresholds; ingredient-presence findings use a severity factor; hard stops are 0. Stored as integer tenths. See `docs/SCORING_FORMULA.md`.

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| Weighted geometric mean | Standard desirability aggregate | Checks that don't apply dilute real problems | More checks would raise scores |
| Nutri-Score as the score | Published, credible | Not personal; banded; needs fibre/FVL data | Kept as a candidate general layer |

## Consequences
### Positive
- No cliffs (tested); a serious problem dominates; each finding has an explainable cost.
### Negative / Risks
- Curve heights are CalFit judgment and need a dietitian review. Users with no matching conditions get 10.0.

## Dependencies
- `AGENTS.md`; related ADRs in `.10x/adrs/`.
