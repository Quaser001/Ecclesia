# How CalFit scores a product (out of 10)

A score answers one question: **how well does this product fit *your* health profile?**

The score is deterministic. Code computes it from the label and your profile, so the same inputs always give the same score, and the AI is never involved in scoring.

## The formula

```
score = 10 × P        P = d₁ × d₂ × … × dₙ   (one factor per finding)
```

1. **The rules decide *what* is wrong for you.** For example, there's a sugar rule for diabetes and a sodium rule for hypertension, each with thresholds cited from WHO, FSSAI, AHA or KDIGO. They are in `apps/api/src/domain/rule_catalog.py` and `scoring_rules.py`.
2. **Each finding becomes a factor *d* between 0 and 1** (`score_formula.py`):
   - **Measured nutrient** (sugar, sodium, saturated fat, cholesterol, trans fat, kidney sodium, keto carbs/sugar, calories/fat for weight loss): a smooth curve through the rule's cited thresholds (see below).
   - **Ingredient present, no amount** (for example refined flour for diabetes): a fixed factor by severity. Heads up 0.8, caution 0.55, avoid 0.3.
   - **Hard stop**: 0, so the score is 0.
   - **Helps you** (iron-rich food for anaemia): 1.1. The score still never goes above 10.
3. **Multiply the factors.**
   - **Rule checks that don't apply to you** are factor 1, so they change nothing.
   - **Two problems compound:** 0.3 × 0.3 = 0.09.
   - **A crashed check** costs nothing itself, but it caps the score at 7.9, so the result can never read "excellent".

### Why a product, not an average

This is the multiplicative form of the **desirability-function** method:

- **Origin:** Harrington (1965); Derringer and Suich (1980), *Journal of Quality Technology*.
- **What it's for:** scoring one thing against several criteria at once.

An average would let things that are fine hide a real problem. With an average, zero fat would partly "make up for" a can of sugar for a diabetic, and every check that doesn't apply would dilute the ones that do. A product can't be gamed that way.

### The curves

Each curve is 1.0 exactly where its rule starts to fire, so there are no cliffs.

- **Later thresholds:** each one starts at its severity's factor, as long as that's below the previous point. When two bands share a severity, the second gets half the previous factor.
- **Floor:** the curve reaches 0.05 at twice the last threshold.
- **Single-threshold rules:** the curve hits its severity factor at 2× the threshold and the floor at 4×.

| Curve | Value → factor |
|---|---|
| Sugar, for diabetes or blood-sugar goal (g per serving) | 3 → 1.0 · 6 → 0.55 · 12 → 0.30 · 20 → 0.15 · 40 → 0.05 |
| Sodium, for hypertension, heart disease or the heart-health goal (mg) | 200 → 1.0 · 400 → 0.55 · 800 → 0.30 · 1600 → 0.05 |
| Saturated fat, for cholesterol or heart disease (g) | 3.5 → 1.0 · 7 → 0.30 · 14 → 0.05 |
| Dietary cholesterol (mg) | 60 → 1.0 · 120 → 0.55 · 240 → 0.05 |
| Trans fat (g) | 0.1 → 1.0 · 0.2 → 0.30 · 0.4 → 0.05 |
| Sodium, for kidney disease (mg) | 300 → 1.0 · 600 → 0.30 · 1200 → 0.05 |
| Carbs, for keto (g) | 15 → 1.0 · 30 → 0.55 · 60 → 0.05 |
| Sugar, for keto (g) | 4 → 1.0 · 8 → 0.80 · 16 → 0.05 |
| Calories, for weight loss (kcal) | 350 → 1.0 · 700 → 0.80 · 1400 → 0.05 |
| Fat, for weight loss (g) | 18 → 1.0 · 36 → 0.80 · 72 → 0.05 |
| Sugar, for weight loss (g) | 12 → 1.0 · 24 → 0.80 · 48 → 0.05 |

