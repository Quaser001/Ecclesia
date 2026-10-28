"""What the scan found out about which product is in the photo.

Plain data, shared by the pipeline (src/services/identification.py), the API
response and the confirm endpoint. The decisions live in the service.
"""

from __future__ import annotations

from enum import Enum
from typing import Literal, Optional

from pydantic import BaseModel, Field

Source = Literal["calfit_database", "open_food_facts"]


class IdStatus(str, Enum):
    CONFIDENT = "confident"
    CONFIRM = "confirm"
    CHOOSE = "choose"
    RETAKE = "retake"
    NOT_FOUND = "not_found"
    UNAVAILABLE = "unavailable"


class ProductOption(BaseModel):
    """A real product the user can pick; the app sends back code + source."""

    code: str
    source: Source
    name: str
    brand: Optional[str] = None
    quantity: Optional[str] = None
    image_url: Optional[str] = None


class Identification(BaseModel):
    status: IdStatus
    read_as: Optional[str] = None  # what was read on the pack, for the message
    options: list[ProductOption] = Field(default_factory=list)
    chosen: Optional[ProductOption] = None  # set when the scan went ahead

    @property
    def needs_user(self) -> bool:
        return self.status not in (IdStatus.CONFIDENT,)
