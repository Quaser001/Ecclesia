"""Device registration: the backend mints a signed identity for each install."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from src.config.dependencies import TokenIssueLimiterDep
from src.config.settings import settings
from src.services.device_tokens import AuthNotConfigured, issue_token
from src.services.rate_limit import RateLimitExceeded

router = APIRouter(prefix="/auth", tags=["auth"])


class DeviceTokenResponse(BaseModel):
    user_id: str
    token: str


@router.post("/device", response_model=DeviceTokenResponse, summary="Register this device")
async def register_device(request: Request, limiter: TokenIssueLimiterDep = None) -> DeviceTokenResponse:
    """Mint a new anonymous identity + bearer token for this install.

    Capped per client IP per UTC day so identities (and the per-user scan
    quota attached to them) cannot be minted without limit.
    """
    client_ip = request.client.host if request.client else ""
    try:
        await limiter.check_and_increment(client_ip)
    except RateLimitExceeded:
        raise HTTPException(status_code=429, detail="Too many registrations from this network today.")
    try:
        user_id, token = issue_token(settings.AUTH_SECRET_KEY)
    except AuthNotConfigured:
        raise HTTPException(status_code=503, detail="Authentication is not configured on the server.")
    return DeviceTokenResponse(user_id=user_id, token=token)
