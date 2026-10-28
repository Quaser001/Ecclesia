# QA: cross-cutting

Confirmed by the founder on 2026-10-28.

## Suites
| Suite | Count | Notes |
|---|---|---|
| Backend pytest | 450 | Includes formula properties (no cliffs, monotonic, hard stops, mutation-checked), identification, lookup, front-of-pack flow, observability privacy and eval report |
| App flutter test | 59 | Includes a double-size-text layout check on a 360 dp screen, picker/serving/feedback flows, paging, onboarding |
| Live smoke (scratch folder) | 24 + 15 | Throwaway account against real Supabase and Open Food Facts; checks the founder's account is untouched |

## Gaps
- **Label-reading accuracy test** has no labelled photos yet.
- **No CI**, so tests only run when someone runs them.
- **No end-to-end test on a device;** MIUI blocks automated taps.
