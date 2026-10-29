"""The 2026-10-29 hardening pass: each test pins one audited failure.

Spec: .10x/specs/2026-10-29-production-hardening.md (ids in brackets).
"""

from __future__ import annotations

import io
import logging
from types import SimpleNamespace

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from src.config import dependencies
from src.config.dependencies import get_gemini_provider, get_storage_provider, get_supabase_provider
from src.config.settings import Settings, settings
from src.domain.models import (
    HealthCondition,
    HealthGoal,
    NutritionInfo,
    ProductObservation,
    SuitabilityStatus,
    UserProfile,
)
from src.domain.rule_catalog import RULE_ERROR_CAP
from src.domain.scoring_rules import _suitability_from_score, calculate_score
from src.main import app
from src.observability import request_context_middleware
from src.orchestration import scan_graph
from src.providers import gemini_provider
from src.providers.food_lookup import LookupUnavailable, OpenFoodFactsLookup
from src.providers.interfaces import GeminiProvider, ServiceUnavailable
from src.providers.local_db_provider import LocalDBProvider, LocalStorageProvider
from src.providers.supabase_provider import SupabaseDBProvider
from src.services.client_ip import client_ip
from src.services.rate_limit import InMemoryStore, ScanLimiter

JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00"
SCANS = "/api/v1/scans"


class LabelGemini(GeminiProvider):
    """Reads a fixed peanut-containing label."""

    def __init__(self, fail: Exception | None = None,
                 product: ProductObservation | None = None) -> None:
        self.fail, self.product, self.seen_photos = fail, product, []

    async def analyze_photo(self, photo_bytes, mime_type="image/jpeg"):
        self.seen_photos.append(photo_bytes)
        if self.fail:
            raise self.fail
        return self.product or ProductObservation(
            product_name="Peanut bar", ingredients=["peanuts", "sugar"],
            allergens_declared=["peanut"],
            nutrition=NutritionInfo(serving_size_g=40, sugars_g=8),
            extraction_confidence=0.95)

    async def analyze_prescription(self, photo_bytes, mime_type="image/jpeg"):
        raise NotImplementedError

    async def generate_explanation(self, messages):
        return "Contains peanuts, which you are allergic to."


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
    app.dependency_overrides.clear()


async def _scan(headers, data=JPEG, mime="image/jpeg"):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        return await c.post(SCANS, headers=headers, files={"photo": ("p.jpg", io.BytesIO(data), mime)})


# --- [A] a profile that failed to load is never scored as an empty one -------


async def test_profile_load_failure_is_a_503_not_an_unprotected_score(wired, make_device):
    user_id, headers = make_device()
    await wired.db.upsert_profile(UserProfile(user_id=user_id, allergies=["peanut"]))

    async def broken(_):
        raise ConnectionError("supabase blip")
    wired.db.get_profile = broken

    r = await _scan(headers)
    assert r.status_code == 503
    assert "health profile" in r.json()["detail"]
    assert await wired.db.get_scan_history(user_id) == []  # nothing scored, nothing saved


# --- [Y] an AI outage is a 503, not "take a clearer photo" -------------------


async def test_gemini_outage_is_a_503(wired, make_device):
    _, headers = make_device()
    wired.gemini = LabelGemini(fail=ServiceUnavailable("The AI service is unavailable."))
    r = await _scan(headers)
    assert r.status_code == 503 and r.headers["retry-after"]
    assert "clearer" not in r.json()["detail"]


# --- a database that doesn't answer is a 503, and its URL stays in the server -


async def test_database_timeout_is_a_503_without_upstream_details(wired, make_device):
    import httpx

    _, headers = make_device()

    async def timeout(*_a, **_k):
        raise httpx.ConnectTimeout("connect to https://secret-ref.supabase.co timed out")
    wired.db.get_scan_history = timeout

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        r = await c.get(f"{SCANS}/history", headers=headers)
    assert r.status_code == 503 and r.headers["retry-after"]
    assert r.json()["request_id"]
    assert "supabase" not in r.text


