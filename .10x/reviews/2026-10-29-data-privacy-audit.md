# Audit: how CalFit handles data, what the AI sees, and family profiles (2026-10-29)

**Roles:** Security, Architect and DBA.

**Question asked:** After a scan, what reaches the AI, and can the AI do its job without the person's details? Is the data consistent and separated? How would multiple family profiles work?

## 1. Where the data goes today

| From → to | What is sent | What is NOT sent |
|---|---|---|
| Phone → CalFit backend | Photo, bearer token, profile edits | Nothing else; release builds refuse unencrypted HTTP |
| Backend → Gemini, **label read** | The label photo only. GPS location is stripped first | Who you are; no user id or token; your profile |
| Backend → Gemini, **explanation** | Product name/brand, the verdict, the findings, the nutrition numbers | **From today:** your profile. Before, it sent every condition, allergy, diet and goal |
| Backend → Gemini, **prescription** (off) | The prescription photo | Your profile. **But the photo itself shows the patient's name, age, doctor and phone** |
| Backend → Open Food Facts | The product name | Anything about you |
| Backend → Supabase (Mumbai) | Profile, scans, photos (private bucket), feedback, serving sizes | The prescription photo and what was read from it |
| Logs | Request route, status, timings, error *types* | Content, error text, health data (enforced by tests) |

**Gemini can't tie a request to a person.** Every call goes from our server with our key. Google sees "someone with a peanut allergy scanned a peanut bar", with no name, device, account or way to link two scans together. This is called **pseudonymous by architecture**, and it is the main protection.

**Fixed in this pass:** the explanation prompt sent the whole profile. Now it sends only the findings, and a finding names only what this product affects. Scanning a biscuit no longer tells the AI about an unrelated condition such as anaemia or a pregnancy.
- Test: `test_the_explanation_prompt_holds_no_profile_beyond_the_findings`.
- The privacy policy (2.3, both copies) is updated to match.

## 2. "Encrypt it so the AI can work on it but never see it": what exists

