"""Build a user's insights from their stored scan rows. Deterministic."""

from __future__ import annotations

import json
from collections import defaultdict
from datetime import date, datetime, timedelta
from typing import Any, Iterable

from src.domain.insights import (
    FlagCount,
    GoalInsight,
    InsightsResponse,
    ProductPick,
    WeeklyPoint,
)
from src.domain.models import (
    FindingSeverity,
    HealthGoal,
    ProductObservation,
    SuitabilityStatus,
    UserProfile,
)
from src.domain.scoring_rules import calculate_score

WEEKS = 8
TOP_FLAGS = 5
PICKS = 3
BEST_MIN_SCORE = 60  # "good" or better
ATTENTION_MAX_SCORE = 40  # "poor" or "not suitable"

_SEVERITY_RANK = {
    FindingSeverity.CRITICAL: 3,
    FindingSeverity.ALERT: 2,
    FindingSeverity.WARNING: 1,
    FindingSeverity.INFO: 0,
}


def _scanned_on(row: dict[str, Any]) -> date:
    value = row["scanned_at"]
    if isinstance(value, datetime):
        return value.date()
    return datetime.fromisoformat(str(value).replace("Z", "+00:00")).date()


def _findings(row: dict[str, Any]) -> list[dict[str, Any]]:
    """Findings from the stored score_json; an unreadable blob has none."""
    raw = row.get("score_json")
    try:
        data = json.loads(raw) if isinstance(raw, str) else (raw or {})
        findings = data.get("findings") or []
        return [f for f in findings if isinstance(f, dict) and f.get("rule_id")]
    except (ValueError, AttributeError):
        return []


def _week_start(d: date) -> date:
    return d - timedelta(days=d.weekday())


def _pick(row: dict[str, Any]) -> ProductPick:
    return ProductPick(
        scan_id=row["scan_id"],
        product_name=row.get("product_name"),
        brand=row.get("brand"),
        score=int(row["score"]),
        suitability=SuitabilityStatus(row["suitability"]),
    )


def _distinct_products(rows: Iterable[dict[str, Any]], prefer_high: bool) -> list[dict[str, Any]]:
    """One row per product (name + brand), keeping its best or worst reading."""
    chosen: dict[tuple[str, str], dict[str, Any]] = {}
    for row in rows:
        name = (row.get("product_name") or "").strip().lower()
        if not name:
            continue
        key = (name, (row.get("brand") or "").strip().lower())
        current = chosen.get(key)
        better = current is None or (
            row["score"] > current["score"] if prefer_high else row["score"] < current["score"]
        )
        if better:
            chosen[key] = row
    return list(chosen.values())


def build_insights(
    rows: list[dict[str, Any]],
    today: date,
    goals: list[HealthGoal] | None = None,
) -> InsightsResponse:
    goal_cards = build_goal_insights(rows, goals or [])
    if not rows:
        this_week = _week_start(today)
        return InsightsResponse(
            goals=goal_cards,
            suitability_counts={s: 0 for s in SuitabilityStatus},
            weekly=[WeeklyPoint(week_start=this_week - timedelta(weeks=WEEKS - 1 - i))
                    for i in range(WEEKS)],
        )

    scores = [int(r["score"]) for r in rows]
    counts = {s: 0 for s in SuitabilityStatus}
    for r in rows:
        counts[SuitabilityStatus(r["suitability"])] += 1

    # Weekly series: the last WEEKS Monday-start weeks, ending this week.
    this_week = _week_start(today)
    starts = [this_week - timedelta(weeks=WEEKS - 1 - i) for i in range(WEEKS)]
    per_week: dict[date, list[int]] = defaultdict(list)
    for r in rows:
        per_week[_week_start(_scanned_on(r))].append(int(r["score"]))
    weekly = [
        WeeklyPoint(
            week_start=s,
            scans=len(per_week.get(s, [])),
            average_score=round(sum(per_week[s]) / len(per_week[s])) if per_week.get(s) else None,
        )
        for s in starts
    ]

    # Flags: how many scans each issue appeared on (once per scan), info excluded.
    flag_scans: dict[str, int] = defaultdict(int)
    flag_meta: dict[str, tuple[str, FindingSeverity]] = {}
    for r in rows:
        seen: set[str] = set()
        for f in _findings(r):
            try:
                severity = FindingSeverity(f.get("severity"))
            except ValueError:
                continue
            if severity == FindingSeverity.INFO or f["rule_id"] in seen:
                continue
            seen.add(f["rule_id"])
            flag_scans[f["rule_id"]] += 1
            title, known = flag_meta.get(f["rule_id"], (f.get("title") or f["rule_id"], severity))
            if _SEVERITY_RANK[severity] > _SEVERITY_RANK[known]:
                known = severity
            flag_meta[f["rule_id"]] = (title, known)
    top_flags = sorted(
        (FlagCount(rule_id=rid, title=flag_meta[rid][0], severity=flag_meta[rid][1], count=n)
         for rid, n in flag_scans.items()),
        key=lambda f: (-f.count, -_SEVERITY_RANK[f.severity], f.title),
    )[:TOP_FLAGS]

    best_rows = sorted(
        (r for r in _distinct_products(rows, prefer_high=True) if r["score"] >= BEST_MIN_SCORE),
        key=lambda r: -r["score"],
    )[:PICKS]
    best_keys = {(r.get("product_name") or "").strip().lower() for r in best_rows}
    attention_rows = sorted(
        (r for r in _distinct_products(rows, prefer_high=False)
         if r["score"] < ATTENTION_MAX_SCORE
         and (r.get("product_name") or "").strip().lower() not in best_keys),
        key=lambda r: r["score"],
    )[:PICKS]

    return InsightsResponse(
        total_scans=len(rows),
        average_score=round(sum(scores) / len(scores)),
        suitability_counts=counts,
        weekly=weekly,
        top_flags=top_flags,
        best=[_pick(r) for r in best_rows],
        needs_attention=[_pick(r) for r in attention_rows],
        goals=goal_cards,
    )


