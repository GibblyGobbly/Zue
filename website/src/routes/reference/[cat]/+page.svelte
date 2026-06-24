<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { base } from '$app/paths';
  import ref from '$lib/generated/reference.json';
  import Rich from '$lib/components/Rich.svelte';

  let { data } = $props();
  const cat = $derived(ref.categories.find((c) => c.slug === data.cat));
</script>

<svelte:head><title>{cat.title} · Reference · Zue</title></svelte:head>

<h1>{cat.title}</h1>
<p class="lead">{cat.blurb} <a href="{base}{cat.lesson}">Read the tutorial page</a>.</p>

{#each cat.entries as e, i}
  {#if e.group && (i === 0 || cat.entries[i - 1].group !== e.group)}
    <h2 class="group">{e.group}</h2>
  {/if}
  <article class="entry" id={e.id}>
    <h3><a class="perma" href="#{e.id}" aria-label="Link to {e.id}">#</a><Rich text={e.sig} /></h3>
    <p class="desc"><Rich text={e.desc} /></p>
    {#if e.example}<p class="eg"><span>Example</span> <Rich text={e.example} /></p>{/if}
  </article>
{/each}

<style>
  h1 { font-size: clamp(2.2rem, 5vw, 3.4rem); }
  .lead { max-width: 56ch; font-size: 1.1rem; margin: 0.9rem 0 2rem; }
  .group { font-size: 1.3rem; margin: 2.4rem 0 0.4rem; }
  .entry { border-top: 2px solid var(--ink); padding: 1rem 0.8rem 1.1rem; scroll-margin-top: 5.5rem; }
  .entry:target { background: color-mix(in srgb, var(--blue) 16%, transparent); box-shadow: inset 8px 0 0 var(--blue); }
  .entry:hover { background: var(--slab); }
  h3 { font-family: var(--mono); font-size: 1.05rem; font-weight: 700; display: flex; flex-wrap: wrap; gap: 0.3rem 0.5rem; align-items: baseline; }
  h3 :global(code) { font-size: 1rem; }
  .perma { text-decoration: none; color: var(--mute); font-weight: 700; }
  .perma:hover { color: var(--blue); }
  .desc { margin: 0.5rem 0 0; max-width: 70ch; }
  .eg { margin: 0.5rem 0 0; font-size: 0.92rem; }
  .eg span { font-family: var(--mono); font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; margin-right: 0.4rem; background: var(--ink); color: var(--paper); padding: 0.05rem 0.4rem; }
</style>
