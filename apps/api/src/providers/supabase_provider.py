"""Real Supabase and Storage providers."""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from typing import Any

from supabase import AsyncClient, acreate_client

from src.domain.models import (
    ActivityLevel,
    DietaryPreference,
    HealthCondition,
    HealthGoal,
    KnowledgeEntry,
    Sex,
    UserProfile,
)
from src.domain.feedback import summarize_feedback
from src.providers.interfaces import StorageProvider, SupabaseProvider

logger = logging.getLogger(__name__)

_KNOWLEDGE_SCAN_CAP = 1000


class SupabaseDBProvider(SupabaseProvider):
    """Production Supabase provider."""

    def __init__(self, url: str, key: str) -> None:
        self._url = url
        self._key = key
        self._client: AsyncClient | None = None
        # Shared per process (config/dependencies.py): without the lock two
        # first requests could each create a client and leak one's pool.
        self._client_lock = asyncio.Lock()

    async def _get_client(self) -> AsyncClient:
        if self._client is None:
            async with self._client_lock:
                if self._client is None:
                    self._client = await acreate_client(self._url, self._key)
        return self._client

    async def query_knowledge_by_tags(
        self, tags: list[str], limit: int = 10
    ) -> list[KnowledgeEntry]:
        client = await self._get_client()
        if not tags:
            return []
        try:
            response = (
                await client.table("knowledge")
                .select("*")
                # The whole (small, curated) table, filtered below. Limiting
                # first returned 10 arbitrary rows, so most entries could
                # never match. The cap only guards against runaway growth.
                .limit(_KNOWLEDGE_SCAN_CAP)
                .execute()
            )
            entries = []
            tags_lower = [t.lower() for t in tags]
            for row in response.data or []:
                row_tags = [t.lower() for t in (row.get("relevance_tags") or [])]
                if any(t in row_tags or t in row.get("topic", "").lower() for t in tags_lower):
                    entries.append(_row_to_knowledge(row))
            return entries[:limit]
        except Exception as exc:
            logger.error("Knowledge tag query failed: %s", type(exc).__name__)
            return []

    async def query_knowledge_vector(
        self, query_text: str, limit: int = 5
    ) -> list[KnowledgeEntry]:
        """Vector search — falls back to tag search if pgvector not configured."""
        keywords = [w.lower() for w in query_text.split() if len(w) > 3]
        return await self.query_knowledge_by_tags(keywords[:5], limit)

    async def get_profile(self, user_id: str) -> UserProfile | None:
        client = await self._get_client()
        try:
            response = (
                await client.table("profiles")
                .select("*")
                .eq("user_id", user_id)
                .limit(1)
                .execute()
            )
            if not response.data:
                return None
            return _row_to_profile(response.data[0])
        except Exception as exc:
            logger.error("Get profile failed for user %s: %s", user_id, type(exc).__name__)
            raise

    async def upsert_profile(self, profile: UserProfile) -> UserProfile:
        client = await self._get_client()
        now = datetime.now(timezone.utc).isoformat()
        row = {
            "user_id": profile.user_id,
            "name": profile.name,
            "health_conditions": [c.value for c in profile.health_conditions],
            "allergies": profile.allergies,
            "dietary_preferences": [d.value for d in profile.dietary_preferences],
            "health_goals": [g.value for g in profile.health_goals],
            "avoid_caffeine": profile.avoid_caffeine,
            "height_cm": profile.height_cm,
            "weight_kg": profile.weight_kg,
            "target_weight_kg": profile.target_weight_kg,
            "birth_year": profile.birth_year,
            "sex": profile.sex.value if profile.sex else None,
            "activity_level": profile.activity_level.value if profile.activity_level else None,
            "updated_at": now,
        }
        try:
            response = (
                await client.table("profiles")
                .upsert(row, on_conflict="user_id")
                .execute()
            )
            return _row_to_profile(response.data[0])
        except Exception as exc:
            logger.error("Upsert profile failed: %s", type(exc).__name__)
            raise

    async def ensure_profile_exists(self, user_id: str) -> None:
        client = await self._get_client()
        try:
            await (
                client.table("profiles")
                .upsert(
                    {"user_id": user_id},
                    on_conflict="user_id",
                    ignore_duplicates=True,
                )
                .execute()
            )
        except Exception as exc:
            logger.error("Ensure profile failed for user %s: %s", user_id, type(exc).__name__)
            raise

    async def increment_scan_usage(self, user_id: str) -> int:
        client = await self._get_client()
        response = await client.rpc(
            "increment_scan_usage", {"p_user_id": user_id}
        ).execute()
        # The function returns a bare integer.
        if isinstance(response.data, int):
            return response.data
        raise RuntimeError(
            f"increment_scan_usage returned {response.data!r}, expected an integer"
        )

    async def save_scan(self, scan_data: dict[str, Any]) -> str:
        client = await self._get_client()
        try:
            response = await client.table("scans").insert(scan_data).execute()
            return response.data[0]["scan_id"]
        except Exception as exc:
            # Class name only: the row holds the explanation (and so conditions).
            logger.error("Save scan failed: %s", type(exc).__name__)
            raise

    async def get_scan_history(
        self, user_id: str, limit: int = 20, before: str | None = None
    ) -> list[dict[str, Any]]:
        client = await self._get_client()
        try:
            query = (
                client.table("scans")
                .select("scan_id, user_id, scanned_at, product_name, brand, score, suitability, image_url")
                .eq("user_id", user_id)
            )
            if before:
                query = query.lt("scanned_at", before)
            response = await query.order("scanned_at", desc=True).limit(limit).execute()
            return response.data or []
        except Exception as exc:
            logger.error("Get scan history failed: %s", type(exc).__name__)
            raise

    async def get_scan_stats(self, user_id: str) -> dict[str, Any]:
        client = await self._get_client()
        try:
            # count="exact" gives the true total; the score list is capped by
            # the server (1000 rows), which is plenty for an average and best.
            response = (
                await client.table("scans")
                .select("score", count="exact")
                .eq("user_id", user_id)
                .execute()
            )
            scores = [int(r["score"]) for r in response.data or []]
            return {
                "total": response.count if response.count is not None else len(scores),
                "average": round(sum(scores) / len(scores)) if scores else None,
                "best": max(scores) if scores else None,
            }
        except Exception as exc:
            logger.error("Get scan stats failed: %s", type(exc).__name__)
            raise

    async def get_scan(self, user_id: str, scan_id: str) -> dict[str, Any] | None:
        client = await self._get_client()
        try:
            response = (
                await client.table("scans")
                .select("*")
                .eq("scan_id", scan_id)
                .eq("user_id", user_id)
                .limit(1)
                .execute()
            )
            return response.data[0] if response.data else None
        except Exception as exc:
            logger.error("Get scan failed: %s", type(exc).__name__)
            raise

    async def delete_user_data(self, user_id: str) -> int:
        client = await self._get_client()
        try:
            # First, so even a delete that fails halfway stops processing.
            # Kept as proof that the processing before now was consented to;
            # withdrawn, so nothing new is processed until they agree again.
            await client.table("consents").update({"withdrawn_at": _utc_now()})                 .eq("user_id", user_id).is_("withdrawn_at", "null").execute()
            await client.table("scan_feedback").delete().eq("user_id", user_id).execute()
            await client.table("serving_memory").delete().eq("user_id", user_id).execute()
            scans = await client.table("scans").delete().eq("user_id", user_id).execute()
            # Past days of the scan and prescription counters ("rx:<user_id>").
            # Today's stay: the token still works after a delete, so wiping
            # them would reset the daily caps. They hold an id, a date and a count.
            await client.table("scan_usage").delete().in_(
                "user_id", [user_id, f"rx:{user_id}"]).lt("usage_date", _utc_today()).execute()
            await client.table("profiles").delete().eq("user_id", user_id).execute()
            return len(scans.data or [])
        except Exception as exc:
            logger.error("Delete user data failed: %s", type(exc).__name__)
            raise

    async def get_scans_for_insights(
        self, user_id: str, limit: int = 500
    ) -> list[dict[str, Any]]:
        client = await self._get_client()
        try:
            response = (
                await client.table("scans")
                .select("scan_id, scanned_at, product_name, brand, score, suitability, score_json, product_json")
                .eq("user_id", user_id)
                .order("scanned_at", desc=True)
                .limit(limit)
                .execute()
            )
            return response.data or []
        except Exception as exc:
            logger.error("Get scans for insights failed: %s", type(exc).__name__)
            raise

    async def save_scan_feedback(
        self, user_id: str, scan_id: str, accurate: bool, issues: list[str]
    ) -> None:
        client = await self._get_client()
        try:
            await client.table("scan_feedback").upsert({
                "scan_id": scan_id,
                "user_id": user_id,
                "accurate": accurate,
                "issues": issues,
                "created_at": datetime.now(timezone.utc).isoformat(),
            }).execute()
        except Exception as exc:
            logger.error("Save scan feedback failed: %s", type(exc).__name__)
            raise

    async def get_feedback_summary(self, since: datetime | None = None) -> dict[str, Any]:
        client = await self._get_client()
        try:
            rows: list[dict[str, Any]] = []
            page = 1000
            while True:
                query = client.table("scan_feedback").select("accurate, issues")
                if since:
                    query = query.gte("created_at", since.astimezone(timezone.utc).isoformat())
                batch = (await query.range(len(rows), len(rows) + page - 1).execute()).data or []
                rows.extend(batch)
                if len(batch) < page:
                    break
            return summarize_feedback(rows)
        except Exception as exc:
            logger.error("Feedback summary failed: %s", type(exc).__name__)
            raise

    async def delete_scan(self, user_id: str, scan_id: str) -> bool:
        client = await self._get_client()
        try:
            # scan_feedback rows go with it (ON DELETE CASCADE).
            res = await client.table("scans").delete().eq("scan_id", scan_id) \
                .eq("user_id", user_id).execute()
            return bool(res.data)
        except Exception as exc:
            logger.error("Delete scan failed: %s", type(exc).__name__)
            raise

    async def get_serving_memory(self, user_id: str, product_key: str) -> dict[str, Any] | None:
        client = await self._get_client()
        try:
            res = await client.table("serving_memory").select("serving_size_g, label_basis") \
                .eq("user_id", user_id).eq("product_key", product_key).limit(1).execute()
        except Exception as exc:
            # A missing memory must not stop a scan; it just isn't applied.
            logger.warning("Serving memory lookup failed: %s", type(exc).__name__)
            return None
        if not res.data:
            return None
        row = res.data[0]
        return {"serving_size_g": float(row["serving_size_g"]), "label_basis": row["label_basis"]}

    async def save_serving_memory(
        self, user_id: str, product_key: str, serving_size_g: float, label_basis: str
    ) -> None:
        client = await self._get_client()
        try:
            await client.table("serving_memory").upsert({
                "user_id": user_id,
                "product_key": product_key,
                "serving_size_g": serving_size_g,
                "label_basis": label_basis,
                "updated_at": datetime.now(timezone.utc).isoformat(),
            }).execute()
        except Exception as exc:
            logger.error("Save serving memory failed: %s", type(exc).__name__)
            raise


    async def record_consent(self, user_id: str, notice_version: str) -> datetime:
        client = await self._get_client()
        try:
            res = await client.table("consents").insert({
                "user_id": user_id,
                "notice_version": notice_version,
                "adult_confirmed": True,
            }).execute()
            return datetime.fromisoformat(res.data[0]["agreed_at"])
        except Exception as exc:
            logger.error("Record consent failed: %s", type(exc).__name__)
            raise

    async def has_consent(self, user_id: str, notice_version: str) -> bool:
        client = await self._get_client()
        try:
            res = await client.table("consents").select("id").eq("user_id", user_id)                 .eq("notice_version", notice_version).is_("withdrawn_at", "null")                 .limit(1).execute()
            return bool(res.data)
        except Exception as exc:
            # Unknown is not "yes": the gate must not wave health data through.
            logger.error("Consent lookup failed: %s", type(exc).__name__)
            raise


