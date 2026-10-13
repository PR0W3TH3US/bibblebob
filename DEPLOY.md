# Deploying bibblebob

There is no server and no database. Each card travels inside its own link (`https://bibblebob.pages.dev/c#…`, see [shared/LINK_FORMAT.md](shared/LINK_FORMAT.md)). You only publish:

| Piece | Where | What it does |
|---|---|---|
| `site/` | Cloudflare Pages (free) | Static files that show a card from its link to people without the app |
| `app/` | GitHub Releases | The Android APK |

Everything here is free. It takes about 30 minutes the first time.

## 0. What you need

- A **GitHub** account.
- A **Cloudflare** account (free): <https://dash.cloudflare.com/sign-up>. No payment method is needed.
- To build the APK on your own PC: Flutter, plus the Android SDK and Java (Android Studio installs both). This is optional, because step 4 builds it on GitHub.

## 1. Put the code on GitHub

Create an empty, **public** repository called `bibblebob` on GitHub (no README). It must be public so the "Get the app" download works for everyone. Then:

```bash
git add -A
git commit -m "bibblebob"
git remote add origin https://github.com/YOUR-GITHUB-USER/bibblebob.git
git push -u origin main
```

In `site/assets/config.js`, replace `YOUR-GITHUB-USER` with your user name and push again.

## 2. Make the release signing key (for App Links)

Android only opens card links in the app if the website lists the fingerprint of the key that signed the APK. Create the key once and **keep it safe**: without it, you can't ship updates that install over the old app.

```bash
keytool -genkeypair -v -keystore bibblebob-release.jks -alias bibblebob -keyalg RSA -keysize 2048 -validity 10000
keytool -list -v -keystore bibblebob-release.jks -alias bibblebob
```

`keytool` comes with Java (in Android Studio it's in `Android Studio\jbr\bin`). Copy the `SHA256:` value into `site/.well-known/assetlinks.json`, replacing `REPLACE:WITH:YOUR:RELEASE:KEY:SHA256:FINGERPRINT`, then commit and push.

Keep `bibblebob-release.jks` out of the repository (`.gitignore` already ignores `*.jks`). To build release APKs locally, create `app/android/key.properties`:

```properties
storeFile=C:/path/to/bibblebob-release.jks
storePassword=your-password
keyAlias=bibblebob
keyPassword=your-password
```

## 3. Publish the website (Cloudflare Pages)

1. Dashboard → **Workers & Pages** → **Create** → **Pages** → **Connect to Git**.
2. Authorise GitHub and pick the `bibblebob` repository.
3. **Project name: `bibblebob`**. This gives the address `bibblebob.pages.dev`.
4. Build settings:
   - Framework preset: **None**
   - Build command: *(leave empty)*
   - Build output directory: **`site`**
5. **Save and Deploy.**

Every push to `main` now redeploys the site. Check that these load:

- `https://bibblebob.pages.dev/`
- `https://bibblebob.pages.dev/.well-known/assetlinks.json`

> **If the name `bibblebob` is taken**, Cloudflare gives you a different address, such as `bibblebob-1ab.pages.dev`. Change it in three places:
> - `android:host` in `app/android/app/src/main/AndroidManifest.xml`
> - `link.host` in `shared/design.json` (then run `node tools/sync-shared.mjs`)
> - a repository variable `SITE_BASE` = `https://<your-address>` (step 4); for local builds use `--dart-define=SITE_BASE=https://<your-address>`
>
> Links already written to tags keep their old address, so do this before writing real tags.

## 4. Release the Android app

On GitHub, open **Settings → Secrets and variables → Actions**. Under **Secrets**, add:

- `KEYSTORE_BASE64`: the key file as base64. In PowerShell:
  `[Convert]::ToBase64String([IO.File]::ReadAllBytes("bibblebob-release.jks")) | Set-Clipboard`, then paste.
- `KEYSTORE_PASSWORD`, `KEY_ALIAS` (`bibblebob`), `KEY_PASSWORD`

Then tag a version:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The **Release APK** workflow builds the app and attaches `bibblebob.apk` to a new release. The website's "Get the app" button always points at the latest one.

To build on your PC instead, run `flutter build apk --release` in `app/`, then upload `app/build/app/outputs/flutter-apk/app-release.apk` to a GitHub release as `bibblebob.apk`.

## 5. Check that it all works

1. Install the APK. Allow "install unknown apps" for your browser or file manager when asked.
2. Settings → Apps → bibblebob → **Open by default**: `bibblebob.pages.dev` should be listed as verified (or run `adb shell pm get-app-links com.bibblebob.app`).
3. Make a card and tap **Write to tag** with a sticker. Then tap the sticker with another phone:
   - with the app installed, the app opens and saves the card, even with no internet;
   - without it, the browser shows the card with **Save contact** and **Get the app**.

## Sticker sizes

The app fits the card to each sticker. The order of priority is: name, phone, email, business, title, links, description.

| Sticker | Room for the card | Typically holds |
|---|---|---|
| NTAG213 | 82 bytes | name, phone, email, business, title |
| NTAG215 | 349 bytes | the full card |
| NTAG216 | 628 bytes | the full card, with room to spare |

The editor shows how big your card is and what a small sticker would leave out.

## Everyday commands

```bash
# App
cd app
flutter test
flutter run                      # phone connected with USB debugging

# Website link codec (must match the app's; CI checks both)
node tools/test-linkcodec.mjs

# After editing shared/design.json or shared/icons.json
node tools/sync-shared.mjs

# After changing the logo (tools/build-icons.mjs)
cd tools && npm install && npm run icons
```
