"""A cap on how many requests one caller can make per hour, on every route.

The daily scan and prescription caps protect the Gemini bill; this protects
everything else (history, insights, profile writes) from a script hammering
the API. Two keys:

- the bearer token, when there is one: one person's app, whatever network;
- the client IP, always, with a much higher cap. Indian mobile carriers put
  many phones behind one address (carrier-grade NAT), so a strict per-IP
  limit would lock out real users who happen to share it.

Counts are per instance and reset on restart. That is enough for a first
layer; a shared edge limit (Cloud Armor) comes with the deploy.
"""

from __future__ import annotations

import hashlib
import json
import time
from typing import Any

from src.services.client_ip import client_ip

WINDOW_SECONDS = 3600
_EXEMPT = frozenset({"/health", "/api/v1/health"})  # Cloud Run's probes
_MAX_KEYS = 50_000  # stale windows are dropped past this, so memory stays bounded


class RequestLimitMiddleware:
    def __init__(self, app: Any, per_token: int, per_ip: int, trusted_proxy_hops: int) -> None:
        self.app = app
        self.per_token = per_token
        self.per_ip = per_ip
        self.hops = trusted_proxy_hops
        self._counts: dict[str, tuple[int, int]] = {}  # key -> (window, count)

    def reset(self) -> None:
        self._counts.clear()

    def _hit(self, key: str, cap: int, window: int) -> bool:
        """Count one request; True if it is over the cap."""
        start, count = self._counts.get(key, (window, 0))
        if start != window:
            count = 0
        self._counts[key] = (window, count + 1)
        return count + 1 > cap

    async def __call__(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if scope["type"] != "http" or scope["path"] in _EXEMPT:
            await self.app(scope, receive, send)
            return
        window = int(time.time()) // WINDOW_SECONDS
        if len(self._counts) > _MAX_KEYS:
            self._counts = {k: v for k, v in self._counts.items() if v[0] == window}

        headers = {k.lower(): v for k, v in scope.get("headers", [])}
        ip = client_ip(_Req(scope, headers), self.hops)
        over = self._hit(f"ip:{ip}", self.per_ip, window)
        auth = headers.get(b"authorization", b"")
        if auth.lower().startswith(b"bearer "):
            # A hash, so tokens are never held in memory as-is.
            token_key = hashlib.sha256(auth[7:].strip()).hexdigest()[:32]
            over = self._hit(f"t:{token_key}", self.per_token, window) or over
        if not over:
            await self.app(scope, receive, send)
            return

        retry_after = str(WINDOW_SECONDS - int(time.time()) % WINDOW_SECONDS)
        body = json.dumps({"detail": "Too many requests. Please try again later."}).encode()
        await send({
            "type": "http.response.start",
            "status": 429,
            "headers": [(b"content-type", b"application/json"),
                        (b"content-length", str(len(body)).encode()),
                        (b"retry-after", retry_after.encode())],
        })
        await send({"type": "http.response.body", "body": body})


class _Req:
    """The two things client_ip reads, from a raw ASGI scope."""

    def __init__(self, scope: dict[str, Any], headers: dict[bytes, bytes]) -> None:
        peer = scope.get("client")
        self.client = type("Peer", (), {"host": peer[0]})() if peer else None
        self.headers = {"x-forwarded-for": headers.get(b"x-forwarded-for", b"").decode("latin-1")}
