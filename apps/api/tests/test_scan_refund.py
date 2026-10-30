"""A scan that fails on our side doesn't use up one of the day's scans
(readiness review C)."""

from __future__ import annotations

import io
from datetime import datetime, timezone

from httpx import ASGITransport, AsyncClient

from src.config.dependencies import get_scan_limiter
from src.domain.models import ProductObservation, UserProfile
from src.main import app
from src.providers.interfaces import ServiceUnavailable
from src.services.rate_limit import ScanLimiter, SupabaseCounterStore
from types import SimpleNamespace

import pytest

from src.config.dependencies import get_gemini_provider, get_storage_provider, get_supabase_provider
from src.providers.local_db_provider import LocalDBProvider, LocalStorageProvider
from tests.test_production_hardening import JPEG, SCANS, LabelGemini


@pytest.fixture
def wired(tmp_path):
    """The app on a fresh local DB and storage, with a chosen Gemini fake."""
    db = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    storage = LocalStorageProvider(base_dir=str(tmp_path / "uploads"))
    state = SimpleNamespace(db=db, storage=storage, gemini=LabelGemini())
    app.dependency_overrides[get_supabase_provider] = lambda: state.db
    app.dependency_overrides[get_storage_provider] = lambda: state.storage
    app.dependency_overrides[get_gemini_provider] = lambda: state.gemini
    yield state
    for dep in (get_supabase_provider, get_storage_provider, get_gemini_provider, get_scan_limiter):
        app.dependency_overrides.pop(dep, None)


def _today_count(db, user_id):
    today = datetime.now(timezone.utc).date().isoformat()
    with db._get_connection() as conn:
        row = conn.execute("SELECT scan_count FROM scan_usage WHERE user_id = ? AND usage_date = ?",
                           (user_id, today)).fetchone()
    return row["scan_count"] if row else 0


async def _post(headers, data=JPEG):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        return await c.post(SCANS, headers=headers, files={"photo": ("p.jpg", io.BytesIO(data), "image/jpeg")})


def _cap(wired, n=5):
    app.dependency_overrides[get_scan_limiter] = lambda: ScanLimiter(cap=n, store=SupabaseCounterStore(wired.db))


async def test_an_ai_outage_gives_the_scan_back(wired, make_device):
    user_id, headers = make_device()
    await wired.db.upsert_profile(UserProfile(user_id=user_id))
    _cap(wired)
    wired.gemini = LabelGemini(fail=ServiceUnavailable("The AI service is unavailable."))
    r = await _post(headers)
    assert r.status_code == 503
    assert _today_count(wired.db, user_id) == 0


async def test_a_file_that_isnt_a_photo_gives_the_scan_back(wired, make_device):
    user_id, headers = make_device()
    _cap(wired)
    r = await _post(headers, data=b"not an image at all")
    assert r.status_code == 422
    assert _today_count(wired.db, user_id) == 0


async def test_a_successful_scan_counts(wired, make_device):
    user_id, headers = make_device()
    await wired.db.upsert_profile(UserProfile(user_id=user_id))
    _cap(wired)
    r = await _post(headers)
    assert r.status_code == 200
    assert _today_count(wired.db, user_id) == 1


async def test_a_label_with_too_little_on_it_still_counts(wired, make_device):
    # It ran a real AI call; refunding it would make junk uploads free.
    user_id, headers = make_device()
    await wired.db.upsert_profile(UserProfile(user_id=user_id))
    _cap(wired)
    wired.gemini = LabelGemini(product=ProductObservation(insufficient_data=True))
    r = await _post(headers)
    assert r.status_code == 200 and r.json()["insufficient_data"] is True
    assert _today_count(wired.db, user_id) == 1


async def test_over_the_cap_is_not_given_back(wired, make_device):
    user_id, headers = make_device()
    await wired.db.upsert_profile(UserProfile(user_id=user_id))
    _cap(wired, n=1)
    assert (await _post(headers)).status_code == 200
    assert (await _post(headers)).status_code == 429
    assert _today_count(wired.db, user_id) == 2  # still over: the next one is refused too
    assert (await _post(headers)).status_code == 429


async def test_a_failing_refund_doesnt_hide_the_real_error(wired, make_device):
    user_id, headers = make_device()
    await wired.db.upsert_profile(UserProfile(user_id=user_id))
    _cap(wired)

    async def broken(_):
        raise ConnectionError("db down")
    wired.db.refund_scan_usage = broken
    wired.gemini = LabelGemini(fail=ServiceUnavailable("The AI service is unavailable."))
    r = await _post(headers)
    assert r.status_code == 503 and "AI" in r.json()["detail"]


async def test_a_scan_is_not_saved_if_consent_is_withdrawn_mid_scan(wired, make_device, monkeypatch):
    """If the user deletes their data while a scan is running, consent is
    withdrawn. The scan must not recreate the profile or save a row behind the
    delete, and its uploaded photo must not be left behind (DPDP erasure)."""
    user_id, headers = make_device()
    await wired.db.upsert_profile(UserProfile(user_id=user_id))
    _cap(wired)

    async def _withdrawn(self, uid, ver):  # consent gone by the time we persist
        return False
    monkeypatch.setattr(LocalDBProvider, "has_consent", _withdrawn)

    r = await _post(headers)
    assert r.status_code == 200
    body = r.json()
    assert body["saved"] is False
    assert await wired.db.get_scan(user_id, body["scan_id"]) is None
    assert await wired.db.get_scan_history(user_id) == []
    user_dir = wired.storage._base_dir / "calfit-scans" / "scans" / user_id
    assert not user_dir.exists() or not any(user_dir.iterdir())


# --- a retry with the same Idempotency-Key returns the first scan -------------


async def _post_keyed(headers, key, data=JPEG):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        return await c.post(SCANS, headers={**headers, "Idempotency-Key": key},
                            files={"photo": ("p.jpg", io.BytesIO(data), "image/jpeg")})


async def test_a_retry_returns_the_first_scan_without_running_or_counting(wired, make_device):
    import uuid

    user_id, headers = make_device()
    await wired.db.upsert_profile(UserProfile(user_id=user_id))
    _cap(wired)
    key = str(uuid.uuid4())
    first = await _post_keyed(headers, key)
    assert first.status_code == 200 and first.json()["scan_id"] == key
    calls = len(wired.gemini.seen_photos)

    again = await _post_keyed(headers, key)
    assert again.status_code == 200 and again.json()["scan_id"] == key
    assert len(wired.gemini.seen_photos) == calls  # not read again
    assert _today_count(wired.db, user_id) == 1  # not counted again
    assert len(await wired.db.get_scan_history(user_id)) == 1


async def test_someone_elses_scan_id_as_a_key_reveals_nothing(wired, make_device):
    import uuid

    owner, owner_h = make_device()
    other, other_h = make_device()
    for u in (owner, other):
        await wired.db.upsert_profile(UserProfile(user_id=u))
    key = str(uuid.uuid4())
    assert (await _post_keyed(owner_h, key)).status_code == 200
    r = await _post_keyed(other_h, key)  # replay lookup is per user: no copy of owner's scan
    assert r.status_code == 200
    assert r.json().get("saved") is False  # the id is taken, so this one isn't stored
    assert len(await wired.db.get_scan_history(other)) == 0


async def test_a_key_that_isnt_a_uuid_is_refused(wired, make_device):
    _, headers = make_device()
    assert (await _post_keyed(headers, "'; drop table scans; --")).status_code == 422
