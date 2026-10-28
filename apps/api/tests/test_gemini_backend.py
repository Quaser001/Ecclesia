"""Choosing where Gemini runs: AI Studio key, or Vertex AI in an Indian region."""

from __future__ import annotations

import pytest

from src.config import dependencies
from src.config.settings import settings
from src.providers import gemini_provider


class _FakeClient:
    def __init__(self, **kwargs):
        self.kwargs = kwargs


@pytest.fixture
def fake_sdk(monkeypatch):
    monkeypatch.setattr(gemini_provider.genai, "Client", _FakeClient)


def _without_timeout(kwargs):
    """Every client gets the per-call timeout; the rest is what differs by backend."""
    assert kwargs["http_options"].timeout == settings.GEMINI_TIMEOUT_SECONDS * 1000
    return {k: v for k, v in kwargs.items() if k != "http_options"}


def _configure(monkeypatch, **values):
    for key, value in values.items():
        monkeypatch.setattr(settings, key, value)


def test_vertex_uses_the_regional_endpoint_and_no_key(monkeypatch, fake_sdk):
    _configure(monkeypatch, GEMINI_BACKEND="vertex", GOOGLE_CLOUD_PROJECT="calfit-prod",
               GOOGLE_CLOUD_LOCATION="asia-south1", GEMINI_API_KEY="should-not-be-used")
    provider = dependencies.get_gemini_provider()
    assert _without_timeout(provider._client.kwargs) == {
        "vertexai": True, "project": "calfit-prod", "location": "asia-south1"}
    assert provider._key == ""


def test_vertex_without_a_project_fails_loudly(monkeypatch, fake_sdk):
    _configure(monkeypatch, GEMINI_BACKEND="vertex", GOOGLE_CLOUD_PROJECT="")
    with pytest.raises(RuntimeError, match="GOOGLE_CLOUD_PROJECT"):
        dependencies.get_gemini_provider()


@pytest.mark.parametrize("location", ["global", "", " Global "])
def test_vertex_refuses_the_global_endpoint(monkeypatch, fake_sdk, location):
    # A global endpoint may process the request anywhere: no residency promise.
    _configure(monkeypatch, GEMINI_BACKEND="vertex", GOOGLE_CLOUD_PROJECT="calfit-prod",
               GOOGLE_CLOUD_LOCATION=location)
    with pytest.raises(RuntimeError, match="regional"):
        dependencies.get_gemini_provider()


def test_developer_api_still_uses_the_key(monkeypatch, fake_sdk):
    _configure(monkeypatch, GEMINI_BACKEND="developer_api", GEMINI_API_KEY="k-123")
    provider = dependencies.get_gemini_provider()
    assert _without_timeout(provider._client.kwargs) == {"api_key": "k-123"}


def test_developer_api_without_a_key_fails_loudly(monkeypatch, fake_sdk):
    _configure(monkeypatch, GEMINI_BACKEND="developer_api", GEMINI_API_KEY="")
    with pytest.raises(RuntimeError, match="GEMINI_API_KEY"):
        dependencies.get_gemini_provider()
