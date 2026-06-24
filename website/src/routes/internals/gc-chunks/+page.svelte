<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
</script>

<svelte:head><title>Chunks and giving memory back · Zue</title></svelte:head>

<LessonHead title="Chunks and giving memory back" lead="Huge pages, the helper thread, and returning pages to the operating system." />

<h2>Chunks and the helper thread</h2>

<p>
  The first touch of a fresh 2 MB chunk asks the kernel for a huge page, which it must find (sometimes by compacting memory) and
  zero. On a 10 GiB heap that took up to 55 ms on the program thread, and it was the cause of every stall over 1 ms. A helper
  thread now maps, hints and touches chunks ahead of time and hands them over through a ring of 16 slots.
</p>

<p>
  The helper times each chunk it makes. A chunk that takes more than 1 ms is a spike. After 3 spikes, the chunks made from then on ask
  for no huge pages and the program carries on. The rule has no size limit, because the kernel's own documentation ties these stalls
  to fragmentation of free memory and not to the size of the heap.
</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>10 GiB request, 20 million iterations</th><th>Worst stall</th><th>Stalls over 1 ms</th></tr></thead>
    <tbody>
      <tr><td>Before (3 runs)</td><td>5.7 to 15.7 ms</td><td>58 to 635</td></tr>
      <tr><td>With the helper (5 runs)</td><td>0.32 to 1.37 ms</td><td>0 to 2</td></tr>
    </tbody>
  </table>
</div>

<h3>Giving pages back, and what it costs</h3>

<p>
  A page whose objects are all dead goes to a pool and can be reused for any size class. Pages beyond what the next cycle can allocate
  go back to the operating system with <code>madvise(MADV_DONTNEED)</code>, a few per step. A single such call on a 64 KB piece of a
  huge-page chunk was measured at 0.3 to 1.0 ms, because it splits the huge page and flushes TLBs on other cores. So a step now stops
  giving pages back after 20 microseconds. Across runs from 1 to 6 GiB this took the number of delays over 1 ms from 3 to 0, and it did
  not cure delays over 0.1 ms, which rose at three of the four sizes.
</p>
