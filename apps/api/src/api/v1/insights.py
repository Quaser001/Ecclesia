"""Insights endpoint: trends from the caller's own scans."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter

from src.config.auth import CurrentUserDep
from src.config.dependencies import SupabaseDep
from src.domain.insights import InsightsResponse
from src.services.insights_service import build_insights

router = APIRouter(prefix="/insights", tags=["insights"])


@router.get("", response_model=InsightsResponse, summary="Trends from your scans")
async def get_insights(
    user_id: CurrentUserDep,
    supabase: SupabaseDep = None,
) -> InsightsResponse:
    """Average score, weekly trend, suitability mix, most-flagged issues, and
    best and worst products, computed from the caller's last 500 scans."""
    rows = await supabase.get_scans_for_insights(user_id)
    profile = await supabase.get_profile(user_id)
    goals = profile.health_goals if profile else []
    return build_insights(rows, today=datetime.now(timezone.utc).date(), goals=goals)
