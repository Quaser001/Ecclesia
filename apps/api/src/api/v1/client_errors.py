"""Receive crash reports from the mobile app.

The app catches Flutter-level errors and sends the type and stack frames
here. No message field — exception messages can echo health data from
prompts, API responses or profile fields, so we never accept or log them.

The endpoint is unauthenticated on purpose: a crash during sign-in or
token migration must still be reportable. Because it is unauthenticated and
writes a retained log line per call, it has its own tight per-IP daily cap
(CLIENT_ERROR_DAILY_CAP_PER_IP) on top of the global request limit. Reports
over the cap are dropped — still answered 204 — so they never reach the log.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Request, Response
from pydantic import BaseModel, Field

from src.config.dependencies import ClientErrorLimiterDep
from src.config.settings import settings
from src.services.client_ip import client_ip
from src.services.rate_limit import RateLimitExceeded

logger = logging.getLogger("calfit.client_error")

router = APIRouter(tags=["observability"])


class StackFrame(BaseModel):
    file: str = Field(max_length=256)
    line: int = Field(ge=0, le=999_999)
    fn: str = Field(default="", max_length=256)


class ClientErrorReport(BaseModel):
    error_type: str = Field(min_length=1, max_length=256)
    frames: list[StackFrame] = Field(default_factory=list, max_length=30)
    app_version: str = Field(default="", max_length=32)
    platform: str = Field(default="", max_length=32)


@router.post("/client-errors", status_code=204, response_class=Response)
async def report_client_error(
    request: Request,
    body: ClientErrorReport,
    limiter: ClientErrorLimiterDep = None,
) -> Response:
    """Log a client crash. Returns 204 unconditionally so a broken app
    doesn't get stuck retrying. Reports past this IP's daily cap are dropped
    without logging, so one IP can't run up the log bill."""
    try:
        await limiter.check_and_increment(client_ip(request, settings.TRUSTED_PROXY_HOPS))
    except RateLimitExceeded:
        return Response(status_code=204)
    logger.warning(
        "Client %s in %s",
        body.error_type,
        body.frames[-1].file if body.frames else "?",
        extra={"fields": {
            "event": "client_error",
            "error_type": body.error_type,
            "frames": [f.model_dump() for f in body.frames],
            "app_version": body.app_version,
            "platform": body.platform,
        }},
    )
    return Response(status_code=204)
