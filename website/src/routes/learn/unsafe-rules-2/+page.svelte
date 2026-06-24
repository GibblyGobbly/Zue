<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Link from '$lib/components/Link.svelte';
</script>

<svelte:head><title>unsafe rules 6 to 10 · Learn Zue</title></svelte:head>

<LessonHead title="unsafe rules 6 to 10" lead="Nesting, allocation sizes, comparing pointers, casts and leaks. Then how unsafe memory meets the collector." />

<h2>The last five rules</h2>
<h3>R6: unsafe blocks cannot be nested in the source</h3>
<Example id="unsafe-r6" shown />

<h3>R7: alloc() size must be a positive integer</h3>
<Example id="unsafe-r7" shown />

<h3>R8: Ordered pointer comparisons need the same base allocation</h3>
<Example id="unsafe-r8" shown />

<h3>R9: Pointers may only be cast with int(ptr)</h3>
<Example id="unsafe-r9" shown />

<h3>R10: Every alloc() is freed before its block ends</h3>
<Example id="unsafe-r10" shown />

<h2>How this meets the garbage collector</h2>

<ul>
  <li>A buffer from <code>alloc()</code> is memory from <code>calloc</code>, not from the GC heap. The collector never frees it. Only <code>free</code> or <code>defer</code> does.</li>
  <li>It is registered as a root range, so Zue values stored in its slots stay alive while the buffer exists. The collector scans such a range in slices of 256 KB while the program runs, so a big buffer does not cause a long pause (a 976 MiB buffer: 0.23 ms worst pause).</li>
  <li>Ordinary Zue values inside an <code>unsafe</code> block are still garbage collected as usual.</li>
  <li>A raw pointer may not be stored in a list, map or other GC value (R2), so the collector never sees one.</li>
</ul>

<p>The same story from the collector's side is in <Link href="/internals/gc/">The garbage collector</Link>. The old names, once more, in use:</p>

<Example id="unsafe-aliases" />
