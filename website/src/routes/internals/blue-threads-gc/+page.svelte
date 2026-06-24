<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Callout from '$lib/components/Callout.svelte';
  import Bars from '$lib/components/Bars.svelte';
</script>

<svelte:head><title>Blue threads and the collector · Zue</title></svelte:head>

<LessonHead title="Blue threads and the collector" lead="How the collector finds pointers on the stacks of waiting threads." />

<h2>How the garbage collector sees them</h2>

<p>
  The collector is conservative: it needs every stack that might hold a pointer. The running thread's stack is scanned at the start
  of a cycle. The stacks of the threads that are <em>away</em> are scanned from the stack pointer each saved, up to the top of its
  stack, together with its register context.
</p>

<p>
  The first version scanned all of them at the start of the cycle. That makes the start of a cycle take time proportional to the number
  of parked threads, which is a pause the program can see:
</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Parked threads</th><th>Longest delay before</th><th>Longest delay after</th><th>Cycle start after</th></tr></thead>
    <tbody>
      <tr><td>1,000</td><td>4.7 ms</td><td>0.41 ms</td><td>24 us</td></tr>
      <tr><td>5,000</td><td>21.9 ms</td><td>0.53 ms</td><td>26 us</td></tr>
      <tr><td>20,000</td><td>80 ms</td><td>0.45 ms</td><td>25 us</td></tr>
    </tbody>
  </table>
</div>

<Bars unit=" ms" items={[
  { label: '20,000 before', value: 80, tone: 'hazard' },
  { label: '20,000 after', value: 0.45, tone: 'blue' }
]} />

<h3>The fix: scan them in slices</h3>

<ol>
  <li>At the start of a cycle only the running thread is scanned. The cycle also records that a scan of parked stacks is under way, and where it has reached in the list of threads.</li>
  <li>Each collector step scans up to 32768 words (256 KB) of parked stacks and moves on. The cycle cannot end before the last thread has been scanned.</li>
  <li>Each thread carries a stamp, the number of the collection at which its stack was scanned, so a stack is never scanned twice in one cycle.</li>
</ol>

<Callout kind="trap" title="a race that had to be closed">
  <p>
    A thread that is about to run again <em>before</em> the scan reached its stack can pick an object off its stack, store it in a heap
    object that was already marked, and drop its own copy. The marker would never see that object. So <code>_blue_load</code>, the function
    that switches into a thread, first shades that thread's stack if the cycle has not scanned it yet. The test for this
    spawns 400 threads that recurse 150 deep, each hands an object that only it holds to a global list and then forgets it. With the
    shading call removed, 3 of 3 runs lost between 23 and 25 of the 400 objects. With it, none.
  </p>
</Callout>
