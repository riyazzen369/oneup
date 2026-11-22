# Design

## Design system as implemented

The design system lives in code, not in a separate token package:

- `lib/core/theme/app_colors.dart` — brand colours, eight dimension colours, brand gradient
- `lib/core/theme/app_theme.dart` — Material 3 light/dark, Poppins, radii, button/input metrics
- `lib/core/theme/motion.dart` — fade-through transitions, bouncing scroll, web pointer drag
- `lib/core/widgets/fx.dart`, `gradient_background.dart`, `oneup_logo.dart`, `stellar_agents_logo.dart`
- `lib/features/plus/plus_ui.dart` — Plus neon lime → cyan, glow, frames, lock cards
- Dimension colours are also seeded in `supabase/migrations/20261021000000_init.sql` (`color_light` / `color_dark`) and should stay in sync with `WellnessDimension`

Full token tables (hex values, typography, spacing, Plus neon, web phone chrome) are in [frontend.md](frontend.md). Do not introduce a second unofficial palette; extend these files.

**Product rules that affect design copy:**

- Always the disclaimer: “OneUp is for wellness awareness, not medical diagnosis.”
- SAMPLE / DEMO labelling on placeholders (market, consult, Plus prices, experts, org, referral)
- Crisis path must remain obvious and ungated
- Medicines are consult-first, never a direct sale
- Mark unverified claims `[VERIFY]`

Light and dark themes are first-class (`themeModeProvider`, system/light/dark). Plus hero surfaces stay dark so neon contrast holds in both themes.

## Design sources (Figma / Canva / other)

Checked during this handover:

- **This git repo** — no Figma or Canva links, no `.fig` files, no design-source folder
- **Canva** (connected account) — no designs or folders matching OneUP / OneUp / StellarOne
- **Figma** — no file key or URL is referenced in the project, so no Figma source can be linked from here
- **Google Drive** (connected account) — a marketing pitch deck `OneUP-Pitch-Deck.pptx` exists in Sir’s Drive (not in git). Share it separately with the new developer if needed. An older `OneUP-demo.apk` is also on Drive; it is a binary, not a design source, and must not be committed to git
- **Local box copies** (not in this repo): `/workspace/slides/oneup-3Gh0Sn/` contains `OneUP-Pitch-Deck.pptx` and a short app-tour video. `/workspace/oneup-preview/` contains tour storyboard scripts and rendered frames used for marketing previews, not the app design system

**Conclusion:** there is **no Figma or Canva source of truth** for the OneUP app UI in the repo or in the accounts searched. The implemented Flutter theme is the design system. If Sir later creates or shares a Figma file, add the URL here (file name + link only).

## Screenshots in the repo

None. The git tree does not contain a `screenshots/` or `docs/images/` set.

Visual coverage is via `test/preview/*_preview_test.dart` (splash, wheel, ritual, report, plus, privacy, experts, games grid, and others). Those tests do not check PNG goldens into git.

Marketing stills and the v0.3.0 APK/web zip may exist outside the repo (for example under `/workspace/` on the build machine). They are build or campaign artefacts, not part of this source tree.

## Pitch / marketing

The slide deck and app-tour video are useful context for product tone, but they are not linked from git and should be treated as optional extras Sir can share, not as implementation specs.
