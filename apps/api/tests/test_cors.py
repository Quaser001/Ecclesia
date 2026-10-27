"""CORS behaviour tests.

The browser's "same origin" is scheme + host + **port**, so `http://127.0.0.1`
is a different origin from `http://127.0.0.1:5000`. The Flutter web dev server
picks whatever port is free, which makes the dev CORS list hard to spell by
hand. We use a localhost regex instead; this test locks that in.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from src.main import app

client = TestClient(app)


def _preflight(origin: str):
    return client.options(
        "/api/v1/profile",
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "GET",
        },
    )


def test_cors_allows_flutter_web_dev_port():
    r = _preflight("http://127.0.0.1:5000")
    assert r.status_code == 200
    assert r.headers.get("access-control-allow-origin") == "http://127.0.0.1:5000"


def test_cors_allows_any_localhost_port():
    r = _preflight("http://localhost:51234")
    assert r.headers.get("access-control-allow-origin") == "http://localhost:51234"


def test_cors_allows_android_emulator_alias():
    r = _preflight("http://10.0.2.2:8000")
    assert r.headers.get("access-control-allow-origin") == "http://10.0.2.2:8000"


def test_cors_blocks_untrusted_origin_in_dev():
    r = _preflight("https://evil.example.com")
    # Starlette does not refuse the preflight itself, but it must NOT echo the
    # origin back as allowed.
    assert r.headers.get("access-control-allow-origin") != "https://evil.example.com"
