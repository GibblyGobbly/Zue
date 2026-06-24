<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { base } from '$app/paths';
  let { prev, next } = $props();
</script>

<nav class="pn" aria-label="Previous and next">
  {#if prev}
    <a class="p" href="{base}{prev.href}/"><span>Back</span>{prev.title}</a>
  {:else}<span></span>{/if}
  {#if next}
    <a class="n" href="{base}{next.href}/"><span>Next</span>{next.title}</a>
  {/if}
</nav>

<style>
  .pn { display: flex; justify-content: space-between; gap: 1rem; margin-top: 4rem; max-width: 100%; }
  a {
    display: block;
    flex: 1;
    max-width: 22rem;
    border: var(--line) solid var(--ink);
    background: var(--slab);
    box-shadow: var(--shadow-sm);
    padding: 0.7rem 1rem;
    text-decoration: none;
    font-weight: 800;
    font-stretch: 110%;
    font-size: 1.15rem;
    line-height: 1.2;
  }
  a:hover { background: var(--blue); color: var(--blue-ink); }
  a span { display: block; font-family: var(--mono); font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.1em; opacity: 0.7; margin-bottom: 0.2rem; }
  .n { text-align: right; margin-left: auto; }
</style>
