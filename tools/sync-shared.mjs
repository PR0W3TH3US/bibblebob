// Copies shared/design.json and shared/icons.json to the site and the app,
// so both render cards from the same spec. Run after editing anything in shared/.
//   node tools/sync-shared.mjs          copy
//   node tools/sync-shared.mjs --check  fail if a copy is out of date (CI)
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const check = process.argv.includes('--check');
let stale = 0;
for (const file of ['design.json', 'icons.json']) {
  const src = await readFile(join(root, 'shared', file), 'utf8');
  for (const dest of ['site/shared', 'app/assets/shared']) {
    const target = join(root, dest, file);
    const current = await readFile(target, 'utf8').catch(() => null);
    if (current === src) continue;
    if (check) {
      console.error(`out of date: ${dest}/${file}`);
      stale++;
    } else {
      await mkdir(dirname(target), { recursive: true });
      await writeFile(target, src);
      console.log(`updated ${dest}/${file}`);
    }
  }
}
if (stale) process.exit(1);
