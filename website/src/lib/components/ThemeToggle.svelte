<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { onMount } from 'svelte';
  import { theme, loadTheme, setTheme } from '$lib/theme.svelte.js';

  const modes = ['auto', 'light', 'dark'];
  onMount(loadTheme);
</script>

<div class="toggle" role="group" aria-label="Colour theme">
  {#each modes as m}
    <button type="button" class:on={theme.mode === m} aria-pressed={theme.mode === m} onclick={() => setTheme(m)}>{m}</button>
  {/each}
</div>

<style>
  .toggle {
    display: inline-flex;
    border: var(--line) solid var(--ink);
    background: var(--slab);
  }
  button {
    font-family: var(--mono);
    font-size: 0.72rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    background: transparent;
    color: var(--ink);
    border: 0;
    padding: 0.32rem 0.55rem;
  }
  button + button { border-left: 2px solid var(--ink); }
  button:hover { background: var(--ink); color: var(--paper); }
  button.on { background: var(--blue); color: var(--blue-ink); }
</style>
