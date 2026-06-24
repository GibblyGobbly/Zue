<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { highlight } from '$lib/highlight/zue.js';

  // A read-only code listing. lang is "zue" for highlighting, anything else for plain text.
  let { code, file = '', lang = 'zue' } = $props();
  const text = $derived(code.replace(/\n$/, ''));
  const html = $derived(lang === 'zue' ? highlight(text) : text.replace(/&/g, '&amp;').replace(/</g, '&lt;'));
  const lines = $derived(text.split('\n').length);
</script>

<figure>
  {#if file}<figcaption>{file}</figcaption>{/if}
  <div class="scroll">
    <pre class="nums" aria-hidden="true">{Array.from({ length: lines }, (_, i) => i + 1).join('\n')}</pre>
    <pre class="src"><code>{@html html}</code></pre>
  </div>
</figure>

<style>
  figure {
    margin: 1.4rem 0;
    border: var(--line) solid var(--ink);
    box-shadow: var(--shadow);
    background: var(--code-bg);
    color: var(--code-fg);
    max-width: 100%;
  }
  figcaption {
    font-family: var(--mono);
    font-size: 0.78rem;
    font-weight: 700;
    background: var(--ink);
    color: var(--paper);
    padding: 0.25rem 0.8rem;
    letter-spacing: 0.04em;
  }
  .scroll { display: flex; overflow-x: auto; }
  pre { margin: 0; font-size: 0.9rem; line-height: 1.6; padding: 0.8rem 0; tab-size: 4; }
  .nums {
    position: sticky;
    left: 0;
    padding-inline: 0.7rem;
    text-align: right;
    color: var(--tok-com);
    background: var(--code-bg);
    border-right: 2px solid var(--tok-com);
    user-select: none;
  }
  .src { padding-inline: 1rem; flex: 1; }
  code { font-family: inherit; }
</style>