# ---------------------------------------------------------------------------
# Goals
# ---------------------------------------------------------------------------

PROTEIN_SUPPORT_G = 10.0  # per serving, for the muscle-gain check


def _product(row: dict[str, Any]) -> ProductObservation | None:
    raw = row.get("product_json")
    try:
        data = json.loads(raw) if isinstance(raw, str) else raw
        return ProductObservation.model_validate(data) if data else None
    except (ValueError, TypeError):
        return None


def _has(product: ProductObservation, *fields: str) -> bool:
    n = product.nutrition
    return any(getattr(n, f) is not None for f in fields)


# Goals judged by the scoring rules: (goal whose rules apply, data the rules
# need, plain-words basis). Maintaining weight reuses the weight-loss
# calorie-density rules.
_RULE_GOALS: dict[HealthGoal, tuple[HealthGoal, Any, str]] = {
    HealthGoal.WEIGHT_LOSS: (
        HealthGoal.WEIGHT_LOSS,
        lambda p: _has(p, "calories_kcal", "total_fat_g", "sugars_g"),
        "Calories, fat and sugar per serving",
    ),
    HealthGoal.MAINTAIN_WEIGHT: (
        HealthGoal.WEIGHT_LOSS,
        lambda p: _has(p, "calories_kcal", "total_fat_g", "sugars_g"),
        "Calories, fat and sugar per serving",
    ),
    HealthGoal.MANAGE_BLOOD_SUGAR: (
        HealthGoal.MANAGE_BLOOD_SUGAR,
        lambda p: _has(p, "sugars_g") or bool(p.ingredients),
        "Sugar per serving and high-glycaemic ingredients",
    ),
    HealthGoal.HEART_HEALTH: (
        HealthGoal.HEART_HEALTH,
        lambda p: _has(p, "sodium_mg", "saturated_fat_g", "trans_fat_g", "cholesterol_mg"),
        "Sodium, saturated fat, trans fat and cholesterol",
    ),
    HealthGoal.IMPROVE_DIGESTION: (
        HealthGoal.IMPROVE_DIGESTION,
        lambda p: bool(p.ingredients),
        "Ingredients that commonly upset digestion",
    ),
}


def _rule_goal(goal: HealthGoal, products: list[ProductObservation]) -> GoalInsight:
    rules_goal, needs, basis = _RULE_GOALS[goal]
    profile = UserProfile(user_id="insights", health_goals=[rules_goal])
    checked = fits = 0
    issues: dict[str, int] = defaultdict(int)
    for product in products:
        if not needs(product):
            continue
        checked += 1
        against = [
            f for f in calculate_score(product, profile).findings
            if not f.rule_id.startswith("RULE-001")  # allergy checks are not goals
            and f.severity != FindingSeverity.INFO
        ]
        if against:
            for title in {f.title for f in against}:
                issues[title] += 1
        else:
            fits += 1
    main = max(issues.items(), key=lambda kv: (kv[1], kv[0]))[0] if issues else None
    return GoalInsight(goal=goal, tracked=True, basis=basis, checked=checked,
                       fits=fits, main_issue=main)


def _protein_goal(goal: HealthGoal, products: list[ProductObservation]) -> GoalInsight:
    with_protein = [p for p in products if p.nutrition.protein_g is not None]
    fits = sum(1 for p in with_protein if p.nutrition.protein_g >= PROTEIN_SUPPORT_G)
    return GoalInsight(
        goal=goal,
        tracked=True,
        basis=f"{PROTEIN_SUPPORT_G:.0f} g protein or more per serving",
        checked=len(with_protein),
        fits=fits,
        main_issue=(f"Under {PROTEIN_SUPPORT_G:.0f} g protein per serving"
                    if fits < len(with_protein) else None),
    )


def build_goal_insights(rows: list[dict[str, Any]], goals: list[HealthGoal]) -> list[GoalInsight]:
    """One card per goal, in the profile's order."""
    products = [p for p in (_product(r) for r in rows) if p is not None]
    cards: list[GoalInsight] = []
    for goal in goals:
        if goal in _RULE_GOALS:
            cards.append(_rule_goal(goal, products))
        elif goal == HealthGoal.MUSCLE_GAIN:
            cards.append(_protein_goal(goal, products))
        else:
            cards.append(GoalInsight(
                goal=goal,
                tracked=False,
                basis="CalFit doesn't have a scoring rule for this goal yet",
            ))
    return cards
