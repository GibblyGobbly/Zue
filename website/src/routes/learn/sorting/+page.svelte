<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Sorting and shuffling · Learn Zue</title></svelte:head>

<LessonHead title="Sorting and shuffling" lead="Five ways to put a list in order or mix it up." />

<h2>The sorting functions</h2>

<Example id="lists-sorting" />

<div class="table-scroll">
  <table>
    <thead><tr><th>Function</th><th>What it does</th></tr></thead>
    <tbody>
      <tr><td><code>sort(list)</code></td><td>In place, ascending, stable. Numbers, strings or chars, and mixing numbers and strings is an error. A list of 256 or more non-negative ints is sorted by radix sort, with no comparisons. Anything else uses insertion sort for 16 items or fewer and merge sort above</td></tr>
      <tr><td><code>reverse(list)</code></td><td>Returns a new list in the opposite order</td></tr>
      <tr><td><code>ssort(list)</code></td><td>Stalin sort: removes every item smaller than the last one kept, so what is left is non-decreasing. Works on dense lists too</td></tr>
      <tr><td><code>shuffle(list)</code></td><td>In-place Fisher-Yates shuffle with the seeded generator, so <code>srand</code> makes it repeatable</td></tr>
      <tr><td><code>tshuffle(list)</code></td><td>The same shuffle, but with the operating system's entropy source. Cannot be repeated, and every ordering of a list of any length can occur</td></tr>
    </tbody>
  </table>
</div>

<p>
  A 128-bit generator can produce at most 2<sup>128</sup> sequences, which covers every ordering of up to 34 items.
  A seeded <code>shuffle</code> of a longer list is well mixed but cannot reach every ordering. Use
  <code>tshuffle</code> for that.
</p>
