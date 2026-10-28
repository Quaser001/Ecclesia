"""
CalFit LangGraph scan orchestration pipeline.

Implements a controlled, deterministic workflow:
  analyze_photo → validate_extraction → match_product → check_scoreable
  → retrieve_knowledge
  → load_profile → score_product → generate_explanation → find_alternatives
  → upload_image → END

With a conditional branch to `assemble_insufficient` whenever extraction
genuinely cannot produce meaningful product information, or when, after
matching, there is still nothing for the rules to evaluate.

This pipeline is NOT an autonomous agent loop. LangGraph only handles
routing and state; the deterministic scoring service remains the sole
authority on scores. The LLM is used strictly for structured extraction
and grounded natural-language explanation.

Design rule (see agents.md):
    Missing data stays missing. We NEVER silently substitute a mocked
    product. If the image cannot be read, the user sees an
    "insufficient data" result, not a fabricated one.
"""

from __future__ import annotations

import logging
import time
import uuid
from datetime import datetime, timezone
from functools import partial
from typing import Any, Literal

from langgraph.graph import END, StateGraph
from pydantic import BaseModel, ConfigDict, Field

from src.config.settings import settings
from src.domain.models import (
    Alternative,
    KnowledgeEntry,
    NutritionInfo,
    ProductObservation,
    RiskLevel,
    ScanResponse,
    ScoreResult,
    SuitabilityStatus,
    UserProfile,
)
from src.domain.rule_catalog import MIN_EXTRACTION_CONFIDENCE
from src.domain.identity import Identification, IdStatus
from src.observability import log_scan_summary, note, start_scan_trace, timed
from src.providers.food_lookup import FoodLookupProvider, LookupUnavailable
from src.providers.interfaces import GeminiProvider, StorageProvider, SupabaseProvider
from src.repositories.product_repository import FoodProduct, ProductRepository, _tokens
from src.services.alternative_service import AlternativeService
from src.services.explanation_service import ExplanationService
from src.services.identification import (
    MIN_CONFIDENCE,
    Source,
    decide,
    message_for,
    observation_from_product,
    rank,
    search_query,
)
from src.services.nutrition_merge import merge_reference_nutrition
from src.services.scoring_service import ScoringService
from src.services.serving_memory import apply_serving, product_key

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Graph State
# ---------------------------------------------------------------------------


class ScanState(BaseModel):
    """Typed state passed between LangGraph nodes."""

    model_config = ConfigDict(arbitrary_types_allowed=True)

    # Inputs
    user_id: str
    photo_bytes: bytes
    mime_type: str = "image/jpeg"

    # Pipeline outputs (populated progressively)
    product: ProductObservation | None = None
    knowledge: list[KnowledgeEntry] = Field(default_factory=list)
    profile: UserProfile | None = None
    score_result: ScoreResult | None = None
    explanation: str = ""
    alternatives: list[Alternative] = Field(default_factory=list)
    image_url: str | None = None

    # Which product a front-of-pack photo shows (services/identification.py).
    identification: Identification | None = None

    # Control flow
    insufficient_data: bool = False
    pipeline_message: str | None = None
    error: str | None = None


# ---------------------------------------------------------------------------
# Node functions
# ---------------------------------------------------------------------------


async def node_analyze_photo(
    state: ScanState, gemini: GeminiProvider
) -> dict[str, Any]:
    """
    Call Gemini to extract product info from the photo.

    If Gemini fails, we DO NOT substitute a mocked product. The pipeline
    continues with product=None and the validation node will route to
    the insufficient-data branch.
    """
    logger.info("node_analyze_photo: user=%s mime=%s", state.user_id, state.mime_type)
    try:
        product = await gemini.analyze_photo(state.photo_bytes, state.mime_type)
        return {"product": product}
    except Exception as exc:
        logger.warning("Gemini photo analysis failed: %s", exc)
        return {
            "product": None,
            "insufficient_data": True,
            "pipeline_message": (
                "We couldn't analyze this photo right now. Please try again — "
                "a clearer shot of the nutrition label usually works best."
            ),
            "error": str(exc),
        }


