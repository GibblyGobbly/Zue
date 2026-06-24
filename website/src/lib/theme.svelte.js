// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly

// The chosen theme: "auto" follows the system, "light" and "dark" are set by hand.
export const theme = $state({ mode: 'auto' });

export function loadTheme() {
  try {
    const t = localStorage.getItem('zue-theme');
    if (t === 'light' || t === 'dark') theme.mode = t;
  } catch (e) {
    /* storage can be blocked; the page then follows the system */
  }
}

export function setTheme(mode) {
  theme.mode = mode;
  document.documentElement.dataset.theme = mode;
  try {
    if (mode === 'auto') localStorage.removeItem('zue-theme');
    else localStorage.setItem('zue-theme', mode);
  } catch (e) {
    /* nothing to do */
  }
}
