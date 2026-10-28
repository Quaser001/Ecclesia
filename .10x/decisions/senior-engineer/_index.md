# Senior Engineer: cross-cutting

Confirmed by the founder on 2026-10-28. Review hot spots, places where bugs have actually happened.

- **Nutrition basis:** per serving vs per 100 g/ml. Label values are per serving (`serving_size_g`, set to 100 when the label only has a per-100 column). Database values are per 100. See `nutrition_merge.py`, `serving_memory.py` and `nutrient_levels.py`.
- **Product matching** must stay strict: a wrong match is fabricated data (`product_repository._match_strength`).
- **Confidence numbers mean what was asked.** `extraction_confidence` covers ingredients and nutrition; `identity_confidence` covers the name.
- **Double-encoded JSON:** `scans.product_json` and `score_json` are JSON text inside `jsonb`. Read with `_as_json`; SQL needs `(col #>> '{}')::jsonb`.
- **Explanations** must pass `is_explanation_grounded`. Numbers in the text have to appear in the facts, which use "N out of 10".
- **When changing real data:** back up, write, read back, then sanity-check the result.
