<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Closures, map, filter and reduce · Learn Zue</title></svelte:head>

<LessonHead title="Closures, map, filter and reduce" lead="A function can remember the variables around it, and you can hand functions to other functions." />

<h2>Closures</h2>

<p>
  A function remembers the variables it was made next to. Each call to <code>make_counter</code> makes a fresh
  <code>count</code>.
</p>

<Example id="func-closure" />

<h2>map, filter, reduce</h2>

<Example id="func-higher" />

<p>
  <code>reduce</code> needs all three arguments: the list, the function and the starting value. All three return new
  values and leave the list alone.
</p>
