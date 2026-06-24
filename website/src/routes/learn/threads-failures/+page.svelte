<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
  import Link from '$lib/components/Link.svelte';
</script>

<svelte:head><title>When threads go wrong · Learn Zue</title></svelte:head>

<LessonHead title="When threads go wrong" lead="Deadlocks, closed channels, and how many threads fit." />

<h2>The errors you can get</h2>

<div class="table-scroll">
  <table>
    <thead><tr><th>Situation</th><th>Error</th></tr></thead>
    <tbody>
      <tr><td><code>recv</code> on a closed channel with no values left, <code>send</code> on a closed one, closing twice</td><td><code>Runtime Error</code></td></tr>
      <tr><td>A thread waits in <code>send</code> or <code>recv</code> when the channel is closed</td><td><code>Runtime Error</code> for that thread</td></tr>
      <tr><td>Every thread waits and none can wake another</td><td><code>Runtime Error</code>: deadlock</td></tr>
      <tr><td><code>wait</code>, <code>yield</code>, <code>send</code> or <code>recv</code> inside an <code>unsafe</code> block</td><td><code>Runtime Error</code></td></tr>
      <tr><td>An error inside a thread</td><td>The program stops, as an error in the main thread does</td></tr>
      <tr><td>Recursion too deep in a thread</td><td><code>Runtime Error</code>: stack overflow</td></tr>
    </tbody>
  </table>
</div>

<Example id="threads-recv-closed" shown />

<Example id="threads-deadlock" shown />

<h2>How many?</h2>

<p>This program starts twenty thousand threads and collects every answer.</p>

<Example id="threads-many" />

<Callout kind="note" title="limits">
  <p>
    Each thread has a stack of 1 MiB of address space (memory is used as it grows, with 128 KiB kept for the runtime), so a
    thread can nest roughly 1200 calls where the main thread allows 100000. The operating system's limit on mappings
    (<code>vm.max_map_count</code>) bounds the number of threads at once, since each one uses two mappings. On a machine where it is 1048576, 70000 threads
    ran, and the spawn after about 500000 failed. A thread that cannot get a stack is an error.
  </p>
</Callout>

<p>
  How the scheduler, the stacks and the garbage collector fit together is in
  <Link href="/internals/blue-threads/">Blue threads inside</Link>.
</p>
