// Card-in-link codec. Spec: shared/LINK_FORMAT.md. Must match app/lib/link/link_codec.dart.
// Works in the browser and in Node (no DOM use).

const VERSION = 1;
const T = { name: 1, title: 2, business: 3, phone: 4, email: 5, description: 6, link: 7, ownLink: 8 };
const DICT_CODES = [1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31];
const PHONE = '0123456789+ -().';

// ---------------------------------------------------------------- base64url

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

export function toBase64Url(bytes) {
  let out = '';
  for (let i = 0; i < bytes.length; i += 3) {
    const n = (bytes[i] << 16) | ((bytes[i + 1] ?? 0) << 8) | (bytes[i + 2] ?? 0);
    const chars = i + 2 < bytes.length ? 4 : i + 1 < bytes.length ? 3 : 2;
    for (let k = 0; k < chars; k++) out += B64[(n >> (18 - 6 * k)) & 63];
  }
  return out;
}

export function fromBase64Url(text) {
  const out = [];
  let buf = 0, bits = 0;
  for (const ch of text) {
    const v = B64.indexOf(ch);
    if (v < 0) throw new Error('bad base64');
    buf = (buf << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push((buf >> bits) & 255);
    }
  }
  return Uint8Array.from(out);
}

// ---------------------------------------------------------------- primitives

function varint(n) {
  const out = [];
  do {
    let b = n & 127;
    n >>>= 7;
    if (n) b |= 128;
    out.push(b);
  } while (n);
  return out;
}

function encodeText(s, dict) {
  const clean = s.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '');
  const order = dict.map((d, i) => [d, DICT_CODES[i]]).sort((a, b) => b[0].length - a[0].length);
  const bytes = [];
  const enc = new TextEncoder();
  let i = 0;
  while (i < clean.length) {
    const hit = order.find(([d]) => clean.startsWith(d, i));
    if (hit) {
      bytes.push(hit[1]);
      i += hit[0].length;
    } else {
      const cp = clean.codePointAt(i);
      const ch = String.fromCodePoint(cp);
      bytes.push(...enc.encode(ch));
      i += ch.length;
    }
  }
  return [...varint(bytes.length), ...bytes];
}

