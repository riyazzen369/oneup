# Front end

Flutter app in this repo. Version `0.3.0+28`. Built against **Flutter 3.24.5** (Dart 3.5.4). `pubspec.yaml` allows Dart `>=3.4.0 <4.0.0`. Codemagic pins `flutter: 3.24.5`.

## Tech stack (declared → resolved in `pubspec.lock`)

| Package | Constraint | Locked |
|---------|------------|--------|
| flutter_riverpod | ^2.5.1 | 2.6.1 |
| go_router | ^14.2.0 | 14.8.1 |
| supabase_flutter | ^2.12.0 | 2.15.4 |
| flutter_secure_storage | ^9.2.2 | 9.2.4 |
| google_fonts | ^6.2.1 | 6.3.0 |
| cryptography | ^2.7.0 | 2.9.0 |
| url_launcher | ^6.3.0 | 6.3.1 |
| image_picker | ^1.1.2 | 1.1.2 |
| image | ^4.2.0 | 4.12.0 |
| flutter_displaymode | ^0.6.0 | 0.6.0 |
| flutter_local_notifications | ^17.2.4 | 17.2.4 |
| timezone | ^0.9.4 | 0.9.4 |
| share_plus | ^10.1.4 | 10.1.4 |
| flutter_lints (dev) | ^4.0.0 | 4.0.0 |

`dependency_overrides`: `app_links: 6.3.3` (comment in `pubspec.yaml`: 6.4+ needs a newer Flutter Gradle plugin than 3.24.5).

Material 3, Impeller enabled on Android (`EnableImpeller=true` in the manifest). 120 Hz: `flutter_displaymode` on Android (guarded; skipped on web); iOS `CADisableMinimumFrameDurationOnPhone`.

## Folder and architecture map

```
lib/
  main.dart                      entry, optional Supabase init, ritual notification tap, PhoneFrame on web
  core/
    config/env.dart              dart-define keys (names only)
    router/app_router.dart       all routes; StatefulShellRoute tabs
    safety/                      crisis_detector, crisis_screen, safety_state
    services/                    auth_service, secure_store, settings_service, haptics
    theme/                       app_colors, app_theme, motion
    widgets/                     fx, gradient_background, logos, phone_frame
  features/
    splash/ onboarding/ auth/ profile_setup/ consent/   first-run
    shell/main_shell.dart        6-tab bar
    home/                        wheel, band, continue to assess, ritual / quick-check entry
    assess/                      question bank, scoring, drafts, history, focus
    results/                     results, dimension detail, radar, focus, trends
    games/                       catalogue + 16 game screens
    learn/                       lesson list + reader
    articles/                    updates & articles
    market/                      SAMPLE market, cart, demo checkout
    consult/                     SAMPLE consultants, booking, demo payment, call UI
    companion/                   offline responder + Edge Function client
    profile/                     profile, edit, delete-my-data, about
    quick/ ritual/ activity/ report/ plus/ privacy/ experts/ org/ referral/
assets/
  images/stellarone_logo.png
  companion/spec.json
  content/learn.json             50 lessons, 9 books
  content/articles.json          20 articles
test/                            widget, unit, flow and preview tests
tool/                            gen_ios_icons.py, gen_learn.py, lessons/
```

Usual feature pattern: `data/` (models, repositories, storage) → `domain/` (pure logic, Riverpod controllers) → `ui/` (screens). Keep business logic out of widgets. Not every feature is split into all three folders (some later Phase 3 features live in one or two files).

## State management

**Riverpod** throughout. `main.dart` creates a `ProviderContainer`, wraps the app in `UncontrolledProviderScope`, and registers the ritual/report notification callback on that container (it sets `pendingRitualPopupProvider` or `pendingReportProvider` and `go`es to Home).

Notable providers:

- `routerProvider` — `GoRouter`
- `authServiceProvider`, `secureStoreProvider`, `themeModeProvider`, `hapticsProvider`
- Assessment history / scores / focus via `assessment_controller.dart`
- `isPlusProvider` and entitlement in `lib/features/plus/entitlement.dart`
- Ritual, report, org, referral, privacy, quick-check providers in their feature files

On-device secrets and user data go through `flutter_secure_storage` (`SecureStore`). Assessment answers are encrypted with **AES-GCM** (`lib/features/assess/data/answer_crypto.dart`) before storage. AAD for answers is `assessmentId:questionId`.

## Navigation and screens

`go_router` 14. `MaterialApp.router` in `lib/main.dart`. Initial route `/` (splash). `errorBuilder` shows `NotFoundScreen`.

**First-run (stack routes):** `/` splash → `/onboarding` → `/login` → `/otp` → `/profile-setup` → `/consent`.

**Main shell** (`StatefulShellRoute.indexedStack`) — six tabs:

| Tab | Path | Screen |
|-----|------|--------|
| Home | `/home` | `HomePage` |
| Games | `/games` | `GamesPage` |
| Learn | `/learn` | `LearnPage` |
| Market | `/market` | `MarketPage` |
| Consult | `/consult` | `ConsultPage` |
| Profile | `/profile` | `ProfilePage` |

Assess is **not** a tab; it is pushed from Home (`/assess`, `/assess/q/:dim`, `/assess/done/:dim`).

**Other stack routes (non-exhaustive):** `/results`, `/results/dim/:dim`, `/circle`, `/focus`, `/trends`, `/quick`, `/quick/result`, `/report`, `/reports`, `/plus`, `/invite`, `/privacy`, `/experts`, `/org`, `/org/join`, `/org/demo`, `/coaching`, `/support`, `/learn/:id`, `/articles`, `/companion`, `/crisis`, `/about`, `/profile/edit`, `/games/:id`, market product/cart/checkout/orders/wishlist, consult profile/book/pay/done/sessions/call.