async def node_validate_extraction(state: ScanState) -> dict[str, Any]:
    """
    Decide whether extraction yielded enough information to score the product.

    "Enough" means we have at least one of: a product name, a brand,
    or any ingredients. Without any of those we have nothing meaningful
    to tell the user — surface insufficient-data instead of guessing.
    """
    product = state.product

    if product is None:
        # Upstream already set a message; make sure the flag is on.
        return {"insufficient_data": True}

    if product.insufficient_data:
        return {
            "insufficient_data": True,
            "pipeline_message": product.extraction_notes
            or "The photo didn't contain enough product information.",
        }

    has_enough = bool(product.product_name or product.ingredients or product.brand)
    if not has_enough:
        return {
            "insufficient_data": True,
            "pipeline_message": (
                "We couldn't find a product name, brand, or ingredients in that image. "
                "Try a clearer photo of the label."
            ),
        }

    # Confidence gate: a shaky read is worse than no read. If the model itself
    # wasn't sure (extraction_confidence < threshold), refuse to score. Giving
    # a confident "Not Suitable" or "Good" verdict from a bad read is the
    # worst possible failure for a health app.
    # Front of pack only (nothing to score on the photo): extraction_confidence
    # is about ingredients and nutrition, so it says nothing here. Identity is
    # judged by identity_confidence in node_identify_product instead.
    if has_scoreable_data(product) and product.extraction_confidence < MIN_EXTRACTION_CONFIDENCE:
        return {
            "insufficient_data": True,
            "pipeline_message": (
                "We weren't confident enough about what the label says to give you "
                "a verdict. Try a sharper photo of the ingredients and nutrition panel."
            ),
        }

    return {"insufficient_data": False}


async def node_match_product(
    state: ScanState, product_repo: ProductRepository
) -> dict[str, Any]:
    """Search local food database to enrich extracted product information."""
    product = state.product
    if not product:
        return {}

    front_only = not has_scoreable_data(product)
    if front_only and product.identity_confidence is not None \
            and product.identity_confidence < MIN_CONFIDENCE:
        return {}  # the name itself is doubtful: let identification ask for a retake

    try:
        matched = product_repo.match_product(
            name=product.product_name,
            brand=product.brand,
            category=product.category,
        )
    except Exception as exc:
        logger.warning("Local product match failed (non-fatal): %s", exc)
        return {}

    if not matched:
        return {}

    logger.info("Matched product in local DB: %s (code=%s)", matched.product_name, matched.code)
    # Database rows are per 100 g/ml; convert onto the label's serving basis.
    merged_nutrition = merge_reference_nutrition(product.nutrition, matched.nutrition)

    enriched_product = product.model_copy(
        update={
            "brand": product.brand or matched.brand,
            "category": product.category
            or (matched.categories[0] if matched.categories else None),
            "ingredients": product.ingredients or matched.ingredients,
            "nutrition": merged_nutrition,
            "allergens_declared": product.allergens_declared or matched.allergens,
            "data_source": "calfit_database",
            "source_code": matched.code,
            "source_date": matched.imported_at,
        }
    )
    update: dict[str, Any] = {"product": enriched_product}
    if front_only:
        # Everything scored came from the database: say which product it was.
        ident = decide(product, [(matched, "calfit_database")])
        if ident.status is IdStatus.CONFIDENT:
            update["identification"] = ident
    return update


# Calories are excluded: a front-of-pack "75 kcal" badge is often the only
# number on the photo, and no sugar, sodium, fat or allergen rule can use it.
_NUTRIENT_VALUE_FIELDS = tuple(
    f for f in NutritionInfo.model_fields
    if f not in ("serving_size_g", "calories_kcal") and not f.endswith("_confidence")
)


