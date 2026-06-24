<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Blue threads · Learn Zue</title></svelte:head>

<LessonHead title="Blue threads" lead="Run several jobs in one program, taking turns." />

<p>
  A blue thread waits in exactly four places: <code>wait</code>, <code>yield</code>, <code>send</code> and
  <code>recv</code>. Between those, nothing else runs, so two threads never change a value at the same moment. A new thread
  first runs when the running thread waits. When the program's own thread ends, the program ends, even if other threads
  have not finished.
</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Function</th><th>Effect</th></tr></thead>
    <tbody>
      <tr><td><code>spawn(fn, args...)</code></td><td>Starts a thread that runs <code>fn(args...)</code> and returns its handle (type <code>"thread"</code>)</td></tr>
      <tr><td><code>wait(thread)</code></td><td>Waits until the thread has finished and returns what its function returned. Only one thread can wait for a given thread, and a thread cannot wait for itself</td></tr>
      <tr><td><code>yield()</code></td><td>Lets the other ready threads run first. Returns <code>null</code></td></tr>
      <tr><td><code>channel(n)</code></td><td>A channel (type <code>"channel"</code>) that holds up to <code>n</code> values. <code>channel()</code> holds none: <code>send</code> and <code>recv</code> meet</td></tr>
      <tr><td><code>send(ch, v)</code></td><td>Gives <code>v</code> to a thread waiting in <code>recv</code>, or stores it, or waits until there is room</td></tr>
      <tr><td><code>recv(ch)</code></td><td>Takes the oldest value, or waits for one</td></tr>
      <tr><td><code>channel_close(ch)</code></td><td>No more sends. Values already stored can still be received</td></tr>
    </tbody>
  </table>
</div>

<h2>Start a thread, get its answer</h2>

<Example id="threads-wait" />

<h2>Workers and a channel</h2>

<Example id="threads-basic" />

<h2>Taking turns with yield</h2>

<p>The two threads alternate because each one yields after every line.</p>

<Example id="threads-yield" />
