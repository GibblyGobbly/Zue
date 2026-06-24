<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Bars from '$lib/components/Bars.svelte';
</script>

<svelte:head><title>Measured results · Zue</title></svelte:head>

<LessonHead title="Measured results" lead="Pauses, throughput and memory, next to the same program in Go." />

<h2>What it costs, measured</h2>

<p>
  The numbers below come from one workload, on one 16-core machine, one 20-second run per cell, so treat them as a snapshot and not
  as a promise. The program keeps a live set of rows <code>[i, i, i, [i]]</code>, then in a loop allocates a short-lived list and writes
  a fresh list into an old row, and times every iteration. The same program was written in Go 1.22 with <code>[]any</code> rows.
</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Live rows</th><th>Runtime</th><th>Throughput</th><th>Worst delay</th><th>Delays over 1 ms</th><th>Peak memory</th></tr></thead>
    <tbody>
      <tr><td>4.8 M</td><td>Zue</td><td>4.34 M/s</td><td>0.56 ms</td><td>0</td><td>2852 MiB</td></tr>
      <tr><td>4.8 M</td><td>Go, <code>GOGC=100</code></td><td>3.51 M/s</td><td>11.8 ms</td><td>24</td><td>2000 MiB</td></tr>
      <tr><td>9.6 M</td><td>Zue</td><td>4.09 M/s</td><td>0.26 ms</td><td>0</td><td>5656 MiB</td></tr>
      <tr><td>9.6 M</td><td>Go, <code>GOGC=100</code></td><td>3.36 M/s</td><td>7.3 ms</td><td>14</td><td>3896 MiB</td></tr>
      <tr><td>19 M</td><td>Zue</td><td>3.06 M/s</td><td>1.01 ms</td><td>1</td><td>8912 MiB</td></tr>
      <tr><td>19 M</td><td>Go, <code>GOGC=100</code></td><td>3.21 M/s</td><td>3.1 ms</td><td>2</td><td>7517 MiB</td></tr>
    </tbody>
  </table>
</div>

<Bars unit=" ms" items={[
  { label: 'Zue, 4.8 M rows', value: 0.56, tone: 'blue' },
  { label: 'Go, 4.8 M rows', value: 11.8 },
  { label: 'Zue, 9.6 M rows', value: 0.26, tone: 'blue' },
  { label: 'Go, 9.6 M rows', value: 7.3 },
  { label: 'Zue, 19 M rows', value: 1.01, tone: 'blue' },
  { label: 'Go, 19 M rows', value: 3.1 }
]} />

<p>The bars are the worst delay the program saw in 20 seconds. Also note:</p>

<ul>
  <li><strong>Memory is where we lose.</strong> Zue peaks at 1.2 to 1.5 times Go's memory. A row is about the same size in both (about 208 bytes against 210), so the gap is the pacing, not the value layout.</li>
  <li><strong>Small delays.</strong> Zue has thousands of delays over 0.1 ms (4143 against 160 at the first size). They are collector steps and the hold-back. Go has far fewer of those, but occasional long ones.</li>
  <li><strong>Go uses the other cores</strong> for its collector, and its delays include its stop-the-world phases and allocation assists. Go with <code>GOGC=50</code> lowers its memory and raises its delays.</li>
  <li><strong>The 4 GiB row</strong> is limited by the machine's memory; there Go's throughput is slightly ahead.</li>
</ul>
