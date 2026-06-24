<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>Modules · Learn Zue</title></svelte:head>

<LessonHead title="Modules" lead="Split a program over several files." />

<p>
  <code>export</code> goes before <code>func</code>, <code>const</code>, <code>template</code>, <code>bloc</code> and
  <code>data</code>. It does not go before <code>let</code>: a variable can change, and an importer would keep a stale
  copy. <code>export let</code> is a syntax error. Use <code>export const</code>, or export a function that returns the
  value.
</p>

<p>The example has three tabs. Click them, then press RUN.</p>

<Example id="modules-demo" />

<h2>Two ways in</h2>

<ul>
  <li><code>use "geometry.zu"</code> brings in every exported name.</li>
  <li><code>use {'{ bump }'} from "counter.zu"</code> brings in only the names you list.</li>
  <li><code>import "util.zu"</code> is the older spelling of <code>use "util.zu"</code>.</li>
</ul>

<h2>What stays private</h2>

<Example id="modules-private" shown />

<p>
  <code>secret</code> was not exported, so the importing file does not see it, even with <code>use "geometry.zu"</code>.
  Asking for it with <code>use {'{ secret }'} from</code> is a compile error that says the module does not export it, with a
  "did you mean" hint when a similar name is exported.
</p>

<h2>The rules</h2>

<div class="table-scroll">
  <table>
    <thead><tr><th>Rule</th><th>What it means</th></tr></thead>
    <tbody>
      <tr><td>Paths are relative to the importing file</td><td>A module in <code>sub/wrapper.zu</code> that writes <code>"../helper.zu"</code> finds <code>helper.zu</code> next to <code>sub/</code></td></tr>
      <tr><td>Modules are part of the binary</td><td>The compiler reads every imported file while it compiles, into the same executable. A program built from <code>main.zu</code> runs without the sources. A file that cannot be read is a compile error at the <code>use</code> line, even in a branch that never runs</td></tr>
      <tr><td>Each file runs once</td><td>The first <code>use</code> runs the module's top-level statements. Later imports, from any file, reuse the same bindings, so module state persists. The counter above kept counting</td></tr>
      <tr><td>Only exported names are visible</td><td>The rest is undefined in the importing file</td></tr>
      <tr><td>Cycles are reported</td><td><code>Circular import detected: 'a.zu' is already loading</code></td></tr>
    </tbody>
  </table>
</div>

<Callout kind="note" title="state that several modules change">
  <p>
    An imported name is a copy of the module's binding made when <code>use</code> runs. Constants and functions never
    change, so the copy is always right. State that changes stays behind an exported function. For state shared by
    several modules, keep the data in a list or map owned by one module and pass it to the functions that need it.
  </p>
</Callout>
