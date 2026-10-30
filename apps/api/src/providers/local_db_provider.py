"""Local SQLite database provider implementing SupabaseProvider and StorageProvider."""

from __future__ import annotations

import json
import logging
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

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


_BODY_COLUMNS = (
    ("height_cm", "REAL"),
    ("weight_kg", "REAL"),
    ("target_weight_kg", "REAL"),
    ("birth_year", "INTEGER"),
    ("sex", "TEXT"),
    ("activity_level", "TEXT"),
)


def get_db_path() -> str:
    """Return local sqlite database path."""
    project_root = Path(__file__).resolve().parent.parent.parent
    data_dir = project_root / "data"
    data_dir.mkdir(parents=True, exist_ok=True)
    return str(data_dir / "calfit.db")


class LocalDBProvider(SupabaseProvider):
    """Local SQLite-backed provider for profile, knowledge, and scan history."""

    def __init__(self, db_path: str | None = None) -> None:
        self._db_path = db_path or get_db_path()
        self._init_db()

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self._db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self) -> None:
        """Create necessary tables if they do not exist."""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS profiles (
                    user_id TEXT PRIMARY KEY,
                    name TEXT,
                    health_conditions TEXT,
                    allergies TEXT,
                    dietary_preferences TEXT,
                    health_goals TEXT,
                    avoid_caffeine INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT,
                    updated_at TEXT
                )
            """)
            # Additive migration: a DB that pre-dates `avoid_caffeine` picks up the
            # column on next boot without losing existing rows. ALTER raises if the
            # column already exists, which is fine — we only need it done once.
            try:
                cursor.execute(
                    "ALTER TABLE profiles ADD COLUMN avoid_caffeine INTEGER NOT NULL DEFAULT 0"
                )
            except sqlite3.OperationalError:
                pass
            # Body details (all optional), added the same additive way.
            for column, kind in _BODY_COLUMNS:
                try:
                    cursor.execute(f"ALTER TABLE profiles ADD COLUMN {column} {kind}")
                except sqlite3.OperationalError:
                    pass
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS scan_usage (
                    user_id TEXT NOT NULL,
                    usage_date TEXT NOT NULL,
                    scan_count INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (user_id, usage_date)
                )
            """)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS knowledge (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    topic TEXT NOT NULL,
                    content TEXT NOT NULL,
                    relevance_tags TEXT,
                    source TEXT DEFAULT 'calfit_knowledge_base'
                )
            """)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS scans (
                    scan_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    scanned_at TEXT NOT NULL,
                    product_name TEXT,
                    brand TEXT,
                    category TEXT,
                    score INTEGER NOT NULL,
                    suitability TEXT NOT NULL,
                    image_url TEXT,
                    product_json TEXT,
                    score_json TEXT,
                    explanation TEXT
                )
            """)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS serving_memory (
                    user_id TEXT NOT NULL,
                    product_key TEXT NOT NULL,
                    serving_size_g REAL NOT NULL,
                    label_basis TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    PRIMARY KEY (user_id, product_key)
                )
            """)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS consents (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    notice_version TEXT NOT NULL,
                    adult_confirmed INTEGER NOT NULL CHECK (adult_confirmed = 1),
                    agreed_at TEXT NOT NULL,
                    withdrawn_at TEXT
                )
            """)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS scan_feedback (
                    scan_id TEXT PRIMARY KEY REFERENCES scans(scan_id) ON DELETE CASCADE,
                    user_id TEXT NOT NULL,
                    accurate INTEGER NOT NULL,
                    issues TEXT NOT NULL DEFAULT '[]',
                    created_at TEXT NOT NULL
                )
            """)
            # Billing: one row per subscription (not per user), plus a ledger of
            # processed webhook ids for idempotency. Mirrors migration 013.
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS entitlements (
                    subscription_id TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    tier TEXT NOT NULL,
                    status TEXT NOT NULL,
                    period_end TEXT,
                    customer_id TEXT,
                    last_event_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                )
            """)
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_entitlements_user ON entitlements(user_id)"
            )
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS billing_webhook_events (
                    webhook_id TEXT PRIMARY KEY,
                    event_type TEXT,
                    received_at TEXT NOT NULL
                )
            """)
            conn.commit()

    async def query_knowledge_by_tags(
        self, tags: list[str], limit: int = 10
    ) -> list[KnowledgeEntry]:
        if not tags:
            return []
        tags_lower = [t.lower() for t in tags]
        entries: list[KnowledgeEntry] = []
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id, topic, content, relevance_tags, source FROM knowledge LIMIT 100")
            rows = cursor.fetchall()
            for row in rows:
                topic = row["topic"] or ""
                relevance_tags_raw = row["relevance_tags"] or "[]"
                try:
                    row_tags = [t.lower() for t in json.loads(relevance_tags_raw)]
                except Exception:
                    row_tags = [t.strip().lower() for t in relevance_tags_raw.split(",") if t.strip()]

                if any(t in row_tags or t in topic.lower() for t in tags_lower):
                    entries.append(
                        KnowledgeEntry(
                            id=row["id"],
                            topic=row["topic"],
                            content=row["content"],
                            relevance_tags=row_tags,
                            source=row["source"] or "calfit_knowledge_base",
                        )
                    )
                    if len(entries) >= limit:
                        break
        return entries

    async def query_knowledge_vector(
        self, query_text: str, limit: int = 5
    ) -> list[KnowledgeEntry]:
        keywords = [w.lower() for w in query_text.split() if len(w) > 3]
        return await self.query_knowledge_by_tags(keywords[:5], limit)

    async def get_profile(self, user_id: str) -> UserProfile | None:
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM profiles WHERE user_id = ?", (user_id,))
            row = cursor.fetchone()
            if not row:
                return None
            return _row_to_profile(row)

    async def upsert_profile(self, profile: UserProfile) -> UserProfile:
        now = datetime.now(timezone.utc).isoformat()
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO profiles (
                    user_id, name, health_conditions, allergies,
                    dietary_preferences, health_goals, avoid_caffeine,
                    height_cm, weight_kg, target_weight_kg, birth_year, sex, activity_level,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(user_id) DO UPDATE SET
                    name=excluded.name,
                    health_conditions=excluded.health_conditions,
                    allergies=excluded.allergies,
                    dietary_preferences=excluded.dietary_preferences,
                    health_goals=excluded.health_goals,
                    avoid_caffeine=excluded.avoid_caffeine,
                    height_cm=excluded.height_cm,
                    weight_kg=excluded.weight_kg,
                    target_weight_kg=excluded.target_weight_kg,
                    birth_year=excluded.birth_year,
                    sex=excluded.sex,
                    activity_level=excluded.activity_level,
                    updated_at=excluded.updated_at
            """, (
                profile.user_id,
                profile.name,
                json.dumps([c.value for c in profile.health_conditions]),
                json.dumps(profile.allergies),
                json.dumps([d.value for d in profile.dietary_preferences]),
                json.dumps([g.value for g in profile.health_goals]),
                1 if profile.avoid_caffeine else 0,
                profile.height_cm,
                profile.weight_kg,
                profile.target_weight_kg,
                profile.birth_year,
                profile.sex.value if profile.sex else None,
                profile.activity_level.value if profile.activity_level else None,
                profile.created_at.isoformat() if profile.created_at else now,
                now,
            ))
            conn.commit()
        return (await self.get_profile(profile.user_id)) or profile

    async def ensure_profile_exists(self, user_id: str) -> None:
        """Insert an empty profile row if the user has none. Idempotent."""
        now = datetime.now(timezone.utc).isoformat()
        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT OR IGNORE INTO profiles
                    (user_id, name, health_conditions, allergies,
                     dietary_preferences, health_goals, avoid_caffeine,
                     created_at, updated_at)
                VALUES (?, NULL, '[]', '[]', '[]', '[]', 0, ?, ?)
                """,
                (user_id, now, now),
            )

    async def increment_scan_usage(self, user_id: str) -> int:
        """Local equivalent of the Postgres quota function."""
        today = datetime.now(timezone.utc).date().isoformat()
        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT INTO scan_usage (user_id, usage_date, scan_count)
                VALUES (?, ?, 1)
                ON CONFLICT(user_id, usage_date)
                DO UPDATE SET scan_count = scan_count + 1
                """,
                (user_id, today),
            )
            row = conn.execute(
                "SELECT scan_count FROM scan_usage WHERE user_id = ? AND usage_date = ?",
                (user_id, today),
            ).fetchone()
        return int(row["scan_count"]) if row else 0

    async def refund_scan_usage(self, user_id: str) -> int:
        """Local equivalent of the Postgres refund function (migration 012)."""
        today = datetime.now(timezone.utc).date().isoformat()
        with self._get_connection() as conn:
            conn.execute(
                "UPDATE scan_usage SET scan_count = MAX(scan_count - 1, 0) "
                "WHERE user_id = ? AND usage_date = ?", (user_id, today))
            row = conn.execute(
                "SELECT scan_count FROM scan_usage WHERE user_id = ? AND usage_date = ?",
                (user_id, today)).fetchone()
        return int(row["scan_count"]) if row else 0

    async def save_scan(self, scan_data: dict[str, Any]) -> str:
        # A plain INSERT, like Supabase: an id that's taken is an error, never
        # an overwrite of someone else's scan (Idempotency-Key ids come from the app).
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO scans (
                    scan_id, user_id, scanned_at, product_name, brand, category,
                    score, suitability, image_url, product_json, score_json, explanation
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                scan_data["scan_id"],
                scan_data["user_id"],
                scan_data["scanned_at"],
                scan_data.get("product_name"),
                scan_data.get("brand"),
                scan_data.get("category"),
                scan_data["score"],
                scan_data["suitability"],
                scan_data.get("image_url"),
                scan_data.get("product_json"),
                scan_data.get("score_json"),
                scan_data.get("explanation"),
            ))
            conn.commit()
        return scan_data["scan_id"]

    async def get_scan_history(
        self, user_id: str, limit: int = 20, before: str | None = None
    ) -> list[dict[str, Any]]:
        with self._get_connection() as conn:
            rows = conn.execute(
                """
                SELECT scan_id, user_id, scanned_at, product_name, brand, score, suitability, image_url
                FROM scans
                WHERE user_id = ? AND (? IS NULL OR scanned_at < ?)
                ORDER BY scanned_at DESC
                LIMIT ?
                """,
                (user_id, before, before, limit),
            ).fetchall()
            return [dict(r) for r in rows]

    async def get_scan_stats(self, user_id: str) -> dict[str, Any]:
        with self._get_connection() as conn:
            total, avg, best = conn.execute(
                "SELECT COUNT(*), AVG(score), MAX(score) FROM scans WHERE user_id = ?",
                (user_id,),
            ).fetchone()
        return {
            "total": total,
            "average": round(avg) if avg is not None else None,
            "best": best,
        }

    async def get_scan(self, user_id: str, scan_id: str) -> dict[str, Any] | None:
        with self._get_connection() as conn:
            row = conn.execute(
                "SELECT * FROM scans WHERE scan_id = ? AND user_id = ?",
                (scan_id, user_id),
            ).fetchone()
            return dict(row) if row else None

    async def delete_user_data(self, user_id: str) -> int:
        with self._get_connection() as conn:
            # First, and withdrawn rather than deleted: see SupabaseDBProvider.
            conn.execute("UPDATE consents SET withdrawn_at = ? WHERE user_id = ? AND withdrawn_at IS NULL",
                         (datetime.now(timezone.utc).isoformat(), user_id))
            conn.execute("DELETE FROM scan_feedback WHERE user_id = ?", (user_id,))
            conn.execute("DELETE FROM serving_memory WHERE user_id = ?", (user_id,))
            deleted = conn.execute("DELETE FROM scans WHERE user_id = ?", (user_id,)).rowcount
            # Past days of the scan and prescription counters; today's stay so
            # a delete doesn't reset the daily caps (see SupabaseDBProvider).
            today = datetime.now(timezone.utc).date().isoformat()
            conn.execute("DELETE FROM scan_usage WHERE user_id IN (?, ?) AND usage_date < ?",
                         (user_id, f"rx:{user_id}", today))
            # Entitlement rows for this profile. Note: this stops US honouring
            # the subscription; it does not cancel it at Dodo (the founder's
            # call — see status.md). Webhook-id ledger rows carry no personal
            # data and are kept so a late duplicate stays a no-op.
            conn.execute("DELETE FROM entitlements WHERE user_id = ?", (user_id,))
            conn.execute("DELETE FROM profiles WHERE user_id = ?", (user_id,))
            conn.commit()
        return deleted

    async def get_scans_for_insights(
        self, user_id: str, limit: int = 500
    ) -> list[dict[str, Any]]:
        with self._get_connection() as conn:
            rows = conn.execute(
                """
                SELECT scan_id, scanned_at, product_name, brand, score, suitability, score_json, product_json
                FROM scans
                WHERE user_id = ?
                ORDER BY scanned_at DESC
                LIMIT ?
                """,
                (user_id, limit),
            ).fetchall()
            return [dict(r) for r in rows]

    async def save_scan_feedback(
        self, user_id: str, scan_id: str, accurate: bool, issues: list[str]
    ) -> None:
        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT INTO scan_feedback (scan_id, user_id, accurate, issues, created_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(scan_id) DO UPDATE SET
                    accurate = excluded.accurate,
                    issues = excluded.issues,
                    created_at = excluded.created_at
                """,
                (scan_id, user_id, int(accurate), json.dumps(issues),
                 datetime.now(timezone.utc).isoformat()),
            )
            conn.commit()

    async def get_feedback_summary(self, since: datetime | None = None) -> dict[str, Any]:
        cutoff = since.astimezone(timezone.utc).isoformat() if since else None
        with self._get_connection() as conn:
            rows = conn.execute(
                "SELECT accurate, issues FROM scan_feedback WHERE (? IS NULL OR created_at >= ?)",
                (cutoff, cutoff),
            ).fetchall()
        return summarize_feedback(
            [{"accurate": bool(r["accurate"]), "issues": json.loads(r["issues"] or "[]")} for r in rows]
        )

    async def delete_scan(self, user_id: str, scan_id: str) -> bool:
        with self._get_connection() as conn:
            conn.execute("DELETE FROM scan_feedback WHERE scan_id = ? AND user_id = ?",
                         (scan_id, user_id))
            gone = conn.execute("DELETE FROM scans WHERE scan_id = ? AND user_id = ?",
                                (scan_id, user_id)).rowcount
            conn.commit()
        return gone > 0

    async def get_serving_memory(self, user_id: str, product_key: str) -> dict[str, Any] | None:
        with self._get_connection() as conn:
            row = conn.execute(
                "SELECT serving_size_g, label_basis FROM serving_memory "
                "WHERE user_id = ? AND product_key = ?", (user_id, product_key)).fetchone()
        return dict(row) if row else None

    async def save_serving_memory(
        self, user_id: str, product_key: str, serving_size_g: float, label_basis: str
    ) -> None:
        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT INTO serving_memory (user_id, product_key, serving_size_g, label_basis, updated_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(user_id, product_key) DO UPDATE SET
                    serving_size_g = excluded.serving_size_g,
                    label_basis = excluded.label_basis,
                    updated_at = excluded.updated_at
                """,
                (user_id, product_key, serving_size_g, label_basis,
                 datetime.now(timezone.utc).isoformat()),
            )
            conn.commit()


    async def record_consent(self, user_id: str, notice_version: str) -> datetime:
        now = datetime.now(timezone.utc)
        with self._get_connection() as conn:
            conn.execute(
                "INSERT INTO consents (user_id, notice_version, adult_confirmed, agreed_at) "
                "VALUES (?, ?, 1, ?)", (user_id, notice_version, now.isoformat()))
            conn.commit()
        return now

    async def has_consent(self, user_id: str, notice_version: str) -> bool:
        with self._get_connection() as conn:
            row = conn.execute(
                "SELECT 1 FROM consents WHERE user_id = ? AND notice_version = ? "
                "AND withdrawn_at IS NULL LIMIT 1", (user_id, notice_version)).fetchone()
        return row is not None

    async def get_entitlements(self, user_id: str) -> list[dict[str, Any]]:
        with self._get_connection() as conn:
            rows = conn.execute(
                "SELECT tier, status, period_end FROM entitlements WHERE user_id = ?",
                (user_id,),
            ).fetchall()
        return [dict(r) for r in rows]

    async def apply_billing_event(
        self,
        *,
        webhook_id: str,
        event_type: str,
        user_id: str,
        subscription_id: str,
        customer_id: str | None,
        tier: str,
        status: str,
        period_end: "datetime | None",
        event_at: "datetime",
    ) -> bool:
        """Local mirror of the Postgres apply_billing_event RPC (migration 013).

        One transaction: skip a webhook id we've already recorded (idempotent),
        then upsert the subscription only if this event is newer than the last
        one applied to it (ordering guard).
        """
        now = datetime.now(timezone.utc).isoformat()
        period_end_s = period_end.isoformat() if period_end else None
        event_at_s = event_at.isoformat()
        with self._get_connection() as conn:
            seen = conn.execute(
                "SELECT 1 FROM billing_webhook_events WHERE webhook_id = ?",
                (webhook_id,),
            ).fetchone()
            if seen is not None:
                return False
            conn.execute(
                "INSERT INTO billing_webhook_events (webhook_id, event_type, received_at) "
                "VALUES (?, ?, ?)",
                (webhook_id, event_type, now),
            )
            cur = conn.execute(
                """
                INSERT INTO entitlements
                    (subscription_id, user_id, tier, status, period_end,
                     customer_id, last_event_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(subscription_id) DO UPDATE SET
                    user_id = excluded.user_id,
                    tier = excluded.tier,
                    status = excluded.status,
                    period_end = excluded.period_end,
                    customer_id = excluded.customer_id,
                    last_event_at = excluded.last_event_at,
                    updated_at = excluded.updated_at
                WHERE excluded.last_event_at > entitlements.last_event_at
                """,
                (subscription_id, user_id, tier, status, period_end_s,
                 customer_id, event_at_s, now),
            )
            conn.commit()
            return cur.rowcount > 0


