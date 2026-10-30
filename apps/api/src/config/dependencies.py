"""
Dependency injection configuration for CalFit.

Wires real providers when credentials are present.
Raises clear errors when credentials are missing — never silently substitutes fake data.

Providers are built once per process and reused (keyed on the settings they
were built from, so tests that change settings still get a matching one).
A Supabase or Gemini client per request means a new HTTP connection pool per
request that is never closed. ADR-006.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from typing import Annotated, Any, TypeVar

from fastapi import Depends, Header

from src.config.settings import settings
from src.providers.food_lookup import FoodLookupProvider
from src.providers.interfaces import GeminiProvider, StorageProvider, SupabaseProvider
from src.providers.payments import PaymentProvider
from src.services.rate_limit import (
    CounterStore,
    InMemoryStore,
    ScanLimiter,
    SupabaseCounterStore,
)

logger = logging.getLogger(__name__)

T = TypeVar("T")
_shared: dict[tuple[Any, ...], Any] = {}


def _shared_instance(key: tuple[Any, ...], build: Callable[[], T]) -> T:
    if key not in _shared:
        _shared[key] = build()
    return _shared[key]  # type: ignore[no-any-return]


def get_gemini_provider() -> GeminiProvider:
    """Return the real Gemini provider. Raises if it is not configured."""
    from src.providers.gemini_provider import GoogleGeminiProvider

    if settings.GEMINI_BACKEND == "vertex":
        if not settings.GOOGLE_CLOUD_PROJECT:
            raise RuntimeError(
                "GEMINI_BACKEND=vertex needs GOOGLE_CLOUD_PROJECT. "
                "See docs/AI_PROVIDER_OPTIONS.md."
            )
        # "global" lets Google process the request in any region, which
        # breaks the in-India promise. Refuse it rather than drift silently.
        if settings.GOOGLE_CLOUD_LOCATION.strip().lower() in ("", "global"):
            raise RuntimeError(
                "GEMINI_BACKEND=vertex needs a regional GOOGLE_CLOUD_LOCATION "
                "(asia-south1 for Mumbai), not 'global'."
            )
        location = settings.GOOGLE_CLOUD_LOCATION.strip()
        return _shared_instance(
            ("gemini-vertex", settings.GOOGLE_CLOUD_PROJECT, location, settings.GEMINI_MODEL),
            lambda: GoogleGeminiProvider(
                model=settings.GEMINI_MODEL,
                vertex_project=settings.GOOGLE_CLOUD_PROJECT,
                vertex_location=location,
            ),
        )

    if not settings.GEMINI_API_KEY:
        raise RuntimeError(
            "GEMINI_API_KEY is not set. Add it to your .env file. "
            "See .env.example for required variables."
        )
    return _shared_instance(
        ("gemini-api", settings.GEMINI_API_KEY, settings.GEMINI_MODEL),
        lambda: GoogleGeminiProvider(api_key=settings.GEMINI_API_KEY, model=settings.GEMINI_MODEL),
    )


_food_lookup: FoodLookupProvider | None = None


def get_food_lookup() -> FoodLookupProvider | None:
    """The online product lookup, or None when switched off.

    One instance per process, so its cache is shared by every request (Open
    Food Facts allows about 10 searches a minute per IP).
    """
    global _food_lookup
    if not settings.FOOD_LOOKUP_ENABLED:
        return None
    if _food_lookup is None:
        from src.providers.food_lookup import OpenFoodFactsLookup
        _food_lookup = OpenFoodFactsLookup(settings.FOOD_LOOKUP_USER_AGENT)
    return _food_lookup


def _local_fallback(what: str) -> None:
    """The laptop fallbacks are for development only: production refuses them.

    On Cloud Run a local SQLite file is per instance and wiped on restart, so a
    user's allergies would silently disappear between requests.
    """
    if settings.is_production:
        raise RuntimeError(
            f"{what}: Supabase is not configured and APP_ENV=production. "
            "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY."
        )


def get_supabase_provider() -> SupabaseProvider:
    """Return the Supabase provider if configured, else the local SQLite provider (dev only)."""
    if settings.supabase_configured:
        from src.providers.supabase_provider import SupabaseDBProvider
        return _shared_instance(
            ("supabase-db", settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY),
            lambda: SupabaseDBProvider(
                url=settings.SUPABASE_URL, key=settings.SUPABASE_SERVICE_ROLE_KEY),
        )
    _local_fallback("Database")
    from src.providers.local_db_provider import LocalDBProvider
    return _shared_instance(("local-db",), LocalDBProvider)


def get_storage_provider() -> StorageProvider:
    """Return Supabase Storage if configured, else local file storage (dev only)."""
    if settings.supabase_configured:
        from src.providers.supabase_provider import SupabaseStorageProvider
        return _shared_instance(
            ("supabase-storage", settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY),
            lambda: SupabaseStorageProvider(
                url=settings.SUPABASE_URL, key=settings.SUPABASE_SERVICE_ROLE_KEY),
        )
    _local_fallback("Photo storage")
    from src.providers.local_db_provider import LocalStorageProvider
    return _shared_instance(("local-storage",), LocalStorageProvider)


# Process-local counter for local runs with no database configured. The STORE
# (not a whole limiter) is module-level so the count persists across requests
# even though the per-request cap now varies with the caller's tier. A new
# store per request would reset the count every time and the cap would never bite.
_scan_counter_store = InMemoryStore()


def _scan_store(supabase: SupabaseProvider) -> CounterStore:
    if settings.supabase_configured:
        return SupabaseCounterStore(supabase)
    _local_fallback("Daily scan limit")
    return _scan_counter_store


async def get_scan_limiter(
    authorization: str | None = Header(default=None),
    supabase: SupabaseProvider = Depends(get_supabase_provider),
) -> ScanLimiter:
    """The daily scan cap for this caller.

    Billing off (the default): everyone gets the free DAILY_SCAN_CAP and we make
    no entitlement read, so the production scan path is unchanged and gains no
    extra round trip. Billing on: the cap is the caller's tier cap, read from
    their entitlement. A failed entitlement read raises (ADR-006) — we never
    quietly fall back to the free cap and wrongly throttle a paying user.

    The Postgres counter is used whenever Supabase is configured (it survives
    restarts and is shared across Cloud Run instances); the process-local store
    is the dev/test fallback.
    """
    store = _scan_store(supabase)
    if not settings.BILLING_ENABLED:
        return ScanLimiter(cap=settings.DAILY_SCAN_CAP, store=store)
    from src.config.auth import get_current_user_id
    from src.services.entitlements import EntitlementService, cap_for_tier

    user_id = get_current_user_id(authorization)
    tier = await EntitlementService(supabase).tier_for(user_id)
    return ScanLimiter(cap=cap_for_tier(tier), store=store)


def get_payment_provider() -> PaymentProvider:
    """The Dodo payment provider, built from settings (one per process).

    Built even when keys are empty; the billing routes guard on BILLING_ENABLED
    and the specific key/secret they need, so an unconfigured provider never
    silently does anything.
    """
    from src.providers.dodo_provider import DodoPaymentProvider

    return _shared_instance(
        ("dodo", settings.DODO_MODE, settings.DODO_API_KEY, settings.DODO_WEBHOOK_SECRET),
        lambda: DodoPaymentProvider(
            api_key=settings.DODO_API_KEY,
            webhook_secret=settings.DODO_WEBHOOK_SECRET,
            base_url=settings.dodo_base_url,
        ),
    )


_token_issue_limiter = ScanLimiter(
    cap=settings.DEVICE_TOKEN_DAILY_CAP_PER_IP, store=InMemoryStore()
)


def get_token_issue_limiter() -> ScanLimiter:
    """Per-client-IP cap on minting device identities (process-local)."""
    return _token_issue_limiter


_client_error_limiter = ScanLimiter(
    cap=settings.CLIENT_ERROR_DAILY_CAP_PER_IP, store=InMemoryStore()
)


def get_client_error_limiter() -> ScanLimiter:
    """Per-client-IP cap on crash reports (process-local).

    Process-local is fine here: the point is to stop one IP from writing an
    unbounded number of retained log lines through an unauthenticated route,
    not to count exactly across instances.
    """
    return _client_error_limiter


_prescription_memory_limiter = ScanLimiter(
    cap=settings.PRESCRIPTION_DAILY_CAP, store=InMemoryStore()
)


def get_prescription_limiter(
    supabase: SupabaseProvider = Depends(get_supabase_provider),
) -> ScanLimiter:
    """Separate, much smaller daily cap for prescription reads."""
    if settings.supabase_configured:
        return ScanLimiter(
            cap=settings.PRESCRIPTION_DAILY_CAP,
            store=SupabaseCounterStore(supabase),
        )
    _local_fallback("Prescription limit")
    return _prescription_memory_limiter


# Annotated dependency types for endpoint injection
PrescriptionLimiterDep = Annotated[ScanLimiter, Depends(get_prescription_limiter)]
TokenIssueLimiterDep = Annotated[ScanLimiter, Depends(get_token_issue_limiter)]
ClientErrorLimiterDep = Annotated[ScanLimiter, Depends(get_client_error_limiter)]
GeminiDep = Annotated[GeminiProvider, Depends(get_gemini_provider)]
FoodLookupDep = Annotated[FoodLookupProvider | None, Depends(get_food_lookup)]
SupabaseDep = Annotated[SupabaseProvider, Depends(get_supabase_provider)]
StorageDep = Annotated[StorageProvider, Depends(get_storage_provider)]
ScanLimiterDep = Annotated[ScanLimiter, Depends(get_scan_limiter)]
PaymentProviderDep = Annotated[PaymentProvider, Depends(get_payment_provider)]
