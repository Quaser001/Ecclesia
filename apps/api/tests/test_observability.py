"""Request ids, per-request and per-scan log lines, and what must never be logged."""

from __future__ import annotations

import asyncio
import io
import json
import logging
from types import SimpleNamespace

from httpx import ASGITransport, AsyncClient

from src.config.dependencies import get_gemini_provider, get_supabase_provider
from src.main import app
from src.observability import JsonFormatter, ScanTrace, note, start_scan_trace, timed
from src.providers.gemini_provider import GoogleGeminiProvider
from src.providers.local_db_provider import LocalDBProvider
from tests.test_api_endpoints import MockGemini

JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00"


def _client():
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


def _records(caplog, logger_name):
    return [r for r in caplog.records if r.name == logger_name]


# --- request ids --------------------------------------------------------------


async def test_every_response_carries_a_request_id():
    async with _client() as c:
        r = await c.get("/health")
    rid = r.headers["x-request-id"]
    assert len(rid) == 32 and all(ch in "0123456789abcdef" for ch in rid)


async def test_a_sane_incoming_id_is_kept_and_a_bad_one_replaced():
    async with _client() as c:
        kept = await c.get("/health", headers={"X-Request-ID": "app-1234abcd"})
        replaced = await c.get("/health", headers={"X-Request-ID": "x\"; drop"})
    assert kept.headers["x-request-id"] == "app-1234abcd"
    assert replaced.headers["x-request-id"] != "x\"; drop"


async def test_access_line_uses_the_route_template_not_the_raw_path(caplog, make_device, tmp_path):
    caplog.set_level(logging.INFO)
    db = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    app.dependency_overrides[get_supabase_provider] = lambda: db
    _, h = make_device()
    try:
        async with _client() as c:
            r = await c.get("/api/v1/scans/secret-scan-id-123", headers=h)
    finally:
        app.dependency_overrides.clear()
    assert r.status_code == 404
    line = _records(caplog, "calfit.access")[-1]
    # FastAPI reports the template as declared in its router (no /api/v1).
    assert line.fields["route"] == "/scans/{scan_id}"
    assert line.fields["status"] == 404 and line.fields["duration_ms"] >= 0
    assert "secret-scan-id-123" not in line.getMessage()


# --- the scan summary line ----------------------------------------------------


async def test_a_scan_logs_one_summary_with_stage_timings_and_no_health_data(
        caplog, make_device, tmp_path):
    caplog.set_level(logging.INFO)
    db = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    app.dependency_overrides[get_gemini_provider] = lambda: MockGemini()
    app.dependency_overrides[get_supabase_provider] = lambda: db
    user_id, h = make_device()
    try:
        async with _client() as c:
            await c.put("/api/v1/profile", headers=h, json={
                "user_id": user_id, "name": "Asha Rahman",
                "health_conditions": ["hypertension"], "allergies": ["peanut"]})
            r = await c.post("/api/v1/scans", headers=h,
                             files={"photo": ("p.jpg", io.BytesIO(JPEG), "image/jpeg")})
    finally:
        app.dependency_overrides.clear()
    assert r.status_code == 200

    summaries = [x for x in _records(caplog, "calfit.scan")
                 if getattr(x, "fields", {}).get("event") == "scan.completed"]
    assert len(summaries) == 1
    f = summaries[0].fields
    assert f["outcome"] == "scored" and f["saved"] is True
    assert f["scan_id"] == r.json()["scan_id"]
    for stage in ("analyze_photo", "match_product", "score_product",
                  "generate_explanation", "find_alternatives"):
        assert stage in f["stage_ms"]
    assert f["explanation"] in ("llm", "fallback_ungrounded")
    assert f["ai_backend"] in ("developer_api", "vertex")

    # The whole JSON line, as Cloud Logging would store it.
    line = JsonFormatter().format(summaries[0]).lower()
    for private in ("maggi", "masala", "peanut", "hypertension", "asha", user_id.lower(),
                    r.json()["explanation"][:40].lower()):
        assert private not in line, private


# --- formatter and provider never log exception text --------------------------


def test_json_lines_keep_the_exception_type_but_not_its_text():
    try:
        raise ValueError("patient has type 1 diabetes")
    except ValueError:
        import sys
        record = logging.LogRecord("x", logging.ERROR, __file__, 1, "failed", None, sys.exc_info())
    out = json.loads(JsonFormatter().format(record))
    assert out["exception"] == "ValueError" and out["severity"] == "ERROR"
    assert "diabetes" not in json.dumps(out)


async def test_gemini_errors_are_logged_by_type_and_the_answering_model_is_noted(caplog):
    caplog.set_level(logging.DEBUG)
    calls = []

    async def generate(**kwargs):
        calls.append(kwargs["model"])
        if len(calls) == 1:
            raise RuntimeError("echo: user has type 1 diabetes")
        return SimpleNamespace(text="Fine.")

    p = GoogleGeminiProvider(api_key="k", model="m1")
    p._client = SimpleNamespace(aio=SimpleNamespace(models=SimpleNamespace(generate_content=generate)))
    trace = start_scan_trace()
    assert await p.generate_explanation([{"role": "user", "content": "x"}]) == "Fine."
    assert "diabetes" not in caplog.text
    assert "RuntimeError" in caplog.text
    assert trace.facts == {"explanation_model": calls[1], "explanation_attempts": 2}


def test_http_client_urls_stay_out_of_the_logs():
    # Supabase request URLs contain user ids; httpx logs them at INFO.
    from src.observability import configure_logging

    configure_logging("text")
    for name in ("httpx", "httpcore"):
        assert logging.getLogger(name).getEffectiveLevel() >= logging.WARNING


# --- timing wrapper -----------------------------------------------------------


def test_timed_records_sync_and_async_nodes():
    trace = start_scan_trace()

    async def slow(state):
        await asyncio.sleep(0.01)
        return {"a": state}

    def quick(state):
        return {"b": state}

    assert asyncio.run(timed("slow", slow)(1)) == {"a": 1}
    assert timed("quick", quick)(2) == {"b": 2}
    note(model="m")
    assert isinstance(trace, ScanTrace)
    assert set(trace.stage_ms) == {"slow", "quick"} and trace.stage_ms["slow"] >= 5
    assert trace.facts == {"model": "m"}