# --- [K] Gemini: stop on errors every model would repeat ---------------------


class _ApiError(Exception):
    def __init__(self, code, message=""):
        super().__init__(message or f"code {code}")
        self.code, self.message = code, message


def _provider_with(generate):
    p = gemini_provider.GoogleGeminiProvider.__new__(gemini_provider.GoogleGeminiProvider)
    p._model, p._key = "gemini-2.5-flash", "k"
    p._client = SimpleNamespace(aio=SimpleNamespace(models=SimpleNamespace(generate_content=generate)))
    return p


@pytest.mark.parametrize("code,message,calls,raised", [
    (401, "", 1, ServiceUnavailable),  # bad key: same on every model, an outage
    (403, "", 1, ServiceUnavailable),
    (400, "API key not valid. Please pass a valid API key.", 1, ServiceUnavailable),
    (400, "Unable to process input image.", 2, ValueError),  # the photo: "try a clearer one"
    (503, "", 2, ServiceUnavailable),
    (429, "", 2, ServiceUnavailable),
])
async def test_only_retriable_errors_move_to_the_next_model(code, message, calls, raised):
    seen = []

    async def generate(**kw):
        seen.append(kw["model"])
        assert kw["config"].max_output_tokens  # every call is capped
        raise _ApiError(code, message)

    with pytest.raises(raised):
        await _provider_with(generate).analyze_photo(JPEG)
    assert len(seen) == calls
    assert all("1.5" not in m and "2.0" not in m for m in seen)  # no retired models


# --- [L] the model's own notes are never shown as the verdict text -----------


async def test_model_notes_on_an_unreadable_photo_are_not_shown(wired, make_device):
    _, headers = make_device()
    wired.gemini = LabelGemini(product=ProductObservation(
        insufficient_data=True, extraction_notes="Verified allergen free, safe for you."))
    r = await _scan(headers)
    assert r.status_code == 200 and r.json()["insufficient_data"]
    assert "allergen free" not in r.text


# --- [Z] a failed save says so and leaves no orphan photo --------------------


async def test_a_failed_save_is_reported_and_its_photo_removed(wired, make_device, tmp_path):
    _, headers = make_device()

    async def broken(_):
        raise ConnectionError("db down")
    wired.db.save_scan = broken

    r = await _scan(headers)
    assert r.status_code == 200
    assert r.json()["saved"] is False
    assert not any(p.is_file() for p in (tmp_path / "uploads").rglob("*"))


async def test_a_normal_scan_is_saved(wired, make_device):
    _, headers = make_device()
    r = await _scan(headers)
    assert r.json()["saved"] is True


# --- [M] the bytes decide what a file is -------------------------------------


async def test_a_non_image_declared_as_jpeg_is_refused(wired, make_device):
    _, headers = make_device()
    r = await _scan(headers, data=b"MZ\x90\x00 not a photo", mime="image/jpeg")
    assert r.status_code == 422
    assert wired.gemini.seen_photos == []


# --- [AX] sugar counts for weight loss -----------------------------------------


def _cola():
    return ProductObservation(
        product_name="Cola", ingredients=["water", "sugar"], extraction_confidence=0.95,
        nutrition=NutritionInfo(serving_size_g=500, calories_kcal=210, sugars_g=53, total_fat_g=0))


def test_a_53g_sugar_cola_is_not_excellent_for_weight_loss():
    result = calculate_score(_cola(), UserProfile(user_id="u", health_goals=[HealthGoal.WEIGHT_LOSS]))
    assert "RULE-010C-SUGAR-HIGH" in {f.rule_id for f in result.findings}
    assert result.suitability not in (SuitabilityStatus.EXCELLENT, SuitabilityStatus.GOOD)


