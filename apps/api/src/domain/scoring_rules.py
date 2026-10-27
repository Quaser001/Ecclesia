"""
CalFit deterministic scoring rule engine.

Rules are pure functions: (ProductObservation, UserProfile) → list[ScanFinding].
The LLM never participates in score calculation.
Each rule has a stable ID, an impact value, and is independently testable.
Fully comprehensive for all medical conditions, allergies, diets, and goals.
"""

from __future__ import annotations

import logging
import re
from typing import Callable

from src.domain.models import (
    DietaryPreference,
    EvidenceTier,
    FindingSeverity,
    HealthCondition,
    HealthGoal,
    NutritionInfo,
    ProductObservation,
    RiskLevel,
    ScoreResult,
    ScanFinding,
    SuitabilityStatus,
    UserProfile,
)
from src.domain.rule_catalog import RuleSpec, rule

# ---------------------------------------------------------------------------
# Score → Suitability mapping
# ---------------------------------------------------------------------------

_SUITABILITY_THRESHOLDS = [
    (80, SuitabilityStatus.EXCELLENT),
    (60, SuitabilityStatus.GOOD),
    (40, SuitabilityStatus.FAIR),
    (20, SuitabilityStatus.POOR),
    (0,  SuitabilityStatus.NOT_SUITABLE),
]

_SUITABILITY_TO_RISK = {
    SuitabilityStatus.EXCELLENT:    RiskLevel.LOW,
    SuitabilityStatus.GOOD:         RiskLevel.LOW,
    SuitabilityStatus.FAIR:         RiskLevel.MODERATE,
    SuitabilityStatus.POOR:         RiskLevel.HIGH,
    SuitabilityStatus.NOT_SUITABLE: RiskLevel.CRITICAL,
}


def _suitability_from_score(score: int) -> SuitabilityStatus:
    for threshold, status in _SUITABILITY_THRESHOLDS:
        if score >= threshold:
            return status
    return SuitabilityStatus.NOT_SUITABLE


RuleFn = Callable[[ProductObservation, UserProfile], list[ScanFinding]]


def _finding_from_spec(
    spec: RuleSpec,
    *,
    nutrient_or_ingredient: str | None = None,
    detail_override: str | None = None,
    **detail_kwargs,
) -> ScanFinding:
    """Build a ScanFinding from a RuleSpec, attaching the citation and tier.

    Keeps every finding anchored to a reviewable row in rule_catalog.py.
    """
    detail = detail_override or spec.detail_template.format(**detail_kwargs)
    return ScanFinding(
        rule_id=spec.rule_id,
        severity=spec.severity,
        title=spec.title,
        detail=detail,
        nutrient_or_ingredient=nutrient_or_ingredient or spec.nutrient_or_ingredient,
        score_impact=spec.score_impact,
        source=spec.source,
        evidence_tier=spec.tier,
    )


# ---------------------------------------------------------------------------
# RULE 1: ALLERGIES & INTOLERANCES
# ---------------------------------------------------------------------------

# Allergen vocabulary. Each group lists every name the allergen can appear under
# on an Indian or international label (e.g. casein/whey/ghee/paneer are all milk).
# Matching is on whole words, so "nutmeg" and "coconut" do not match "nut".
# Second tuple item: phrases that contain a term but are NOT the allergen.
_ALLERGEN_GROUPS: dict[str, tuple[tuple[str, ...], tuple[str, ...]]] = {
    "milk": (
        ("milk", "dairy", "lactose", "casein", "caseinate", "whey", "ghee", "butter",
         "cream", "curd", "dahi", "yogurt", "yoghurt", "paneer", "cheese", "khoa", "mawa",
         "buttermilk", "milk solids", "milk powder", "skimmed milk", "lactoglobulin"),
        ("coconut milk", "almond milk", "oat milk", "rice milk", "soy milk", "soya milk",
         "peanut butter", "cocoa butter", "shea butter", "almond butter", "nut butter",
         "coconut cream", "cream of tartar"),
    ),
    "peanut": (
        ("peanut", "groundnut", "arachis", "monkey nut", "nut", "mixed nut"),
        (),
    ),
    "tree_nut": (
        ("tree nut", "nut", "almond", "cashew", "walnut", "pistachio", "hazelnut", "pecan",
         "macadamia", "brazil nut", "pine nut", "marzipan", "praline", "gianduja"),
        (),
    ),
    "wheat": (
        ("wheat", "atta", "maida", "semolina", "suji", "sooji", "rava", "durum", "spelt",
         "farina", "couscous", "seitan", "bulgur", "triticale", "kamut", "gluten"),
        (),
    ),
    "gluten": (
        ("gluten", "wheat", "atta", "maida", "semolina", "suji", "sooji", "rava", "durum",
         "spelt", "farina", "couscous", "seitan", "bulgur", "triticale", "kamut",
         "barley", "rye", "malt"),
        (),
    ),
    "soy": (
        ("soy", "soya", "soybean", "soja", "edamame", "tofu", "tempeh", "miso"),
        (),
    ),
    "egg": (
        ("egg", "albumin", "albumen", "ovalbumin", "lysozyme", "mayonnaise", "meringue"),
        (),
    ),
    "fish": (
        ("fish", "anchovy", "cod", "salmon", "tuna", "sardine", "mackerel", "hilsa",
         "rohu", "tilapia", "basa", "pangasius", "surimi"),
        (),
    ),
    "shellfish": (
        ("shellfish", "shrimp", "prawn", "crab", "lobster", "crayfish", "krill", "oyster",
         "clam", "mussel", "scallop", "squid", "octopus", "mollusc", "mollusk"),
        (),
    ),
    "sesame": (("sesame", "til", "tahini", "gingelly"), ()),
    "mustard": (("mustard", "sarson"), ()),
}

