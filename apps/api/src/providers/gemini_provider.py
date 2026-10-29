"""Gemini provider implementation using google-genai SDK."""

from __future__ import annotations

import json
import logging
import re
from typing import Any

from google import genai
from google.genai import types

from src.config.settings import settings
from src.domain.models import NutritionInfo, ProductObservation
from src.domain.prescription import AllergyKind, PrescriptionObservation, StatedAllergy
from src.observability import note
from src.prompts.extraction import EXTRACTION_USER_INSTRUCTION, build_extraction_prompt
from src.prompts.prescription_extraction import (
    PRESCRIPTION_USER_INSTRUCTION,
    build_prescription_prompt,
)
from src.providers.interfaces import GeminiProvider, ServiceUnavailable

logger = logging.getLogger(__name__)

# Real, generally-available Gemini models, newest first. Keep names in sync with
# https://ai.google.dev/gemini-api/docs/models — the SDK rejects fictional names.
# Retired models only add a failing call (and its latency) to every fallback.
_FALLBACK_MODELS = [
    "gemini-2.5-flash",
    "gemini-3.5-flash-lite",  # correct but slow (19.5 s on a label, 2026-10-29): last resort
]

# A bad key (401) or no permission (403) fails the same way on every model:
# trying the next one only multiplies the cost and the wait. A 400 moves on
# (one model can reject a config field another accepts) unless it is about the
# key; if every model rejects the request, the photo itself is the problem.
# Anything else (429, 5xx, timeout, unreadable output) moves on too.
_SAME_ON_EVERY_MODEL = {401, 403}

# Output caps, thinking included. They bound what one call can cost; a label
# or prescription transcription and a short explanation fit well inside.
_MAX_READ_TOKENS = 8192
_MAX_EXPLANATION_TOKENS = 2048

_UNAVAILABLE = "The AI service is unavailable right now. Please try again in a few minutes."


def _is_key_error(exc: Exception) -> bool:
    # AI Studio answers an invalid key with 400 INVALID_ARGUMENT, not 401.
    return "api key" in str(getattr(exc, "message", "") or exc).lower()


def _fails_on_every_model(exc: Exception) -> bool:
    code = getattr(exc, "code", None)
    return code in _SAME_ON_EVERY_MODEL or (code == 400 and _is_key_error(exc))


def _give_up(last_exception: Exception | None) -> Exception:
    """Unusable output, or a request every model rejected (400), is the
    photo's problem: a ValueError, shown as "try a clearer photo". Anything
    else means the service is down: a 503."""
    if isinstance(last_exception, ValueError):
        return last_exception
    if last_exception is not None and getattr(last_exception, "code", None) == 400 \
            and not _is_key_error(last_exception):
        return ValueError("every model rejected the request (400)")
    return ServiceUnavailable(_UNAVAILABLE)


# Greedy decoding (temperature 0) plus a fixed seed: as repeatable as hosted
# models allow. Not bit-for-bit guaranteed; the score never depends on the
# model anyway (rules + score_formula.py), only the wording of explanations.
GENERATION_SEED = 7


