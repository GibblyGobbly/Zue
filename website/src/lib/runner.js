// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly
import examples from '$lib/generated/examples.json';

// Where live runs go. Empty until the run server exists; then edited code is sent there.
const RUN_URL = import.meta.env.VITE_RUN_URL ?? '';

export function getExample(id) {
  const e = examples[id];
  if (!e) throw new Error(`There is no recorded example "${id}". Add examples/${id}.zu and run npm run record.`);
  return e;
}

export const liveRunAvailable = RUN_URL !== '';

// The editor shows a file without its final newline, so compare without it.
export const strip = (s) => s.replace(/\n$/, '');

function same(a, b) {
  const ka = Object.keys(a);
  const kb = Object.keys(b);
  return ka.length === kb.length && ka.every((k) => strip(a[k]) === strip(b[k]));
}

// Returns { stdout, stderr, status, source } where source is "recorded", "live" or "needs-server".
export async function runExample(id, files) {
  const rec = getExample(id);
  if (same(rec.files, files)) {
    return { stdout: rec.stdout, stderr: rec.stderr, status: rec.status, source: 'recorded' };
  }
  if (!RUN_URL) return { stdout: '', stderr: '', status: null, source: 'needs-server' };
  try {
    const res = await fetch(RUN_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ files, stdin: rec.stdin ?? '' })
    });
    const out = await res.json();
    return { stdout: out.stdout ?? '', stderr: out.stderr ?? '', status: out.status ?? 1, source: 'live' };
  } catch (e) {
    return { stdout: '', stderr: `The run server did not answer: ${e.message}\n`, status: null, source: 'live' };
  }
}
