# Back end

OneUP’s backend target is **Supabase** (Auth, Postgres with RLS, Storage, Edge Functions). The Flutter client is in this repo. SQL and the Companion function are also in this repo.

## Live project status

During this handover:

- No Supabase project ref or URL is hardcoded in the app. Keys are injected at build time (see Environment, below).
- The connected Supabase account available to the authoring agent listed **no projects**, so a live schema could not be exported.
- Comments in `CLAUDE.md` and in `supabase/migrations/20261022070000_market.sql` state that migrations are **not yet applied to a live project**.

Treat the SQL under `supabase/migrations/` as the intended schema. Do not assume a hosted project already exists. Sir must create or share the project and grant access (see [access.md](access.md)). This document does not invent a project ref.

When a project exists, record **only** the project name and ref here (for example `abcdxyzxyzxyzxyz`). Never commit the anon key, service-role key, or database password.

## Environment config (names only)

`lib/core/config/env.dart` reads three compile-time defines:

| Variable name | Purpose |
|---------------|---------|
| `SUPABASE_URL` | Supabase API URL |
| `SUPABASE_ANON_KEY` | Anon / publishable key (safe for the client only if RLS is correct) |
| `GOOGLE_WEB_CLIENT_ID` | Declared on `Env` and passed empty by Codemagic; **not used** elsewhere in Dart today |

`Env.isConfigured` is true only when both `SUPABASE_URL` and `SUPABASE_ANON_KEY` are non-empty. Otherwise the app stays in **demo mode** (no `Supabase.initialize`, local storage, OTP `123456`).

Copy `env.example.json` to `env.json` (gitignored) and pass `--dart-define-from-file=env.json`. Command-line `--dart-define=NAME=value` still works and is what `codemagic.yaml` uses (values empty → demo).

**Edge Function secrets** (server only, never in the app or this repo): `AI_API_KEY`, `AI_BASE_URL`, `AI_MODEL`. See `supabase/functions/companion/index.ts` and the README deploy snippet.

## Auth

`lib/core/services/auth_service.dart`:

- **Demo (unconfigured):** any valid 10-digit number; OTP must be `123456`; profile and consent stored on device. Google sign-in throws `Google sign-in is unavailable in demo mode`.
- **Configured:** `signInWithOtp` / `verifyOTP` (SMS). Google is `signInWithOAuth(OAuthProvider.google, redirectTo: 'in.stellarone.oneup://login-callback')`.
- Profile rows live in `profiles` (upsert/select by `auth.uid()`).
- Consent writes `consent_version` and `consent_at`.

Enable Phone (SMS provider) and Google in the Supabase Auth dashboard when the project exists. Register redirect `in.stellarone.oneup://login-callback`. iOS already declares that URL scheme in `Info.plist`. Android declares the same scheme and host via an intent-filter on `MainActivity` in `AndroidManifest.xml`. Still to verify on a real device once a Supabase project exists.

## Migrations in the repo

All under `supabase/migrations/`. Apply, once a project exists, with `supabase db push` (after `supabase link`).

| File | What it does |
|------|----------------|
| `20261021000000_init.sql` | Core model: `profiles`, `dimensions` (seeded), `questions`, `assessments`, `answers` (`value_enc` text, AES-GCM ciphertext — plaintext scores are not meant to be stored), `dimension_scores`, `goals`, first-pass SAMPLE `products` / `consultants` / `slots`, `wishlist`, `cart_items`, `orders`, `order_items`, `bookings`. Enables RLS. `delete_my_data()` security definer function (authenticated only) |
| `20261021010000_seed_questions.sql` | 72 original questions; IDs match `lib/features/assess/data/question_bank.dart` |
| `20261022000000_open_text_item9.sql` | Item 9 becomes `open_text` (not scored); scoring comment: 8 items, `round((S-8)/32*100)`; re-seeds questions |
| `20261022010000_consult.sql` | Consultant types, SAMPLE consultants, booking status/mode, RPCs `book_sample_session` and `cancel_my_booking` (authenticated execute only) |
| `20261022020000_bands_companion.sql` | `oneup_band()`; band check 0–40 / 41–70 / 71–100; `companion_flags` (no message text — timestamp, risk, user id) with RLS |
| `20261022030000_profile_details.sql` | Extra optional profile columns; drops `avatar_url`; private Storage bucket `avatars` at `avatars/<uid>/avatar.jpg`, owner-only policies. Notes that `delete_my_data()` cannot delete storage objects from SQL — the app must remove the avatar via the Storage API first |
| `20261022040000_articles.sql` | `articles` table; select for anon + authenticated when `is_active`; no client writes (editors would use the service role) |
| `20261022050000_learn.sql` | `lessons` (read-only for clients) and `learn_progress` (own rows) |
| `20261022080000_market_seed.sql` | Seeds `products` with the 79 SAMPLE catalogue items (idempotent upsert) |
| `20261022070000_market.sql` | Demo market tables `market_wishlist`, `market_cart`, `market_orders`; cart guard trigger; comment: “Not yet applied remotely”. Also contains `create table if not exists public.products` with a the only `products` definition (init’s was removed) — see drift section below |

