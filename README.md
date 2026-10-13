<p align="center"><img src="brand/logo.svg" width="120" alt="bibblebob logo"></p>

<h1 align="center">bibblebob</h1>

<p align="center">Your business card on an NFC sticker, and every card you collect in one offline list.<br>
No accounts. No server storing your data. Android.</p>

## Download

**[⬇ Download bibblebob.apk](https://github.com/PR0W3TH3US/bibblebob/releases/latest/download/bibblebob.apk)** (latest version, Android 7 or newer)

### How to install

1. Tap the download link above on your Android phone.
2. Open the downloaded **bibblebob.apk** (from the notification or your *Downloads* folder).
3. Android asks to allow installing from this source: tap **Settings**, switch on **Allow from this source**, go back.
4. Tap **Install**. If Play Protect warns about an unknown app, tap **More details → Install anyway**. The warning appears because bibblebob isn't from the Play Store.

To update, download and install the new version the same way. Your cards and contacts stay.

## What it does

- **Make your cards:** as many as you like ("Work", "Freelance", "Events"…), with templates, colours and fonts.
- **Share them your way:**
  - **Web page:** the NFC sticker opens your designed card in any phone's browser, iPhone too.
  - **Contact:** Android phones get "Add to contacts" straight from the sticker, offline.
  - **QR code:** show it on your screen; any phone camera adds you as a contact.
  - **Own link:** the sticker opens a link you already have (Linktree, your website…).
- **Collect cards:** tap someone's bibblebob sticker, or **scan a paper business card** with the camera. Everything is stored on your phone only.
- **Contacts list** with search, and one-tap intro text or email.
- **Backup** to a single file: no account needed.

## Privacy

The app has **no internet permission**: it can't send anything anywhere. Your card travels inside the sticker or link itself. The web page only draws it, and the part of the link that holds your card is never sent to the website.

## NFC stickers

Any **NTAG213, NTAG215 or NTAG216** sticker works. NTAG215/216 hold a full card; on the small NTAG213 the app fits the most important details (name, phone, email first).

---

### For developers

The app is Flutter (`app/`), the card viewer is a static site (`site/`) and the card format is shared between them (`shared/`, see [LINK_FORMAT.md](shared/LINK_FORMAT.md)). Hosting, signing and releases: [DEPLOY.md](DEPLOY.md).
