# CTO: cross-cutting

Reverse-engineered from the codebase and the decisions made with the founder. Confirmed by the founder on 2026-10-28.

## Product
CalFit scans a **photo** of a packaged food (front or back of pack). It identifies the product and scores how well it fits the user's health profile out of 10, explains why, and suggests real alternatives. It is India-first.

## Tech stack
- **Mobile:** Flutter (Android first; POCO M4 Pro is the test device), Material 3, gen-l10n in 5 languages.
- **Backend:** Python 3.12, FastAPI, Pydantic v2, LangGraph pipeline.
- **AI:** Gemini via `google-genai`, behind a provider interface. A Vertex AI (Mumbai) mode exists.
- **Data:**
  - Supabase: Postgres plus a private storage bucket, in Singapore.
  - A local SQLite food database (`apps/api/data/food.db`, 764 Indian products from Open Food Facts).
  - Live Open Food Facts lookup.
- **Hosting:** Google Cloud Run `asia-south1` (planned, runbook written, not deployed).

## Strategic decisions already taken with the founder
| Decision | Choice |
|---|---|
| Launch model | Free first; payments later |
| Sign-in | Google sign-in (decided; **not built**: anonymous device tokens today) |
| Languages | English, Hindi, Assamese, Bengali, Khasi |
| Input | Photo-first, not barcode |
| AI plan | Gemini on Vertex AI, `asia-south1` (recommended in `docs/AI_PROVIDER_OPTIONS.md`; **not bought yet**) |
| Look | Warm, light-first; centre Scan button with Home/History · Scan · Insights/Profile |

## Build vs buy
- **Build:** deterministic scoring rules and formula, identification decisions, alternatives ranking.
- **Buy:** Gemini, Supabase, Cloud Run.
- **Use open data:** Open Food Facts (ODbL; attribution in Settings).

Feature files: `calfit-mvp.md`.