class GoogleGeminiProvider(GeminiProvider):
    """Production Gemini provider implementing both photo analysis and text explanation."""

    def __init__(
        self,
        api_key: str = "",
        model: str = "",
        *,
        vertex_project: str = "",
        vertex_location: str = "",
    ) -> None:
        self._model = (model or getattr(settings, "GEMINI_MODEL", "gemini-2.5-flash")).strip()
        # Without a timeout one stuck call holds the request until Cloud Run
        # kills it, with every fallback model still to try.
        http_options = types.HttpOptions(timeout=settings.GEMINI_TIMEOUT_SECONDS * 1000)
        if vertex_project:
            # Vertex AI: the service account's credentials, a regional endpoint.
            self._key = ""
            self._client = genai.Client(
                vertexai=True, project=vertex_project, location=vertex_location,
                http_options=http_options,
            )
        else:
            self._key = (api_key or getattr(settings, "GEMINI_API_KEY", "")).strip()
            self._client = genai.Client(api_key=self._key, http_options=http_options)

    async def analyze_photo(
        self, photo_bytes: bytes, mime_type: str = "image/jpeg"
    ) -> ProductObservation:
        prompt = build_extraction_prompt()
        image_part = types.Part.from_bytes(data=photo_bytes, mime_type=mime_type)

        candidate_models = [self._model] + [m for m in _FALLBACK_MODELS if m != self._model]
        last_exception: Exception | None = None

        # A JSON Schema the model is required to return. Gemini treats it as a
        # hard constraint and refuses to add other keys, which replaces the old
        # regex-rescue parser as the primary path. The regex parser is still
        # called as a fallback for responses that slip through (older SDKs,
        # structured-output rejection, etc.).
        for attempt, model_name in enumerate(candidate_models, start=1):
            try:
                logger.info("Attempting photo analysis with model: %s", model_name)
                response = await self._client.aio.models.generate_content(
                    model=model_name,
                    contents=[image_part, EXTRACTION_USER_INSTRUCTION],
                    config=types.GenerateContentConfig(
                        system_instruction=prompt,
                        response_mime_type="application/json",
                        response_schema=_EXTRACTION_SCHEMA,
                        temperature=0.0,
                        seed=GENERATION_SEED,
                        max_output_tokens=_MAX_READ_TOKENS,
                    ),
                )
                raw_text = response.text or ""
                parsed = _parse_extraction_json(raw_text)
                observation = _dict_to_product_observation(parsed)
                note(model=model_name, model_attempts=attempt)
                return observation
            except Exception as exc:
                # Class name only: SDK errors can echo request content.
                logger.warning(
                    "Photo analysis with model %s failed: %s", model_name, type(exc).__name__)
                last_exception = exc
                if _fails_on_every_model(exc):
                    break

        note(model=None, model_attempts=attempt)
        logger.error(
            "Gemini photo analysis gave up. Last error: %s", type(last_exception).__name__)
        raise _give_up(last_exception)

    async def analyze_prescription(
        self, photo_bytes: bytes, mime_type: str = "image/jpeg"
    ) -> PrescriptionObservation:
        """Transcribe a prescription photo.

        Health data: neither the image, the model's text, nor exception text is
        logged (SDK errors can echo content). Only model name and exception class
        name reach the log.
        """
        image_part = types.Part.from_bytes(data=photo_bytes, mime_type=mime_type)
        candidate_models = [self._model] + [m for m in _FALLBACK_MODELS if m != self._model]
        last_exception: Exception | None = None

        for model_name in candidate_models:
            try:
                response = await self._client.aio.models.generate_content(
                    model=model_name,
                    contents=[image_part, PRESCRIPTION_USER_INSTRUCTION],
                    config=types.GenerateContentConfig(
                        system_instruction=build_prescription_prompt(),
                        response_mime_type="application/json",
                        response_schema=_PRESCRIPTION_SCHEMA,
                        temperature=0.0,
                        seed=GENERATION_SEED,
                        max_output_tokens=_MAX_READ_TOKENS,
                    ),
                )
                parsed = _parse_prescription_json(response.text or "")
                if parsed is None:
                    # A model failure, not a verdict on the photo: try the next model.
                    raise ValueError("unparseable prescription response")
                return _dict_to_prescription_observation(parsed)
            except Exception as exc:
                logger.warning(
                    "Prescription analysis with model %s failed: %s",
                    model_name,
                    type(exc).__name__,
                )
                last_exception = exc
                if _fails_on_every_model(exc):
                    break

        logger.error("Gemini prescription analysis gave up.")
        raise _give_up(last_exception)

    async def generate_explanation(self, messages: list[dict[str, str]]) -> str:
        """Generate clinical health explanation for nutritional suitability."""
        system_text = "\n\n".join(m.get("content", "") for m in messages if m.get("role") == "system")
        prompt_text = "\n\n".join(m.get("content", "") for m in messages if m.get("role") != "system")
        candidate_models = [self._model] + [m for m in _FALLBACK_MODELS if m != self._model]
        last_exception: Exception | None = None

        for attempt, model_name in enumerate(candidate_models, start=1):
            try:
                response = await self._client.aio.models.generate_content(
                    model=model_name,
                    contents=prompt_text,
                    config=types.GenerateContentConfig(
                        system_instruction=system_text or None,
                        temperature=0.0,
                        seed=GENERATION_SEED,
                        max_output_tokens=_MAX_EXPLANATION_TOKENS,
                    ),
                )
                note(explanation_model=model_name, explanation_attempts=attempt)
                return (response.text or "").strip()
            except Exception as exc:
                # The prompt holds health conditions; never log the error text.
                logger.warning(
                    "Explanation generation with model %s failed: %s",
                    model_name, type(exc).__name__,
                )
                last_exception = exc
                if _fails_on_every_model(exc):
                    break

        logger.error(
            "Gemini explanation gave up. Last error: %s", type(last_exception).__name__)
        raise _give_up(last_exception)


