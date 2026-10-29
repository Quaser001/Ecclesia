# ADR-007: A scan's rating is history; editing the profile never changes it

**Status:** Accepted (founder's decision, 2026-10-29)
**Date:** 2026-10-29
**Feature:** scan-history
**Author:** 10x-Team (Architect + Staff Engineer)

## Context

Scores are personal: the same cola scores differently for a diabetic than for someone with no conditions. When the profile changes, what should old scans show?

Until now, stored scans kept their score, but nothing recorded which profile produced it. History then looked wrong. For example, Sting at 10.0 for someone whose profile now says "weight loss": it was scored before that goal was added. Rescoring old scans was an open question; earlier it was done once, by hand.

## Decision

**A rating is a record of the moment it was made.**
- Each scan keeps the score, verdict and findings it got.
- It also keeps `scored_for`: the conditions, allergies, diets, goals and caffeine setting it was scored against. No name, no body details.
- Editing the profile never rescores past scans.
- The scan screen shows "Scored for" with that profile's chips. On past scans it adds: "Changing your profile later doesn't change this rating."

The snapshot lives inside `score_json` (`ScoreResult.scored_for`), so there is no schema change and no migration. Scans saved before this change have no snapshot. Their screen shows only the note.

Insights' "Your goals" section is unaffected. It re-checks stored products against the current goals by design, because it answers "how do my scans fit what I'm working toward now?".

## Alternatives considered

| Alternative | Pros | Cons | Why not |
|---|---|---|---|
| Rescore every scan on each profile change | History always "current" | Rewrites the past; history can't show what you saw then; a profile edit becomes a bulk write | The founder chose history |
| Keep scores, no snapshot (status quo) | Nothing to build | Old ratings look like bugs (Sting 10.0 with a weight-loss goal) | Confusing |
| Snapshot in a new `scans.profile_snapshot` column | Queryable in SQL | Needs a live migration; nothing queries it yet | `score_json` already carries the scoring result |

## Consequences

- **Positive:**
  - History is honest and explainable.
  - Scoring-rule fixes, like RULE-010C sugar, apply only to new scans, which is what a record should do.
- **Negative:**
  - Each scan row duplicates a few profile fields. They are covered by "Delete my data" and stated in the privacy policy (2.3).
- **Risk:** the old 31 scans have no snapshot. Filling it in would touch the founder's account, so it waits for approval.
