<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  // The 16-byte cell that holds every Zue value, drawn to scale: 8 bytes of tag, 8 bytes of payload.
  let { rows = [] } = $props();
</script>

<div class="cells" role="img" aria-label="Value cells: an 8-byte tag and an 8-byte payload">
  {#each rows as r}
    <div class="row">
      <span class="label">{r.label}</span>
      <span class="tag">{r.tag}</span>
      <span class="pay" class:ptr={r.ptr}>{r.payload}</span>
      {#if r.points}<span class="to">&rarr; {r.points}</span>{/if}
    </div>
  {/each}
  <div class="scale"><span>8 bytes</span><span>8 bytes</span></div>
</div>

<style>
  .cells { margin: 1.6rem 0; max-width: 40rem; font-family: var(--mono); font-size: 0.85rem; }
  .row { display: grid; grid-template-columns: 6.5rem 6rem 1fr auto; align-items: stretch; margin-bottom: 0.45rem; }
  .label { padding: 0.4rem 0.5rem 0.4rem 0; font-weight: 700; }
  .tag, .pay { border: var(--line) solid var(--ink); background: var(--slab); padding: 0.4rem 0.6rem; }
  .tag { background: var(--ink); color: var(--paper); border-right: 0; text-align: center; font-weight: 700; }
  .pay.ptr { background: var(--blue); color: var(--blue-ink); }
  .to { padding: 0.4rem 0 0.4rem 0.7rem; color: var(--mute); }
  .scale { display: grid; grid-template-columns: 6.5rem 6rem 1fr; font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.08em; color: var(--mute); }
  .scale span:first-child { grid-column: 2; text-align: center; }
  .scale span:last-child { grid-column: 3; padding-left: 0.6rem; }
</style>
