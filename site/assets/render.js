// Renders a card from its data (decoded from the link), using the shared design spec
// (shared/design.json + shared/icons.json). The Flutter app's CardView follows
// the same spec and metrics, so a card looks the same in both places.
// All user text goes through textContent; links are re-checked to be http(s).

export function contrastRatio(a, b) {
  const lum = (hex) => {
    const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
      .map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  };
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
}

export function onColor(hex) {
  return contrastRatio(hex, '#FFFFFF') >= contrastRatio(hex, '#000000') ? '#FFFFFF' : '#000000';
}

export function safeHref(url) {
  try {
    const u = new URL(url);
    return u.protocol === 'http:' || u.protocol === 'https:' ? u.toString() : null;
  } catch {
    return null;
  }
}

function el(tag, cls, text) {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text !== undefined) n.textContent = text;
  return n;
}

export function icon(icons, id, cls = 'ic') {
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('aria-hidden', 'true');
  svg.setAttribute('class', cls);
  const path = document.createElementNS(ns, 'path');
  path.setAttribute('d', icons[id] || icons.link);
  path.setAttribute('fill', 'currentColor');
  svg.appendChild(path);
  return svg;
}

export function fontFor(design, fontId) {
  return design.fonts.find((f) => f.id === fontId) || design.fonts.find((f) => f.id === design.defaults.fontId);
}

export function loadFont(font) {
  const id = `font-${font.id}`;
  if (document.getElementById(id)) return;
  const link = document.createElement('link');
  link.id = id;
  link.rel = 'stylesheet';
  const weights = font.weights.join(';');
  link.href = `https://fonts.googleapis.com/css2?family=${encodeURIComponent(font.family).replace(/%20/g, '+')}:wght@${weights}&display=swap`;
  document.head.appendChild(link);
}

// Template card -> <article class="card ...">
export function renderTemplateCard(card, design, icons) {
  const tpl = design.templates.find((t) => t.id === card.templateId) || design.templates[0];
  const style = card.style;
  const font = fontFor(design, style.fontId);
  loadFont(font);

  const root = el('article', `card hdr-${tpl.header} face-${tpl.face} links-${tpl.links}`);
  root.style.setProperty('--bg', style.bg);
  root.style.setProperty('--text', style.text);
  root.style.setProperty('--accent', style.accent);
  root.style.setProperty('--on-accent', onColor(style.accent));
  root.style.setProperty('--name-size', `${tpl.nameSize}px`);
  root.style.fontFamily = `'${font.family}', system-ui, sans-serif`;

  const blocks = {
    header: () => header(card, tpl, icons),
    contact: () => contact(card, icons),
    description: () => (card.description ? el('p', 'desc', card.description) : null),
    links: () => linkList(card.links || [], tpl, design, icons),
  };
  for (const name of tpl.order) {
    const node = blocks[name]();
    if (node) root.appendChild(node);
  }
  return root;
}

function header(card, tpl, icons) {
  const h = el('header', 'hdr');
  const logo = card.logo ? Object.assign(el('img', 'logo'), { src: card.logo, alt: card.business ? `${card.business} logo` : 'Logo' }) : null;
  const face = card.face ? Object.assign(el('img', 'face'), { src: card.face, alt: card.name }) : null;
  const text = el('div', 'hdr-text');
  text.appendChild(el('h1', 'name', card.name));
  if (card.title) text.appendChild(el('p', 'title', card.title));
  if (card.business) text.appendChild(el('p', 'business', card.business));

  if (tpl.header === 'banner') {
    const band = el('div', 'band');
    if (logo) band.appendChild(logo);
    h.appendChild(band);
    if (face) h.appendChild(face);
    else h.classList.add('no-face');
    h.appendChild(text);
  } else if (tpl.header === 'split') {
    if (logo) h.appendChild(logo);
    const row = el('div', 'split-row');
    if (face) row.appendChild(face);
    row.appendChild(text);
    h.appendChild(row);
  } else {
    if (logo) h.appendChild(logo);
    if (face) h.appendChild(face);
    h.appendChild(text);
  }
  return h;
}

function contact(card, icons) {
  if (!card.phone && !card.email) return null;
  const box = el('div', 'contact');
  if (card.phone) {
    const a = el('a', 'contact-row');
    a.href = `tel:${card.phone.replace(/[^0-9+]/g, '')}`;
    a.append(icon(icons, 'ui-phone'), el('span', '', card.phone));
    box.appendChild(a);
  }
  if (card.email) {
    const a = el('a', 'contact-row');
    a.href = `mailto:${card.email}`;
    a.append(icon(icons, 'ui-email'), el('span', '', card.email));
    box.appendChild(a);
  }
  return box;
}

function linkList(links, tpl, design, icons) {
  const valid = links.map((l) => ({ ...l, href: safeHref(l.url) })).filter((l) => l.href);
  if (!valid.length) return null;
  const wrap = el('nav', 'links');
  const list = el('div', 'link-list');
  wrap.appendChild(list);
  const max = design.linkPreviewCount;

  valid.forEach((l, i) => {
    const a = el('a', 'link');
    a.href = l.href;
    a.rel = 'noopener noreferrer';
    if (i >= max) a.hidden = true;
    a.appendChild(icon(icons, l.icon || 'link'));
    a.appendChild(el('span', 'link-label', l.label));
    if (tpl.links === 'list') a.appendChild(icon(icons, 'ui-chevron', 'ic chev'));
    list.appendChild(a);
  });

  if (valid.length > max) {
    const more = el('button', 'more');
    more.type = 'button';
    more.append(el('span', '', `More (${valid.length - max})`), icon(icons, 'ui-more'));
    more.addEventListener('click', () => {
      list.querySelectorAll('.link[hidden]').forEach((n) => (n.hidden = false));
      more.remove();
    });
    wrap.appendChild(more);
  }
  return wrap;
}
