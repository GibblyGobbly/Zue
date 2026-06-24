<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>The pacer · Zue</title></svelte:head>

<LessonHead title="The pacer" lead="How the collector decides when to start and when to slow your program down." />

<h2>The pacer</h2>

<p>
  When to start a cycle, and how much the program may allocate before it is held back, are worked out at the end of every cycle
  from what was measured, not from fixed percentages.
</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Step</th><th>What the pacer does</th></tr></thead>
    <tbody>
      <tr><td>Measure</td><td>The program's allocation rate (bytes per millisecond) and the cost of a cycle (nanoseconds from its start to the end of its sweep, per MiB of live data), each averaged with the last value</td></tr>
      <tr><td>Estimate</td><td><code>a</code>, the bytes the program will allocate during the next cycle: rate times the cycle time for the live size</td></tr>
      <tr><td>Goal</td><td>Twice <code>a</code>, but at least 32 MiB, at most the live size, and at most half of the free memory of the machine</td></tr>
      <tr><td>Start</td><td>The next cycle starts when the goal minus <code>a</code> has been allocated, at least 16 MiB</td></tr>
      <tr><td>Hold back</td><td>While a cycle runs, once the bytes allocated since the last cycle end pass the goal, each step spins for 100 microseconds</td></tr>
    </tbody>
  </table>
</div>

<p>
  The hold-back is a spin and not a sleep: a sleep can overshoot by milliseconds, and <code>sched_yield</code> can hand the core to
  another thread for a whole time slice.
</p>

<Callout kind="trap" title="a bug the pacer had, and how it was found">
  <p>
    The pacer read the live size at the end of the sweep. That figure includes everything the program allocated during the
    cycle, because all of it survives that cycle. On a heap of 1.0 GB it read 1.7 GB, so the goal, which is capped by the live size,
    grew with the garbage it was meant to bound. The next cycle waited 840 MiB when it should have waited about 130. The pacer now
    subtracts the bytes allocated during the cycle. At a 1 GiB working set the peak memory went from 4463 MiB to 2684 MiB,
    and throughput from 4.97 to 4.38 million iterations a second.
  </p>
</Callout>
