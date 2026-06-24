<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
  import Link from '$lib/components/Link.svelte';
</script>

<svelte:head><title>Values and variables · Learn Zue</title></svelte:head>

<LessonHead title="Values and variables" lead="The kinds of data Zue works with, and how to give a value a name." />



<h2>The types</h2>

<div class="table-scroll">
  <table>
    <thead><tr><th>Literal</th><th><code>type()</code></th></tr></thead>
    <tbody>
      <tr><td><code>42</code>, <code>-7</code> (64-bit)</td><td><code>int</code></td></tr>
      <tr><td><code>1.5</code>, <code>3.0</code></td><td><code>float</code></td></tr>
      <tr><td><code>'c'</code></td><td><code>char</code></td></tr>
      <tr><td><code>"text"</code></td><td><code>string</code></td></tr>
      <tr><td><code>true</code>, <code>false</code></td><td><code>boolean</code></td></tr>
      <tr><td><code>null</code></td><td><code>null</code></td></tr>
      <tr><td><code>[1, 2, 3]</code></td><td><code>list</code></td></tr>
      <tr><td><code>{'{"key": value}'}</code></td><td><code>map</code></td></tr>
      <tr><td><code>func(x) {'{ return x }'}</code></td><td><code>function</code></td></tr>
      <tr><td>a builtin such as <code>len</code></td><td><code>native_function</code></td></tr>
    </tbody>
  </table>
</div>

<Example id="types-tour" />

<p>
  A file handle from <code>open</code> reports <code>file</code>; the shapes from later lessons report
  <code>bloc</code>, <code>box</code> and <code>template</code>. A <code>data</code> value reports
  <code>map</code>, and a pointer inside <code>unsafe</code> reports <code>pointer</code>. Blue threads
  report <code>thread</code> and <code>channel</code>.
</p>

<h2>let, const, and changing a variable</h2>

<p>
  <code>let x = 10</code> declares a variable. <code>x = 20</code> changes it, and <code>+=</code>, <code>-=</code>,
  <code>*=</code>, <code>/=</code>, <code>%=</code>, <code>++</code> and <code>--</code> work as you would hope.
  <code>x++</code> used as a value gives the old value; <code>++x</code> gives the new one.
</p>

<Callout kind="rule" title="a variable keeps its type">
  <p>
    After <code>let x = 10</code>, the lines <code>x = "ten"</code> and <code>x = 2.5</code> are errors. A variable
    that starts as <code>null</code>, or has no value, takes the type of the first value assigned to it.
  </p>
</Callout>

<Example id="types-check" shown />

<p>
  The compiler caught that before the program ever ran, and the error points at the line and tells you where the
  variable got its type. More about this in <Link href="/learn/types/">The type checker</Link>.
</p>

<Callout kind="trap" title="const">
  <p>
    <code>const</code> marks a binding that is meant to stay fixed. Today the compiler does not reject a
    reassignment. Treat it as a promise to the reader, not as a lock.
  </p>
</Callout>
