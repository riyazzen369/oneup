# OneUP — project brief for Claude Code (and other assistants)

Read this first, then [HANDOVER.md](HANDOVER.md) for front end, back end, design, deploy and access. This file is conventions and commands, not a second product spec.

## What OneUP is

Wellness-awareness app from **StellarOne Healthcare Pvt Ltd** (splash: “Created by Stellar Agents”). Eight dimensions: Emotional, Physical, Occupational, Social, Spiritual, Intellectual, Environmental, Financial.

Core loop: **Assess → results (Wellness Wheel, Circle Paradigm radar) → OneUP Focus → Learn / Games / Market / Consult → reassess and Trends.**

Mandatory disclaimer: *OneUp is for wellness awareness, not medical diagnosis.*

Version in `pubspec.yaml`: **0.3.0+28**. Do not bump it unless the product owner asks.

## Stack

- Flutter **3.24.5** (Dart `>=3.4.0 <4.0.0`; CI pins 3.24.5), Material 3, Impeller on
- State: flutter_riverpod 2.x — `lib/core/router/app_router.dart` and feature providers
- Navigation: go_router 14, `StatefulShellRoute` tabs: Home · Games · Learn · Market · Consult · Profile
- Backend: optional Supabase. Keys via `--dart-define` or `--dart-define-from-file=env.json` (`lib/core/config/env.dart`). Names only: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`. Empty keys → **demo mode** (any 10-digit phone, OTP `123456`, data on device)
- Security: flutter_secure_storage + `cryptography` AES-GCM (`lib/features/assess/data/answer_crypto.dart`)
- Games: custom Ticker + CustomPainter, no Flame
- IDs: Android / iOS `in.stellarone.oneup`
- CI: `codemagic.yaml` (iOS → TestFlight, optional Android APK)

## Layout

```
lib/main.dart
lib/core/          config, router, safety, services, theme, widgets
lib/features/      one folder per area (assess, results, games, learn, market, consult,
                   companion, profile, plus, privacy, quick, ritual, activity, report,
                   experts, org, referral, …)
assets/content/    learn.json (50 lessons), articles.json
assets/companion/  spec.json
supabase/migrations/   intended schema — not applied to a live project as of this handover
supabase/functions/companion/   Edge Function source (AI keys are server secrets, never in the app)
test/              52 Dart test files (unit, widget, flow, preview)
```

Pattern: `data/` → `domain/` → `ui/` where those folders exist. Keep business logic out of widgets.

## Scoring (do not change without sign-off)

8 scored Likert items (1–5) + 1 open-text reflection per dimension. Reverse items: `v' = 6 − v`.  
`score = round((S − 8) / 32 × 100)` with S in 8–40. Bands: 0–40 Needs Attention, 41–70 Developing, 71–100 Thriving.  
Overall = average of all 8, only when all 8 are done. New history row per attempt.  
Focus: Needs Attention → gap to goal (default 71) → lowest score → wheel order.  
Reflections go through `crisis_detector.dart` → `/crisis`.

## Rules

1. No medical diagnosis or treatment advice (UI, companion, lessons).
2. Never invent medical facts or statistics. Mark unverified material `[VERIFY]`.
3. Products, courses, consultants, Plus prices, experts and org data are **SAMPLE**; checkout and payment are **demo only**. Medicines are consult-first, never sold directly.
4. Questions stay original (not copied from copyrighted scales).
5. Privacy: consent before collection, minimal data, encrypted storage, working delete-my-data, disclaimer before assessment.
6. Crisis safety always wins.
7. Keep animation smooth: `const`, `RepaintBoundary` on animated painters, no heavy work on the UI thread.
8. Never commit secrets: `*.jks`, `key.properties`, `env.json`, `.env*`, `*.p8`, APKs, `google-services.json`, `GoogleService-Info.plist`.

## Commands

```bash
flutter pub get
flutter run                              # demo
flutter run --dart-define-from-file=env.json
flutter run -d chrome
flutter build apk --release --target-platform android-arm64
flutter build web --release
flutter analyze
flutter test
python3 tool/gen_ios_icons.py            # needs Pillow
```

VS Code launch configs live in `.vscode/`. Copy `env.example.json` → `env.json` before the “from env.json” configs. `env.json` is gitignored. Do not add dart-defines that break bare `flutter run`.

There is no `windows/` (or macOS/Linux) platform tree in this repo.

## Production gaps (summary)

Full list: [HANDOVER.md](HANDOVER.md). Highlights: create/share a Supabase project and fix marketplace migration drift before `db push`; test the Android login callback on a device once Supabase is live; replace demo payments and SAMPLE catalogue/consult/Plus; review questions and lessons with qualified people; fill `APP_STORE_APPLE_ID`; confirm or add Netlify (no site config in repo); DPDP / store-policy review `[VERIFY]`.

## How to work

- Small, focused changes. Run `flutter analyze` and `flutter test` before each commit.
- Add or adjust tests for scoring, focus, safety or storage changes.
- Ask the product owner before adding features not already listed in the handover.
