"""Insights: summaries of a user's own stored scans.

Everything here is counted or averaged from rows already in the database.
Nothing is estimated, and a week with no scans has no average.
"""

from __future__ import annotations

from datetime import date
from typing import Optional

from pydantic import BaseModel, Field

from src.domain.models import FindingSeverity, HealthGoal, SuitabilityStatus


class WeeklyPoint(BaseModel):
    """One Monday-start week."""

    week_start: date
    scans: int = 0
    average_score: Optional[int] = None


class FlagCount(BaseModel):
    """A scoring rule and how many of the user's scans it flagged."""

    rule_id: str
    title: str
    severity: FindingSeverity
    count: int


class ProductPick(BaseModel):
    scan_id: str
    product_name: Optional[str] = None
    brand: Optional[str] = None
    score: int
    suitability: SuitabilityStatus


class GoalInsight(BaseModel):
    """How the user's scans line up with one of their goals."""

    goal: HealthGoal
    tracked: bool
    basis: str  # what the check is, in plain words
    checked: int = 0  # scans that had the data this check needs
    fits: int = 0
    main_issue: Optional[str] = None  # the most common reason a scan didn't fit


class InsightsResponse(BaseModel):
    total_scans: int = 0
    average_score: Optional[int] = None
    suitability_counts: dict[SuitabilityStatus, int] = Field(default_factory=dict)
    weekly: list[WeeklyPoint] = Field(default_factory=list)
    top_flags: list[FlagCount] = Field(default_factory=list)
    best: list[ProductPick] = Field(default_factory=list)
    needs_attention: list[ProductPick] = Field(default_factory=list)
    goals: list[GoalInsight] = Field(default_factory=list)
