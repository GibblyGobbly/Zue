<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Lists of numbers as vectors · Learn Zue</title></svelte:head>

<LessonHead title="Lists of numbers as vectors" lead="Add, multiply and divide whole lists of numbers at once." />

<h2>Dense lists and vector math</h2>

<p>
  A <code>dense_list</code> is a contiguous array of raw floats. It prints as <code>d[...]</code>, reports
  <code>list</code> from <code>type()</code>, has a fixed size, and does not accept <code>append</code>. The collector
  never scans it, so it costs the garbage collector nothing.
</p>

<Example id="math-vectors" />

<p>
  <code>+ - * /</code> between two lists of numbers work element by element and return a dense list. The items are
  floats even when both lists hold ints. Different lengths, a division by zero or a float overflow are errors.
  <code>vec_mul_inline(a, b)</code> multiplies in place without allocating. <code>mat_mul</code> is a plain triple
  loop on one thread, and a dimension mismatch is an <code>Argument Error</code>.
</p>
