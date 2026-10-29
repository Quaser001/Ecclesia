# DPDP Act and Rules: where CalFit stands

**Date:** 2026-10-29. **Not legal advice:** a lawyer should review this before launch.

## Sources

- **DPDP Rules, 2025:** G.S.R. 846(E), gazette text from MeitY. I quote it below.
- **DPDP Act, 2023:** commencement notification G.S.R. 843(E), 13 Nov 2025. I read it through secondary summaries (Taxmann, TeamLease RegTech), not the gazette.
- **Not verified, treat as rumour:**
  - a MeitY proposal (January 2026) to cut the 18 months to 12;
  - a "Removal of Difficulties Order" dated 5 Oct 2026 that changes wording only.
  - Both come from law-firm and vendor blogs and are not in a gazette I have read. Check before relying on them.

## When it applies

| What | From |
|---|---|
| Board, definitions, Rules 1–2 and 17–21 | 13 Nov 2025 (in force) |
| Consent managers (Rule 4, Act s.6(9)) | 13 Nov 2026 |
| **Everything that binds CalFit:** Act ss.3–17; Rules 3 and 5–16 | **13 May 2027** |

## Which class CalFit is in

- **An ordinary Data Fiduciary.** It is not a Significant Data Fiduciary, since nobody has notified it as one, so Rule 13 (audits, impact assessments) doesn't apply.
- **Not in the Third Schedule**, which covers e-commerce, gaming and social media at 50 lakh–2 crore users. So the Rule 8(1) "erase after 3 years idle, warn 48 hours before" doesn't apply.
- **Health data** has no separate class in DPDP. The Act still applies in full.

## Rule by rule

Status key:
- **met**
- **fixed 2026-10-29**
- **before launch**: must exist by 13 May 2027 or by public launch, whichever is first
- **founder**: the founder's decision, with a lawyer

| Duty | Where | Status |
|---|---|---|
| Notice: itemised data, purposes, links to withdraw, use rights, complain to the Board | Rule 3; Act s.5 | **built** (A) |
| Consent: free, specific, informed, a clear yes; withdrawal as easy as giving | Act s.6(1), (4); Rule 3(c)(i) | **before launch** for the profile (A). Prescription consent: **fixed**, now a Settings switch |
| Fiduciary must be able to prove notice and consent | Act s.6(10) | **built** (A): `consents` table |
| Stop processing and erase on withdrawal | Act s.6(6), s.8(7) | **met**: "Delete my data" erases profile, scans, photos and serving sizes at once |
| Security: encryption, access control, logs, backups, processor contracts | Rule 6(1)(a)–(g) | partly met (B) |
| Keep logs for at least a year | Rules 6(1)(e), 8(3) | **fixed** in the policy and `DEPLOY_CLOUD_RUN.md` (`--retention-days=365`). Personal data after deletion: **founder** (C) |
| Breach: tell each affected person without delay; Board full report within 72 hours | Rule 7 | **before launch** (D) |
| Publish a contact person | Rule 9 | **founder**: the policy still has a blank |
| Children: verifiable parental consent | Act s.9; Rule 10 | **fixed**: adults only; server and app refuse a birth year under 18 |
| Rights: access, correction, erasure, nomination, grievance within 90 days | Act ss.11–14; Rule 14 | correction and erasure **met** in app; nomination and Board complaint **fixed** in policy; access (E) |
| Transfer outside India | Rule 15 | **met**: Singapore (Supabase) and Google are disclosed; no country is restricted yet |

## A. Consent notice for the health profile: built 2026-10-29 (migration 010 waiting for the founder's approval)

- **App:** `lib/features/consent/consent_notice.dart`. A gate in front of onboarding and the tabs, one per family profile. The notice lists the data, purposes, who else handles it, and how to withdraw, use your rights and complain; then "I am 18 or older" and "I agree". A server 428 brings it back.
- **Server:** `src/services/consent.py`, `src/api/v1/consent.py` and the `consents` table. Saving a profile, submitting or confirming a scan, and reading a prescription answer 428 without a live consent for `CONSENT_NOTICE_VERSION`. A failed lookup is an error, never a yes.
- **"Delete my data"** withdraws consent first and keeps the row as proof.

