// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly
//
// Fails when a builtin of compiler/shared.zu is missing from the reference, or when a builtin is never
// used in any example. This is what keeps the site from skipping a function.
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const site = resolve(here, '..');
const shared = readFileSync(join(site, '..', 'compiler', 'shared.zu'), 'utf8');
const list = /split\("([^"]+)", " "\)/.exec(shared)[1].split(' ');
const ref = JSON.parse(readFileSync(join(site, 'src/lib/generated/reference.json'), 'utf8'));
const examples = JSON.parse(readFileSync(join(site, 'src/lib/generated/examples.json'), 'utf8'));

const documented = new Set();
for (const t of ref.builtins) for (const r of t.rows) for (const m of r.sig.matchAll(/([A-Za-z_][A-Za-z0-9_]*)\s*\(/g)) documented.add(m[1]);
const code = Object.values(examples).flatMap((e) => Object.values(e.files)).join('\n');

let bad = 0;
for (const name of list) {
  if (!documented.has(name)) {
    console.error(`[MISSING] ${name} is not in the reference`);
    bad++;
  }
  if (!new RegExp(`\\b${name}\\b`).test(code)) {
    console.error(`[NO EXAMPLE] ${name} appears in no example`);
    bad++;
  }
}
console.log(`${list.length} builtins checked, ${bad} problem(s)`);
process.exit(bad ? 1 : 0);
