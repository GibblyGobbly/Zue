// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly
//
// Builds the reference data from the repository's own documentation, so the site cannot drift from it:
// the tables of docs/builtins.md and docs/unsafe.md, the error codes of docs/errors.md, the commands
// of docs/getting-started.md and the environment variables of docs/gc.md.
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const site = resolve(here, '..');
const docs = join(site, '..', 'docs');
const out = join(site, 'src', 'lib', 'generated', 'reference.json');

function splitRow(line) {
  const cells = [];
  let cur = '';
  let inCode = false;
  for (let i = 1; i < line.length; i++) {
    const c = line[i];
    if (c === '`') inCode = !inCode;
    if (c === '\\' && line[i + 1] === '|') {
      cur += '|';
      i++;
      continue;
    }
    if (c === '|' && !inCode) {
      cells.push(cur.trim());
      cur = '';
      continue;
    }
    cur += c;
  }
  return cells;
}

function tables(file) {
  const lines = readFileSync(join(docs, file), 'utf8').split('\n');
  const result = [];
  let h2 = '';
  let h3 = '';
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    if (l.startsWith('## ')) {
      h2 = l.slice(3).trim();
      h3 = '';
    } else if (l.startsWith('### ')) h3 = l.slice(4).trim();
    if (l.startsWith('|') && lines[i + 1] && /^\|[\s:|-]+\|?$/.test(lines[i + 1])) {
      const head = splitRow(l);
      const rows = [];
      let j = i + 2;
      while (j < lines.length && lines[j].startsWith('|')) {
        rows.push(splitRow(lines[j]));
        j++;
      }
      result.push({ file, h2, h3, head, rows });
      i = j - 1;
    }
  }
  return result;
}

const builtins = [];
for (const file of ['builtins.md', 'unsafe.md']) {
  for (const t of tables(file)) {
    const first = t.head[0].toLowerCase();
    if (!(first === 'function' || first === 'name')) continue;
    if (file === 'builtins.md' && t.head.length < 2) continue;
    if (file === 'unsafe.md' && t.h2 !== 'Functions') continue;
    const area = file === 'unsafe.md' ? 'Unsafe memory' : t.h2;
    builtins.push({
      area,
      group: file === 'unsafe.md' ? 'Raw memory, inside unsafe { }' : t.h3 || '',
      rows: t.rows.map((r) => ({ sig: r[0], desc: r[1] ?? '', example: r[2] ?? '' }))
    });
  }
}

builtins.push({
  area: 'Unsafe memory',
  group: 'Older names, still accepted',
  rows: [
    { sig: '`deref(ptr)`', desc: 'Same as `load(ptr)`', example: '' },
    { sig: '`ptr_add(ptr, n)`', desc: 'Same as `ptr_offset(ptr, n)`. Its out-of-bounds message still says `ptr_add()`', example: '' },
    { sig: '`addr(name)`', desc: 'Same as `address_of(name)`', example: '' }
  ]
});

