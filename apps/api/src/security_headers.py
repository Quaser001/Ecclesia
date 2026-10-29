"""Security headers on every response.

The API answers JSON to the app, but a response can still be opened in a
browser, cached by a proxy, or framed. These headers close that off:

* Cache-Control: no-store: profile, scan and history responses carry health
  data; no proxy, CDN or on-disk cache may keep a copy.
* X-Content-Type-Options: nosniff: a JSON body is never run as a script.
* X-Frame-Options / CSP frame-ancestors: no page may frame the API.
* Referrer-Policy: no-referrer: no URL (with ids in it) leaks onward.
* Content-Security-Policy: default-src 'none' on API routes: a response
  can't load anything. Skipped on the dev-only /docs pages, which need scripts.
* Strict-Transport-Security in production: browsers never try plain HTTP.
"""

from __future__ import annotations

from starlette.types import ASGIApp, Message, Receive, Scope, Send

_DOCS = ("/docs", "/redoc", "/openapi.json")


class SecurityHeadersMiddleware:
    def __init__(self, app: ASGIApp, *, hsts: bool) -> None:
        self.app = app
        self.hsts = hsts

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        path: str = scope.get("path", "")
        api_page = not any(path.startswith(d) or path.endswith(d) for d in _DOCS)

        async def send_with_headers(message: Message) -> None:
            if message["type"] == "http.response.start":
                headers = list(message.get("headers", []))
                present = {k.lower() for k, _ in headers}

                def add(name: str, value: str) -> None:
                    if name.encode() not in present:
                        headers.append((name.encode(), value.encode()))

                add("x-content-type-options", "nosniff")
                add("x-frame-options", "DENY")
                add("referrer-policy", "no-referrer")
                if api_page:
                    add("cache-control", "no-store")
                    add("content-security-policy", "default-src 'none'; frame-ancestors 'none'")
                if self.hsts:
                    add("strict-transport-security", "max-age=31536000; includeSubDomains")
                message["headers"] = headers
            await send(message)

        await self.app(scope, receive, send_with_headers)
