<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Loops · Learn Zue</title></svelte:head>

<LessonHead title="Loops" lead="Repeat work with while and for, and make lists of numbers with range." />

<h2>while, for, for-in</h2>

<Example id="control-loops" />

<ul>
  <li><code>break</code> and <code>continue</code> work in every loop.</li>
  <li><code>for (let x in ...)</code> walks a list, a dense list or a string, one <code>char</code> at a time. A map is not walked directly: use <code>map_keys</code>, <code>map_values</code> or <code>map_items</code>.</li>
  <li>Each iteration has a fresh scope. The closures in the example captured 0, 1 and 2, not three copies of the last value. A variable declared <em>before</em> the loop (<code>for (k = 0; ...)</code>) is one variable, and stays shared.</li>
</ul>

<h2>range</h2>

<Example id="control-range" />

<p>
  <code>range(end)</code>, <code>range(start, end)</code> and <code>range(start, end, step)</code> build a list of
  ints. The end is not included, <code>step</code> may be negative, and it must not be 0.
</p>
