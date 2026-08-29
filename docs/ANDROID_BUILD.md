# Building the Rank Rush Android app

This guide takes you from a fresh clone to a signed release **APK** / **App
Bundle** you can install or upload to Google Play. The `android/` folder is
already generated and wired for Firebase — you supply your own Firebase project,
signing key, and build-time config.

> **Virtual coins only.** Rank Rush is an entertainment app with no real-money
> features. If you publish it, keep the virtual-coin-only boundary intact and
> follow Google Play's policies for apps that simulate gambling (18+ content
> rating, no real prizes).

- **Application ID:** `com.rankrush.app`
- **Min SDK:** 23 (Android 6.0) · **Target/Compile SDK:** 35
- **Requires:** Flutter **3.27+** (Dart 3.6+), JDK **17**, Android SDK, and a
  Firebase project on the **Blaze** plan (Cloud Functions).

---

## 0. One-time machine setup

Install Flutter and confirm the Android toolchain is healthy:

```bash
flutter --version          # must be 3.27 or newer
flutter doctor             # resolve any [✗] under "Android toolchain"
```

`flutter doctor --android-licenses` accepts the SDK licenses if prompted. Android
Studio (or the standalone command-line tools) provides the SDK and platform
build tools.

> **Why no `gradle-wrapper.jar` in the repo?** It's intentionally git-ignored.
> The Flutter tool drops the correct wrapper jar into `android/gradle/wrapper/`
> automatically on your first `flutter run`/`flutter build`. If you ever need it
> without a full build, run `flutter build apk --config-only` once.

---

## 1. Get the Flutter dependencies

From the project root:

```bash
flutter pub get
```

This also writes `android/local.properties` (pointing at your Flutter + Android
SDKs). That file is machine-specific and git-ignored — never commit it.

---

## 2. Create the Firebase Android app

1. In the [Firebase console](https://console.firebase.google.com), open (or
   create) your project.
