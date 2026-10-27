import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src.domain.models import ProductObservation, NutritionInfo, UserProfile, HealthCondition
from src.domain.scoring_rules import calculate_score

# User with Hypertension and High Cholesterol
user = UserProfile(
    user_id="dev-user-001",
    health_conditions=[HealthCondition.HYPERTENSION, HealthCondition.HIGH_CHOLESTEROL],
)

bikaji = ProductObservation(
    brand="Bikaji",
    product_name="Kuch Kuch All-In-One Namkeen",
    category="snacks",
    ingredients=["gram flour", "palmolein oil", "peanuts", "rice flakes", "tapioca starch", "salt", "spices"],
    nutrition=NutritionInfo(
        calories_kcal=540,
        total_fat_g=34.0,
        saturated_fat_g=15.0,
        sodium_mg=750,
        sugars_g=6.0,
        protein_g=10.0,
    ),
)

res = calculate_score(bikaji, user)
print("=== BIKAJI KUCH KUCH EVALUATION RESULT ===")
print("Product:", bikaji.brand, bikaji.product_name)
print("Score:", res.score, "/ 100")
print("Suitability:", res.suitability.value)
print("Risk Level:", res.risk_level.value)
print("Findings Count:", len(res.findings))
for f in res.findings:
    print(f" - [{f.severity.value}] {f.title}: {f.detail} (-{f.score_impact} pts)")
