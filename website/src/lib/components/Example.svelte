<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { getExample, runExample, strip } from '$lib/runner.js';
  import Editor from './Editor.svelte';
  import Terminal from './Terminal.svelte';

  // A program that can be edited and run. Its output was recorded from the real compiler.
  // shown: show the recorded output at once, without waiting for RUN.
  let { id, title = '', shown = false } = $props();
  const rec = getExample(id);
  const names = Object.keys(rec.files);
  const fresh = () => Object.fromEntries(names.map((n) => [n, strip(rec.files[n])]));
  let files = $state(fresh());
  let active = $state(names[0]);
  let result = $state(shown ? { stdout: rec.stdout, stderr: rec.stderr, status: rec.status, source: 'recorded' } : null);
  let running = $state(false);
  const command = `${Object.entries(rec.env ?? {}).map(([k, v]) => `${k}=${v} `).join('')}zue run main.zu`;
  const changed = $derived(names.some((n) => files[n] !== strip(rec.files[n])));

  async function run() {
    running = true;
    result = await runExample(id, files);
    running = false;
  }

  function reset() {
    files = fresh();
    result = null;
  }
</script>

<section class="ex">
  <div class="bar">
    {#if names.length > 1}
      <div class="tabs" role="tablist">
        {#each names as n}
          <button type="button" role="tab" aria-selected={active === n} class:on={active === n} onclick={() => (active = n)}>{n}</button>
        {/each}
      </div>
    {:else}
      <span class="file">{title || names[0]}</span>
    {/if}
    <div class="actions">
      {#if changed}<button type="button" class="mini" onclick={reset}>reset</button>{/if}
      <button type="button" class="mini go" onclick={run} disabled={running}>run</button>
    </div>
  </div>
  <div class="editor"><Editor bind:value={files[active]} label={active} /></div>
  <Terminal {command} {result} {running} />
</section>

<style>
  .ex { margin: 1.8rem 0; }
  .bar {
    display: flex;
    align-items: stretch;
    justify-content: space-between;
    background: var(--ink);
    color: var(--paper);
    border: var(--line) solid var(--ink);
    border-bottom: 0;
  }
  .file { font-family: var(--mono); font-size: 0.78rem; font-weight: 700; padding: 0.35rem 0.8rem; letter-spacing: 0.04em; }
  .tabs { display: flex; flex-wrap: wrap; }
  .tabs button {
    font-family: var(--mono);
    font-size: 0.78rem;
    font-weight: 700;
    background: transparent;
    color: var(--paper);
    border: 0;
    border-right: 2px solid var(--paper);
    padding: 0.35rem 0.8rem;
  }
  .tabs button.on { background: var(--blue); color: var(--blue-ink); }
  .actions { display: flex; }
  .mini {
    font-family: var(--mono);
    font-size: 0.78rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    background: transparent;
    color: var(--paper);
    border: 0;
    border-left: 2px solid var(--paper);
    padding: 0 1rem;
  }
  .mini:hover { background: var(--paper); color: var(--ink); }
  .mini.go { background: var(--blue); color: var(--blue-ink); }
  .mini.go:hover { background: var(--hazard); color: #111110; }
  .mini:disabled { opacity: 0.5; }
  .editor { border: var(--line) solid var(--ink); border-bottom: 0; box-shadow: var(--shadow); position: relative; z-index: 1; }
</style>
