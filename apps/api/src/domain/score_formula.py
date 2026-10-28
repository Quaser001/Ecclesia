"""Findings to a score out of 10: score = 10 x the product of one factor per finding.

The rules (scoring_rules.py) decide WHAT is wrong for this person; this
module decides HOW MUCH it costs. The curves and factors live in
rule_catalog.py so they can be reviewed with the thresholds they use.

Why a product and not an average: averaging lets things that are fine hide
a real problem (zero fat would "make up for" a can of sugar for a diabetic),
and every check that doesn't apply would dilute the ones that do. A product
ignores what doesn't apply (factor 1) and lets a serious problem pull the
score down on its own.

The score is an integer 0-100: tenths of the 0.0-10.0 shown to people, so
storage, history and averages stay whole numbers with one-decimal precision.
"""

from __future__ import annotations

from src.domain.models import FindingSeverity, ProductObservation, ScanFinding
from src.domain.rule_catalog import (
    CELIAC_GLUTEN_RULE_ID,
    CURVE_BY_RULE,
    HARD_STOP_RULE_IDS,
    POSITIVE_FACTOR,
    POSITIVE_RULE_IDS,
    SEVERITY_FACTOR,
)


def is_hard_stop(finding: ScanFinding) -> bool:
    return finding.rule_id in HARD_STOP_RULE_IDS or (
        finding.rule_id == CELIAC_GLUTEN_RULE_ID and finding.severity == FindingSeverity.CRITICAL
    )


def factor_for(finding: ScanFinding, product: ProductObservation) -> float:
    """How much one finding multiplies the score by (0 = hard stop)."""
    if is_hard_stop(finding):
        return 0.0
    if finding.rule_id.startswith("RULE-ERROR-"):
        return 1.0  # a check that crashed costs nothing itself; the score is capped instead
    if finding.rule_id in POSITIVE_RULE_IDS:
        return POSITIVE_FACTOR
    curve = CURVE_BY_RULE.get(finding.rule_id)
    if curve is not None:
        value = getattr(product.nutrition, curve.field, None)
        if value is not None:
            return curve.factor(float(value))
    return SEVERITY_FACTOR.get(finding.severity, 1.0)


def _tenths(p: float) -> int:
    return max(0, min(100, round(p * 100)))


def combine(
    findings: list[ScanFinding], product: ProductObservation
) -> tuple[int, list[ScanFinding]]:
    """The score in tenths, and the findings with each one's own cost.

    A finding's `score_impact` becomes what the score would gain without it
    (in tenths; negative for a finding that helps). Under multiplication
    these don't add up to the total, but each is exactly "this one cost you
    X" on its own.
    """
    factors = [factor_for(f, product) for f in findings]
    total = 1.0
    for f in factors:
        total *= f
    score = _tenths(total)

    priced: list[ScanFinding] = []
    for i, finding in enumerate(findings):
        if factors[i] == 0.0:
            # A hard stop excludes the product whatever else is true, so it
            # always "costs" the full 10, never a misleading "-0.4" just
            # because something else already sank the score.
            priced.append(finding.model_copy(update={"score_impact": 100}))
            continue
        without = 1.0
        for j, f in enumerate(factors):
            if j != i:
                without *= f
        priced.append(finding.model_copy(update={"score_impact": _tenths(without) - score}))
    return score, priced


def format_score(tenths: int) -> str:
    """6.3 out of 10 from the stored 63."""
    return f"{tenths / 10:.1f}"
