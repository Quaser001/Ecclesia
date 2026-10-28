# Which AI plan to buy for health data and photos

CalFit sends two kinds of data to an AI model:

- The label photo, so the model can transcribe the label.
- The label details, score, findings and the profile's conditions, allergies, diet and goals, so the model can write the explanation.

The name and body details are never sent. Prescription photos are also sent, but only when `PRESCRIPTION_AI_ENABLED` is on.

Whichever AI plan you buy should meet five conditions:

1. **No training.** The provider must not train on the data.
2. **Short or zero retention.** Little or nothing is kept after the reply.
3. **A data processing agreement.** You need one to be a proper DPDP data fiduciary.
4. **Processing in India, if possible.** Users trust it more, and it shortens section 6 of the privacy policy.
5. **No API key to leak.** This one is optional but valuable.

Checked on 28 Oct 2026. Re-check the linked pages before signing up, because these terms change.

## Recommendation: Gemini on Vertex AI, Mumbai (`asia-south1`)

Use the same Google Cloud project and billing account that Cloud Run uses. You buy nothing separately. Vertex AI usage is billed per token on that Cloud Billing account.

| | Gemini API, free | Gemini API, paid (AI Studio) | **Gemini on Vertex AI, asia-south1** | Claude on Amazon Bedrock, India profile |
|---|---|---|---|---|
| Trains on your data | **Yes**. Google: "Do not submit sensitive, confidential, or personal information" | No | No ([data governance][vgov]) | No |
| Retention after the reply | Used for product improvement; human review possible | **55 days** for abuse monitoring ([usage policies][gpol]), no zero-retention option | Up to 24 h in-memory cache, which you can switch off. Abuse logging only under the standard Cloud terms, and you can request an exception ([data governance][vgov]) | Not stored by Bedrock, per AWS |
| Where it is processed | Anywhere | Anywhere | **Mumbai**, with a regional endpoint for models listed for asia-south1 ([data residency][vres]) | India geographic inference profile (Mumbai and Hyderabad) ([AWS blog][bedrock]) |
| Contract | Gemini API terms | Gemini API terms | Google Cloud terms and Cloud Data Processing Addendum | AWS customer agreement and DPA |
| Authentication | API key | API key | **Service account, no key** | IAM role |
| Code change in CalFit | none | none | **Done**: `GEMINI_BACKEND=vertex` | A new provider class and new prompts; scan output needs re-evaluation |
| Verdict | Never for real users | Acceptable minimum | **Use this** | Good second provider, later |

Why Vertex wins for CalFit:

- **Strictest data terms.** No training, a regional endpoint in India, and zero retention is achievable (the steps are below).
- **No new vendor.** It is the same Google Cloud account as Cloud Run and the same `google-genai` SDK. The backend already supports it with a configuration switch.
- **No API key at all.** Cloud Run's service account authenticates, so there is no key to rotate or leak.
- **Prescriptions become possible.** It is the plan under which turning on prescription reading is defensible.

Google's Gemini API terms also say not to use the service "in clinical practice, to provide medical advice". CalFit gives food-label guidance with a not-medical-advice notice and does not diagnose. Keep it that way.

## Switch to Vertex AI (about 15 minutes)

**1. Enable Vertex AI and let the API's service account call it.** Use the account from `DEPLOY_CLOUD_RUN.md` §2:

```bash
gcloud services enable aiplatform.googleapis.com
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:calfit-api@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/aiplatform.user
```

**2. Pick a model that runs in Mumbai.** Open the [data residency table][vres] and check the `asia-south1` column. `GEMINI_MODEL` must be one of the models ticked there; `gemini-2.5-flash` is today's default. If a fallback model in `gemini_provider.py` is not offered in Mumbai, its call simply fails and the next model is tried.

**3. Set the environment on Cloud Run:**

```
GEMINI_BACKEND=vertex
GOOGLE_CLOUD_PROJECT=<your project id>
GOOGLE_CLOUD_LOCATION=asia-south1
```

The API refuses to start a scan if `GOOGLE_CLOUD_LOCATION` is `global`, because a global endpoint may process data anywhere. After a scan works, remove the `GEMINI_API_KEY` secret from the service.

**4. For zero data retention:**

- **Turn off the project's implicit cache.** Set the project cache config to `disableCache: true`, as described in [data governance][vgov]. This keeps nothing at rest beyond the request.
- **Ask for the abuse-monitoring exception.** Ask through Google Cloud support or your account team. Until it is granted, Google may log prompts for abuse detection under the Cloud terms; that logging is not used for training.
- **Don't add grounding with Google Search or Maps.** Neither can be opted out of storing. CalFit does not use them.

**5. Run CalFit locally against Vertex** (optional). Run `gcloud auth application-default login`, then set the same three variables in `apps/api/.env`.

**6. Set a budget and quotas as in `GEMINI_BILLING.md`.** On Vertex the quota lives under **Vertex AI API** rather than *Generative Language API*.

**7. Only then:**

- Set `PRESCRIPTION_AI_ENABLED=true`, if you want prescription reading.
- Update the privacy policy. Section 5 should say *Google Cloud Vertex AI, processed in Mumbai, not used for training*. Section 6 should drop the "outside India" line for Gemini.

## The rest of the data path

- **Phone → API:** HTTPS only. `network_security_config.xml` blocks cleartext traffic to every host except the local development addresses.
- **Stored photos:** in a private Supabase bucket. The app only ever gets one-hour signed links (`/scans/history`, `/scans/{id}`), never a public URL.
- **Supabase is in Singapore.** DPDP allows transfers outside India unless the government restricts a country. For all-India storage, a new Supabase project in Mumbai (`ap-south-1`) plus a data move would be needed. That is not required for launch; the policy already discloses Singapore.
- **Logs** carry IDs, timings and outcomes only, never photos, profile fields or label text. See `EVALS_AND_OBSERVABILITY.md`.

## Not chosen, and why

- **OpenAI or Anthropic direct APIs.** Neither has an India-region guarantee on the direct API, and either would add a second vendor contract and a provider rewrite.
- **Groq and Cerebras.** These appear in `settings.py` but no code uses them, and they are not suitable for health data. They were removed from `.env.example` so nobody wires them in by accident.

[gpol]: https://ai.google.dev/gemini-api/docs/usage-policies
[vgov]: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/data-governance
[vres]: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/learn/data-residency
[bedrock]: https://aws.amazon.com/blogs/machine-learning/amazon-bedrock-expands-claude-model-availability-to-india-cross-region-inference/
