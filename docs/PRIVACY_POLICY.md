# CalFit Privacy Policy

**Effective:** 2026-10-28 (draft — not yet reviewed by a lawyer)
**Applies to:** CalFit mobile app (Android) and the CalFit API.
**Contact:** _(fill in before Play Store submission — a working email the user can reach, e.g. privacy@calfit.app)_

CalFit is published by _(fill in: your legal name or company, address, country)_. This policy explains what we collect, why, how long we keep it, and the choices you have. It is written under India's **Digital Personal Data Protection Act, 2023 ("DPDP Act")** because our first users are in India. It covers you wherever you use CalFit.

## 1. What CalFit does

CalFit reads the label on a packaged food, grades how well it fits the health profile you set, and shows you findings and alternatives. CalFit is a label reader. **It is not medical advice.**

## 2. What we collect

### 2.1 Your profile (stored on our server)

- The health profile you choose: conditions (e.g. diabetes, hypertension, anaemia), allergies, dietary preferences, goals, sensitivities (e.g. "avoid caffeine"), and the name you give.
- Optional body details: height, weight, target weight, year of birth, sex and activity level. We calculate your BMI from height and weight; we do not store the BMI itself.

We store your profile on our server, linked to your anonymous identifier (see 2.2), so every scan can be scored against it and you see the same profile each time you open the app. Health conditions, allergies and body details are **sensitive personal data** under the DPDP Act. They are never used for advertising, never sold, never shared with third parties for marketing.

On your device we keep only your sign-in token, your app settings (theme, text size, language) and your acknowledgement of the "not medical advice" notice.

### 2.2 Anonymous identity

On first launch, our server issues the app a random identifier and a signed token, which the app keeps on the device and sends with each request. If you add family members on the same phone, each profile gets its own separate identifier and token: their conditions, scans and history are stored apart, our server cannot tell that the profiles share a phone, and deleting one profile's data deletes only that profile's. Family profiles are for adults. Your profile, scan history and daily scan cap are attached to that identifier. It is not your name, email, phone number, or any government ID. Uninstalling the app or clearing its data removes the token from the device; your data stays on our server until you delete it (see 5 and 8), and without the token it can no longer be reached from the app.

### 2.3 Each scan

When you scan a product, we receive:

- The photo of the label.
- Your anonymous identifier and a timestamp.

We send the photo to Google's Gemini API so Gemini can transcribe what is printed on the label. The transcribed label is scored on our server by deterministic rules — a reviewable list of thresholds — not by an AI model. We then send Gemini the label details and the score and findings, so it can write a short plain-language explanation; that explanation is checked against the findings before you see it. A finding names only the condition, allergy or diet that this product affects (for example "declared allergen: peanut"). Your profile itself is not sent: not your name, age or body details, and not your full list of conditions, allergies, diets or goals. Nothing that identifies you or your device is sent with any request to Gemini. We keep the scan (photo, label details, score, findings and explanation) so you can see it in your history, together with the conditions, allergies, dietary preferences and goals it was scored for. A past score is a record of that moment: editing your profile later does not change it.

If you answer "Was this result right?" under a scan, we store your answer with that scan: yes or no, and which of a fixed list of problems you picked (for example "wrong product" or "missed an allergen"). There is no free-text box, so nothing else is collected. We use the answers, counted across all users, to measure and improve how accurate CalFit is. They are deleted with your scans.

Product information shown as alternatives comes from Open Food Facts (openfoodfacts.org), an open database of food products. It contains no personal data. When a photo shows only the front of a pack and the product isn't in our own database, our server searches Open Food Facts by the product's name as printed (for example "Amul Lassi") to find its ingredients and nutrition. Only that product name or barcode is sent, from our server; nothing about you is sent to Open Food Facts.

