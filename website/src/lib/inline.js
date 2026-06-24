// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly

// Splits a documentation cell into plain and code parts. Backticks mark code; [text](link) keeps only the text.
export function inline(text) {
  const clean = String(text ?? '').replace(/\[([^\]]+)\]\([^)]*\)/g, '$1');
  return clean
    .split(/(`[^`]*`)/)
    .filter((p) => p !== '')
    .map((p) => (p.startsWith('`') && p.endsWith('`') && p.length > 1 ? { code: true, text: p.slice(1, -1) } : { code: false, text: p }));
}

export function plain(text) {
  return inline(text)
    .map((p) => p.text)
    .join('');
}
