<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Link from '$lib/components/Link.svelte';
</script>

<svelte:head><title>The garbage collector: an overview · Zue</title></svelte:head>

<LessonHead title="The garbage collector: an overview" lead="What kind of collector Zue has and what it looks at. The next pages go into each part." />

<p>
  The collector is called <strong>Hush</strong>. It is a conservative, non-moving mark-and-sweep collector with a
  snapshot-at-the-beginning write barrier. It lives in <code>compiler/runtime/zue_gc.zu</code>. It needs no type maps from the
  compiler: it treats every aligned word it scans as a possible pointer.
</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Word</th><th>What it means here</th></tr></thead>
    <tbody>
      <tr><td>Conservative</td><td>A stale integer that looks like an address can keep an object alive longer than needed. It can never free a live object, as long as every pointer is kept in a scanned place: the stack, the registers, the data segment, a registered range, or a reachable heap object</td></tr>
      <tr><td>Non-moving</td><td>An object keeps its address for its whole life. That is what makes conservative scanning safe, and it means there is no compaction. Fragmented pages are reused through their free lists</td></tr>
      <tr><td>Mark and sweep</td><td>Find what is reachable, then reclaim everything else</td></tr>
      <tr><td>Snapshot at the beginning</td><td>A cycle sees the heap as it was when the cycle began. A write barrier keeps that promise while the program changes things</td></tr>
      <tr><td>Concurrent marking</td><td>A second thread, the GC thread, does the marking. The program thread keeps running</td></tr>
    </tbody>
  </table>
</div>

<h2>What it scans</h2>

<ol>
  <li>The data segment: all module-level variables and constants of the program and the runtime.</li>
  <li>Every registered root range: the <code>alloc()</code> buffers from <Link href="/learn/unsafe/">unsafe</Link>.</li>
  <li>The machine stack of the thread that runs the program, and the registers, spilled to the stack first.</li>
  <li>The stacks of the <Link href="/internals/blue-threads/">blue threads</Link> that are away, from the stack pointer each saved when it gave up the processor, and the registers they saved.</li>
</ol>

<p>
  Anything that holds a heap pointer must be reachable from one of those, or from a heap object that is.
  The collector treats an interior pointer as a hit, and every allocation is one byte larger than requested, so a pointer
  just past the end of an object still points inside it.
</p>
