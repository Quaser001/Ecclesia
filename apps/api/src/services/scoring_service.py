"""Scoring service — thin wrapper around the deterministic scoring rule engine."""

from __future__ import annotations

from src.domain.models import KnowledgeEntry, ProductObservation, ScoreResult, UserProfile
from src.domain.scoring_rules import calculate_score


class ScoringService:
    """
    Applies deterministic scoring rules to produce a ScoreResult.

    This service is the authoritative source of scores.
    The LLM never participates in score calculation.
    """

    def score(
        self,
        product: ProductObservation,
        profile: UserProfile,
        knowledge: list[KnowledgeEntry] | None = None,
    ) -> ScoreResult:
        """
        Calculate a personalized score for a product given a user's profile.

        Returns different results for the same product if profiles differ.
        """
        return calculate_score(product, profile, knowledge)
