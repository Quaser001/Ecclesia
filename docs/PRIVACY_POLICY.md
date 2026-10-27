# CalFit Privacy Policy

**Effective:** 2026-10-26
**Applies to:** CalFit mobile app (Android) and the CalFit API.
**Contact:** _(fill in before Play Store submission — a working email the user can reach, e.g. privacy@calfit.app)_

CalFit is published by _(fill in: your legal name or company, address, country)_. This policy explains what we collect, why, how long we keep it, and the choices you have. It is written under India's **Digital Personal Data Protection Act, 2023 ("DPDP Act")** because our first users are in India. It covers you wherever you use CalFit.

## 1. What CalFit does

CalFit reads the label on a packaged food, grades how well it fits the health profile you set, and shows you findings and alternatives. CalFit is a label reader. **It is not medical advice.**

## 2. What we collect

### 2.1 On your device, never sent to us

- The health profile you choose: conditions (e.g. diabetes, hypertension, anaemia), allergies, dietary preferences, goals, sensitivities (e.g. "avoid caffeine").
- Your device identifier for the app (see 2.2).
- Your acknowledgement of the "not medical advice" notice.

Health conditions and allergies are **sensitive personal data** under the DPDP Act. We store them locally on your device and send them to our server only as part of a scan request, so the scoring engine can personalise the result. They are never used for advertising, never sold, never shared with third parties for marketing.

### 2.2 Anonymous device identifier

On first launch, the app generates a random UUID and saves it on the device. We send it with each API request so your scan history and daily scan cap are attached to you. The UUID is not your name, email, phone number, or any government ID. Uninstalling the app or clearing its data wipes it.

### 2.3 Each scan

When you scan a product, we receive:

- The photo of the label.
- The health profile fields relevant to scoring that product.
- Your anonymous device identifier.
- A timestamp.

We send the photo to Google's Gemini API so Gemini can transcribe what is printed on the label. Gemini receives the photo but not your health profile. The transcribed label is scored on our server by deterministic rules — a doctor-reviewable list of thresholds — not by an AI model. See the "Processing" section for the detail.

### 2.4 Prescription reading (optional)

If you choose "Prescription" in your profile, you can photograph a prescription so CalFit can suggest conditions and allergies to add to your profile. This is optional and off until you agree in the app.

- The photo is sent to our server and on to Google's Gemini API, which reads the diagnoses, medicine names and allergies printed on it. We tell the model not to copy your name, doctor, address, phone numbers or ID numbers.
- **We do not save the photo or what is read from it.** They are held in memory while your request is processed; a large upload may briefly sit in temporary server storage that is deleted when the request ends. They are not stored in our database or file storage, are not added to your scan history, and are not written to our logs. We do keep a per-day count of how many prescriptions you have read, to enforce a daily limit; the count contains no content.
- We never add anything to your profile automatically. You see the suggestions, tick the ones that apply, and confirm. Only what you confirm is saved, as part of your profile.
- We do not store medicine names at all.
- Some suggestions are inferred from a medicine name (for example, a diabetes medicine suggesting diabetes). These are labelled "inferred" and are not a diagnosis. **This is not medical advice.**
- Legal basis: your explicit consent, given in the app before first use (you can decline, and nothing is sent until you also pick a photo). The app currently remembers your consent on the device and does not yet offer a way to withdraw it; clearing the app's data resets it.

### 2.5 What we do **not** collect

- Your name, email address, phone number, Aadhaar, or any government ID.
- Advertising identifiers.
- Precise location.
- Contacts, calendar, SMS, call logs, browser history.
- Any health data that is not the profile you set yourself.

## 3. Why we process this data (DPDP §5, §6)

- **Scan evaluation.** Legal basis: your consent, given each time you tap "scan" and in advance by setting a profile.
- **Daily scan cap.** Legal basis: our legitimate business interest in keeping the service affordable and resistant to abuse.
- **Scan history (if enabled).** Legal basis: your consent — history is bound to the device identifier you control.
- **Service health and errors.** Legal basis: legitimate interest in keeping the service running. Logs include request paths, status codes, and error messages. They do not include the content of your profile or the content of your photo.

## 4. Processing — who touches what

- **CalFit server (Google Cloud Run, Mumbai `asia-south1`).** Receives your request, applies the scoring rules, returns the result, keeps the scan record (so you can see your history).
- **Google Gemini (Google AI).** Receives the photo and returns a transcription of what the label says. Google processes it under the Gemini API terms. We use a paid tier (see 6).
- **Supabase (database and object storage).** Holds the scan record and the uploaded photo.

Each of these is a **data processor** under the DPDP Act. CalFit is the **data fiduciary**: we decide what happens with your data. We keep the list of processors small on purpose and will update this document before adding one.

## 5. Retention

- **Health profile:** on your device until you change or clear it. On our server, only for the duration of a request.
- **Scan history and photo:** 90 days from the scan date, then deleted. You can wipe your history earlier by clearing the app data on your device (the next release will add a one-tap "delete my data" button; see 9).
- **Logs:** 30 days.

## 6. International transfers

- Our server lives in **India (Mumbai, `asia-south1`)**.
- Gemini may process your photo in Google data centres outside India under Google's terms. We will update this policy if we switch providers.

## 7. Security

- Secrets (API keys, database credentials) live in Google Secret Manager and are never embedded in the app or on your device.
- Traffic between the app and the server uses HTTPS/TLS.
- The release Android build is signed with an upload key and distributed through Google Play App Signing.
- Access to our server-side records is limited to the CalFit maintainers.

## 8. Your rights (DPDP §11-§15)

You can at any time:

- **Access** the data we hold about you.
- **Correct** or **update** it.
- **Erase** it.
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
