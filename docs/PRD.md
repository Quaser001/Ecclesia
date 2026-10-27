# Product Requirements Document: CalFit

## 1. Product Overview
**CalFit** is an AI-powered personalized nutrition and dietary scanner mobile application. By taking a simple photo of a food product's packaging, CalFit cross-references the extracted ingredients, allergens, and nutritional information against the user's specific health profile, medical conditions, and dietary preferences. It then produces a deterministic, highly personalized "Suitability Score," an easy-to-understand explanation, and data-backed alternative recommendations.

## 2. Target Audience & Use Cases
* **Individuals with Health Conditions:** Users managing Type 1/Type 2 Diabetes, Hypertension, High Cholesterol, or Celiac Disease who need to carefully monitor specific nutritional intakes (e.g., Sodium, Sugar, Trans Fats, Gluten).
* **Dietary-Restricted Individuals:** Users adhering to specific diets (Vegan, Vegetarian, Keto, Gluten-Free, Halal, Dairy-Free, etc.).
* **Allergy Sufferers:** Users needing strict confidence that food products are safe from their allergens.
* **Health & Fitness Enthusiasts:** Users targeting Weight Loss, Muscle Gain, or general dietary improvements.

## 3. Core Features & Capabilities

### 3.1. Personalized User Profiles
* **Health Conditions:** Users can log chronic conditions (e.g., Hypertension, Diabetes, IBS, Heart Disease, Celiac Disease).
* **Allergies:** Free-text/tag-based tracking of specific allergens.
* **Dietary Preferences:** Pre-defined toggles for diets (e.g., Vegan, Gluten-Free, Paleo).
* **Health Goals:** Objectives like Weight Loss, Muscle Gain, or Maintaining Blood Sugar.

### 3.2. AI-Powered Product Scanning (Computer Vision)
* **Photo Capture:** Users take a photo of the product packaging (nutrition label / ingredients).
* **LLM Extraction (Gemini):** Vision AI extracts brand, product name, ingredients, nutritional values (calories, fat, sugar, sodium, protein), and declared allergens into a structured schema.
* **Data Confidence:** The system flags whether nutrition extraction is high-confidence or estimated.
* **Local Database Matching:** The system matches extracted data against a local product database (Open Food Facts) to enrich missing data and prevent AI hallucinations.

### 3.3. Deterministic Health Scoring Engine
* **Rule-Based Evaluation:** A strict, non-LLM, rules-engine that acts as the single source of truth.
* **Point Penalty System:** Products start at a score of 100. Specific violations (e.g., High Sodium for a Hypertension user, Gluten for a Celiac user) trigger penalty deductions.
* **Risk Levels:** Scores are categorized into Suitability Statuses (Excellent, Good, Fair, Poor, Not Suitable) and Risk Levels (Low, Moderate, High, Critical).
* **Scan Findings:** Concrete, deterministic findings explaining exactly *which* rule was triggered and *why* (e.g., "Contains Trans Fat - Critical").

### 3.4. AI-Generated Personalized Explanations
* **Contextual Explanations:** Taking the output of the deterministic scoring engine and the user's profile, the LLM generates a personalized, empathetic, and easily readable summary of the evaluation.

### 3.5. Healthy Alternatives Generation
* **Database-Driven Recommendations:** If a product scores poorly, the app suggests better-fitting alternatives natively sourced from the verified local Open Food Facts database.
* **Guidance Criteria:** If an exact product match isn't available, it provides criteria for what the user should look for instead.

### 3.6. Scan History
* **Activity Tracking:** A history log of previously scanned items, displaying the product photo, date, score, and final suitability.

---

## 4. Technical Architecture

### 4.1. Mobile Application (Client)
* **Framework:** Flutter / Dart
* **Target:** Android (Primary)
* **Responsibility:** UI/UX, Camera integration, API communication.

### 4.2. Backend API
* **Language/Framework:** Python 3.12 + FastAPI
* **Package Manager:** `uv`
* **Core Design:** Separation of concerns between API routes (`apps/api/src/api`), Services (`apps/api/src/services`), and Domain logic (`apps/api/src/domain`).
* **Validation:** Strict data structuring and validation using **Pydantic**.

### 4.3. External Providers
* **AI/LLM Provider:** Google Gemini (Used *strictly* for data extraction from photos and grounding natural language explanations).
* **Database & Auth:** Supabase (PostgreSQL for user profiles, scan histories, and Knowledge Base).
* **File Storage:** Cloud Storage for storing uploaded product scan images.

### 4.4. Workflow Orchestration
* **LangGraph:** Powers the pipeline (`scan_graph.py`).
* **State Flow:** `Analyze Photo` -> `Validate Extraction` -> `Match Product (Local DB)` -> `Retrieve Knowledge Base` -> `Load Profile` -> `Score Product (Deterministic)` -> `Generate Explanation` -> `Find Alternatives`.

---

## 5. Engineering Rules & Guardrails
*(Crucial for project integrity as defined in `agents.md`)*

1. **Strictly Deterministic Logic:** The LLM is **never** used for scoring, rule checking, or logic execution. The rule engine (`scoring_rules.py`) holds absolute authority over suitability and risk calculation.
2. **No Data Hallucination:** 
    * Missing data (e.g., missing sugar value) remains `None`.
    * Alternatives must come from the actual database, or be framed as search criteria. Never hallucinate fake products.
3. **Data Provenance:** The local Open Food Facts database is the authoritative source. Provenance and confidence scores must be preserved.
4. **Clean Abstractions:** External provider interactions (Gemini, Supabase, Storage) are abstracted behind interfaces/abstract classes.
5. **Secrets Management:** The mobile client is completely free of secrets. All API keys and environment variables live strictly on the FastAPI server. 
6. **No Silent Failures:** In the event of a failure or unreadable image, the pipeline gracefully routes to an "Insufficient Data" state rather than mocking fake data.