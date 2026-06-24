<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  // A 64 KB page cut into slots of one size class. used: slots handed out, live: slots that survived.
  let { size, slots, used, live } = $props();
</script>

<div class="page">
  <span class="size">{size} B</span>
  <div class="grid" style="--n: {slots}">
    {#each Array.from({ length: slots }) as _, i}
      <i class:live={i < live} class:dead={i >= live && i < used}></i>
    {/each}
  </div>
  <span class="meta">{used} of {slots} handed out, {live} live</span>
</div>

<style>
  .page { display: grid; grid-template-columns: 5rem 1fr auto; gap: 0.8rem; align-items: center; margin: 0.6rem 0; font-family: var(--mono); font-size: 0.78rem; }
  .size { font-weight: 700; }
  .grid { display: grid; grid-template-columns: repeat(var(--n), 1fr); border: var(--line) solid var(--ink); background: var(--slab); box-shadow: var(--shadow-sm); height: 2rem; }
  i { border-right: 2px solid var(--ink); display: block; }
  i:last-child { border-right: 0; }
  i.live { background: var(--blue); }
  i.dead { background: repeating-linear-gradient(135deg, var(--ink) 0 3px, transparent 3px 6px); }
  .meta { color: var(--mute); }
  @media (max-width: 40rem) { .page { grid-template-columns: 1fr; } }
</style>
