<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  // Horizontal bars. items: [{ label, value, note, tone }]. Every bar is scaled to the largest value.
  let { items, unit = '' } = $props();
  const max = $derived(Math.max(...items.map((i) => i.value)));
</script>

<div class="bars">
  {#each items as it}
    <div class="row">
      <span class="label">{it.label}</span>
      <div class="rail"><div class="fill {it.tone ?? ''}" style="width: {(it.value / max) * 100}%"></div></div>
      <span class="val">{it.value}{unit}</span>
      {#if it.note}<span class="note">{it.note}</span>{/if}
    </div>
  {/each}
</div>

<style>
  .bars { margin: 1.6rem 0; max-width: 46rem; font-family: var(--mono); font-size: 0.82rem; }
  .row { display: grid; grid-template-columns: 11rem 1fr 6.5rem; gap: 0.7rem; align-items: center; margin-bottom: 0.55rem; }
  .label { font-weight: 700; }
  .rail { border: var(--line) solid var(--ink); background: var(--slab); height: 1.5rem; }
  .fill { height: 100%; background: var(--ink); }
  .fill.blue { background: var(--blue); }
  .fill.hazard { background: var(--hazard); }
  .val { font-weight: 700; }
  .note { grid-column: 2 / 4; color: var(--mute); margin-top: -0.35rem; font-size: 0.74rem; }
  @media (max-width: 40rem) { .row { grid-template-columns: 1fr 5rem; } .label { grid-column: 1 / 3; } .rail { grid-column: 1; } }
</style>
