# OneUp on iPhone via Codemagic → TestFlight

You need no Mac. Codemagic builds the app on its own Macs and uploads it to TestFlight.
Items marked **[VERIFY]** are prices or menu paths that I did not check on the live site. Apple and Codemagic change these often.

## 0. What is already done in this repo
- `ios/` project: bundle id `in.stellarone.oneup`, display name **OneUp**, iOS 13.0 minimum, camera and photo-library permission texts, the `in.stellarone.oneup://login-callback` URL scheme, `ITSAppUsesNonExemptEncryption = false`, and new app icons and a launch screen (made by `tool/gen_ios_icons.py`).
- `codemagic.yaml`: an `ios-testflight` workflow, plus an optional `android-apk` workflow.
- `.gitignore`: excludes the keystore (`*.jks`), `key.properties`, `.p8`, `.p12` and `.env` files.

## 1. Join the Apple Developer Program
1. Go to https://developer.apple.com/programs/enroll/ and sign in with your Apple ID. 2-factor authentication is required.
2. Enroll as an **Individual**, or as an **Organization** (this needs a D-U-N-S number).
3. Pay the yearly fee: about **US$99/year, or the local equivalent in INR [VERIFY]**. Approval can take from a few hours to a couple of days.

## 2. Create the App ID
1. Open https://developer.apple.com/account → **Certificates, Identifiers & Profiles → Identifiers → +** [VERIFY].
2. Choose **App IDs → App**. Set the description to `OneUp` and use the **Explicit** bundle ID `in.stellarone.oneup`.
3. You do not need any extra capabilities. Click **Register**.

## 3. Create the app in App Store Connect
1. Open https://appstoreconnect.apple.com → **Apps → + → New App** [VERIFY].
2. Fill in: Platform iOS, Name `OneUp`, primary language, Bundle ID `in.stellarone.oneup`, and SKU `oneup-001` (any text works).
3. After you create it, open **App Information** and copy the **Apple ID** (a 10-digit number).
   Put that number in `codemagic.yaml` as `APP_STORE_APPLE_ID`, replacing `0000000000`.

## 4. Create the App Store Connect API key
1. In App Store Connect, open **Users and Access → Integrations → App Store Connect API**. If asked, click "Request access" first.
2. Click **+**. Use the name `Codemagic` and the access role **App Manager** (Admin also works).
3. **Download the .p8 file.** Apple lets you download it only once. Store it safely and never put it in git.
4. Note down the **Issuer ID** (shown above the table) and the **Key ID**.

## 5. Put the code on GitHub (private repo recommended)
No git repository exists yet. On your own computer:
```bash
cd oneup
git init && git add -A && git status   # check: no .jks, key.properties or .p8 in the list
git commit -m "OneUp iOS + Codemagic"
git branch -M main
git remote add origin https://github.com/<you>/oneup.git   # create an empty PRIVATE repo first
git push -u origin main
```

## 6. Set up Codemagic
1. Sign up at https://codemagic.io with **GitHub**. The free tier includes some macOS build minutes each month: **about 500 [VERIFY]**.
2. Click **Add application** → GitHub → pick the `oneup` repo → project type **Flutter App (via codemagic.yaml)** [VERIFY].
3. **Environment variables:** go to App → **Environment variables** and create a group named exactly `app_store_credentials`. Add these three variables and tick **Secure** for each:
   - `APP_STORE_CONNECT_ISSUER_ID`: the Issuer ID
   - `APP_STORE_CONNECT_KEY_IDENTIFIER`: the Key ID
   - `APP_STORE_CONNECT_PRIVATE_KEY`: the whole text of the .p8 file, including the BEGIN and END lines
4. **API key for signing:** go to **Team settings → Team integrations → Developer Portal → Manage keys → Add key**. Upload the same .p8 file with its Issuer ID and Key ID.
5. **Code signing files:** go to **Team settings → codemagic.yaml settings → Code signing identities**.
   - **iOS certificates → Generate certificate.** Choose type *Apple Distribution*, then download it and save the password Codemagic shows. Then upload the certificate on the same tab.
   - **iOS provisioning profiles → Fetch profiles.** Choose the *App Store* profile for `in.stellarone.oneup`.
     If no profile is listed, create one at developer.apple.com → Profiles → + → **App Store Connect** → select the App ID and the certificate. Then click Fetch again.

## 7. Start a build
- Push to `main`; the workflow starts automatically. You can also open the app in Codemagic → **Start new build** → workflow **iOS -> TestFlight**.
- A build takes about 15–25 minutes. Codemagic uploads it to App Store Connect, and Apple then takes another 5–30 minutes to "process" it.
- The build number is set automatically to the latest TestFlight build number + 1.
- If the build fails, open the failing step's log. The usual causes are a missing certificate or profile, or a wrong group name.

## 8. Install on your iPhone
1. On the iPhone, install **TestFlight** from the App Store.
2. In App Store Connect, open the app → **TestFlight**.
   - **Internal testers:** create a group under *Internal Testing*, then add yourself and up to 100 App Store Connect users. They get the build without any review.
   - **External testers:** friends without an App Store Connect account. Create a group under *External Testing* and add their emails, or turn on a public link. The first build needs a short **Beta App Review**.
3. If Apple asks about **Export Compliance**, answer "None". This should already be answered by `ITSAppUsesNonExemptEncryption = false`.
4. Open the email invite on the iPhone → TestFlight → **Install**. Each build expires after **90 days [VERIFY]**.

## Notes
- The app runs in **demo mode** because the Supabase keys are left empty. Google sign-in redirects to `in.stellarone.oneup://login-callback` and only matters once Supabase is configured. In that case also add this URL in Supabase → Auth → URL configuration [VERIFY].
- The Android build keeps using your existing keystore. To build Android on Codemagic, upload `oneup-demo.jks` under Code signing identities → Android keystores with reference `oneup_keystore`. Do not commit it.
- To regenerate the iOS icons: `python3 tool/gen_ios_icons.py` (needs Pillow).
