<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { page } from '$app/state';
  import { base } from '$app/paths';

  // groups: [{ name, pages: [{ slug, title }] }]. area: "learn" or "internals". Only the group you are in starts open.
  let { groups, area, label, numbered = false } = $props();
  const path = $derived(page.url.pathname.replace(base, ''));
  const here = (slug) => path === `/${area}/${slug}/`;
  let count = 0;
  const numbers = {};
  for (const g of groups) for (const p of g.pages) numbers[p.slug] = ++count;
</script>

<nav class="side" aria-label={label}>
  {#each groups as g}
    <details open={g.pages.some((p) => here(p.slug))}>
      <summary>{g.name}</summary>
      <ol>
        {#each g.pages as p}
          <li>
            <a href="{base}/{area}/{p.slug}/" class:here={here(p.slug)} aria-current={here(p.slug) ? 'page' : undefined}>
              {#if numbered}<span class="n">{String(numbers[p.slug]).padStart(2, '0')}</span>{/if}{p.title}
            </a>
          </li>
        {/each}
      </ol>
    </details>
  {/each}
</nav>

<style>
  .side { position: sticky; top: 5rem; max-height: calc(100vh - 6rem); overflow: auto; padding: 0 8px 8px 0; }
  details { margin-bottom: 0.7rem; }
  summary {
    cursor: pointer;
    font-family: var(--mono);
    font-size: 0.76rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    padding: 0.35rem 0;
    list-style: none;
  }
  summary::-webkit-details-marker { display: none; }
  summary::before { content: '+ '; color: var(--blue); }
  details[open] > summary::before { content: '- '; }
  summary:hover { color: var(--blue); }
  ol { list-style: none; margin: 0.3rem 0 0; padding: 0; border: var(--line) solid var(--ink); background: var(--slab); box-shadow: var(--shadow-sm); }
  li + li { border-top: 2px solid var(--ink); }
  a { display: flex; gap: 0.6rem; padding: 0.42rem 0.7rem; text-decoration: none; font-size: 0.95rem; font-weight: 600; color: var(--ink); }
  a:hover { background: var(--blue); color: var(--blue-ink); }
  a.here { background: var(--ink); color: var(--paper); }
  a.here:hover { background: var(--blue); color: var(--blue-ink); }
  .n { font-family: var(--mono); font-size: 0.78rem; opacity: 0.7; padding-top: 0.12rem; }
  @media (max-width: 60rem) { .side { position: static; max-height: none; } }
</style>
