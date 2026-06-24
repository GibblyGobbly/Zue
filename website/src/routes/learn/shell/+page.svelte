<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Time, the shell and exit · Learn Zue</title></svelte:head>

<LessonHead title="Time, the shell and exit" lead="Measure time, run another program, and end yours." />

<h2>The clock, the shell, the arguments</h2>

<Example id="io-misc" />

<ul>
  <li><code>clock()</code> is monotonic time in seconds, as a float. The zero point is arbitrary, so subtract two readings.</li>
  <li><code>system(cmd)</code> runs <code>cmd</code> with the shell and returns its exit status.</li>
  <li><code>args()</code> is the list of command-line arguments after the program name.</li>
</ul>

<h2>Leaving</h2>

<p><code>exit(code)</code> flushes standard output and ends the program with that status. The default is 0.</p>

<Example id="io-exit" shown />
