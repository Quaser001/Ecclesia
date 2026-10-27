"""Models for reading a prescription photo and proposing profile additions.

Nothing here is persisted. A `PrescriptionObservation` is what the vision model
transcribed; `PrescriptionSuggestions` is what we offer the user to confirm.
"""

from __future__ import annotations

from enum import Enum
from typing import Literal

from pydantic import BaseModel, Field

from src.domain.models import HealthCondition


class AllergyKind(str, Enum):
    FOOD = "food"
    DRUG = "drug"
    OTHER = "other"


class StatedAllergy(BaseModel):
    """An allergy exactly as written on the prescription."""

    name: str
    kind: AllergyKind = AllergyKind.OTHER


class PrescriptionObservation(BaseModel):
    """Verbatim transcription. Unknown stays empty; nothing is inferred here."""

    diagnoses: list[str] = Field(default_factory=list)
    medicines: list[str] = Field(default_factory=list)
    allergies: list[StatedAllergy] = Field(default_factory=list)
    # Unknown is not a prescription: a missing flag must never count as one.
    is_prescription: bool = True
    notes: str | None = None


class ConditionSuggestion(BaseModel):
    condition: HealthCondition
    basis: Literal["stated", "inferred_from_medicine"]
    source_text: str


class AllergySuggestion(BaseModel):
    name: str
    source_text: str


class PrescriptionSuggestions(BaseModel):
    conditions: list[ConditionSuggestion] = Field(default_factory=list)
    allergies: list[AllergySuggestion] = Field(default_factory=list)
    # Things we read but will not offer as profile entries (unmapped diagnoses
    # and medicines, drug allergies). Shown so the user can see what was skipped.
    unrecognised: list[str] = Field(default_factory=list)
    insufficient_data: bool = False
    message: str | None = None
