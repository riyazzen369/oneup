# OneUP — Developer handover

This is the starting point for continuing the OneUP build in VS Code or Claude Code.

**App version (do not bump as part of this handover):** `0.3.0+28` in `pubspec.yaml`.  
**Repo:** https://github.com/riyazzen369/oneup (public, default branch `main`).  
**Package / bundle ID:** `in.stellarone.oneup`.  
**Owner:** StellarOne Healthcare Pvt Ltd (splash credit: "Created by Stellar Agents").

> OneUp is for wellness awareness, not medical diagnosis.

The product is a Flutter wellness-awareness app across **eight dimensions**: Emotional, Physical, Occupational, Social, Spiritual, Intellectual, Environmental, Financial.

Core loop: **Assess → results (Wellness Wheel, Circle Paradigm radar) → OneUP Focus → Learn / Games / Market / Consult → reassess and watch Trends.**  
**OneUP Plus** is a freemium layer. Purchases, coaching, consultation booking and marketplace checkout in this tree are **demo / SAMPLE only** — no real payments.

This handover covers front end, back end, design, deploy and access. Read the area notes next:

| Area | File |
|------|------|
| Front end | [docs/handover/frontend.md](docs/handover/frontend.md) |
| Back end | [docs/handover/backend.md](docs/handover/backend.md) |
| Design | [docs/handover/design.md](docs/handover/design.md) |
| Deploy | [docs/handover/deploy.md](docs/handover/deploy.md) |
| Access | [docs/handover/access.md](docs/handover/access.md) |

Related files already in the repo:

- [CLAUDE.md](CLAUDE.md) — concise brief and conventions for Claude Code (and other assistants)
- [IOS_SETUP.md](IOS_SETUP.md) — step-by-step Apple Developer + Codemagic → TestFlight. Early “create the GitHub repo” steps are already done; the Apple/Codemagic steps still apply
- [codemagic.yaml](codemagic.yaml) — iOS TestFlight and optional Android APK workflows
- [README.md](README.md) — quick start

## Quick start

```bash
# Flutter 3.24.5 / Dart 3.5.4 is what this project was built and CI-pinned with (Dart SDK constraint: >=3.4.0 <4.0.0).
flutter pub get
flutter run                 # demo mode: any 10-digit number, OTP 123456, data stays on device
flutter analyze
flutter test
```

Optional real backend (names only — never commit values):

```bash
cp env.example.json env.json   # then fill values locally; env.json is gitignored
flutter run --dart-define-from-file=env.json
```

VS Code: open the repo folder, install the recommended Dart and Flutter extensions, then use the **OneUP (demo)** or **OneUP (from env.json)** launch configs. Existing CLI commands are unchanged.

**Platforms in this repo:** Android, iOS, web. There is no `windows/`, `macos/` or `linux/` folder. Desktop Windows is not set up or tested here.

## Feature status (as implemented in this tree)

### Done (works in demo mode, on-device)