def test_sugar_is_not_counted_twice_for_a_diabetic_on_weight_loss():
    user = UserProfile(user_id="u", health_goals=[HealthGoal.WEIGHT_LOSS],
                       health_conditions=[HealthCondition.DIABETES_TYPE_2])
    ids = {f.rule_id for f in calculate_score(_cola(), user).findings}
    assert "RULE-010C-SUGAR-HIGH" not in ids and "RULE-003A-SUGAR-EXTREME" in ids


def test_a_crashed_check_can_never_read_excellent():  # [BA] the cap tracks the bands
    assert _suitability_from_score(RULE_ERROR_CAP) != SuitabilityStatus.EXCELLENT


# --- [Q] prescriptions never reach a tier that may train on them ------------


@pytest.mark.parametrize("backend,confirmed,allowed", [
    ("developer_api", False, False), ("developer_api", True, True), ("vertex", False, True)])
def test_prescriptions_need_vertex_or_a_confirmed_paid_tier(backend, confirmed, allowed):
    s = Settings(_env_file=None, PRESCRIPTION_AI_ENABLED=True, GEMINI_BACKEND=backend,
                 GEMINI_PAID_TIER_CONFIRMED=confirmed)
    assert s.prescription_ai_allowed is allowed


async def test_prescription_endpoint_is_off_on_an_unconfirmed_tier(wired, monkeypatch, make_device):
    monkeypatch.setattr(settings, "PRESCRIPTION_AI_ENABLED", True)
    monkeypatch.setattr(settings, "GEMINI_BACKEND", "developer_api")
    monkeypatch.setattr(settings, "GEMINI_PAID_TIER_CONFIRMED", False)
    _, headers = make_device()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        r = await c.post("/api/v1/profile/prescription-suggestions", headers=headers,
                         files={"photo": ("p.jpg", io.BytesIO(JPEG), "image/jpeg")})
    assert r.status_code == 503


# --- [P, R] production refuses to start misconfigured ------------------------


def test_production_refuses_missing_or_weak_config():
    s = Settings(_env_file=None, APP_ENV="production", AUTH_SECRET_KEY="s3cr3t-value")
    with pytest.raises(RuntimeError) as err:
        s.validate_for_production()
    for name in ("AUTH_SECRET_KEY", "SUPABASE_URL", "GEMINI_API_KEY"):
        assert name in str(err.value)
    assert "s3cr3t-value" not in str(err.value)  # names, never values
    Settings(_env_file=None, AUTH_SECRET_KEY="s3cr3t-value").validate_for_production()  # dev: fine


def test_production_never_falls_back_to_local_sqlite(monkeypatch):
    monkeypatch.setattr(settings, "APP_ENV", "production")
    with pytest.raises(RuntimeError, match="Supabase"):
        get_supabase_provider()
    with pytest.raises(RuntimeError, match="Supabase"):
        get_storage_provider()


# --- [T] one client per process ------------------------------------------------


def test_supabase_provider_is_shared_between_requests(monkeypatch):
    monkeypatch.setattr(settings, "SUPABASE_URL", "https://x.supabase.co")
    monkeypatch.setattr(settings, "SUPABASE_SERVICE_ROLE_KEY", "k")
    monkeypatch.setattr(dependencies, "_shared", {})
    assert get_supabase_provider() is get_supabase_provider()
    assert get_storage_provider() is get_storage_provider()


# --- [C] the registration cap keys on the real client --------------------------


def _req(peer, xff=None):
    return SimpleNamespace(client=SimpleNamespace(host=peer),
                           headers={"x-forwarded-for": xff} if xff else {})


def test_client_ip_trusts_only_what_our_proxy_appended():
    assert client_ip(_req("10.0.0.1", "6.6.6.6"), 0) == "10.0.0.1"  # local: the socket
    assert client_ip(_req("10.0.0.1", "6.6.6.6, 203.0.113.9"), 1) == "203.0.113.9"
    assert client_ip(_req("10.0.0.1"), 1) == "10.0.0.1"  # no header: not behind it


