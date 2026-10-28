# Architect: scoring-formula

Decided with the founder on 2026-10-28. Confirmed by the founder on 2026-10-28. See ADR-002 and `docs/SCORING_FORMULA.md`.

- **score = 10 × ∏ factor(finding).** Measured nutrients use curves through the cited thresholds (`rule_catalog.SCORE_CURVES`); ingredient-presence findings use a fixed factor per severity; hard stops are 0.
- **Stored as integer tenths (0–100).**
- **Finding cost** = score without that finding − actual score; a hard stop always costs 100.
- **Open:** a general quality layer (Nutri-Score), dietitian review of the curve heights, and whether to keep a profile snapshot per scan.