If you add a serving size to a scan (when the label doesn't say what its numbers are per), we store that serving size with your account and use it the next time you scan the same product. It is deleted with your data.

### 2.4 Prescription reading (optional)

If you choose "Prescription" in your profile, you can photograph a prescription so CalFit can suggest conditions and allergies to add to your profile. This is optional and off until you agree in the app.

- The photo is sent to our server and on to Google's Gemini API, which reads the diagnoses, medicine names and allergies printed on it. We tell the model not to copy your name, doctor, address, phone numbers or ID numbers.
- **We do not save the photo or what is read from it.** They are held in memory while your request is processed; a large upload may briefly sit in temporary server storage that is deleted when the request ends. They are not stored in our database or file storage, are not added to your scan history, and are not written to our logs. We do keep a per-day count of how many prescriptions you have read, to enforce a daily limit; the count contains no content. **Delete my data** removes earlier days' counts. Today's scan and prescription counts (a number and a date) stay, so the daily limits still apply after a delete.
- We never add anything to your profile automatically. You see the suggestions, tick the ones that apply, and confirm. Only what you confirm is saved, as part of your profile.
- We do not store medicine names at all.
- Some suggestions are inferred from a medicine name (for example, a diabetes medicine suggesting diabetes). These are labelled "inferred" and are not a diagnosis. **This is not medical advice.**
- Legal basis: your explicit consent, given in the app before first use (you can decline, and nothing is sent until you also pick a photo). The app currently remembers your consent on the device and does not yet offer a way to withdraw it; clearing the app's data resets it.

### 2.5 What we do **not** collect

- Your name, email address, phone number, Aadhaar, or any government ID.
- Advertising identifiers.
- Precise location.
- Contacts, calendar, SMS, call logs, browser history.
- Any health data that is not the profile and body details you set yourself.

## 3. Why we process this data (DPDP §5, §6)

- **Scan evaluation.** Legal basis: your consent, given each time you tap "scan" and in advance by setting a profile.
- **Daily scan cap.** Legal basis: our legitimate business interest in keeping the service affordable and resistant to abuse.
- **Scan history (if enabled).** Legal basis: your consent — history is bound to the device identifier you control.
- **Service health and errors.** Legal basis: legitimate interest in keeping the service running. Logs include a random request id, which part of the app was called, status codes, timings, which AI model answered, and the type of any error. They never include your photo, the label text, your profile, your explanation or error messages (which can repeat what was sent).

## 4. Processing — who touches what

- **CalFit server (Google Cloud Run, Mumbai `asia-south1`, when launched).** Receives your request, applies the scoring rules, returns the result.
- **Google Gemini (Google AI).** Receives the label photo and returns a transcription; receives the label details, findings and the profile fields listed in 2.3 to write the explanation. Google processes it under the Gemini API terms. Before public launch we will use only the paid tier, under which Google does not use your data to improve its products.
- **Supabase (database and object storage, Singapore).** Holds your profile, your scan records and the uploaded photos.

Each of these is a **data processor** under the DPDP Act. CalFit is the **data fiduciary**: we decide what happens with your data. We keep the list of processors small on purpose and will update this document before adding one.

## 5. Retention

- **Profile, body details, scan history, photos, saved serving sizes and your "Was this result right?" answers:** kept until you delete them. You can remove a single scan from its result screen. Use **Settings → Delete my data** to remove your profile, every scan, every photo, every saved serving size and every answer from our servers immediately. An automatic retention limit will be added before public launch and stated here.
- **Logs:** 30 days.

## 6. International transfers

- Your profile, scans and photos are stored with Supabase in **Singapore**. The CalFit server will run in India (Mumbai, `asia-south1`).
- Gemini may process your photo and the data in 2.3 in Google data centres outside India under Google's terms. We will update this policy if we switch providers or regions.

## 7. Security

- Secrets (API keys, database credentials) live in Google Secret Manager and are never embedded in the app or on your device.
- Traffic between the app and the server uses HTTPS/TLS.
- The release Android build is signed with an upload key and distributed through Google Play App Signing.
- Access to our server-side records is limited to the CalFit maintainers.

## 8. Your rights (DPDP §11-§15)

You can at any time:

- **Access** the data we hold about you.
- **Correct** or **update** it.
- **Erase** it — in the app under **Settings → Delete my data**, or by writing to us.
- **Withdraw consent** for any purpose.
- **Grieve** — raise a complaint with us or escalate to the Data Protection Board of India.

Write to _(privacy contact above)_. We will respond within **30 days**. You do not need to give a reason, and we will not charge you for a reasonable request. If you are not satisfied, you can escalate to the Data Protection Board of India under DPDP §27.

## 9. Children

The CalFit app is intended for users aged 18 and above. We do not knowingly collect data from children under 18. If you are a parent or guardian and believe your child has used CalFit, contact us and we will delete the data.

## 10. Changes to this policy

If we change this policy in a way that affects your rights, we will show you the new policy inside the app and ask for your consent before continuing. Smaller clarifications will be published here with the effective date updated at the top.

## 11. Grievance Officer (DPDP §13)

_(fill in before Play Store submission — one named contact with an email you reliably check within 30 days.)_

---

> **Not medical advice.** CalFit scans a product label and tells you how well it fits the profile you set. It cannot replace a doctor or dietitian, and it will not know everything about a food. If you have an allergy, read the pack yourself. If you have a medical condition, talk to your clinician before making diet changes based on a scan.