class SupabaseStorageProvider(StorageProvider):
    """Supabase Storage provider for image uploads."""

    def __init__(self, url: str, key: str) -> None:
        self._url = url
        self._key = key
        self._client: AsyncClient | None = None
        # Shared per process (config/dependencies.py): without the lock two
        # first requests could each create a client and leak one's pool.
        self._client_lock = asyncio.Lock()

    async def _get_client(self) -> AsyncClient:
        if self._client is None:
            async with self._client_lock:
                if self._client is None:
                    self._client = await acreate_client(self._url, self._key)
        return self._client

    async def upload_image(
        self, bucket: str, path: str, data: bytes, content_type: str
    ) -> str:
        client = await self._get_client()
        try:
            await client.storage.from_(bucket).upload(
                path=path,
                file=data,
                file_options={"content-type": content_type, "upsert": "true"},
            )
            # Async client: get_public_url is a coroutine and must be awaited.
            # The bucket is private, so this link does not open on its own;
            # serve signed URLs before showing photos in the app.
            return await client.storage.from_(bucket).get_public_url(path)
        except Exception as exc:
            # No path (it holds the user id) and no error text, per the logging rule.
            logger.error("Image upload failed: %s", type(exc).__name__)
            raise

    async def signed_urls(
        self, bucket: str, paths: list[str], expires_in: int
    ) -> dict[str, str | None]:
        if not paths:
            return {}
        client = await self._get_client()
        try:
            signed = await client.storage.from_(bucket).create_signed_urls(paths, expires_in)
        except Exception as exc:
            # No photo is better than a failed history page.
            logger.warning("Signing photo links failed: %s", type(exc).__name__)
            return {p: None for p in paths}
        out: dict[str, str | None] = {p: None for p in paths}
        for item in signed or []:
            url = item.get("signedURL") or item.get("signedUrl")
            if item.get("path") in out and url and not item.get("error"):
                out[item["path"]] = url
        return out

    async def delete_folder(self, bucket: str, prefix: str) -> int:
        if not prefix.strip("/") or ".." in prefix:
            raise ValueError("Refusing to delete outside one folder of the bucket.")
        client = await self._get_client()
        store = client.storage.from_(bucket)
        removed = 0
        # Bounded: if a remove ever silently deletes nothing, the same page
        # would come back forever. 200 passes covers 20,000 photos.
        for _ in range(200):
            objects = await store.list(prefix.rstrip("/"), {"limit": 100})
            paths = [f"{prefix.rstrip('/')}/{o['name']}" for o in objects or [] if o.get("name")]
            if not paths:
                return removed
            deleted = await store.remove(paths)
            if not deleted:
                raise RuntimeError("Storage reported nothing removed; stopping to avoid a loop.")
            removed += len(deleted)
        raise RuntimeError("Too many photos to delete in one request.")

    async def delete_object(self, bucket: str, path: str) -> None:
        if not path.strip("/") or ".." in path:
            raise ValueError("Refusing to delete outside the bucket.")
        client = await self._get_client()
        await client.storage.from_(bucket).remove([path])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _row_to_profile(row: dict) -> UserProfile:
    return UserProfile(
        user_id=row["user_id"],
        name=row.get("name"),
        health_conditions=[
            HealthCondition(c) for c in (row.get("health_conditions") or [])
            if c in HealthCondition._value2member_map_
        ],
        allergies=row.get("allergies") or [],
        dietary_preferences=[
            DietaryPreference(d) for d in (row.get("dietary_preferences") or [])
            if d in DietaryPreference._value2member_map_
        ],
        health_goals=[
            HealthGoal(g) for g in (row.get("health_goals") or [])
            if g in HealthGoal._value2member_map_
        ],
        avoid_caffeine=bool(row.get("avoid_caffeine", False)),
        height_cm=row.get("height_cm"),
        weight_kg=row.get("weight_kg"),
        target_weight_kg=row.get("target_weight_kg"),
        birth_year=row.get("birth_year"),
        sex=Sex(row["sex"]) if row.get("sex") in Sex._value2member_map_ else None,
        activity_level=(
            ActivityLevel(row["activity_level"])
            if row.get("activity_level") in ActivityLevel._value2member_map_
            else None
        ),
        created_at=row.get("created_at"),
        updated_at=row.get("updated_at"),
    )


def _row_to_knowledge(row: dict) -> KnowledgeEntry:
    return KnowledgeEntry(
        id=row.get("id"),
        topic=row.get("topic", ""),
        content=row.get("content", ""),
        relevance_tags=row.get("relevance_tags") or [],
        source=row.get("source", "calfit_knowledge_base"),
    )


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _utc_today() -> str:
    """The quota day, as the scan_usage table counts it (UTC)."""
    return datetime.now(timezone.utc).date().isoformat()