# What a user might type or pick in their profile -> which groups to check.
_USER_ALLERGY_ALIASES: dict[str, tuple[str, ...]] = {
    "milk": ("milk",), "dairy": ("milk",), "lactose": ("milk",), "cow milk": ("milk",),
    "peanut": ("peanut",), "peanuts": ("peanut",), "groundnut": ("peanut",),
    "groundnuts": ("peanut",),
    "tree nut": ("tree_nut",), "tree nuts": ("tree_nut",),
    "nut": ("peanut", "tree_nut"), "nuts": ("peanut", "tree_nut"),
    "wheat": ("wheat",), "gluten": ("gluten",),
    "soy": ("soy",), "soya": ("soy",), "soybean": ("soy",), "soybeans": ("soy",),
    "egg": ("egg",), "eggs": ("egg",),
    "fish": ("fish",),
    "shellfish": ("shellfish",), "prawn": ("shellfish",), "prawns": ("shellfish",),
    "shrimp": ("shellfish",), "crab": ("shellfish",),
    "seafood": ("fish", "shellfish"),
    "sesame": ("sesame",), "mustard": ("mustard",),
}

# A matched allergen (declared or in ingredients) or active celiac gluten
# finding is a hard stop: the score can never rise above this, so the verdict
# is always "Not Suitable". A "may contain" warning is NOT a hard stop — it is
# an alert, not a declared allergen.
_HARD_STOP_SCORE_CAP = 15
_HARD_STOP_RULE_IDS = ("RULE-001A", "RULE-001B")


def _contains_term(text: str, term: str) -> bool:
    """Whole-word match with simple plurals ('peanut' matches 'peanuts')."""
    pattern = rf"(?<![a-z]){re.escape(term)}(?:s|es)?(?![a-z])"
    return re.search(pattern, text) is not None


def _first_allergen_match(user_allergy: str, texts: list[str]) -> str | None:
    """Return the first label text that matches the user's allergy, else None.

    Known allergens use the vocabulary above. Anything else the user typed
    falls back to a plain substring check so custom allergies still work.
    """
    groups = _USER_ALLERGY_ALIASES.get(user_allergy)
    if groups is None:
        return next((t for t in texts if user_allergy in t), None)

    for text in texts:
        for group in groups:
            terms, not_allergen = _ALLERGEN_GROUPS[group]
            cleaned = text
            for phrase in not_allergen:
                cleaned = cleaned.replace(phrase, " ")
            if any(_contains_term(cleaned, term) for term in terms):
                return text
    return None

