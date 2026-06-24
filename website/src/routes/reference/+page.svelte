<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { base } from '$app/paths';
  import ref from '$lib/generated/reference.json';

  const names = (sig) => [...new Set([...sig.replace(/`/g, '').matchAll(/([A-Za-z_][A-Za-z0-9_]*)\s*\(/g)].map((m) => m[1]))];
</script>

<svelte:head><title>Reference · Zue</title></svelte:head>

<h1>Reference</h1>
<p class="lead">Pick what you want to do. Every function is listed under its topic, so you can see the names before you open a page.</p>

<div class="cats">
  {#each ref.categories as c}
    <section>
      <h2><a href="{base}/reference/{c.slug}/">{c.title}</a></h2>
      <p class="blurb">{c.blurb}</p>
      <p class="names">
        {#each c.entries as e}
          {#each names(e.sig) as n}<a href="{base}/reference/{c.slug}/#{e.id}">{n}</a>{' '}{/each}
        {/each}
      </p>
    </section>
  {/each}
</div>

<h2 class="lang">The language itself</h2>
<ul class="langlist">
  <li><a href="{base}/reference/keywords/">Keywords</a> <span>the reserved words</span></li>
  <li><a href="{base}/reference/operators/">Operators</a> <span>arithmetic, comparison, logic, and their order</span></li>
  <li><a href="{base}/reference/error-codes/">Error codes</a> <span>what each E-number means</span></li>
  <li><a href="{base}/reference/commands/">Commands</a> <span>zue run, build, check and the rest</span></li>
  <li><a href="{base}/reference/environment/">Environment variables</a> <span>switches for the collector and the compiler</span></li>
</ul>

<style>
  .lead { max-width: 56ch; font-size: 1.15rem; margin: 1rem 0 2.4rem; }
  .cats { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 2.5rem; }
  section { border-top: var(--line) solid var(--ink); padding: 1rem 0 1.4rem; }
  h2 { font-size: 1.4rem; text-transform: none; font-stretch: 108%; }
  h2 a { text-decoration: none; }
  .blurb { margin: 0.3rem 0 0.7rem; color: var(--mute); }
  .names { margin: 0; display: flex; flex-wrap: wrap; gap: 0.35rem 0.5rem; }
  .names a {
    font-family: var(--mono);
    font-size: 0.86rem;
    text-decoration: none;
    border: 2px solid var(--ink);
    background: var(--slab);
    color: var(--ink);
    padding: 0.05rem 0.4rem;
  }
  .names a:hover { background: var(--ink); color: var(--paper); }
  .lang { margin-top: 2.4rem; border-top: var(--line) solid var(--ink); padding-top: 1rem; }
  .langlist { list-style: none; padding: 0; margin: 1rem 0 0; max-width: 40rem; }
  .langlist li { padding: 0.5rem 0; border-bottom: 2px solid var(--ink); display: flex; gap: 1rem; flex-wrap: wrap; }
  .langlist a { font-weight: 800; }
  .langlist span { color: var(--mute); }
  @media (max-width: 52rem) { .cats { grid-template-columns: 1fr; } }
</style>
