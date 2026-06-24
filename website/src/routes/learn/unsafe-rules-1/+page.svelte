<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>unsafe rules 1 to 5 · Learn Zue</title></svelte:head>

<LessonHead title="unsafe rules 1 to 5" lead="A pointer cannot point at a pointer, leave its block, run off the end, outlive its memory or come from a temporary." />

<h2>The first five rules</h2>

<p>
  Rules are checked when the operation runs, except R6, which is a compile-time error. A violation stops the program
  with exit status 1. Together the rules say three things: a pointer never outlives its block (R1, R2, R5); every access
  stays inside a live allocation (R3, R4, R7, R8); and nothing turns a pointer into another kind of value, except its
  address as an int (R9). R10 makes sure memory is given back.
</p>

<h3>R1: No pointer-to-pointer through address_of()</h3>
<Example id="unsafe-r1" shown />

<h3>R2: A pointer stays inside the unsafe block that made it</h3>
<Example id="unsafe-r2" shown />

<h3>R3: ptr_offset() cannot go out of bounds</h3>
<Example id="unsafe-r3" shown />

<h3>R4: No use after free and no double free</h3>
<Example id="unsafe-r4" shown />

<h3>R5: address_of() only works on named values, inside unsafe</h3>
<Example id="unsafe-r5" shown />


<Callout kind="note" title="what R2 also covers">
  <p>
    The same message appears for <code>return buf</code> inside the block, for assigning a pointer to a global, and with the
    message <code>pointers cannot be stored inside GC-managed values</code> for <code>[buf]</code> or <code>{'{"k": buf}'}</code>.
    A function that returns a pointer it made returns it into the block that called it.
  </p>
</Callout>
