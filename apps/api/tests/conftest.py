"""Shared test fixtures for CalFit backend tests."""

from __future__ import annotations

import pytest

from src.domain.models import (
    DietaryPreference,
    HealthCondition,
    HealthGoal,
    NutritionInfo,
    ProductObservation,
    UserProfile,
)


# ---------------------------------------------------------------------------
# Isolation: never touch the live Supabase project from tests
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def _no_live_supabase(monkeypatch):
    """`.env` may hold real Supabase keys; tests must use the local providers.

    Without this, every endpoint test that does not override the provider
    writes profiles, scans and photos into the production database.
    """
    from src.config.settings import settings

    monkeypatch.setattr(settings, "SUPABASE_URL", "")
    monkeypatch.setattr(settings, "SUPABASE_SERVICE_ROLE_KEY", "")
    # Same for the AI settings: tests must pass identically with no .env (CI).
    # A test that needs Gemini injects a fake via get_gemini_provider.
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "")
    monkeypatch.setattr(settings, "GEMINI_BACKEND", "developer_api")
    monkeypatch.setattr(settings, "PRESCRIPTION_AI_ENABLED", False)
    monkeypatch.setattr(settings, "GEMINI_PAID_TIER_CONFIRMED", False)
    monkeypatch.setattr(settings, "APP_ENV", "development")
    # Never call Open Food Facts from tests (flaky, and it spends the shared
    # rate limit). Tests that need a lookup inject a fake via get_food_lookup.
    monkeypatch.setattr(settings, "FOOD_LOOKUP_ENABLED", False)


# ---------------------------------------------------------------------------
# Auth fixtures
# ---------------------------------------------------------------------------

TEST_AUTH_SECRET = "test-secret-" + "x" * 40


@pytest.fixture
def auth_secret(monkeypatch):
    """Configure a signing secret for the duration of one test."""
    from src.config.settings import settings

    monkeypatch.setattr(settings, "AUTH_SECRET_KEY", TEST_AUTH_SECRET)
    return TEST_AUTH_SECRET


@pytest.fixture
def make_device(auth_secret):
    """Mint a fresh (user_id, Authorization-headers) pair, like a new install."""
    from src.services.device_tokens import issue_token

    def _make() -> tuple[str, dict[str, str]]:
        user_id, token = issue_token(auth_secret)
        return user_id, {"Authorization": f"Bearer {token}"}

    return _make


# ---------------------------------------------------------------------------
# Profile fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def healthy_profile() -> UserProfile:
    """A user with no health conditions or dietary restrictions."""
    return UserProfile(
        user_id="test-healthy",
        name="Healthy User",
        health_conditions=[],
        allergies=[],
        dietary_preferences=[],
        health_goals=[HealthGoal.MAINTAIN_WEIGHT],
    )


@pytest.fixture
def diabetic_profile() -> UserProfile:
    """A user with type 2 diabetes and blood sugar management goal."""
    return UserProfile(
        user_id="test-diabetic",
        name="Diabetic User",
        health_conditions=[HealthCondition.DIABETES_TYPE_2],
        allergies=[],
        dietary_preferences=[],
        health_goals=[HealthGoal.MANAGE_BLOOD_SUGAR],
    )


@pytest.fixture
def hypertensive_profile() -> UserProfile:
    """A user with hypertension and heart health goal."""
    return UserProfile(
        user_id="test-hypertensive",
        name="Hypertensive User",
        health_conditions=[HealthCondition.HYPERTENSION],
        allergies=[],
        dietary_preferences=[],
        health_goals=[HealthGoal.HEART_HEALTH],
    )


@pytest.fixture
def allergic_profile() -> UserProfile:
    """A user with peanut and tree nut allergies."""
    return UserProfile(
        user_id="test-allergic",
        name="Allergic User",
        health_conditions=[],
        allergies=["peanuts", "tree nuts"],
        dietary_preferences=[],
        health_goals=[],
    )


@pytest.fixture
def vegan_profile() -> UserProfile:
    """A user with a vegan dietary preference."""
    return UserProfile(
        user_id="test-vegan",
        name="Vegan User",
        health_conditions=[],
        allergies=[],
        dietary_preferences=[DietaryPreference.VEGAN],
        health_goals=[HealthGoal.MAINTAIN_WEIGHT],
    )


