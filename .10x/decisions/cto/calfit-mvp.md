# CTO: calfit-mvp

Confirmed by the founder on 2026-10-28.

- **Goal (founder):** live on the Play Store, then payments, looking professional and friendly.
- **Where it stands:** feature-rich MVP, running locally against live Supabase, not deployed.
  - Tracked in `docs/MARKET_READY_CHECKLIST.md`, with phases 0–5 and a log.
  - Launch steps are in `docs/LAUNCH_CHECKLIST.md`.
- **Main strategic risks:**
  1. **AI data terms:** the free Gemini tier trains on prompts. Must move to Vertex before real users; `docs/AI_PROVIDER_OPTIONS.md`.
  2. **Score credibility:** curve heights are CalFit judgment and need a dietitian review. Users with no conditions get 10.0 for everything (Nutri-Score layer undecided).
  3. **Open Food Facts limits:** about 10 searches/min per server IP. Importing more products is the fix at scale.
