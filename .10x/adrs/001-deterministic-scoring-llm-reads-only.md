# ADR-001: Deterministic rule-based scoring; the LLM only reads and explains

**Status:** Accepted: decided during development; recorded and confirmed 2026-10-28
**Date:** 2026-10-28
**Feature:** deterministic-scoring-llm-reads-only
**Author:** 10x-Team (Architect + Staff Engineer)

## Context
A health app's verdict must be reproducible, auditable and safe. LLM outputs vary and can invent facts.

## Decision
Scores come from code: `rule_catalog.py` thresholds with citations, plus `scoring_rules.py`. Gemini only transcribes labels and writes explanations, which must pass a grounding check. All Gemini output is parsed into Pydantic models.

## Alternatives Considered
| Alternative | Pros | Cons | Why Not |
|-------------|------|------|---------|
| LLM decides suitability | Flexible, handles odd labels | Not reproducible; can hallucinate; can't be audited | Unsafe for allergies and medical conditions |

## Consequences
### Positive
- Same inputs give the same score; a dietitian can review one file. Odd labels need explicit rules.
### Negative / Risks
- Rules can miss cases. Mitigated by "Couldn't check your allergens", a data gate that refuses no-data scans, and user feedback.

## Dependencies
- `AGENTS.md`; related ADRs in `.10x/adrs/`.
