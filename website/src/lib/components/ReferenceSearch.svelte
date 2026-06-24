<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { base } from '$app/paths';
  import ref from '$lib/generated/reference.json';
  import { plain } from '$lib/inline.js';

  const items = [
    ...ref.categories.flatMap((c) =>
      c.entries.map((e) => ({ label: plain(e.sig), desc: plain(e.desc), where: c.title, href: `/reference/${c.slug}/#${e.id}`, hay: (plain(e.sig) + ' ' + plain(e.desc)).toLowerCase() }))
    ),
    ...ref.errorCodes.map((e) => ({ label: e.code, desc: e.meaning, where: 'Error codes', href: `/reference/error-codes/#${e.code}`, hay: (e.code + ' ' + e.meaning).toLowerCase() }))
  ];

  let q = $state('');
  const hits = $derived.by(() => {
    const n = q.trim().toLowerCase();
    if (n.length < 1) return [];
    const starts = items.filter((i) => i.label.toLowerCase().startsWith(n));
    const rest = items.filter((i) => !i.label.toLowerCase().startsWith(n) && i.hay.includes(n));
    return [...starts, ...rest].slice(0, 12);
  });
</script>

<div class="search">
  <label for="rq">Look something up</label>
  <input id="rq" type="search" bind:value={q} placeholder="a function, a word, or an error code" autocomplete="off" />
  {#if q.trim()}
    <ul class="hits" aria-label="Search results">
      {#each hits as h}
        <li>
          <a href="{base}{h.href}" onclick={() => (q = '')}>
            <span class="what"><code>{h.label}</code><span class="where">{h.where}</span></span>
            <span class="desc">{h.desc.length > 110 ? h.desc.slice(0, 110) + '...' : h.desc}</span>
          </a>
        </li>
      {:else}
        <li class="none">Nothing matches "{q}". Try part of a name, like "str" or "file".</li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .search { position: relative; margin-bottom: 2rem; }
  label { display: block; font-family: var(--mono); font-weight: 700; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 0.4rem; }
  input {
    width: 100%;
    font-family: var(--mono);
    font-size: 1.1rem;
    padding: 0.7rem 0.9rem;
    border: var(--line) solid var(--ink);
    background: var(--slab);
    color: var(--ink);
    border-radius: 0;
    box-shadow: var(--shadow-sm);
  }
  .hits {
    list-style: none;
    margin: 0.4rem 0 0;
    padding: 0;
    border: var(--line) solid var(--ink);
    background: var(--slab);
    box-shadow: var(--shadow);
    position: absolute;
    left: 0;
    right: 0;
    z-index: 10;
    max-height: 26rem;
    overflow: auto;
  }
  li + li { border-top: 2px solid var(--ink); }
  a { display: block; padding: 0.55rem 0.9rem; text-decoration: none; color: var(--ink); }
  a:hover, a:focus-visible { background: var(--paper); box-shadow: inset 8px 0 0 var(--blue); padding-left: 1.3rem; color: var(--ink); }
  .what { display: flex; gap: 0.8rem; align-items: baseline; flex-wrap: wrap; }
  .what code { font-weight: 700; }
  .where { font-family: var(--mono); font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--mute); }
  .desc { display: block; font-size: 0.9rem; color: var(--mute); margin-top: 0.15rem; }
  .none { padding: 0.8rem 0.9rem; }
</style>
