import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src.domain.models import ProductObservation, NutritionInfo, UserProfile, HealthCondition
from src.domain.scoring_rules import calculate_score

# 1. Diabetic User Profile
diabetic_profile = UserProfile(
    user_id="dev-user-001",
    health_conditions=[HealthCondition.DIABETES_TYPE_2],
)

# 2. Good Day Biscuits Product Observation
good_day = ProductObservation(
    brand="Britannia",
    product_name="Good Day Cashew Biscuits",
    category="biscuits",
    ingredients=["refined wheat flour (maida)", "sugar", "vegetable oil", "cashew nuts (4.5%)", "invert sugar syrup"],
    nutrition=NutritionInfo(
        calories_kcal=490,
        sugars_g=23.5,
        total_fat_g=21.0,
        saturated_fat_g=10.0,
        sodium_mg=150,
        protein_g=7.0,
    ),
)

res = calculate_score(good_day, diabetic_profile)
print("--- SCORING RESULT FOR GOOD DAY BISCUITS (DIABETIC USER) ---")
print("Score:", res.score, "/ 100")
print("Suitability:", res.suitability.value)
print("Risk Level:", res.risk_level.value)
print("Findings Count:", len(res.findings))
for f in res.findings:
    print(f" - [{f.severity.value}] {f.title}: {f.detail} (-{f.score_impact} pts)")
