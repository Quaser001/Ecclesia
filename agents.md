# CalFit Engineering Rules

## 1. Code Modifiability & Inspection
* **Inspect first**: Always inspect existing structures and implementation details before modifying code.
* **Preserve working code**: Do not rewrite or break components that are already functioning correctly.
* **No unnecessary dependencies**: Minimize external packages; favor native platforms/APIs and pre-configured stable integrations.
* **Reusable/modular code**: Design for isolated features rather than deep hierarchies. Keep files small and distinct.

## 2. Architecture & Abstractions
* **Separation of Concerns**: Separate business/domain logic completely from API route handlers and Flutter UI layers.
* **External Provider Abstraction**: Always write interface boundaries (abstract classes) for external integrations (Gemini, Supabase, Storage).
* **Pydantic Validation**: Rely strictly on Pydantic schemas for data modeling, configurations, request/response validation, and serialization.
* **Deterministic Logic**: Never delegate deterministic calculations, scores, rule checks, or logic execution to LLMs. Deterministic scoring is authoritative. LLMs are used for extraction and grounded natural-language explanation only.
* **LangGraph Orchestration**: LangGraph orchestrates the workflow and handles conditional routing; it does not hallucinate or invent facts.
* **Gemini Output Validation**: All Gemini outputs must be parsed into structured Pydantic models and validated. Unknown information must remain unknown (NULL/empty).
* **Real Alternatives Only**: Never fabricate or hallucinate real products or alternatives. Alternatives must come from the local product database or provide structured criteria guidance.

## 3. Data & Storage
* **Local Food Database**: The local food product database (from Open Food Facts) is the authoritative development source.
* **Preserve Provenance**: Always preserve data source provenance (`source="open_food_facts"`, dates, data confidence).
* **Missing Data Handling**: Missing nutrition or ingredients must remain `None`/unknown. Never hallucinate or silently fill in missing data.
* **Secrets Management**: Absolutely no secrets or API keys exposed in source control or the Flutter mobile client. Secrets remain server-side.
* **No Silent Fake Fallbacks**: Never silently return fake/mock data in production pipelines when a real failure occurs; provide clear, transparent status/errors.

## 4. Engineering Quality & Verification
* **Test meaningful changes**: All changes to business logic, scoring rules, and API endpoints require automated tests.
* **Verify before claiming success**: Never declare a feature complete without compiling, analyzing, and successfully running tests.
* **Scope control**: Keep MVP scope focused. Do not expand MVP scope or build speculative infrastructure.
