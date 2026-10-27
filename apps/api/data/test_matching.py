import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src.repositories.product_repository import ProductRepository
from src.domain.models import UserProfile, HealthCondition
from src.domain.scoring_rules import calculate_score

repo = ProductRepository()

print("=== TESTING FUZZY MATCHING & SCORING ===")

# Test Bikaji matching
m1 = repo.match_product(name="Bikaji Kuch-Kuch Snacks", brand="Bikaji")
print("\nMatched Bikaji:", m1.brand if m1 else None, m1.product_name if m1 else None)
if m1:
    print(" Sodium:", m1.nutrition.sodium_mg, "mg")
    print(" Sat Fat:", m1.nutrition.saturated_fat_g, "g")

    # Score for user with hypertension and high cholesterol
    user = UserProfile(user_id="u1", health_conditions=[HealthCondition.HYPERTENSION, HealthCondition.HIGH_CHOLESTEROL])
    obs = m1.to_observation() if hasattr(m1, 'to_observation') else None
    from src.domain.models import ProductObservation
    obs = ProductObservation(
        brand=m1.brand,
        product_name=m1.product_name,
        category=m1.categories[0] if m1.categories else "snacks",
        ingredients=m1.ingredients,
        nutrition=m1.nutrition,
    )
    score_res = calculate_score(obs, user)
    print(" Score for Hypertensive/Cholesterol User:", score_res.score, "/ 100")
    for f in score_res.findings:
        print("  -", f.title, f"(-{f.score_impact} pts)")

# Test Good Day matching
m2 = repo.match_product(name="Good Day Biscuits", brand="Britannia")
print("\nMatched Good Day:", m2.brand if m2 else None, m2.product_name if m2 else None)
if m2:
    print(" Sugars:", m2.nutrition.sugars_g, "g")
    diabetic = UserProfile(user_id="u2", health_conditions=[HealthCondition.DIABETES_TYPE_2])
    obs2 = ProductObservation(
        brand=m2.brand,
        product_name=m2.product_name,
        category="biscuits",
        ingredients=m2.ingredients,
        nutrition=m2.nutrition,
    )
    score_res2 = calculate_score(obs2, diabetic)
    print(" Score for Diabetic User:", score_res2.score, "/ 100")
    for f in score_res2.findings:
        print("  -", f.title, f"(-{f.score_impact} pts)")