2. **Add app → Android.**
3. **Android package name:** `com.rankrush.app` (must match exactly).
4. Add the **SHA-1** _and_ **SHA-256** fingerprints of every signing key you'll
   use — this is required for Google Sign-In and App Check to work. See
   [§5](#5-signing-fingerprints-for-google-sign-in) for how to get them. You can
   add fingerprints now or after generating your keystore; add debug now so
   `flutter run` works immediately.
5. Download **`google-services.json`** and place it at:

   ```
   android/app/google-services.json
   ```

   A template (`android/app/google-services.json.example`) shows the expected
   shape. The real file is git-ignored.

The moment `google-services.json` exists, the Google Services and Crashlytics
Gradle plugins activate automatically (see `android/app/build.gradle`). Without
it, the app still assembles so you can iterate on UI — but Firebase calls fail
at runtime.

> **Single package for debug + release.** Debug builds use the same
> `applicationId` (`com.rankrush.app`) as release, so one `google-services.json`
> client entry covers both. Just register both keys' fingerprints under that one
> Android app in Firebase.

---

## 3. Supply build-time config (dart-defines)

The app reads **no secrets from source** — all Firebase client identifiers come
in through `--dart-define`. Copy the template and fill in your values:

```bash
cp dart_defines.example.json dart_defines.json   # then edit it
```

The Android build only needs the `FIREBASE_*_ANDROID`, `FIREBASE_PROJECT_ID`,
`FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_STORAGE_BUCKET` keys populated
(find them in the Firebase console under *Project settings → General* and in
`google-services.json`). `dart_defines.json` is git-ignored.

> These are **public** Firebase client identifiers, not secrets. Server secrets
> (the provably-fair `serverSeed`, the Admin SDK service account) live only in
> the Cloud Functions runtime and never ship in the APK.

---

## 4. Generate a release keystore

Skip this for debug-only runs. For anything you distribute:

```bash
keytool -genkey -v \
  -keystore ~/keys/rank-rush-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias rank-rush
```

Keep the `.jks` file **safe and backed up** — losing it means you can't ship
updates to the same Play listing. Never commit it.

Then tell Gradle about it by copying the template and filling it in:

```bash
cp android/key.properties.example android/key.properties
```

```properties
# android/key.properties  (git-ignored)
storePassword=…
keyPassword=…
keyAlias=rank-rush
storeFile=/absolute/path/to/rank-rush-release.jks
```

If `android/key.properties` is absent, release builds fall back to the debug
signing key so the project still assembles — but such an APK is **not**
Play-uploadable.

---

## 5. Signing fingerprints (for Google Sign-In)

Google Sign-In and App Check reject requests from an app whose signing
fingerprint isn't registered in Firebase. Get them with:

```bash
# Debug key (auto-created by the SDK; needed for `flutter run`)
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android

# Your release key
keytool -list -v -alias rank-rush \
  -keystore ~/keys/rank-rush-release.jks
```

Copy the **SHA1** and **SHA-256** lines into *Firebase console → Project
settings → Your apps → (Android app) → Add fingerprint*, then **re-download
`google-services.json`** and replace the one in `android/app/`.

> **Play App Signing:** if you enrol in Play App Signing (recommended), Google
> re-signs your app with its own key. Add the **App signing key** SHA-1/-256
> from the Play Console (*Setup → App integrity*) to Firebase as well, or
> Sign-In will fail for installs from the Play Store.

---

## 6. Build

Run/instal on a connected device or emulator:

```bash
flutter run --dart-define-from-file=dart_defines.json
```

Release **APK** (universal + per-ABI split for smaller downloads):

```bash
flutter build apk --release \
  --dart-define-from-file=dart_defines.json --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (and armeabi-v7a, x86_64)
```

A single universal APK (simplest to sideload):

```bash
flutter build apk --release --dart-define-from-file=dart_defines.json
# → build/app/outputs/flutter-apk/app-release.apk
```

Release **App Bundle** (what you upload to Google Play):

```bash
flutter build appbundle --release --dart-define-from-file=dart_defines.json
# → build/app/outputs/bundle/release/app-release.aab
```

Install a built APK on a plugged-in device:

```bash
flutter install --release       # or: adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 7. Local development against Firebase emulators

Set `"USE_EMULATORS": true` in `dart_defines.json`, start the emulators, and run.
Android emulators reach your host machine at `10.0.2.2`, which is already
allow-listed for cleartext in the debug network-security config.

```bash
cd functions && npm run serve      # functions + firestore + auth emulators
# in another terminal:
flutter run --dart-define-from-file=dart_defines.json
```

App Check on a physical debug device needs a debug token: run once, copy the
token the console logs print, register it in *Firebase console → App Check →
Apps → (your app) → Manage debug tokens*, and optionally set it as
`APP_CHECK_DEBUG_TOKEN` in `dart_defines.json`.

---

## 8. Troubleshooting

**`Could not find google-services.json` / Firebase calls hang.** The file isn't
at `android/app/google-services.json`, or its `package_name` isn't
`com.rankrush.app`. Re-download from the console.

**Google Sign-In returns `ApiException: 10` (DEVELOPER_ERROR).** The current
signing key's SHA-1 isn't registered in Firebase, or you didn't re-download
`google-services.json` after adding it. Also confirm an OAuth **web** client
(`client_type: 3`) exists in the file — it's what Android Sign-In uses.

**`Duplicate class` / dependency version clashes.** Let the FlutterFire plugins
manage Firebase versions; don't add manual `com.google.firebase:*` lines to
`app/build.gradle`. Run `flutter clean && flutter pub get`.

**`minSdkVersion` conflict.** A plugin requires a higher floor than 23. Raise
`minSdk` in `android/app/build.gradle` to match the message.

**R8 stripped something at runtime (release only).** Add a `-keep` rule to
`android/app/proguard-rules.pro` for the affected class, then rebuild. To
confirm R8 is the cause, temporarily set `minifyEnabled = false`.

**NDK download is slow/fails.** The build pins NDK `27.0.12077973`; Gradle
fetches it once. Ensure the Android SDK's `ndk` and `cmake` components are
installed via Android Studio's SDK Manager if the auto-download is blocked.

**Build succeeds but crashes on launch with a config error screen.** That's the
intended `_ConfigNeededApp` fallback — you built without
`--dart-define-from-file=dart_defines.json`, so `FIREBASE_PROJECT_ID` is empty.

---

## 9. What's in `android/`

```
android/
├─ app/
│  ├─ build.gradle              # applicationId, signing, R8, conditional Firebase plugins
│  ├─ google-services.json      # YOU add this (git-ignored); .example provided
│  ├─ proguard-rules.pro        # release keep-rules for Flutter + Firebase
│  └─ src/
│     ├─ main/
│     │  ├─ AndroidManifest.xml  # perms, launcher activity, FCM channel
│     │  ├─ kotlin/com/rankrush/app/MainActivity.kt
│     │  └─ res/                 # themes, colors, launch screen, adaptive icons
│     ├─ debug/AndroidManifest.xml    # INTERNET + emulator cleartext
│     └─ profile/AndroidManifest.xml
├─ build.gradle                 # repositories, shared build dir
├─ settings.gradle              # plugin versions (AGP, Kotlin, google-services)
├─ gradle.properties            # AndroidX, JVM args, caching
├─ gradle/wrapper/gradle-wrapper.properties   # pins Gradle 8.10.2
├─ gradlew / gradlew.bat        # wrapper scripts (jar injected by Flutter)
├─ key.properties.example       # release-signing template (copy → key.properties)
└─ .gitignore
```

Everything a normal `flutter create` would produce is here, pre-wired for this
project's Firebase stack — you only add project-specific secrets, which stay out
of source control by design.
