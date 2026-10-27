"""The REAL Gemini provider must not leak prescription content to logs.

The endpoint tests use a fake provider, so they cannot see what
GoogleGeminiProvider logs. These tests drive the real class with a stubbed
SDK client.
"""

from __future__ import annotations

import logging
from types import SimpleNamespace

import pytest

from src.providers.gemini_provider import GoogleGeminiProvider, _parse_prescription_json

SECRET = "Metformin"


def _provider(generate):
    p = GoogleGeminiProvider(api_key="test-key", model="m1")
    p._client = SimpleNamespace(aio=SimpleNamespace(models=SimpleNamespace(generate_content=generate)))
    return p


def _reply(text):
    return SimpleNamespace(text=text)


async def test_truncated_json_is_not_logged_and_is_a_failure_not_a_verdict(caplog):
    caplog.set_level(logging.DEBUG)

    async def generate(**kwargs):
        return _reply('{"is_prescription": true, "diagnoses": ["Type 2 diabetes"], "medicines": ["Metformin')

    with pytest.raises(ValueError):
        await _provider(generate).analyze_prescription(b"x")
    assert SECRET.lower() not in caplog.text.lower()
    assert "type 2 diabetes" not in caplog.text.lower()


async def test_exception_text_is_not_logged(caplog):
    caplog.set_level(logging.DEBUG)

    async def generate(**kwargs):
        raise RuntimeError(f"bad response mentioning {SECRET}")

    with pytest.raises(RuntimeError):
        await _provider(generate).analyze_prescription(b"x")
    assert SECRET.lower() not in caplog.text.lower()


async def test_unparseable_first_model_falls_through_to_the_next(caplog):
    caplog.set_level(logging.DEBUG)
    calls = []

    async def generate(**kwargs):
        calls.append(kwargs["model"])
        if len(calls) == 1:
            return _reply("sorry, I cannot help with that")
        return _reply('{"is_prescription": true, "diagnoses": ["HTN"], "medicines": [], "allergies": []}')

    obs = await _provider(generate).analyze_prescription(b"x")
    assert len(calls) == 2
    assert obs.diagnoses == ["HTN"]
    assert obs.is_prescription is True


def test_parser_returns_none_on_garbage_and_never_logs(caplog):
    caplog.set_level(logging.DEBUG)
    assert _parse_prescription_json("not json Metformin") is None
    assert _parse_prescription_json("[1, 2]") is None
    assert _parse_prescription_json('```json\n{"is_prescription": true}\n```') == {
        "is_prescription": True
    }
    assert SECRET.lower() not in caplog.text.lower()
