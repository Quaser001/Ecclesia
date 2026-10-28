"""CalFit FastAPI application entry point."""

from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.api.v1.endpoints import router as api_router
from src.config.settings import settings
from src.observability import configure_logging, request_context_middleware

configure_logging(settings.LOG_FORMAT)
logger = logging.getLogger(__name__)

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
)

# Dev-safe default; override at deploy time with CORS_ALLOWED_ORIGINS=https://a.com,https://b.com
#
# Browsers compare origins exactly, so `http://127.0.0.1` is NOT the same as
# `http://127.0.0.1:5000`. In dev we accept any localhost / 127.0.0.1 / Android
# emulator alias on any port via a regex, while production stays on the strict
# explicit list from CORS_ALLOWED_ORIGINS.
_cors_origins: list[str] = []
_cors_origin_regex: str | None = None
if settings.CORS_ALLOWED_ORIGINS:
    _cors_origins = [o.strip() for o in settings.CORS_ALLOWED_ORIGINS.split(",") if o.strip()]
else:
    _cors_origin_regex = r"^http://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$"

# Credentials-aware CORS requires an explicit origin list or regex (never "*").
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_origin_regex=_cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Added after CORS, so it runs first: every request (CORS preflights too) gets an id.
app.middleware("http")(request_context_middleware)

app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/health", status_code=200)
async def health_check() -> dict[str, str]:
    """Root-level liveness probe (same shape as the versioned one)."""
    return {"status": "ok", "service": "CalFit API"}
