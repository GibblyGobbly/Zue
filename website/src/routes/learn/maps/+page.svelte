<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Maps · Learn Zue</title></svelte:head>

<LessonHead title="Maps" lead="Look up a value by a text key." />

<h2>Maps</h2>

<p>
  Map keys are strings. <code>m["k"]</code> and <code>m.k</code> read a key, and <code>m["k"] = v</code> and
  <code>m.k = v</code> write one.
</p>

<Example id="maps-basics" />

<div class="table-scroll">
  <table>
    <thead><tr><th>Function</th><th>Effect</th></tr></thead>
    <tbody>
      <tr><td><code>map_set(m, key, v)</code></td><td>Insert or replace</td></tr>
      <tr><td><code>map_get(m, key)</code></td><td>The value, or <code>null</code></td></tr>
      <tr><td><code>map_has(m, key)</code></td><td><code>true</code> if present</td></tr>
      <tr><td><code>map_delete(m, key)</code></td><td>Remove. <code>true</code> if the key existed</td></tr>
      <tr><td><code>map_keys(m)</code>, <code>map_values(m)</code></td><td>Lists of keys or values</td></tr>
      <tr><td><code>map_items(m)</code></td><td>A list of <code>[key, value]</code> pairs</td></tr>
    </tbody>
  </table>
</div>
