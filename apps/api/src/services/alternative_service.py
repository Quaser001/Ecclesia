"""Alternative service — finds similar, better-fit product alternatives."""

from __future__ import annotations

import logging
from typing import Any

from src.domain.models import (
    Alternative,
    DietaryPreference,
    KnowledgeEntry,
    ProductObservation,
    ScoreResult,
    UserProfile,
)

logger = logging.getLogger(__name__)


class AlternativeService:
    """
    Finds product alternatives or generates useful alternative criteria.

    Never fabricates product availability. Returns:
    - Verified real products from the local DB when available
    - Structured criteria guidance when no verified products exist
    """

    def find(
        self,
        product: ProductObservation,
        profile: UserProfile,
        score_result: ScoreResult,
        knowledge: list[KnowledgeEntry] | None = None,
        product_repo: Any = None,
    ) -> list[Alternative]:
        alternatives: list[Alternative] = []

        # 1. Search real products from local product repository
        if product_repo is not None and product.category:
            try:
                from src.domain.scoring_rules import calculate_score

                candidates = product_repo.find_candidates_by_category(product.category, limit=25)
                scored_candidates = []
                for cand in candidates:
                    if (
                        product.product_name
                        and cand.product_name.strip().lower()
                        == product.product_name.strip().lower()
                    ):
                        continue
                    obs = ProductObservation(
                        brand=cand.brand,
                        product_name=cand.product_name,
                        category=cand.categories[0] if cand.categories else product.category,
                        ingredients=cand.ingredients,
                        nutrition=cand.nutrition,
                        allergens_declared=cand.allergens,
                    )
                    cand_score = calculate_score(obs, profile, knowledge)
                    if cand_score.score >= score_result.score:
                        scored_candidates.append((cand, cand_score))

                scored_candidates.sort(key=lambda x: x[1].score, reverse=True)

                for cand, cand_score in scored_candidates[:3]:
                    reasons = []
                    if (
                        cand.nutrition.sodium_mg is not None
                        and product.nutrition.sodium_mg is not None
                        and cand.nutrition.sodium_mg < product.nutrition.sodium_mg
                    ):
                        reasons.append(
                            f"lower sodium ({cand.nutrition.sodium_mg:.0f}mg vs "
                            f"{product.nutrition.sodium_mg:.0f}mg)"
                        )
                    if (
                        cand.nutrition.sugars_g is not None
                        and product.nutrition.sugars_g is not None
                        and cand.nutrition.sugars_g < product.nutrition.sugars_g
                    ):
                        reasons.append(
                            f"lower sugar ({cand.nutrition.sugars_g:.1f}g vs "
                            f"{product.nutrition.sugars_g:.1f}g)"
                        )
                    if (
                        cand.nutrition.saturated_fat_g is not None
                        and product.nutrition.saturated_fat_g is not None
                        and cand.nutrition.saturated_fat_g < product.nutrition.saturated_fat_g
                    ):
                        reasons.append(
                            f"lower saturated fat "
                            f"({cand.nutrition.saturated_fat_g:.1f}g vs "
                            f"{product.nutrition.saturated_fat_g:.1f}g)"
                        )

                    reason_str = f"Scores {cand_score.score}/100 for your profile"
                    if reasons:
                        reason_str += f" with {', '.join(reasons)}"

                    alternatives.append(
                        Alternative(
                            type="product",
                            name=cand.product_name,
                            brand=cand.brand,
                            reason=reason_str,
                            verified=True,
                        )
                    )
            except Exception as exc:
                logger.warning("Error ranking candidate alternatives: %s", exc)

        # 2. Try to find verified alternatives from knowledge entries if still needed
        if not alternatives and knowledge:
            for entry in knowledge:
                if (
                    "alternative" in entry.topic.lower()
                    or "alternative" in " ".join(entry.relevance_tags).lower()
                ):
                    alt = _knowledge_to_alternative(entry, product)
                    if alt:
                        alternatives.append(alt)

        # 3. If no verified real products or knowledge alternatives found, generate criteria
        if not alternatives:
            criteria_alt = _build_criteria_alternative(product, profile, score_result)
            if criteria_alt:
                alternatives.append(criteria_alt)

        return alternatives[:5]


def _knowledge_to_alternative(
    entry: KnowledgeEntry, product: ProductObservation
) -> Alternative | None:
    if product.category and product.category.lower() not in entry.content.lower():
        return None
    return Alternative(
        type="product",
        name=entry.topic,
        reason=entry.content[:200],
        verified=True,
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
