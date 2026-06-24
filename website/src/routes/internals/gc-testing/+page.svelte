<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
</script>

<svelte:head><title>Testing and known limits · Zue</title></svelte:head>

<LessonHead title="Testing and known limits" lead="How the collector is tested, and what it does not do yet." />

<h2>How it is tested</h2>

<ul>
  <li>The GC tests build and drop many objects and check that live data stays intact, and the barrier test moves objects out of lists, maps, closure cells, template fields, <code>remove</code> and <code>sort</code>, overwrites the old place, and keeps the object elsewhere.</li>
  <li>Switching off any one barrier function makes the barrier test fail under <code>ZUE_RT_GC_VERIFY=1 ZUE_RT_GC_STRESS=1</code>. The checks were mutation-tested that way.</li>
  <li><code>ZUE_RT_GC_STRESS=7 ZUE_RT_GC_SLOW=50</code> runs the suites with the two threads interleaved as much as possible.</li>
  <li><code>tools/gc_race_check.sh</code> builds the GC tests with ThreadSanitizer and fails on any race other than the two the design allows: the marker reads object contents and two page descriptor fields while the program writes them. That is safe because the snapshot is taken at the start, the barrier marks what the program overwrites, and an object allocated during a cycle is marked at birth.</li>
  <li>The compiler compiles itself twice with every build, and the two outputs must be identical, so the collector is exercised by a 15 MB program on every <code>make</code>.</li>
</ul>

<h2>Known limits</h2>

<ul>
  <li>One GC thread marks at roughly 4 GB of live data per second. A program that allocates faster is slowed down, or holds more memory.</li>
  <li>Sweeping is still done by the program thread, in 50-microsecond steps. Moving it to the GC thread is the next planned change.</li>
  <li>No compaction, so a fragmented heap costs memory and not pauses.</li>
  <li>A tighter heap goal trades throughput and small delays for memory. There is no setting for it yet.</li>
</ul>
