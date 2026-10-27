"""CalFit configuration settings."""

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
