# Access checklist

Grant access **before** the new developer can build, ship or wire a real backend. **Sir grants all of these.** This handover does not invite anyone, change roles, or open tickets.

Minimum roles below are a starting point (enough to continue the build, not necessarily Owner). Tighten or raise them if your org policy says so.

| Service | Why it is needed | Status at handover | Suggested minimum role for the new dev | Who grants |
|---------|------------------|--------------------|----------------------------------------|------------|
| **GitHub** — `riyazzen369/oneup` | Clone, branch, PR, push | Public repo; Sir is the owner | **Write** collaborator (or a fork + PR if you prefer not to grant write) | Sir |
| **Supabase** org / project | Apply migrations, Auth providers, RLS review, Storage, deploy `companion` | **No live project** was visible to the connected account; none is named in the repo | After Sir creates or identifies the project: **Developer** (or equivalent) on that project | Sir |
| **Netlify** team / site | Host the Flutter web build | **No site name or config in the repo**; existence unconfirmed | If a site exists or is created: **Developer** (build + deploy, not billing) | Sir |
| **Codemagic** team | iOS TestFlight + optional Android APK | `codemagic.yaml` is in the repo; team membership is not | **Developer** (trigger builds, see logs). Signing identities stay in the team; do not email `.p8` files | Sir |
| **Apple Developer / App Store Connect** | Bundle ID `in.stellarone.oneup`, certificates, TestFlight | App ID and app may or may not already be created; `APP_STORE_APPLE_ID` is still `0000000000` | **Developer** or **App Manager** on the OneUp app (not Account Holder) | Sir (Account Holder) |
| **Google Play Console** | Only if you ship Android to Play | **Not set up in this repo** | If you start Play: **Release to production** or at least **View app information + release to testing**, plus access to the *upload* keystore via a secure channel — never git | Sir |
| **Firebase** | — | **Not used** (no Firebase deps, no `google-services` files in git) | None | — |
| **Figma** | Design source | **No OneUP Figma file found** or linked | If Sir later creates one: **can view** (or **can edit** if they will maintain the file) | Sir |
| **Canva** | Marketing / deck | **No OneUP Canva design or folder found** | If Sir later shares the pitch deck or a brand kit: **Can edit** or view, as needed | Sir |
| **Google Drive** (optional) | Pitch deck / older demo APK already on Sir’s Drive | Present in Sir’s Drive, not in git | Viewer on those specific files, if useful | Sir |
| **Android keystore** | Sign release APK/AAB | Held **privately by Sir**; gitignored | Not an “account”. Share `key.properties` + the `.jks` through a password manager or in-person — never commit, never paste into chat or a ticket | Sir |

## What Sir must grant himself (only Sir can do this)

The new developer cannot self-join these. Sir needs to:

1. Add the developer as a **GitHub collaborator** (Write) on `riyazzen369/oneup`, or agree a fork/PR workflow.
2. Create or identify the **Supabase** project, then add the developer as a project member. Record the project **name and ref only** (no keys) in the team’s private notes or a future update to [backend.md](backend.md).
3. Confirm whether a **Netlify** site already exists. If yes, add the developer to that team/site and tell them the site name. If no, decide the host and add config to the repo.
4. Invite the developer to the **Codemagic** team that builds this app (group `app_store_credentials` must remain secure).
5. Invite them in **App Store Connect** / Apple Developer to the OneUp app, and fill in `APP_STORE_APPLE_ID` when the app record exists.
6. If Play Store is in scope, invite them in **Google Play Console** and hand over the signing key through a secure channel.
7. Share **Figma / Canva / Drive** design or pitch files if he wants those used — none are in git.
8. Hand over the **demo (or Play) keystore** securely if they will produce signed Android builds.

Do not send service-role keys, `.p8` contents, keystore passwords, or `env.json` values through GitHub issues, this public repo, or unencrypted email.