Sugar for weight loss (new 2026-10-29, cited to WHO's free-sugar guideline) is skipped when the diabetes sugar curve already applies, so the same grams aren't counted twice. Before it, a 53 g-sugar cola scored 10/10 for weight loss.

Between two points the factor is a straight line. Beyond the last point it is 0.05: a measured excess alone never reaches 0, only a hard stop does.

**What is cited and what is our judgment.** The x-values are the rules' cited thresholds. The heights (0.8, 0.55, 0.3, the halving and the 0.05 floor) are **CalFit's judgment**. They are labelled that way in `rule_catalog.py`, and a dietitian should review them before launch.

### Hard stops (score 0, "Not suitable")

- **A declared allergen**, or one found in the ingredients, matching your allergies.
- **Gluten**, if you have celiac disease.
- **A product your diet excludes**: meat or fish for vegetarians, any animal product for vegans, non-halal for halal. *New in this version.* These used to cost a fixed 40–50 points, so chicken noodles scored 60 ("good") for a vegetarian.

"May contain" is a caution (0.55), not a hard stop.

### Verdicts

| Score | Verdict |
|---|---|
| 8.0–10 | Excellent fit |
| 6.0–7.9 | Good fit |
| 4.0–5.9 | Fair |
| 2.0–3.9 | Poor fit |
| 0–1.9 | Not suitable |

## What each finding "cost"

The finding card shows **what that one finding cost you**: the score without it, minus the actual score. For example, sugar at 0.30 and sodium at 0.30 give a score of 0.9. Each card then says "−2.1", because without either finding the score would be 3.0.

These costs don't add up to the total, because the factors multiply. A hard stop always shows the full −10.0: it excludes the product whatever else is true.

## Storage

Scores are stored and sent as an integer 0–100, meaning tenths of a point. The app shows 63 as "6.3". This keeps history, averages and the database in whole numbers with one-decimal precision. It's the same technique as storing money in paise.

## Examples: old engine (out of 100) vs new (out of 10)

| Product | No conditions | Type 1 diabetes | Hypertension | High cholesterol | Peanut allergy | Vegetarian |
|---|---|---|---|---|---|---|
| Sting, 250 ml can | 100 → 10.0 | **60 → 2.1** | 100 → 10.0 | 100 → 10.0 | 100 → 10.0 | 100 → 10.0 |
| Amul Lassi, 200 ml | 100 → 10.0 | 45 → 1.0 | 100 → 10.0 | 100 → 10.0 | 100 → 10.0 | 100 → 10.0 |
| Maggi masala, 70 g | 100 → 10.0 | 70 → 3.0 | 60 → 2.8 | 55 → 2.8 | 100 → 10.0 | 100 → 10.0 |
| Lay's Classic, 100 g | 100 → 10.0 | 100 → 10.0 | 75 → 4.3 | 65 → 0.9 | 100 → 10.0 | 100 → 10.0 |
| Parle-G, 100 g | 100 → 10.0 | 45 → 1.2 | 85 → 6.6 | 80 → 5.0 | 100 → 10.0 | 100 → 10.0 |
| Rolled oats, 40 g | 100 → 10.0 | 100 → 10.0 | 100 → 10.0 | 100 → 10.0 | 100 → 10.0 | 100 → 10.0 |
| Peanut chikki, 25 g | 100 → 10.0 | 75 → 3.4 | 100 → 10.0 | 100 → 10.0 | 15 → 0.0 | 100 → 10.0 |
| Chicken noodle cup | 100 → 10.0 | 100 → 10.0 | 75 → 3.6 | 80 → 7.0 | 100 → 10.0 | **60 → 0.0** |

**Known gap:** the "No conditions" column. With no conditions, allergies or diet, every product scores 10.0, because the score only measures fit to the profile. Closing it needs a general nutrition-quality layer. The candidate is Nutri-Score (2023 algorithm), implemented from its published tables, not invented. That's a separate decision.

## The AI is as repeatable as it can be

- **All three Gemini calls use the same settings:** label reading, prescription reading and the explanation run at temperature 0 (greedy decoding) with a fixed seed (`GENERATION_SEED = 7`).
- **Hosted models still aren't bit-for-bit repeatable.** The provider's batching and hardware can change a word.
- **That doesn't touch the score.** The score never depends on the AI, so only the wording of an explanation can vary, and every explanation is checked against the findings before you see it.
- **The bigger source of variation is the fallback chain.** If the main model fails, a different model answers. The scan log records `model` and `model_attempts`, so that is visible.

## Tests that keep it honest

`apps/api/tests/test_score_formula.py` checks:

- **No cliffs:** the score barely changes across every threshold.
- **Each curve starts exactly where its rule fires.**
- **More is never better:** more sugar or sodium never raises the score.
- **Hard stops are exactly 0.**
- **Checks that don't apply change nothing.**
- **Problems multiply, and each finding's cost is computed correctly.**

A mutation check confirmed the cliff test fails if the curves are turned back into steps.
