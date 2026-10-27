"""Profile API endpoints."""

from __future__ import annotations

from fastapi import APIRouter

from src.config.auth import CurrentUserDep
from src.config.dependencies import SupabaseDep
from src.domain.models import UserProfile, UserProfileRequest

router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("", response_model=UserProfile, summary="Get user profile")
async def get_profile(
    user_id: CurrentUserDep,
    supabase: SupabaseDep = None,
) -> UserProfile:
    """Retrieve a user's health profile. Returns a default empty profile if not found."""
    profile = await supabase.get_profile(user_id)
    if profile is None:
        # Return a default profile for new users rather than 404
        return UserProfile(user_id=user_id)
    return profile


@router.put("", response_model=UserProfile, summary="Create or update user profile")
async def upsert_profile(
    user_id: CurrentUserDep,
    body: UserProfileRequest,
    supabase: SupabaseDep = None,
) -> UserProfile:
    """Create or update a user's health profile."""
    profile = UserProfile(
        user_id=user_id,
        name=body.name,
        health_conditions=body.health_conditions,
        allergies=body.allergies,
        dietary_preferences=body.dietary_preferences,
        health_goals=body.health_goals,
        avoid_caffeine=body.avoid_caffeine,
    )
    saved = await supabase.upsert_profile(profile)
    return saved
