"""Provider interfaces for external services."""

from abc import ABC, abstractmethod
from datetime import datetime
from typing import Any

from src.domain.models import KnowledgeEntry, ProductObservation, UserProfile
from src.domain.prescription import PrescriptionObservation


class ServiceUnavailable(Exception):
    """A service the answer depends on is down: the API returns 503 with `message`.

    Never turned into a normal-looking result (ADR-006): a Gemini outage is not
    "take a clearer photo", and a profile that didn't load is not an empty profile.
    """

    def __init__(self, message: str) -> None:
        super().__init__(message)
        self.message = message


class GeminiProvider(ABC):
    """Interface for Gemini multimodal capabilities."""

    @abstractmethod
    async def analyze_photo(self, photo_bytes: bytes, mime_type: str = "image/jpeg") -> ProductObservation:
        """Analyze a product photo and return a structured ProductObservation."""
        ...

    @abstractmethod
    async def analyze_prescription(
        self, photo_bytes: bytes, mime_type: str = "image/jpeg"
    ) -> PrescriptionObservation:
        """Transcribe a prescription photo. Must not retain or log the image or its text."""
        ...

    @abstractmethod
    async def generate_explanation(self, messages: list[dict[str, str]]) -> str:
        """Generate a text explanation from a structured messages list."""
        ...


class SupabaseProvider(ABC):
    """Interface for Supabase database interactions."""

    @abstractmethod
    async def query_knowledge_by_tags(self, tags: list[str], limit: int = 10) -> list[KnowledgeEntry]:
        """Retrieve knowledge entries matching the given relevance tags."""
        ...

    @abstractmethod
    async def query_knowledge_vector(self, query_text: str, limit: int = 5) -> list[KnowledgeEntry]:
        """Retrieve knowledge entries using vector similarity search."""
        ...

    @abstractmethod
    async def get_profile(self, user_id: str) -> UserProfile | None:
        """Retrieve a user profile by user_id. Returns None if not found."""
        ...

    @abstractmethod
    async def upsert_profile(self, profile: UserProfile) -> UserProfile:
        """Create or update a user profile. Returns the saved profile."""
        ...

    @abstractmethod
    async def ensure_profile_exists(self, user_id: str) -> None:
        """Create an empty profile row for user_id if none exists.

        `scans.user_id` has a foreign key to `profiles.user_id`, so a scan
        cannot be saved for a device that has never opened the profile screen.
        SQLite does not enforce foreign keys by default, so this only fails on
        Postgres — i.e. only in production. Must be idempotent.
        """
        ...

    @abstractmethod
    async def increment_scan_usage(self, user_id: str) -> int:
        """Atomically add one to today's scan count and return the new total.

        Used by the daily cap. Returning the post-increment value in a single
        round trip means two concurrent scans cannot both read "under the cap"
        and both proceed.
        """
        ...

    @abstractmethod
    async def save_scan(self, scan_data: dict[str, Any]) -> str:
        """Persist a scan record. Returns the scan_id."""
        ...

    @abstractmethod
    async def get_scan_history(
        self, user_id: str, limit: int = 20, before: str | None = None
    ) -> list[dict[str, Any]]:
        """Newest-first scan history; `before` (ISO time, UTC) pages backwards."""
        ...

    @abstractmethod
    async def get_scan_stats(self, user_id: str) -> dict[str, Any]:
        """{"total", "average", "best"} over all of the user's scans."""
        ...

    @abstractmethod
    async def get_scan(self, user_id: str, scan_id: str) -> dict[str, Any] | None:
        """One full scan row, or None if it does not exist or is not this user's."""
        ...

    @abstractmethod
    async def delete_user_data(self, user_id: str) -> int:
        """Delete the user's scans, usage counters and profile. Returns scans deleted."""
        ...

    @abstractmethod
    async def get_scans_for_insights(
        self, user_id: str, limit: int = 500
    ) -> list[dict[str, Any]]:
        """Recent scans with their score_json, newest first."""
        ...

    @abstractmethod
    async def save_scan_feedback(
        self, user_id: str, scan_id: str, accurate: bool, issues: list[str]
    ) -> None:
        """Record "was this right?" for one of the user's scans (latest answer wins)."""
        ...

    @abstractmethod
    async def get_feedback_summary(self, since: datetime | None = None) -> dict[str, Any]:
        """Counts over all users: total, accurate, and how often each issue was picked."""
        ...

    @abstractmethod
    async def delete_scan(self, user_id: str, scan_id: str) -> bool:
        """Delete one of the user's scans (and its feedback). False if not theirs."""
        ...

    @abstractmethod
    async def get_serving_memory(self, user_id: str, product_key: str) -> dict[str, Any] | None:
        """The serving size this user saved for a product: {serving_size_g, label_basis}."""
        ...

    @abstractmethod
    async def save_serving_memory(
        self, user_id: str, product_key: str, serving_size_g: float, label_basis: str
    ) -> None:
        """Remember (or replace) the user's serving size for a product."""
        ...

    @abstractmethod
    async def record_consent(self, user_id: str, notice_version: str) -> datetime:
        """Store that the user agreed to this notice version (and is 18+). Returns when."""
        ...

    @abstractmethod
    async def has_consent(self, user_id: str, notice_version: str) -> bool:
        """True if the user has a consent for this version that wasn't withdrawn."""
        ...


class StorageProvider(ABC):
    """Interface for file/image storage."""

    @abstractmethod
    async def upload_image(self, bucket: str, path: str, data: bytes, content_type: str) -> str:
        """Upload an image and return the public URL."""
        ...

    @abstractmethod
    async def signed_urls(
        self, bucket: str, paths: list[str], expires_in: int
    ) -> dict[str, str | None]:
        """Short-lived links for private objects; None where a link can't be made."""
        ...

    @abstractmethod
    async def delete_folder(self, bucket: str, prefix: str) -> int:
        """Delete every object under `prefix` in `bucket`. Returns how many."""
        ...

    @abstractmethod
    async def delete_object(self, bucket: str, path: str) -> None:
        """Delete one object. Missing objects are not an error."""
        ...
