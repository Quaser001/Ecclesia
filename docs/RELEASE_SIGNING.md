# Release signing for the CalFit Android app

Debug keys are fine for `flutter run --debug`. They are not valid for Play Store, so a release build needs an **upload keystore**. Google Play App Signing then re-signs the APK with the final signing key — you keep only the upload keystore, which you can rotate.

## 1. Generate an upload keystore

Run once, on a machine you control. The output file is a secret.

```bash
keytool -genkey -v \
  -keystore calfit-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Fill in the prompts. Pick strong passwords and store them somewhere you'll still have in two years (password manager, not Notes).

Move the file somewhere **outside the repo** — e.g. `~/.android/calfit-upload.jks`.

## 2. Point the build at it

```bash
cp apps/mobile/android/key.properties.example apps/mobile/android/key.properties
# edit key.properties with the real path and passwords
```

`android/key.properties` is already in `.gitignore` — do not commit it. The Gradle script (`apps/mobile/android/app/build.gradle.kts`) reads it when it exists and switches the release build to the real keystore automatically.

## 3. Build a release APK / App Bundle

```bash
cd apps/mobile
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://<cloud-run-url>
```

The App Bundle at `build/app/outputs/bundle/release/app-release.aab` is what you upload to Play Console.

## 4. Enroll in Play App Signing

Play App Signing is on by default for new apps on Play Console. The first release upload asks you to enroll — accept. From then on, Google manages the final signing key and you only ever handle the upload keystore.

If the upload keystore is ever lost or compromised, rotate through Play Console → **Setup → App signing → Request upload key reset**. This is cheap, which is exactly why we don't keep the final signing key on this laptop.

## 5. What to check before uploading

```bash
# Confirm the APK is signed with your upload key, not debug.
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | head
# Issuer: CN=... (should NOT be CN=Android Debug)
```

Also confirm:

- `versionCode` was bumped in `pubspec.yaml` (`version: 1.0.0+1` → `1.0.0+2` etc).
- `--dart-define=API_BASE_URL` points at the deployed Cloud Run URL, not localhost.
- A fresh install opens, shows the first-launch disclaimer dialog once, and a scan reaches the deployed API.
