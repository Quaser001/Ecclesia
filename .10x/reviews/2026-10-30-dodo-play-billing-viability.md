# Dodo Payments × Google Play billing — viability check

**Date:** 2026-10-30
**Question (handoff item 3):** Can CalFit charge for Plus/Pro subscriptions through **Dodo Payments** inside the Play-distributed Android app?
**Short answer:** **Not on its own.** In India, Google requires **User Choice Billing (UCB)** — Dodo can only run *alongside* Google Play Billing, not instead of it, and every Dodo charge must be reported to Google within 24 h. There is no "Dodo-only" option for India.

## What Google's policy actually says (primary sources)
- **India = User Choice Billing only.** Alternative billing is offered *alongside* Google Play's billing; the user picks at checkout. India is **not** on the "alternative billing only" track (that exists for the EEA / South Korea, not India).
  - Play Console Help, "Changes to Google Play's billing requirements … India": the app must be "offering alternative billing to mobile and tablet users in India," i.e. a *second* system next to Google's.
- **You must integrate Google Play Billing too.** UCB requires the Play Billing Library in the app plus a Google-controlled choice screen. You cannot ship only a Dodo checkout.
- **24-hour reporting is mandatory.** Authorized Dodo transactions must be reported to Google via the **ExternalTransactions API within 24 hours**. Manual monthly self-reporting is being discontinued; recurring subs must be migrated to the API.
- **Enrollment gate:** accept the alt-billing ToS, set up a payment profile, **certify PCI DSS compliance**, and provide a user fraud-reporting channel.
- **Fee:** Google's service fee only drops **4%** when the user pays via Dodo. Google still takes the rest (subscriptions are ~15%, so ~11% after the discount) — *on top of* Dodo's own cut (~4% + fee domestic, higher international).

## What Dodo says
- Dodo's own "bypassing app store fees" page lists **India as a UCB market with a 4% fee reduction** and recommends an **in-app SDK + hosted checkout that follows Google's UX rules**. It does **not** claim you can skip Google Play Billing in India, and it does **not** document the ExternalTransactions reporting — that reporting would be **our** backend's job from Dodo's webhooks, not something Dodo does for us.
- Dodo is a **Merchant of Record**: it handles GST/VAT, invoicing, refunds, disputes. That is its real value here, not fee savings.

## The economics are roughly a wash (confirm before committing)
For a ₹199/mo sub in India via UCB you'd pay **Google (~11% after the −4%) + Dodo (~4%+)** ≈ as much as, or more than, **Google Play Billing alone (~15%)**. So on fees, Dodo-inside-the-Play-app saves little. Dodo wins only if its MoR tax/invoicing handling or payment-method reach (UPI, global cards) is worth that overhead. *(Fee percentages are directional — verify against Google's current India fee table and Dodo's live rate card.)*

## Two other blockers (unchanged)
1. **Durable identity first.** Production billing still waits on **Google sign-in (item 8)**. A paid entitlement can't hang off an anonymous Keystore token — it'd be lost with the phone and can't cover family profiles (ADR-008).
2. **Privacy policy still blocks the Play listing** (handoff item 2), independent of payments.

## Options for the founder
- **A — Web checkout, honor entitlement in app (reader-app style).** Sell the subscription on a **website** via Dodo (clean, no Play fee, full MoR). The app just *unlocks* what the user already bought. Caveat: Google's anti-steering rules forbid *promoting/linking* the external purchase from inside the app; the UX is weaker (user subscribes in a browser). Lawyer's call for a non-"reader" app. **Most of the Dodo value, least Play entanglement.**
- **B — Full UCB inside the app.** Integrate **both** Play Billing and Dodo + the choice screen + 24 h ExternalTransactions reporting + PCI/enrollment. Biggest build, ongoing compliance, little fee saving. Only worth it if in-app purchase conversion matters a lot.
- **C — Just use Google Play Billing** for in-app subs, skip Dodo in the app. Simplest, fully compliant, no second integration. Loses Dodo's MoR tax handling (you'd handle GST yourself or via Google).
- **D — Test-mode groundwork now.** Build the provider-agnostic backend (`PaymentProvider` → `DodoPaymentProvider`, `/billing/checkout`, signed idempotent `/billing/webhook`, entitlements table) in **test mode**, decoupled from the Play decision, so progress continues while A/B/C and Google sign-in are settled.

## Recommendation
**D now, aiming at A.** Build the test-mode backend groundwork (it's useful under any of A/B/C), and plan for **web checkout + in-app entitlement (A)** as the launch path — it captures Dodo's real value (MoR, global payments) with the least Play-policy risk. Revisit full UCB (B) only if in-app purchase conversion proves it's needed. Decision is the founder's.

## Do NOT do yet
- Don't install the Dodo Claude Code plugin or create the test API key until the path is chosen (the founder does both themselves; the key never goes in chat or the repo).
- Don't write billing code or create Dodo products until the founder picks A/B/C/D and confirms the annual prices (currently 10× monthly placeholders).

**Sources:** Google Play Console Help (India billing requirements; user choice billing; enrolling in UCB), Android developer docs (alternative billing with user choice; outside-GPB backend / ExternalTransactions), Dodo Payments docs (bypassing app store fees; merchant of record; pricing; checkout session; webhooks).

---

## Decision & build (2026-10-30)
Founder chose **D→A**. The provider-agnostic, test-mode backend groundwork is built (details in `status.md`): `PaymentProvider`/`DodoPaymentProvider`, `/billing/checkout|webhook|status`, entitlements + idempotency ledger, tier-aware scan cap behind `BILLING_ENABLED`, migration 013 (not applied). Backend 614 tests pass.

### Guardrail — do NOT ship an in-app link-out to web checkout
Path A's weak spot: a button inside the Play app that opens the Dodo web checkout is exactly the external-purchase steering Google forbids **outside** UCB. So:
- Keep any app-side checkout entry **debug-only** (the Settings subscription tile already is). Don't expose a "Subscribe" button in a release build until the compliant path is decided.
- Path A also can't identify the buyer without **Google sign-in (item 8)** — the token lives in the Keystore, so a browser checkout has no durable identity to attach the entitlement to.
- If we ever want paid subs *inside* the Play app, that's **Path B** (Play Billing + Dodo + UCB enrollment + 24 h ExternalTransactions reporting), a separate decision.

### First test-purchase checklist (verify against a real Dodo test event)
The code was built from Dodo's docs, which don't pin every field. On the first **test** purchase, confirm against the actual webhook payload:
- `data.metadata.user_id` is echoed back (the whole user→entitlement link depends on it). If not, pass it via `subscription_data.metadata` or add a checkout-session→user_id mapping.
- `data.product_id` is where we read it (maps back to the tier).
- the status string is literally `"active"` (the only value we treat as entitled).
- `data.next_billing_date` is the period-end field (and parses as ISO 8601).
- the secret format: if **every** test webhook 401s, suspect the `whsec_`/raw-key branch in `dodo_provider._signing_key` first.
- Dodo accepts `subscription_data.metadata` at checkout; if checkout itself fails, retry without it.

### Migration 013 — dry-run first
It has never been executed. Run it once inside `BEGIN; … ROLLBACK;` to confirm it applies cleanly, then run it for real (with the founder's approval) and record it in `status.md`.

### Erasure caveat
`delete_my_data` drops the entitlement rows, but the device token still works, so a **renewal webhook after a delete would recreate the row**. And it does not cancel the subscription at Dodo, so charges continue. Both are founder decisions (cancel at Dodo on erasure? ignore webhooks for deleted users?) — noted in `status.md`.
