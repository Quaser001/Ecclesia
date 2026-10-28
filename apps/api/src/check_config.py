"""Check that every configured key and service actually works.

    cd apps/api && .venv/Scripts/python.exe -m src.check_config

Each check makes one small, free call: Gemini's model metadata (not a
generation), one row from Supabase, the photo bucket's settings. Prints
OK / FAIL per line and exits 1 if anything failed. It prints names and error
types only, never a key or a value from .env.
"""

from __future__ import annotations

import asyncio
import sys
from collections.abc import Awaitable, Callable

from src.config.settings import settings

Result = tuple[bool, str]


async def _gemini() -> Result:
    from google import genai
    from google.genai import types

    options = types.HttpOptions(timeout=15_000)
    if settings.GEMINI_BACKEND == "vertex":
        client = genai.Client(vertexai=True, project=settings.GOOGLE_CLOUD_PROJECT,
                              location=settings.GOOGLE_CLOUD_LOCATION, http_options=options)
    else:
        if not settings.GEMINI_API_KEY:
            return False, "GEMINI_API_KEY is not set"
        client = genai.Client(api_key=settings.GEMINI_API_KEY, http_options=options)
    model = await client.aio.models.get(model=settings.GEMINI_MODEL)
    return True, f"{settings.GEMINI_BACKEND}: key accepted, model {model.name} available"


async def _supabase_db() -> Result:
    if not settings.supabase_configured:
        return False, "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set (local SQLite in dev)"
    from supabase import acreate_client

    client = await acreate_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
    for table in ("profiles", "scans", "scan_usage", "scan_feedback", "serving_memory"):
        await client.table(table).select("*", count="exact", head=True).execute()
    return True, "service-role key accepted; profiles, scans, scan_usage, feedback, serving tables reachable"


async def _bucket() -> Result:
    if not settings.supabase_configured:
        return False, "Supabase not configured"
    from supabase import acreate_client

    client = await acreate_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
    bucket = await client.storage.get_bucket(settings.STORAGE_BUCKET)
    if bucket.public:
        return False, f"bucket '{settings.STORAGE_BUCKET}' is PUBLIC: anyone with a link sees photos"
    return True, f"bucket '{settings.STORAGE_BUCKET}' exists and is private"


async def _auth_secret() -> Result:
    if len(settings.AUTH_SECRET_KEY) < 32:
        return False, "AUTH_SECRET_KEY missing or shorter than 32 characters"
    return True, "AUTH_SECRET_KEY set (32+ characters)"


async def _prescriptions() -> Result:
    if not settings.PRESCRIPTION_AI_ENABLED:
        return True, "prescription reading is off"
    if settings.prescription_ai_allowed:
        return True, "prescription reading is on, on Vertex or a confirmed paid tier"
    return False, ("PRESCRIPTION_AI_ENABLED=true but the tier isn't confirmed paid: the endpoint "
                   "refuses (set GEMINI_BACKEND=vertex or GEMINI_PAID_TIER_CONFIRMED=true)")


CHECKS: list[tuple[str, Callable[[], Awaitable[Result]]]] = [
    ("Auth secret", _auth_secret),
    ("Gemini", _gemini),
    ("Supabase database", _supabase_db),
    ("Photo bucket", _bucket),
    ("Prescriptions", _prescriptions),
]


async def run() -> int:
    print(f"APP_ENV={settings.APP_ENV}")
    failed = 0
    for name, check in CHECKS:
        try:
            ok, detail = await check()
        except Exception as exc:  # report the failure type, never its text (may echo a key)
            code = getattr(exc, "code", None)
            ok, detail = False, f"{type(exc).__name__}{f' (HTTP {code})' if code else ''}"
        failed += not ok
        print(f"{'OK  ' if ok else 'FAIL'}  {name}: {detail}")
    if settings.is_production:
        for problem in settings.config_problems():
            failed += 1
            print(f"FAIL  Production config: {problem}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(run()))
