"""Provider interfaces for external services."""

from abc import ABC, abstractmethod
from typing import Any

from src.domain.models import KnowledgeEntry, ProductObservation, UserProfile
from src.domain.prescription import PrescriptionObservation


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
    async def get_scan_history(self, user_id: str, limit: int = 20) -> list[dict[str, Any]]:
        """Retrieve scan history for a user."""
        ...


class StorageProvider(ABC):
    """Interface for file/image storage."""

    @abstractmethod
    async def upload_image(self, bucket: str, path: str, data: bytes, content_type: str) -> str:
        """Upload an image and return the public URL."""
        ...
