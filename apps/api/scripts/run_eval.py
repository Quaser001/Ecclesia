"""
Evaluation harness: run the CalFit pipeline over a labelled CSV and report
how often it matches the ground truth.

Allergen recall is the primary metric. A wrong "safe" is the worst possible
failure, so we count a missed declared allergen as a false negative on recall,
and surface each one.
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import json
import logging
import math
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from src.providers.gemini_provider import GoogleGeminiProvider

logger = logging.getLogger("eval")


# ---------------------------------------------------------------------------
# Row model
# ---------------------------------------------------------------------------


@dataclass
class GTRow:
    product_id: str
    brand: str
    product_name: str
    category: str
    photo_path: str
    ingredients: list[str]
    allergens: list[str]
    may_contain: list[str]
    sodium_mg: float | None
    sugars_g: float | None
    saturated_fat_g: float | None
    iron_mg: float | None
    notes: str


def _parse_list(cell: str, sep: str = ",") -> list[str]:
    if not cell:
        return []
    return [p.strip().lower() for p in cell.split(sep) if p.strip()]


def _parse_num(cell: str) -> float | None:
    if not cell or not cell.strip():
        return None
    try:
        return float(cell)
    except ValueError:
        return None


def load_rows(path: Path) -> list[GTRow]:
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows: list[GTRow] = []
        for r in reader:
            if not (r.get("brand") or r.get("product_name") or r.get("photo_path")):
                continue  # empty template row
            rows.append(
                GTRow(
                    product_id=r.get("product_id", "") or "",
                    brand=(r.get("brand") or "").strip(),
                    product_name=(r.get("product_name") or "").strip(),
                    category=(r.get("category") or "").strip(),
                    photo_path=(r.get("photo_path") or "").strip(),
                    ingredients=_parse_list(r.get("ground_truth_ingredients", ""), sep=";"),
                    allergens=_parse_list(r.get("ground_truth_allergens", "")),
                    may_contain=_parse_list(r.get("ground_truth_may_contain", "")),
                    sodium_mg=_parse_num(r.get("sodium_mg", "")),
                    sugars_g=_parse_num(r.get("sugars_g", "")),
                    saturated_fat_g=_parse_num(r.get("saturated_fat_g", "")),
                    iron_mg=_parse_num(r.get("iron_mg", "")),
                    notes=r.get("notes", "") or "",
                )
            )
    return rows


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------


@dataclass
class Report:
    rows: int = 0
    allergen_true_positives: int = 0
    allergen_false_negatives: int = 0
    allergen_false_positives: int = 0
    nutrition_errors: dict[str, list[float]] = field(default_factory=dict)
    disagreements: list[dict[str, Any]] = field(default_factory=list)

    @property
    def allergen_recall(self) -> float:
        denom = self.allergen_true_positives + self.allergen_false_negatives
        return (self.allergen_true_positives / denom) if denom else float("nan")

    @property
    def allergen_precision(self) -> float:
        denom = self.allergen_true_positives + self.allergen_false_positives
        return (self.allergen_true_positives / denom) if denom else float("nan")

    def record_nutrition(self, field_name: str, gt: float | None, pred: float | None) -> None:
        if gt is None or pred is None:
            return
        self.nutrition_errors.setdefault(field_name, []).append(abs(pred - gt))

    def summary(self) -> dict[str, Any]:
        def mean(xs: list[float]) -> float:
            return sum(xs) / len(xs) if xs else float("nan")

        return {
            "rows": self.rows,
            "allergen_recall": self.allergen_recall,
            "allergen_precision": self.allergen_precision,
            "nutrition_mean_abs_error": {k: mean(v) for k, v in self.nutrition_errors.items()},
            "disagreement_count": len(self.disagreements),
        }


async def score_row(gemini: GoogleGeminiProvider, row: GTRow, report: Report) -> None:
    report.rows += 1
    photo = Path(row.photo_path)
    if not photo.is_absolute():
        # photos live next to the CSV
        photo = Path("data/eval") / photo
    if not photo.exists():
        print(f"[{row.product_id}] photo not found: {photo}", file=sys.stderr)
        return

    photo_bytes = photo.read_bytes()
    try:
        pred = await gemini.analyze_photo(photo_bytes)
    except Exception as exc:
        print(f"[{row.product_id}] extraction failed: {exc}", file=sys.stderr)
        return

    # Allergens: declared + may_contain in the ground truth count as positives.
    gt_all = set(row.allergens)
    pred_all = {a.lower().strip() for a in pred.allergens_declared}
    for a in gt_all:
        if a in pred_all:
            report.allergen_true_positives += 1
        else:
            report.allergen_false_negatives += 1
            report.disagreements.append({
                "product_id": row.product_id, "field": "allergen",
                "expected": a, "got": sorted(pred_all), "severity": "critical",
            })
    for a in pred_all - gt_all:
        report.allergen_false_positives += 1
        report.disagreements.append({
            "product_id": row.product_id, "field": "allergen",
            "expected": sorted(gt_all), "got": a, "severity": "warning",
        })

    # Nutrition errors
    report.record_nutrition("sodium_mg", row.sodium_mg, pred.nutrition.sodium_mg)
    report.record_nutrition("sugars_g", row.sugars_g, pred.nutrition.sugars_g)
    report.record_nutrition("saturated_fat_g", row.saturated_fat_g, pred.nutrition.saturated_fat_g)
    report.record_nutrition("iron_mg", row.iron_mg, pred.nutrition.iron_mg)

    # Nutrition disagreements that exceed 20% of the ground-truth value
    for name, gt, got in [
        ("sodium_mg", row.sodium_mg, pred.nutrition.sodium_mg),
        ("sugars_g", row.sugars_g, pred.nutrition.sugars_g),
        ("saturated_fat_g", row.saturated_fat_g, pred.nutrition.saturated_fat_g),
        ("iron_mg", row.iron_mg, pred.nutrition.iron_mg),
    ]:
        if gt is None or got is None:
            continue
        if gt > 0 and abs(got - gt) / gt > 0.2:
            report.disagreements.append({
                "product_id": row.product_id, "field": name,
                "expected": gt, "got": got, "severity": "warning",
            })


async def main() -> int:
    parser = argparse.ArgumentParser(description="Run CalFit evaluation harness.")
    parser.add_argument("--csv", required=True, type=Path, help="Labelled ground-truth CSV.")
    parser.add_argument("--out", type=Path, default=Path("data/eval/report.json"))
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(message)s")

    rows = load_rows(args.csv)
    if not rows:
        print("No labelled rows in CSV. Fill it in before running the eval.", file=sys.stderr)
        return 2

    gemini = GoogleGeminiProvider()
    report = Report()
    for r in rows:
        await score_row(gemini, r, report)

    summary = report.summary()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(
        {"summary": summary, "disagreements": report.disagreements},
        indent=2, default=lambda x: None if (isinstance(x, float) and math.isnan(x)) else x,
    ))

    print(f"Rows:              {summary['rows']}")
    print(f"Allergen recall:   {summary['allergen_recall']:.3f}")
    print(f"Allergen precision:{summary['allergen_precision']:.3f}")
    print(f"Nutrition MAE:     {summary['nutrition_mean_abs_error']}")
    print(f"Disagreements:     {summary['disagreement_count']} (see {args.out})")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
