# CalFit — Market-Ready Checklist

The single working list for taking CalFit from "runs on my phone over a cable"
to "live on the Play Store, taking payments, looking professional".

Rules for working this list:
- Do not remove existing features. Add what is missing.
- Work top to bottom. Do not start a later phase while an earlier **BLOCKER** is open.
- Anything that needs a decision from the owner is marked **DECIDE** and is asked before building.
- Infrastructure detail (secrets, Cloud Run commands) lives in `docs/LAUNCH_CHECKLIST.md` and `docs/DEPLOY_CLOUD_RUN.md`; this list only tracks it.

Legend: `[x]` done · `[~]` in progress · `[ ]` left · **BLOCKER** · **DECIDE** · **YOU** = owner action (accounts, payments, devices)

Last updated: 2026-10-28

---

## Phase 0 — Audit (2026-10-28)

How it was checked: source review of every screen. Live device QA was blocked:
the POCO M4 Pro was locked and MIUI refuses adb input without
"USB debugging (Security settings)", and the Pixel 8 emulator cannot start
because this PC reports no CPU virtualisation support.

Findings:
1. **Bottom bar is lopsided.** One tab (Home) sits left of the Scan button and two (History, Profile) sit right of it, so nothing lines up.
2. **Design reads as AI-generated:** neon green on near-black, glowing gradient shadows, a gradient "C" tile as the logo, sparkle ripple effect, a gradient glowing scan button.
3. **Tapping a scan goes nowhere useful.** History rows show "Scan detail is coming in the next release"; Home's recent scans just switch to the History tab. There is no `GET /scans/{id}` endpoint.
4. **No first-run onboarding.** A new user lands on an empty dashboard and can scan before telling the app their conditions, so the first result ignores them.
5. **No Settings screen.** The theme toggle sits in the Home header; there is no privacy policy, terms, about/version, contact, or "delete my data".
6. **History stops at 20 scans** and has no search or filter.
7. **Scan photos never display.** The bucket is private and the app gets unsigned URLs.
8. **Legacy launcher icons are the Flutter default**; only Android 8+ shows the adaptive icon.
9. **Accounts are anonymous device tokens.** Reinstalling or changing phones loses everything. Payments cannot be tied to a person.
10. **No payments of any kind.**
11. Small text (10 px nav labels), no accessibility labels checked, no localisation (English only).

---

## Decisions (2026-10-28)

| Topic | Decision |
|---|---|
| Bottom bar | Scan stays in the centre with two tabs each side: Home, History · **Scan** · Insights, Profile. Insights is a new tab. |
| Look and feel | Warm and friendly, light-first: off-white background, deep green brand colour, coral/amber accents, flat rounded cards, no glows or gradients. Dark mode kept as an option. |
| Payments | **Launch free** with a daily scan cap; payments in a later version. Phase 3 is deferred, not dropped. |
| Sign-in | Google sign-in via Supabase Auth; existing anonymous data is linked on first sign-in. |
| Languages | English, Hindi, Assamese, Bengali, Khasi. Machine-drafted; **native-speaker review required before launch**. Flutter has no built-in Khasi strings for system widgets, so those fall back to English. |
| Body details | Height, weight, BMI (calculated), age (birth year), sex, activity level, target weight. BMI bands use the Asian-Indian cut-offs (overweight from 23, obese from 25). No calorie estimate for now. |
| Food database | India-first, photo-matched (by name and brand, not barcode). Source: Open Food Facts (ODbL, credited in the app). FSSAI publishes labelling rules, not a product database, so it informs scoring rules, not products. Categories: biscuits, chips, namkeen/bhujiya, instant noodles, edible oils, chocolates, cold drinks, breakfast cereals, fruit juices, flavoured milk and ice cream, ketchup and sauces, energy drinks. |

## Phase 1 — App quality and design

- [x] **DECIDE** Bottom bar layout
- [x] **DECIDE** Visual direction
- [x] Bottom bar: Home, History · Scan · Insights, Profile — five equal slots, symmetric (widget test checks widths and mirror symmetry)
- [x] Insights tab: average score, suitability mix, 8-week trend, most-flagged issues, best picks, products worth a second look
  - [x] Backend `GET /api/v1/insights` (owner-only, deterministic, 6 service + 2 endpoint tests)
  - [x] App screen with loading, empty (offers to scan) and error (retry) states; 4 tests
