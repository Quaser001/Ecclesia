"""
CalFit rule catalog — the single source of truth for every scoring threshold.

A dietitian can review this file end to end without reading Python logic:
each entry says what the rule is, which condition triggers it, which nutrient
or ingredient it checks, the threshold and direction, the severity, the score
impact, which authority the threshold comes from, and whether the rule is
backed by clinical consensus (`strong`) or is a personal sensitivity the user
asked to track (`sensitivity`).

The engine in `scoring_rules.py` reads thresholds and metadata from this file
and attaches `source` and `evidence_tier` to every finding, so users can see
why a product was flagged.

Order below mirrors the launch priority:
  1. Allergens
  2. Diabetes / prediabetes
  3. Hypertension / heart disease (sodium)
  4. High cholesterol / heart disease (fat, cholesterol)
  5. Anaemia
  6. (Celiac, dairy, kidney, IBS, dietary preferences, weight — supported)

Removed:
  - Hypotension. There is no safe general dietary rule to encode (telling a
    hypertensive user to eat more salt is dangerous), so it is not supported.

Sensitivity (non-medical, user-toggled):
  - Caffeine (period-cramp preference). Inferred from the ingredient list only
    because Indian labels rarely print caffeine in mg.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from src.domain.models import EvidenceTier, FindingSeverity

# ---------------------------------------------------------------------------
# Source citations
# ---------------------------------------------------------------------------

SRC_WHO_SODIUM = "WHO sodium intake guideline (2012): < 2 g sodium / day for adults."
SRC_WHO_SUGAR = "WHO sugars guideline (2015): free sugars < 10% of daily energy."
SRC_WHO_TFA = "WHO trans-fat guidance (2018): < 1% of daily energy; eliminate industrially produced."
SRC_FSSAI_HFSS = (
    "FSSAI labelling and front-of-pack regulations: thresholds for high "
    "fat/sugar/salt packaged foods."
)
SRC_FSSAI_IRON_FORT = (
    "FSSAI fortification standards: '+F' fortified foods carry ≥ 1.4-2.8 mg iron / 10 g (wheat/rice)."
)
SRC_ICMR_NIN = "ICMR-NIN Dietary Guidelines for Indians (2024): RDA iron 29 mg/day (adult woman)."
SRC_NFHS_5 = "NFHS-5 (2019-21): 57% of Indian women aged 15-49 are anaemic."
SRC_AHA_SATFAT = (
    "American Heart Association (2017): limit saturated fat to < 6% of daily energy "
    "for people managing cholesterol."
)
SRC_AHA_CHOL = "American Heart Association: < 300 mg dietary cholesterol / day for the general population."
SRC_KDIGO = "KDIGO clinical practice guideline: sodium < 2 g / day in CKD."
SRC_CELIAC = "Codex Alimentarius: gluten-free is < 20 ppm; any gluten source is unsafe in celiac disease."
SRC_INTERNAL = "CalFit internal threshold — a conservative default pending a cited source."
SRC_USER_PREFERENCE = "User sensitivity, not a medical rule. Based on the ingredient list only."

# ---------------------------------------------------------------------------
# RuleSpec — declarative description of a single threshold
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class RuleSpec:
    """One reviewable row in the rule catalog.

    rule_id          Stable identifier of the form RULE-NNNX-NAME.
    condition        Health condition / goal / preference / sensitivity in plain words.
    nutrient_or_ing  What the rule checks (e.g. 'sodium', 'added sugar', 'peanut').
    threshold        The number used in the comparison. None for ingredient-presence rules.
    unit             'mg', 'g', 'kcal', '' etc. For documentation only.
    direction        '>', '>=', '<', '<=', or 'presence'.
    severity         FindingSeverity assigned to the finding.
    score_impact     Positive integer — points subtracted from the 100 baseline.
    source           Short citation of the authority the threshold comes from.
    tier             'strong' for clinical consensus, 'sensitivity' for personal.
    title            Short headline shown to the user.
    detail_template  Short rationale. Substitute '{value}' for the measured number.
    notes            Any reviewer notes — flag anything uncertain here.
    """

    rule_id: str
    condition: str
    nutrient_or_ingredient: str
    threshold: Optional[float]
    unit: str
    direction: str
    severity: FindingSeverity
    score_impact: int
    source: str
    tier: EvidenceTier
    title: str
    detail_template: str
    notes: str = ""


# ---------------------------------------------------------------------------
# 1. Allergens
# ---------------------------------------------------------------------------

ALLERGY_DECLARED = RuleSpec(
    rule_id="RULE-001A-ALLERGY-DECLARED",
    condition="User-declared allergy",
    nutrient_or_ingredient="allergen",
    threshold=None, unit="", direction="presence",
    severity=FindingSeverity.CRITICAL, score_impact=50,
    source="FSSAI allergen-labelling rules; FDA Food Allergen Labeling and Consumer Protection Act.",
    tier=EvidenceTier.STRONG,
    title="Declared allergen matches your profile",
    detail_template="The 'Contains' statement lists {match}, which matches your allergy ({allergy}).",
    notes="Hard stop: score capped at 15.",
)

ALLERGY_INGREDIENT = RuleSpec(
    rule_id="RULE-001B-ALLERGY-INGREDIENT",
    condition="User-declared allergy",
    nutrient_or_ingredient="allergen",
    threshold=None, unit="", direction="presence",
    severity=FindingSeverity.CRITICAL, score_impact=45,
    source="FSSAI allergen-labelling rules; FDA FALCPA; CalFit allergen synonym vocabulary.",
    tier=EvidenceTier.STRONG,
    title="Allergen found in ingredients",
    detail_template="Ingredient '{match}' contains your allergen ({allergy}).",
    notes="Hard stop: score capped at 15.",
)

ALLERGY_UNVERIFIED = RuleSpec(
    rule_id="RULE-001C-ALLERGY-UNVERIFIED",
    condition="User-declared allergy with unreadable label",
    nutrient_or_ingredient="allergens",
    threshold=None, unit="", direction="presence",
    severity=FindingSeverity.ALERT, score_impact=25,
    source=SRC_INTERNAL,
    tier=EvidenceTier.STRONG,
    title="Couldn't check your allergens",
    detail_template=(
        "We couldn't read the ingredient list, so we can't confirm this product "
        "is free of your allergens. Check the label yourself."
    ),
)

ALLERGY_MAY_CONTAIN = RuleSpec(
    rule_id="RULE-001D-ALLERGY-MAY-CONTAIN",
    condition="User-declared allergy + cross-contact warning on label",
    nutrient_or_ingredient="allergen",
    threshold=None, unit="", direction="presence",
    severity=FindingSeverity.ALERT, score_impact=30,
    source="FSSAI advisory on precautionary allergen labelling.",
    tier=EvidenceTier.STRONG,
    title="Possible cross-contact with your allergen",
    detail_template=(
        "The pack says it may contain {match}, which matches your allergy ({allergy}). "
        "This is a shared-facility warning, not a declared ingredient."
    ),
)

# ---------------------------------------------------------------------------
# 2. Diabetes / blood-sugar management (sugar per serving)
# ---------------------------------------------------------------------------

SUGAR_EXTREME = RuleSpec(
    rule_id="RULE-003A-SUGAR-EXTREME",
    condition="Diabetes type 1/2, prediabetes, or 'manage blood sugar' goal",
    nutrient_or_ingredient="sugars",
    threshold=20, unit="g", direction=">",
    severity=FindingSeverity.CRITICAL, score_impact=55,
    source=SRC_WHO_SUGAR,
    tier=EvidenceTier.STRONG,
    title="Critical sugar level for diabetes",
    detail_template="{value:.1f} g of sugar per serving — a severe glycaemic load.",
)

SUGAR_VERY_HIGH = RuleSpec(
    rule_id="RULE-003B-SUGAR-VERY-HIGH",
    condition="Diabetes type 1/2, prediabetes, or 'manage blood sugar' goal",
    nutrient_or_ingredient="sugars",
    threshold=12, unit="g", direction=">",
    severity=FindingSeverity.CRITICAL, score_impact=40,
    source=SRC_WHO_SUGAR,
    tier=EvidenceTier.STRONG,
    title="Very high sugar content",
    detail_template="{value:.1f} g of sugar per serving will cause a rapid glucose rise.",
)

SUGAR_HIGH = RuleSpec(
    rule_id="RULE-003C-SUGAR-HIGH",
    condition="Diabetes type 1/2, prediabetes, or 'manage blood sugar' goal",
    nutrient_or_ingredient="sugars",
    threshold=6, unit="g", direction=">",
    severity=FindingSeverity.ALERT, score_impact=25,
    source=SRC_WHO_SUGAR,
    tier=EvidenceTier.STRONG,
    title="Elevated sugar content",
    detail_template="{value:.1f} g of sugar per serving. Watch your glucose response.",
)

SUGAR_MODERATE = RuleSpec(
    rule_id="RULE-003D-SUGAR-MODERATE",
    condition="Diabetes type 1/2, prediabetes, or 'manage blood sugar' goal",
    nutrient_or_ingredient="sugars",
    threshold=3, unit="g", direction=">",
    severity=FindingSeverity.WARNING, score_impact=15,
    source=SRC_WHO_SUGAR,
    tier=EvidenceTier.STRONG,
    title="Contains added sugar",
    detail_template="{value:.1f} g of sugar per serving.",
)

SUGAR_HIGH_GI = RuleSpec(
    rule_id="RULE-003E-HIGH-GI-INGREDIENTS",
    condition="Diabetes / blood-sugar management, when sugar value cannot be read",
    nutrient_or_ingredient="refined carbs / sugars (ingredients)",
    threshold=None, unit="", direction="presence",
    severity=FindingSeverity.CRITICAL, score_impact=30,
    source="ICMR-NIN guidance on refined carbs and glycaemic index.",
    tier=EvidenceTier.STRONG,
    title="High-glycaemic ingredients",
    detail_template="Contains refined carbs or sugars: {matches}.",
    notes="Only fires if no numeric sugar rule above matched, to avoid double-counting.",
)

# ---------------------------------------------------------------------------
# 3. Hypertension / heart disease (sodium per serving)
# ---------------------------------------------------------------------------

SODIUM_CRITICAL = RuleSpec(
    rule_id="RULE-002A-SODIUM-CRITICAL",
    condition="Hypertension, heart disease or 'heart health' goal",
    nutrient_or_ingredient="sodium",
    threshold=800, unit="mg", direction=">",
    severity=FindingSeverity.CRITICAL, score_impact=40,
    source=SRC_WHO_SODIUM,
    tier=EvidenceTier.STRONG,
    title="Critical sodium warning",
    detail_template="{value:.0f} mg of sodium per serving raises blood pressure.",
)

SODIUM_HIGH = RuleSpec(
    rule_id="RULE-002B-SODIUM-HIGH",
    condition="Hypertension, heart disease or 'heart health' goal",
    nutrient_or_ingredient="sodium",
    threshold=400, unit="mg", direction=">",
    severity=FindingSeverity.ALERT, score_impact=25,
    source=SRC_WHO_SODIUM,
    tier=EvidenceTier.STRONG,
    title="High sodium",
    detail_template="{value:.0f} mg of sodium per serving — consider a lower-sodium option.",
)

SODIUM_MODERATE = RuleSpec(
    rule_id="RULE-002C-SODIUM-MODERATE",
    condition="Hypertension, heart disease or 'heart health' goal",
    nutrient_or_ingredient="sodium",
    threshold=200, unit="mg", direction=">",
    severity=FindingSeverity.WARNING, score_impact=15,
    source=SRC_WHO_SODIUM,
    tier=EvidenceTier.STRONG,
    title="Moderate sodium",
    detail_template="{value:.0f} mg of sodium per serving.",
)

SODIUM_COMPOUNDS = RuleSpec(
    rule_id="RULE-002D-SODIUM-COMPOUNDS",
    condition="Hypertension, heart disease or 'heart health' goal, when sodium value cannot be read",
    nutrient_or_ingredient="salt / sodium additives (ingredients)",
    threshold=None, unit="", direction="presence",
    severity=FindingSeverity.ALERT, score_impact=25,
    source=SRC_FSSAI_HFSS,
    tier=EvidenceTier.STRONG,
    title="Salty ingredients",
    detail_template="Contains high-sodium ingredients: {matches}.",
    notes="Only fires when numeric sodium is unreadable.",
)

# ---------------------------------------------------------------------------
# 4. High cholesterol / heart health (saturated, trans, cholesterol)
# ---------------------------------------------------------------------------

SATFAT_VERY_HIGH = RuleSpec(
    rule_id="RULE-004A-SATFAT-VERY-HIGH",
    condition="High cholesterol, heart disease, or heart-health goal",
    nutrient_or_ingredient="saturated fat",
    threshold=7, unit="g", direction=">",
    severity=FindingSeverity.CRITICAL, score_impact=35,
    source=SRC_AHA_SATFAT,
    tier=EvidenceTier.STRONG,
    title="Very high saturated fat",
    detail_template="{value:.1f} g of saturated fat per serving raises LDL cholesterol.",
)

SATFAT_HIGH = RuleSpec(
    rule_id="RULE-004B-SATFAT-HIGH",
    condition="High cholesterol, heart disease, or heart-health goal",
    nutrient_or_ingredient="saturated fat",
    threshold=3.5, unit="g", direction=">",
    severity=FindingSeverity.ALERT, score_impact=20,
    source=SRC_AHA_SATFAT,
    tier=EvidenceTier.STRONG,
    title="High saturated fat",
    detail_template="{value:.1f} g of saturated fat per serving.",
)

TRANSFAT_ANY = RuleSpec(
    rule_id="RULE-004C-TRANSFAT-DANGER",
    condition="High cholesterol, heart disease, or heart-health goal",
    nutrient_or_ingredient="trans fat",
    threshold=0.1, unit="g", direction=">",
    severity=FindingSeverity.CRITICAL, score_impact=50,
    source=SRC_WHO_TFA,
    tier=EvidenceTier.STRONG,
    title="Trans fat detected",
    detail_template="{value:.1f} g of trans fat — raises LDL and lowers HDL.",
)

CHOLESTEROL_HIGH = RuleSpec(
    rule_id="RULE-004D-CHOLESTEROL-HIGH",
    condition="High cholesterol, heart disease, or heart-health goal",
    nutrient_or_ingredient="dietary cholesterol",
    threshold=60, unit="mg", direction=">",
    severity=FindingSeverity.ALERT, score_impact=20,
    source=SRC_AHA_CHOL,
    tier=EvidenceTier.STRONG,
    title="Elevated dietary cholesterol",
    detail_template="{value:.0f} mg of cholesterol per serving.",
)

BAD_FAT_INGREDIENTS = RuleSpec(
    rule_id="RULE-004E-BAD-FAT-INGREDIENT",
    condition="High cholesterol, heart disease, or heart-health goal",
    nutrient_or_ingredient="atherogenic oils (ingredients)",
    threshold=None, unit="", direction="presence",
    severity=FindingSeverity.ALERT, score_impact=25,
    source="AHA guidance on tropical and hydrogenated oils.",
    tier=EvidenceTier.STRONG,
    title="Atherogenic oils detected",
    detail_template="Contains: {matches}. These oils are associated with higher LDL.",
)

# ---------------------------------------------------------------------------
# 5. Anaemia / iron deficiency
#
# Context: 57% of Indian women aged 15-49 are anaemic (NFHS-5), so this is
# the single most relevant condition for our first audience. These rules are
# conservative — iron content on an Indian label is often absent, and iron
# fortification is a positive signal rather than a warning.
# ---------------------------------------------------------------------------

ANAEMIA_IRON_RICH = RuleSpec(
    rule_id="RULE-011A-ANAEMIA-IRON-RICH",
    condition="Anaemia / iron deficiency",
    nutrient_or_ingredient="iron",
    threshold=4.0, unit="mg", direction=">=",
    severity=FindingSeverity.INFO, score_impact=-10,
    source=SRC_ICMR_NIN,
    tier=EvidenceTier.STRONG,
    title="Iron-rich serving",
    detail_template="{value:.1f} mg of iron per serving — a useful contribution toward the 29 mg/day RDA.",
    notes="Negative score_impact = BONUS. See scoring_rules.py for sign handling.",
)

ANAEMIA_FORTIFIED = RuleSpec(
    rule_id="RULE-011B-ANAEMIA-FORTIFIED",
    condition="Anaemia / iron deficiency",
    nutrient_or_ingredient="iron fortification (+F)",
    threshold=None, unit="", direction="presence",
    severity=FindingSeverity.INFO, score_impact=-5,
    source=SRC_FSSAI_IRON_FORT,
    tier=EvidenceTier.STRONG,
    title="Fortified with iron",
    detail_template="Label indicates iron fortification: {matches}.",
    notes="Positive signal, small bonus. +F logo and 'iron fortified' claims both count.",
)

ANAEMIA_VITAMIN_C_AID = RuleSpec(
    rule_id="RULE-011C-ANAEMIA-VITAMIN-C",
    condition="Anaemia / iron deficiency",
    nutrient_or_ingredient="vitamin C (ingredients)",
    threshold=None, unit="", direction="presence",
    severity=FindingSeverity.INFO, score_impact=0,
    source="ICMR-NIN: vitamin C enhances non-haem iron absorption.",
    tier=EvidenceTier.STRONG,
    title="May help iron absorption",
    detail_template="Vitamin C in {matches} can help your body absorb iron from the same meal.",
    notes="Pure information. No score impact.",
)

ANAEMIA_INHIBITOR = RuleSpec(
    rule_id="RULE-011D-ANAEMIA-INHIBITOR",
    condition="Anaemia / iron deficiency",
    nutrient_or_ingredient="tea / coffee (ingredients)",
    threshold=None, unit="", direction="presence",
    severity=FindingSeverity.WARNING, score_impact=10,
    source="ICMR-NIN: tannins/polyphenols in tea and coffee reduce non-haem iron absorption.",
    tier=EvidenceTier.STRONG,
    title="May reduce iron absorption",
    detail_template="Contains {matches}. Keep tea or coffee one hour away from iron-rich meals.",
    notes="Review: the magnitude is uncertain; keep severity at WARNING, not ALERT.",
)

# ---------------------------------------------------------------------------
# 6. Extraction confidence gate (not a user-facing rule, but a scored policy)
# ---------------------------------------------------------------------------

MIN_EXTRACTION_CONFIDENCE = 0.4
"""Below this, we return insufficient-data instead of a verdict.

