# OneUp — Module 1 (by StellarOne Healthcare Pvt Ltd)

Flutter + Supabase. Scope: scaffold, theme, splash, onboarding, phone OTP + Google sign-in,
profile setup, consent, 5-tab shell with placeholder pages, full DB migration with RLS.

## Run
```
flutter create . --platforms=android,ios --org in.stellarone   # generates native folders
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
```
Supabase: enable Phone (SMS provider) and Google auth providers; add redirect
`in.stellarone.oneup://login-callback` and register that deep-link scheme in Android/iOS.
Apply `supabase/migrations/*.sql` with `supabase db push`.

> OneUp is for wellness awareness, not medical diagnosis.

## Open items
- StellarOne official logo: not available from stellaragents.in — drop it in `assets/images/stellarone_logo.png`.
- Consent wording vs DPDP Act 2023: [VERIFY] with legal counsel.

## Module 2 — Assessment
- 72 original items in `lib/features/assess/data/question_bank.dart` (local fallback) and
  `supabase/migrations/20261021010000_seed_questions.sql` (same deterministic IDs).
- Answers encrypted with AES-256-GCM (key in flutter_secure_storage); AAD = `assessmentId:questionId`.
- Scoring: v' = 6 − v (reverse), S = Σv', score = round((S − 8) / 32 × 100) over 8 scored items; item 9 is an unscored open-text reflection. Bands 0–40 Needs Attention / 41–70 Developing / 71–100 Thriving.

## Module 3 — Results
- Each dimension attempt is its own `assessments` row (redo one dimension without losing history).
- History + goals are cached in secure storage and merged from Supabase on launch / pull-to-refresh.
- Wheel, radar and line charts are CustomPainters (no chart dependency).

## OneUp Companion
- Spec: `assets/companion/spec.json` (also bundled into the edge function).
- Demo/offline: rule-based responder in `lib/features/companion/domain/offline_responder.dart`.
- App-side crisis layer: `lib/core/safety/crisis_detector.dart` → full-screen helpline card (`/crisis`).

### Deploy the edge function
```
supabase link --project-ref <ref>
supabase db push                                   # applies migrations incl. companion_flags
supabase secrets set AI_API_KEY=... AI_BASE_URL=https://<provider>/v1 AI_MODEL=<model>
supabase functions deploy companion                # JWT verification stays ON (default)
```
The app calls it via `supabase.functions.invoke('companion')` only when built with
`--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` and the user is signed in.