### Original gap

- **The problem:** today consent is implied by setting a profile. Act s.6(10) puts the burden of proving consent on CalFit, and nothing on the server records that consent was given.
- **Fix before launch:**
  1. a Rule 3 notice in onboarding: what is collected, the purposes, and how to withdraw, use your rights and complain;
  2. an "I am 18 or older" line in the same notice;
  3. an explicit "I agree";
  4. a server record of `(user_id, notice_version, agreed_at)`.
- **Withdrawing:** "Delete my data" already works as withdrawal.
- **Needs:** a Supabase migration on the live project, plus `LocalDBProvider`.

## B. Security (Rule 6)

- **Met:**
  - TLS;
  - Supabase encrypts at rest;
  - secrets stay on the server;
  - tokens are in the Android Keystore;
  - row-level security was tested with the public key;
  - logs hold no health data.
- **Gap: who accessed what.** Logs carry no user id, so we couldn't tell whose data a suspicious request touched (Rule 6(1)(c)). Options:
  - log a keyed hash of the user id;
  - lean on Supabase's own audit logs.
- **Founder:**
  - data processing agreements with Supabase and Google (Rule 6(1)(f));
  - check that the Supabase plan includes backups (Rule 6(1)(d); the free tier has none).

## C. Rule 8(3): personal data after "Delete my data"

- **The text:** keep "such personal data, associated traffic data and other logs of the processing for a minimum period of one year". Illustration 1 says this applies "even if X deletes her account".
- **Reading 1, logs only:** keep logs a year (done), and keep erasing health data at once.
  - Supports it: the Seventh Schedule purposes are all State access, and the Act's s.8(7) duty to erase. It matches what the policy promises.
  - Risk: a regulator could read the rule as covering the data itself.
- **Reading 2, everything for a year:** on "Delete my data", hide the data from the app but keep it, locked, for a year.
  - Cost: we hold health data people asked us to delete. The policy, the app text and the delete code would all change.
- **Status:** Reading 1 is in place. The founder decides with a lawyer before 13 May 2027.

## D. Breach notice (Rule 7)

- **Problem:** CalFit has no email or phone for anyone, so a notice can only reach people inside the app.
- **Before launch:**
  - a server-delivered notice the app shows on Home;
  - a short runbook: who decides, the Board's 72-hour report, the user message using the five items in Rule 7(1).

## E. Access (Act s.11)

- **Already in the app:** the profile, full history and the policy.
- **Gap:** s.11 also asks for "a summary" of processing and the processors. The policy lists them.
- **Options:** a "Download my data" export later. Never put health data on the clipboard.

## Changed today

**Backend:** `UserProfileRequest` refuses a birth year that makes someone under 18 (`ADULT_AGE`). The check is on requests only, so stored rows still load.
- Boundary: turning 18 in this calendar year is allowed, because a year can't pin the birthday.
- Tests: `tests/test_body_metrics.py`, three tests.

**App:**
- the body-details sheet refuses the same years, with the message "CalFit is for adults (18+)";
- Settings has a "Prescription reading" switch. Off withdraws consent at once and clears the old un-namespaced key; on shows the same consent sheet as first use;
- new strings in en/hi/bn/as. Khasi is in English until a speaker reviews it, because consent wording must be exact;
- tests: two widget tests, plus `privacy_policy_copy_test.dart`, which keeps the two policy copies identical.

**Policy, both copies:**
- prescription withdrawal;
- one-year logs;
- nomination;
- complaining to the Board;
- the 90-day legal limit (we promise 30);
- adults-only refusal;
- a breach section.

**`docs/DEPLOY_CLOUD_RUN.md`:**
- the log-retention command;
- the out-of-date "device ID" gap is corrected.
