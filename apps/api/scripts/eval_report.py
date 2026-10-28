"""How often real users say a scan result was right, and what went wrong.

    cd apps/api
    python -m scripts.eval_report            # last 7 days
    python -m scripts.eval_report --days 30

Reads the configured database (Supabase when its keys are in .env, else the
local SQLite file) and prints totals only: no user ids, products or
per-person answers. Exits 1 when accuracy is below target on enough answers,
so it can gate a release or run as a scheduled check.

The offline counterpart is scripts/run_eval.py (labelled photos). See
docs/EVALS_AND_OBSERVABILITY.md for how the two fit together.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from datetime import datetime, timedelta, timezone
from typing import Any

# A scan is "right" when the user says so. Below this, look at the issue
# breakdown before shipping anything else.
TARGET_ACCURACY = 0.85
# Fewer answers than this and the rate is noise (one answer moves it 3+ points).
MIN_ANSWERS = 30

ISSUE_LABELS = {
    "wrong_product": "Wrong product identified",
    "wrong_nutrition": "Nutrition numbers wrong",
    "wrong_ingredients": "Ingredients wrong",
    "missed_allergen": "Missed an allergen (treat every one as urgent)",
    "score_unfair": "Score felt wrong",
    "other": "Something else",
}


def assess(summary: dict[str, Any]) -> tuple[str, bool]:
    """A one-line verdict and whether it should fail the check."""
    total = summary["total"]
    rate = summary["accuracy_rate"]
    if summary["issues"].get("missed_allergen"):
        return (f"ALERT: {summary['issues']['missed_allergen']} missed-allergen report(s). "
                "Review those scans before anything else.", True)
    if total < MIN_ANSWERS:
        return f"Not enough answers yet ({total} of {MIN_ANSWERS}) to judge accuracy.", False
    if rate < TARGET_ACCURACY:
        return f"BELOW TARGET: {rate:.0%} said right (target {TARGET_ACCURACY:.0%}).", True
    return f"On target: {rate:.0%} said right (target {TARGET_ACCURACY:.0%}).", False


def render(summary: dict[str, Any], days: int) -> str:
    verdict, _ = assess(summary)
    lines = [f"CalFit feedback, last {days} days", "",
             f"Answers:        {summary['total']}",
             f"Said right:     {summary['accurate']}"]
    if summary["accuracy_rate"] is not None:
        lines.append(f"Accuracy:       {summary['accuracy_rate']:.1%}")
    wrong = summary["total"] - summary["accurate"]
    if wrong:
        lines += ["", f"What was wrong ({wrong} answers; one answer can pick several):"]
        for key, count in sorted(summary["issues"].items(), key=lambda kv: -kv[1]):
            if count:
                lines.append(f"  {count:>4}  {ISSUE_LABELS.get(key, key)}")
    lines += ["", verdict]
    return "\n".join(lines)


async def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--days", type=int, default=7)
    parser.add_argument("--json", action="store_true", help="Machine-readable output.")
    args = parser.parse_args()

    from src.config.dependencies import get_supabase_provider

    since = datetime.now(timezone.utc) - timedelta(days=args.days)
    summary = await get_supabase_provider().get_feedback_summary(since=since)
    verdict, failed = assess(summary)
    if args.json:
        print(json.dumps({**summary, "days": args.days, "verdict": verdict, "failed": failed}))
    else:
        print(render(summary, args.days))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
