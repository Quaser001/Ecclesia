"""Summing up "was this right?" answers into numbers the evals can track."""

from __future__ import annotations

from typing import Any

from src.domain.models import FeedbackIssue


def summarize_feedback(rows: list[dict[str, Any]]) -> dict[str, Any]:
    """Totals over feedback rows of {"accurate": bool, "issues": [str]}.

    `accuracy_rate` is None with no answers yet, rather than a made-up 0 or 1.
    Issues outside the known list are ignored, not counted as "other".
    """
    total = len(rows)
    accurate = sum(1 for r in rows if r.get("accurate"))
    issues = {issue.value: 0 for issue in FeedbackIssue}
    for r in rows:
        for issue in r.get("issues") or []:
            if issue in issues:
                issues[issue] += 1
    return {
        "total": total,
        "accurate": accurate,
        "accuracy_rate": round(accurate / total, 3) if total else None,
        "issues": issues,
    }
