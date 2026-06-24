<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  // result: { stdout, stderr, status, source } or null before the first run.
  let { command = 'zue run main.zu', result = null, running = false } = $props();
  const sourceLabel = { recorded: 'recorded run', live: 'live run', 'needs-server': 'not run' };
</script>

<div class="term" role="region" aria-label="Program output" aria-live="polite">
  <div class="title">
    <span class="dots" aria-hidden="true"><i></i><i></i><i></i></span>
    <span>terminal</span>
    {#if result}<span class="src">{sourceLabel[result.source]}</span>{/if}
  </div>
  <pre class="screen"><span class="cmd">$ {command}</span>
{#if running}<span class="dim">running...</span>
{:else if !result}<span class="dim">press RUN</span>
{:else if result.source === 'needs-server'}<span class="warn">You changed the code. Running changed code needs the run server, which is not connected yet.
The original code runs from its recorded output. Use RESET to get it back.</span>
{:else}{#if result.stdout}{result.stdout}{/if}{#if result.stderr}<span class="err">{result.stderr}</span>{/if}<span class="status" class:bad={result.status !== 0}>exit status {result.status ?? '?'}</span>
{/if}</pre>
</div>

<style>
  .term { border: var(--line) solid var(--ink); box-shadow: var(--shadow); background: #0b0b0c; color: #e6f0e6; margin-top: -0.2rem; }
  .title {
    display: flex;
    align-items: center;
    gap: 0.7rem;
    background: var(--ink);
    color: var(--paper);
    font-family: var(--mono);
    font-size: 0.74rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    padding: 0.25rem 0.7rem;
  }
  .dots { display: inline-flex; gap: 4px; }
  .dots i { width: 9px; height: 9px; background: var(--paper); display: block; }
  .src { margin-left: auto; color: var(--paper); opacity: 0.8; }
  .screen {
    margin: 0;
    padding: 0.8rem 1rem 1rem;
    font-size: 0.88rem;
    line-height: 1.55;
    min-height: 5.5rem;
    max-height: 26rem;
    overflow: auto;
    white-space: pre-wrap;
    word-break: break-word;
  }
  .cmd { color: #8ff0c2; }
  .dim { opacity: 0.55; }
  .err { color: #ff8a66; }
  .warn { color: #ffb454; }
  .status { display: block; margin-top: 0.4rem; opacity: 0.6; }
  .status.bad { color: #ff8a66; opacity: 1; }
</style>
