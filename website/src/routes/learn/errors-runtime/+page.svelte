<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
  import Link from '$lib/components/Link.svelte';
</script>

<svelte:head><title>Errors while a program runs · Learn Zue</title></svelte:head>

<LessonHead title="Errors while a program runs" lead="Call stacks, JSON output and crashes." />

<h2>Errors while the program runs</h2>

<p>
  A run-time error has the same shape and adds the call stack, innermost call first, with the line of each call. A long
  chain shows the first six calls, the last three, and how many were left out.
</p>

<Example id="errors-index" shown />

<Callout kind="note" title="why pass()?">
  <p>
    The compile-time checker proves what it can. In <code>errors-index</code> the list index comes through a function
    so that the checker cannot see it, and the problem surfaces at run time with the call stack.
    Runtime-error tests in the Zue repository do the same.
  </p>
</Callout>

<h2>Machine-readable errors</h2>

<div class="table-scroll">
  <table>
    <thead><tr><th>How</th><th>Output</th></tr></thead>
    <tbody>
      <tr><td><code>zue check --error-format=json prog.zu</code> (also <code>build</code>, <code>run</code>, <code>emit</code>)</td><td>One JSON object per compile error, with <code>kind</code>, <code>code</code>, <code>file</code>, <code>line</code>, <code>column</code>, <code>end_line</code>, <code>end_column</code>, <code>message</code>, <code>text</code>, <code>hint</code>, <code>labels</code>, <code>notes</code>, <code>trace</code></td></tr>
      <tr><td><code>ZUE_ERROR_FORMAT=json ./program</code></td><td>One JSON object for the run-time error, on standard error</td></tr>
    </tbody>
  </table>
</div>

<p>
  A crash (an invalid memory access or an arithmetic fault) is caught and reported as a <code>Fatal Error</code> with the
  line it happened near. The exit status is 128 plus the signal number. <code>zue build -g</code> adds line tables, so
  <code>gdb</code>, <code>lldb</code>, <code>valgrind</code> and <code>perf</code> show Zue files and lines.
</p>

<p>Every code, with its meaning, is in the <Link href="/reference/error-codes/">reference</Link>.</p>
