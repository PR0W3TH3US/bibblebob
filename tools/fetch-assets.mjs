// Downloads the bundled fonts and builds shared/icons.json.
// Run once after cloning (outputs are committed): node tools/fetch-assets.mjs
import { mkdir, writeFile, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const design = JSON.parse(await readFile(join(root, 'shared/design.json'), 'utf8'));

// ---- Icons: SVG path data from Material Design Icons (Apache 2.0) ----
const MDI = 'https://cdn.jsdelivr.net/npm/@mdi/js@7.4.47/mdi.js';
const mdi = await (await fetch(MDI)).text();
const icons = {};
for (const icon of [...design.linkIcons, ...design.uiIcons]) {
  const m = mdi.match(new RegExp(`export var ${icon.mdi} = "([^"]+)"`));
  if (!m) throw new Error(`MDI icon not found: ${icon.mdi}`);
  icons[icon.id] = m[1];
}
await writeFile(join(root, 'shared/icons.json'), JSON.stringify(icons, null, 1) + '\n');
console.log(`icons: ${Object.keys(icons).length}`);

// ---- Fonts: static TTFs (all subsets) from @expo-google-fonts ----
const fontDir = join(root, 'app/assets/fonts');
await mkdir(fontDir, { recursive: true });
for (const font of design.fonts) {
  for (const w of font.weights) {
    const variant = { 400: '400Regular', 600: '600SemiBold', 700: '700Bold' }[w];
    const file = `${font.family.replace(/ /g, '')}_${variant}.ttf`;
    const url = `https://cdn.jsdelivr.net/npm/@expo-google-fonts/${font.package}@${font.packageVersion}/${variant}/${file}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`${res.status} ${url}`);
    await writeFile(join(fontDir, `${font.id}-${w}.ttf`), Buffer.from(await res.arrayBuffer()));
    console.log(`font: ${font.id}-${w}.ttf`);
  }
}
