# ADR-008: Family profiles are separate identities on one phone

**Status:** Accepted (founder chose "adults first", 2026-10-29)
**Date:** 2026-10-29
**Feature:** family-profiles
**Author:** 10x-Team (Architect + Security)

## Context

A family (for example father, mother and an adult child) wants to share one phone. Each person needs their own conditions, scans, history, insights and quota, and switching should work like Telegram's accounts.

## Decision

- **One anonymous server identity per person.** The phone keeps a list of profiles in `ProfileRegistry`: a local id, a label and that person's signed token.
- **Switching** changes the active profile. The app builds a separate `ApiService`, bound to that profile's token, and rebuilds every tab, keyed by profile.
- **The backend and database are unchanged.** Every existing guarantee now holds per person: token-scoped reads and writes, quota, delete, and the "scored for" snapshot (ADR-007).
- **A token store bound to one profile id,** not "the active one". A request finishing after a switch stays with the person it was made for.
- **Per person:** prescription consent and the profile-reset flag. **Per phone:** theme, language, text size, onboarding and the disclaimer.
- **"Delete my data"** deletes the active person's data and removes them from the phone. The last profile stays as an empty one.
- **Upgrade path:** the first run after the update moves the existing single sign-in into the first profile. No data moves on the server.
- **Adults only for now.** The add dialog says so, and the privacy policy (2.2) explains separate identities.

## Alternatives considered

| Alternative | Why not now |
|---|---|
| One account with members (`members` table; `member_id` on scans, feedback and servings) | Needs a live migration and changes every route, which adds a new way to read someone else's data; family-level features aren't needed yet |
| Several installs or app clones | Not something users can be expected to do |

## Consequences

- **Positive:**
  - Strongest separation: the server can't link family members.
  - No migration.
  - Isolation is already proven by the existing per-identity tests.
- **Negative:**
  - Each person has their own daily scan cap, so a family gets more scans; each new profile uses 1 of the 20 registrations per IP per day.
  - "Delete everyone" has to delete each profile in turn.
  - Google sign-in later must link several identities to one login.
- **Children:** not supported yet. They need verifiable parental consent (DPDP Act) and child-specific thresholds; the current limits are for adults.
