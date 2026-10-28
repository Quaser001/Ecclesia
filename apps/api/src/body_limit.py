"""Reject oversized or anonymous uploads before anything parses them.

FastAPI reads a multipart form (spooling each file to disk past 1 MB) before
it runs any dependency, so the token and size checks in the routes come after
the whole body has been received. This ASGI middleware runs first: it refuses
a body over the limit from its Content-Length, counts the bytes of a body
without one, and turns away an upload that carries no bearer token at all.
"""

from __future__ import annotations

import json
from typing import Any

from starlette.exceptions import HTTPException

UPLOAD_PATHS = frozenset({
    "/api/v1/scans",
    "/api/v1/scans/confirm",
    "/api/v1/profile/prescription-suggestions",
})
# Room for the multipart boundaries and the confirm form's small fields.
UPLOAD_OVERHEAD = 64 * 1024
# Every other body is small JSON (a profile with its capped lists, feedback).
OTHER_BODY_LIMIT = 64 * 1024


class _TooLarge(HTTPException):
    """Raised from receive() mid-body. An HTTPException because FastAPI turns
    any other error while reading a body into "400 error parsing the body"."""

    def __init__(self, detail: str) -> None:
        super().__init__(status_code=413, detail=detail)


class BodyLimitMiddleware:
    def __init__(self, app: Any, max_upload_bytes: int) -> None:
        self.app = app
        self.max_upload = max_upload_bytes + UPLOAD_OVERHEAD

    async def __call__(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        upload = scope["path"] in UPLOAD_PATHS
        limit = self.max_upload if upload else OTHER_BODY_LIMIT
        headers = {k.lower(): v for k, v in scope.get("headers", [])}

        if upload and scope["method"] == "POST" \
                and not headers.get(b"authorization", b"").lower().startswith(b"bearer "):
            await _reply(send, 401, "Missing or invalid credentials.",
                         [(b"www-authenticate", b"Bearer")])
            return
        declared = headers.get(b"content-length")
        if declared is not None and (not declared.isdigit() or int(declared) > limit):
            await _reply(send, 413, _too_large(limit, upload))
            return

        received = 0
        started = False

        async def counted_receive() -> dict[str, Any]:
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > limit:
                    raise _TooLarge(_too_large(limit, upload))
            return message

        async def tracked_send(message: dict[str, Any]) -> None:
            nonlocal started
            if message["type"] == "http.response.start":
                started = True
            await send(message)

        try:
            await self.app(scope, counted_receive, tracked_send)
        except _TooLarge as exc:  # an app that doesn't handle HTTPException itself
            if started:
                raise
            await _reply(send, 413, str(exc.detail))


def _too_large(limit: int, upload: bool) -> str:
    if upload:
        return f"Image too large. Maximum size is {(limit - UPLOAD_OVERHEAD) // (1024 * 1024)} MB."
    return "Request body too large."


async def _reply(send: Any, status: int, detail: str,
                 extra_headers: list[tuple[bytes, bytes]] | None = None) -> None:
    body = json.dumps({"detail": detail}).encode()
    await send({
        "type": "http.response.start",
        "status": status,
        "headers": [(b"content-type", b"application/json"),
                    (b"content-length", str(len(body)).encode()),
                    *(extra_headers or [])],
    })
    await send({"type": "http.response.body", "body": body})
