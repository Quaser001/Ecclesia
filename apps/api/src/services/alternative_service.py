"""Alternative service — real, better-fit products from the same category.

An alternative must be:
  1. A real product from the local food database (never invented).
  2. In the same CalFit category (food_taxonomy), so namkeen is swapped for
     namkeen, not for oats.
  3. Better on whatever the scan flagged: at least 15% less of each flagged
     nutrient per 100 g, and none of the flagged ingredient-type issues.
  4. Free of hard stops for this user (allergens, diet violations).
  5. A better overall fit for this user under the same scoring rules.
Ranked by similar flavour first, then how many flagged issues it fixes, then
score. Database values are per 100 g/ml, so the scanned product is converted
to per 100 g before any comparison.

When nothing qualifies, the user gets shopping guidance (criteria) instead.
"""

from __future__ import annotations

import logging
from typing import Any

from src.domain.food_taxonomy import CATEGORIES, classify_text, flavours_of
from src.domain.models import (
    Alternative,
    DietaryPreference,
    FindingSeverity,
    KnowledgeEntry,
    NutritionInfo,
    ProductObservation,
    ScoreResult,
    UserProfile,
)
from src.domain.scoring_rules import calculate_score

logger = logging.getLogger(__name__)

MAX_ALTERNATIVES = 3
MIN_IMPROVEMENT = 0.15  # a flagged nutrient must drop by at least 15% per 100 g

# Finding nutrient names -> (NutritionInfo field, words used in the reason).
_NUMERIC_FLAGS: dict[str, tuple[str, str]] = {
    "sodium": ("sodium_mg", "sodium"),
    "sugars": ("sugars_g", "sugar"),
    "sugar": ("sugars_g", "sugar"),
    "saturated fat": ("saturated_fat_g", "saturated fat"),
    "trans fat": ("trans_fat_g", "trans fat"),
    "fat": ("total_fat_g", "fat"),
    "calories": ("calories_kcal", "calories"),
    "dietary cholesterol": ("cholesterol_mg", "cholesterol"),
    "carbs": ("total_carbs_g", "carbs"),
}

_PER_100_FIELDS = (
    "calories_kcal", "total_fat_g", "saturated_fat_g", "trans_fat_g", "cholesterol_mg",
    "sodium_mg", "total_carbs_g", "dietary_fiber_g", "sugars_g", "added_sugars_g",
    "protein_g", "iron_mg", "vitamin_c_mg",
)


def _per_100(n: NutritionInfo) -> NutritionInfo:
    """Label values (per serving) on the database's per-100 g basis."""
    if not n.serving_size_g or n.serving_size_g == 100:
        return n.model_copy(update={"serving_size_g": 100.0})
    factor = 100 / n.serving_size_g
    update: dict[str, Any] = {"serving_size_g": 100.0}
    for f in _PER_100_FIELDS:
        v = getattr(n, f)
        if v is not None:
            update[f] = v * factor
    return n.model_copy(update=update)


def _same_product(a: ProductObservation, name: str, brand: str | None) -> bool:
    def norm(s: str | None) -> str:
        return " ".join((s or "").lower().split())
    return norm(a.product_name) == norm(name) and norm(a.brand) == norm(brand)