# ---------------------------------------------------------------------------
# Structured output schema
#
# Keep in sync with ProductObservation + NutritionInfo. Any mismatch here is a
# transcription key the model will omit, so missing data stays missing rather
# than being silently invented. One source of truth: the catalogue of fields
# documented in prompts/extraction.py.
# ---------------------------------------------------------------------------

_NUM = {"type": "NUMBER", "nullable": True}
_BOOL = {"type": "BOOLEAN"}
_STR_ARR = {"type": "ARRAY", "items": {"type": "STRING"}}

_EXTRACTION_SCHEMA: dict[str, Any] = {
    "type": "OBJECT",
    "properties": {
        "brand": {"type": "STRING", "nullable": True},
        "product_name": {"type": "STRING", "nullable": True},
        "category": {"type": "STRING", "nullable": True},
        "variant": {"type": "STRING", "nullable": True},
        "net_quantity": {"type": "STRING", "nullable": True},
        "mrp": {"type": "STRING", "nullable": True},
        "identity_confidence": {"type": "NUMBER", "nullable": True},
        "ingredients": _STR_ARR,
        "nutrition": {
            "type": "OBJECT",
            "properties": {
                "serving_size_g": _NUM,
                "calories_kcal": _NUM,
                "total_fat_g": _NUM,
                "saturated_fat_g": _NUM,
                "trans_fat_g": _NUM,
                "cholesterol_mg": _NUM,
                "sodium_mg": _NUM,
                "sodium_unit": {"type": "STRING", "enum": ["mg", "g"], "nullable": True},
                "salt_g": _NUM,
                "total_carbs_g": _NUM,
                "dietary_fiber_g": _NUM,
                "sugars_g": _NUM,
                "added_sugars_g": _NUM,
                "protein_g": _NUM,
                "iron_mg": _NUM,
                "vitamin_c_mg": _NUM,
                "sodium_confidence": _BOOL,
                "sugar_confidence": _BOOL,
                "fat_confidence": _BOOL,
            },
        },
        "allergens_declared": _STR_ARR,
        "may_contain": _STR_ARR,
        "visible_claims": _STR_ARR,
        "extraction_confidence": {"type": "NUMBER"},
        "insufficient_data": _BOOL,
        "extraction_notes": {"type": "STRING", "nullable": True},
    },
}


_PRESCRIPTION_SCHEMA: dict[str, Any] = {
    "type": "OBJECT",
    "properties": {
        "is_prescription": _BOOL,
        "diagnoses": _STR_ARR,
        "medicines": _STR_ARR,
        "allergies": {
            "type": "ARRAY",
            "items": {
                "type": "OBJECT",
                "properties": {
                    "name": {"type": "STRING"},
                    "kind": {"type": "STRING", "enum": ["food", "drug", "other"]},
                },
            },
        },
        "notes": {"type": "STRING", "nullable": True},
    },
}


