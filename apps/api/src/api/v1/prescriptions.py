"""Prescription → profile suggestions.

Privacy contract: the photo and everything read from it live in memory for the
length of this request. They are never passed to storage, never saved, never
added to scan history, and never logged. The server only *suggests*; adding to
the profile is the user's explicit confirmation through PUT /profile.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, File, Header, HTTPException, UploadFile

from src.api.v1.scans import checked_photo
from src.config.dependencies import GeminiDep, PrescriptionLimiterDep, SupabaseDep
from src.config.settings import settings
from src.domain.models import UserProfile
from src.domain.prescription import PrescriptionSuggestions
from src.services.prescription_service import suggest_from_prescription
from src.services.rate_limit import RateLimitExceeded
from src.services.consent import ConsentedUserDep

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/profile", tags=["profile"])

_ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}


@router.post(
    "/prescription-suggestions",
    response_model=PrescriptionSuggestions,
    summary="Suggest profile entries from a prescription photo (nothing is stored)",
)
async def prescription_suggestions(
    user_id: ConsentedUserDep,
    photo: UploadFile = File(..., description="Photo of a prescription"),
    content_length: int | None = Header(default=None, alias="content-length"),
    gemini: GeminiDep = None,
    supabase: SupabaseDep = None,
    limiter: PrescriptionLimiterDep = None,
) -> PrescriptionSuggestions:
    # Prescriptions are health data: only on Vertex or a confirmed paid tier,
    # never the free tier, even if PRESCRIPTION_AI_ENABLED is switched on.
    if not settings.prescription_ai_allowed:
        raise HTTPException(
            status_code=503, detail="Prescription reading is not enabled on this server."
        )

    max_bytes = settings.MAX_SCAN_UPLOAD_BYTES
    too_large = HTTPException(
        status_code=413,
        detail=f"Image too large. Maximum size is {max_bytes // (1024 * 1024)} MB.",
    )
    if content_length is not None and content_length > max_bytes:
        raise too_large

    content_type = photo.content_type or "image/jpeg"
    if content_type not in _ALLOWED_MIME_TYPES:
        raise HTTPException(status_code=422, detail=f"Unsupported file type: {content_type}.")

    try:
        await limiter.check_and_increment(f"rx:{user_id}")
    except RateLimitExceeded as exc:
        raise HTTPException(
            status_code=429,
            detail=f"You've reached today's prescription limit ({exc.cap}). Try again tomorrow.",
        )

    photo_bytes = await photo.read()
    if not photo_bytes:
        raise HTTPException(status_code=422, detail="Uploaded file is empty.")
    if len(photo_bytes) > max_bytes:
        raise too_large
    photo_bytes, content_type = checked_photo(photo_bytes)

    try:
        observation = await gemini.analyze_prescription(photo_bytes, content_type)
    except Exception as exc:
        # Class name only: exception text could echo document content.
        logger.warning("prescription read failed user=%s error=%s", user_id, type(exc).__name__)
        raise HTTPException(
            status_code=502,
            detail="We couldn't read that prescription right now. Please try again.",
        )

    profile = await supabase.get_profile(user_id)
    result = suggest_from_prescription(observation, profile or UserProfile(user_id=user_id))
    logger.info(
        "prescription read user=%s conditions=%d allergies=%d",
        user_id,
        len(result.conditions),
        len(result.allergies),
    )
    return result
