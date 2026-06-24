<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Recursion and defer · Learn Zue</title></svelte:head>

<LessonHead title="Recursion and defer" lead="A function that calls itself, and a way to run cleanup when a function ends." />

<h2>Recursion</h2>

<Example id="func-recursion" />

<p>
  Recursion is limited to 100000 nested calls. Past that the program stops with
  <code>stack overflow: recursion is too deep</code>, and the error shows the first calls and the last ones with the count
  in between. See <a href="../../internals/memory/">where values live</a> for the stack.
</p>

<Example id="memory-limits" shown />

<h2>defer</h2>

<p>
  <code>defer(call(...))</code> runs the call when the current scope exits, for any exit (<code>return</code>,
  <code>break</code>, <code>continue</code>, or falling off the end), in reverse order. The call expression is captured
  at once. It is the usual way to close a file.
</p>

<Example id="func-defer" />

<p>
  A function whose name is <code>main</code> and takes no arguments runs on its own after the top level. Inside
  <code>unsafe</code> blocks, <code>defer(ptr)</code> frees a pointer instead (see <a href="../unsafe/">unsafe</a>).
</p>