Plus-gated example: `/consult/book/:id` shows `PlusLockCard` when `isPlusProvider` is false. Crisis help is not gated.

## Theme and design tokens

Source of truth is the Dart theme, not a separate token file. See also [design.md](design.md).

**Brand (`lib/core/theme/app_colors.dart`):**

| Token | Value |
|-------|-------|
| primary | `#5B4BF5` |
| secondary | `#16C2B0` |
| accent | `#FF6B8B` |
| lightBg | `#F6F7FB` |
| darkBg | `#0E1020` |
| darkSurface | `#181B30` |
| brandGradient | primary → `#8E5BF5` → secondary |

**Eight dimension colours (light / dark):**

| Dimension | Light | Dark |
|-----------|-------|------|
| Emotional | `#E5487A` | `#FF7AA2` |
| Physical | `#1E88E5` | `#64B5F6` |
| Occupational | `#F57C00` | `#FFB74D` |
| Social | `#00897B` | `#4DD0C1` |
| Spiritual | `#7E57C2` | `#B39DDB` |
| Intellectual | `#C79100` | `#FFD54F` |
| Environmental | `#43A047` | `#81C784` |
| Financial | `#3949AB` | `#8C9EFF` |

**OneUP Plus neon (`lib/features/plus/plus_ui.dart`):**

| Token | Value | Use |
|-------|-------|-----|
| plusLime | `#C6FF00` | fluorescent lime |
| plusCyan | `#00F0FF` | neon cyan |
| plusInk | `#07140F` | text/icons on neon |
| plusGradient | lime → cyan | frames, hero, pills |
| plusOn (light) | `#00796B` | readable neon on light surfaces |
| plusOn (dark) | plusLime | readable neon on dark surfaces |
| Plus hero wash | `#0B0F1C`, `#0F2A2E`, `#1A2B05` | dark hero so neon reads in both themes |

Plus buttons and frames use a 1.6 px gradient border, corner radius 20 by default, and a lime/cyan glow.

**Typography:** `GoogleFonts.poppinsTextTheme` on both light and dark (`lib/core/theme/app_theme.dart`).

**Shape and spacing:**

- `AppTheme.radius = 20` for cards
- Inputs: 16 px radius, padding 18 × 16
- Filled/outlined buttons: height 54 (≥ 48 dp touch target), 16 px radius, filled label 16 / w600
- Text scaler clamped 0.85–1.6 in `main.dart`

**Motion:** fade-through + scale (0.94 → 1) page transitions on Android and iOS (`lib/core/theme/motion.dart`). `OneUpScrollBehavior`: bouncing physics; mouse and trackpad can drag-scroll (web showcase).

## Assets

Declared in `pubspec.yaml`: `assets/images/`, `assets/companion/`, `assets/content/`.

- `assets/images/stellarone_logo.png` — StellarOne mark (earlier README noted a formal logo drop-in if a newer official file is supplied)
- `assets/companion/spec.json` — companion behaviour spec (also bundled into the Edge Function)
- `assets/content/learn.json` — 50 lessons, 9 books, version 2, plus disclaimer notes
- `assets/content/articles.json` — 20 curated article records

Logos in the UI are also painted in code: `lib/core/widgets/oneup_logo.dart`, `stellar_agents_logo.dart`.

There is no screenshot folder in the git tree. `test/preview/*_preview_test.dart` files exist for visual checks; they are tests, not checked-in PNGs.

## Web showcase build

`web/` is present (`index.html`, `manifest.json`, icons, favicon). On web, `main.dart` wraps the app in `PhoneFrame` (`lib/core/widgets/phone_frame.dart`):

- Viewport width **< 600**: full-width (phone browser)
- Wider: app sits in a 390×844 phone chrome (height clamped) on a `#1C1D22` backdrop, 10 px `#3A3B42` bezel, 44 px outer corner radius

```bash
flutter run -d chrome                 # demo
flutter build web --release           # output: build/web/
# optional, with backend keys from the gitignored file:
flutter build web --release --dart-define-from-file=env.json
```

`build/` is gitignored. Deploy notes: [deploy.md](deploy.md).

## How to run (front end)

```bash
flutter pub get
flutter run                           # picks a connected device / emulator; demo mode
flutter run -d chrome
flutter run --dart-define-from-file=env.json
```

iOS needs a Mac or Codemagic (see [deploy.md](deploy.md)). Android minSdk is **23**. iOS minimum is **13.0**.

**Windows:** this repo does not contain a `windows/` platform tree. Do not assume `flutter run -d windows` works until someone adds the platform with `flutter create . --platforms=windows` and verifies plugins (secure storage, local notifications, etc.). That is new work, not part of the current app.

## Assessment scoring (do not change without sign-off)

From `lib/features/assess/domain/scoring.dart` and the question bank:

- Per dimension: 8 scored Likert items (1–5) + 1 open-text reflection (not scored)
- Reverse-scored items: `v' = 6 − v`
- `S` = sum of the 8 scored items (8–40)
- `score = round((S − 8) / 32 × 100)`
- Bands: 0–40 Needs Attention, 41–70 Developing, 71–100 Thriving
- Overall = average of all 8 dimension scores, only when all 8 are done
- Each attempt is a new history row (never overwrite)
- OneUP Focus: Needs Attention first → biggest gap to goal (default target 71) → lowest score → wheel order
- Reflection text is checked by `crisis_detector.dart`; a match opens `/crisis`

Quick Check maps a 1–10 slider to 0–100 (`1 → 0`, `10 → 100`) and **must not** be mixed into deep-dive history.