| Technique | What it means | Can CalFit use it? |
|---|---|---|
| **Homomorphic encryption (FHE)** | The model computes on encrypted data and never decrypts it | **No.** Research systems for LLMs "remain far from practical deployment" ([VLDB 2025](https://www.vldb.org/pvldb/vol19/p4927-lim.pdf)). A healthcare FHE study needed major model changes and lost accuracy ([arXiv 2025](https://arxiv.org/pdf/2501.04058)) |
| **Confidential computing** | Data is decrypted only inside sealed hardware that even the cloud provider can't read, with proof ("attestation"). Examples: Apple Private Cloud Compute; Google **Private AI Compute** (Nov 2025, Titanium Intelligence Enclaves) | **Not for third-party apps yet.** Google's version powers its own products; I found no developer API ([The Hacker News](https://thehackernews.com/2025/11/google-launches-private-ai-compute.html), [The Register](https://www.theregister.com/2025/11/12/google_touts_private_ai_compute/)) |
| **Data minimisation and pseudonymisation** | Send only the facts the task needs, with no identity attached | **Yes: done.** This is what health apps actually ship |
| **Contractual zero retention** | The provider neither trains on nor keeps prompts | **Yes, on Vertex AI.** It doesn't train on customer data. Abuse-monitoring prompt logging can be waived (zero data retention) on request. Google's own docs say to use Vertex, not the Developer API, when you need guaranteed zero retention ([Vertex AI data governance](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/data-governance)) |
| **On-device processing** | Identifying parts never leave the phone | **Yes, for prescriptions** (see 3) |

**So:** the predictable, proven version of your idea is not encryption. It is **send nothing identifying, send only what this answer needs, and use a provider contract that keeps nothing.** The first two are now in place. The third is the Vertex move that is already on your list.

## 3. Gaps, ranked

1. **The current AI tier.** The AI Studio key (`developer_api`) has weaker terms than Vertex, and on the free tier Google may review prompts.
   - Fix: switch to Vertex (`GEMINI_BACKEND=vertex`, asia-south1), then request the abuse-logging exception. This is already a founder task, and nothing else is needed in code.
2. **Prescription photos carry identity.** The page itself shows name, age, doctor and phone. The feature is off.
   - Fix before turning it on: read the text **on the phone** with Google ML Kit, which works offline and is free. Drop the name, age, phone, address and doctor lines, then send only the remaining text.
   - Alternative: a crop and blur step before upload.
3. **The token sits in plain SharedPreferences.** Backup is now off, but a rooted or stolen phone can still read it.
   - Fix: Keystore storage (`flutter_secure_storage`). Deferred item F.
4. **Label photos can include a face or background.** Low risk; GPS is already stripped.
   - Fix later: crop on the phone to the detected text area.
5. **Free text in allergies:** capped at 30 entries of 60 characters each. Only an allergy that matches the product is ever sent.

**Already in place:**
- TLS everywhere; release builds block unencrypted HTTP.
- Private photo bucket with 1-hour signed links.
- Supabase encrypts its storage at rest.
- Logs carry no content.
- GPS EXIF is stripped.
- No cloud backup.
- Each scan's own "scored for" record (ADR-007).

## 4. Consistency and separation

**Holding up (with tests):**
- **Every read and write is scoped by the identity inside the signed token.** It never trusts a client-sent id. Photos are path-checked against `scans/<identity>/`, and a test checks that every route requires a token.
- **A past rating keeps its score and the profile it was scored for** (ADR-007).
- **A failed save says `saved: false`** and removes its orphan photo.
- **Today's daily quota survives "Delete my data".**

**Gaps:**
- **"Delete my data" is five separate deletes, not one transaction.** A failure partway can leave some rows behind. Fix: one SQL function, which is a live migration and needs your yes (deferred AM).
- **Scan rows store JSON as double-encoded text.** Known; it works, but it can't be queried in SQL.
- **Device-level state:** the prescription consent, the profile-reset flag and the screens' in-memory data belong to the *device*, not a person. With one person that's fine. **With family profiles it must become per profile** (see 5).

## 5. Family profiles (father, mother, child), designed but not built

**Goal:** switch profile like switching accounts in Telegram. Each profile has its own conditions, scans, history, insights, serving sizes and quota, and nothing mixes.

| Option | How | Pros | Cons |
|---|---|---|---|
| **A. Separate identity per profile (recommended)** | The app keeps one signed token per profile and switching profile switches token. Exactly how Telegram's multiple accounts work | **No backend or database change.** Strongest separation: the server can't even tell they're one family. Every existing check (ownership, quota, delete) applies per profile unchanged | Each profile has its own daily cap. "Delete all family data" loops over profiles. Google sign-in later must link several identities |
| B. One account with members | New `members` table; scans, feedback and servings get `member_id`; every endpoint takes a member id | Family-level features (shared quota, one deletion) | Live migration; every route changes; a new way to see someone else's data (member-id checks); more tests |

**What changes in the app (option A):**
- A token store keyed by profile.
- A profile switcher on Home, plus "Add family member" (name, emoji or colour, then the normal profile setup).
- Every screen's data reloads on switch, keyed by profile, so no screen ever shows the previous person's data.
- A scan started for one profile is saved and shown under that profile even if you switch mid-scan.
- Prescription consent and the reset flag become per profile.
- "Delete my data" offers "this profile" or "everyone on this phone".

**A child profile needs two decisions first:**
- **Law:** India's DPDP Act requires verifiable parental consent before processing a child's (under 18) data. The privacy policy currently says the app is for 18+.
- **Health:** every threshold is adult. WHO's salt and sugar limits for children are lower, scaled to their energy needs. Scoring a child against adult limits would under-warn.
- **Options:**
  - adults only for now; or
  - a child profile with a parent-consent step, a clear "scored with adult limits" warning, and cited child thresholds later (dietitian review).

## Sources
- [VLDB 2025: private LLM inference under FHE](https://www.vldb.org/pvldb/vol19/p4927-lim.pdf)
- [Homomorphic encryption in healthcare (arXiv 2501.04058)](https://arxiv.org/pdf/2501.04058)
- [Google Private AI Compute launch (The Hacker News)](https://thehackernews.com/2025/11/google-launches-private-ai-compute.html)
- [The Register on Private AI Compute](https://www.theregister.com/2025/11/12/google_touts_private_ai_compute/)
- [Vertex AI data governance and zero data retention](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/data-governance)
- [Gemini API zero data retention notes](https://ai.google.dev/gemini-api/docs/zdr.md.txt)
