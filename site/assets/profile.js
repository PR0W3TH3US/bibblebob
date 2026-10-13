import { APK_URL } from './config.js';
import { renderTemplateCard, icon, safeHref, onColor } from './render.js';
import { decodeCard } from './linkcodec.js';

// The whole card is in the link after "#" (see shared/LINK_FORMAT.md).
// That part is never sent to any server, so nobody but the visitor sees it.
const main = document.getElementById('main');

start();
window.addEventListener('hashchange', start);

async function start() {
  const payload = location.hash.replace(/^#/, '');
  if (!payload) return showMessage('Card not found', 'This link doesn’t contain a bibblebob card.');
  let design, icons;
  try {
    [design, icons] = await Promise.all([
      fetch('/shared/design.json').then(okJson),
      fetch('/shared/icons.json').then(okJson),
    ]);
  } catch {
    return showMessage('Couldn’t load the card', 'Please check your connection and try again.', true);
  }
  const card = decodeCard(payload, design);
  if (!card) {
    return showMessage('This card link is broken', 'The link is incomplete or was changed. Ask the owner to share it again.');
  }
  document.title = `${card.name} · bibblebob`;
  setMeta(card);

  if (card.type === 'links') return renderLinksCard(card, icons);
  renderTemplate(card, design, icons);
}

function renderTemplate(card, design, icons) {
  const node = renderTemplateCard(card, design, icons);
  document.body.style.background = card.style.bg;
  document.documentElement.style.setProperty('--page-accent', card.style.accent);
  document.documentElement.style.setProperty('--page-on-accent', onColor(card.style.accent));
  document.documentElement.style.setProperty('--page-text', card.style.text);
  document.documentElement.style.colorScheme = onColor(card.style.bg) === '#FFFFFF' ? 'dark' : 'light';
  main.replaceChildren(node, actions(card));
}

function renderLinksCard(card, icons) {
  const links = card.links.map((l) => ({ ...l, href: safeHref(l.url) })).filter((l) => l.href);
  if (links.length === 1 && card.singleLinkMode === 'redirect') {
    location.replace(links[0].href);
    return showMessage('Opening…', `Taking you to ${links[0].label}.`);
  }
  const box = el('section', 'own');
  box.appendChild(el('h1', 'own-name', card.name));
  if (card.business) box.appendChild(el('p', 'own-business', card.business));
  const list = el('div', 'own-links');
  for (const l of links) {
    const a = el('a', 'btn btn-accent');
    a.href = l.href;
    a.rel = 'noopener noreferrer';
    a.append(icon(icons, 'link'), el('span', '', links.length === 1 ? 'Open profile' : l.label));
    list.appendChild(a);
  }
  box.appendChild(list);
  main.replaceChildren(box, actions(card));
}

function actions(card) {
  const bar = el('div', 'actions');
  const save = el('button', 'btn btn-accent', 'Save contact');
  save.type = 'button';
  const hint = el('p', 'save-hint', 'Downloaded. Tap “Open” in the notification to add the contact.');
  hint.hidden = true;
  save.addEventListener('click', () => downloadVCard(card, hint));
  const app = el('a', 'btn btn-ghost', 'Get the app');
  app.href = APK_URL;
  bar.append(save, hint, app);
  const foot = el('p', 'foot');
  foot.append('Shared with ', Object.assign(el('a', '', 'bibblebob'), { href: '/' }));
  bar.appendChild(foot);
  return bar;
}

// ---------------------------------------------------------------- vCard

// "Save contact":
//  - iPhone: open the vCard itself; Safari shows "Create New Contact" straight away.
//  - Android and others: download the .vcf. Android browsers don't let web pages open the
//    Contacts app directly (Chromium only launches apps that accept web links), so the
//    person opens the download from the notification.
function downloadVCard(card, hint) {
  const ua = navigator.userAgent;
  if (/iPhone|iPad|iPod/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)) {
    const blob = new Blob([buildVCard(card)], { type: 'text/vcard;charset=utf-8' });
    location.href = URL.createObjectURL(blob);
    return;
  }
  saveVCardFile(card);
  if (hint && /Android/i.test(ua)) hint.hidden = false;
}

function saveVCardFile(card) {
  const blob = new Blob([buildVCard(card)], { type: 'text/vcard;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `${card.name.replace(/[^\p{L}\p{N} _-]/gu, '').trim() || 'contact'}.vcf`;
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
}

export function buildVCard(card) {
  const esc = (s) => s.replace(/\\/g, '\\\\').replace(/\n/g, '\\n').replace(/,/g, '\\,').replace(/;/g, '\\;');
  const parts = card.name.trim().split(/\s+/);
  const family = parts.length > 1 ? parts.pop() : '';
  const lines = ['BEGIN:VCARD', 'VERSION:3.0', `N:${esc(family)};${esc(parts.join(' '))};;;`, `FN:${esc(card.name)}`];
  if (card.business) lines.push(`ORG:${esc(card.business)}`);
  if (card.title) lines.push(`TITLE:${esc(card.title)}`);
  if (card.phone) lines.push(`TEL;TYPE=CELL:${esc(card.phone)}`);
  if (card.email) lines.push(`EMAIL;TYPE=INTERNET:${esc(card.email)}`);
  (card.links || []).forEach((l, i) => {
    lines.push(`item${i + 1}.URL:${l.url.replace(/[\r\n]/g, '')}`, `item${i + 1}.X-ABLabel:${esc(l.label)}`);
  });
  if (card.description) lines.push(`NOTE:${esc(card.description)}`);
  lines.push('END:VCARD');
  return lines.map(fold).join('\r\n') + '\r\n';
}

// RFC 6350 line folding at 75 octets.
function fold(line) {
  const bytes = new TextEncoder().encode(line);
  if (bytes.length <= 75) return line;
  const out = [];
  let cur = '';
  let len = 0;
  for (const ch of line) {
    const n = new TextEncoder().encode(ch).length;
    if (len + n > (out.length ? 74 : 75)) { out.push(cur); cur = ''; len = 0; }
    cur += ch;
    len += n;
  }
  out.push(cur);
  return out.join('\r\n ');
}

// ---------------------------------------------------------------- helpers

function showMessage(title, text, retry = false) {
  document.title = 'bibblebob';
  const box = el('section', 'message');
  box.append(el('h1', '', title), el('p', '', text));
  if (retry) {
    const b = el('button', 'btn btn-accent', 'Try again');
    b.type = 'button';
    b.addEventListener('click', () => location.reload());
    box.appendChild(b);
  }
  const app = el('a', 'btn btn-ghost', 'Get the bibblebob app');
  app.href = APK_URL;
  box.appendChild(app);
  main.replaceChildren(box);
}

function setMeta(card) {
  const desc = [card.title, card.business].filter(Boolean).join(' · ') || 'Digital business card';
  document.querySelector('meta[name="description"]').setAttribute('content', desc);
}

function okJson(r) {
  if (!r.ok) throw new Error(String(r.status));
  return r.json();
}

function el(tag, cls, text) {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text !== undefined) n.textContent = text;
  return n;
}