def has_scoreable_data(product: ProductObservation) -> bool:
    """True if the rules have anything to evaluate.

    The rules only subtract for problems they can see, so a product with no
    nutrients, ingredients or declared allergens would score 100 on nothing.
    """
    nutrition = product.nutrition
    return bool(
        product.ingredients
        or product.allergens_declared
        or any(getattr(nutrition, f) is not None for f in _NUTRIENT_VALUE_FIELDS)
    )


async def node_check_scoreable(state: ScanState) -> dict[str, Any]:
    """After matching: is there anything to score? Routing acts on the answer:
    yes -> score; no -> find out which real product this is (identification)."""
    return {}


async def node_identify_product(
    state: ScanState,
    product_repo: ProductRepository,
    lookup: FoodLookupProvider | None,
) -> dict[str, Any]:
    """Front of pack only: find the real product, or ask the user.

    Local database first; Open Food Facts once, only if nothing local fits.
    The model's reading is never a source of nutrition (AGENTS.md).
    """
    obs = state.product
    if obs is None:
        return {"insufficient_data": True}
    if not obs.product_name or (obs.identity_confidence is not None
                                and obs.identity_confidence < MIN_CONFIDENCE):
        # A doubtful reading: ask for a retake without spending a search on it.
        ident = decide(obs, [])
        note(identification=ident.status.value, identification_options=0)
        return {"identification": ident, "insufficient_data": True,
                "pipeline_message": message_for(ident)}
    words = _tokens(obs.brand) | _tokens(obs.product_name) | _tokens(obs.variant)
    candidates: list[tuple[FoodProduct, Source]] = [
        (p, "calfit_database") for p in product_repo.search_by_words(words)]
    ranked = rank(obs, candidates)
    lookup_failed = False
    if not ranked and lookup is not None and obs.product_name:
        try:
            online = await lookup.search(search_query(obs))
            ranked = rank(obs, [(p, "open_food_facts") for p in online])
        except LookupUnavailable:
            lookup_failed = True

    ident = decide(obs, ranked, lookup_failed=lookup_failed)
    note(identification=ident.status.value, identification_options=len(ident.options))
    if ident.status is IdStatus.CONFIDENT:
        product, source = ranked[0]
        return {"product": observation_from_product(product, source, obs),
                "identification": ident}
    return {"identification": ident, "insufficient_data": True,
            "pipeline_message": message_for(ident)}


async def node_apply_serving_memory(
    state: ScanState, supabase: SupabaseProvider
) -> dict[str, Any]:
    """Use the serving size this user saved for this product, if any."""
    product = state.product
    key = product_key(product.brand, product.product_name) if product else None
    if not key:
        return {}
    try:
        saved = await supabase.get_serving_memory(state.user_id, key)
    except Exception as exc:  # noqa: BLE001 - a missing memory never blocks a scan
        logger.warning("Serving memory unavailable: %s", type(exc).__name__)
        return {}
    if not saved:
        return {}
    nutrition = apply_serving(product.nutrition, float(saved["serving_size_g"]),
                              saved["label_basis"])
    if nutrition is product.nutrition:
        return {}
    note(serving_from_memory=True)
    return {"product": product.model_copy(update={"nutrition": nutrition})}


async def node_retrieve_knowledge(
    state: ScanState, supabase: SupabaseProvider
) -> dict[str, Any]:
    """Retrieve relevant knowledge from the knowledge base."""
    product = state.product
    if not product:
        return {"knowledge": []}

    tags: list[str] = []
    if product.category:
        tags.append(product.category)
    tags.extend(product.ingredients[:5])
    tags.extend(product.allergens_declared)

    try:
        knowledge = await supabase.query_knowledge_by_tags(tags, limit=10)
        logger.info("Retrieved %d knowledge entries", len(knowledge))
        return {"knowledge": knowledge}
    except Exception as exc:
        logger.warning("Knowledge retrieval failed (non-fatal): %s", exc)
        return {"knowledge": []}


