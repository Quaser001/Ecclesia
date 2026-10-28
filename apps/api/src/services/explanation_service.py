"""Explanation service — generates human-readable explanation using LLM."""

from __future__ import annotations

import logging
import re

from src.domain.models import KnowledgeEntry, ProductObservation, ScoreResult, UserProfile
from src.prompts.explanation import build_explanation_messages
from src.providers.interfaces import GeminiProvider
from src.observability import note

logger = logging.getLogger(__name__)


class ExplanationService:
    """
    Generates a natural-language explanation of a scan result.

    The LLM receives ONLY structured, verified facts — no raw image, no free-form data.
    The score and findings are computed by ScoringService and passed in as inputs.
    """

    def __init__(self, gemini: GeminiProvider) -> None:
        self._gemini = gemini

    async def explain(
        self,
        product: ProductObservation,
        score_result: ScoreResult,
        profile: UserProfile,
        knowledge: list[KnowledgeEntry] | None = None,
    ) -> str:
        """Generate a concise, factual explanation of the scan result."""
        try:
            findings_summary = _format_findings(score_result)
            nutrition_summary = _format_nutrition(product)
            conditions = ", ".join(c.value for c in profile.health_conditions) or "None"
            allergies = ", ".join(profile.allergies) or "None"
            preferences = ", ".join(p.value for p in profile.dietary_preferences) or "None"
            goals = ", ".join(g.value for g in profile.health_goals) or "None"

            messages = build_explanation_messages(
                product_name=product.product_name or "Unknown Product",
                brand=product.brand or "Unknown Brand",
                category=product.category or "Unknown",
                score=score_result.score,
                suitability=score_result.suitability.value,
                findings_summary=findings_summary,
                conditions=conditions,
                allergies=allergies,
                preferences=preferences,
                goals=goals,
                nutrition_summary=nutrition_summary,
            )

            explanation = (await self._gemini.generate_explanation(messages)).strip()

            facts = f"{score_result.score} 100\n{findings_summary}\n{nutrition_summary}"
            if not is_explanation_grounded(explanation, facts):
                logger.warning("Explanation rejected by guard; using rule-based fallback.")
                note(explanation="fallback_ungrounded")
                return _fallback_explanation(product, score_result)
            note(explanation="llm")
            return explanation

        except Exception as exc:
            logger.error("Explanation generation failed: %s", type(exc).__name__)
            note(explanation="fallback_error")
            # Provide a factual fallback rather than hiding the failure
            return _fallback_explanation(product, score_result)


# Phrases that would turn an explanation into a safety guarantee or medical advice.
_FORBIDDEN_PHRASES = (
    "is safe", "are safe", "100% safe", "totally safe", "completely safe",
    "allergen-free", "allergen free", "free of allergens", "free from allergens",
    "diagnos", "as an ai",
)
_FORBIDDEN_WORDS = re.compile(r"\b(cure|cures|cured|treat|treats|treatment)\b")


def is_explanation_grounded(explanation: str, facts: str) -> bool:
    """Check an LLM explanation before it reaches the user.

    Rejects empty text, safety guarantees, medical advice wording, and any number
    that does not appear in the verified facts the model was given.
    """
    text = (explanation or "").strip()
    if not text:
        return False

    lowered = text.lower()
    if any(phrase in lowered for phrase in _FORBIDDEN_PHRASES) or _FORBIDDEN_WORDS.search(lowered):
        return False

    allowed = set(re.findall(r"\d+(?:\.\d+)?", facts))
    for number in re.findall(r"\d+(?:\.\d+)?", text):
        if number not in allowed and number.rstrip("0").rstrip(".") not in allowed:
            return False
    return True


def _format_findings(score_result: ScoreResult) -> str:
    if not score_result.findings:
        return "No specific concerns identified."
    lines = []
    for f in score_result.findings:
        lines.append(f"- [{f.severity.value.upper()}] {f.title}: {f.detail}")
    return "\n".join(lines)


def _format_nutrition(product: ProductObservation) -> str:
    n = product.nutrition
    parts = []
    if n.calories_kcal is not None:
        parts.append(f"Calories: {n.calories_kcal:.0f} kcal")
    if n.sodium_mg is not None:
        parts.append(f"Sodium: {n.sodium_mg:.0f} mg")
    if n.sugars_g is not None:
        parts.append(f"Sugars: {n.sugars_g:.1f} g")
    if n.total_fat_g is not None:
        parts.append(f"Total Fat: {n.total_fat_g:.1f} g")
    if n.saturated_fat_g is not None:
        parts.append(f"Saturated Fat: {n.saturated_fat_g:.1f} g")
    if n.protein_g is not None:
        parts.append(f"Protein: {n.protein_g:.1f} g")
    return ", ".join(parts) if parts else "Not available"


def _fallback_explanation(product: ProductObservation, score_result: ScoreResult) -> str:
    """Factual rule-based fallback explanation when LLM is unavailable."""
    product_name = product.product_name or "This product"
    score = score_result.score
    suitability = score_result.suitability.value

    if not score_result.findings:
        return (
            f"{product_name} received a score of {score}/100 ({suitability}). "
            "No specific concerns were identified based on your health profile and the available product information."
        )

    key_concerns = [f.title for f in score_result.findings[:3]]
    concerns_text = "; ".join(key_concerns)
    return (
        f"{product_name} received a personalized score of {score}/100 ({suitability}). "
        f"Key concerns for your profile: {concerns_text}. "
        "Please review the findings below for details."
    )
