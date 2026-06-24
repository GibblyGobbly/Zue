<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Watching the collector · Zue</title></svelte:head>

<LessonHead title="Watching the collector" lead="Environment variables and two programs to try them on." />

<h2>Watch it work</h2>

<p>
  Set <code>ZUE_RT_GC_STATS=1</code> and the program prints a summary on exit. This run was recorded with the real compiler.
</p>

<Example id="gc-stats" shown />

<p>
  The first line is the collection count, live bytes, pages, the total and longest pause, the GC thread's marking time and the
  sweep time. <code>ZUE_RT_GC_THROTTLE</code> counts the steps that were held back. <code>ZUE_RT_GC_CHUNKS</code> tells how many 2 MB chunks
  the helper had ready and how many the program thread had to make itself. A pause there is one stop of the program thread, which is
  why it is smaller than what the program sees: the benchmark times every loop iteration to find the rest.
</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Variable</th><th>Effect</th></tr></thead>
    <tbody>
      <tr><td><code>ZUE_RT_GC_STATS=1</code></td><td>Summary at exit</td></tr>
      <tr><td><code>ZUE_RT_GC_STATS=2</code></td><td>Also one line per cycle: wall time, GC thread time, bytes allocated during and before it</td></tr>
      <tr><td><code>ZUE_RT_GC_STATS=3</code></td><td>Instead, a census after every sweep: per size class the pages, slots in use and free, and how full the pages are</td></tr>
      <tr><td><code>ZUE_RT_GC_STRESS=N</code></td><td>Collect on every Nth allocation. <code>1</code> collects on every allocation. Finds missing roots</td></tr>
      <tr><td><code>ZUE_RT_GC_SLOW=N</code></td><td>The GC thread sleeps N microseconds after each piece of marking, to widen the time the two threads overlap</td></tr>
      <tr><td><code>ZUE_RT_GC_VERIFY=1</code></td><td>After each marking, walk the heap again and stop if a reachable object is not marked. Freed objects are filled with <code>0xDD</code> so a use after free shows</td></tr>
    </tbody>
  </table>
</div>

<h2>Cycles, and a big live set</h2>

<p>Two lists that point at each other are freed once nothing else refers to them. Two million of these pairs:</p>

<Example id="gc-cycles" />

<p>A live set of 300000 rows, with three million short-lived lists churning around it:</p>

<Example id="gc-live" />
