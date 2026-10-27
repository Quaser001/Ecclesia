"""CalFit domain models — all data structures for the scan pipeline."""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Optional
from uuid import uuid4

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------


class RiskLevel(str, Enum):
    UNKNOWN = "unknown"
    LOW = "low"
    MODERATE = "moderate"
    HIGH = "high"
    CRITICAL = "critical"


class SuitabilityStatus(str, Enum):
    EXCELLENT = "excellent"   # 80-100
    GOOD = "good"             # 60-79
    FAIR = "fair"             # 40-59
    POOR = "poor"             # 20-39
    NOT_SUITABLE = "not_suitable"  # 0-19


class DietaryPreference(str, Enum):
    VEGETARIAN = "vegetarian"
    VEGAN = "vegan"
    GLUTEN_FREE = "gluten_free"
    DAIRY_FREE = "dairy_free"
    HALAL = "halal"
    KOSHER = "kosher"
    LOW_CARB = "low_carb"
    KETO = "keto"
    PALEO = "paleo"


class HealthCondition(str, Enum):
    DIABETES_TYPE_1 = "diabetes_type_1"
    DIABETES_TYPE_2 = "diabetes_type_2"
    PREDIABETES = "prediabetes"
    HYPERTENSION = "hypertension"
    HIGH_CHOLESTEROL = "high_cholesterol"
    CELIAC_DISEASE = "celiac_disease"
    IBS = "ibs"
    KIDNEY_DISEASE = "kidney_disease"
    HEART_DISEASE = "heart_disease"
    OBESITY = "obesity"
    LACTOSE_INTOLERANCE = "lactose_intolerance"
    ANAEMIA = "anaemia"


class HealthGoal(str, Enum):
    WEIGHT_LOSS = "weight_loss"
    MUSCLE_GAIN = "muscle_gain"
    MAINTAIN_WEIGHT = "maintain_weight"
    IMPROVE_ENERGY = "improve_energy"
    IMPROVE_DIGESTION = "improve_digestion"
    REDUCE_INFLAMMATION = "reduce_inflammation"
    MANAGE_BLOOD_SUGAR = "manage_blood_sugar"
    HEART_HEALTH = "heart_health"


class FindingSeverity(str, Enum):
    INFO = "info"
    WARNING = "warning"
    ALERT = "alert"
    CRITICAL = "critical"


class EvidenceTier(str, Enum):
    """How well-established a rule's threshold is.

    strong      — clinical consensus, authoritative source (WHO, FSSAI, ICMR-NIN, AHA).
    sensitivity — a personal, not medical, dietary signal the user asked to track.
    """

    STRONG = "strong"
    SENSITIVITY = "sensitivity"


# ---------------------------------------------------------------------------
# User Profile
# ---------------------------------------------------------------------------


def _utc_now() -> datetime:
    """Timezone-aware UTC now (datetime.utcnow() is deprecated in 3.12)."""
    return datetime.now(timezone.utc)


class UserProfile(BaseModel):
    """Represents a user's health profile for personalized evaluation."""

    user_id: str = Field(default_factory=lambda: str(uuid4()))
    name: Optional[str] = None
    health_conditions: list[HealthCondition] = Field(default_factory=list)
    allergies: list[str] = Field(default_factory=list)
    dietary_preferences: list[DietaryPreference] = Field(default_factory=list)
    health_goals: list[HealthGoal] = Field(default_factory=list)
    # Non-medical, user-toggled sensitivities. Flagged as `sensitivity` tier,
    # never surfaced as a medical warning.
    avoid_caffeine: bool = False
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class UserProfileRequest(BaseModel):
    """Request body for creating/updating a user profile."""

    name: Optional[str] = None
    health_conditions: list[HealthCondition] = Field(default_factory=list)
    allergies: list[str] = Field(default_factory=list)
    dietary_preferences: list[DietaryPreference] = Field(default_factory=list)
    health_goals: list[HealthGoal] = Field(default_factory=list)
    avoid_caffeine: bool = False


# ---------------------------------------------------------------------------
# Product Observation (from Gemini analysis)
# ---------------------------------------------------------------------------