async def test_forged_forwarded_for_does_not_dodge_the_cap(monkeypatch):
    monkeypatch.setattr(settings, "TRUSTED_PROXY_HOPS", 1)
    monkeypatch.setattr(settings, "AUTH_SECRET_KEY", "x" * 40)
    monkeypatch.setattr(dependencies, "_token_issue_limiter",
                        ScanLimiter(cap=2, store=InMemoryStore()))
    codes = []
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        for n in range(3):  # a new forged prefix each time, same real client
            r = await c.post("/api/v1/auth/device",
                             headers={"x-forwarded-for": f"1.1.1.{n}, 198.51.100.7"})
            codes.append(r.status_code)
    assert codes == [200, 200, 429]


# --- [D] oversized and anonymous uploads are refused before parsing -----------


async def test_uploads_without_a_token_or_over_the_limit_are_refused_unread(wired, make_device):
    _, headers = make_device()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        anon = await c.post(SCANS, files={"photo": ("p.jpg", io.BytesIO(JPEG), "image/jpeg")})
        huge = await c.post(SCANS, headers={**headers, "content-length": str(50 * 1024 * 1024)},
                            content=b"x")
        big_json = await c.put("/api/v1/profile", headers=headers, content=b"{" + b" " * 70_000 + b"}")
    assert anon.status_code == 401
    assert huge.status_code == 413
    assert big_json.status_code == 413
    assert wired.gemini.seen_photos == []


async def test_a_chunked_body_over_the_limit_is_a_413_through_fastapi(make_device):
    """No Content-Length: counted while FastAPI reads it, and still a 413
    (FastAPI turns other errors raised while reading a body into a 400)."""
    _, headers = make_device()

    async def chunks():
        for _ in range(3):
            yield b" " * 30_000

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        r = await c.put("/api/v1/profile", headers={**headers, "content-type": "application/json"},
                        content=chunks())
    assert r.status_code == 413


async def test_a_body_without_content_length_is_counted():
    from src.body_limit import BodyLimitMiddleware

    async def app_reads(scope, receive, send):
        while (await receive()).get("more_body"):
            pass
        await send({"type": "http.response.start", "status": 200, "headers": []})
        await send({"type": "http.response.body", "body": b""})

    chunks = [{"type": "http.request", "body": b"x" * 40_000, "more_body": True}] * 3
    sent = []

    async def receive():
        return chunks.pop(0)

    async def send(m):
        sent.append(m)

    mw = BodyLimitMiddleware(app_reads, max_upload_bytes=10)
    await mw({"type": "http", "path": "/api/v1/profile", "method": "PUT", "headers": []},
             receive, send)
    assert sent[0]["status"] == 413


# --- [E] profile text is bounded -----------------------------------------------


@pytest.mark.parametrize("body", [
    {"allergies": ["peanut"] * 31},
    {"allergies": ["x" * 61]},
    {"allergies": ["  "]},
    {"name": "n" * 81},
])
async def test_profile_limits(body, make_device):
    _, headers = make_device()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        r = await c.put("/api/v1/profile", headers=headers, json=body)
    assert r.status_code == 422


# --- [G] a non-ASCII token is a 401, not a 500 ---------------------------------


async def test_non_ascii_token_signature_is_rejected_cleanly(auth_secret):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        r = await c.get("/api/v1/scans/stats",
                        headers={"Authorization": b"Bearer v1." + b"a" * 32 + b".\xff"})
    assert r.status_code == 401


# --- [AA] an unhandled error still answers JSON with the request id ----------


async def test_unhandled_errors_carry_the_request_id(caplog):
    mini = FastAPI()
    mini.middleware("http")(request_context_middleware)

    @mini.get("/boom")
    async def boom():
        raise RuntimeError("user has diabetes")

    async with AsyncClient(transport=ASGITransport(app=mini), base_url="http://test") as c:
        r = await c.get("/boom")
    assert r.status_code == 500
    assert r.json()["request_id"] == r.headers["x-request-id"]
    assert "diabetes" not in caplog.text


