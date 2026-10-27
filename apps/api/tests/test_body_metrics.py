"""Body details on the profile: stored as given, BMI calculated, never guessed."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient
from pydantic import ValidationError

from src.config.dependencies import get_supabase_provider
from src.domain.models import UserProfile
from src.main import app
from src.providers.local_db_provider import LocalDBProvider
from src.services.body_metrics import bmi, bmi_category


def test_bmi_is_weight_over_height_squared():
    assert bmi(height_cm=170, weight_kg=65) == 22.5
    assert bmi(height_cm=160, weight_kg=72) == 28.1


def test_bmi_unknown_without_both_values():
    assert bmi(height_cm=None, weight_kg=65) is None
    assert bmi(height_cm=170, weight_kg=None) is None


@pytest.mark.parametrize(
    "value, band",
    [(18.4, "underweight"), (18.5, "normal"), (22.9, "normal"),
     (23.0, "overweight"), (24.9, "overweight"), (25.0, "obese"), (31.2, "obese")],
)
def test_asian_indian_bmi_bands(value, band):
    assert bmi_category(value) == band


def test_profile_exposes_calculated_bmi():
    p = UserProfile(user_id="u", height_cm=170, weight_kg=65)
    assert p.bmi == 22.5
    assert p.bmi_category == "normal"
    assert UserProfile(user_id="u").bmi is None


@pytest.mark.parametrize(
    "field, value",
    [("height_cm", 20), ("height_cm", 300), ("weight_kg", 5), ("weight_kg", 400),
     ("target_weight_kg", 0), ("birth_year", 1850), ("birth_year", 2999)],
)
def test_impossible_values_are_rejected(field, value):
    with pytest.raises(ValidationError):
        UserProfile(user_id="u", **{field: value})


@pytest.fixture
def db(tmp_path):
    provider = LocalDBProvider(db_path=str(tmp_path / "t.db"))
    app.dependency_overrides[get_supabase_provider] = lambda: provider
    yield provider
    app.dependency_overrides.clear()


async def test_body_details_round_trip_through_the_api(db, make_device):
    _, headers = make_device()
    body = {
        "name": "Suhail",
        "health_goals": ["weight_loss"],
        "height_cm": 172,
        "weight_kg": 80,
        "target_weight_kg": 72,
        "birth_year": 1998,
        "sex": "male",
        "activity_level": "light",
    }
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        r = await client.put("/api/v1/profile", json=body, headers=headers)
        assert r.status_code == 200
        again = (await client.get("/api/v1/profile", headers=headers)).json()

    for key in ("height_cm", "weight_kg", "target_weight_kg", "birth_year", "sex", "activity_level"):
        assert again[key] == body[key]
    assert again["bmi"] == 27.0
    assert again["bmi_category"] == "obese"


async def test_unknown_sex_or_activity_is_rejected(db, make_device):
    _, headers = make_device()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        r = await client.put("/api/v1/profile", json={"sex": "robot"}, headers=headers)
    assert r.status_code == 422


async def test_an_old_profile_without_body_details_still_loads(db, make_device):
    user_id, headers = make_device()
    await db.upsert_profile(UserProfile(user_id=user_id, name="Old"))
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        got = (await client.get("/api/v1/profile", headers=headers)).json()
    assert got["name"] == "Old"
    assert got["height_cm"] is None and got["bmi"] is None