@pytest.fixture
def combined_conditions_profile() -> UserProfile:
    """A user with multiple conditions — worst case for a high-sodium, high-sugar product."""
    return UserProfile(
        user_id="test-combined",
        name="Combined Conditions User",
        health_conditions=[HealthCondition.DIABETES_TYPE_2, HealthCondition.HYPERTENSION],
        allergies=["peanuts"],
        dietary_preferences=[],
        health_goals=[HealthGoal.MANAGE_BLOOD_SUGAR, HealthGoal.HEART_HEALTH],
    )


# ---------------------------------------------------------------------------
# Product fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def instant_noodle_product() -> ProductObservation:
    """A high-sodium, high-carb instant noodle product — bad for hypertension and diabetes."""
    return ProductObservation(
        brand="TestBrand",
        product_name="Spicy Instant Noodles",
        category="instant noodles",
        ingredients=[
            "wheat flour", "palm oil", "salt", "monosodium glutamate",
            "chilli powder", "garlic powder", "sugar",
        ],
        nutrition=NutritionInfo(
            serving_size_g=85,
            calories_kcal=380,
            total_fat_g=14,
            saturated_fat_g=6,
            trans_fat_g=0,
            sodium_mg=1400,
            total_carbs_g=52,
            sugars_g=4,
            protein_g=8,
            sodium_confidence=True,
            sugar_confidence=True,
            fat_confidence=True,
        ),
        allergens_declared=["wheat"],
        extraction_confidence=0.9,
    )


@pytest.fixture
def sugary_drink_product() -> ProductObservation:
    """A sugary juice drink — high sugar, bad for diabetes."""
    return ProductObservation(
        brand="TestBrand",
        product_name="Tropical Fruit Drink",
        category="juice drink",
        ingredients=["water", "high fructose corn syrup", "fruit concentrate", "citric acid"],
        nutrition=NutritionInfo(
            serving_size_g=250,
            calories_kcal=120,
            sodium_mg=30,
            sugars_g=28,
            total_carbs_g=30,
            protein_g=0,
            sodium_confidence=True,
            sugar_confidence=True,
        ),
        allergens_declared=[],
        extraction_confidence=0.85,
    )


@pytest.fixture
def peanut_product() -> ProductObservation:
    """A product containing peanuts — critical for allergic users."""
    return ProductObservation(
        brand="TestBrand",
        product_name="Peanut Butter Cookies",
        category="biscuits",
        ingredients=["wheat flour", "peanuts", "sugar", "butter", "eggs"],
        nutrition=NutritionInfo(
            serving_size_g=30,
            calories_kcal=150,
            sodium_mg=100,
            sugars_g=8,
            total_fat_g=8,
            saturated_fat_g=3,
            sugar_confidence=True,
            sodium_confidence=True,
            fat_confidence=True,
        ),
        allergens_declared=["peanuts", "wheat", "eggs", "milk"],
        extraction_confidence=0.95,
    )


@pytest.fixture
def healthy_product() -> ProductObservation:
    """A simple, low-concern product — oats."""
    return ProductObservation(
        brand="TestBrand",
        product_name="Plain Rolled Oats",
        category="breakfast cereals",
        ingredients=["oats"],
        nutrition=NutritionInfo(
            serving_size_g=40,
            calories_kcal=150,
            total_fat_g=2.5,
            saturated_fat_g=0.5,
            sodium_mg=5,
            total_carbs_g=27,
            dietary_fiber_g=4,
            sugars_g=1,
            protein_g=5,
            sodium_confidence=True,
            sugar_confidence=True,
            fat_confidence=True,
        ),
        allergens_declared=["oats"],
        extraction_confidence=0.98,
    )


@pytest.fixture
def vegan_violation_product() -> ProductObservation:
    """A product with animal products — bad for vegans."""
    return ProductObservation(
        brand="TestBrand",
        product_name="Chicken Flavour Crisps",
        category="crisps",
        ingredients=["potato", "sunflower oil", "chicken powder", "milk powder", "salt"],
        nutrition=NutritionInfo(
            serving_size_g=25,
            calories_kcal=130,
            sodium_mg=200,
            total_fat_g=7,
            saturated_fat_g=1,
            sugars_g=0.5,
            sodium_confidence=True,
        ),
        allergens_declared=["milk"],
        extraction_confidence=0.9,
    )
