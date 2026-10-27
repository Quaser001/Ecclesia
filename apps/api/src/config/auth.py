"""Request authentication: derive the caller's user_id from a signed device token."""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Header, HTTPException

from src.config.settings import settings
from src.services.device_tokens import AuthNotConfigured, InvalidToken, verify_token


def get_current_user_id(authorization: str | None = Header(default=None)) -> str:
    """Return the user_id from `Authorization: Bearer <token>`.

    The id comes only from the verified token — never from query or form
    fields — so one device cannot read or write another device's data.
    """
    unauthorized = HTTPException(
        status_code=401,
        detail="Missing or invalid credentials.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if not authorization:
        raise unauthorized
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise unauthorized
    try:
        return verify_token(settings.AUTH_SECRET_KEY, token.strip())
    except InvalidToken:
        raise unauthorized
    except AuthNotConfigured:
        raise HTTPException(status_code=503, detail="Authentication is not configured on the server.")


CurrentUserDep = Annotated[str, Depends(get_current_user_id)]
