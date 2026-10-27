"""A scan must not be lost because the device has no profile row yet.

`scans.user_id` has a foreign key to `profiles.user_id`. A fresh install has
no profile until the user opens the profile screen, so without a bootstrap
step the very first scan of every new user fails the foreign key on Postgres.
SQLite does not enforce foreign keys by default, which is why this never
showed up locally.
"""

from __future__ import annotations

from datetime import datetime, timezone

import pytest

from src.domain.models import (
    NutritionInfo,
    ProductObservation,
    RiskLevel,
    ScanResponse,
    ScoreResult,
    SuitabilityStatus,
)
from src.orchestration.scan_graph import ScanOrchestrator
from src.providers.local_db_provider import LocalDBProvider


@pytest.fixture()
def local_provider(tmp_path):
    return LocalDBProvider(db_path=str(tmp_path / "test.db"))


async def test_ensure_profile_creates_a_row(local_provider):
    assert await local_provider.get_profile("new-device") is None
    await local_provider.ensure_profile_exists("new-device")
    profile = await local_provider.get_profile("new-device")
    assert profile is not None
    assert profile.user_id == "new-device"
    assert profile.allergies == []


async def test_ensure_profile_is_idempotent(local_provider):
    await local_provider.ensure_profile_exists("d")
    await local_provider.ensure_profile_exists("d")
    assert (await local_provider.get_profile("d")) is not None


async def test_ensure_profile_does_not_overwrite_real_data(local_provider):
    """Called on every scan, so it must never clobber a filled-in profile."""
    from src.domain.models import UserProfile

    await local_provider.upsert_profile(
        UserProfile(user_id="d", name="Asef", allergies=["peanut"])
    )
    await local_provider.ensure_profile_exists("d")
    profile = await local_provider.get_profile("d")
    assert profile.name == "Asef"
    assert profile.allergies == ["peanut"]


def _response(user_id: str) -> ScanResponse:
    return ScanResponse(
        scan_id="s1",
        user_id=user_id,
        scanned_at=datetime.now(timezone.utc),
        product=ProductObservation(product_name="X", nutrition=NutritionInfo()),
        score_result=ScoreResult(
            score=90,
            suitability=SuitabilityStatus.EXCELLENT,
            risk_level=RiskLevel.LOW,
            findings=[],
            rules_applied=[],
        ),
        explanation="ok",
        alternatives=[],
        insufficient_data=False,
    )


class _RecordingProvider:
    """Records the order of calls so we can assert the bootstrap comes first."""

    def __init__(self) -> None:
        self.calls: list[str] = []

    async def ensure_profile_exists(self, user_id: str) -> None:
        self.calls.append("ensure_profile_exists")

    async def save_scan(self, scan_data: dict) -> str:
        self.calls.append("save_scan")
        return "s1"


async def test_profile_is_created_before_the_scan_is_saved():
    provider = _RecordingProvider()
    orchestrator = ScanOrchestrator(
        gemini=None, supabase=provider, storage=None, storage_bucket="b"
    )
    await orchestrator._persist_scan(_response("fresh-device"))
    assert provider.calls == ["ensure_profile_exists", "save_scan"], (
        "the profile row must exist before the scan insert, or the FK fails"
    )


async def test_local_scan_usage_counter_increments(local_provider):
    assert await local_provider.increment_scan_usage("u") == 1
    assert await local_provider.increment_scan_usage("u") == 2
    assert await local_provider.increment_scan_usage("other") == 1
