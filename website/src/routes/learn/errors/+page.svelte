<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Reading an error · Learn Zue</title></svelte:head>

<LessonHead title="Reading an error" lead="What each part of a Zue error message means." />

<Example id="errors-type" shown />

<div class="table-scroll">
  <table>
    <thead><tr><th>Part</th><th>Meaning</th></tr></thead>
    <tbody>
      <tr><td><code>Type Error</code></td><td>The kind: Syntax, Type, Name, Index, Argument, Runtime, Assertion or Fatal Error</td></tr>
      <tr><td><code>[E0201]</code></td><td>The error code. <code>zue explain E0201</code> describes it, with an example and the fix</td></tr>
      <tr><td><code>main.zu at line 3</code></td><td>The file and the line</td></tr>
      <tr><td>The source line</td><td>With a tab shown as four spaces</td></tr>
      <tr><td><code>^^^</code></td><td>The exact text that is wrong</td></tr>
      <tr><td><code>---</code></td><td>Related text with a short note. Here, the two operands and their types</td></tr>
      <tr><td><code>Hint:</code>, <code>Note:</code></td><td>What to write instead, and an extra remark</td></tr>
    </tbody>
  </table>
</div>

<p>
  A label may point at another line. A repeated name shows where it was first declared, a wrong assignment shows where
  the variable got its type, and a call with the wrong arguments shows where the function is defined.
</p>

<h2>A missing name gets a suggestion</h2>

<Example id="errors-name" shown />

<h2>You get every error in one run</h2>

<p>
  The lexer, the parser and the type checker do not stop at the first mistake. They record it, go on, and print all of them
  in source order, followed by <code>N errors found.</code> After a syntax error the parser skips to the start of the next
  statement, so one mistake does not cause a string of false ones. At most one syntax error is reported for a line.
</p>

<Example id="errors-many" shown />

<p><code>zue check prog.zu</code> finds the lexical, syntax, type and import errors without building. It prints nothing and exits 0 when there are none.</p>
