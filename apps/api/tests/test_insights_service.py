"""Insights are arithmetic over the user's own stored scans — nothing invented."""

from __future__ import annotations

import json
from datetime import date, datetime, timezone

from src.domain.models import FindingSeverity, SuitabilityStatus
from src.services.insights_service import build_insights

TODAY = date(2026, 10, 28)  # a Wednesday; its week starts Monday 26 Oct


def _finding(rule_id, title, severity="warning"):
    return {"rule_id": rule_id, "severity": severity, "title": title, "detail": "d"}


def _row(scan_id, day, name, brand, score, suitability, findings=()):
    return {
        "scan_id": scan_id,
        "scanned_at": datetime(2026, 10, day, 9, 0, tzinfo=timezone.utc).isoformat(),
        "product_name": name,
        "brand": brand,
        "score": score,
        "suitability": suitability,
        "score_json": json.dumps({
            "score": score, "suitability": suitability, "risk_level": "low",
            "findings": list(findings), "rules_applied": [],
        }),
    }


ROWS = [
    _row("a", 27, "Kurkure Masala Munch", "Kurkure", 0, "not_suitable",
         [_finding("R-SODIUM", "High sodium", "alert"), _finding("R-FAT", "Saturated fat")]),
    _row("b", 26, "Amul Lassi", "Amul", 60, "good",
         [_finding("R-SUGAR", "Very high sugar", "critical")]),
    _row("c", 20, "Good Day Butter Cookies", "Britannia", 25, "poor",
         [_finding("R-SUGAR", "Very high sugar", "critical"), _finding("R-FAT", "Saturated fat")]),
    _row("d", 19, "Amul Lassi", "Amul", 85, "excellent",
         [_finding("R-IRON", "Iron-rich serving", "info")]),
    _row("e", 2, "Rolled Oats", "Saffola", 95, "excellent"),
]


def test_empty_history_gives_empty_insights():
    out = build_insights([], today=TODAY)

    assert out.total_scans == 0
    assert out.average_score is None
    assert out.top_flags == [] and out.best == [] and out.needs_attention == []
    assert len(out.weekly) == 8 and all(w.scans == 0 for w in out.weekly)


def test_totals_average_and_suitability_mix():
    out = build_insights(ROWS, today=TODAY)

    assert out.total_scans == 5
    assert out.average_score == round((0 + 60 + 25 + 85 + 95) / 5)
    assert out.suitability_counts[SuitabilityStatus.EXCELLENT] == 2
    assert out.suitability_counts[SuitabilityStatus.NOT_SUITABLE] == 1
    assert out.suitability_counts[SuitabilityStatus.FAIR] == 0


def test_weekly_series_is_eight_monday_weeks_ending_this_week():
    out = build_insights(ROWS, today=TODAY)

    assert [w.week_start for w in out.weekly][-1] == date(2026, 10, 26)
    assert out.weekly[0].week_start == date(2026, 9, 7)
    this_week, last_week = out.weekly[-1], out.weekly[-2]
    assert (this_week.scans, this_week.average_score) == (2, 30)
    assert (last_week.scans, last_week.average_score) == (2, 55)
    assert out.weekly[-3].week_start == date(2026, 10, 12)
    assert (out.weekly[-3].scans, out.weekly[-3].average_score) == (0, None)  # no scans: unknown, not 0
    assert out.weekly[-5].average_score == 95  # the oats scan on 2 Oct


def test_top_flags_count_scans_and_skip_info():
    out = build_insights(ROWS, today=TODAY)

    by_rule = {f.rule_id: f for f in out.top_flags}
    assert by_rule["R-SUGAR"].count == 2
    assert by_rule["R-SUGAR"].severity == FindingSeverity.CRITICAL
    assert by_rule["R-FAT"].count == 2
    assert "R-IRON" not in by_rule  # informational, not an issue
    assert out.top_flags[0].rule_id == "R-SUGAR"  # ties broken by severity


def test_best_and_needs_attention_dedupe_products():
    """Best: distinct products scoring 60+, highest first. Needs attention:
    distinct products scoring under 40, lowest first. Up to 3 each."""
    out = build_insights(ROWS, today=TODAY)

    assert [p.product_name for p in out.best] == ["Rolled Oats", "Amul Lassi"]
    assert out.best[1].score == 85  # the product's best reading, not its latest
    assert [p.product_name for p in out.needs_attention] == [
        "Kurkure Masala Munch", "Good Day Butter Cookies",
    ]
    best_names = {p.product_name for p in out.best}
    assert not best_names & {p.product_name for p in out.needs_attention}


def test_rows_with_unreadable_score_json_still_count():
    rows = [dict(ROWS[0], score_json="not json")]
    out = build_insights(rows, today=TODAY)

    assert out.total_scans == 1
    assert out.top_flags == []
