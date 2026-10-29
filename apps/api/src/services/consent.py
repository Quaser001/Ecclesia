"""Consent to the privacy notice: recorded on the server, checked before
health data is processed (DPDP Act s.6, s.6(10); Rules r.3).

The app shows the notice (Rule 3: what is collected, why, how to withdraw,
use your rights and complain) with an "I am 18 or older" box and "I agree".
Agreeing stores a row. Routes that save a health profile, score a scan or
read a prescription depend on `require_consent`, which answers 428 until
there is a live row for the current notice version.

Changing what the notice says means a new version here and in the app
(`lib/features/consent/consent_notice.dart`): everyone is asked again.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, HTTPException

from src.config.auth import CurrentUserDep
from src.config.dependencies import SupabaseDep

CONSENT_NOTICE_VERSION = "2026-10-29"

CONSENT_REQUIRED = HTTPException(
    status_code=428,
    detail="Agree to the privacy notice in the app before using this.",
)


async def require_consent(user_id: CurrentUserDep, supabase: SupabaseDep = None) -> str:
    """The caller's user_id, once they have agreed to the current notice."""
    if not await supabase.has_consent(user_id, CONSENT_NOTICE_VERSION):
        raise CONSENT_REQUIRED
    return user_id


ConsentedUserDep = Annotated[str, Depends(require_consent)]
