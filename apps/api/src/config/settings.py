"""CalFit configuration settings."""

from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """CalFit configuration — all values come from environment variables."""

    # API Settings
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "CalFit API"

    # Comma-separated list of allowed CORS origins for production.
    # Empty = fall back to localhost-only defaults in main.py.
    CORS_ALLOWED_ORIGINS: str = ""

    # Scan upload limits
    MAX_SCAN_UPLOAD_BYTES: int = 10 * 1024 * 1024  # 10 MB

    # Daily scan cap per user. One bad actor should not run up the Gemini bill.
    # UTC midnight reset. See services/rate_limit.py.
    DAILY_SCAN_CAP: int = 50

    # Secret used to sign per-device tokens (>= 32 chars). Server-side only.
    # Generate one with: python -c "import secrets; print(secrets.token_urlsafe(48))"
    AUTH_SECRET_KEY: str = ""

    # How many new device identities one client IP may mint per UTC day.
    DEVICE_TOKEN_DAILY_CAP_PER_IP: int = 20

    # Prescription reading sends a medical document to Gemini. Keep OFF until the
    # key is on the paid, no-training tier (docs/GEMINI_BILLING.md).
    PRESCRIPTION_AI_ENABLED: bool = False
    PRESCRIPTION_DAILY_CAP: int = 5

    # Gemini — real, generally-available model names only.
    # Browse https://ai.google.dev/gemini-api/docs/models for the current list.
    GEMINI_API_KEY: str = ""
    GEMINI_API_KEYS: str = ""
    GEMINI_MODEL: str = "gemini-2.5-flash"

    # Where Gemini runs (docs/AI_PROVIDER_OPTIONS.md).
    #   developer_api: AI Studio, authenticated with GEMINI_API_KEY.
    #   vertex: Vertex AI in GOOGLE_CLOUD_LOCATION, authenticated with the
    #     service account (no API key). Processing stays in that region and
    #     Google does not train on the data.
    GEMINI_BACKEND: Literal["developer_api", "vertex"] = "developer_api"
    GOOGLE_CLOUD_PROJECT: str = ""
    GOOGLE_CLOUD_LOCATION: str = "asia-south1"

    # Grok (xAI)
    GROK_API_KEY: str = ""
    GROK_BASE_URL: str = "https://api.groq.com/openai/v1"
    GROK_VISION_MODEL: str = "llama-3.2-11b-vision-preview"
    GROK_TEXT_MODEL: str = "llama-3.3-70b-versatile"

    # Groq Cloud
    GROQ_API_KEY: str = ""
    GROQ_BASE_URL: str = "https://api.groq.com/openai/v1"
    GROQ_VISION_MODEL: str = "llama-3.2-11b-vision-preview"
    GROQ_TEXT_MODEL: str = "openai/gpt-oss-120b"

    # Cerebras
    CEREBRAS_API_KEY: str = ""
    CEREBRAS_BASE_URL: str = "https://api.cerebras.ai/v1"
    CEREBRAS_TEXT_MODEL: str = "gpt-oss-120b"

    # Supabase
    SUPABASE_URL: str = ""
    SUPABASE_PUBLISHABLE_KEY: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""

    # Storage
    STORAGE_BUCKET: str = "calfit-scans"

    # Online product lookup (Open Food Facts) when a front-of-pack photo names a
    # product that isn't in food.db. Only the product name is sent.
    FOOD_LOOKUP_ENABLED: bool = True
    FOOD_LOOKUP_USER_AGENT: str = "CalFit/0.1 (+https://github.com/Quaser001/Ecclesia)"

    # "json" on Cloud Run (one JSON object per line, parsed by Cloud Logging);
    # "text" locally. See docs/EVALS_AND_OBSERVABILITY.md.
    LOG_FORMAT: Literal["text", "json"] = "text"

    # Dev convenience — default user ID when no auth system is connected.
    # Not used for authorization: endpoints still take user_id explicitly.
    DEFAULT_USER_ID: str = "dev-user-001"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


# Global settings instance
settings = Settings()
