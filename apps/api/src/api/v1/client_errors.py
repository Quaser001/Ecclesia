"""Receive crash reports from the mobile app.

The app catches Flutter-level errors and sends the type and stack frames
here. No message field — exception messages can echo health data from
prompts, API responses or profile fields, so we never accept or log them.

The endpoint is unauthenticated on purpose: a crash during sign-in or
token migration must still be reportable. To prevent abuse the per-IP
rate limit applies (RequestLimitMiddleware).
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Response
from pydantic import BaseModel, Field

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
async def report_client_error(body: ClientErrorReport) -> Response:
    """Log a client crash. Returns 204 unconditionally so a broken app
    doesn't get stuck retrying."""
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
