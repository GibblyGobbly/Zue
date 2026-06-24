// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly
import ref from '$lib/generated/reference.json';

export const entries = () => ref.categories.map((c) => ({ cat: c.slug }));

export function load({ params }) {
  return { cat: params.cat };
}
