"""CalFit configuration settings."""

from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """CalFit configuration — all values come from environment variables."""

    # "production" turns on startup validation (validate_for_production) and
    # turns off everything that only makes sense on a laptop: the local SQLite
    # / disk / in-memory fallbacks and the public API docs. ADR-006.
    APP_ENV: Literal["development", "production"] = "development"

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

    # How many proxies in front of us append to X-Forwarded-For. 0 = use the
    # socket peer (local dev). Cloud Run's front end appends one entry: 1.
    # The client can put anything in the header, so only entries our own
    # proxies appended (counted from the right) are trusted. services/client_ip.py
    TRUSTED_PROXY_HOPS: int = 0

    # Prescription reading sends a medical document to Gemini. Keep OFF until the
    # key is on the paid, no-training tier (docs/GEMINI_BILLING.md). Even when
    # ON, it only runs on Vertex or when the paid tier is confirmed: see
    # prescription_ai_allowed. Prescriptions must never reach the free tier.
    PRESCRIPTION_AI_ENABLED: bool = False
    PRESCRIPTION_DAILY_CAP: int = 5
    # Set to true only after checking in AI Studio that GEMINI_API_KEY's
    # project has billing on (paid tier: Google doesn't train on the data).
    GEMINI_PAID_TIER_CONFIRMED: bool = False

    # Gemini — real, generally-available model names only.
    # Browse https://ai.google.dev/gemini-api/docs/models for the current list.
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.5-flash"
    # Per call. Cloud Run cuts a request at its own timeout, so one slow model
    # must not use all of it.
    GEMINI_TIMEOUT_SECONDS: int = 25

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

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def is_production(self) -> bool:
        return self.APP_ENV == "production"

    @property
    def supabase_configured(self) -> bool:
        return bool(self.SUPABASE_URL and self.SUPABASE_SERVICE_ROLE_KEY)

    @property
    def prescription_ai_allowed(self) -> bool:
        """Prescriptions are health data: only on a tier that doesn't train on them."""
        return self.PRESCRIPTION_AI_ENABLED and (
            self.GEMINI_BACKEND == "vertex" or self.GEMINI_PAID_TIER_CONFIRMED
        )

    def config_problems(self) -> list[str]:
        """What would make a production instance wrong. Names only, never values."""
        problems = []
        if len(self.AUTH_SECRET_KEY) < 32:
            problems.append("AUTH_SECRET_KEY is missing or shorter than 32 characters")
        if not self.supabase_configured:
            problems.append("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must both be set")
        if self.GEMINI_BACKEND == "vertex" and not self.GOOGLE_CLOUD_PROJECT:
            problems.append("GEMINI_BACKEND=vertex needs GOOGLE_CLOUD_PROJECT")
        if self.GEMINI_BACKEND == "developer_api" and not self.GEMINI_API_KEY:
            problems.append("GEMINI_API_KEY is not set")
        if self.PRESCRIPTION_AI_ENABLED and not self.prescription_ai_allowed:
            problems.append("PRESCRIPTION_AI_ENABLED needs GEMINI_BACKEND=vertex "
                            "or GEMINI_PAID_TIER_CONFIRMED=true")
        return problems

    def validate_for_production(self) -> None:
        """Refuse to start a production instance that would misbehave quietly."""
        if self.is_production and (problems := self.config_problems()):
            raise RuntimeError("Refusing to start in production: " + "; ".join(problems))


# Global settings instance
settings = Settings()
