# Builder notes: what a pro does, and why

These are habits worth keeping, each tied to something that actually happened while building CalFit. Read one before you start a similar task.

## 1. Know where data goes before you choose a vendor

Before buying an AI plan, list what you send:

- the photo;
- health conditions;
- allergies.

Then check four things per vendor: training, retention, region, and contract (DPA). That is how Vertex AI in Mumbai beat the plain Gemini paid tier. The paid tier keeps prompts for 55 days, Vertex can keep nothing, and the price is the same. See `AI_PROVIDER_OPTIONS.md`.

## 2. Logs are a database too

Logs are kept for weeks and read by more people than your tables, so they get the strictest rule:

- **Log:** ids, timings, outcomes.
- **Never log:** content. That includes error *text*: the prescription code knew provider errors can echo the prompt, but the photo and explanation code still logged them.

Write a test that fails when private words appear in a log line (`test_observability.py`). The test enforces the rule even after everyone has forgotten it.

Libraries log too. After this rule was written, a review of the real backend output found `httpx` printing every Supabase URL, with `user_id=eq.<your id>` in it, 53 times in one session. The fix was one line: set those loggers to warnings only. Finding it needed someone to read the actual log output, not just the code.

## 3. Evals before opinions

"Is the app accurate?" needs a number, and that number needs a definition, a target and a fail condition. CalFit has four:

- **Rule tests:** exact answers.
- **Labelled-photo eval:** allergen recall at least 0.98.
- **Grounding guard:** checks every explanation.
- **User feedback:** at least 85% "right", and any missed allergen raises an alert.

Without targets, every result looks "fine".

## 4. Look at real data, not just tests

All tests passed, yet the first look at real data showed "Sting: Best, 75" for a Type 1 diabetic. The cause is that 16 of 31 old scans have nutrition numbers with no serving size, so 6.8 g per 100 ml was judged as if it were a whole can.

Tests prove the code does what you meant. Real data shows whether what you meant was right. After every feature, open the app on real data and ask: "Would a user believe this?"

## 5. Missing stays missing

Nutrient levels show nothing when the serving size is unknown, rather than guessing. The feedback report says "not enough answers" instead of showing a 0% or 100% rate. A blank with a reason builds more trust than a confident wrong number.

## 6. Keep diffs honest

A script that rewrote the language files also reformatted 300 untouched lines, which hid the 21 real changes. It was rebuilt to add only new lines.

Reviewers, including future you, read diffs. Noise hides mistakes.

## 7. Every new kind of stored data means a privacy-policy update

Feedback answers are new data, so section 2.3 and section 5 of the privacy policy were updated in the same change, along with the bundled copy in the app. Under the DPDP Act the policy has to match what the code actually does.

## 8. Database changes go through migrations

`008_scan_feedback.sql` is a file in the repo and was applied with the migration tool, not typed into a dashboard. The repo then rebuilds the database exactly.

Each migration only adds things: a new table with row-level security on. Nothing existing changes, so it is safe to apply live.

## 9. Smoke-test live with a throwaway account

Unit tests use fakes. The live smoke test, with 24 checks, uses the real Supabase and storage. It is what proved signed photo links actually download.

It creates its own account, deletes it at the end, and confirms your real account is untouched. Never test on real users' data.

## 10. Hardware gotchas worth remembering

- **When the USB connection blips, Android forgets `adb reverse`.** The app then says "Can't reach server" even though the server is fine. Re-run `adb reverse tcp:8000 tcp:8000`.
- **MIUI blocks automated taps** unless *USB debugging (Security settings)* is on in Developer options. It needs a Mi account sign-in.
- **PowerShell `>` corrupts binary files**, such as screenshots. Save on the phone and `adb pull` instead.

## 11. A confidence number only means what you asked for

Front-of-pack scans failed because the AI was asked "how sure are you of the **ingredients and nutrition**?" A front photo has neither, so it honestly said "not sure", and the app refused to go on. The name had been read fine.

When one number gates a decision, write down what it measures. Add a second number for a second question; here that was `identity_confidence` for the name.

## 12. Let the AI read; let code decide and real data answer

The AI never suggests which product it might be. It reads what is printed, and the options come from our database and Open Food Facts. Asked for "its top 3 guesses", a model will happily invent product names. Asked to read a pack, it can only be wrong about what's in front of it.

## 13. Test that your test can fail

The "lassi never gets ice cream as an alternative" test first passed for the wrong reason: the test data gave the ice cream sugar, so a different rule excluded it. The check that caught it: switch the feature off and confirm the test fails.

A test that passes either way gives you confidence you haven't earned.

