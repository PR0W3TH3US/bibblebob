// Tests the website's link codec and maintains shared/link-vectors.json,
// which the app's Dart codec is tested against too.
//   node tools/test-linkcodec.mjs          check
//   node tools/test-linkcodec.mjs --write  regenerate vectors (only when the format changes on purpose)
import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { encodeCard, decodeCard, tagCapacity, toBase64Url } from '../site/assets/linkcodec.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const design = JSON.parse(await readFile(join(root, 'shared/design.json'), 'utf8'));
const vectorsPath = join(root, 'shared/link-vectors.json');

const NTAG213 = tagCapacity(137, design);
const NTAG215 = tagCapacity(496, design);

const full = {
  type: 'template', id: 'a1b2c3', name: 'Ada Lovelace', title: 'Analytical Engineer', business: 'Babbage & Co',
  phone: '+44 20 7946 0958', email: 'ada.lovelace@gmail.com',
  description: 'I write programs for machines that do not exist yet.\nAsk me about Bernoulli numbers.',
  links: [
    { label: 'LinkedIn', url: 'https://www.linkedin.com/in/ada', icon: 'linkedin' },
    { label: 'My site', url: 'https://ada.dev/', icon: 'web' },
    { label: 'Instagram', url: 'https://instagram.com/ada', icon: 'instagram' },
  ],
  templateId: 'banner', style: { bg: '#101418', text: '#F3F4F6', accent: '#60A5FA', fontId: 'poppins' },
};
const cases = [
  ['full template card, unlimited', full, null],
  ['full template card on NTAG213', full, NTAG213],
  ['custom colours, unicode', { ...full, id: '00ff10', name: 'Zoë Ñúñez 李', description: '', links: [],
    style: { bg: '#123456', text: '#FEDCBA', accent: '#00FF00', fontId: 'dm-serif' }, templateId: 'spotlight' }, null],
  ['own-link, one link, redirect', { type: 'links', id: 'ffffff', name: 'Grace Hopper',
    links: [{ label: 'linktr.ee', url: 'https://linktr.ee/grace' }], singleLinkMode: 'redirect' }, NTAG213],
  ['own-link, several links', { type: 'links', id: '010203', name: 'Alan Turing', business: 'Bletchley',
    links: [{ label: 'Linktree', url: 'https://linktr.ee/alan' }, { label: 'Blog', url: 'https://alan.org/blog' }], singleLinkMode: 'page' }, null],
];

const vectors = cases.map(([name, card, maxBytes]) => {
  const r = encodeCard(card, design, maxBytes ?? Infinity);
  return { name, card, maxBytes, payload: r.payload, bytes: r.bytes, omitted: r.omitted, decoded: decodeCard(r.payload, design) };
});

if (process.argv.includes('--write')) {
  await writeFile(vectorsPath, JSON.stringify(vectors, null, 2) + '\n');
  console.log(`wrote ${vectors.length} vectors`);
} else {
  const saved = JSON.parse(await readFile(vectorsPath, 'utf8'));
  assert.deepEqual(vectors, saved, 'codec output changed; if intended run with --write');
}

// Behaviour checks
const log = (m) => console.log(`- ${m}`);
log(`capacity NTAG213=${NTAG213} B, NTAG215=${NTAG215} B, NTAG216=${tagCapacity(868, design)} B`);
const v = Object.fromEntries(vectors.map((x) => [x.name, x]));

const rt = v['full template card, unlimited'].decoded;
assert.equal(rt.name, full.name);
assert.equal(rt.phone, full.phone);
assert.equal(rt.email, full.email);
assert.equal(rt.description, full.description);
assert.equal(rt.templateId, 'banner');
assert.deepEqual(rt.style, full.style);
assert.equal(rt.links[1].label, 'My site');
assert.equal(rt.links[0].label, 'LinkedIn');
log(`full card round-trips (${v['full template card, unlimited'].bytes} bytes)`);

const small = v['full template card on NTAG213'];
assert.ok(small.bytes <= NTAG213);
assert.ok(['name', 'phone', 'email'].every((f) => !small.omitted.includes(f)));
log(`NTAG213 keeps name/phone/email, omits: ${small.omitted.join(', ')}`);

assert.equal(v['custom colours, unicode'].decoded.name, 'Zoë Ñúñez 李');
assert.equal(v['custom colours, unicode'].decoded.style.accent, '#00FF00');
assert.equal(v['own-link, one link, redirect'].decoded.singleLinkMode, 'redirect');
assert.equal(v['own-link, one link, redirect'].decoded.links[0].label, 'linktr.ee');
log('unicode, custom colours and own-link cards round-trip');

// Hostile input
const evilPayload = toBase64Url(Uint8Array.from([0x20, 1, 2, 3, 0x00, 0x00, 1, 1, 0x41, 7, 0, 19, ...new TextEncoder().encode('javascript:alert(1)'), 0]));
assert.equal(decodeCard(evilPayload, design).links.length, 0);
assert.equal(decodeCard('!!!', design), null);
assert.equal(decodeCard('', design), null);
assert.equal(decodeCard(toBase64Url(Uint8Array.from([0x20, 1, 2])), design), null);
log('rejects javascript: links, garbage and truncated payloads');
console.log('\nLink codec OK.');
