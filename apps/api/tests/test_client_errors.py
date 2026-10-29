"""Client-error reporting endpoint: the app sends crash types and frames,
never exception messages (which can echo health data)."""

from __future__ import annotations

import logging

import pytest
from httpx import ASGITransport, AsyncClient

from src.main import app


def _client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


async def test_valid_report_returns_204():
    async with _client() as c:
        r = await c.post("/api/v1/client-errors", json={
            "error_type": "StateError",
            "frames": [
                {"file": "home_screen.dart", "line": 42, "fn": "build"},
                {"file": "main.dart", "line": 10, "fn": "main"},
            ],
            "app_version": "1.0.0+1",
            "platform": "android",
        })
    assert r.status_code == 204


async def test_minimal_report():
    async with _client() as c:
        r = await c.post("/api/v1/client-errors", json={"error_type": "TypeError"})
    assert r.status_code == 204


async def test_empty_type_rejected():
    async with _client() as c:
        r = await c.post("/api/v1/client-errors", json={"error_type": ""})
    assert r.status_code == 422


async def test_oversized_type_rejected():
    async with _client() as c:
        r = await c.post("/api/v1/client-errors", json={"error_type": "X" * 300})
    assert r.status_code == 422


async def test_too_many_frames_rejected():
    frames = [{"file": "a.dart", "line": i, "fn": "f"} for i in range(40)]
    async with _client() as c:
        r = await c.post("/api/v1/client-errors", json={"error_type": "E", "frames": frames})
    assert r.status_code == 422


async def test_no_auth_required():
    """Crashes during sign-in or token migration must still be reportable."""
    async with _client() as c:
        r = await c.post("/api/v1/client-errors", json={"error_type": "StateError"})
    assert r.status_code == 204


async def test_log_output_has_no_health_data(caplog):
    """The log must contain the error type and frames but never any string
    that could be a health condition or allergy (which would appear in an
    exception message, which we deliberately don't accept)."""
    fake_allergy = "peanut-anaphylaxis-profile"
    with caplog.at_level(logging.WARNING, logger="calfit.client_error"):
        async with _client() as c:
            await c.post("/api/v1/client-errors", json={
                "error_type": "StateError",
                "frames": [{"file": "scan.dart", "line": 1, "fn": "run"}],
            })
    assert any("StateError" in r.message for r in caplog.records)
    assert all(fake_allergy not in r.message for r in caplog.records)


async def test_unhandled_error_logs_frames(caplog):
    """An unhandled exception in a route logs the type and frames, not the
    message (which can contain health data from upstream responses)."""

    @app.get("/test-crash")
    async def _crash():
        raise ValueError("secret allergy: peanut")

    with caplog.at_level(logging.ERROR):
        async with _client() as c:
            r = await c.get("/test-crash")
    assert r.status_code == 500

    error_records = [r for r in caplog.records if r.levelno >= logging.ERROR]
    assert any("ValueError" in r.message for r in error_records)
    for rec in error_records:
        assert "peanut" not in rec.message
        fields = getattr(rec, "fields", None)
        if fields:
            assert "peanut" not in str(fields)
