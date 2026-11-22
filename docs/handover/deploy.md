# Deploy

## Tooling baseline

- Flutter **3.24.5** (Codemagic workflows pin this; local dev should match)
- Dart **3.5.4** on that Flutter channel (`pubspec` SDK: `>=3.4.0 <4.0.0`)
- Android `applicationId` / iOS bundle: `in.stellarone.oneup`
- App version: `0.3.0+28` (`versionName` / `FLUTTER_BUILD_NAME` + `versionCode` / `FLUTTER_BUILD_NUMBER`)
- Android `minSdk` 23, Java 8, core library desugaring (for `flutter_local_notifications`)
- iOS 13.0 minimum (`Podfile` and Xcode project)
- CI: `codemagic.yaml` at the repo root

Supabase keys in CI builds are intentionally **empty**, so shipped CI artefacts run in demo mode unless someone changes that on purpose.

## Android (APK / AAB) and signing

Local release signing is in `android/app/build.gradle`. If `android/key.properties` exists, the release build type uses the `release` signing config; otherwise it falls back to the debug key.

`key.properties` **must stay local** (already gitignored). Expected **key names** (never commit values):

```
storeFile
storePassword
keyAlias
keyPassword
```

The keystore file itself (`*.jks` / `*.keystore`) is gitignored. Sir holds the keystore privately. This tree’s Gradle comment describes a self-generated **demo** key, not a Play Store upload key. Do not commit the store or the properties file. Do not put passwords in chat or in this repo.

```bash
# Debug / run
flutter run

# Release APK (needs key.properties + keystore locally for a signed release)
flutter build apk --release --target-platform android-arm64

# App bundle (Play Store), when you are ready
flutter build appbundle --release
```

Optional backend defines: add `--dart-define-from-file=env.json` or individual `--dart-define` flags. Outputs land under `build/` (gitignored). `*.apk` is also gitignored.

**Google Play Console:** there is no Play listing, `play/` metadata, or upload-key documentation in this repo. Publishing to Play is not set up here. If it happens later, use a dedicated upload keystore (not the demo key) and keep it out of git.

**Codemagic Android (optional workflow `android-apk`):**

- Triggers on **tags**, not on every push
- Flutter 3.24.5, Java 17
- Signing: upload the keystore in Codemagic → Code signing identities → Android keystores, reference name **`oneup_keystore`**
- The workflow writes `android/key.properties` on the builder from Codemagic variables `CM_KEYSTORE_PASSWORD`, `CM_KEY_PASSWORD`, `CM_KEY_ALIAS`, `CM_KEYSTORE_PATH` (provided by that integration — do not put those values in yaml)
- Command: `flutter build apk --release --target-platform android-arm64` with empty dart-defines

## iOS via Codemagic → TestFlight

You do not need a Mac for a TestFlight build. Details and Apple UI steps: [IOS_SETUP.md](../../IOS_SETUP.md). Note: that file still contains early “create the GitHub repo” instructions; the repo **already exists**.

**Workflow:** `ios-testflight` in `codemagic.yaml`  
**Trigger:** push to `main` (previous builds cancelled)  
**Machine:** `mac_mini_m2`, Flutter 3.24.5, latest Xcode  
**Bundle ID:** `in.stellarone.oneup`  
**Build number:** latest TestFlight number + 1 (`app-store-connect get-latest-testflight-build-number`)  
**Steps:** `flutter pub get` → `flutter analyze` + `flutter test` → `pod install` → `xcode-project use-profiles` → `flutter build ipa --release` with empty dart-defines → publish to TestFlight (`submit_to_testflight: true`, `submit_to_app_store: false`)

**Codemagic environment group (name only):** `app_store_credentials`  
Variables in that group (mark Secure in the Codemagic UI; **values must never be committed**):

- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_IDENTIFIER`
- `APP_STORE_CONNECT_PRIVATE_KEY` (full contents of the App Store Connect API `.p8`)

Also required in the Codemagic team UI (not in git): Apple Distribution certificate + App Store provisioning profile for `in.stellarone.oneup`.

**Still a placeholder in yaml:** `APP_STORE_APPLE_ID: 0000000000` — replace with the numeric Apple ID from App Store Connect → App Information before a real TestFlight upload will work.

Export compliance: `ITSAppUsesNonExemptEncryption = false` is already set in `Info.plist`.

To regenerate iOS icons: `python3 tool/gen_ios_icons.py` (needs Pillow).

## Web via Netlify

**This repo has no `netlify.toml`, no `_redirects`, and no documented Netlify site name or team.** No Netlify connector was available to inspect a live site during this handover. Do not assume a production URL.

The web app **is** buildable:

```bash
flutter build web --release
# artefacts: build/web/
```

If Sir already has a Netlify site, he should share the **site name** and invite the new developer (see [access.md](access.md)), then add a `netlify.toml` to the repo. A typical Flutter web setup (proposed, not yet in git) is:

- Build command: `flutter build web --release` (the Netlify image must have Flutter 3.24.5, or the command must install it)
- Publish directory: `build/web`
- SPA fallback: redirect all routes to `/index.html` (go_router uses path URLs; a refresh on `/home` will 404 without this)

Until that is agreed and committed, treat Netlify as **intended / to be confirmed**, not as a configured pipeline.

A packaged web build (`OneUP-web-v0.3.0.zip`) may exist as a local artefact on the build machine; it is not in git.

## Other CI

There is no GitHub Actions workflow in this repo. Codemagic is the CI that is actually defined.

`flutter analyze` and `flutter test` run in the iOS TestFlight workflow before the IPA is built.

## Secrets that must never enter git or CI yaml values

- `android/key.properties` and any `.jks` / `.keystore`
- `env.json`, `.env*`, API `.p8` / `.p12`, provisioning profiles
- `google-services.json` / `GoogleService-Info.plist` (not used today; already gitignored)
- Supabase service-role key, DB password, Companion `AI_API_KEY`
- Apple Issuer / Key ID / private key values (use the Codemagic secure group)
