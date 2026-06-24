<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
  import Link from '$lib/components/Link.svelte';
</script>

<svelte:head><title>Math functions · Learn Zue</title></svelte:head>

<LessonHead title="Math functions" lead="Absolute value, powers, roots and rounding, and the errors you get for input that makes no sense." />

<p>
  Arguments must be numbers (an int or a float). Anything else is a <code>Type Error</code> such as
  <code>sqrt() argument 1 must be a number, got string</code>. A call outside the function's domain is an
  <code>Argument Error</code>, and a float result that is too large is a <code>Runtime Error</code>
  (<code>float overflow in exp()</code>).
</p>

<h2>Common functions</h2>

<Example id="math-basics" />

<div class="table-scroll">
  <table>
    <thead><tr><th>Function</th><th>Notes</th></tr></thead>
    <tbody>
      <tr><td><code>abs(x)</code>, <code>sign(x)</code></td><td><code>sign</code> gives <code>-1</code>, <code>0</code> or <code>1</code></td></tr>
      <tr><td><code>min(a, b)</code>, <code>max(a, b)</code></td><td>Both ints or both floats. With a list: <code>min(list)</code>, <code>max(list)</code>, which must not be empty</td></tr>
      <tr><td><code>sum(list)</code>, <code>mean(list)</code></td><td>Ints raise <code>integer overflow in 'sum'</code>. Floats use a compensated sum, so <code>sum([1.0, 1e100, 1.0, -1e100])</code> is <code>2.0</code>. <code>mean</code> is always a float</td></tr>
      <tr><td><code>gcd(a, b)</code>, <code>lcm(a, b)</code></td><td>Never negative. <code>lcm</code> is <code>0</code> if either side is <code>0</code></td></tr>
      <tr><td><code>isqrt(n)</code></td><td>Exact integer square root. A negative <code>n</code> is an <code>Argument Error</code></td></tr>
      <tr><td><code>clamp(x, lo, hi)</code></td><td><code>lo</code> greater than <code>hi</code> is an <code>Argument Error</code></td></tr>
    </tbody>
  </table>
</div>

<h2>Powers and roots</h2>

<Example id="math-powers" />

<p>
  <code>pow</code> with two ints and a non-negative exponent gives an exact int, and
  <code>integer overflow in 'pow'</code> when it does not fit. Every other combination gives a float.
  <code>pow(0, -1)</code> is a division by zero, and a negative base with a fractional exponent is an
  <code>Argument Error</code>. <code>ln</code> and <code>log10</code> need <code>x &gt; 0</code>.
</p>

<h2>Rounding and remainders</h2>

<Example id="math-rounding" />

<Callout kind="trap" title="% is not mod">
  <p>
    <code>-7 % 3</code> is <code>-1</code>: the result takes the sign of the left side. <code>mod(-7, 3)</code> is
    <code>2</code>: the result takes the sign of the right side, which is what you want for wrapping around.
    <code>floor_div</code> and <code>mod</code> always satisfy <code>x == floor_div(x, y) * y + mod(x, y)</code>.
  </p>
</Callout>

<ul>
  <li><code>floor</code>, <code>ceil</code>, <code>round</code> (one argument) and <code>trunc</code> return an int. A result outside the 64-bit range is a <code>Runtime Error</code>.</li>
  <li><code>round(x, digits)</code> rounds a float to 0 to 15 places, halves away from zero. The scaling happens in binary, so <code>1.005</code> (really <code>1.00499...</code>) rounds down.</li>
  <li><code>fract</code> and <code>mod</code> on floats return floats. Zue has no negative zero.</li>
  <li><code>divmod(x, y)</code> returns <code>[floor_div, mod]</code>.</li>
</ul>

<h2>When the input is wrong</h2>

<Example id="math-domain" shown />

<p>See also <Link href="/reference/">the reference</Link> for every function on one page.</p>
