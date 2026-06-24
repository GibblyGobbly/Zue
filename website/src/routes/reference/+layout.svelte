<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { page } from '$app/state';
  import { base } from '$app/paths';
  import ref from '$lib/generated/reference.json';
  import ReferenceSearch from '$lib/components/ReferenceSearch.svelte';

  let { children } = $props();
  const path = $derived(page.url.pathname.replace(base, ''));
  const language = [
    { slug: 'keywords', title: 'Keywords' },
    { slug: 'operators', title: 'Operators' },
    { slug: 'error-codes', title: 'Error codes' },
    { slug: 'commands', title: 'Commands' },
    { slug: 'environment', title: 'Environment variables' }
  ];
  const here = (slug) => path === `/reference/${slug}/`;
</script>

<div class="wrap layout">
  <nav class="side" aria-label="Reference">
    <p class="cap"><a href="{base}/reference/" class:here={path === '/reference/'}>Reference home</a></p>
    <p class="cap">Functions</p>
    <ol>
      {#each ref.categories as c}
        <li><a href="{base}/reference/{c.slug}/" class:here={here(c.slug)}>{c.title}</a></li>
      {/each}
    </ol>
    <p class="cap">The language</p>
    <ol>
      {#each language as l}
        <li><a href="{base}/reference/{l.slug}/" class:here={here(l.slug)}>{l.title}</a></li>
      {/each}
    </ol>
  </nav>
  <div class="content">
    <ReferenceSearch />
    {@render children()}
  </div>
</div>

<style>
  .layout { display: grid; grid-template-columns: 15.5rem minmax(0, 1fr); gap: 3rem; padding-top: 2.4rem; align-items: start; }
  .side { position: sticky; top: 5rem; max-height: calc(100vh - 6rem); overflow: auto; padding: 0 8px 8px 0; }
  .cap { font-family: var(--mono); font-size: 0.76rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.1em; margin: 1.1rem 0 0.4rem; }
  .cap:first-child { margin-top: 0; }
  .cap a { text-decoration: none; }
  .cap a:hover, .cap a.here { color: var(--blue); }
  ol { list-style: none; margin: 0; padding: 0; border: var(--line) solid var(--ink); background: var(--slab); box-shadow: var(--shadow-sm); }
  li + li { border-top: 2px solid var(--ink); }
  li a { display: block; padding: 0.42rem 0.7rem; text-decoration: none; font-size: 0.95rem; font-weight: 600; color: var(--ink); }
  li a:hover { background: var(--blue); color: var(--blue-ink); }
  li a.here { background: var(--ink); color: var(--paper); }
  li a.here:hover { background: var(--blue); color: var(--blue-ink); }
  .content { min-width: 0; }
  @media (max-width: 60rem) { .layout { grid-template-columns: 1fr; gap: 1.6rem; } .side { position: static; max-height: none; } }
</style>
