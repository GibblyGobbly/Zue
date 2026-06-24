<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  // One collection cycle drawn as two lanes: what the program thread does and what the GC thread does.
  const prog = [
    { w: 3, t: 'start', note: 'roots, about 25 us' },
    { w: 14, t: 'runs; barrier shades overwritten pointers; a step every 8 KB', run: true },
    { w: 3, t: 'end', note: 'a few us' },
    { w: 10, t: 'runs; sweep steps of 50 us', run: true, sweep: true }
  ];
  const gc = [
    { w: 3, t: '' , idle: true },
    { w: 14, t: 'marks from the mark stack', mark: true },
    { w: 13, t: 'sleeps until the next cycle', idle: true }
  ];
</script>

<figure>
  <div class="lane"><span class="who">program thread</span>
    <div class="track">{#each prog as s}<div class="seg" class:run={s.run} class:sweep={s.sweep} style="flex: {s.w}"><b>{s.t}</b>{#if s.note}<small>{s.note}</small>{/if}</div>{/each}</div>
  </div>
  <div class="lane"><span class="who">GC thread</span>
    <div class="track">{#each gc as s}<div class="seg" class:mark={s.mark} class:idle={s.idle} style="flex: {s.w}"><b>{s.t}</b></div>{/each}</div>
  </div>
  <figcaption>Time runs left to right. The program never waits for the GC thread, except when it allocates faster than the marker can keep up.</figcaption>
</figure>

<style>
  figure { margin: 1.8rem 0; max-width: 100%; }
  .lane { display: grid; grid-template-columns: 7.5rem 1fr; gap: 0.7rem; align-items: stretch; margin-bottom: 0.7rem; }
  .who { font-family: var(--mono); font-size: 0.74rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; align-self: center; }
  .track { display: flex; border: var(--line) solid var(--ink); box-shadow: var(--shadow-sm); background: var(--slab); min-height: 4.6rem; }
  .seg { padding: 0.4rem 0.5rem; border-right: 2px solid var(--ink); display: flex; flex-direction: column; justify-content: center; gap: 0.2rem; font-size: 0.78rem; line-height: 1.25; min-width: 0; }
  .seg:last-child { border-right: 0; }
  .seg small { font-family: var(--mono); font-size: 0.68rem; opacity: 0.75; }
  .seg b { font-weight: 700; }
  .run { background: color-mix(in srgb, var(--blue) 14%, var(--slab)); }
  .sweep { background: repeating-linear-gradient(135deg, color-mix(in srgb, var(--blue) 20%, var(--slab)) 0 8px, var(--slab) 8px 16px); }
  .mark { background: var(--blue); color: var(--blue-ink); }
  .idle { background: repeating-linear-gradient(135deg, transparent 0 6px, color-mix(in srgb, var(--ink) 14%, transparent) 6px 12px); color: var(--mute); }
  figcaption { font-size: 0.88rem; color: var(--mute); max-width: 60ch; margin-top: 0.8rem; }
  @media (max-width: 40rem) { .lane { grid-template-columns: 1fr; gap: 0.3rem; } .seg b { font-size: 0.7rem; } }
</style>