class LocalStorageProvider(StorageProvider):
    """Local file-based storage provider for images."""

    def __init__(self, base_dir: str | None = None) -> None:
        if base_dir:
            self._base_dir = Path(base_dir)
        else:
            project_root = Path(__file__).resolve().parent.parent.parent
            self._base_dir = project_root / "data" / "uploads"
        self._base_dir.mkdir(parents=True, exist_ok=True)

    async def upload_image(self, bucket: str, path: str, data: bytes, content_type: str) -> str:
        # `path` can carry caller-influenced segments; never let it climb out
        # of the uploads directory (e.g. "scans/../../x").
        base = self._base_dir.resolve()
        bucket_dir = (base / bucket).resolve()
        dest = (bucket_dir / path).resolve()
        if bucket_dir == base or not bucket_dir.is_relative_to(base) or not dest.is_relative_to(bucket_dir):
            raise ValueError("Refusing to write outside the bucket's uploads directory.")
        dest.parent.mkdir(parents=True, exist_ok=True)
        with open(dest, "wb") as f:
            f.write(data)
        return f"/uploads/{bucket}/{path}"

    async def signed_urls(
        self, bucket: str, paths: list[str], expires_in: int
    ) -> dict[str, str | None]:
        # Local development has no file server for uploads, so there is no
        # link to give; the app shows its placeholder instead.
        return {p: None for p in paths}

    async def delete_folder(self, bucket: str, prefix: str) -> int:
        base = self._base_dir.resolve()
        bucket_dir = (base / bucket).resolve()
        folder = (bucket_dir / prefix).resolve()
        if folder == bucket_dir or not folder.is_relative_to(bucket_dir):
            raise ValueError("Refusing to delete outside one folder of the bucket.")
        if not folder.is_dir():
            return 0
        removed = 0
        for f in sorted(folder.rglob("*"), reverse=True):
            if f.is_file():
                f.unlink()
                removed += 1
            elif f.is_dir():
                f.rmdir()
        folder.rmdir()
        return removed

    async def delete_object(self, bucket: str, path: str) -> None:
        base = self._base_dir.resolve()
        bucket_dir = (base / bucket).resolve()
        target = (bucket_dir / path).resolve()
        if not target.is_relative_to(bucket_dir) or target == bucket_dir:
            raise ValueError("Refusing to delete outside the bucket.")
        target.unlink(missing_ok=True)


