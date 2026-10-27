"""Tests must never reach the live Supabase project, whatever .env contains."""

from __future__ import annotations

from src.config.dependencies import get_storage_provider, get_supabase_provider
from src.config.settings import settings
from src.providers.local_db_provider import LocalDBProvider, LocalStorageProvider


def test_supabase_credentials_are_blanked_for_tests():
    assert settings.SUPABASE_URL == ""
    assert settings.SUPABASE_SERVICE_ROLE_KEY == ""


def test_default_providers_are_local_in_tests():
    assert isinstance(get_supabase_provider(), LocalDBProvider)
    assert isinstance(get_storage_provider(), LocalStorageProvider)