def _parse_prescription_json(raw_text: str) -> dict[str, Any] | None:
    """Parse the model's JSON, or None if it is not a JSON object.

    Unlike the label parser this NEVER logs the raw text: it is health data.
    """
    text = raw_text.strip()
    fenced = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
    if fenced:
        text = fenced.group(1).strip()
    else:
        braces = re.search(r"(\{[\s\S]*\})", text)
        if braces:
            text = braces.group(1).strip()
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def _parse_extraction_json(raw_text: str) -> dict[str, Any]:
    text = raw_text.strip()
    match = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
    if match:
        text = match.group(1).strip()
    else:
        brace_match = re.search(r"(\{[\s\S]*\})", text)
        if brace_match:
            text = brace_match.group(1).strip()

    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        logger.warning("Failed to parse JSON: %s. Raw: %.200s", exc, text)
        return {
            "insufficient_data": True,
            "extraction_notes": f"JSON parse error: {exc}",
            "extraction_confidence": 0.0,
        }


def _parse_float(val: Any) -> float | None:
    if val is None:
        return None
    if isinstance(val, (int, float)):
        return float(val)
    if isinstance(val, str):
        match = re.search(r"[-+]?\d*\.?\d+", val)
        if match:
            try:
                return float(match.group())
            except ValueError:
                return None
    return None


def _get_val(d: dict, keys: list[str]) -> float | None:
    for k in keys:
        if k in d and d[k] is not None:
            parsed = _parse_float(d[k])
            if parsed is not None:
                return parsed
    return None


def _confidence_flag(nutrition_raw: dict, key: str, value: float | None) -> bool:
    """True only when a value exists and the model did not mark it as uncertain."""
    if value is None:
        return False
    reported = nutrition_raw.get(key)
    return True if reported is None else bool(reported)


def _clean_confidence(raw: Any) -> float:
    """Missing or invalid confidence is treated as uncertain, never as high."""
    parsed = _parse_float(raw)
    if parsed is None:
        return 0.5
    return max(0.0, min(1.0, parsed))


def _optional_confidence(raw: Any) -> float | None:
    """Identity confidence: missing stays None (unknown), never 0 or 1."""
    parsed = _parse_float(raw)
    return None if parsed is None else max(0.0, min(1.0, parsed))


def _clean_text(raw: Any) -> str | None:
    """A short printed string, or None. Anything that isn't text is dropped."""
    if not isinstance(raw, str):
        return None
    text = " ".join(raw.split())
    return text[:80] or None


def _clean_strings(raw: Any) -> list[str]:
    """Keep only non-empty strings; anything else the model sent is dropped."""
    if not isinstance(raw, list):
        return []
    return [s.strip() for s in raw if isinstance(s, str) and s.strip()]


def _dict_to_prescription_observation(data: dict) -> PrescriptionObservation:
    allergies: list[StatedAllergy] = []
    raw_allergies = data.get("allergies")
    for item in raw_allergies if isinstance(raw_allergies, list) else []:
        if isinstance(item, str):
            name, kind_raw = item, None
        elif isinstance(item, dict):
            name, kind_raw = item.get("name"), item.get("kind")
        else:
            continue
        if not isinstance(name, str) or not name.strip():
            continue
        try:
            kind = AllergyKind(kind_raw)
        except ValueError:
            kind = AllergyKind.OTHER
        allergies.append(StatedAllergy(name=name.strip(), kind=kind))

    notes = data.get("notes")
    return PrescriptionObservation(
        # Missing flag means we do not know it is a prescription.
        is_prescription=data.get("is_prescription") is True,
        diagnoses=_clean_strings(data.get("diagnoses")),
        medicines=_clean_strings(data.get("medicines")),
        allergies=allergies,
        notes=notes if isinstance(notes, str) else None,
    )


