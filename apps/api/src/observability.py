"""Request IDs, one line per request, and one summary line per scan.

What goes in a log: ids, timings, counts, model names and outcomes. What never
does: photos, label text, profile fields, explanations or raw exception text
(provider errors can echo the prompt, which holds health conditions). Logs are
a data store too: they are kept for weeks and read by more people than the
database, so they get the strictest rule.

With LOG_FORMAT=json each line is one JSON object, which Cloud Logging parses
into searchable fields (severity, request_id, stage_ms, ...). Locally the
default is readable text.
"""

from __future__ import annotations

import contextvars
import inspect
import json
import logging
import re
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable

_request_id: contextvars.ContextVar[str] = contextvars.ContextVar("request_id", default="-")
_scan_trace: contextvars.ContextVar[ScanTrace | None] = contextvars.ContextVar(
    "scan_trace", default=None
)

# A caller may pass its own id (the app could, to match a bug report); anything
# odd-looking is replaced so log lines can't be forged or bloated.
_VALID_ID = re.compile(r"^[A-Za-z0-9._-]{8,64}$")

access_logger = logging.getLogger("calfit.access")
scan_logger = logging.getLogger("calfit.scan")


def current_request_id() -> str:
    return _request_id.get()


# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------


class _RequestIdFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = _request_id.get()
        return True


class JsonFormatter(logging.Formatter):
    """One JSON object per line, in the field names Cloud Logging understands."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "severity": record.levelname,
            "time": datetime.fromtimestamp(record.created, timezone.utc).isoformat(),
            "logger": record.name,
            "message": record.getMessage(),
            "request_id": getattr(record, "request_id", "-"),
        }
        fields = getattr(record, "fields", None)
        if isinstance(fields, dict):
            payload.update(fields)
        if record.exc_info and record.exc_info[0] is not None:
            payload["exception"] = record.exc_info[0].__name__  # type only, never text
        return json.dumps(payload, default=str)


def configure_logging(fmt: str = "text") -> None:
    handler = logging.StreamHandler()
    handler.addFilter(_RequestIdFilter())
    if fmt == "json":
        handler.setFormatter(JsonFormatter())
    else:
        handler.setFormatter(logging.Formatter(
            "%(asctime)s %(levelname)s %(name)s [%(request_id)s] - %(message)s"))
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(logging.INFO)
    # HTTP client libraries log every request URL at INFO, and Supabase URLs
    # carry ids (user_id=eq.<id>). Keep their warnings, drop the URLs.
    for noisy in ("httpx", "httpcore", "hpack"):
        logging.getLogger(noisy).setLevel(logging.WARNING)


# ---------------------------------------------------------------------------
# Per-request context
# ---------------------------------------------------------------------------


async def request_context_middleware(request: Any, call_next: Callable[..., Any]) -> Any:
    """Give every request an id, echo it back, and log method/route/status/time."""
    incoming = request.headers.get("x-request-id", "")
    rid = incoming if _VALID_ID.match(incoming) else uuid.uuid4().hex
    token = _request_id.set(rid)
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        response.headers["X-Request-ID"] = rid
        return response
    finally:
        route = request.scope.get("route")
        # The route template (/scans/{scan_id}), not the raw path, so lines
        # group by endpoint and carry no ids from the URL.
        access_logger.info(
            "%s %s %s", request.method, getattr(route, "path", "unmatched"), status,
            extra={"fields": {
                "event": "http.request",
                "method": request.method,
                "route": getattr(route, "path", "unmatched"),
                "status": status,
                "duration_ms": round((time.perf_counter() - start) * 1000),
            }},
        )
        _request_id.reset(token)


# ---------------------------------------------------------------------------
# Per-scan trace
# ---------------------------------------------------------------------------


@dataclass
class ScanTrace:
    stage_ms: dict[str, int] = field(default_factory=dict)
    facts: dict[str, Any] = field(default_factory=dict)


def start_scan_trace() -> ScanTrace:
    trace = ScanTrace()
    _scan_trace.set(trace)
    return trace


def note(**facts: Any) -> None:
    """Record facts about the scan in progress (model used, fallbacks, ...)."""
    trace = _scan_trace.get()
    if trace is not None:
        trace.facts.update(facts)


def _record(stage: str, start: float) -> None:
    trace = _scan_trace.get()
    if trace is not None:
        trace.stage_ms[stage] = round((time.perf_counter() - start) * 1000)


def timed(stage: str, fn: Callable[..., Any]) -> Callable[..., Any]:
    """Wrap a pipeline node so its run time lands in the scan trace.

    Nodes take the state as their only argument (the rest is bound with
    functools.partial), so the wrapper keeps that exact shape for LangGraph.
    """
    if inspect.iscoroutinefunction(fn):
        async def run_async(state: Any) -> Any:
            start = time.perf_counter()
            try:
                return await fn(state)
            finally:
                _record(stage, start)
        return run_async

    def run_sync(state: Any) -> Any:
        start = time.perf_counter()
        try:
            return fn(state)
        finally:
            _record(stage, start)
    return run_sync


def log_scan_summary(trace: ScanTrace, total_ms: int, **outcome: Any) -> None:
    """The one line per scan that dashboards and alerts are built on."""
    fields = {"event": "scan.completed", "total_ms": total_ms,
              "stage_ms": dict(trace.stage_ms), **trace.facts, **outcome}
    scan_logger.info(
        "scan %s in %d ms (%s)", outcome.get("outcome", "?"), total_ms,
        trace.facts.get("model", "no model"),
        extra={"fields": fields},
    )
