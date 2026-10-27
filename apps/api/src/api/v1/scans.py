"""Scans API endpoints."""

from __future__ import annotations

import logging

from fastapi import APIRouter, File, Header, HTTPException, Query, UploadFile

from src.config.auth import CurrentUserDep
from src.config.dependencies import GeminiDep, ScanLimiterDep, StorageDep, SupabaseDep
from src.config.settings import settings
from src.domain.models import ScanHistoryItem, ScanResponse, SuitabilityStatus
from src.orchestration.scan_graph import ScanOrchestrator
from src.services.rate_limit import RateLimitExceeded

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/scans", tags=["scans"])

# Supported image MIME types
_ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}


@router.post("", response_model=ScanResponse, summary="Submit a product photo for analysis")
async def create_scan(
    user_id: CurrentUserDep,
    photo: UploadFile = File(..., description="Product photo file"),
    content_length: int | None = Header(default=None, alias="content-length"),
    gemini: GeminiDep = None,
    supabase: SupabaseDep = None,
    storage: StorageDep = None,
    limiter: ScanLimiterDep = None,
) -> ScanResponse:
    """
    Submit a product photo and receive a personalized evaluation.

    The response includes:
    - Extracted product information
    - A personalized score (0-100)
    - Key health findings
    - A short explanation
    - Better-fit alternatives or criteria
    """
    # Reject oversized uploads BEFORE buffering them into memory.
    if content_length is not None and content_length > settings.MAX_SCAN_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Image too large. Maximum size is {settings.MAX_SCAN_UPLOAD_BYTES // (1024 * 1024)} MB.",
        )

    content_type = photo.content_type or "image/jpeg"
    if content_type not in _ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"Unsupported file type: {content_type}. Accepted: {sorted(_ALLOWED_MIME_TYPES)}",
        )

    # Per-user daily cap. We check BEFORE reading the photo so a user who is
    # already over quota is rejected cheaply.
    try:
        await limiter.check_and_increment(user_id)
    except RateLimitExceeded as exc:
        raise HTTPException(
            status_code=429,
            detail=(
                f"You've reached today's scan limit ({exc.cap}). "
                "The limit resets at UTC midnight."
            ),
        )

    photo_bytes = await photo.read()
    if not photo_bytes:
        raise HTTPException(status_code=422, detail="Uploaded file is empty.")

    # Belt-and-suspenders: enforce the limit again on the actually-read bytes
    # in case the client lied about content-length.
    if len(photo_bytes) > settings.MAX_SCAN_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"Image too large. Maximum size is {settings.MAX_SCAN_UPLOAD_BYTES // (1024 * 1024)} MB.",
        )

    orchestrator = ScanOrchestrator(
        gemini=gemini,
        supabase=supabase,
        storage=storage,
        storage_bucket=settings.STORAGE_BUCKET,
    )

    return await orchestrator.run(
        user_id=user_id,
        photo_bytes=photo_bytes,
        mime_type=content_type,
    )


@router.get("/history", response_model=list[ScanHistoryItem], summary="Get scan history")
async def get_scan_history(
    user_id: CurrentUserDep,
    limit: int = Query(default=20, ge=1, le=100),
    supabase: SupabaseDep = None,
) -> list[ScanHistoryItem]:
    """Retrieve the scan history for a user, most recent first."""
    rows = await supabase.get_scan_history(user_id, limit=limit)
    items: list[ScanHistoryItem] = []
    for row in rows:
        try:
            items.append(
                ScanHistoryItem(
                    scan_id=row["scan_id"],
                    user_id=row["user_id"],
                    scanned_at=row["scanned_at"],
                    product_name=row.get("product_name"),
                    brand=row.get("brand"),
                    score=row.get("score", 0),
                    suitability=SuitabilityStatus(row.get("suitability", "unknown")),
                    image_url=row.get("image_url"),
                )
            )
        except Exception as exc:
            logger.warning("Skipping malformed scan history row: %s", exc)
    return items
