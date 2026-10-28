"""CalFit domain models — all data structures for the scan pipeline."""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Literal, Optional
from uuid import uuid4

from pydantic import BaseModel, Field, computed_field, field_validator

from src.domain.identity import Identification
from src.domain.nutrient_levels import NutrientLevel, nutrient_levels
from src.services.body_metrics import bmi as _bmi, bmi_category as _bmi_category


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


class Sex(str, Enum):
    FEMALE = "female"
    MALE = "male"
    OTHER = "other"


class ActivityLevel(str, Enum):
    SEDENTARY = "sedentary"      # desk job, little exercise
    LIGHT = "light"              # light exercise 1-3 days a week
    MODERATE = "moderate"        # moderate exercise 3-5 days a week
    ACTIVE = "active"            # hard exercise 6-7 days a week
    VERY_ACTIVE = "very_active"  # physical job plus training


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
    # Body details: optional, stored exactly as entered; BMI is calculated.
    height_cm: Optional[float] = Field(default=None, ge=50, le=250)
    weight_kg: Optional[float] = Field(default=None, ge=15, le=350)
    target_weight_kg: Optional[float] = Field(default=None, ge=15, le=350)
    birth_year: Optional[int] = Field(default=None, ge=1900)
    sex: Optional[Sex] = None
    activity_level: Optional[ActivityLevel] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    @field_validator("birth_year")
    @classmethod
    def _birth_year_not_in_future(cls, v: Optional[int]) -> Optional[int]:
        if v is not None and v > datetime.now(timezone.utc).year:
            raise ValueError("birth_year cannot be in the future")
        return v

    @computed_field  # type: ignore[prop-decorator]
    @property
    def bmi(self) -> Optional[float]:
        return _bmi(self.height_cm, self.weight_kg)

    @computed_field  # type: ignore[prop-decorator]
    @property
    def bmi_category(self) -> Optional[str]:
        return _bmi_category(self.bmi)


class UserProfileRequest(BaseModel):
    """Request body for creating/updating a user profile."""

    name: Optional[str] = None
    health_conditions: list[HealthCondition] = Field(default_factory=list)
    allergies: list[str] = Field(default_factory=list)
    dietary_preferences: list[DietaryPreference] = Field(default_factory=list)
    health_goals: list[HealthGoal] = Field(default_factory=list)
    avoid_caffeine: bool = False
    height_cm: Optional[float] = Field(default=None, ge=50, le=250)
    weight_kg: Optional[float] = Field(default=None, ge=15, le=350)
    target_weight_kg: Optional[float] = Field(default=None, ge=15, le=350)
    birth_year: Optional[int] = Field(default=None, ge=1900)
    sex: Optional[Sex] = None
    activity_level: Optional[ActivityLevel] = None


# ---------------------------------------------------------------------------
# Product Observation (from Gemini analysis)
# ---------------------------------------------------------------------------


class NutritionInfo(BaseModel):
    """Nutritional values extracted from a product package."""

    serving_size_g: Optional[float] = None
    # "you" when the serving size came from the user's saved answer for this
    # product (see services/serving_memory.py); None when read from the label.
    serving_size_source: Optional[Literal["you"]] = None
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
    variant: Optional[str] = None       # flavour or variant as printed ("Rose", "Masala")
    net_quantity: Optional[str] = None  # as printed ("200 ml", "52 g")
    mrp: Optional[str] = None           # price as printed ("Rs 20", "₹20")
    # How sure the model is that brand and name were read correctly. None =
    # not reported (old responses): unknown, never treated as zero.
    identity_confidence: Optional[float] = Field(default=None, ge=0.0, le=1.0)

    # Where the ingredients and nutrition came from (AGENTS.md: provenance).
    # None = read from the photo; otherwise the database the data was taken
    # from, with its product code and the date it was fetched.
    data_source: Optional[Literal["calfit_database", "open_food_facts"]] = None
    source_code: Optional[str] = None
    source_date: Optional[str] = None

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
    verified: bool = False              # True only for real products from the food database
    image_url: Optional[str] = None     # Product photo (Open Food Facts) when known


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
    # Front-of-pack scans: which real product was used, or the choices to
    # offer when the user has to confirm or pick (status confirm/choose).
    identification: Optional[Identification] = None

    @computed_field  # type: ignore[prop-decorator]
    @property
    def serving_size_unknown(self) -> bool:
        """Numbers without a serving size: the app asks the user to check the pack."""
        n = self.product.nutrition
        return n.serving_size_g is None and any(
            getattr(n, f) is not None for f in NutritionInfo.model_fields
            if f not in ("serving_size_g", "serving_size_source") and not f.endswith("_confidence"))

    @computed_field  # type: ignore[prop-decorator]
    @property
    def nutrient_levels(self) -> list[NutrientLevel]:
        """Fat, saturates, sugars and salt per 100 g/ml as low/medium/high."""
        n = self.product.nutrition
        return nutrient_levels(
            serving_size_g=n.serving_size_g,
            fat_g=n.total_fat_g,
            saturated_fat_g=n.saturated_fat_g,
            sugars_g=n.sugars_g,
            sodium_mg=n.sodium_mg,
            category=self.product.category,
            name=self.product.product_name,
        )


class FeedbackIssue(str, Enum):
    """What a user says was wrong with a scan result."""

    WRONG_PRODUCT = "wrong_product"
    WRONG_NUTRITION = "wrong_nutrition"
    WRONG_INGREDIENTS = "wrong_ingredients"
    MISSED_ALLERGEN = "missed_allergen"
    SCORE_UNFAIR = "score_unfair"
    OTHER = "other"


class ScanFeedbackRequest(BaseModel):
    """"Was this right?" on a scan. No free text, so no health details leak in."""

    accurate: bool
    issues: list[FeedbackIssue] = Field(default_factory=list, max_length=len(FeedbackIssue))

    @field_validator("issues")
    @classmethod
    def _unique(cls, v: list[FeedbackIssue]) -> list[FeedbackIssue]:
        return list(dict.fromkeys(v))


class ServingSizeRequest(BaseModel):
    """The user's answer to "Serving size unknown, check the pack"."""

    serving_size_g: float = Field(gt=0, le=5000, description="One serving, in g or ml.")
    label_basis: Literal["per_100", "per_serving"] = Field(
        description="Whether the label's numbers are per 100 g/ml or per serving.")


class ScanStats(BaseModel):
    """Totals over all of a user's scans (Home's numbers)."""

    total: int
    average: Optional[int] = None
    best: Optional[int] = None


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