const errText = readFileSync(join(docs, 'errors.md'), 'utf8');
const codeBlock = errText.slice(errText.indexOf('<!-- codes:start -->'), errText.indexOf('<!-- codes:end -->'));
const errorCodes = codeBlock
  .split('\n')
  .filter((l) => /^\| `E\d{4}`/.test(l))
  .map((l) => {
    const c = splitRow(l);
    return { code: c[0].replace(/`/g, ''), meaning: c[1] };
  })
  .sort((a, b) => a.code.localeCompare(b.code));

const cli = tables('getting-started.md')
  .filter((t) => t.head[0] === 'Command')
  .flatMap((t) => t.rows.map((r) => ({ command: r[0], effect: r[1] })));

const env = tables('gc.md')
  .flatMap((t) => t.rows)
  .filter((r) => /^`ZUE_RT_/.test(r[0]))
  .map((r) => ({ name: r[0], effect: r[1] }));
env.push(
  { name: '`ZUE_HOME`', effect: 'Where `zue` looks for `compiler/runtime`. The default is the directory above the one holding the `zue` binary' },
  { name: '`ZUE_ERROR_FORMAT=json`', effect: 'A compiled program prints its run-time error as one JSON object on standard error' },
  { name: '`CC`', effect: 'The C compiler driver for the final build step. The default is `clang`' }
);


// Group the rows by what a reader wants to do, not by the documentation page they came from.
const categories = [
  { slug: 'text', title: 'Text', blurb: 'Measure, search, cut, change, split and join strings.', lesson: '/learn/strings/' },
  { slug: 'numbers', title: 'Numbers and math', blurb: 'Rounding, powers, roots, trigonometry, sums and averages.', lesson: '/learn/math/' },
  { slug: 'random', title: 'Random numbers', blurb: 'Seeded and operating-system randomness.', lesson: '/learn/math-trig-random/' },
  { slug: 'vectors', title: 'Vectors and dense lists', blurb: 'Whole-list math on arrays of floats.', lesson: '/learn/math-vectors/' },
  { slug: 'lists', title: 'Lists', blurb: 'Add, remove, find, slice, sort and shuffle.', lesson: '/learn/lists/' },
  { slug: 'maps', title: 'Maps', blurb: 'Look up values by a text key.', lesson: '/learn/maps/' },
  { slug: 'types', title: 'Types and conversion', blurb: 'What a value is, and changing one kind into another.', lesson: '/learn/values/' },
  { slug: 'printing', title: 'Printing and input', blurb: 'Show output, read a line, check a condition.', lesson: '/learn/printing/' },
  { slug: 'system', title: 'The program and the system', blurb: 'Arguments, time, the shell and exit.', lesson: '/learn/shell/' },
  { slug: 'files', title: 'Files', blurb: 'Open, read, write and delete text files.', lesson: '/learn/files/' },
  { slug: 'threads', title: 'Threads and channels', blurb: 'Blue threads: spawn, wait, yield, send and receive.', lesson: '/learn/blue-threads/' },
  { slug: 'unsafe', title: 'Unsafe memory', blurb: 'Raw memory inside unsafe blocks.', lesson: '/learn/unsafe/' }
].map((c) => ({ ...c, entries: [] }));
const bySlug = Object.fromEntries(categories.map((c) => [c.slug, c]));

function categoryOf(area, group, name) {
  if (area === 'Strings') return 'text';
  if (area === 'Files') return 'files';
  if (area === 'Blue threads') return 'threads';
  if (area === 'Unsafe memory') return 'unsafe';
  if (area === 'Math') {
    if (/Random/.test(group)) return 'random';
    if (/Dense/.test(group)) return 'vectors';
    return 'numbers';
  }
  if (/Lists/.test(group)) return 'lists';
  if (/Maps/.test(group)) return 'maps';
  if (['print', 'input', 'debug', 'assert'].includes(name)) return 'printing';
  if (['clock', 'args', 'exit', 'system'].includes(name)) return 'system';
  return 'types';
}

const seen = new Set();
for (const t of builtins) {
  for (const r of t.rows) {
    const name = (/([A-Za-z_][A-Za-z0-9_]*)\s*\(/.exec(r.sig.replace(/`/g, '')) ?? [])[1];
    if (!name) continue;
    const cat = bySlug[categoryOf(t.area, t.group, name)];
    // a function that two documentation tables list (len, slice, contains ...) appears once, in its first category
    const key = cat.slug + ':' + name;
    if (seen.has(key)) continue;
    seen.add(key);
    cat.entries.push({ id: name, sig: r.sig, desc: r.desc, example: r.example, group: t.group });
  }
}
for (const c of categories) c.entries.sort((a, b) => 0);

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify({ builtins, categories, errorCodes, cli, env }, null, 1));
const rows = builtins.reduce((n, b) => n + b.rows.length, 0);
const entries = categories.reduce((n, c) => n + c.entries.length, 0);
console.log(`[OK] reference: ${rows} table rows in ${categories.length} categories (${entries} entries), ${errorCodes.length} error codes, ${cli.length} commands, ${env.length} environment variables`);