- [x] Replace the AI-looking styling: glows, gradients, glass card and sparkle ripple removed; real logo mark from the launcher vector; warm light-first palette (WCAG AA checked in both themes) as a `ThemeExtension`; components styled once in the theme
- [x] Scan detail screen: tap any scan (Home, History or Insights) to see the full result
  - [x] Backend `GET /api/v1/scans/{scan_id}` (owner-only, 404 for others' scans), with tests
  - [x] App screen reusing the result layout (past-scan mode hides alternatives, which are not stored)
- [x] Home: first-scan card with a Scan button, "Personalise your scores" prompt when the profile is empty, profile chips with Edit
- [x] Scan screen: clearer instructions and photo tips (back of pack, light, fill the frame)
- [x] Shared `ScoreBadge`, `ScanRow`, `StatusView` so every list and empty/error state looks the same
- [x] Settings screen behind a gear icon (top right of Profile): theme (phone/light/dark), text size (4 steps, multiplies the phone's own size), language, privacy policy, delete my data, about and data sources
- [x] Delete my data: `DELETE /api/v1/profile` removes photos, scans, usage and profile (owner-only, tested); confirm dialog in red; sign-in token dropped afterwards
- [x] Languages: English, Hindi, Assamese, Bengali, Khasi — every app string through `gen-l10n` (5 ARB files, identical keys); Khasi falls back to English for Flutter's own widget strings; test renders the app shell in all five
  - [ ] **BLOCKER for launch** Native-speaker review of hi, as, bn, kha (machine-drafted; Khasi most uncertain)
  - [ ] Scan findings, explanations and goal "checks" text come from the server in English; translate server-side later
- [x] Body details on Profile: height, weight, BMI (Asian-Indian bands), age (birth year), sex, activity level, target weight; edit sheet with validation
  - [x] Backend fields, validation and BMI calculation with tests
  - [ ] **YOU / BLOCKER before restarting the backend** Apply Supabase migration 007 (`apps/api/migrations/007_profile_body_details.sql`); until then profile saves fail on the live project
- [x] Insights linked to goals: per goal, how many scans fit (judged by the same scoring rules, or a stated protein threshold for muscle gain), the most common issue, and kg to target weight; goals without a rule say "not tracked yet"
- [x] India food database: 764 Open Food Facts India products with complete nutrition across the 12 categories, each with a CalFit category, flavour tags, ingredients (from tags) and provenance; implausible records skipped (`scripts/import_india_foods.py`)
  - [x] Fixed: the old import stored sodium in grams as milligrams (1000× too low) and used per-serving fallbacks
  - [x] Removed made-up "seed" products (invalid barcodes labelled as Open Food Facts)
- [x] Alternatives: same CalFit category, similar flavour first, at least 15% less of each flagged nutrient per 100 g, none of the flagged ingredient issues, no allergen/diet hard stops, better score for this user; product photo shown; knowledge-base tips no longer badged as verified products
- [x] Privacy policy corrected to match the app (profile stored on server, Gemini sees profile for explanations, Singapore storage, in-app deletion); bundled in the app
  - [ ] **BLOCKER for launch** Legal review; fill in publisher and grievance contact
  - [ ] Automatic retention limit for scans and photos (the old policy promised 90 days; nothing implemented it)
- [ ] Scoring follow-up: the heart-health goal triggers only the fat/cholesterol rules, not sodium
- [ ] Onboarding: 3 short screens (what it does, set up profile, not medical advice) before the first scan
- [ ] Settings screen: theme, privacy policy, terms, about/version, contact, delete my data
- [ ] History: load more (paging), search by product name
- [ ] Show scan photos via short-lived signed URLs (backend) in History and detail
- [ ] Launcher icon for every density, plus a proper splash screen
- [ ] Accessibility pass: text ≥ 12 sp, semantic labels on icon buttons, contrast in both themes
- [ ] Friendly empty, loading and error states on every screen (check each)
- [x] `flutter analyze` clean and `flutter test` passing (24 tests, 2026-10-28)
- [ ] Real-device QA on the POCO M4 Pro, every screen in light and dark, screenshots saved

## Phase 2 — Accounts (needed before payments)

- [x] **DECIDE** Sign-in method — Google sign-in
- [ ] **YOU** Google Cloud OAuth client (Android, with the app's SHA-1) and the Google provider turned on in Supabase Auth
- [ ] Supabase Auth on the backend: verify Supabase JWTs alongside device tokens
- [ ] Sign-in screen in the app; link the existing anonymous data to the new account on first sign-in
- [ ] Sign out, and delete account and all data (Play Store requires an in-app path and a web link)
- [ ] Tests for linking, ownership and deletion

## Phase 3 — Payments (deferred: launch free first)

- [ ] **DECIDE** What is free and what is paid, and the prices (asked 2026-10-28: launch free, decide later)
- [ ] **DECIDE** Payment rails (Google Play Billing is required for digital subscriptions sold in Play-installed apps; India also allows an alternative alongside it)
- [ ] **YOU** Google Play Console account, payments profile, merchant details
- [ ] Products created in Play Console (subscription base plans)
- [ ] App paywall screen and purchase flow (`in_app_purchase`)
- [ ] Backend verifies purchases with the Google Play Developer API and stores entitlements per account
- [ ] Real-time developer notifications (Pub/Sub) for renewals, cancellations, refunds
- [ ] Server enforces limits by entitlement (e.g. daily scan cap, prescription reading)
- [ ] Restore purchases; test with licence testers

## Phase 4 — Go live (backend in the cloud)

Detail: `docs/LAUNCH_CHECKLIST.md` sections 1–2, `docs/DEPLOY_CLOUD_RUN.md`.

- [ ] **YOU** **BLOCKER** Rotate exposed keys (Gemini, Groq, Cerebras, old `calfit` Supabase secret)
- [ ] **YOU** **BLOCKER** Google Cloud billing account, gcloud CLI installed
- [ ] **DECIDE** Data region: stay on the Singapore Supabase project and fix the privacy policy, or move to Mumbai
- [ ] Gemini on the paid tier with budget alert and quota caps
- [ ] Deploy to Cloud Run (four secrets), smoke test health and auth
- [ ] Release build pointing at the deployed URL; end-to-end test on mobile data with the laptop off

## Phase 5 — Play Store

- [ ] **YOU** Google Play developer account ($25 one-time); identity verification
- [ ] **YOU** Release keystore created and backed up
- [ ] Privacy policy hosted at a public URL; matches what the app actually does
- [ ] Data Safety form (health data, photos, purchase history)
- [ ] Health apps declaration and content rating questionnaire
- [ ] Store listing: name, short and full description, feature graphic, 4–8 phone screenshots, icon 512 px
- [ ] App Bundle (`.aab`) signed, version code bumped
- [ ] Internal testing track → closed testing (new personal accounts need 12+ testers for 14 days before production) → production
- [ ] Pre-launch report reviewed, crashes fixed

---

## Log

- 2026-10-28 — Audit done (Phase 0). Checklist created.
- 2026-10-28 — Decisions taken: centre Scan with Insights tab, warm light-first look, launch free, Google sign-in.
- 2026-10-28 — Pass 2: Settings, five languages, body details + BMI, goal-linked Insights, delete my data, India food database (764 products), new alternatives engine, privacy policy corrected. Backend 310 tests, app 33 tests, analyze clean. Waiting on Supabase migration 007 before the backend restart and phone check.
- 2026-10-28 — Redesign pass 1 done: new palette and theme, even bottom bar, Insights tab, scan detail, Home/History/Scan/Profile restyled. Backend 232 tests, Flutter 24 tests, analyze clean. Not yet checked on the phone.

## Phase 1 progress (28 Oct 2026, not committed)

- [x] History paging (`before` cursor) and real totals on Home (`GET /scans/stats`)
- [x] Scan photos via 1-hour signed links; tap to view the photo on past scans
- [x] Onboarding for new installs (language, allergies/conditions/diet, safety note)
- [x] Smoother app: tabs stay alive, fade-forward page transitions, double-size text fits on a 360 dp phone (tests)
- [x] Launcher icons for every density + round icons + 512 px Play Store icon (`apps/mobile/store/`)
- [x] AI plan comparison: `docs/AI_PROVIDER_OPTIONS.md`; Vertex AI Mumbai mode (`GEMINI_BACKEND=vertex`) built and tested
- [x] Backend: traffic-light nutrient levels per 100 g/ml on every scan response (UK FSA thresholds, as Open Food Facts uses)
- [x] "Was this right?" feedback: `POST /scans/{id}/feedback`, no free text; migration 008 applied to Supabase (28 Oct)
- [x] App: "At a glance" nutrient tiles (word + icon + colour) and the feedback card on every scan result, in all 5 languages
- [x] Observability: request id on every response and log line; one JSON line per request and per scan (stage timings, model, fallbacks, grounding outcome); no photos, label text, profile or error text in logs (enforced by tests)
- [x] Evals: `scripts/eval_report.py` (weekly accuracy from feedback, fails below 85% or on any missed allergen); `docs/EVALS_AND_OBSERVABILITY.md` with alert thresholds
- [x] Privacy policy updated for feedback answers and the new logging rule (both copies)
- [x] Live smoke test 24/24 with a throwaway account (paging, Home totals, signed photo download, nutrient levels, feedback, delete-my-data); phone account untouched
- [x] Phone: new build installed; Home shows the right totals (31 scans) and signed-link photo thumbnails
- [ ] Phone: open a scan with a known serving size (latest "Unnamed product" or "Good Day Butter Cookies"), scroll down, check "At a glance" and "Was this result right?"

**Front-of-pack scanning and serving sizes (28 Oct, from your Amul Lassi test):**
- [x] AI reads brand, name, variant, pack size, price and a separate "how sure of the name" confidence; never nutrition from memory
- [x] Code decides: one real match -> result ("Identified as ... · Open Food Facts"); fairly sure -> "Is this the product?"; several -> pick from up to 3; unreadable -> retake; known but no data -> photograph the back; lookup down -> says so (not "not found")
- [x] Options only ever real products (CalFit database, else Open Food Facts searched once), brand must match, pack size narrows; confirm re-fetches by code server-side
- [x] Lassi/buttermilk added to the taxonomy; drinks only get drink alternatives
- [x] "Serving size unknown, check the pack" note + optional input (size + per 100 / per serving); remembered per product (migration 009, applied); old scores unchanged
- [x] "Not this product?" removes the scan (`DELETE /scans/{id}`, photo too)
- [x] Tests: backend 404, app 59; live: 15/15 front-of-pack + 24/24 main smoke
- [ ] Try it on the phone: front of the Amul Lassi pack, then a pack without size in view
- [ ] Scale note: Open Food Facts search allows ~10 requests/min per server IP; import more products into food.db before launch

**Found while checking real data (decide next):**
- [x] 16 of 31 older scans have nutrition numbers with no serving size (Sting: 6.8 g/100 ml scored "good", 75). Decided: keep scores, show "Serving size unknown, check the pack" with an optional serving-size answer remembered per product
- [ ] 7 imported scans are old test runs, not real scans: 6 identical "Amul Lassi 200ml" (6 Oct) + 1 "Masala Munch", each with an 85-332 byte stub photo (the phone's "Failed to decode image" errors). They inflate Home's count and average. Delete with your OK
- [x] Logs: httpx printed Supabase URLs with user ids and uvicorn printed raw paths; both silenced (test added, `--no-access-log` in Dockerfile)
- [ ] Tech debt: `product_json`/`score_json` are stored as JSON text inside `jsonb`, so SQL can't query inside them. Store real JSON objects (provider change + one data migration)

**Your to-dos (only you can do these):**
- [ ] Label 50-100 real pack photos for the extraction eval (`docs/EVALS_AND_OBSERVABILITY.md`, "extraction eval")
- [ ] Ask a Khasi speaker to review the Khasi strings (machine-quality today)
- [ ] When deploying: `LOG_FORMAT=json`, then the four log-based metrics and alerts from the evals doc
- [ ] Buy the plan: Vertex AI in `asia-south1`, then follow `docs/AI_PROVIDER_OPTIONS.md` steps 1-7
- Later (from competitor review: Yuka, TruthIn, FoodSwitch): product search in the food database, additive (INS) explanations from a sourced list, share a result, data export
