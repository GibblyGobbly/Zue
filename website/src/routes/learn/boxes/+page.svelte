<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>box · Learn Zue</title></svelte:head>

<LessonHead title="box" lead="A buffer of bytes with an owner." />

<Example id="box-basic" />

<ul>
  <li>Bytes are ints from 0 to 255. Negative indexes count from the end. <code>buf.len</code> and <code>len(buf)</code> give the size.</li>
  <li>With a size written in the source (<code>box[16]</code>) the bytes live in the function's own stack frame, so making the box costs no allocation. With a variable size, the bytes come from the C heap. Either way a table of 4096 handles tracks the live boxes, and freed slots are reused.</li>
  <li>A <code>box</code> is a handle that carries a generation number. Freeing it bumps the number, so a reused slot never brings back an old handle.</li>
</ul>

<h2>Using a box after it is freed</h2>

<Example id="box-use-after-free" shown />

<h2>A box must not outlive its scope</h2>

<Example id="box-escape" shown />

<div class="table-scroll">
  <table>
    <thead><tr><th>Rule</th><th>Error</th></tr></thead>
    <tbody>
      <tr><td>Size from 1 to 4096 bytes</td><td><code>box size must be between 1 and 4096 bytes</code></td></tr>
      <tr><td>At most 4096 boxes live at once</td><td><code>box allocation failed: more than 4096 boxes are live at once</code></td></tr>
      <tr><td>Index from 0 to len - 1 (or negative)</td><td><code>box index 2 is out of bounds for a box of 2 bytes</code></td></tr>
      <tr><td>Bytes are 0 to 255</td><td><code>box bytes must be integers from 0 to 255</code></td></tr>
      <tr><td>No use after free, double free</td><td><code>box was already freed (use-after-free)</code>, <code>(double free)</code></td></tr>
      <tr><td>A box must not outlive its scope</td><td>a box cannot be returned from a function, stored in a list or map, or assigned to a global from inside a function</td></tr>
    </tbody>
  </table>
</div>

<h2>Giving a box a longer life</h2>

<p>
  Put it in a <code>template</code>. The template then owns the box, and the box lives as long as the template. A template
  that takes a stack box copies its bytes to the heap, so the box stays valid after the function returns.
</p>

<Example id="box-owned" />

<Callout kind="note" title="assigning a box copies">
  <p>
    <code>let b = a</code> copies the bytes of a box. Passing a box to a function lends it. Boxes may not be created inside
    <code>unsafe</code> blocks.
  </p>
</Callout>
