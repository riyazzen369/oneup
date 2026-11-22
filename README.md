# OneUP

Wellness-awareness app from **StellarOne Healthcare Pvt Ltd** (credit on splash: “Created by Stellar Agents”).

OneUP helps people check, understand and improve balance across **eight dimensions**: Emotional, Physical, Occupational, Social, Spiritual, Intellectual, Environmental, Financial.

Current app version: **0.3.0+28**. Flutter + Supabase (optional). Package / bundle ID: `in.stellarone.oneup`.

> OneUp is for wellness awareness, not medical diagnosis.

**Full developer handover** (front end, back end, design, deploy, access): [HANDOVER.md](HANDOVER.md).  
Assistant brief: [CLAUDE.md](CLAUDE.md). iOS / TestFlight steps: [IOS_SETUP.md](IOS_SETUP.md).

## Quick start

You need [Flutter 3.24.5](https://docs.flutter.dev/release/archive) (Dart 3.5.4). The project SDK constraint is `>=3.4.0 <4.0.0`.

```bash
git clone https://github.com/riyazzen369/oneup.git
cd oneup
flutter pub get
flutter run                 # demo mode — any 10-digit number, OTP 123456, data stays on this device
flutter analyze
flutter test
```

Supported in this repo: **Android**, **iOS**, and **web** (`flutter run -d chrome`). Windows / macOS / Linux platform folders are not present.

### Optional: real Supabase keys (local only)

```bash
cp env.example.json env.json   # fill in values; env.json is gitignored
flutter run --dart-define-from-file=env.json
```

Variable **names** (never commit values): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`.  
You can still pass them as `--dart-define=NAME=...` if you prefer. With empty or missing keys the app stays in demo mode.

### VS Code / Cursor

Open this folder, install the recommended **Dart** and **Flutter** extensions (`.vscode/extensions.json`), then launch **OneUP (demo)** or **OneUP (from env.json)**. Copy `env.example.json` to `env.json` first if you use the second config. CLI commands above keep working unchanged.

## What is in this tree (short)

- Full assessment (72 original questions, encrypted answers, Wellness Wheel, Focus, Trends)
- 16 games, 50 Learn lessons, articles, offline Companion with a crisis path
- OneUP Plus, Privacy Center, daily ritual, weekly report, quick check, referral and B2B demos — see the status table in [HANDOVER.md](HANDOVER.md)
- Marketplace, consult booking, Plus purchases and several Phase 3 services are **SAMPLE / demo only** (no real payments)

## Android signing

Release builds read `android/key.properties` (gitignored) for `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. The keystore is held privately and must never be committed. See [docs/handover/deploy.md](docs/handover/deploy.md).

## iOS / TestFlight

Codemagic workflow `ios-testflight` in `codemagic.yaml` builds on push to `main` and can upload to TestFlight. You still need to set `APP_STORE_APPLE_ID` and the Codemagic signing group `app_store_credentials`. Follow [IOS_SETUP.md](IOS_SETUP.md).

## Web

```bash
flutter build web --release    # output: build/web/
```

There is no Netlify (or other host) config in this repo yet. Wide screens show the app in a phone frame. Details: [docs/handover/deploy.md](docs/handover/deploy.md).
