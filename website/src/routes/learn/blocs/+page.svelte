<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>bloc · Learn Zue</title></svelte:head>

<LessonHead title="bloc" lead="A small value that never changes." />

<p>
  A bloc is built with braces: <code>Vec2{'{1, 2}'}</code>. Its fields hold an int, float, bool, char or string, or another bloc.
  The first construction fixes the layout, but the field kinds may differ between instances (<code>Vec2{'{1.5, 2.5}'}</code>).
</p>

<Example id="bloc-basic" />

<ul>
  <li>Blocs compare by value: <code>Vec2{'{1, 2}'} == Vec2{'{1, 2}'}</code> is <code>true</code>.</li>
  <li>A bloc is a small GC object holding a pointer to a shared descriptor (name, field names, kinds, size) and one 16-byte cell per field.</li>
  <li>A <code>bloc</code> types all its fields or none. Typed fields can also hold a <code>box[N]</code>: the bloc keeps a read-only copy.</li>
  <li>Blocs may not hold lists, maps, functions or templates.</li>
</ul>

<h2>Immutable</h2>

<Example id="bloc-immutable" shown />

<h2>The size limit</h2>

<p>
  A bloc is at most 64 bytes of unique fields: every primitive field takes 8, and a nested bloc takes its own size. Nine
  fields are 72 bytes.
</p>

<Example id="bloc-too-big" shown />

<div class="table-scroll">
  <table>
    <thead><tr><th>Rule</th><th>Error</th></tr></thead>
    <tbody>
      <tr><td>Size</td><td><code>bloc exceeds the cache-line size limit (64 bytes)</code></td></tr>
      <tr><td>Field kinds</td><td><code>Bloc field 'name' only accepts int, float, bool, char, or another bloc</code></td></tr>
      <tr><td>A nested field keeps the same bloc type</td><td><code>Bloc 'R' field 'min' must use the same nested bloc type</code></td></tr>
      <tr><td>One value per field</td><td><code>Bloc 'Vec2' expects 2 field value(s), but got 1</code></td></tr>
      <tr><td>Immutability</td><td><code>bloc values are immutable</code></td></tr>
      <tr><td>Unknown fields</td><td><code>Field 'z' does not exist on this bloc value</code></td></tr>
      <tr><td>Unique names, one field list per name</td><td><code>bloc has duplicate field names</code>, <code>bloc 'V' is already defined with different fields</code></td></tr>
    </tbody>
  </table>
</div>

<Callout kind="note" title="why 64">
  <p>
    A 64-byte bloc fits one cache line. The limit keeps blocs small enough to copy cheaply. For anything bigger or anything
    that changes, use a <code>template</code>.
  </p>
</Callout>
