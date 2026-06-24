<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>Writing types down · Learn Zue</title></svelte:head>

<LessonHead title="Writing types down" lead="Type annotations, strict mode, and the speed they can buy." />

<h2>Writing the type down</h2>

<p>
  A type can follow a colon on a variable, a parameter or a field. <code>list</code> and <code>map</code> take an element
  type in angle brackets and may nest (<code>map&lt;list&lt;int&gt;&gt;</code>). The names are <code>int</code>,
  <code>float</code>, <code>bool</code>, <code>char</code>, <code>string</code>, <code>list</code>, <code>map</code>,
  <code>function</code> and the name of a <code>bloc</code> or <code>template</code>. Whole numbers in the source become
  floats where a float is wanted, so <code>let xs: list&lt;float&gt; = [1, 2]</code> holds floats.
</p>

<Example id="types-annotated" />

<p>
  Builtins with a fixed result type give it: <code>len</code> is an int, <code>split</code> is a
  <code>list&lt;string&gt;</code>, <code>range</code> is a <code>list&lt;int&gt;</code>, and <code>min</code>,
  <code>max</code> and <code>sum</code> of a <code>list&lt;int&gt;</code> are ints.
</p>

<h2>Strict mode</h2>

<Callout kind="rule" title="# strict">
  <p>
    A file whose first lines, before any code, include the comment <code># strict</code> is checked harder. Every
    parameter needs a type, and a value whose type the checker cannot tell is an error where it is used: as an operand, in
    a condition, as an argument, or as the target of an index or a field read. Writing the type
    (<code>let y: int = xs[0]</code>) is the way to say what the value is. Comparing with <code>null</code> is allowed.
  </p>
</Callout>

<Example id="types-strict" shown />

<h2>Raw values and speed</h2>

<p>
  A local variable that the checker proves to be an <code>int</code>, <code>float</code> or <code>bool</code>, that no
  nested function uses and that no <code>address_of</code> touches, is kept as a raw machine value instead of a 16-byte
  value. Expressions made only of such variables and literals are computed without type tests. The results, the errors and
  the line numbers are the same as for the general code. A value that comes from code the checker cannot see is tested
  when it is stored: <code>variable 'n' must be an int, got string</code>.
</p>
