<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>Building Zue from its seeds · Zue</title></svelte:head>

<LessonHead title="Building Zue from its seeds" lead="How a build starts from committed files and checks itself." />

<h2>How a build bootstraps</h2>

<ol>
  <li>Build a <strong>seed compiler</strong> from the committed <code>bootstrap/zuec.ll</code> and <code>bootstrap/zue_rt_native.ll</code>.</li>
  <li>Use it to compile the runtime and the compiler sources of the working tree.</li>
  <li>Build that compiler (<strong>stage 1</strong>), use it to compile the compiler again (<strong>stage 2</strong>), and require the two outputs to be <em>identical</em>.</li>
  <li>Copy stage 1 to <code>bin/zue</code>.</li>
</ol>

<p>
  The identical-output check is the strongest test the project has: a 15 MB program, produced by the compiler it describes, must come
  out the same twice. A change that breaks code generation shows up there first.
</p>

<h2>The rules this creates</h2>

<ul>
  <li><strong>Seeds follow the sources.</strong> After a change to the compiler or runtime, <code>make seed</code> refreshes the committed files, and they are committed together with the change. A build prints a warning when a seed is stale.</li>
  <li><strong>Do not seed a broken compiler.</strong> A compiler that fails its tests would become the base of the next build, and a broken seed can make the project unrecoverable except from an older commit.</li>
  <li><strong>The compiler uses only what its seed supports.</strong> A new language feature can be used in the compiler's own source only after a seed that supports it exists.</li>
  <li>If a change alters how code is generated, stage 1 and stage 2 differ, and the build stops with a message. <code>tools/bootstrap_until_stable.sh</code> repeats the stages until they agree.</li>
  <li>The compiler's own source must stay inside the part of the language it compiles, and must keep passing its own type checker.</li>
</ul>

<Callout kind="note" title="coming later">
  <p>The toolchain underneath, how the generated IR becomes a native program, gets its own page later.</p>
</Callout>