| Area | What is in the code |
|------|---------------------|
| First-run | Splash, onboarding, phone OTP (demo), profile setup, consent |
| Assessment | 72 original questions (8 scored Likert + 1 open reflection per dimension), AES-GCM encryption, scoring, drafts, history, OneUP Focus |
| Results | Wellness Wheel, dimension detail, Circle Paradigm radar, Trends & Goals, Home band + one-liner |
| Games | 16 custom arcade games (2 per dimension), custom engine (Ticker + CustomPainter, no Flame) |
| Learn | 50 bundled lessons from 9 books (`assets/content/learn.json`), book-style reader |
| Articles | 20 bundled articles (`assets/content/articles.json`) |
| Companion | Rule-based offline responder; crisis detector → `/crisis` helpline screen |
| Profile | View/edit, theme, haptics, about, delete-my-data (local; also calls `delete_my_data` RPC when Supabase is configured) |
| Quick Check (#1) | 60-second estimate (one 1–10 rating per dimension), stored separately from the deep-dive history |
| Daily ritual (#2) | Today card: mood, micro-task, streak, 7-day strip, local reminder notification, pop-up |
| Living wheel (#3) | Activity glow/growth, pulse, “+1” badge, 7-day decay, encrypted activity log |
| Weekly report card (#6) | Story pages, Sunday reminder, private share, 8-week encrypted history |
| Privacy Center (#16) | Inventory of on-device data, export, delete-all, private-by-design badge |
| Web showcase | `PhoneFrame` on wide viewports (390×844), mouse/trackpad drag-scroll |

### Demo / SAMPLE placeholders (UI exists; not production)

| Area | What is still fake or local-only |
|------|----------------------------------|
| Auth | Demo OTP `123456` when keys are empty. Google sign-in throws in demo mode. Android and iOS both declare the `in.stellarone.oneup://login-callback` scheme (Android not yet tested on a device) |
| OneUP Plus (#9) | Local encrypted entitlement, 7-day trial, SAMPLE prices (₹149/month, ₹1,299/year, both `[VERIFY]`). No billing SDK |
| Plus services (#9b) | SAMPLE expert consultation, 1-on-1 coaching, “Picked for you”, reports dashboard, priority support. Requests stay on device. Crisis help stays free |
| Marketplace | SAMPLE catalogue, cart, wishlist, **demo checkout only** (no payment). Consult-only “medicines” are not sold directly |
| Consult | SAMPLE consultants, demo booking/payment, call screen is a UI shell (round icons respond to taps; not a real call) |
| Experts (#15) | SAMPLE advisory board, methodology, “Reviewed-by” badges, local “Report an issue”. Not real people or credentials |
| B2B / org (#10) | Demo join via code `STELLAR-DEMO`, k=5 anonymous dashboard, book-a-demo form — all local, SAMPLE data |
| Referral (#17) | Invite codes (`ONEUP-XXXX`) created and checked on-device only; friend joins are simulated |
| Supabase | Client code and SQL migrations exist. They are **not applied to a live project** in this handover (see backend note) |
| Companion AI | Edge Function source is in the repo; the app falls back to the offline responder unless Supabase is configured and the user is signed in |

### Not started / not in this repo

- Real payment gateway (for example Razorpay) and a real catalogue/orders backend
- Real consultant onboarding, verification, scheduling, or video calls
- Analytics, crash reporting, push notifications (beyond local ritual/report reminders)
- Accessibility audit, localisation (Hindi and regional languages)
- App Store / Play Store listings and production signing accounts wired up
- Windows / macOS / Linux desktop targets
- Firebase is not used
- A Figma or Canva design source for the app was not found (see design note)
- Netlify site config is not in this repo (see deploy note)
- `APP_STORE_APPLE_ID` in `codemagic.yaml` is still the placeholder `0000000000`

## Known issues and tech debt

- **Migrations not applied.** Comments in the SQL and project brief say the schema has not been applied to a live Supabase project. The connected Supabase account visible during this handover listed no projects, so a live schema could not be exported.
- **Marketplace schema drift: fixed in the repo.** Unused UUID `products` / `wishlist` / `cart_items` / `order_items` were removed from `init`; `products` is defined once in the market migration (see [backend.md](docs/handover/backend.md)). Still open: `products` has no seed rows, so the cart guard does nothing until seeded; untested on a real Supabase project.
- **Android deep link untested.** Google / Supabase auth redirect is `in.stellarone.oneup://login-callback`. Both platforms now declare it (Android intent-filter on `MainActivity`); verify on a device once Supabase is live.
- **`GOOGLE_WEB_CLIENT_ID`** is read in `lib/core/config/env.dart` but not referenced elsewhere in Dart. Codemagic still passes it as an empty dart-define.
- **Call screen** is a demo UI only.
- **README** (before this handover) still described an early “Module 1” scope; this document and the refreshed README are the current picture.
- **`android/.gitignore`** ignores `gradlew`, `gradlew.bat` and `gradle-wrapper.jar`. Those files exist locally but are not in git (Flutter template default here). CI uses the Flutter tool to build, so this has worked, but a raw Gradle-only checkout would be incomplete.
- **Demo Android keystore** is for sideload/demo APKs only (`android/app/build.gradle` comment: not for Play Store). Sir holds the keystore privately; it must never be committed.
- Open `[VERIFY]` items in copy and content: Wellness 8 book details, *The Art of Persuasion* book choice (Bob Burg, 2011 assumed), Eco Sort waste rules, Tele-MANAS / crisis keyword list, Plus prices, DPDP consent wording, expert credentials, org legal review.

## Suggested next steps toward production

1. Sir grants the new developer the access listed in [docs/handover/access.md](docs/handover/access.md). This handover does not invite anyone or change permissions.
2. Create (or share) a Supabase project, review RLS (and seed `products` if you want server-side consult-only enforcement), apply `supabase/migrations/*`, deploy the `companion` Edge Function, and enable Phone + Google auth. Register the `in.stellarone.oneup://login-callback` redirect URL in Supabase and test Google sign-in on an Android device.
3. Replace demo Plus billing, market checkout and consult payments with a real gateway; keep crisis help free.
4. Replace SAMPLE consultants, coaches, experts and products with real, consented data. Run psychologist / therapist review of the question bank and lessons.
5. Fill `APP_STORE_APPLE_ID`, complete Codemagic signing, and cut a TestFlight build. Decide a Play Store keystore (not the demo key) if Android is going to Play.
6. Confirm whether a Netlify (or other) web site already exists; add `netlify.toml` (or equivalent) to the repo once the site name and build settings are agreed. See [docs/handover/deploy.md](docs/handover/deploy.md).
7. Analytics, crash reporting, accessibility, localisation, and a DPDP Act 2023 privacy review `[VERIFY]` with legal counsel.

## How to work

- Small, focused changes. Run `flutter analyze` and `flutter test` before each commit.
- Add or adjust tests for scoring, focus, safety or storage changes.
- Do not change the assessment scoring formula without product-owner sign-off.
- Never commit secrets: keystores, `key.properties`, `env.json`, `.p8`, `.env*`, APKs, `google-services.json`, `GoogleService-Info.plist`.
- No medical diagnosis or treatment advice in UI, companion or lessons. Mark unverified claims `[VERIFY]`.
