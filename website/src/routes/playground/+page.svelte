<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import examples from '$lib/generated/examples.json';
  import Example from '$lib/components/Example.svelte';
  import { liveRunAvailable } from '$lib/runner.js';

  const ids = Object.keys(examples).sort();
  let id = $state('hello-name');
</script>

<svelte:head><title>Playground · Zue</title></svelte:head>

<div class="wrap page">
  <h1>Playground</h1>
  <p class="lead">
    Pick a program, read it, change it, press RUN.
    {#if liveRunAvailable}
      Changed code is sent to the run server.
    {:else}
      The run server is not connected yet, so the programs run from output that was recorded with the real compiler. Changing the code works as an editor; running changed code comes with the server.
    {/if}
  </p>

  <div class="pick">
    <label for="ex">Program</label>
    <select id="ex" bind:value={id}>
      {#each ids as i}<option value={i}>{i}</option>{/each}
    </select>
    <span class="n">{ids.length} programs</span>
  </div>

  {#key id}
    <Example {id} />
  {/key}
</div>

<style>
  .page { padding-block: 2.4rem 1rem; max-width: 60rem; }
  .lead { max-width: 60ch; font-size: 1.1rem; margin: 1rem 0 1.6rem; }
  .pick { display: flex; flex-wrap: wrap; gap: 0.6rem 1rem; align-items: center; margin-bottom: 0.6rem; }
  label { font-family: var(--mono); font-weight: 700; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.06em; }
  select { font-family: var(--mono); font-size: 0.95rem; padding: 0.4rem 0.6rem; border: var(--line) solid var(--ink); background: var(--slab); color: var(--ink); border-radius: 0; box-shadow: var(--shadow-sm); }
  .n { font-family: var(--mono); font-size: 0.8rem; color: var(--mute); }
</style>
