# Architect: front-of-pack-identification

Confirmed by the founder on 2026-10-28. See ADR-003. `services/identification.py` (pure decision) and `providers/food_lookup.py` (Open Food Facts client).

- **Options shown are real products only.** If a brand was read, the option's brand must match. A matching pack size narrows the list.
- **The decision is plain code:**
  - doubtful name → retake;
  - one match → confident if identity confidence ≥ 0.8, otherwise confirm;
  - several matches → choose.
- **Confirm sends a product code; the server fetches the product again.** The photo is re-sent at confirm, so no orphan photos are left behind.
- **Provenance:** `data_source`, `source_code` and `source_date` are stored in `product_json`.