A low extraction_confidence means Gemini itself wasn't sure about the label.
Giving a confident "Not Suitable" or "Good" from a shaky read is the worst
possible failure mode for a health app. Rationale documented alongside the
pipeline in `scan_graph.py:node_validate_extraction`.
"""

# ---------------------------------------------------------------------------
# 7. Caffeine sensitivity (period cramps etc) — NON-MEDICAL
# ---------------------------------------------------------------------------

CAFFEINE_SENSITIVITY = RuleSpec(
    rule_id="RULE-012-CAFFEINE-SENSITIVITY",
    condition="User set 'avoid caffeine' sensitivity",
    nutrient_or_ingredient="caffeine source (ingredients)",
    threshold=None, unit="", direction="presence",
    severity=FindingSeverity.INFO, score_impact=10,
    source=SRC_USER_PREFERENCE,
    tier=EvidenceTier.SENSITIVITY,
    title="Contains a source of caffeine",
    detail_template=(
        "Caffeine source on the ingredient list: {matches}. "
        "Flagged because of your sensitivity, not as a medical warning."
    ),
    notes=(
        "Indian labels rarely print caffeine in mg, so we infer only from "
        "ingredients: coffee, tea, guarana, cola nut, mate, kola nut."
    ),
)

# ---------------------------------------------------------------------------
# Index — every rule, in order a dietitian would want to see them
# ---------------------------------------------------------------------------

RULE_CATALOG: list[RuleSpec] = [
    # Allergens
    ALLERGY_DECLARED, ALLERGY_INGREDIENT, ALLERGY_UNVERIFIED, ALLERGY_MAY_CONTAIN,
    # Diabetes / blood sugar
    SUGAR_EXTREME, SUGAR_VERY_HIGH, SUGAR_HIGH, SUGAR_MODERATE, SUGAR_HIGH_GI,
    # Hypertension / sodium
    SODIUM_CRITICAL, SODIUM_HIGH, SODIUM_MODERATE, SODIUM_COMPOUNDS,
    # Cholesterol / heart
    SATFAT_VERY_HIGH, SATFAT_HIGH, TRANSFAT_ANY, CHOLESTEROL_HIGH, BAD_FAT_INGREDIENTS,
    # Anaemia
    ANAEMIA_IRON_RICH, ANAEMIA_FORTIFIED, ANAEMIA_VITAMIN_C_AID, ANAEMIA_INHIBITOR,
    # Caffeine sensitivity
    CAFFEINE_SENSITIVITY,
]


_BY_ID: dict[str, RuleSpec] = {r.rule_id: r for r in RULE_CATALOG}


def rule(rule_id: str) -> RuleSpec:
    """Look up a RuleSpec by id. Raises KeyError if unknown."""
    return _BY_ID[rule_id]


# ---------------------------------------------------------------------------
# Score formula: how findings become a score out of 10
# ---------------------------------------------------------------------------
#
#   score = 10 x P,   P = product of one factor per finding (each 0..1)
#
# - A measured nutrient (sugar, sodium, ...) is scored on a smooth curve, so
#   5.9 g and 6.1 g of sugar score almost the same: no cliffs at thresholds.
#   The curve is 1.0 where the rule starts to fire and falls through the
#   cited thresholds above (WHO, FSSAI, AHA, KDIGO) to a floor.
# - A rule with no quantity (an ingredient is present) uses its severity's
#   factor below.
# - A hard stop (your allergen, gluten with celiac disease, a product your
#   diet excludes) is 0, so the score is 0.
# - Factors multiply, so a serious problem can't be averaged away by things
#   that are fine, and checks that don't apply to you change nothing.
#
# The x-axis thresholds are the cited rule thresholds. The heights below are
# CalFit's judgment, not from a cited source: reviewers, change them here.
# Stored and sent as an integer 0-100 (tenths of a point); shown as 0.0-10.0.

SEVERITY_FACTOR: dict[FindingSeverity, float] = {
    FindingSeverity.INFO: 1.0,
    FindingSeverity.WARNING: 0.8,
    FindingSeverity.ALERT: 0.55,
    FindingSeverity.CRITICAL: 0.3,
}
POSITIVE_FACTOR = 1.1   # a finding that helps (iron-rich food for anaemia); score still caps at 10
CURVE_FLOOR = 0.05      # a measured excess never drives a score to 0 on its own
RULE_ERROR_CAP = 79     # a check that crashed: the result can't read as excellent (< 8.0)

# Hard stops: the product is excluded for this person, whatever else is true.
HARD_STOP_RULE_IDS = (
    "RULE-001A-ALLERGY-DECLARED", "RULE-001B-ALLERGY-INGREDIENT",
    "RULE-009A-VEGAN", "RULE-009B-VEGETARIAN", "RULE-009C-HALAL",
)
# Gluten is a hard stop only for celiac disease (its finding is CRITICAL then).
CELIAC_GLUTEN_RULE_ID = "RULE-005-GLUTEN"
# Findings that help rather than hurt.
POSITIVE_RULE_IDS = ("RULE-011A-ANAEMIA-IRON-RICH", "RULE-011B-ANAEMIA-FORTIFIED")


@dataclass(frozen=True)
class ScoreCurve:
    """One measured nutrient's effect on the score: (value, factor) anchors,
    linear in between, CURVE_FLOOR beyond the last anchor."""

    curve_id: str
    rule_ids: tuple[str, ...]  # findings scored on this curve
    field: str                 # NutritionInfo field holding the measured value
    unit: str
    points: tuple[tuple[float, float], ...]

    def factor(self, value: float) -> float:
        pts = self.points
        if value <= pts[0][0]:
            return 1.0
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            if value <= x1:
                return y0 + (y1 - y0) * (value - x0) / (x1 - x0)
        return CURVE_FLOOR


def _anchors(bands: list[tuple[float, FindingSeverity]]) -> tuple[tuple[float, float], ...]:
    """Curve anchors from a rule's thresholds, lowest first.

    1.0 where the first band starts; each later band starts at its severity's
    factor (half the previous one when two bands share a severity); the floor
    at twice the last threshold. A single-threshold rule reaches its severity
    factor at twice the threshold and the floor at four times.
    """
    points = [(bands[0][0], 1.0)]
    previous = 1.0
    for threshold, severity in bands[1:]:
        f = SEVERITY_FACTOR[severity]
        if f >= previous:
            f = previous / 2
        points.append((threshold, f))
        previous = f
    last = bands[-1][0]
    if len(bands) == 1:
        points += [(2 * last, SEVERITY_FACTOR[bands[0][1]]), (4 * last, CURVE_FLOOR)]
    else:
        points.append((2 * last, CURVE_FLOOR))
    return tuple(points)


def _bands(*rule_ids: str) -> list[tuple[float, FindingSeverity]]:
    specs = sorted((rule(r) for r in rule_ids), key=lambda s: s.threshold)
    return [(s.threshold, s.severity) for s in specs]


_SUGAR = ("RULE-003D-SUGAR-MODERATE", "RULE-003C-SUGAR-HIGH",
          "RULE-003B-SUGAR-VERY-HIGH", "RULE-003A-SUGAR-EXTREME")
_SODIUM = ("RULE-002C-SODIUM-MODERATE", "RULE-002B-SODIUM-HIGH", "RULE-002A-SODIUM-CRITICAL")
_SATFAT = ("RULE-004B-SATFAT-HIGH", "RULE-004A-SATFAT-VERY-HIGH")

# Thresholds of the rules that are not catalog rows yet (scoring_rules.py);
# test_score_formula.py checks each curve starts exactly where its rule fires.
KIDNEY_SODIUM_MG = 300.0
KETO_CARBS_G = 15.0
KETO_SUGAR_G = 4.0
WEIGHT_CALORIES_KCAL = 350.0
WEIGHT_FAT_G = 18.0
# SRC_WHO_SUGAR: free sugars < 10% of energy is 50 g a day at 2000 kcal, so
# 12 g (the RULE-003B line) is about a quarter of the day in one serving.
WEIGHT_SUGAR_G = 12.0

SCORE_CURVES: tuple[ScoreCurve, ...] = (
    ScoreCurve("sugar-blood-sugar", _SUGAR, "sugars_g", "g", _anchors(_bands(*_SUGAR))),
    ScoreCurve("sodium-blood-pressure", _SODIUM, "sodium_mg", "mg", _anchors(_bands(*_SODIUM))),
    ScoreCurve("satfat-cholesterol", _SATFAT, "saturated_fat_g", "g", _anchors(_bands(*_SATFAT))),
    ScoreCurve("cholesterol", ("RULE-004D-CHOLESTEROL-HIGH",), "cholesterol_mg", "mg",
               _anchors(_bands("RULE-004D-CHOLESTEROL-HIGH"))),
    ScoreCurve("trans-fat", ("RULE-004C-TRANSFAT-DANGER",), "trans_fat_g", "g",
               _anchors(_bands("RULE-004C-TRANSFAT-DANGER"))),
    ScoreCurve("sodium-kidney", ("RULE-008A-KIDNEY-SODIUM",), "sodium_mg", "mg",
               _anchors([(KIDNEY_SODIUM_MG, FindingSeverity.CRITICAL)])),
    ScoreCurve("carbs-keto", ("RULE-009D-KETO-CARBS",), "total_carbs_g", "g",
               _anchors([(KETO_CARBS_G, FindingSeverity.ALERT)])),
    ScoreCurve("sugar-keto", ("RULE-009E-KETO-SUGAR",), "sugars_g", "g",
               _anchors([(KETO_SUGAR_G, FindingSeverity.WARNING)])),
    ScoreCurve("calories-weight", ("RULE-010A-CALORIES-HIGH",), "calories_kcal", "kcal",
               _anchors([(WEIGHT_CALORIES_KCAL, FindingSeverity.WARNING)])),
    ScoreCurve("fat-weight", ("RULE-010B-FAT-HIGH",), "total_fat_g", "g",
               _anchors([(WEIGHT_FAT_G, FindingSeverity.WARNING)])),
    ScoreCurve("sugar-weight", ("RULE-010C-SUGAR-HIGH",), "sugars_g", "g",
               _anchors([(WEIGHT_SUGAR_G, FindingSeverity.WARNING)])),
)
CURVE_BY_RULE: dict[str, ScoreCurve] = {r: c for c in SCORE_CURVES for r in c.rule_ids}
