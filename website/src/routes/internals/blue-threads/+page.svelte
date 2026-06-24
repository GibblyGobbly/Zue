<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
  import Link from '$lib/components/Link.svelte';
</script>

<svelte:head><title>Blue threads: the machinery · Zue</title></svelte:head>

<LessonHead title="Blue threads: the machinery" lead="What a thread is made of, and what it costs." />

<p>
  The code is in <code>compiler/runtime/zue_rt_blue.zu</code>. The language side is in
  <Link href="/learn/blue-threads/">Blue threads</Link>. This page is about what happens under it.
</p>

<h2>What a blue thread is</h2>

<ul>
  <li>A <strong>thread object</strong> of 200 bytes: a state (new, ready, running, waiting or done), the function and its arguments, the saved stack pointer, the call depth and a copy of the call frames (so error call stacks stay right), the value it returned, the thread waiting for it, and links into the run queue and into the list of all threads.</li>
  <li>A <strong>saved context</strong>: the registers, kept in a 1024-byte <code>ucontext</code> object on the heap, filled by <code>swapcontext</code>.</li>
  <li>An <strong>mmap'd stack</strong> of 1 MiB of address space. Memory is used as the stack grows, and 128 KiB is kept for the runtime itself. The bottom of the stack is a guard region made unreadable with <code>mprotect</code>, which the kernel counts as a second mapping, so the operating system's mapping limit bounds how many threads can exist.</li>
</ul>

<p>
  A thread switch is a call to <code>swapcontext</code> inside <code>wait</code>, <code>yield</code>, <code>send</code> or
  <code>recv</code>. Nothing else switches, so there is no preemption and no data race between blue threads. All of them run on
  the one thread that runs the program.
</p>

<Callout kind="rule" title="why unsafe forbids waiting">
  <p>
    A <code>wait</code>, <code>yield</code>, <code>send</code> or <code>recv</code> inside an <code>unsafe</code> block is a
    <code>Runtime Error</code>. A pointer is tied to the block that made it, and switching away in the middle of the block would let
    another thread run while raw pointers are live.
  </p>
</Callout>

<h2>Blocking in the wrong places</h2>

<p>
  A thread that waits in <code>send</code> or <code>recv</code> on a channel with no one on the other side is parked on that channel. If
  every thread is parked and none can wake another, the runtime reports a deadlock and names the line of the last <code>recv</code> or
  <code>wait</code>, instead of hanging.
</p>

<Example id="threads-deadlock" shown />

<h2>Limits and costs</h2>

<ul>
  <li>Each thread can nest roughly 1200 calls where the main thread allows 100000, because its stack is 1 MiB.</li>
  <li>Creating a thread costs a stack mapping and a context. Twenty thousand of them run and finish in the example on the tutorial page, and the program ends when the main thread ends.</li>
  <li>An error in a thread stops the program, as an error in the main thread does.</li>
</ul>
