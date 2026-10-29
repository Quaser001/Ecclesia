"""Every response carries the security headers (readiness review E)."""

from __future__ import annotations

from httpx import ASGITransport, AsyncClient

from src.main import app


def _client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def test_api_responses_carry_security_headers():
    async with _client() as c:
        for r in (await c.get("/health"), await c.get("/api/v1/profile")):  # 200 and 401
            assert r.headers["x-content-type-options"] == "nosniff"
            assert r.headers["x-frame-options"] == "DENY"
            assert r.headers["referrer-policy"] == "no-referrer"
            assert r.headers["cache-control"] == "no-store"  # health data is never cached
            assert "default-src 'none'" in r.headers["content-security-policy"]


async def test_the_dev_docs_page_still_loads_its_scripts():
    async with _client() as c:
        r = await c.get("/docs")
    assert "content-security-policy" not in r.headers
