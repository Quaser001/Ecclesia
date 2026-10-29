"""Scans API endpoints."""

from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timezone
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Any, Literal

from fastapi import APIRouter, File, Form, Header, HTTPException, Query, Response, UploadFile

from src.config.auth import CurrentUserDep
from src.services.consent import ConsentedUserDep
from src.config.dependencies import (
    FoodLookupDep,
    GeminiDep,
    ScanLimiterDep,
    StorageDep,
    SupabaseDep,
)
from src.config.settings import settings
from src.domain.identity import Identification, IdStatus, ProductOption
from src.domain.models import (
    ProductObservation,
    ScanFeedbackRequest,
    ScanHistoryItem,
    ScanResponse,
    ScanStats,
    ScoreResult,
    ServingSizeRequest,
    SuitabilityStatus,
)
from src.orchestration.scan_graph import ScanOrchestrator
from src.providers.food_lookup import LookupUnavailable
from src.repositories.product_repository import shared_product_repository
from src.services.identification import observation_from_product
from src.services.image_bytes import sniff_image_type, strip_jpeg_location
from src.services.rate_limit import RateLimitExceeded
from src.services.serving_memory import product_key

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/scans", tags=["scans"])

# Supported image MIME types
_ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}


@router.post("", response_model=ScanResponse, summary="Submit a product photo for analysis")
async def create_scan(
    user_id: ConsentedUserDep,
    photo: UploadFile = File(..., description="Product photo file"),
    content_length: int | None = Header(default=None, alias="content-length"),
    gemini: GeminiDep = None,
    supabase: SupabaseDep = None,
    storage: StorageDep = None,
    limiter: ScanLimiterDep = None,
    lookup: FoodLookupDep = None,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> ScanResponse:
    """
    Submit a product photo and receive a personalized evaluation.

    `Idempotency-Key` (a UUID the app makes per photo) makes a retry safe: if
    a scan with that id was already saved, it is returned as it is, without
    running or counting again. Otherwise it becomes the new scan's id.

    The response includes:
    - Extracted product information
    - A personalized score (0-100)
    - Key health findings
    - A short explanation
    - Better-fit alternatives or criteria
    """
    scan_id = _scan_id_from(idempotency_key)
    if (done := await _already_saved(scan_id, user_id, supabase, storage)) is not None:
        return done
    charge = _Charge(limiter, user_id)
    async with charge.refunded_on_failure():
        photo_bytes, content_type = await _accept_photo(photo, content_length, charge)

        orchestrator = ScanOrchestrator(
            gemini=gemini,
            supabase=supabase,
            storage=storage,
            storage_bucket=settings.STORAGE_BUCKET,
            lookup=lookup,
        )

        return await orchestrator.run(
            user_id=user_id,
            photo_bytes=photo_bytes,
            mime_type=content_type,
            scan_id=scan_id,
        )


def _scan_id_from(idempotency_key: str | None) -> str | None:
    """The app's key as a scan id: a UUID or nothing, never free text."""
    if idempotency_key is None:
        return None
    try:
        return str(uuid.UUID(idempotency_key.strip()))
    except ValueError:
        raise HTTPException(status_code=422, detail="Idempotency-Key must be a UUID.")


async def _already_saved(scan_id: str | None, user_id: str, supabase: Any,
                         storage: Any) -> ScanResponse | None:
    """The caller's saved scan with this id, if a retry is repeating it."""
    if scan_id is None:
        return None
    row = await supabase.get_scan(user_id, scan_id)  # someone else's id reads as None
    if row is None:
        return None
    response = await _stored_scan_response(row, user_id, storage)
    response.saved = True
    return response


class _Charge:
    """One scan against the daily cap, given back if the scan then fails.

    Taken before the work (so concurrent scans can't both slip under the cap).
    Given back when the scan fails on our side or upstream (5xx, timeout) or
    is rejected after charging (a file that isn't a photo, a product not
    found). A scan that ran and found too little on the label still counts:
    it cost a real AI call.
    """

    def __init__(self, limiter: Any, user_id: str) -> None:
        self.limiter, self.user_id, self.taken = limiter, user_id, False

    async def take(self) -> None:
        await self.limiter.check_and_increment(self.user_id)
        self.taken = True

    @asynccontextmanager
    async def refunded_on_failure(self) -> AsyncIterator[None]:
        try:
            yield
        except BaseException as exc:
            over_cap = isinstance(exc, HTTPException) and exc.status_code == 429
            if self.taken and not over_cap:
                await self.limiter.give_back(self.user_id)
            raise


async def _accept_photo(
    photo: UploadFile, content_length: int | None, charge: "_Charge"
) -> tuple[bytes, str]:
    """Size, type and daily-limit checks shared by every endpoint taking a photo."""
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
        await charge.take()
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
    return checked_photo(photo_bytes)


def checked_photo(photo_bytes: bytes) -> tuple[bytes, str]:
    """The photo's real type from its bytes, and a JPEG without its GPS position."""
    actual_type = sniff_image_type(photo_bytes)
    if actual_type is None:
        raise HTTPException(status_code=422, detail="That file isn't a photo we can read.")
    if actual_type == "image/jpeg":
        photo_bytes = strip_jpeg_location(photo_bytes)
    return photo_bytes, actual_type


PHOTO_LINK_SECONDS = 3600


def photo_path(image_url: str | None, user_id: str, bucket: str) -> str | None:
    """The object path inside the bucket for one of this user's own photos.

    Stored links are either Supabase object URLs or local `/uploads/...`
    paths. Anything outside `scans/<user_id>/` returns None, so a link is
    never signed for someone else's file.
    """
    if not image_url:
        return None
    marker = f"/{bucket}/"
    if marker not in image_url:
        return None
    path = image_url.split(marker, 1)[1].split("?", 1)[0]
    if ".." in path.split("/") or not path.startswith(f"scans/{user_id}/"):
        return None
    return path


async def _sign_photos(rows: list[dict[str, Any]], user_id: str, storage: Any) -> None:
    """Swap stored photo links for short-lived signed ones, in place."""
    paths = {id(r): photo_path(r.get("image_url"), user_id, settings.STORAGE_BUCKET) for r in rows}
    wanted = [p for p in paths.values() if p]
    signed = await storage.signed_urls(settings.STORAGE_BUCKET, wanted, PHOTO_LINK_SECONDS) if wanted else {}
    for r in rows:
        p = paths[id(r)]
        r["image_url"] = signed.get(p) if p else None


@router.get("/history", response_model=list[ScanHistoryItem], summary="Get scan history")
async def get_scan_history(
    user_id: CurrentUserDep,
    limit: int = Query(default=20, ge=1, le=100),
    before: datetime | None = Query(
        default=None, description="Page backwards: only scans older than this time."
    ),
    supabase: SupabaseDep = None,
    storage: StorageDep = None,
) -> list[ScanHistoryItem]:
    """Scan history, newest first. Photos come as links valid for an hour."""
    cursor = before.astimezone(timezone.utc).isoformat() if before else None
    rows = await supabase.get_scan_history(user_id, limit=limit, before=cursor)
    await _sign_photos(rows, user_id, storage)
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
            logger.warning("Skipping malformed scan history row: %s", type(exc).__name__)
    return items


@router.get("/stats", response_model=ScanStats, summary="Totals over all your scans")
async def get_scan_stats(
    user_id: CurrentUserDep,
    supabase: SupabaseDep = None,
) -> ScanStats:
    """How many scans, their average score and the best one, across all of them."""
    return ScanStats(**await supabase.get_scan_stats(user_id))


def _as_json(value: Any) -> Any:
    """JSON columns come back as text from some providers and dicts from others."""
    return json.loads(value) if isinstance(value, str) else value


# Declared after /history so "history" is never captured as a scan id.
@router.get("/{scan_id}", response_model=ScanResponse, summary="Get one past scan")
async def get_scan(
    scan_id: str,
    user_id: CurrentUserDep,
    supabase: SupabaseDep = None,
    storage: StorageDep = None,
) -> ScanResponse:
    """The full stored result of one of the caller's scans.

    A scan that does not exist and a scan that belongs to someone else both
    return 404, so ids cannot be probed. Alternatives are not stored with a
    scan, so the list is empty.
    """
    row = await supabase.get_scan(user_id, scan_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Scan not found.")
    return await _stored_scan_response(row, user_id, storage)


async def _stored_scan_response(row: dict[str, Any], user_id: str, storage: Any) -> ScanResponse:
    await _sign_photos([row], user_id, storage)
    try:
        return ScanResponse(
            scan_id=row["scan_id"],
            user_id=row["user_id"],
            scanned_at=row["scanned_at"],
            product=ProductObservation.model_validate(_as_json(row.get("product_json")) or {}),
            score_result=ScoreResult.model_validate(_as_json(row["score_json"])),
            explanation=row.get("explanation") or "",
            alternatives=[],
            image_url=row.get("image_url"),
        )
    except (ValueError, KeyError, TypeError) as exc:
        logger.error("Stored scan %s could not be read: %s", row.get("scan_id"), type(exc).__name__)
        raise HTTPException(status_code=500, detail="This scan could not be loaded.")


@router.post(
    "/{scan_id}/feedback",
    status_code=204,
    summary="Say whether a scan result was right",
)
async def give_scan_feedback(
    scan_id: str,
    body: ScanFeedbackRequest,
    user_id: CurrentUserDep,
    supabase: SupabaseDep = None,
) -> Response:
    """Record the caller's "was this right?" answer for one of their scans.

    Someone else's scan is a 404, like a missing one. Answering again
    replaces the earlier answer. Issues only count when the answer is "no".
    """
    if await supabase.get_scan(user_id, scan_id) is None:
        raise HTTPException(status_code=404, detail="Scan not found.")
    issues = [] if body.accurate else [i.value for i in body.issues]
    await supabase.save_scan_feedback(user_id, scan_id, body.accurate, issues)
    return Response(status_code=204)


@router.post("/confirm", response_model=ScanResponse,
             summary="Score the product the user confirmed or picked")
async def confirm_scan(
    user_id: ConsentedUserDep,
    photo: UploadFile = File(..., description="The same product photo"),
    product_code: str = Form(..., max_length=32),
    source: Literal["calfit_database", "open_food_facts"] = Form(...),
    content_length: int | None = Header(default=None, alias="content-length"),
    gemini: GeminiDep = None,
    supabase: SupabaseDep = None,
    storage: StorageDep = None,
    limiter: ScanLimiterDep = None,
    lookup: FoodLookupDep = None,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> ScanResponse:
    """After "Is this it?" or "Which one is it?" on a front-of-pack scan.

    `Idempotency-Key` works as on POST /scans.

    Only the product's code comes from the app; its data is fetched again here,
    so the app can never supply nutrition. The photo is sent again rather than
    kept from the first request, so nothing is stored for scans the user never
    confirmed. Counts against the daily limit like any scan (it runs the
    explanation model).
    """
    scan_id = _scan_id_from(idempotency_key)
    if (done := await _already_saved(scan_id, user_id, supabase, storage)) is not None:
        return done
    charge = _Charge(limiter, user_id)
    async with charge.refunded_on_failure():
        return await _confirm(charge, photo, content_length, product_code, source,
                              gemini, supabase, storage, lookup, user_id, scan_id)


async def _confirm(charge: _Charge, photo: UploadFile, content_length: int | None,
                   product_code: str, source: str, gemini: Any, supabase: Any,
                   storage: Any, lookup: Any, user_id: str,
                   scan_id: str | None) -> ScanResponse:
    photo_bytes, content_type = await _accept_photo(photo, content_length, charge)
    product = None
    if source == "calfit_database":
        product = shared_product_repository().find_by_code(product_code)
    elif lookup is not None:
        try:
            product = await lookup.get(product_code)
        except LookupUnavailable:
            raise HTTPException(
                status_code=503,
                detail="The online product database isn't reachable right now. Try again shortly.",
            )
    if product is None:
        raise HTTPException(status_code=404, detail="That product wasn't found.")

    option = ProductOption(code=product.code, source=source, name=product.product_name,
                           brand=product.brand, quantity=product.quantity,
                           image_url=product.image_url)
    orchestrator = ScanOrchestrator(gemini=gemini, supabase=supabase, storage=storage,
                                    storage_bucket=settings.STORAGE_BUCKET, lookup=lookup)
    return await orchestrator.run_with_product(
        user_id=user_id,
        product=observation_from_product(product, source),
        identification=Identification(status=IdStatus.CONFIDENT, options=[option],
                                      chosen=option),
        photo_bytes=photo_bytes,
        mime_type=content_type,
        scan_id=scan_id,
    )


@router.put("/{scan_id}/serving", status_code=204,
            summary="Remember the serving size for this scan's product")
async def remember_serving_size(
    scan_id: str,
    body: ServingSizeRequest,
    user_id: CurrentUserDep,
    supabase: SupabaseDep = None,
) -> Response:
    """For a scan whose label had no serving size. The answer is used the next
    time this user scans the same product; this scan's score does not change."""
    row = await supabase.get_scan(user_id, scan_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Scan not found.")
    product = ProductObservation.model_validate(_as_json(row.get("product_json")) or {})
    key = product_key(product.brand or row.get("brand"),
                      product.product_name or row.get("product_name"))
    if key is None:
        raise HTTPException(status_code=422,
                            detail="This scan has no product name to remember a serving size by.")
    await supabase.save_serving_memory(user_id, key, body.serving_size_g, body.label_basis)
    return Response(status_code=204)


@router.delete("/{scan_id}", status_code=204, summary="Delete one of your scans")
async def delete_scan(
    scan_id: str,
    user_id: CurrentUserDep,
    supabase: SupabaseDep = None,
    storage: StorageDep = None,
) -> Response:
    """Remove a scan, its feedback and its photo ("Not this product?", or a
    scan the user doesn't want). Someone else's scan is a 404."""
    row = await supabase.get_scan(user_id, scan_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Scan not found.")
    await supabase.delete_scan(user_id, scan_id)
    path = photo_path(row.get("image_url"), user_id, settings.STORAGE_BUCKET)
    if path:
        try:
            await storage.delete_object(settings.STORAGE_BUCKET, path)
        except Exception as exc:
            logger.warning("Scan photo not deleted: %s", type(exc).__name__)
    return Response(status_code=204)
