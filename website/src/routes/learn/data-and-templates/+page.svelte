<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
  import Link from '$lib/components/Link.svelte';
</script>

<svelte:head><title>data and template · Learn Zue</title></svelte:head>

<LessonHead title="data and template" lead="Records you can change." />

<div class="table-scroll">
  <table>
    <thead><tr><th>Kind</th><th>Changes?</th><th>Lives in</th><th>Best for</th></tr></thead>
    <tbody>
      <tr><td><code>data</code></td><td>yes</td><td>GC heap (a map)</td><td>quick records</td></tr>
      <tr><td><code>template</code></td><td>yes</td><td>GC heap, checked against its schema</td><td>entities, game state, anything that changes</td></tr>
      <tr><td><code>bloc</code></td><td>no</td><td>small GC object, at most 64 bytes</td><td><Link href="/learn/blocs/">vectors, colours, small constants</Link></td></tr>
      <tr><td><code>box</code></td><td>yes</td><td>a manual byte buffer, freed at scope end</td><td><Link href="/learn/boxes/">scratch bytes, up to 4096</Link></td></tr>
    </tbody>
  </table>
</div>

<p>
  Their rules are checked at run time by the runtime library. A violation stops the program with the messages shown on
  these pages, and every rule has a test in the Zue repository.
</p>

<h2>data</h2>

<p>A <code>data</code> value is a map with a constructor. <code>type(p)</code> is <code>"map"</code>, and <code>shape(p)</code> names the constructor.</p>

<Example id="data-basic" />

<h2>template</h2>

<p>
  A template is a record checked against its declaration. It is shared, not copied: <code>let alias = hero</code> makes a second name
  for the same object, so a change through one shows in the other.
</p>

<Example id="template-basic" />

<div class="table-scroll">
  <table>
    <thead><tr><th>Rule</th><th>Error</th></tr></thead>
    <tbody>
      <tr><td>The constructor needs exactly one value per field</td><td><code>Data constructor 'Player' expects 3 field value(s), but got 1</code></td></tr>
      <tr><td>Reading or writing an undeclared field</td><td><code>Template field 'z' does not exist</code></td></tr>
      <tr><td>Field names must be unique</td><td><code>template has duplicate field names</code></td></tr>
      <tr><td>A name keeps one field list (an identical redefinition is fine)</td><td><code>template 'A' is already defined with different fields</code></td></tr>
    </tbody>
  </table>
</div>

<Example id="template-wrong-field" shown />

<h2>Typed fields</h2>

<p>
  A field can be given a type after a colon: <code>int</code>, <code>float</code>, <code>bool</code>, <code>char</code>,
  <code>string</code>, <code>list</code>, <code>map</code>, <code>function</code>, the name of a <code>bloc</code> or
  <code>template</code>, or <code>box[N]</code>. <code>list&lt;int&gt;</code> and <code>map&lt;float&gt;</code> give the items a type
  that the compiler checks; at run time only <code>list</code> or <code>map</code> is checked. A value of another type is
  an error when the object is built and when a field is assigned. A whole number written in the source adapts to a float field; a variable never does.
  Fields without a type accept any value.
</p>

<Example id="template-wrong-type" shown />

<Callout kind="note" title="a template can hold anything">
  <p>
    Including a bloc, a box, or another template. A template that takes a box owns it: the box lives as long as the template.
    See <Link href="/learn/boxes/">box</Link>.
  </p>
</Callout>
