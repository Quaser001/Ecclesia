"""
Signed per-device tokens.

The backend mints an opaque identity for each installed app and signs it with
a server-side secret. The client presents the token on every request; the
server derives `user_id` from the verified token and never trusts a
client-supplied one. There is no account system yet, so a token is a bearer
credential for one anonymous device.

Format: ``v1.<user_id>.<hex HMAC-SHA256 of "v1.<user_id>">``
"""

from __future__ import annotations

import hashlib
import hmac
import re
import uuid

_VERSION = "v1"
_USER_ID_RE = re.compile(r"^[0-9a-f]{32}$")
MIN_SECRET_LENGTH = 32


class InvalidToken(Exception):
    """Raised when a token is malformed or its signature does not verify."""


class AuthNotConfigured(Exception):
    """Raised when the server has no usable signing secret."""


def _sign(secret: str, user_id: str) -> str:
    if len(secret) < MIN_SECRET_LENGTH:
        raise AuthNotConfigured(
            f"AUTH_SECRET_KEY must be set to at least {MIN_SECRET_LENGTH} characters."
        )
    msg = f"{_VERSION}.{user_id}".encode()
    return hmac.new(secret.encode(), msg, hashlib.sha256).hexdigest()


def issue_token(secret: str) -> tuple[str, str]:
    """Create a fresh server-generated identity. Returns (user_id, token)."""
    user_id = uuid.uuid4().hex
    return user_id, f"{_VERSION}.{user_id}.{_sign(secret, user_id)}"


def verify_token(secret: str, token: str) -> str:
    """Return the user_id inside a valid token, else raise InvalidToken."""
    parts = token.split(".")
    if len(parts) != 3 or parts[0] != _VERSION or not _USER_ID_RE.match(parts[1]):
        raise InvalidToken("malformed token")
    expected = _sign(secret, parts[1])
    if not hmac.compare_digest(expected, parts[2]):
        raise InvalidToken("bad signature")
    return parts[1]
