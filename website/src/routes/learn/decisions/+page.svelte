<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>Making decisions · Learn Zue</title></svelte:head>

<LessonHead title="Making decisions" lead="if, else and switch. A condition has to be true or false." />



<h2>if, else if, else</h2>

<Example id="control-if" />

<Callout kind="rule" title="conditions are booleans">
  <p>
    <code>if</code>, <code>while</code>, <code>for</code>, <code>and</code>, <code>or</code> and <code>not</code> need a
    boolean. <code>if (5)</code> is the error <code>condition must be a boolean, got int</code>. Write
    <code>if (x != 0)</code> or <code>if (len(s) &gt; 0)</code>. <code>and</code> / <code>&amp;&amp;</code>,
    <code>or</code> / <code>||</code> and <code>not</code> / <code>!</code> short-circuit. <code>not</code> binds looser
    than a comparison and tighter than <code>and</code>.
  </p>
</Callout>

<h2>switch</h2>

<Example id="control-switch" />

<p>
  A <code>case</code> never falls through to the next one, and <code>break</code> inside a <code>switch</code> leaves
  it. Here each case returns, so no <code>break</code> is needed.
</p>