async def node_load_profile(
    state: ScanState, supabase: SupabaseProvider
) -> dict[str, Any]:
    """Load the user's health profile from the database."""
    try:
        profile = await supabase.get_profile(state.user_id)
        if profile is None:
            logger.info("No profile for user=%s, using empty profile", state.user_id)
            profile = UserProfile(user_id=state.user_id)
        return {"profile": profile}
    except Exception as exc:
        logger.warning("Profile load failed, using empty profile: %s", exc)
        return {"profile": UserProfile(user_id=state.user_id)}


async def node_score_product(state: ScanState) -> dict[str, Any]:
    """Apply deterministic scoring rules — no LLM."""
    scoring = ScoringService()
    score_result = scoring.score(
        product=state.product,
        profile=state.profile,
        knowledge=state.knowledge or None,
    )
    logger.info("Score: %d (%s)", score_result.score, score_result.suitability)
    return {"score_result": score_result}


async def node_generate_explanation(
    state: ScanState, gemini: GeminiProvider
) -> dict[str, Any]:
    """Generate a human-readable explanation using the LLM, with a factual fallback."""
    try:
        explanation_svc = ExplanationService(gemini)
        explanation = await explanation_svc.explain(
            product=state.product,
            score_result=state.score_result,
            profile=state.profile,
            knowledge=state.knowledge or None,
        )
        return {"explanation": explanation}
    except Exception as exc:
        logger.warning("LLM explanation generation failed (%s), using rule-summary fallback.", exc)
        score = state.score_result.score if state.score_result else 0
        suitability = (
            state.score_result.suitability.value.replace("_", " ").title()
            if state.score_result
            else "Unknown"
        )
        return {
            "explanation": (
                f"Evaluated with a health score of {score}/100 ({suitability}) based on "
                "your profile. See the detailed findings below."
            )
        }


async def node_find_alternatives(
    state: ScanState, product_repo: ProductRepository
) -> dict[str, Any]:
    """Find better-fit alternatives for the scanned product from the local DB."""
    alt_svc = AlternativeService()
    alternatives = alt_svc.find(
        product=state.product,
        profile=state.profile,
        score_result=state.score_result,
        knowledge=state.knowledge or None,
        product_repo=product_repo,
    )
    return {"alternatives": alternatives}


async def node_upload_image(
    state: ScanState, storage: StorageProvider, bucket: str
) -> dict[str, Any]:
    """Upload the scanned image to storage and get a URL."""
    try:
        path = f"scans/{state.user_id}/{uuid.uuid4()}.jpg"
        url = await storage.upload_image(bucket, path, state.photo_bytes, state.mime_type)
        return {"image_url": url}
    except Exception as exc:
        logger.warning("Image upload failed (non-fatal): %s", exc)
        return {"image_url": None}


def node_assemble_insufficient_result(state: ScanState) -> dict[str, Any]:
    """Assemble a transparent response when data is insufficient (no fake data)."""
    product = state.product or ProductObservation(
        insufficient_data=True,
        extraction_notes=state.pipeline_message,
        extraction_confidence=0.0,
    )
    score_result = ScoreResult(
        score=0,
        suitability=SuitabilityStatus.NOT_SUITABLE,
        risk_level=RiskLevel.UNKNOWN,
        findings=[],
        rules_applied=[],
    )
    return {
        "product": product,
        "score_result": score_result,
        "explanation": state.pipeline_message
        or "We couldn't read enough information from this photo.",
        "alternatives": [],
        "insufficient_data": True,
    }


# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------


def route_after_validation(
    state: ScanState,
) -> Literal["match_product", "assemble_insufficient"]:
    if state.insufficient_data:
        return "assemble_insufficient"
    return "match_product"


def route_after_scoreable_check(
    state: ScanState,
) -> Literal["apply_serving_memory", "identify_product"]:
    if state.product is not None and has_scoreable_data(state.product):
        return "apply_serving_memory"
    return "identify_product"


def route_after_identification(
    state: ScanState,
) -> Literal["apply_serving_memory", "assemble_insufficient"]:
    if state.insufficient_data or state.product is None \
            or not has_scoreable_data(state.product):
        return "assemble_insufficient"
    return "apply_serving_memory"