def _row_to_profile(row: sqlite3.Row) -> UserProfile:
    def _parse_list(val: Any) -> list:
        if not val:
            return []
        if isinstance(val, list):
            return val
        try:
            return json.loads(val)
        except Exception:
            return []

    conditions_raw = _parse_list(row["health_conditions"])
    dietary_raw = _parse_list(row["dietary_preferences"])
    goals_raw = _parse_list(row["health_goals"])

    # `row[key]` raises on sqlite3.Row when the column is missing (pre-migration
    # DB file). Fall back to 0 so we never crash reading an older row.
    try:
        avoid_caffeine = bool(row["avoid_caffeine"])
    except (IndexError, KeyError):
        avoid_caffeine = False

    def _col(name: str) -> Any:
        try:
            return row[name]
        except (IndexError, KeyError):
            return None

    sex = _col("sex")
    activity = _col("activity_level")

    return UserProfile(
        user_id=row["user_id"],
        name=row["name"],
        health_conditions=[
            HealthCondition(c) for c in conditions_raw
            if c in HealthCondition._value2member_map_
        ],
        allergies=_parse_list(row["allergies"]),
        dietary_preferences=[
            DietaryPreference(d) for d in dietary_raw
            if d in DietaryPreference._value2member_map_
        ],
        health_goals=[
            HealthGoal(g) for g in goals_raw
            if g in HealthGoal._value2member_map_
        ],
        avoid_caffeine=avoid_caffeine,
        height_cm=_col("height_cm"),
        weight_kg=_col("weight_kg"),
        target_weight_kg=_col("target_weight_kg"),
        birth_year=_col("birth_year"),
        sex=Sex(sex) if sex in Sex._value2member_map_ else None,
        activity_level=(
            ActivityLevel(activity) if activity in ActivityLevel._value2member_map_ else None
        ),
        created_at=datetime.fromisoformat(row["created_at"]) if row["created_at"] else None,
        updated_at=datetime.fromisoformat(row["updated_at"]) if row["updated_at"] else None,
    )
