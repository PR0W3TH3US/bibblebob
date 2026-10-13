# Card-in-link format (v1)

A card travels inside its own link, so nothing is stored on a server:

```
https://bibblebob.pages.dev/c#<payload>
```

`<payload>` is base64url (no padding) of the binary card below. Everything after `#` stays in the browser: the hosting service never sees which card was opened.

Both implementations must agree byte for byte:

- `site/assets/linkcodec.js` (website, and Node tests)
- `app/lib/link/link_codec.dart` (app)

`shared/link-vectors.json` holds test vectors that both test suites check (`node tools/test-linkcodec.mjs`, `flutter test`).

## Binary layout

| Bytes | Meaning |
|---|---|
| 1 | Header: bits 7–5 = version (1); bit 4 = own-link card; bit 3 = custom colours; bit 2 = single link opens directly (redirect); bits 1–0 = 0 |
| 3 | Card ID (random, chosen when the card is made). Lets the app update a saved contact instead of duplicating it. |
| 1 | Template cards only: `templateIndex << 4 \| fontIndex` |
| 1 or 9 | Template cards only: palette index, or 9 bytes `bg, text, accent` as RGB when the custom-colours bit is set |
| … | Entries until the end |

Indexes point into `shared/design.json` (`templates`, `fonts`, `palettes`, `linkIcons`). **Never reorder those lists; only append.**

### Entries

Each entry starts with a tag byte:

| Tag | Field | Body |
|---|---|---|
| 1 | name | text |
| 2 | title | text |
| 3 | business | text |
| 4 | phone | phone |
| 5 | email | text |
| 6 | description | text |
| 7 | link (template card) | icon index byte, text url, text label |
| 8 | link (own-link card) | text url, text label |

An empty label means "use the default": the icon's label for named icons, otherwise the link's host name. A decoder that meets an unknown tag stops and keeps what it has decoded so far.

- **text** = varint byte length + bytes. The bytes are UTF-8, except that the control codes `0x01–0x08, 0x0B, 0x0C, 0x0E–0x1F` (28 codes, in that order) stand for the strings in `design.json → link.dictionary`. The encoder replaces the longest dictionary match first. Tab, newline and carriage return are left as themselves.
- **phone** = varint number of characters + characters packed two per byte (high nibble first). `0–9` are digits, `A` = `+`, `B` = space, `C` = `-`, `D` = `(`, `E` = `)`, `F` = `.`. Any `/` becomes `-`.
- **varint** = 7 bits per byte, low bits first, top bit set means "more bytes follow".

## Fitting a sticker

Fields are written in priority order: name, phone, email, business, title, links (in the card's order), description. When a sticker is too small, the encoder skips any field that doesn't fit and tries the next, so the smallest stickers still carry the most important details. Capacity for the payload:

```
chars = ndefMaxSize − recordHeader(4, or 7 if the record payload > 255) − 1 (URI prefix code) − len("bibblebob.pages.dev/c#")
bytes = floor(chars × 6 / 8)
```

An NTAG213 (137 bytes) leaves 82 bytes, an NTAG215 (496) 349 bytes and an NTAG216 (868) 628 bytes. A full card with a description and three links is about 200 bytes.

## Safety

Decoded links are only used if they are `http:` or `https:`. Text is shown as text, never as HTML. Lengths are capped by `design.json → limits`.
