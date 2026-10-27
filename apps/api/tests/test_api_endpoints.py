"""Tests for API endpoints, profile validation, scans, and regression checks."""

import io
import pytest
from httpx import ASGITransport, AsyncClient
from unittest.mock import AsyncMock

from src.main import app
from src.domain.models import (
    DietaryPreference,
    HealthCondition,
    NutritionInfo,
    ProductObservation,
    RiskLevel,
    ScoreResult,
    SuitabilityStatus,
    UserProfile,
)
from src.providers.interfaces import GeminiProvider, StorageProvider, SupabaseProvider
from src.config.dependencies import get_gemini_provider, get_supabase_provider, get_storage_provider
from src.providers.local_db_provider import LocalDBProvider, LocalStorageProvider
from src.repositories.product_repository import ProductRepository, FoodProduct
from src.services.scoring_service import ScoringService
from src.services.alternative_service import AlternativeService


class MockGemini(GeminiProvider):
    async def analyze_photo(self, photo_bytes: bytes, mime_type: str = "image/jpeg") -> ProductObservation:
        return ProductObservation(
            brand="Maggi",
            product_name="2-Minute Masala Noodles",
            category="instant noodles",
            ingredients=["Wheat flour", "Palm oil", "Salt", "Hydrolysed peanut protein", "Flavor enhancer (635)"],
            nutrition=NutritionInfo(
                calories_kcal=312.0,
                total_fat_g=13.0,
                saturated_fat_g=6.0,
                sodium_mg=860.0,
                total_carbs_g=42.0,
                sugars_g=1.5,
                protein_g=6.5,
            ),
            allergens_declared=["wheat", "peanut"],
            extraction_confidence=0.95,
        )

    async def analyze_prescription(self, photo_bytes: bytes, mime_type: str = "image/jpeg"):
        raise NotImplementedError("not used by these tests")

    async def generate_explanation(self, messages: list[dict[str, str]]) -> str:
        return "This product contains elevated sodium and saturated fat, which may conflict with cardiovascular guidelines."


@pytest.fixture
def mock_gemini():
    return MockGemini()


@pytest.mark.asyncio
async def test_health_endpoints():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        r1 = await client.get("/health")
        assert r1.status_code == 200
        assert r1.json() == {"status": "ok", "service": "CalFit API"}

        r2 = await client.get("/api/v1/health")
        assert r2.status_code == 200
        assert r2.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_profile_lifecycle(make_device):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        user_id, headers = make_device()

        # GET empty initial profile
        r_get = await client.get("/api/v1/profile", headers=headers)
        assert r_get.status_code == 200
        data = r_get.json()
        assert data["user_id"] == user_id
        assert data["health_conditions"] == []

        # PUT updated profile
        payload = {
            "name": "Test User",
            "health_conditions": ["hypertension", "diabetes_type_2"],
            "allergies": ["peanut"],
            "dietary_preferences": ["vegetarian"],
            "health_goals": ["weight_loss"],
        }
        r_put = await client.put("/api/v1/profile", json=payload, headers=headers)
        assert r_put.status_code == 200
        saved = r_put.json()
        assert saved["name"] == "Test User"
        assert "hypertension" in saved["health_conditions"]
        assert "peanut" in saved["allergies"]

        # Re-fetch
        r_get2 = await client.get("/api/v1/profile", headers=headers)
        assert r_get2.status_code == 200
        assert r_get2.json()["name"] == "Test User"


@pytest.mark.asyncio
async def test_product_matching_and_alternatives():
    repo = ProductRepository()
    
    # Save candidate noodles
    cand = FoodProduct(
        code="cand-001",
        product_name="Whole Wheat Millet Noodles",
        brand="HealthyBowl",
        categories=["instant noodles"],
        ingredients=["Whole wheat flour", "Foxtail millet", "Salt"],
        nutrition=NutritionInfo(
            calories_kcal=240.0,
            total_fat_g=2.0,
            saturated_fat_g=0.5,
            sodium_mg=220.0,
            sugars_g=0.5,
        ),
    )
    repo.save_product(cand)

    obs = ProductObservation(
        brand="UnhealthyNoodles",
        product_name="Fried Super Salty Noodles",
        category="instant noodles",
        ingredients=["Wheat flour", "Palm oil", "Salt"],
        nutrition=NutritionInfo(
            calories_kcal=450.0,
            total_fat_g=18.0,
            saturated_fat_g=8.0,
            sodium_mg=1100.0,
            sugars_g=2.0,
        ),
    )

    profile = UserProfile(
        user_id="user-bp",
        health_conditions=[HealthCondition.HYPERTENSION],
    )

    scoring = ScoringService()
    orig_score = scoring.score(obs, profile)
    assert orig_score.score < 80

    alt_svc = AlternativeService()
    alts = alt_svc.find(obs, profile, orig_score, product_repo=repo)
    assert len(alts) > 0
    assert any(a.verified and a.type == "product" and a.name for a in alts)


def test_critical_regression_same_food_different_profiles():
    """
    CRITICAL REGRESSION:
    SAME PRODUCT + DIFFERENT PROFILES = DIFFERENT PERSONALIZED RESULTS
    """
    scoring = ScoringService()

    product = ProductObservation(
        brand="ChocoBar",
        product_name="Sweet Peanut Chocolate Bar",
        category="chocolates",
        ingredients=["Sugar", "Peanuts", "Milk solids", "Cocoa butter"],
        allergens_declared=["peanut", "milk"],
        nutrition=NutritionInfo(
            calories_kcal=520.0,
            sugars_g=34.0,
            saturated_fat_g=12.0,
            sodium_mg=120.0,
        ),
    )

    # Profile A: Healthy individual with no constraints
    profile_a = UserProfile(user_id="user-a", name="Healthy Alex")
    result_a = scoring.score(product, profile_a)

    # Profile B: Individual with Diabetes and Peanut Allergy
    profile_b = UserProfile(
        user_id="user-b",
        name="Allergic Diabetic Bob",
        health_conditions=[HealthCondition.DIABETES_TYPE_2],
        allergies=["peanut"],
    )
    result_b = scoring.score(product, profile_b)

    # Assert distinct outcomes
    assert result_a.score > result_b.score
    assert result_b.score <= 35  # Heavy penalties for severe allergy and very high sugar
    assert any(f.rule_id.startswith("RULE-001A") or f.rule_id.startswith("RULE-001B") for f in result_b.findings)
    assert any(f.rule_id == "RULE-003A-SUGAR-EXTREME" for f in result_b.findings)


@pytest.mark.asyncio
async def test_full_scan_pipeline_mocked_gemini(mock_gemini, make_device):
    app.dependency_overrides[get_gemini_provider] = lambda: mock_gemini
    user_id, headers = make_device()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        image_bytes = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00"
        files = {"photo": ("maggi.jpg", io.BytesIO(image_bytes), "image/jpeg")}

        response = await client.post("/api/v1/scans", files=files, headers=headers)
        assert response.status_code == 200
        scan_result = response.json()

        assert scan_result["user_id"] == user_id
        assert scan_result["product"]["brand"] == "Maggi"
        assert "score_result" in scan_result
        assert "explanation" in scan_result
        assert isinstance(scan_result["alternatives"], list)

        # Check scan history now has the record
        history_resp = await client.get("/api/v1/scans/history", headers=headers)
        assert history_resp.status_code == 200
        history_items = history_resp.json()
        assert len(history_items) >= 1
        assert history_items[0]["brand"] == "Maggi"

    app.dependency_overrides.clear()
