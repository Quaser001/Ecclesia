# Switch Gemini to paid billing + hard spend cap

The Gemini **free tier trains on prompts** by default, which is unacceptable for a health app that handles allergies and medical conditions. Before CalFit talks to real users, Gemini must be on a **paid plan** and we must have a **spending cap** that cannot overflow.

> Prescription reading (`PRESCRIPTION_AI_ENABLED`) sends medical documents to Gemini. Do not turn it on until this page is done.

## 1. Enable the paid tier

Follow Google's docs: https://ai.google.dev/pricing

1. Open **Google AI Studio** → the project's API key.
2. Link it to a **Google Cloud project** that has billing enabled.
3. On the Gemini API usage page, confirm the project is on the **paid tier** (not "Free").
4. Under the Gemini API terms, the paid tier excludes prompt content from model training. Keep a dated screenshot of this setting for your records.

## 2. Set a monthly budget alert

Budget alerts don't block spend — they email you. Still essential as a safety net.

- Google Cloud Console → **Billing → Budgets & alerts → Create budget**
- Scope: the Gemini project only.
- Amount: start at **₹500 / month** (adjust as you grow).
- Alert thresholds: 50% / 90% / 100% actual, 100% forecasted.

## 3. Set a hard quota cap

Budgets warn — quotas enforce. This is the one that actually stops bleeding.

- Google Cloud Console → **IAM & Admin → Quotas & System Limits**.
- Filter for the service: **Generative Language API** (that is the backing service for `generativelanguage.googleapis.com`, which `google-genai` calls).
- The two to cap:
  - **Requests per minute** per project → set to a value you can live with (e.g. **60**).
  - **Requests per day** per project → cap at **5,000** while we're in MVP.
- "Edit quotas" → fill in the new value → submit. Google reviews daily caps > their default; apply early.

With `DAILY_SCAN_CAP=50` per user, 100 users at the limit would hit 5,000 scans/day. Lift the project-level cap only when you're ready to raise `DAILY_SCAN_CAP` too.

## 4. Rotate the key under the new project

Rotating the key is part of this move, because the old key is tied to the old project. Steps:

1. Google AI Studio → **Get API key** → create a new key under the paid Cloud project.
2. Replace `GEMINI_API_KEY` in Secret Manager (`gcloud secrets versions add GEMINI_API_KEY --data-file=-`).
3. Redeploy Cloud Run — picks up the latest secret version on the next revision.
4. Verify a scan from the device works.
5. **Only then** delete the old key in AI Studio.

## 5. Verify no free-tier fallback can happen

- Confirm `GEMINI_API_KEY` in production is the paid-tier key.
- Confirm `GEMINI_API_KEYS` (plural, for load-balancing — see `settings.py`) is **unset** or holds only paid-tier keys. A single free-tier key in that list would silently route some traffic through free-tier terms.

## 6. One-time billing dashboard

Pin a dashboard that shows:

- Daily spend on Generative Language API.
- Requests per day.
- Error rate.

If Daily spend × 30 ever reaches 70% of the budget, come back to this page and either raise the budget deliberately or cap stricter. Don't lift the daily quota until you've looked at who is actually scanning.
