<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { lessons, deep } from '$lib/content/nav.js';
  import { page } from '$app/state';

  let { title, lead } = $props();
  const all = [...lessons, ...deep];
  const index = $derived(all.findIndex((l) => page.url.pathname.endsWith(`${l.href}/`)));
  const num = $derived(index >= 0 && index < lessons.length ? String(index + 1).padStart(2, '0') : '');
  const group = $derived(index >= 0 ? all[index].group : '');
</script>

<header class="head">
  {#if num}<span class="num" aria-hidden="true">{num}</span>{/if}
  <div>
    <p class="group">{group}</p>
    <h1>{title}</h1>
    <p class="lead">{lead}</p>
  </div>
</header>

<style>
  .head { display: flex; gap: 1.2rem; align-items: flex-start; padding-bottom: 1.6rem; border-bottom: var(--line) solid var(--ink); margin-bottom: 2rem; }
  .num {
    font-family: var(--display);
    font-weight: 900;
    font-stretch: 125%;
    font-size: clamp(3.4rem, 9vw, 6.5rem);
    line-height: 0.82;
    color: transparent;
    -webkit-text-stroke: 3px var(--ink);
    user-select: none;
  }
  h1 { font-size: clamp(2rem, 5.2vw, 3.6rem); }
  .group { margin: 0 0 0.5rem; font-family: var(--mono); font-weight: 700; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.1em; color: var(--blue); }
  .lead { margin: 0.9rem 0 0; font-size: 1.2rem; max-width: 52ch; }
  .head + :global(h2) { margin-top: 0; padding-top: 0; border-top: 0; }
  @media (max-width: 40rem) { .num { display: none; } }
</style>
