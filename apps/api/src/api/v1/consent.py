"""The privacy notice: has this person agreed, and record that they do."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from src.config.auth import CurrentUserDep
from src.config.dependencies import SupabaseDep
from src.services.consent import CONSENT_NOTICE_VERSION

router = APIRouter(prefix="/consent", tags=["consent"])


class ConsentStatus(BaseModel):
    current_version: str
    agreed: bool


class ConsentRequest(BaseModel):
    # The version of the notice the app showed. Agreeing to an older text
    # isn't agreeing to what we do now.
    notice_version: str = Field(min_length=1, max_length=32)
    # The person ticked "I am 18 or older" (DPDP Act s.9: no child data
    # without verifiable parental consent, which CalFit doesn't collect).
    adult_confirmed: bool


class ConsentRecorded(BaseModel):
    notice_version: str
    agreed_at: datetime


@router.get("", response_model=ConsentStatus, summary="Has this person agreed to the current notice?")
async def get_consent(user_id: CurrentUserDep, supabase: SupabaseDep = None) -> ConsentStatus:
    return ConsentStatus(
        current_version=CONSENT_NOTICE_VERSION,
        agreed=await supabase.has_consent(user_id, CONSENT_NOTICE_VERSION),
    )


@router.post("", response_model=ConsentRecorded, status_code=201, summary="Agree to the notice")
async def give_consent(
    user_id: CurrentUserDep, body: ConsentRequest, supabase: SupabaseDep = None
) -> ConsentRecorded:
    if body.notice_version != CONSENT_NOTICE_VERSION:
        # The app showed an older notice: it needs updating first.
        raise HTTPException(status_code=409, detail="This notice is out of date. Update the app.")
    if not body.adult_confirmed:
        raise HTTPException(status_code=422, detail="CalFit is for adults (18+).")
    agreed_at = await supabase.record_consent(user_id, CONSENT_NOTICE_VERSION)
    return ConsentRecorded(notice_version=CONSENT_NOTICE_VERSION, agreed_at=agreed_at)
