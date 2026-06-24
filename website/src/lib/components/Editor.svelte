<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { highlight } from '$lib/highlight/zue.js';

  // A text area with the highlighted code drawn underneath it, so the code can be edited in place.
  let { value = $bindable(), label = 'Zue source' } = $props();
  let back = $state();
  const lines = $derived(value.split('\n').length);
  const html = $derived(highlight(value) + '\n');

  function sync(e) {
    back.scrollTop = e.target.scrollTop;
    back.scrollLeft = e.target.scrollLeft;
  }

  function onkey(e) {
    if (e.key === 'Tab') {
      e.preventDefault();
      const t = e.target;
      const s = t.selectionStart;
      value = value.slice(0, s) + '    ' + value.slice(t.selectionEnd);
      queueMicrotask(() => t.setSelectionRange(s + 4, s + 4));
    }
  }
</script>

<div class="ed" style="--rows: {Math.min(Math.max(lines, 3), 26)}">
  <pre class="nums" aria-hidden="true">{Array.from({ length: lines }, (_, i) => i + 1).join('\n')}</pre>
  <div class="stack">
    <pre class="back" bind:this={back} aria-hidden="true">{@html html}</pre>
    <textarea
      bind:value
      onscroll={sync}
      onkeydown={onkey}
      spellcheck="false"
      autocapitalize="off"
      autocomplete="off"
      aria-label={label}
      wrap="off"
    ></textarea>
  </div>
</div>

<style>
  .ed {
    display: flex;
    background: var(--code-bg);
    color: var(--code-fg);
    height: calc(var(--rows) * 1.6 * 0.9rem + 1.6rem);
    max-height: 70vh;
  }
  .nums, .back, textarea {
    margin: 0;
    font-family: var(--mono);
    font-size: 0.9rem;
    line-height: 1.6;
    padding: 0.8rem 0;
    tab-size: 4;
  }
  .nums {
    padding-inline: 0.7rem;
    text-align: right;
    color: var(--tok-com);
    border-right: 2px solid var(--tok-com);
    user-select: none;
    overflow: hidden;
  }
  .stack { position: relative; flex: 1; min-width: 0; }
  .back, textarea {
    position: absolute;
    inset: 0;
    width: 100%;
    height: 100%;
    padding-inline: 1rem;
    white-space: pre;
    overflow: auto;
    border: 0;
    background: transparent;
  }
  .back { pointer-events: none; overflow: hidden; }
  textarea {
    color: transparent;
    caret-color: var(--code-fg);
    resize: none;
    outline-offset: -4px;
  }
  textarea::selection { background: color-mix(in srgb, var(--blue) 60%, transparent); }
</style>