class NutritionInfo(BaseModel):
    """Nutritional values extracted from a product package."""

    serving_size_g: Optional[float] = None
    calories_kcal: Optional[float] = None
    total_fat_g: Optional[float] = None
    saturated_fat_g: Optional[float] = None
    trans_fat_g: Optional[float] = None
    cholesterol_mg: Optional[float] = None
    sodium_mg: Optional[float] = None
    total_carbs_g: Optional[float] = None
    dietary_fiber_g: Optional[float] = None
    sugars_g: Optional[float] = None
    added_sugars_g: Optional[float] = None
    protein_g: Optional[float] = None
    # Micronutrients — currently used for anaemia rules.
    iron_mg: Optional[float] = None
    vitamin_c_mg: Optional[float] = None

    # Confidence flags: True if value was clearly read, False if estimated/unclear
    sodium_confidence: bool = False
    sugar_confidence: bool = False
    fat_confidence: bool = False


class ProductObservation(BaseModel):
    """Structured information extracted from a product photo by Gemini."""

    # Identification
    brand: Optional[str] = None
    product_name: Optional[str] = None
    category: Optional[str] = None  # e.g. "instant noodles", "biscuits", "juice"

    # Ingredients & nutrition
    ingredients: list[str] = Field(default_factory=list)
    nutrition: NutritionInfo = Field(default_factory=NutritionInfo)
    allergens_declared: list[str] = Field(default_factory=list)
    # "May contain X" or "manufactured in a facility that processes Y" — treated
    # as a warning for an allergic user, never a clear pass.
    may_contain: list[str] = Field(default_factory=list)
    visible_claims: list[str] = Field(default_factory=list)

    # Extraction metadata
    extraction_confidence: float = Field(
        ge=0.0,
        le=1.0,
        default=0.0,
        description="Overall confidence in extraction quality (0-1).",
    )
    insufficient_data: bool = Field(
        default=False,
        description="True if the image lacks enough information for a meaningful assessment.",
    )
    extraction_notes: Optional[str] = None  # What was unclear or missing


# ---------------------------------------------------------------------------
# Knowledge
# ---------------------------------------------------------------------------


class KnowledgeEntry(BaseModel):
    """A knowledge base entry about ingredients, nutrients, or conditions."""

    id: Optional[int] = None
    topic: str
    content: str
    relevance_tags: list[str] = Field(default_factory=list)
    source: str = "calfit_knowledge_base"


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------


class ScanFinding(BaseModel):
    """A single finding triggered by a scoring rule."""

    rule_id: str
    severity: FindingSeverity
    title: str
    detail: str
    nutrient_or_ingredient: Optional[str] = None
    score_impact: int = Field(default=0, description="Negative score points this rule subtracts.")
    # Short citation of the authority the threshold comes from (e.g. "WHO sodium
    # guidance 2012", "FSSAI labelling rules 2020"). Shown to the user so they
    # can see why a product was flagged.
    source: Optional[str] = None
    # strong = clinical consensus; sensitivity = user-toggled, not medical.
    evidence_tier: EvidenceTier = EvidenceTier.STRONG


class ScoreResult(BaseModel):
    """Deterministic scoring output — computed entirely in code, not by LLM."""

    score: int = Field(ge=0, le=100)
    suitability: SuitabilityStatus
    risk_level: RiskLevel
    findings: list[ScanFinding] = Field(default_factory=list)
    rules_applied: list[str] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Alternatives
# ---------------------------------------------------------------------------


class Alternative(BaseModel):
    """A product alternative or alternative criteria suggestion."""

    type: str = Field(description="'product' if a real product, 'criteria' if search guidance.")
    name: Optional[str] = None          # Product name if type == 'product'
    brand: Optional[str] = None
    reason: str                          # Why this is a better fit
    criteria: Optional[str] = None      # Guidance text if no real product available
    verified: bool = False              # True only for products from knowledge base


# ---------------------------------------------------------------------------
# Scan (full pipeline result)
# ---------------------------------------------------------------------------


class ScanResponse(BaseModel):
    """Complete response from a product scan — returned to Flutter."""

    scan_id: str = Field(default_factory=lambda: str(uuid4()))
    user_id: str
    scanned_at: datetime = Field(default_factory=_utc_now)

    product: ProductObservation
    score_result: ScoreResult
    explanation: str
    alternatives: list[Alternative] = Field(default_factory=list)

    image_url: Optional[str] = None
    insufficient_data: bool = False
    pipeline_message: Optional[str] = None


class ScanHistoryItem(BaseModel):
    """Lightweight scan record for history listing."""

    scan_id: str
    user_id: str
    scanned_at: datetime
    product_name: Optional[str] = None
    brand: Optional[str] = None
    score: int
    suitability: SuitabilityStatus
    image_url: Optional[str] = None
