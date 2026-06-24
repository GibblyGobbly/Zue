<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>What the compiler checks · Learn Zue</title></svelte:head>

<LessonHead title="What the compiler checks" lead="Zue checks some things before your program runs." />

<p>
  The checker looks at the main program and at imported modules. A mistake it can prove is a <code>Type Error</code> with
  the line, and the program is not built. Where it cannot tell a type (items of a plain list, the result of a function
  whose returns differ, function values, values from modules), the run-time checks still apply.
</p>

<h2>What it infers</h2>

<ul>
  <li><strong>A variable keeps its first type.</strong> A variable that starts as <code>null</code>, or has no value, takes the type of the first value assigned to it.</li>
  <li><strong>A written number adapts. A variable never converts.</strong> <code>sqrt(16)</code> and <code>2.5 * 2</code> are fine. With <code>let n = 16</code>, both <code>sqrt(n)</code> and <code>n + 1.5</code> are errors. Write <code>sqrt(float(n))</code> to convert on purpose.</li>
  <li><strong>Operators need operands of the same type.</strong> <code>"a" + 1</code>, <code>-"a"</code>, <code>1 == "a"</code> and dividing by a zero written in the source are all errors.</li>
  <li><strong>Conditions need a bool.</strong></li>
  <li><strong>Math builtins check their arguments:</strong> <code>sqrt(float)</code>, <code>pow(int, int)</code> or <code>pow(float, float)</code>, <code>floor(float)</code> giving an int, <code>rand(int)</code>.</li>
  <li><strong>Your own function is checked at each call</strong> with its parameters bound to the argument types, and the message names the call: <code>in area(int, string), called at line 3</code>.</li>
  <li><strong>A list or map literal with one item type has that element type.</strong> <code>[1, 2, 3]</code> is <code>list&lt;int&gt;</code>. After <code>let xs = [1, 2]</code>, both <code>xs[0] = "a"</code> and <code>append(xs, "a")</code> fail. A list of mixed items, or an empty one, is a plain <code>list</code> that is not checked.</li>
</ul>

<Example id="types-mixed" shown />
