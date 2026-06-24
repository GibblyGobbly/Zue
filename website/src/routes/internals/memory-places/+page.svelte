<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Callout from '$lib/components/Callout.svelte';
  import Link from '$lib/components/Link.svelte';
</script>

<svelte:head><title>Stack, heap and limits · Zue</title></svelte:head>

<LessonHead title="Stack, heap and limits" lead="Where each kind of value lives, who frees it, and the limits." />

<h2>The call stack</h2>

<p>
  A program runs on its own thread with a 1 GiB stack, so deep recursion works. If the system will not give that much address
  space (for example under <code>ulimit -v</code>), the runtime tries 256 MiB, 64 MiB and 16 MiB. A call nested more than
  100000 deep stops with <code>stack overflow: recursion is too deep</code>, and running out of stack earlier gives the same
  error instead of a crash.
</p>

<h2>Boxes and blocs</h2>

<p>
  <code>box[n]</code> makes a zeroed buffer of 1 to 4096 bytes outside the collected heap. With a size written in the source
  the bytes live in the function's own frame. A table of 4096 handles tracks the live boxes. A box is freed when its scope
  ends, when you call <code>free(box)</code> once, or when the template that owns it is collected. A bloc is a record of
  up to 64 bytes that lives on the heap like any small object.
</p>

<h2>Raw memory</h2>

<p>
  Inside <code>unsafe</code> you allocate cells with <code>alloc(n)</code>. Nothing collects them, and the ten rules in
  <Link href="/learn/unsafe/">unsafe</Link> check every access. The collector does scan these buffers, so a Zue value stored in
  one stays alive.
</p>

<h2>Limits</h2>

<div class="table-scroll">
  <table>
    <thead><tr><th>Limit</th><th>Value</th><th>Result</th></tr></thead>
    <tbody>
      <tr><td>Call depth</td><td>100000</td><td><code>stack overflow: recursion is too deep</code></td></tr>
      <tr><td>Stack</td><td>1 GiB (less when address space is limited)</td><td>the same error</td></tr>
      <tr><td>One allocation</td><td>64 TiB</td><td><code>Runtime Error: out of memory</code></td></tr>
      <tr><td>Items in one list or dense list</td><td>2<sup>42</sup></td><td><code>Runtime Error: out of memory</code></td></tr>
      <tr><td>Box size</td><td>1 to 4096 bytes</td><td><code>box size must be between 1 and 4096 bytes</code></td></tr>
      <tr><td>Live boxes</td><td>4096</td><td><code>box allocation failed: more than 4096 boxes are live at once</code></td></tr>
      <tr><td>Bloc size</td><td>64 bytes</td><td><code>bloc exceeds the cache-line size limit (64 bytes)</code></td></tr>
      <tr><td>Integer</td><td>64-bit signed</td><td><code>integer overflow in '+'</code> (and <code>-</code>, <code>*</code>, ...)</td></tr>
    </tbody>
  </table>
</div>

<Callout kind="note" title="files">
  <p>
    An open file is an object holding a C file handle. The collector does not close files. A handle that is never closed
    stays open until the program exits, so close it, or use <code>defer(close(f))</code>.
  </p>
</Callout>

<p>
  Who finds the garbage, and how it does it without stopping the program, is the next page:
  <Link href="/internals/gc/">The garbage collector</Link>.
</p>
