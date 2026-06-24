<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>Numbers · Learn Zue</title></svelte:head>

<LessonHead title="Numbers" lead="Whole numbers, decimals, and what happens when a number gets too big." />

<h2>Numbers</h2>

<p>
  Integers are 64-bit. Write them in decimal, hex (<code>0xFF</code>), binary (<code>0b1010</code>) or with
  underscores (<code>1_000_000</code>). Floats take a point or an exponent: <code>3.14</code>, <code>1e3</code>,
  <code>2.5e-4</code>.
</p>

<Example id="numbers" />

<ul>
  <li><code>/</code> follows the types: two ints give an int that truncates toward zero, and any float makes it a float.</li>
  <li><code>%</code> takes the sign of the left side, and also works on floats.</li>
  <li><code>**</code> is the power operator. It is right-associative, so <code>2 ** 3 ** 2</code> is 512.</li>
  <li>Bitwise operators <code>&amp; | ^ &lt;&lt; &gt;&gt; ~</code> are for ints only and bind tighter than comparisons, unlike C.</li>
</ul>

<Callout kind="trap" title="print with several arguments">
  <p>
    That last <code>print</code> had six arguments and produced six lines: <code>print</code> puts each argument on
    its own line.
  </p>
</Callout>

<h2>How decimals print</h2>

<p>
  A float prints with up to six significant digits and always shows that it is a float. For more, use
  <code>fixed(x, decimals)</code> or <code>to_string(x, digits)</code>.
</p>

<Example id="numbers-float" />

<h2>Overflow is an error</h2>

<p>
  Integer arithmetic never wraps around. The result that does not fit in 64 bits is a run-time error, with a hint.
</p>

<Example id="overflow" shown />

<Callout kind="rule" title="calculations that have no answer">
  <p>
    Some calculations have no sensible result, such as the square root of -1 or a number too large to store. Zue stops with an
    error message and does not carry on with a made-up value. There is no special "not a number" value.
  </p>
  <p>
    A function that fails gives an error. It does not return <code>null</code>, <code>0</code> or <code>-1</code> to say so.
    Whole numbers and decimals do not mix by accident, and a condition must be <code>true</code> or <code>false</code>:
    <code>if (5)</code> is an error, so write <code>if (x != 0)</code>.
  </p>
</Callout>
