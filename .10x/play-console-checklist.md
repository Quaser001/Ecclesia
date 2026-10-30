# Play Console Checklist

**Prepared:** 2026-10-30. Use this while filling in Play Console.

---

## 1. Developer account ($25 one-time)

Sign up at https://play.google.com/console. A **personal account** must run a closed test with at least 12 testers for 14 continuous days before production access. An organisation account (needs a D-U-N-S number) is exempt.

## 2. Create the app

- App name: **CalFit**
- Default language: English (India)
- App or game: **App**
- Free or paid: **Free** (payments come later via Play Billing)

## 3. App content declarations

### 3a. Privacy policy

Play needs a **public URL**. The policy text is in `apps/mobile/assets/legal/privacy_policy.md` and `docs/PRIVACY_POLICY.md`. Before publishing, fill in the blanks:
- Publisher legal name / company
- Contact email (e.g. privacy@calfit.app)
- Grievance officer name and email

**Hosting options** (cheapest to easiest):
- GitHub Pages (free): push the .md to a public repo, enable Pages
- A static page on your domain (calfit.app if you have one)
- Google Sites (free, no domain needed)

Put the URL in: Play Console → Policy → App content → Privacy policy, **and** in the app's Settings screen (it already links to the bundled copy).

### 3b. Data safety form

Answer these in Play Console → Policy → App content → Data safety:

| Question | Answer |
|---|---|
| **Does your app collect or share any user data?** | Yes |
| **Is all collected data encrypted in transit?** | Yes (HTTPS/TLS) |
| **Do you provide a way to delete data?** | Yes (Settings → Delete my data) |
| **Does your app target children?** | No (18+ only) |

**Data types collected:**

| Data type | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|
| **Health info** (profile: conditions, allergies, goals, body details) | Yes | No | App functionality | No |
| **Photos** (label scans) | Yes | No | App functionality | No |
| **App activity** (scan history, ratings feedback) | Yes | No | App functionality, Analytics | No |
| **Device or other IDs** (anonymous token) | Yes | No | App functionality, Security | No |
| **App info & performance** → Crash logs, Diagnostics (error type + stack frames from `/client-errors`) | Yes | No | App functionality, Analytics | No |

**Why "Shared: No" even though photos go to Gemini.** Play defines "sharing" as transferring data to a *third party*, and it **excludes** transfers to a "service provider" that only processes the data on your behalf. Gemini (label reading) and Supabase (storage) are processors under contract — they don't use the data for their own purposes — so under Play's definition this is **not** sharing. (This matches the privacy policy, which calls them processors.) Keep a note of this reasoning in case Play asks. If you'd rather be conservative, you may still declare Photos as "Shared" — it won't get the app rejected, but "No" is the accurate answer.

**Not collected:** name, email, phone, location, financial info, contacts, messages, files, audio, calendar, browsing history, search history, ads ID.

**Processors the data reaches (not "sharing" per Play, but good to know):**
- Google Gemini — receives label photos and findings for transcription/explanation
- Supabase — stores profile, scans and photos
- Google Cloud Logging — receives crash reports (error type + stack frames, no health data)

**Data retention:** until the user deletes it. Logs: 1 year.

### 3c. Health apps declaration

Play Console → Policy → App content → Health apps:
- Category: **Nutrition / Food label reader**
- This is NOT a medical device, NOT a clinical tool
- It does NOT diagnose, treat, cure or prevent any disease
- Answer "No" to all medical-related questions
- State: "CalFit reads food labels and compares nutrition against a user-set health profile. It is not medical advice."

### 3d. Content rating (IARC questionnaire)

- Violence: None
- Sexual content: None
- Drugs/alcohol: None
- Language: None
- Interactive: No (no user-to-user communication)
- Location sharing: No
- Personal info collected: Yes (health profile)
- Target age: **18+** (select "Not designed for children")

Expected rating: **Everyone** or **3+** (since there's no objectionable content), but flagged as 18+ for data collection.

### 3e. Government apps / Financial features / News

Answer **No** to all.

## 4. Store listing

### Short description (80 chars max)
```
Scan any food label. See how it fits your health profile instantly.
```

### Full description (4000 chars max)
```
CalFit reads the back of any packaged food and tells you how well it fits the health profile you set — your conditions, allergies, dietary preferences and goals.

How it works:
1. Set your health profile (conditions like diabetes or hypertension, allergies, dietary preferences, goals).
2. Photograph the back label of any packaged food.
3. CalFit reads the label, scores it against your profile, and explains what to watch.

What you get:
- A clear rating for YOUR profile, not a generic score.
- Findings that name the specific condition or allergy each applies to.
- A plain-language explanation of why this product is good or bad for you.
- Alternatives from Open Food Facts when available.
- Scan history so you can compare products.

What CalFit is NOT:
- Not medical advice. It reads labels; it doesn't replace a doctor or dietitian.
- Not a calorie counter or meal planner.
- Not a barcode scanner (it reads the nutrition and ingredients table).

Privacy:
- No name, email or phone number collected.
- Your health profile stays on our server, linked only to an anonymous token.
- Photos are sent to Google Gemini for label reading only — your profile is never sent.
- Scores come from reviewable rules, not from the AI.
- Delete everything at any time in Settings.

Built for India's packaged food labels. Works with any language on the label.
```

### Category
Health & Fitness

### Contact details (required)
- Email: _(your support email)_
- Website: _(optional — calfit.app if you have it)_

## 5. Upload the app bundle

Play Console → Testing → Closed testing → Create track:
- Upload `app-release.aab` from `apps/mobile/build/app/outputs/bundle/release/`
- Play App Signing: accept (enrol) when prompted
- Create a tester list with at least 12 email addresses
- The 14-day clock starts when you add testers and they opt in

## 6. Things to do before production release

- [ ] Privacy policy hosted at a public URL
- [ ] All Data safety answers filled in
- [ ] Health apps declaration completed
- [ ] Content rating questionnaire completed
- [ ] Store listing: icon (512x512 already generated), screenshots (phone), feature graphic (1024x500)
- [ ] 12 testers opted in for 14 continuous days
- [ ] Release build tested on mobile data (laptop off) against the deployed server
- [ ] Gemini quota cap set in GCP Console
- [ ] All exposed keys rotated
