<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  // kind: "rule" (a language rule), "trap" (a mistake that is easy to make), "note" (extra detail)
  let { kind = 'note', title = '', children } = $props();
  const labels = { rule: 'Rule', trap: 'Trap', note: 'Note' };
</script>

<aside class={kind}>
  <span class="label">{labels[kind]}{title ? ` / ${title}` : ''}</span>
  <div class="body">{@render children?.()}</div>
</aside>

<style>
  aside {
    position: relative;
    border: var(--line) solid var(--ink);
    background: var(--slab);
    box-shadow: var(--shadow-sm);
    padding: 1.35rem 1.1rem 0.9rem;
    margin-block: 1.6rem;
  }
  .label {
    position: absolute;
    top: -0.85rem;
    left: 0.8rem;
    font-family: var(--mono);
    font-weight: 700;
    font-size: 0.74rem;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    background: var(--ink);
    color: var(--paper);
    padding: 0.12rem 0.5rem;
  }
  .rule { border-left-width: 12px; border-left-color: var(--blue); }
  .trap { background: color-mix(in srgb, var(--hazard) 22%, var(--slab)); }
  .trap .label { background: var(--hazard); color: #111110; }
  .body :global(p) { margin: 0; }
  .body :global(p + p) { margin-top: 0.7rem; }
</style>