# --- [N] Open Food Facts calls stay under its per-IP budget --------------------


async def test_lookup_stops_calling_when_the_minute_budget_is_used():
    calls = []

    class Client:
        async def get(self, url, **kw):
            calls.append(url)
            return SimpleNamespace(status_code=200, json=lambda: {"hits": []})

    lookup = OpenFoodFactsLookup("test", client=Client())
    for n in range(lookup.CALLS_PER_MINUTE):
        await lookup.search(f"query {n}")
    with pytest.raises(LookupUnavailable):
        await lookup.search("one too many")
    assert len(calls) == lookup.CALLS_PER_MINUTE


# --- [AL, H] Supabase provider: knowledge filtering and quiet logs -------------


class _Query:
    def __init__(self, rows=None, fail=None):
        self.rows, self.fail, self.limits = rows or [], fail, []

    def __getattr__(self, _name):
        return lambda *a, **k: self

    def limit(self, n):
        self.limits.append(n)
        return self

    async def execute(self):
        if self.fail:
            raise self.fail
        return SimpleNamespace(data=self.rows)


def _supabase_with(query):
    p = SupabaseDBProvider(url="https://x.supabase.co", key="k")
    p._client = SimpleNamespace(table=lambda _name: query)
    return p


async def test_knowledge_rows_past_the_first_ten_can_match():
    rows = [{"id": n, "topic": f"t{n}", "content": "c", "relevance_tags": ["other"]} for n in range(12)]
    rows[11]["relevance_tags"] = ["fibre"]
    query = _Query(rows)
    found = await _supabase_with(query).query_knowledge_by_tags(["fibre"])
    assert [k.id for k in found] == [11]
    assert query.limits[0] > 10


async def test_database_errors_do_not_write_profile_values_to_logs(caplog):
    query = _Query(fail=RuntimeError('Failing row contains (u1, diabetes, peanut)'))
    with pytest.raises(RuntimeError):
        await _supabase_with(query).upsert_profile(
            UserProfile(user_id="u1", allergies=["peanut"]))
    assert "diabetes" not in caplog.text and "peanut" not in caplog.text


# --- [AZ] the rule-summary fallback uses the score out of 10 ------------------


async def test_explanation_fallback_says_out_of_10(monkeypatch):
    class Boom:
        def __init__(self, *_):
            raise RuntimeError("no explanation service")

    monkeypatch.setattr(scan_graph, "ExplanationService", Boom)
    state = scan_graph.ScanState(user_id="u", photo_bytes=b"", score_result=calculate_score(
        _cola(), UserProfile(user_id="u")))
    out = await scan_graph.node_generate_explanation(state, gemini=None)
    assert "out of 10" in out["explanation"] and "/100" not in out["explanation"]


# --- [AY] every API route needs a token, except the few that must not ---------

PUBLIC = {"/api/v1/health", "/api/v1/auth/device", "/api/v1/openapi.json"}


async def test_every_api_route_requires_a_token(caplog):
    caplog.set_level(logging.CRITICAL)
    checked = 0
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        # The schema, not app.routes: FastAPI 0.162 keeps included routers nested.
        for path, operations in app.openapi()["paths"].items():
            if not path.startswith("/api/v1") or path in PUBLIC:
                continue
            url = path.replace("{scan_id}", "00000000-0000-0000-0000-000000000000")
            for method in operations:
                r = await c.request(method.upper(), url)
                assert r.status_code == 401, (method, path, r.status_code)
                checked += 1
    assert checked >= 13


# --- heart-health goal checks salt (MARKET_READY_CHECKLIST scoring follow-up) ---


def test_heart_health_goal_flags_high_sodium():
    noodles = ProductObservation(
        product_name="Instant noodles", ingredients=["wheat flour", "salt"], extraction_confidence=0.95,
        nutrition=NutritionInfo(serving_size_g=70, sodium_mg=1200, saturated_fat_g=1))
    result = calculate_score(noodles, UserProfile(user_id="u", health_goals=[HealthGoal.HEART_HEALTH]))
    assert any(f.nutrient_or_ingredient == "sodium" for f in result.findings)
    assert result.suitability in (SuitabilityStatus.POOR, SuitabilityStatus.NOT_SUITABLE)


