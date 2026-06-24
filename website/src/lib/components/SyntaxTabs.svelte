<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import Example from './Example.svelte';

  // tabs: [{ label, id }]. Each tab is a recorded, runnable example.
  let { tabs } = $props();
  let current = $state(0);
</script>

<div class="tabs" role="tablist" aria-label="Syntax samples">
  {#each tabs as t, i}
    <button type="button" role="tab" aria-selected={current === i} class:on={current === i} onclick={() => (current = i)}>{t.label}</button>
  {/each}
</div>
{#key current}
  <Example id={tabs[current].id} shown />
{/key}

<style>
  .tabs { display: flex; flex-wrap: wrap; gap: 0.4rem; }
  button {
    font-family: var(--mono);
    font-weight: 700;
    font-size: 0.85rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    background: var(--slab);
    color: var(--ink);
    border: var(--line) solid var(--ink);
    padding: 0.4rem 0.9rem;
  }
  button:hover { background: var(--ink); color: var(--paper); }
  button.on { background: var(--blue); color: var(--blue-ink); box-shadow: 4px 4px 0 var(--ink); }
</style>
