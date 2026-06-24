<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Printing · Learn Zue</title></svelte:head>

<LessonHead title="Printing" lead="print, text with slots, debug and assert." />



<h2>The printing family</h2>

<Example id="io-print" />

<ul>
  <li><code>print</code> and <code>input</code> are ordinary functions, so <code>let p = print</code> works.</li>
  <li>A string with <code>{'{}'}</code> slots followed by values fills each slot, in order, and prints one line.</li>
  <li>Values print as: ints in decimal, floats with up to six significant digits, <code>true</code> / <code>false</code>, <code>null</code>, lists as <code>[1, 2]</code> (strings inside a list are not quoted), maps as <code>{'{"key": value}'}</code>.</li>
  <li><code>debug(v)</code> prints <code>value = &lt;v&gt;</code> to the terminal and returns <code>v</code> unchanged, so it can wrap an expression. <code>assert(cond)</code> stops the program with <code>Assertion failed</code> when <code>cond</code> is false.</li>
</ul>
