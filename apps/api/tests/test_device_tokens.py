"""Unit tests for signed device tokens."""

from __future__ import annotations

import pytest

from src.services.device_tokens import (
    AuthNotConfigured,
    InvalidToken,
    issue_token,
    verify_token,
)

SECRET = "s" * 40


def test_round_trip_returns_the_same_user_id():
    user_id, token = issue_token(SECRET)
    assert verify_token(SECRET, token) == user_id


def test_each_issued_identity_is_unique():
    assert issue_token(SECRET)[0] != issue_token(SECRET)[0]


def test_tampered_user_id_is_rejected():
    _, token = issue_token(SECRET)
    version, _, sig = token.split(".")
    forged = f"{version}.{'0' * 32}.{sig}"
    with pytest.raises(InvalidToken):
        verify_token(SECRET, forged)


def test_tampered_signature_is_rejected():
    _, token = issue_token(SECRET)
    flipped = token[:-1] + ("0" if token[-1] != "0" else "1")
    with pytest.raises(InvalidToken):
        verify_token(SECRET, flipped)


def test_token_signed_with_another_secret_is_rejected():
    _, token = issue_token("a" * 40)
    with pytest.raises(InvalidToken):
        verify_token("b" * 40, token)


@pytest.mark.parametrize(
    "bad",
    ["", "garbage", "v1.abc", "v2." + "a" * 32 + ".sig", "v1.../etc.sig", "v1." + "A" * 32 + ".sig"],
)
def test_malformed_tokens_are_rejected(bad):
    with pytest.raises(InvalidToken):
        verify_token(SECRET, bad)


def test_short_secret_is_refused_not_silently_accepted():
    with pytest.raises(AuthNotConfigured):
        issue_token("short")
    with pytest.raises(AuthNotConfigured):
        issue_token("")
