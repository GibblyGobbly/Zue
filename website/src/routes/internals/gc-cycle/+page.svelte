<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import CycleLanes from '$lib/components/CycleLanes.svelte';
</script>

<svelte:head><title>One collection cycle · Zue</title></svelte:head>

<LessonHead title="One collection cycle" lead="What the program thread and the collector thread do, step by step, and the write barrier." />

<h2>One cycle</h2>

<CycleLanes />

<ol>
  <li><strong>Start.</strong> The program thread marks the data segment and its own stack and registers. That is the snapshot. It takes about 25 microseconds. The <code>alloc()</code> buffers and the parked blue thread stacks are part of the snapshot too, but they are scanned in slices of 256 KB, one slice per collector step, and the cycle cannot end before the last slice.</li>
  <li><strong>Marking.</strong> The GC thread scans from its mark stack while the program runs. New objects are allocated already marked, so they survive the cycle. Empty pages are not reused while a cycle marks.</li>
  <li><strong>Write barrier.</strong> While a cycle marks, any code about to overwrite a pointer inside a heap object first marks the object that pointer leads to, and queues it. Without this, an object the program moves out of a heap location and holds only in a local could be freed.</li>
  <li><strong>Steps.</strong> After every 8 KB the program allocates, its thread hands over its batch and asks whether the GC thread has run dry.</li>
  <li><strong>End of marking.</strong> When the GC thread has nothing left and nothing was handed over, the marks are final. The boxes of dead templates are freed and the sweep is set up. A few microseconds.</li>
  <li><strong>Sweep.</strong> Each step sweeps pages for up to 50 microseconds and returns. The allocator only ever sees swept pages.</li>
</ol>

<h3>Where the barrier is applied</h3>

<div class="table-scroll">
  <table>
    <thead><tr><th>Place</th><th>How</th></tr></thead>
    <tbody>
      <tr><td>Every value cell written by the runtime</td><td><code>lv_wb_cell</code> before the write</td></tr>
      <tr><td>List items pointer, map entries pointer, map index pointer, map entry key</td><td><code>lv_wb_word</code> before the store</td></tr>
      <tr><td>Map rehash, list <code>remove</code>, sort copy-back</td><td><code>lv_wb_range</code> over the cells that are overwritten or moved</td></tr>
      <tr><td>Compiled assignment to a captured variable</td><td>the compiler emits a call to <code>lv_wb_cell</code></td></tr>
    </tbody>
  </table>
</div>

<p>
  Not needed: stores to the stack and to globals (scanned at the start of the cycle), initial stores into a new object (its old
  contents are zero), and dense lists, strings and box bytes (they hold no heap pointers). A new store of a pointer into a heap
  object must call a barrier function, and the tests fail when one is missing.
</p>