def _dict_to_product_observation(data: dict) -> ProductObservation:
    nutrition_raw = data.get("nutrition") or {}
    if not isinstance(nutrition_raw, dict):
        nutrition_raw = {}

    calories = _get_val(nutrition_raw, ["calories_kcal", "calories", "energy_kcal", "energy"])
    total_fat = _get_val(nutrition_raw, ["total_fat_g", "total_fat", "fat_g", "fat"])
    sat_fat = _get_val(nutrition_raw, ["saturated_fat_g", "saturated_fat", "sat_fat_g", "sat_fat"])
    trans_fat = _get_val(nutrition_raw, ["trans_fat_g", "trans_fat"])
    cholesterol = _get_val(nutrition_raw, ["cholesterol_mg", "cholesterol"])
    sodium = _get_val(nutrition_raw, ["sodium_mg", "sodium"])
    if sodium is not None and str(nutrition_raw.get("sodium_unit") or "").strip().lower() == "g":
        # "Sodium 0.4 g" copied as printed: 400 mg. Converted here, in code,
        # never by the model; left as-is it would be 1000x too low and wave
        # salty food past the blood-pressure rules.
        sodium = round(sodium * 1000.0, 1)
    if sodium is None:
        # Labels sometimes print only salt. Sodium is 40% of salt by weight
        # (1 g salt = 400 mg sodium). Convert in code, never trust the model's arithmetic.
        salt_g = _get_val(nutrition_raw, ["salt_g", "salt"])
        salt_mg = _get_val(nutrition_raw, ["salt_mg"])
        if salt_g is not None:
            sodium = round(salt_g * 400.0, 1)
        elif salt_mg is not None:
            sodium = round(salt_mg * 0.4, 1)
    total_carbs = _get_val(
        nutrition_raw, ["total_carbs_g", "total_carbs", "carbs_g", "carbs", "carbohydrates"]
    )
    fiber = _get_val(nutrition_raw, ["dietary_fiber_g", "dietary_fiber", "fiber_g", "fiber"])
    sugars = _get_val(nutrition_raw, ["sugars_g", "sugars", "sugar_g", "sugar"])
    added_sugars = _get_val(nutrition_raw, ["added_sugars_g", "added_sugars"])
    protein = _get_val(nutrition_raw, ["protein_g", "protein", "proteins"])
    iron = _get_val(nutrition_raw, ["iron_mg", "iron"])
    vitamin_c = _get_val(nutrition_raw, ["vitamin_c_mg", "vitamin_c", "vitamin c"])

    nutrition = NutritionInfo(
        serving_size_g=_parse_float(
            nutrition_raw.get("serving_size_g") or nutrition_raw.get("serving_size")
        ),
        calories_kcal=calories,
        total_fat_g=total_fat,
        saturated_fat_g=sat_fat,
        trans_fat_g=trans_fat,
        cholesterol_mg=cholesterol,
        sodium_mg=sodium,
        total_carbs_g=total_carbs,
        dietary_fiber_g=fiber,
        sugars_g=sugars,
        added_sugars_g=added_sugars,
        protein_g=protein,
        iron_mg=iron,
        vitamin_c_mg=vitamin_c,
        sodium_confidence=_confidence_flag(nutrition_raw, "sodium_confidence", sodium),
        sugar_confidence=_confidence_flag(nutrition_raw, "sugar_confidence", sugars),
        fat_confidence=_confidence_flag(nutrition_raw, "fat_confidence", total_fat),
    )

    return ProductObservation(
        brand=data.get("brand"),
        product_name=data.get("product_name") or data.get("name") or data.get("title"),
        category=data.get("category"),
        variant=_clean_text(data.get("variant")),
        net_quantity=_clean_text(data.get("net_quantity")),
        mrp=_clean_text(data.get("mrp")),
        identity_confidence=_optional_confidence(data.get("identity_confidence")),
        ingredients=data.get("ingredients") or [],
        nutrition=nutrition,
        allergens_declared=data.get("allergens_declared") or data.get("allergens") or [],
        may_contain=data.get("may_contain") or data.get("may_contain_statement") or [],
        visible_claims=data.get("visible_claims") or data.get("claims") or [],
        extraction_confidence=_clean_confidence(data.get("extraction_confidence")),
        insufficient_data=bool(data.get("insufficient_data", False)),
        extraction_notes=data.get("extraction_notes"),
    )
