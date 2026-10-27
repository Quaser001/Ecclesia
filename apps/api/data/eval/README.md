# Evaluation set — labelled Indian products

This folder holds the labelled ground-truth set we score the pipeline against.
The one number that matters: **allergen recall**. A product whose label clearly
declares an allergen must come back with the matching finding every time.

## How to fill `labeled_products.csv`

One row per product. Fill it in by reading the packet by hand — never from
what Gemini extracts. The idea is that your row is the truth we grade against.

Columns:

| column | what to put in it |
|---|---|
| `product_id` | pre-filled `EV-NNN`, don't change |
| `brand` | brand on the pack, e.g. `Britannia` |
| `product_name` | as printed, e.g. `Marie Gold` |
| `category` | short label, e.g. `biscuit`, `instant noodles`, `juice` |
| `photo_path` | path to the photo, relative to this folder, e.g. `photos/EV-001.jpg` |
| `ground_truth_ingredients` | ingredient list copied verbatim, `;`-separated |
| `ground_truth_allergens` | comma list from the "Contains" statement, e.g. `wheat,milk` |
| `ground_truth_may_contain` | comma list from "may contain / shared facility" |
| `sodium_mg` | per serving, from the nutrition panel |
| `sugars_g` | per serving |
| `saturated_fat_g` | per serving |
| `iron_mg` | per serving if printed, else leave blank |
| `notes` | anything odd about the pack (dim lighting, small font, Hindi-only) |

Leave any field blank if the pack does not print it — the evaluator will
treat a blank as "label does not say" and score accordingly, which is exactly
what we want. A guessed value is worse than a blank one.

## Running the eval

From `apps/api/`:

```bash
uv run python scripts/run_eval.py --csv data/eval/labeled_products.csv --out data/eval/report.json
```

The runner needs a `GEMINI_API_KEY` in the environment. It prints:

- **Allergen recall** — the number that matters most. Missed declared allergens
  are the worst failure.
- **Nutrition field accuracy** — per-field mean error against ground truth.
- **Every disagreement** — one row per product × field where the pipeline
  differed from the label, so you can read each one and decide if it's a
  pipeline bug or a label that genuinely is unclear.

Rerun whenever rules, prompts, or the Gemini model change.
