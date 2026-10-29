"""A scan finishes inside the app's wait, or stops cleanly (readiness review B)."""

from __future__ import annotations

import asyncio

import pytest

from src.config.settings import settings
from src.domain.models import NutritionInfo, ProductObservation, UserProfile
from src.orchestration.scan_graph import ScanOrchestrator
from src.providers.interfaces import ServiceUnavailable
from src.providers.local_db_provider import LocalDBProvider
from tests.test_scan_data_gate import _Repo, _Storage

LABEL = ProductObservation(
    product_name="Biscuit", brand="X", extraction_confidence=0.95, ingredients=["wheat", "sugar"],
    nutrition=NutritionInfo(serving_size_g=30, calories_kcal=144, total_fat_g=6, total_carbs_g=20.4,
                            sugars_g=7.5, protein_g=2.1, sodium_mg=105, sugar_confidence=True),
)


class _SlowGemini:
    def __init__(self, photo_delay=0.0, explain_delay=0.0):
        self.photo_delay, self.explain_delay = photo_delay, explain_delay
        self.explained = False

    async def analyze_photo(self, photo_bytes, mime_type="image/jpeg"):
        await asyncio.sleep(self.photo_delay)
        return LABEL

    async def generate_explanation(self, messages):
        self.explained = True
        await asyncio.sleep(self.explain_delay)
        return "An AI explanation."


async def _scan(tmp_path, gemini):
    db = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    await db.upsert_profile(UserProfile(user_id="u"))
    orch = ScanOrchestrator(gemini=gemini, supabase=db, storage=_Storage(), product_repo=_Repo(None))
    return db, await orch.run(user_id="u", photo_bytes=b"img")


async def test_a_scan_past_the_deadline_is_a_503_and_nothing_is_saved(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "SCAN_DEADLINE_SECONDS", 0.3)
    db = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    await db.upsert_profile(UserProfile(user_id="u"))
    orch = ScanOrchestrator(gemini=_SlowGemini(photo_delay=2), supabase=db, storage=_Storage(),
                            product_repo=_Repo(None))
    with pytest.raises(ServiceUnavailable, match="too long"):
        await orch.run(user_id="u", photo_bytes=b"img")
    assert await db.get_scan_history("u") == []


async def test_little_time_left_skips_the_ai_explanation(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "SCAN_DEADLINE_SECONDS", 5.0)
    monkeypatch.setattr(settings, "EXPLANATION_MIN_SECONDS", 4.9)  # reading used the slack
    gemini = _SlowGemini(photo_delay=0.2)
    _, result = await _scan(tmp_path, gemini)
    assert gemini.explained is False
    assert result.explanation and "AI" not in result.explanation  # the rule summary
    assert not result.insufficient_data


async def test_a_slow_explanation_falls_back_and_the_scan_still_lands(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "SCAN_DEADLINE_SECONDS", 6.0)
    monkeypatch.setattr(settings, "EXPLANATION_MIN_SECONDS", 1.0)
    db, result = await _scan(tmp_path, _SlowGemini(explain_delay=30))
    assert result.explanation and "AI" not in result.explanation
    assert result.saved and len(await db.get_scan_history("u")) == 1


async def test_a_quick_scan_keeps_the_ai_explanation(tmp_path):
    gemini = _SlowGemini()
    _, result = await _scan(tmp_path, gemini)
    assert gemini.explained is True and result.explanation
