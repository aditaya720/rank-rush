# How to get an installable APK

An APK has to be **compiled** by an Android/Flutter toolchain — it isn't a file
that can be handed over pre-made from this repo, because a real build must be
signed with *your* key and wired to *your* Firebase project. Below are three
ways to produce one, fastest first. All three run the exact same command under
the hood:

```bash
flutter build apk --release --dart-define-from-file=dart_defines.json
```

| Route | Local setup needed | Gets you |
|-------|--------------------|----------|
| **A. GitHub Actions** | none (runs in the cloud) | debug APK on every push; signed release on demand |
| **B. Codemagic** | none (runs in the cloud) | debug or signed release APK + AAB |
| **C. Local machine** | Flutter 3.27+, JDK 17, Android SDK | full control, fastest iteration |

> **You can get a working APK with _zero_ secrets** via route A or C — it just
> shows a "configuration needed" screen at launch until you add your Firebase
> config, because the app refuses to ship hard-coded keys. Add the secrets when
> you want a fully functional, signed build.

---

## Route A — GitHub Actions (no local setup)

The workflow is already in the repo at `.github/workflows/android-build.yml`.

### A1. Debug APK (no secrets)

1. Push this project to a GitHub repo (the `pubspec.yaml` must be at the repo
   root).
2. Open the **Actions** tab → the **Android build** workflow runs automatically
   on the push.
3. When it finishes, open the run and download the **`rank-rush-debug-apk`**
   artifact. Unzip it → `app-debug.apk` → copy to your phone and install
   (enable "Install unknown apps" for your file manager).

That APK is installable immediately. It talks to Firebase only once you add the
config in the next step.

### A2. Signed release APK + AAB (with secrets)

Add these repository secrets under **Settings → Secrets and variables → Actions
→ New repository secret**, then run the workflow manually (**Actions → Android
build → Run workflow → tick "Also build a signed release"**):

| Secret | What it is | How to produce it |
|--------|-----------|-------------------|
| `GOOGLE_SERVICES_JSON` | base64 of `android/app/google-services.json` | `base64 -w0 google-services.json` |
| `DART_DEFINES_JSON` | base64 of your filled-in `dart_defines.json` | `base64 -w0 dart_defines.json` |
| `KEYSTORE_BASE64` | base64 of your release `.jks` | `base64 -w0 rank-rush-release.jks` |
| `STORE_PASSWORD` | keystore store password | (what you chose with `keytool`) |
| `KEY_PASSWORD` | key password | (what you chose with `keytool`) |
| `KEY_ALIAS` | key alias | e.g. `rank-rush` |

The signed **`rank-rush-release`** artifact then contains `app-release.apk`
(sideload) and `app-release.aab` (upload to Google Play).

> **base64 tips.** On macOS use `base64 -i google-services.json | pbcopy`
> (no `-w0`). On Windows PowerShell:
> `[Convert]::ToBase64String([IO.File]::ReadAllBytes("google-services.json"))`.
> Paste the single-line result as the secret value.

---

## Route B — Codemagic (no local setup)

The config is already in the repo at `codemagic.yaml`.

1. Sign in at [codemagic.io](https://codemagic.io) and add your repository.
2. **Debug:** run the **`android-debug`** workflow — no secrets required — and
   download the APK artifact.
3. **Signed release:** in the Codemagic UI create an environment-variable group
   named **`rankrush`** (mark every entry *secure*) with the same six variables
   as the table above (`GOOGLE_SERVICES_JSON`, `DART_DEFINES_JSON`,
   `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`), then run
   the **`android-release`** workflow. Artifacts: `app-release.apk` +
   `app-release.aab`.

---

## Route C — Local machine (full control)

Prerequisites: **Flutter 3.27+**, **JDK 17**, the **Android SDK** (Android
Studio is the easiest way to get it). Verify with `flutter doctor`.

```bash
# 1. from the project root
flutter pub get

# 2. add your Firebase config (see docs/ANDROID_BUILD.md §2)
#    → android/app/google-services.json

# 3. fill in build-time config
cp dart_defines.example.json dart_defines.json     # then edit values

# 4a. quick debug build (installable, no keystore needed)
flutter build apk --debug --dart-define-from-file=dart_defines.json
#    → build/app/outputs/flutter-apk/app-debug.apk

# 4b. signed release build (needs a keystore + android/key.properties,
#     see docs/ANDROID_BUILD.md §4)
flutter build apk --release --dart-define-from-file=dart_defines.json
#    → build/app/outputs/flutter-apk/app-release.apk

# 5. install straight to a plugged-in phone (USB debugging on)
flutter install --release
```

The complete keystore / Firebase / SHA-fingerprint walkthrough is in
[`ANDROID_BUILD.md`](ANDROID_BUILD.md).

---

## Which should I pick?

- **Just want an APK on your phone right now, no tooling?** Route A1 (push →
  download the debug artifact).
- **Publishing to Google Play?** Route A2 or B for the signed `.aab`.
- **Actively developing / debugging?** Route C — instant rebuilds and hot
  reload.

Whichever route you use, the build is signed with **your** key and points at
**your** Firebase project — nobody can hand you a pre-built Rank Rush APK that is
both functional and safely signed, which is exactly why these routes exist.