function encodePhone(s) {
  const chars = [...s.replace(/\//g, '-')].filter((c) => PHONE.includes(c));
  const nibbles = chars.map((c) => PHONE.indexOf(c));
  const bytes = [];
  for (let i = 0; i < nibbles.length; i += 2) bytes.push((nibbles[i] << 4) | (nibbles[i + 1] ?? 0));
  return [...varint(nibbles.length), ...bytes];
}

const hex = (s) => s.replace('#', '').match(/../g).map((h) => parseInt(h, 16));
const toHex = (b) => '#' + b.map((x) => x.toString(16).padStart(2, '0')).join('').toUpperCase();

// ---------------------------------------------------------------- encode

/**
 * card: the public card shape used by render.js:
 *   { type: 'template'|'links', id: 'a1b2c3', name, title?, business?, phone?, email?, description?,
 *     links: [{label, url, icon?}], templateId?, style?: {bg,text,accent,fontId}, singleLinkMode? }
 * maxBytes: payload budget (Infinity for shared links / QR codes).
 * Returns { payload, bytes, omitted: [field names] }.
 */
export function encodeCard(card, design, maxBytes = Infinity) {
  const dict = design.link.dictionary;
  const own = card.type === 'links';
  const palette = !own && design.palettes.findIndex((p) =>
    p.bg.toUpperCase() === card.style.bg.toUpperCase() &&
    p.text.toUpperCase() === card.style.text.toUpperCase() &&
    p.accent.toUpperCase() === card.style.accent.toUpperCase());
  const custom = !own && palette < 0;

  const head = [(VERSION << 5) | (own ? 16 : 0) | (custom ? 8 : 0) | (card.singleLinkMode === 'redirect' ? 4 : 0)];
  head.push(...hex(card.id));
  if (!own) {
    const t = Math.max(0, design.templates.findIndex((x) => x.id === card.templateId));
    const f = Math.max(0, design.fonts.findIndex((x) => x.id === card.style.fontId));
    head.push((t << 4) | f);
    if (custom) head.push(...hex(card.style.bg), ...hex(card.style.text), ...hex(card.style.accent));
    else head.push(palette);
  }

  const entries = []; // [fieldName, bytes]
  const text = (tag, v) => [tag, ...encodeText(v, dict)];
  if (card.name) entries.push(['name', text(T.name, card.name)]);
  if (!own) {
    if (card.phone) entries.push(['phone', [T.phone, ...encodePhone(card.phone)]]);
    if (card.email) entries.push(['email', text(T.email, card.email)]);
  }
  if (card.business) entries.push(['business', text(T.business, card.business)]);
  if (!own && card.title) entries.push(['title', text(T.title, card.title)]);
  (card.links || []).forEach((l, i) => {
    const label = l.label === defaultLabel(l, design, own) ? '' : l.label;
    const body = own
      ? [T.ownLink, ...encodeText(l.url, dict), ...encodeText(label, dict)]
      : [T.link, Math.max(0, design.linkIcons.findIndex((x) => x.id === l.icon)), ...encodeText(l.url, dict), ...encodeText(label, dict)];
    entries.push([`link ${i + 1}`, body]);
  });
  if (!own && card.description) entries.push(['description', text(T.description, card.description)]);

  const bytes = [...head];
  const omitted = [];
  for (const [name, body] of entries) {
    if (bytes.length + body.length <= maxBytes) bytes.push(...body);
    else omitted.push(name);
  }
  if (omitted.includes('name')) throw new Error('name does not fit');
  const u8 = Uint8Array.from(bytes);
  return { payload: toBase64Url(u8), bytes: u8.length, omitted };
}

function defaultLabel(link, design, own) {
  if (!own) {
    const icon = design.linkIcons.find((x) => x.id === link.icon);
    if (icon && icon.id !== 'link' && icon.id !== 'web') return icon.label;
  }
  try {
    return new URL(link.url).hostname.replace(/^www\./, '');
  } catch {
    return link.url;
  }
}

// ---------------------------------------------------------------- decode

/** Returns the card object, or null if the payload is not a valid card link. */
export function decodeCard(payload, design) {
  try {
    const b = fromBase64Url(payload);
    let i = 0;
    const need = (n) => {
      if (i + n > b.length) throw new Error('truncated');
    };
    const readVarint = () => {
      let n = 0, shift = 0, x;
      do {
        need(1);
        x = b[i++];
        n |= (x & 127) << shift;
        shift += 7;
      } while (x & 128 && shift < 28);
      return n;
    };
    const dict = design.link.dictionary;
    const readText = () => {
      const len = readVarint();
      need(len);
      const chunk = b.subarray(i, i + len);
      i += len;
      let out = '', pending = [];
      const flush = () => {
        if (pending.length) out += new TextDecoder().decode(Uint8Array.from(pending));
        pending = [];
      };
      for (const x of chunk) {
        const d = DICT_CODES.indexOf(x);
        if (d >= 0) {
          flush();
          out += dict[d] ?? '';
        } else pending.push(x);
      }
      flush();
      return out;
    };
    const readPhone = () => {
      const n = readVarint();
      const len = Math.ceil(n / 2);
      need(len);
      let out = '';
      for (let k = 0; k < n; k++) {
        const byte = b[i + (k >> 1)];
        out += PHONE[k % 2 === 0 ? byte >> 4 : byte & 15];
      }
      i += len;
      return out;
    };

    need(4);
    const h = b[i++];
    if (h >> 5 !== VERSION) return null;
    const own = !!(h & 16);
    const card = {
      v: 1,
      type: own ? 'links' : 'template',
      id: [...b.subarray(i, i + 3)].map((x) => x.toString(16).padStart(2, '0')).join(''),
      name: '',
      links: [],
    };
    i += 3;
    if (!own) {
      need(1);
      const tf = b[i++];
      card.templateId = (design.templates[tf >> 4] || design.templates[0]).id;
      const fontId = (design.fonts[tf & 15] || design.fonts[0]).id;
      if (h & 8) {
        need(9);
        const c = [...b.subarray(i, i + 9)];
        i += 9;
        card.style = { bg: toHex(c.slice(0, 3)), text: toHex(c.slice(3, 6)), accent: toHex(c.slice(6, 9)), fontId };
      } else {
        need(1);
        const p = design.palettes[b[i++]] || design.palettes[0];
        card.style = { bg: p.bg, text: p.text, accent: p.accent, fontId };
      }
    } else {
      card.singleLinkMode = h & 4 ? 'redirect' : 'page';
    }

    const L = design.limits;
    const cap = (s, n) => s.slice(0, n);
    while (i < b.length) {
      const tag = b[i++];
      if (tag === T.name) card.name = cap(readText(), L.name);
      else if (tag === T.title) card.title = cap(readText(), L.title);
      else if (tag === T.business) card.business = cap(readText(), L.business);
      else if (tag === T.phone) card.phone = cap(readPhone(), L.phone);
      else if (tag === T.email) card.email = cap(readText(), L.email);
      else if (tag === T.description) card.description = cap(readText(), L.description);
      else if (tag === T.link || tag === T.ownLink) {
        let icon = 'link';
        if (tag === T.link) {
          need(1);
          icon = (design.linkIcons[b[i++]] || design.linkIcons[0]).id;
        }
        const url = readText();
        const label = readText();
        if (!/^https?:\/\/[^\s]+\.[^\s]+/i.test(url) || card.links.length >= L.maxLinks) continue;
        const link = { url, icon, label: '' };
        link.label = cap(label || defaultLabel(link, design, own), L.linkLabel);
        if (own) delete link.icon;
        card.links.push(link);
      } else break; // unknown tag: keep what we have
    }
    for (const k of ['title', 'business', 'phone', 'email', 'description']) if (card[k] === '') delete card[k];
    return card.name ? card : null;
  } catch {
    return null;
  }
}

/** Payload capacity in bytes for an NDEF tag of `maxSize` (Ndef.getMaxSize()). */
export function tagCapacity(maxSize, design) {
  const prefix = design.link.host.length + design.link.path.length + 1; // "host/c#"
  let chars = maxSize - 4 - 1 - prefix; // short record: 4-byte header, 1-byte URI prefix code
  if (1 + prefix + chars > 255) chars = maxSize - 7 - 1 - prefix; // long record header
  return Math.max(0, Math.floor((chars * 6) / 8));
}
