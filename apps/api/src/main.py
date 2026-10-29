"""CalFit FastAPI application entry point."""

from __future__ import annotations

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from src.api.v1.endpoints import router as api_router
from src.body_limit import BodyLimitMiddleware
from src.config.settings import settings
from src.observability import configure_logging, current_request_id, request_context_middleware
from src.providers.interfaces import ServiceUnavailable
from src.request_limit import RequestLimitMiddleware

configure_logging(settings.LOG_FORMAT)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    # Production refuses to start misconfigured, instead of failing on the
    # first request or quietly using a laptop fallback (ADR-006).
    settings.validate_for_production()
    if not settings.is_production:
        for problem in settings.config_problems():
            logger.warning("Development config: %s", problem)
    yield


# The interactive docs and schema list every route: useful locally, an
# inventory for attackers in production.
_docs = not settings.is_production
app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json" if _docs else None,
    docs_url="/docs" if _docs else None,
    redoc_url="/redoc" if _docs else None,
    lifespan=lifespan,
)


@app.exception_handler(ServiceUnavailable)
async def service_unavailable(_: Request, exc: ServiceUnavailable) -> JSONResponse:
    return JSONResponse(
        status_code=503,
        content={"detail": exc.message, "request_id": current_request_id()},
        headers={"Retry-After": "30"},
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

# Size and token-presence checks before any route parses a body.
app.add_middleware(BodyLimitMiddleware, max_upload_bytes=settings.MAX_SCAN_UPLOAD_BYTES)

# Per-caller request cap on every route; before the body is read.
app.add_middleware(
    RequestLimitMiddleware,
    per_token=settings.REQUESTS_PER_HOUR_PER_TOKEN,
    per_ip=settings.REQUESTS_PER_HOUR_PER_IP,
    trusted_proxy_hops=settings.TRUSTED_PROXY_HOPS,
)

# Added last, so it runs first: every request (CORS preflights and 413s too) gets an id.
app.middleware("http")(request_context_middleware)

app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/health", status_code=200)
async def health_check() -> dict[str, str]:
    """Root-level liveness probe (same shape as the versioned one)."""
    return {"status": "ok", "service": "CalFit API"}
