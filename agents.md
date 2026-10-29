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

## 5. Mobile Client Security & Robustness
* **The app talks only to our API**: The Flutter client never calls Supabase, Gemini or any third party directly and never holds their URLs or keys (no `supabase_flutter`, no anon key). The only build-time value is `--dart-define=API_BASE_URL`, which is not a secret.
* **Credentials live in the Keystore**: Bearer tokens and anything that unlocks a person's data go through `SecretStore` (`lib/services/secret_store.dart`, flutter_secure_storage with `resetOnError: false`). Never in `SharedPreferences`. Plain prefs are for non-sensitive settings only (theme, language, "disclaimer seen").
* **No device identifiers**: Don't store or send a per-phone id. Identity is the server-issued token, one per profile (ADR-008).
* **A lost credential is never a new user**: If the Keystore can't produce a token it had, mark the profile "save your profile again" (reset pending). Never mint a fresh, empty identity silently.
* **Keystore package majors are manual**: A major version can drop the cipher saved tokens use. Dependabot ignores them; upgrade one major at a time after testing the upgrade over an existing install on a phone (`adb install -r`, never uninstall first).
* **`mounted` after every await**: In a `State`, check `if (!mounted) return;` after each `await` before `setState`, `Navigator` or `ScaffoldMessenger`. Outside a `State`, check `context.mounted`. Dispose every controller, subscription and timer a `State` creates.
* **Network errors are named, not generic**: `ApiService._run` maps timeouts, `SocketException` and `http.ClientException` to their `ApiErrorKind`, so the screen says "can't reach the server" rather than "something went wrong". Screens show `UserMessage.of(context, e)`, never `e.toString()`.
* **Layouts adapt**: Screens without an `AppBar` wrap their body in `SafeArea`; bottom sheets too. No fixed heights that assume a portrait phone; scale with `MediaQuery.sizeOf` and clamp. Content scrolls.

## 6. Backend Error Handling
* **Errors reach the app as JSON with a request id, never as raw text**: No exception message, stack trace, SQL or upstream URL in a response. Log the exception *type* only (`type(exc).__name__`), since messages can contain health data.
* **Upstream down = 503, our bug = 500**: A dependency that times out or drops (`httpx.TransportError`, `ServiceUnavailable`) is a 503 with `Retry-After`. A PostgREST `APIError` is a bug in our query and stays a 500. Never turn either into an empty or default result (ADR-006).
* **Database calls go through the provider interfaces** (`SupabaseProvider`, `StorageProvider`), and each provider method logs and re-raises; routes don't swallow them.