def route_entry(state: ScanState) -> Literal["analyze_photo", "apply_serving_memory"]:
    """A product the user already picked skips reading the photo."""
    return "apply_serving_memory" if state.product is not None else "analyze_photo"


# ---------------------------------------------------------------------------
# Graph builder
# ---------------------------------------------------------------------------


def build_scan_graph(
    gemini: GeminiProvider,
    supabase: SupabaseProvider,
    storage: StorageProvider,
    storage_bucket: str,
    product_repo: ProductRepository | None = None,
    lookup: FoodLookupProvider | None = None,
) -> Any:
    """Build and compile the LangGraph scan pipeline."""
    repo = product_repo or ProductRepository()
    graph = StateGraph(ScanState)

    def add(name: str, node: Any) -> None:
        # Every node is timed into the scan's trace (src/observability.py).
        graph.add_node(name, timed(name, node))

    add("analyze_photo", partial(node_analyze_photo, gemini=gemini))
    add("validate_extraction", node_validate_extraction)
    add("match_product", partial(node_match_product, product_repo=repo))
    add("check_scoreable", node_check_scoreable)
    add("identify_product", partial(node_identify_product, product_repo=repo, lookup=lookup))
    add("apply_serving_memory", partial(node_apply_serving_memory, supabase=supabase))
    add("retrieve_knowledge", partial(node_retrieve_knowledge, supabase=supabase))
    add("load_profile", partial(node_load_profile, supabase=supabase))
    add("score_product", node_score_product)
    add("generate_explanation", partial(node_generate_explanation, gemini=gemini))
    add("find_alternatives", partial(node_find_alternatives, product_repo=repo))
    add("upload_image", partial(node_upload_image, storage=storage, bucket=storage_bucket))
    add("assemble_insufficient", node_assemble_insufficient_result)

    graph.set_conditional_entry_point(
        route_entry,
        {"analyze_photo": "analyze_photo", "apply_serving_memory": "apply_serving_memory"},
    )
    graph.add_edge("analyze_photo", "validate_extraction")
    graph.add_conditional_edges(
        "validate_extraction",
        route_after_validation,
        {
            "match_product": "match_product",
            "assemble_insufficient": "assemble_insufficient",
        },
    )
    graph.add_edge("match_product", "check_scoreable")
    graph.add_conditional_edges(
        "check_scoreable",
        route_after_scoreable_check,
        {
            "apply_serving_memory": "apply_serving_memory",
            "identify_product": "identify_product",
        },
    )
    graph.add_conditional_edges(
        "identify_product",
        route_after_identification,
        {
            "apply_serving_memory": "apply_serving_memory",
            "assemble_insufficient": "assemble_insufficient",
        },
    )
    graph.add_edge("apply_serving_memory", "retrieve_knowledge")
    graph.add_edge("retrieve_knowledge", "load_profile")
    graph.add_edge("load_profile", "score_product")
    graph.add_edge("score_product", "generate_explanation")
    graph.add_edge("generate_explanation", "find_alternatives")
    graph.add_edge("find_alternatives", "upload_image")
    graph.add_edge("upload_image", END)
    graph.add_edge("assemble_insufficient", END)

    return graph.compile()


# ---------------------------------------------------------------------------
# Orchestrator — high-level entry point
# ---------------------------------------------------------------------------


