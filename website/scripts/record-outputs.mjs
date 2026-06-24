// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly
//
// Runs every example under website/examples with the real compiler and stores the code with its true
// output in src/lib/generated/examples.json. An example is either examples/<id>.zu or a folder
// examples/<id>/ with main.zu and the modules it uses. A name ending in .err (hello.err.zu) must fail
// to compile or run; any other example must exit with status 0. An optional <id>.in is the standard input.
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const site = resolve(here, '..');
const zue = process.env.ZUE ?? resolve(site, '..', 'bin', 'zue');
const exdir = join(site, 'examples');
const outfile = join(site, 'src', 'lib', 'generated', 'examples.json');

if (!existsSync(zue)) {
  console.error(`[ERROR] ${zue} is not built; run make in the repository root`);
  process.exit(1);
}

const entries = readdirSync(exdir).sort();
const result = {};
let failures = 0;

function runOne(id, files, stdin, mustFail, env) {
  const dir = mkdtempSync(join(tmpdir(), 'zue-site-'));
  try {
    for (const [name, code] of Object.entries(files)) {
      mkdirSync(dirname(join(dir, name)), { recursive: true });
      writeFileSync(join(dir, name), code);
    }
    const r = spawnSync(zue, ['run', 'main.zu'], { cwd: dir, input: stdin ?? '', encoding: 'utf8', timeout: 120000, env: { ...process.env, ...env } });
    const status = r.status ?? 1;
    const ok = mustFail ? status !== 0 : status === 0;
    if (!ok) {
      failures++;
      console.error(`[FAIL] ${id}: exit ${status}${mustFail ? ' (expected an error)' : ''}\n${r.stdout}${r.stderr}`);
    }
    return { files, stdout: r.stdout, stderr: r.stderr.replace(/\x1b\[[0-9;]*m/g, ''), status };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

for (const entry of entries) {
  const full = join(exdir, entry);
  let id, files;
  if (statSync(full).isDirectory()) {
    id = entry;
    files = {};
    const walk = (d, pre) => {
      for (const f of readdirSync(d).sort()) {
        const p = join(d, f);
        if (statSync(p).isDirectory()) walk(p, pre + f + '/');
        else if (f.endsWith('.zu')) files[pre + f] = readFileSync(p, 'utf8');
      }
    };
    walk(full, '');
  } else if (entry.endsWith('.zu')) {
    id = entry.replace(/\.zu$/, '');
    files = { 'main.zu': readFileSync(full, 'utf8') };
  } else continue;
  const mustFail = id.endsWith('.err');
  const key = id.replace(/\.err$/, '');
  const inFile = join(exdir, `${key}.in`);
  const stdin = existsSync(inFile) ? readFileSync(inFile, 'utf8') : '';
  const envFile = join(exdir, `${key}.env`);
  const env = {};
  if (existsSync(envFile)) {
    for (const line of readFileSync(envFile, 'utf8').split('\n')) {
      const m = /^([A-Z_]+)=(.*)$/.exec(line.trim());
      if (m) env[m[1]] = m[2];
    }
  }
  result[key] = { ...runOne(id, files, stdin, mustFail, env), stdin, env };
}

mkdirSync(dirname(outfile), { recursive: true });
writeFileSync(outfile, JSON.stringify(result, null, 1));
console.log(`[OK] recorded ${Object.keys(result).length} examples${failures ? `, ${failures} FAILED` : ''}`);
process.exit(failures ? 1 : 0);
