<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>Text · Learn Zue</title></svelte:head>

<LessonHead title="Text" lead="A string holds text. This page covers writing one, picking pieces out of it, and why you cannot edit it in place." />



<h2>Interpolation, escapes, indexing</h2>

<p>
  Inside a double-quoted string, <code>{'{expression}'}</code> is replaced by the text of the expression. The
  expression can contain strings of its own: <code>"{'{len("abc")}'}"</code>. To write a literal brace, use
  <code>\{'{'}</code>. A string may span lines.
</p>

<Example id="strings-basic" />

<p>
  The escapes are <code>\n \t \r \" \' \\ \{'{'} \{'}'}</code>. Any other character after a backslash is a syntax error.
  A <code>char</code> literal holds exactly one character or escape: <code>'a'</code>, <code>'\n'</code>, <code>'\0'</code>.
  Only ASCII is allowed outside strings and comments.
</p>

<Callout kind="rule" title="indexing gives a char">
  <p>
    <code>"Zue"[0]</code> is the <code>char</code> <code>'Z'</code>, and a negative index counts from the end:
    <code>"Zue"[-1]</code> is <code>'e'</code>. A <code>char</code> and a one-character string are different types:
    <code>'a' == "a"</code> is an error. Both work with <code>contains</code>, <code>index_of</code>,
    <code>starts_with</code> and <code>ends_with</code>.
  </p>
</Callout>

<h2>Slices: from 0, both ends included</h2>

<p>
  <code>x[a:b]</code> takes part of a string or a list. Positions count from 0 like indexes, and <strong>both
  ends are included</strong>. A slice never takes negative positions and never runs backwards.
</p>

<Example id="strings-slices" />

<div class="table-scroll">
  <table>
    <thead><tr><th>Rule</th><th>Result</th></tr></thead>
    <tbody>
      <tr><td><code>a</code> or <code>b</code> left out</td><td>The first or the last position</td></tr>
      <tr><td><code>a</code> is negative</td><td><code>Index Error</code></td></tr>
      <tr><td><code>b</code> is past the last index: <code>"bug"[0:3]</code></td><td><code>Index Error</code></td></tr>
      <tr><td><code>a</code> is after <code>b</code>: <code>"bug"[2:1]</code></td><td><code>Index Error</code></td></tr>
      <tr><td><code>a</code> or <code>b</code> is not an int</td><td><code>Type Error</code></td></tr>
      <tr><td>Anything but a string or a list</td><td><code>Type Error</code></td></tr>
    </tbody>
  </table>
</div>

<p>
  To take from the end, start at <code>len(x) - n</code>, as the example does for the last two items. For last to
  first, <code>reverse(x)</code> returns a new string or list and leaves <code>x</code> alone.
</p>

<h2>Strings cannot be changed</h2>

<Example id="strings-immutable" shown />

<p>
  Assigning into a string is an error. Build a new one with a function from below. Also note that <code>+</code>
  joins two strings only: <code>"a" + 1</code> is a type error, so write <code>"a{'{1}'}"</code> or
  <code>"a" + to_string(1)</code>.
</p>