There is no `config.toml` or generated types folder in this checkout.

## Intended tables and RLS (from the SQL)

**Catalogue / read-mostly:** `dimensions`, `questions`, `products`, `consultants`, `slots`, `articles`, `lessons` — policies are select (some authenticated-only in init; articles/lessons also allow anon when active). Clients must not write catalogue tables.

**User-owned:** `profiles`, `assessments`, `answers` (via parent assessment), `dimension_scores` (via parent), `goals`, `wishlist` / `cart_items` / `orders` / `order_items` / `bookings` (init), `companion_flags`, `learn_progress`, `market_wishlist`, `market_cart`, `market_orders`. Policies use `auth.uid()`.

**RPCs:** `delete_my_data()`, `book_sample_session(...)`, `cancel_my_booking(uuid)`, `oneup_band(int)`. Execute on the first three is granted to `authenticated` only (revoked from `public`/`anon`).

**Storage:** private bucket `avatars`; object path `avatars/<uid>/avatar.jpg`.

Always re-read the SQL before changing policies. A live project should be reviewed after apply — especially `products` and any policy that uses `using (true)` without a role qualifier.

## Marketplace schema drift (fixed in the repo)

Previously `init` created a UUID-keyed `products` (plus `wishlist`, `cart_items`, `order_items`) and the later market migration's `create table if not exists public.products` (text id, `consult_only`) would have been silently skipped. The app only ever used the `market_*` tables with text product ids.

Fix: those four unused tables, their RLS and policies were removed from `20261021000000_init.sql`. `products` is now defined once, in `20261022070000_market.sql`. `orders` stays in init because `bookings.order_id` references it. All nine migrations were applied in order on a throwaway Postgres 16 with stubbed `auth` objects; they ran clean (Supabase `storage` was not stubbed, so the avatars-bucket statement in `profile_details` was not exercised).

The SAMPLE catalogue (79 items) is seeded by `20261022080000_market_seed.sql`, generated from `catalog` in `lib/features/market/market_models.dart`. `test/market_seed_sync_test.dart` fails if the SQL and the Dart list drift, so change both together. The three consult-only items (`ph-supplement`, `ph-medicine`, `em-sleep-aid`) are rejected by `market_cart_guard`; this was checked on local Postgres. Not tested against a real Supabase project.

## What the Flutter client actually calls

When `Env.isConfigured` and the user is signed in, repositories best-effort sync to:

- `profiles`, `assessments`, `answers`, `dimension_scores`, `goals`
- `articles` (select)
- `learn_progress`
- `market_wishlist`, `market_cart`, `market_orders`
- RPC `book_sample_session`, `cancel_my_booking`, `delete_my_data`
- Storage `avatars`
- Edge Function `companion` via `supabase.functions.invoke('companion')`

If keys are missing, **everything stays local** (secure storage). Plus entitlement, org join, referral codes, quick-check, ritual, weekly reports and activity glow are **local-only** in this tree (no matching migrations).

## Edge Functions

`supabase/functions/companion/index.ts` plus `spec.json`.

- Builds the system prompt from `spec.json` on the server (the client cannot alter it)
- Calls an OpenAI-compatible chat API using secrets `AI_API_KEY`, `AI_BASE_URL`, `AI_MODEL`
- Validates JSON against the spec’s output schema; includes a server-side crisis keyword net
- App uses it only when Supabase is configured **and** the user is signed in; otherwise `offline_responder.dart`

Deploy outline (from the existing README, names only):

```bash
supabase link --project-ref <ref>
supabase db push
supabase secrets set AI_API_KEY=... AI_BASE_URL=https://<provider>/v1 AI_MODEL=<model>
supabase functions deploy companion    # JWT verification stays ON (default)
```

## What is still mock / local

- Demo auth and all Phase 3 Plus / org / referral / experts data
- SAMPLE market checkout (`status` default `demo_placed` in the later orders table; init orders allowed `paid_placeholder`)
- SAMPLE consult booking and the in-app call screen
- Companion AI, until the function is deployed and secrets are set on a real project
- No Firebase, no custom Node/Express server, no other BaaS in this repo
