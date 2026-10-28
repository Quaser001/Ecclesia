# Product Manager: cross-cutting

Confirmed by the founder on 2026-10-28.

## Users
Indian shoppers managing a condition (diabetes, hypertension, cholesterol, kidney disease, anaemia and others), an allergy, or a diet (vegetarian, vegan, halal, keto and others), or with a goal such as weight loss.

## Core flows (built)
1. **Onboarding:** language, allergies/conditions/diet, safety note.
2. **Scan:**
   - Back of pack: read the label, then score.
   - Front of pack: identify the product → confirm or choose → score.
   - Unreadable: retake.
3. **Result:**
   - Score out of 10 and verdict.
   - Findings, each with its cost.
   - "At a glance" nutrient levels.
   - Label facts with their source.
   - Alternatives.
   - "Was this right?" feedback.
   - Serving-size note.
   - "Not this product?"
4. **History** (paged), **Home** (totals), **Insights** (trends, goal fit), **Profile** (conditions, body details/BMI, prescription reading), **Settings** (language, text size, theme, privacy, delete my data).

## Success measures
- **User feedback:** at least 85% "right"; any missed allergen is an alert (`scripts/eval_report.py`).
- **Label-reading accuracy:** allergen recall ≥ 0.98 and precision ≥ 0.90 (`docs/EVALS_AND_OBSERVABILITY.md`). Needs 50–100 labelled photos, which the founder has not made yet.

## Open product decisions
- **General quality score** for users with no matching condition (Nutri-Score 2023?). Today every product is 10.0 for them.
- **History scores:** keep each scan's score frozen at the profile used then, or re-score when the profile changes? (Profile snapshot per scan.)
- **7 imported test scans** with stub photos (6× Amul Lassi, 1× Masala Munch): delete?
- **Vegetarian/vegan/halal violations** became hard stops (score 0). Founder to confirm.

Feature files: `calfit-mvp.md`.