# --- ADR-007: a rating is history; editing the profile never changes it --------


async def test_past_ratings_keep_the_profile_they_were_scored_for(wired, make_device):
    user_id, headers = make_device()
    await wired.db.upsert_profile(UserProfile(user_id=user_id, allergies=["peanut"]))
    scanned = (await _scan(headers)).json()
    assert scanned["score_result"]["score"] == 0  # peanut bar, peanut allergy
    assert scanned["score_result"]["scored_for"]["allergies"] == ["peanut"]

    await wired.db.upsert_profile(UserProfile(user_id=user_id))  # allergy removed later

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        detail = (await c.get(f"{SCANS}/{scanned['scan_id']}", headers=headers)).json()
        history = (await c.get(f"{SCANS}/history", headers=headers)).json()
    assert detail["score_result"]["score"] == 0
    assert detail["score_result"]["scored_for"]["allergies"] == ["peanut"]
    assert history[0]["score"] == 0


# --- data minimisation: the AI gets the findings, never the profile -----------


async def test_the_explanation_prompt_holds_no_profile_beyond_the_findings():
    from src.services.explanation_service import ExplanationService

    sent = []

    class Capture(LabelGemini):
        async def generate_explanation(self, messages):
            sent.append(" ".join(m["content"] for m in messages))
            return "Contains peanut, which you are allergic to."

    user = UserProfile(user_id="u-secret-id", name="Sharon", birth_year=1990, weight_kg=70,
                       allergies=["peanut"],
                       health_conditions=[HealthCondition.LACTOSE_INTOLERANCE, HealthCondition.ANAEMIA])
    bar = ProductObservation(product_name="Peanut bar", ingredients=["peanuts"], allergens_declared=["peanut"],
                             nutrition=NutritionInfo(serving_size_g=40, sugars_g=2), extraction_confidence=0.95)
    await ExplanationService(Capture()).explain(bar, calculate_score(bar, user), user)
    prompt = sent[0].lower()
    assert "peanut" in prompt                      # the finding this product triggers
    for private in ("sharon", "1990", "u-secret-id", "lactose", "anaemia", "70"):
        assert private not in prompt, private      # identity and unrelated conditions never leave


# --- general request cap (every route) ---------------------------------------


async def test_one_caller_is_capped_per_hour_and_told_when_to_retry():
    from src.request_limit import RequestLimitMiddleware

    async def ok(scope, receive, send):
        await send({"type": "http.response.start", "status": 200, "headers": []})
        await send({"type": "http.response.body", "body": b""})

    mw = RequestLimitMiddleware(ok, per_token=3, per_ip=100, trusted_proxy_hops=0)
    statuses = []

    async def call(token, ip="1.2.3.4", path="/api/v1/scans/history"):
        sent = []

        async def send(m):
            sent.append(m)
        scope = {"type": "http", "path": path, "client": (ip, 1),
                 "headers": [(b"authorization", f"Bearer {token}".encode())]}
        await mw(scope, None, send)
        return sent[0]

    for _ in range(4):
        statuses.append((await call("tok-a"))["status"])
    assert statuses == [200, 200, 200, 429]
    assert dict((await call("tok-a"))["headers"])[b"retry-after"]
    assert (await call("tok-b"))["status"] == 200          # another install is unaffected
    for _ in range(10):
        assert (await call("tok-a", path="/health"))["status"] == 200  # probes never count

    shared = RequestLimitMiddleware(ok, per_token=1000, per_ip=5, trusted_proxy_hops=0)
    mw = shared
    codes = [(await call(f"t{n}", ip="9.9.9.9"))["status"] for n in range(6)]
    assert codes[-1] == 429                                  # one address hammering is capped too