def _rule_allergy_conflict(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-001: Declared allergen, ingredient, or 'may contain' matches a user allergy.

    Threshold rows live in rule_catalog.py:
      RULE-001A — declared allergen (hard stop)
      RULE-001B — allergen in ingredients (hard stop)
      RULE-001C — unreadable label with allergic user
      RULE-001D — cross-contact warning on the label (alert, not hard stop)
    """
    findings: list[ScanFinding] = []
    user_allergies_lower = {a.lower().strip() for a in profile.allergies if a.strip()}
    if not user_allergies_lower:
        return findings

    # We cannot call a product safe if we could not read what is in it.
    if not product.ingredients and not product.allergens_declared:
        findings.append(_finding_from_spec(rule("RULE-001C-ALLERGY-UNVERIFIED")))
        return findings

    declared = [a.lower().strip() for a in product.allergens_declared if a.strip()]
    ingredients = [i.lower().strip() for i in product.ingredients if i.strip()]
    may_contain = [m.lower().strip() for m in product.may_contain if m.strip()]

    for user_alg in sorted(user_allergies_lower):
        declared_hit = _first_allergen_match(user_alg, declared)
        if declared_hit:
            findings.append(
                _finding_from_spec(
                    rule("RULE-001A-ALLERGY-DECLARED"),
                    nutrient_or_ingredient=user_alg,
                    match=declared_hit, allergy=user_alg,
                )
            )
            continue

        ingredient_hit = _first_allergen_match(user_alg, ingredients)
        if ingredient_hit:
            findings.append(
                _finding_from_spec(
                    rule("RULE-001B-ALLERGY-INGREDIENT"),
                    nutrient_or_ingredient=user_alg,
                    match=ingredient_hit, allergy=user_alg,
                )
            )
            continue

        may_contain_hit = _first_allergen_match(user_alg, may_contain)
        if may_contain_hit:
            findings.append(
                _finding_from_spec(
                    rule("RULE-001D-ALLERGY-MAY-CONTAIN"),
                    nutrient_or_ingredient=user_alg,
                    match=may_contain_hit, allergy=user_alg,
                )
            )

    return findings


# ---------------------------------------------------------------------------
# RULE 2: HYPERTENSION / HEART DISEASE (SODIUM)
# ---------------------------------------------------------------------------

def _rule_high_sodium_hypertension(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-002: High sodium for users with hypertension or heart disease.

    Thresholds and sources: rule_catalog.py (SODIUM_CRITICAL / HIGH / MODERATE /
    COMPOUNDS). WHO sodium guideline: < 2 g sodium per day.
    """
    findings: list[ScanFinding] = []
    has_bp_condition = bool(
        {HealthCondition.HYPERTENSION, HealthCondition.HEART_DISEASE}
        & set(profile.health_conditions)
    )
    if not has_bp_condition:
        return findings

    sodium = product.nutrition.sodium_mg
    if sodium is not None:
        if sodium > rule("RULE-002A-SODIUM-CRITICAL").threshold:
            findings.append(_finding_from_spec(rule("RULE-002A-SODIUM-CRITICAL"), value=sodium))
        elif sodium > rule("RULE-002B-SODIUM-HIGH").threshold:
            findings.append(_finding_from_spec(rule("RULE-002B-SODIUM-HIGH"), value=sodium))
        elif sodium > rule("RULE-002C-SODIUM-MODERATE").threshold:
            findings.append(_finding_from_spec(rule("RULE-002C-SODIUM-MODERATE"), value=sodium))

    # Ingredient fallback: only when the label's sodium value could not be read.
    # Otherwise plain 'salt' in a low-sodium food would be penalised wrongly.
    salty_compounds = ["salt", "sea salt", "black salt", "monosodium glutamate", "msg",
                       "sodium nitrite", "sodium benzoate", "baking soda", "sodium nitrate"]
    found_salty = [ing for ing in product.ingredients
                   if any(sc in ing.lower() for sc in salty_compounds)]
    if sodium is None and found_salty and not findings:
        findings.append(
            _finding_from_spec(
                rule("RULE-002D-SODIUM-COMPOUNDS"),
                matches=", ".join(found_salty[:3]),
            )
        )

    return findings


# ---------------------------------------------------------------------------
# RULE 3: DIABETES TYPE 1 & TYPE 2 (SUGAR & GLYCEMIC INDEX)
# ---------------------------------------------------------------------------

def _rule_high_sugar_diabetes(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-003: Sugar load for diabetes, prediabetes, or 'manage blood sugar'.

    Thresholds and sources: rule_catalog.py SUGAR_* rows. WHO sugars guideline
    (2015): free sugars < 10% of daily energy.
    """
    findings: list[ScanFinding] = []
    has_diabetes = bool(
        {HealthCondition.DIABETES_TYPE_1, HealthCondition.DIABETES_TYPE_2,
         HealthCondition.PREDIABETES}
        & set(profile.health_conditions)
    ) or (HealthGoal.MANAGE_BLOOD_SUGAR in profile.health_goals)

    if not has_diabetes:
        return findings

    sugar = product.nutrition.sugars_g
    if sugar is not None:
        if sugar > rule("RULE-003A-SUGAR-EXTREME").threshold:
            findings.append(_finding_from_spec(rule("RULE-003A-SUGAR-EXTREME"), value=sugar))
        elif sugar > rule("RULE-003B-SUGAR-VERY-HIGH").threshold:
            findings.append(_finding_from_spec(rule("RULE-003B-SUGAR-VERY-HIGH"), value=sugar))
        elif sugar > rule("RULE-003C-SUGAR-HIGH").threshold:
            findings.append(_finding_from_spec(rule("RULE-003C-SUGAR-HIGH"), value=sugar))
        elif sugar > rule("RULE-003D-SUGAR-MODERATE").threshold:
            findings.append(_finding_from_spec(rule("RULE-003D-SUGAR-MODERATE"), value=sugar))

    # Ingredient fallback — fires only if no numeric sugar rule already matched,
    # so we never double-penalise the same product for the same reason.
    high_gi = [
        "sugar", "added sugar", "invert sugar", "glucose", "fructose", "sucrose",
        "dextrose", "maltodextrin", "corn syrup", "glucose syrup", "jaggery",
        "refined wheat flour", "maida", "liquid glucose", "corn starch"
    ]
    found_gi = [ing for ing in product.ingredients if any(hgi in ing.lower() for hgi in high_gi)]
    if found_gi and not findings:
        findings.append(
            _finding_from_spec(
                rule("RULE-003E-HIGH-GI-INGREDIENTS"),
                matches=", ".join(found_gi[:3]),
            )
        )

    return findings


# ---------------------------------------------------------------------------
# RULE 4: HIGH CHOLESTEROL & HEART DISEASE (FAT & CHOLESTEROL)
# ---------------------------------------------------------------------------

def _rule_high_saturated_fat_cholesterol(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-004: High saturated fat, trans fat, or cholesterol for heart health."""
    findings: list[ScanFinding] = []
    has_condition = bool(
        {HealthCondition.HIGH_CHOLESTEROL, HealthCondition.HEART_DISEASE}
        & set(profile.health_conditions)
    ) or (HealthGoal.HEART_HEALTH in profile.health_goals)

    if not has_condition:
        return findings

    sat_fat = product.nutrition.saturated_fat_g
    trans_fat = product.nutrition.trans_fat_g
    cholesterol = product.nutrition.cholesterol_mg

    if sat_fat is not None:
        if sat_fat > rule("RULE-004A-SATFAT-VERY-HIGH").threshold:
            findings.append(_finding_from_spec(rule("RULE-004A-SATFAT-VERY-HIGH"), value=sat_fat))
        elif sat_fat > rule("RULE-004B-SATFAT-HIGH").threshold:
            findings.append(_finding_from_spec(rule("RULE-004B-SATFAT-HIGH"), value=sat_fat))

    if trans_fat is not None and trans_fat > rule("RULE-004C-TRANSFAT-DANGER").threshold:
        findings.append(_finding_from_spec(rule("RULE-004C-TRANSFAT-DANGER"), value=trans_fat))

    if cholesterol is not None and cholesterol > rule("RULE-004D-CHOLESTEROL-HIGH").threshold:
        findings.append(_finding_from_spec(rule("RULE-004D-CHOLESTEROL-HIGH"), value=cholesterol))

    # Ingredient fallback: fire only when no numeric fat/trans-fat rule already matched.
    bad_fats = ["palm oil", "palmolein oil", "palmolein", "hydrogenated oil",
                "partially hydrogenated", "lard", "margarine", "butter"]
    found_bad_fats = [ing for ing in product.ingredients
                      if any(bf in ing.lower() for bf in bad_fats)]
    already_fat_flagged = any(
        f.rule_id in ("RULE-004A-SATFAT-VERY-HIGH", "RULE-004C-TRANSFAT-DANGER")
        for f in findings
    )
    if found_bad_fats and not already_fat_flagged:
        findings.append(
            _finding_from_spec(
                rule("RULE-004E-BAD-FAT-INGREDIENT"),
                matches=", ".join(found_bad_fats[:2]),
            )
        )

    return findings


# ---------------------------------------------------------------------------
# RULE 11: ANAEMIA / IRON DEFICIENCY
# ---------------------------------------------------------------------------

_IRON_FORTIFICATION_HINTS = (
    "+f logo", "+f fortified", "iron fortified", "fortified with iron",
    "iron (as", "ferrous fumarate", "ferric pyrophosphate", "ferrous sulphate",
    "ferrous sulfate", "elemental iron", "nahtol iron",
)
_VITAMIN_C_HINTS = (
    "ascorbic acid", "vitamin c", "amla", "lemon", "lime juice",
    "orange", "guava", "citrus",
)
_IRON_INHIBITORS = (
    "tea", "black tea", "green tea", "coffee", "cocoa",
)
# These are tea/coffee *leaves/extract* only, not an incidental "tea" syllable.
_IRON_INHIBITOR_NOT = ("tea tree",)


def _rule_anaemia(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-011: Iron load, fortification, absorption aids and inhibitors.

    Thresholds and sources live in rule_catalog.py (RULE-011A..D). We only
    fire for users who marked anaemia in their profile — this is personal to
    them, not a general warning.
    """
    findings: list[ScanFinding] = []
    if HealthCondition.ANAEMIA not in profile.health_conditions:
        return findings

    iron = product.nutrition.iron_mg
    if iron is not None and iron >= rule("RULE-011A-ANAEMIA-IRON-RICH").threshold:
        findings.append(_finding_from_spec(rule("RULE-011A-ANAEMIA-IRON-RICH"), value=iron))

    label_text = " ".join(
        product.ingredients + product.visible_claims + product.allergens_declared
    ).lower()
    fortification_hits = [h for h in _IRON_FORTIFICATION_HINTS if h in label_text]
    if fortification_hits:
        findings.append(
            _finding_from_spec(
                rule("RULE-011B-ANAEMIA-FORTIFIED"),
                matches=", ".join(sorted(set(fortification_hits))[:2]),
            )
        )

    vit_c_hits = [h for h in _VITAMIN_C_HINTS
                  if any(h in ing.lower() for ing in product.ingredients)]
    if vit_c_hits:
        findings.append(
            _finding_from_spec(
                rule("RULE-011C-ANAEMIA-VITAMIN-C"),
                matches=", ".join(sorted(set(vit_c_hits))[:2]),
            )
        )

    inhibitor_hits = []
    for ing in product.ingredients:
        low = ing.lower()
        if any(bad in low for bad in _IRON_INHIBITOR_NOT):
            continue
        for inhib in _IRON_INHIBITORS:
            if _contains_term(low, inhib):
                inhibitor_hits.append(inhib)
                break
    if inhibitor_hits:
        findings.append(
            _finding_from_spec(
                rule("RULE-011D-ANAEMIA-INHIBITOR"),
                matches=", ".join(sorted(set(inhibitor_hits))[:2]),
            )
        )

    return findings


# ---------------------------------------------------------------------------
# RULE 12: CAFFEINE SENSITIVITY (user-toggled, non-medical)
# ---------------------------------------------------------------------------

_CAFFEINE_SOURCES = (
    "coffee", "coffee powder", "tea", "black tea", "green tea",
    "guarana", "cola nut", "kola nut", "mate", "yerba mate",
    "caffeine",
)
_CAFFEINE_NOT = ("tea tree",)


def _rule_caffeine_sensitivity(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-012: Caffeine source for users with avoid_caffeine set.

    Non-medical. Threshold row: rule_catalog.CAFFEINE_SENSITIVITY. Flagged as
    `sensitivity` tier so it never reads as a medical warning.
    """
    if not getattr(profile, "avoid_caffeine", False):
        return []

    hits: list[str] = []
    for ing in product.ingredients:
        low = ing.lower()
        if any(bad in low for bad in _CAFFEINE_NOT):
            continue
        for src in _CAFFEINE_SOURCES:
            if _contains_term(low, src):
                hits.append(src)
                break
    if not hits:
        return []

    return [
        _finding_from_spec(
            rule("RULE-012-CAFFEINE-SENSITIVITY"),
            matches=", ".join(sorted(set(hits))[:2]),
        )
    ]


# ---------------------------------------------------------------------------
# RULE 5: CELIAC DISEASE & GLUTEN PREFERENCE
# ---------------------------------------------------------------------------

def _rule_gluten_celiac(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-005: Gluten detection for Celiac Disease or Gluten-Free preference."""
    findings: list[ScanFinding] = []
    has_celiac = HealthCondition.CELIAC_DISEASE in profile.health_conditions
    wants_gluten_free = DietaryPreference.GLUTEN_FREE in profile.dietary_preferences

    if not has_celiac and not wants_gluten_free:
        return findings

    gluten_sources = ["wheat", "barley", "rye", "oats", "spelt", "triticale", "kamut", "gluten", "maida", "durum", "semolina"]
    found = [
        src for src in gluten_sources
        if any(src in ing.lower() for ing in product.ingredients)
        or any(src in a.lower() for a in product.allergens_declared)
    ]

    if found:
        severity = FindingSeverity.CRITICAL if has_celiac else FindingSeverity.ALERT
        score_impact = 50 if has_celiac else 25
        findings.append(
            ScanFinding(
                rule_id="RULE-005-GLUTEN",
                severity=severity,
                title="Contains Gluten",
                detail=(
                    f"Gluten sources detected: {', '.join(found[:3])}. "
                    + ("Strictly unsuitable for Celiac Disease." if has_celiac else "Does not meet gluten-free preference.")
                ),
                nutrient_or_ingredient="gluten",
                score_impact=score_impact,
            )
        )

    return findings


# ---------------------------------------------------------------------------
# RULE 6: LACTOSE INTOLERANCE & DAIRY PREFERENCE
# ---------------------------------------------------------------------------

def _rule_dairy_lactose(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-006: Dairy/Lactose detection."""
    findings: list[ScanFinding] = []
    has_lactose = HealthCondition.LACTOSE_INTOLERANCE in profile.health_conditions
    wants_dairy_free = DietaryPreference.DAIRY_FREE in profile.dietary_preferences

    if not has_lactose and not wants_dairy_free:
        return findings

    dairy_sources = ["milk", "lactose", "whey", "casein", "caseinate", "cream", "butter", "cheese", "yogurt", "ghi", "ghee", "milk powder"]
    found = [
        src for src in dairy_sources
        if any(src in ing.lower() for ing in product.ingredients)
        or any(src in a.lower() for a in product.allergens_declared)
    ]

    if found:
        severity = FindingSeverity.ALERT if has_lactose else FindingSeverity.WARNING
        score_impact = 35 if has_lactose else 20
        findings.append(
            ScanFinding(
                rule_id="RULE-006-DAIRY",
                severity=severity,
                title="Contains Dairy / Lactose",
                detail=(
                    f"Dairy components detected: {', '.join(found[:3])}. "
                    + ("Will trigger lactose intolerance digestive distress." if has_lactose else "Does not meet dairy-free preference.")
                ),
                nutrient_or_ingredient="dairy",
                score_impact=score_impact,
            )
        )

    return findings


# ---------------------------------------------------------------------------
# RULE 7: IBS (IRRITABLE BOWEL SYNDROME) & DIGESTION
# ---------------------------------------------------------------------------

def _rule_ibs_fodmap(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-007: High FODMAP and gut irritant ingredients for IBS or digestion goals."""
    findings: list[ScanFinding] = []
    has_ibs = HealthCondition.IBS in profile.health_conditions
    wants_digestion = HealthGoal.IMPROVE_DIGESTION in profile.health_goals

    if not has_ibs and not wants_digestion:
        return findings

    fodmap_irritants = [
        "high fructose corn syrup", "sorbitol", "mannitol", "xylitol", "maltitol",
        "inulin", "chicory root", "onion", "garlic", "lactose", "milk", "artificial sweetener",
        "carrageenan", "sucralose", "aspartame"
    ]
    found = [
        fi for fi in fodmap_irritants
        if any(fi in ing.lower() for ing in product.ingredients)
    ]

    if found:
        findings.append(
            ScanFinding(
                rule_id="RULE-007-IBS-FODMAP",
                severity=FindingSeverity.ALERT if has_ibs else FindingSeverity.WARNING,
                title="Gut Irritants / High FODMAP Detected",
                detail=f"Contains GI irritants: {', '.join(found[:3])}. May trigger bloating, cramps, or IBS flare-ups.",
                nutrient_or_ingredient="fodmap",
                score_impact=30 if has_ibs else 15,
            )
        )

    return findings


# ---------------------------------------------------------------------------
# RULE 8: KIDNEY DISEASE (SODIUM, POTASSIUM, PHOSPHORUS)
# ---------------------------------------------------------------------------

def _rule_kidney_disease(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-008: Strict mineral limits for Kidney Disease."""
    findings: list[ScanFinding] = []
    if HealthCondition.KIDNEY_DISEASE not in profile.health_conditions:
        return findings

    sodium = product.nutrition.sodium_mg
    if sodium is not None and sodium > 300:
        findings.append(
            ScanFinding(
                rule_id="RULE-008A-KIDNEY-SODIUM",
                severity=FindingSeverity.CRITICAL,
                title="High Sodium for Kidney Health",
                detail=f"Contains {sodium:.0f} mg of sodium per serving. Kidney disease requires strict low-sodium intake (<300mg/serving).",
                nutrient_or_ingredient="sodium",
                score_impact=45,
            )
        )

    # Check for phosphate and potassium additives
    kidney_additives = ["phosphate", "phosphoric acid", "potassium chloride", "potassium sorbate", "potassium benzoate"]
    found_additives = [ing for ing in product.ingredients if any(ka in ing.lower() for ka in kidney_additives)]
    if found_additives:
        findings.append(
            ScanFinding(
                rule_id="RULE-008B-KIDNEY-ADDITIVES",
                severity=FindingSeverity.CRITICAL,
                title="Phosphate/Potassium Additives Detected",
                detail=f"Contains additives requiring renal restriction: {', '.join(found_additives[:2])}.",
                nutrient_or_ingredient="kidney_additives",
                score_impact=40,
            )
        )

    return findings


# ---------------------------------------------------------------------------
# RULE 9: DIETARY PREFERENCES (VEGAN, VEGETARIAN, HALAL, KOSHER, KETO)
# ---------------------------------------------------------------------------

def _rule_dietary_preferences(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-009: Strict dietary compliance (Vegan, Vegetarian, Halal, Kosher, Keto)."""
    findings: list[ScanFinding] = []

    # Vegan Check
    if DietaryPreference.VEGAN in profile.dietary_preferences:
        animal = ["meat", "chicken", "beef", "pork", "lamb", "fish", "seafood", "milk", "egg", "whey", "casein", "gelatin", "honey", "butter", "lard"]
        found_vegan = [a for a in animal if any(a in ing.lower() for ing in product.ingredients)]
        if found_vegan:
            findings.append(
                ScanFinding(
                    rule_id="RULE-009A-VEGAN",
                    severity=FindingSeverity.CRITICAL,
                    title="Non-Vegan Ingredients Detected",
                    detail=f"Contains animal-derived ingredients: {', '.join(found_vegan[:3])}.",
                    nutrient_or_ingredient="vegan",
                    score_impact=40,
                )
            )

    # Vegetarian Check
    if DietaryPreference.VEGETARIAN in profile.dietary_preferences:
        meats = ["meat", "chicken", "beef", "pork", "lamb", "fish", "seafood", "anchovy", "gelatin", "shrimp"]
        found_veg = [m for m in meats if any(m in ing.lower() for ing in product.ingredients)]
        if found_veg:
            findings.append(
                ScanFinding(
                    rule_id="RULE-009B-VEGETARIAN",
                    severity=FindingSeverity.CRITICAL,
                    title="Contains Meat or Fish",
                    detail=f"Contains non-vegetarian ingredients: {', '.join(found_veg[:3])}.",
                    nutrient_or_ingredient="vegetarian",
                    score_impact=40,
                )
            )

    # Halal Check
    if DietaryPreference.HALAL in profile.dietary_preferences:
        haram = ["pork", "bacon", "lard", "gelatin", "alcohol", "wine", "rum", "beer", "whiskey"]
        found_haram = [h for h in haram if any(h in ing.lower() for ing in product.ingredients)]
        if found_haram:
            findings.append(
                ScanFinding(
                    rule_id="RULE-009C-HALAL",
                    severity=FindingSeverity.CRITICAL,
                    title="Non-Halal (Haram) Ingredients Detected",
                    detail=f"Contains haram ingredients: {', '.join(found_haram[:3])}.",
                    nutrient_or_ingredient="halal",
                    score_impact=50,
                )
            )

    # Keto / Low-Carb Check
    if (DietaryPreference.KETO in profile.dietary_preferences) or (DietaryPreference.LOW_CARB in profile.dietary_preferences):
        carbs = product.nutrition.total_carbs_g
        sugars = product.nutrition.sugars_g
        if carbs is not None and carbs > 15:
            findings.append(
                ScanFinding(
                    rule_id="RULE-009D-KETO-CARBS",
                    severity=FindingSeverity.ALERT,
                    title="High Carbohydrate Level for Keto",
                    detail=f"Contains {carbs:.1f} g of carbs per serving. Exceeds standard keto target.",
                    nutrient_or_ingredient="carbs",
                    score_impact=30,
                )
            )
        elif sugars is not None and sugars > 4:
            findings.append(
                ScanFinding(
                    rule_id="RULE-009E-KETO-SUGAR",
                    severity=FindingSeverity.WARNING,
                    title="Contains Sugars (Non-Keto)",
                    detail=f"Contains {sugars:.1f} g of sugar.",
                    nutrient_or_ingredient="sugar",
                    score_impact=20,
                )
            )

    return findings


# ---------------------------------------------------------------------------
# RULE 10: OBESITY & WEIGHT LOSS
# ---------------------------------------------------------------------------

def _rule_obesity_weight_loss(
    product: ProductObservation, profile: UserProfile
) -> list[ScanFinding]:
    """RULE-010: High calorie density and high fat/sugar for obesity or weight loss."""
    findings: list[ScanFinding] = []
    has_weight_goal = (
        HealthCondition.OBESITY in profile.health_conditions
        or HealthGoal.WEIGHT_LOSS in profile.health_goals
    )
    if not has_weight_goal:
        return findings

    calories = product.nutrition.calories_kcal
    total_fat = product.nutrition.total_fat_g
    sugars = product.nutrition.sugars_g

    if calories is not None and calories > 350:
        findings.append(
            ScanFinding(
                rule_id="RULE-010A-CALORIES-HIGH",
                severity=FindingSeverity.WARNING,
                title="High Calorie Density",
                detail=f"Provides {calories:.0f} kcal per serving. Monitor calorie budget for weight management.",
                nutrient_or_ingredient="calories",
                score_impact=15,
            )
        )

    if total_fat is not None and total_fat > 18:
        findings.append(
            ScanFinding(
                rule_id="RULE-010B-FAT-HIGH",
                severity=FindingSeverity.WARNING,
                title="High Total Fat Content",
                detail=f"Contains {total_fat:.1f} g of fat per serving.",
                nutrient_or_ingredient="fat",
                score_impact=15,
            )
        )

    return findings


# ---------------------------------------------------------------------------
# Rule registry — ordered by clinical priority
# ---------------------------------------------------------------------------

RULES: list[RuleFn] = [
    _rule_allergy_conflict,
    _rule_gluten_celiac,
    _rule_kidney_disease,
    _rule_high_sugar_diabetes,
    _rule_high_sodium_hypertension,
    _rule_high_saturated_fat_cholesterol,
    _rule_dairy_lactose,
    _rule_ibs_fodmap,
    _rule_dietary_preferences,
    _rule_obesity_weight_loss,
    _rule_anaemia,
    _rule_caffeine_sensitivity,
]


# ---------------------------------------------------------------------------
# Scoring engine
# ---------------------------------------------------------------------------

def calculate_score(
    product: ProductObservation,
    profile: UserProfile,
    knowledge: list | None = None,
) -> ScoreResult:
    """
    Deterministic scoring engine.

    Applies all rules to (product, profile) and computes a score.
    Rules are independent — no LLM involvement.
    Score starts at 100 and rules subtract penalty points.
    Score is clamped to [0, 100].
    """
    all_findings: list[ScanFinding] = []
    rules_applied: list[str] = []

    rule_errors = 0
    for rule_fn in RULES:
        try:
            findings = rule_fn(product, profile)
            if findings:
                all_findings.extend(findings)
                rules_applied.append(rule_fn.__name__)
        except Exception:  # noqa: BLE001
            rule_errors += 1
            logging.getLogger(__name__).exception("Rule %s raised an exception", rule_fn.__name__)
            all_findings.append(
                ScanFinding(
                    rule_id=f"RULE-ERROR-{rule_fn.__name__.strip('_').upper()}",
                    severity=FindingSeverity.WARNING,
                    title="One check couldn't be completed",
                    detail=(
                        "A safety check hit an error, so this result may be incomplete. "
                        "Please read the label yourself."
                    ),
                    score_impact=0,
                )
            )

    total_penalty = sum(f.score_impact for f in all_findings)
    score = max(0, min(100, 100 - total_penalty))

    # A result with a failed check can never read as "excellent".
    if rule_errors:
        score = min(score, 79)

    # Hard stops: a matched allergen, or gluten for someone with celiac disease,
    # always means Not Suitable regardless of how clean the rest of the label is.
    hard_stop = any(
        f.rule_id.startswith(_HARD_STOP_RULE_IDS)
        or (f.rule_id == "RULE-005-GLUTEN" and f.severity == FindingSeverity.CRITICAL)
        for f in all_findings
    )
    if hard_stop:
        score = min(score, _HARD_STOP_SCORE_CAP)

    suitability = _suitability_from_score(score)
    risk_level = _SUITABILITY_TO_RISK[suitability]

    return ScoreResult(
        score=score,
        suitability=suitability,
        risk_level=risk_level,
        findings=all_findings,
        rules_applied=rules_applied,
    )
