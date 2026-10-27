"""Profile API endpoints."""

from __future__ import annotations

from fastapi import APIRouter

from src.config.auth import CurrentUserDep
from src.config.dependencies import StorageDep, SupabaseDep
from src.config.settings import settings
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
        height_cm=body.height_cm,
        weight_kg=body.weight_kg,
        target_weight_kg=body.target_weight_kg,
        birth_year=body.birth_year,
        sex=body.sex,
        activity_level=body.activity_level,
    )
    saved = await supabase.upsert_profile(profile)
    return saved


@router.delete("", summary="Delete my data")
async def delete_my_data(
    user_id: CurrentUserDep,
    supabase: SupabaseDep = None,
    storage: StorageDep = None,
) -> dict[str, int]:
    """Delete the caller's scan photos, scans, usage counters and profile.

    Photos go first: if that fails the request errors and nothing else has
    been removed, so the user can simply try again.
    """
    photos = await storage.delete_folder(settings.STORAGE_BUCKET, f"scans/{user_id}")
    scans = await supabase.delete_user_data(user_id)
    return {"scans_deleted": scans, "photos_deleted": photos}