class AlternativeService:
    def find(
        self,
        product: ProductObservation,
        profile: UserProfile,
        score_result: ScoreResult,
        knowledge: list[KnowledgeEntry] | None = None,
        product_repo: Any = None,
    ) -> list[Alternative]:
        alternatives: list[Alternative] = []

        if product_repo is not None:
            try:
                alternatives = self._from_database(product, profile, score_result, product_repo)
            except Exception as exc:
                logger.warning("Ranking alternatives failed: %s", type(exc).__name__)

        # Guidance from the knowledge base, labelled as guidance (not a product).
        if not alternatives and knowledge:
            for entry in knowledge:
                if (
                    "alternative" in entry.topic.lower()
                    or "alternative" in " ".join(entry.relevance_tags).lower()
                ):
                    alt = _knowledge_to_alternative(entry, product)
                    if alt:
                        alternatives.append(alt)

        if not alternatives:
            criteria_alt = _build_criteria_alternative(product, profile, score_result)
            if criteria_alt:
                alternatives.append(criteria_alt)

        return alternatives[:5]

    def _from_database(
        self,
        product: ProductObservation,
        profile: UserProfile,
        score_result: ScoreResult,
        product_repo: Any,
    ) -> list[Alternative]:
        category = classify_text(product.category, product.product_name)
        if category is None:
            return []

        base = product.model_copy(update={"nutrition": _per_100(product.nutrition)})
        base_score = calculate_score(base, profile)
        numeric: dict[str, str] = {}
        ingredient_rules: set[str] = set()
        for f in score_result.findings:
            key = (f.nutrient_or_ingredient or "").lower()
            if key in _NUMERIC_FLAGS:
                field, words = _NUMERIC_FLAGS[key]
                numeric[field] = words
            elif f.severity != FindingSeverity.INFO and not f.rule_id.startswith("RULE-001C"):
                ingredient_rules.add(f.rule_id)

        wanted_flavours = set(flavours_of(product.product_name))
        ranked: list[tuple[tuple, Alternative]] = []
        for cand in product_repo.find_by_calfit_category(category):
            if _same_product(product, cand.product_name, cand.brand):
                continue
            if profile.allergies and not cand.ingredients:
                continue  # allergens can't be checked without an ingredient list
            obs = ProductObservation(
                product_name=cand.product_name,
                brand=cand.brand,
                category=product.category,
                ingredients=cand.ingredients,
                nutrition=cand.nutrition.model_copy(update={"serving_size_g": 100.0}),
                allergens_declared=cand.allergens,
                extraction_confidence=cand.data_confidence,
            )
            cand_score = calculate_score(obs, profile)
            if any(f.severity == FindingSeverity.CRITICAL for f in cand_score.findings):
                continue  # allergen or diet hard stop for this user
            if cand_score.score <= base_score.score:
                continue
            if ingredient_rules & {f.rule_id for f in cand_score.findings}:
                continue  # still has the flagged ingredient-type issue

            improvements: list[str] = []
            for field, words in numeric.items():
                before = getattr(base.nutrition, field)
                after = getattr(cand.nutrition, field)
                if before and after is not None and after <= before * (1 - MIN_IMPROVEMENT):
                    improvements.append(
                        f"zero {words}" if after == 0
                        else f"{round((1 - after / before) * 100)}% less {words} per 100 g"
                    )
            if numeric and not improvements:
                continue  # doesn't fix what was flagged

            shared = sorted(wanted_flavours & set(cand.flavours or flavours_of(cand.product_name)))
            reason = [f"Same category ({CATEGORIES[category].label})."]
            if shared:
                reason.append(f"Similar {', '.join(s.replace('_', ' & ') for s in shared)} flavour.")
            if improvements:
                text = ", ".join(improvements)
                reason.append(text[0].upper() + text[1:] + ".")
            reason.append("A better fit for your profile.")
            rank = (len(shared) > 0, len(improvements), cand_score.score)
            ranked.append((rank, Alternative(
                type="product",
                name=cand.product_name,
                brand=cand.brand,
                reason=" ".join(reason),
                verified=True,
                image_url=cand.image_url,
            )))

        ranked.sort(key=lambda r: r[0], reverse=True)
        return [alt for _, alt in ranked[:MAX_ALTERNATIVES]]


def _knowledge_to_alternative(
    entry: KnowledgeEntry, product: ProductObservation
) -> Alternative | None:
    if product.category and product.category.lower() not in entry.content.lower():
        return None
    # Knowledge entries are general advice, not products: never badge them
    # as verified products.
    return Alternative(
        type="criteria",
        reason=entry.content[:200],
        criteria=entry.content[:200],
        verified=False,
    )


def _build_criteria_alternative(
    product: ProductObservation,
    profile: UserProfile,
    score_result: ScoreResult,
) -> Alternative | None:
    category = product.category or "similar product"
    criteria_parts = [f"Look for a {category}"]

    issues: list[str] = []
    for finding in score_result.findings:
        nutrient = finding.nutrient_or_ingredient
        if nutrient == "sodium":
            issues.append("lower sodium (under 600 mg per serving)")
        elif nutrient == "sugar":
            issues.append("lower sugar (under 5 g per serving)")
        elif nutrient == "saturated_fat":
            issues.append("less saturated fat (under 3 g per serving)")
        elif nutrient == "trans_fat":
            issues.append("no trans fat")
        elif nutrient == "gluten":
            issues.append("certified gluten-free")
        elif nutrient == "dairy":
            issues.append("dairy-free")
        elif nutrient == "animal_products":
            issues.append("plant-based ingredients only")
        elif nutrient == "meat":
            issues.append("vegetarian-friendly")
        elif "allergy" in (finding.rule_id or "").lower():
            issues.append(f"no {finding.nutrient_or_ingredient}")

    if issues:
        issues_text = " and ".join(issues[:3])
        criteria_parts.append(f"with {issues_text}")

    if DietaryPreference.VEGAN in profile.dietary_preferences:
        criteria_parts.append("(vegan-certified)")
    elif DietaryPreference.VEGETARIAN in profile.dietary_preferences:
        criteria_parts.append("(vegetarian-friendly)")

    if len(product.ingredients) > 20:
        criteria_parts.append("and a simpler ingredient list")

    criteria_text = " ".join(criteria_parts) + "."

    if score_result.score >= 75:
        return None

    return Alternative(
        type="criteria",
        reason=(
            f"This product scored {score_result.score}/100 for your profile. "
            f"When shopping for alternatives: {criteria_text}"
        ),
        criteria=criteria_text,
        verified=False,
    )