class ScanOrchestrator:
    """High-level orchestrator for the scan pipeline."""

    def __init__(
        self,
        gemini: GeminiProvider,
        supabase: SupabaseProvider,
        storage: StorageProvider,
        storage_bucket: str = "calfit-scans",
        lookup: FoodLookupProvider | None = None,
        product_repo: ProductRepository | None = None,
    ) -> None:
        self._graph = build_scan_graph(gemini, supabase, storage, storage_bucket,
                                       product_repo=product_repo, lookup=lookup)
        self._supabase = supabase

    async def run(
        self,
        user_id: str,
        photo_bytes: bytes,
        mime_type: str = "image/jpeg",
    ) -> ScanResponse:
        """Execute the full scan pipeline and return a ScanResponse."""
        initial_state = ScanState(
            user_id=user_id,
            photo_bytes=photo_bytes,
            mime_type=mime_type,
        )
        return await self._execute(initial_state)

    async def run_with_product(
        self,
        user_id: str,
        product: ProductObservation,
        identification: Identification,
        photo_bytes: bytes,
        mime_type: str = "image/jpeg",
    ) -> ScanResponse:
        """Score a product the user picked (confirm / choose): no photo reading."""
        initial_state = ScanState(
            user_id=user_id,
            photo_bytes=photo_bytes,
            mime_type=mime_type,
            product=product,
            identification=identification,
        )
        return await self._execute(initial_state)

    async def _execute(self, initial_state: ScanState) -> ScanResponse:
        user_id = initial_state.user_id
        trace = start_scan_trace()
        started = time.perf_counter()
        result_raw = await self._graph.ainvoke(initial_state)
        final_state = ScanState(**result_raw) if isinstance(result_raw, dict) else result_raw

        scan_id = str(uuid.uuid4())
        response = ScanResponse(
            scan_id=scan_id,
            user_id=user_id,
            scanned_at=datetime.now(timezone.utc),
            product=final_state.product
            or ProductObservation(insufficient_data=True),
            score_result=final_state.score_result
            or ScoreResult(
                score=0,
                suitability=SuitabilityStatus.NOT_SUITABLE,
                risk_level=RiskLevel.UNKNOWN,
                findings=[],
                rules_applied=[],
            ),
            explanation=final_state.explanation,
            alternatives=final_state.alternatives,
            image_url=final_state.image_url,
            insufficient_data=final_state.insufficient_data,
            pipeline_message=final_state.pipeline_message,
            identification=final_state.identification,
        )

        # Only persist scans that produced a real result; skip insufficient-data entries
        # so a user's history isn't polluted with "unknown product" placeholders.
        saved = False
        if not response.insufficient_data:
            saved = await self._persist_scan(response)

        log_scan_summary(
            trace,
            round((time.perf_counter() - started) * 1000),
            scan_id=response.scan_id,
            outcome="insufficient_data" if response.insufficient_data else "scored",
            ai_backend=settings.GEMINI_BACKEND,
            suitability=None if response.insufficient_data
            else response.score_result.suitability.value,
            findings=len(response.score_result.findings),
            alternatives=len(response.alternatives),
            verified_alternatives=sum(1 for a in response.alternatives if a.verified),
            extraction_confidence=round(response.product.extraction_confidence, 2),
            nutrient_levels=len(response.nutrient_levels),
            identification=(response.identification.status.value
                            if response.identification else None),
            data_source=response.product.data_source,
            saved=saved,
        )
        return response

    async def _persist_scan(self, response: ScanResponse) -> bool:
        try:
            scan_data = {
                "scan_id": response.scan_id,
                "user_id": response.user_id,
                "scanned_at": response.scanned_at.isoformat(),
                "product_name": response.product.product_name,
                "brand": response.product.brand,
                "category": response.product.category,
                "score": response.score_result.score,
                "suitability": response.score_result.suitability.value,
                "image_url": response.image_url,
                "product_json": response.product.model_dump_json(),
                "score_json": response.score_result.model_dump_json(),
                "explanation": response.explanation,
            }
            # `scans.user_id` references `profiles.user_id`, so the row must
            # exist before the insert. A new install has no profile until the
            # user opens the profile screen, so create an empty one here.
            await self._supabase.ensure_profile_exists(response.user_id)
            await self._supabase.save_scan(scan_data)
            return True
        except Exception as exc:
            # Class name only: a database error can echo the row, which holds
            # the explanation (and so the user's conditions).
            logger.warning("Failed to persist scan %s: %s", response.scan_id, type(exc).__name__)
            return False
