"""
Dependency injection configuration for CalFit.

Wires real providers when credentials are present.
Raises clear errors when credentials are missing — never silently substitutes fake data.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends

from src.config.settings import settings
from src.providers.interfaces import GeminiProvider, StorageProvider, SupabaseProvider
from src.services.rate_limit import InMemoryStore, ScanLimiter, SupabaseCounterStore


def get_gemini_provider() -> GeminiProvider:
    """Return the real Gemini provider. Raises if API key is not configured."""
    if not settings.GEMINI_API_KEY:
        raise RuntimeError(
            "GEMINI_API_KEY is not set. Add it to your .env file. "
            "See .env.example for required variables."
        )
    from src.providers.gemini_provider import GoogleGeminiProvider
    return GoogleGeminiProvider(
        api_key=settings.GEMINI_API_KEY,
        model=settings.GEMINI_MODEL,
    )


def get_supabase_provider() -> SupabaseProvider:
    """Return the Supabase provider if configured, else the local SQLite provider."""
    if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY:
        from src.providers.supabase_provider import SupabaseDBProvider
        return SupabaseDBProvider(
            url=settings.SUPABASE_URL,
            key=settings.SUPABASE_SERVICE_ROLE_KEY,
        )
    # Default to local SQLite database for local MVP
    from src.providers.local_db_provider import LocalDBProvider
    return LocalDBProvider()


def get_storage_provider() -> StorageProvider:
    """Return the Supabase Storage provider if configured, else local file storage."""
    if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY:
        from src.providers.supabase_provider import SupabaseStorageProvider
        return SupabaseStorageProvider(
            url=settings.SUPABASE_URL,
            key=settings.SUPABASE_SERVICE_ROLE_KEY,
        )
    # Default to local storage
    from src.providers.local_db_provider import LocalStorageProvider
    return LocalStorageProvider()


# Fallback limiter for local runs with no database configured. Its counter
# must live outside the per-request dependency so it counts across requests.
_in_memory_limiter = ScanLimiter(cap=settings.DAILY_SCAN_CAP, store=InMemoryStore())


def get_scan_limiter(
    supabase: SupabaseProvider = Depends(get_supabase_provider),
) -> ScanLimiter:
    """Prefer the database-backed counter whenever Supabase is configured.

    The in-memory counter resets on every restart and is not shared between
    Cloud Run instances, so on its own it would let a user take
    `cap * instances` scans a day. The Postgres counter has neither problem.
    """
    if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY:
        return ScanLimiter(
            cap=settings.DAILY_SCAN_CAP,
            store=SupabaseCounterStore(supabase),
        )
    return _in_memory_limiter


_token_issue_limiter = ScanLimiter(
    cap=settings.DEVICE_TOKEN_DAILY_CAP_PER_IP, store=InMemoryStore()
)


def get_token_issue_limiter() -> ScanLimiter:
    """Per-client-IP cap on minting device identities (process-local)."""
    return _token_issue_limiter


_prescription_memory_limiter = ScanLimiter(
    cap=settings.PRESCRIPTION_DAILY_CAP, store=InMemoryStore()
)


def get_prescription_limiter(
    supabase: SupabaseProvider = Depends(get_supabase_provider),
) -> ScanLimiter:
    """Separate, much smaller daily cap for prescription reads."""
    if settings.SUPABASE_URL and settings.SUPABASE_SERVICE_ROLE_KEY:
        return ScanLimiter(
            cap=settings.PRESCRIPTION_DAILY_CAP,
            store=SupabaseCounterStore(supabase),
        )
    return _prescription_memory_limiter


# Annotated dependency types for endpoint injection
PrescriptionLimiterDep = Annotated[ScanLimiter, Depends(get_prescription_limiter)]
TokenIssueLimiterDep = Annotated[ScanLimiter, Depends(get_token_issue_limiter)]
GeminiDep = Annotated[GeminiProvider, Depends(get_gemini_provider)]
SupabaseDep = Annotated[SupabaseProvider, Depends(get_supabase_provider)]
StorageDep = Annotated[StorageProvider, Depends(get_storage_provider)]
ScanLimiterDep = Annotated[ScanLimiter, Depends(get_scan_limiter)]
