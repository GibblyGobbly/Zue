<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>unsafe · Learn Zue</title></svelte:head>

<LessonHead title="unsafe" lead="Allocate, read, write and free memory by hand." />

<p>
  Most programs never need it. Lists, maps, strings and <code>dense_list</code> cover normal work. Inside
  <code>unsafe {'{ }'}</code> you get these functions:
</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Function</th><th>Meaning</th></tr></thead>
    <tbody>
      <tr><td><code>alloc(n)</code></td><td>Allocate <code>n</code> value slots. Returns a pointer</td></tr>
      <tr><td><code>free(ptr)</code></td><td>Free an allocation</td></tr>
      <tr><td><code>defer(ptr)</code></td><td>Free <code>ptr</code> when the block exits</td></tr>
      <tr><td><code>load(ptr)</code></td><td>Read the value at <code>ptr</code></td></tr>
      <tr><td><code>store(ptr, value)</code></td><td>Write <code>value</code> at <code>ptr</code></td></tr>
      <tr><td><code>ptr_offset(ptr, n)</code></td><td>The pointer <code>n</code> slots past <code>ptr</code>, bounds-checked</td></tr>
      <tr><td><code>address_of(name)</code></td><td>A pointer to a named variable</td></tr>
      <tr><td><code>int(ptr)</code></td><td>The only allowed pointer cast: the raw address as an int</td></tr>
    </tbody>
  </table>
</div>

<p>The older names <code>deref</code>, <code>ptr_add</code> and <code>addr</code> still work as aliases.</p>

<h2>The usual flow</h2>

<p>Allocate, register the cleanup, write, read.</p>

<Example id="unsafe-basic" />

<h2>Editing a variable through its address</h2>

<Example id="unsafe-address-of" />

<h2>A table in raw memory</h2>

<Example id="unsafe-grid" />

<h2>Templates and blocs made by hand</h2>

<p>
  <code>alloc(object)</code> with a template or bloc value copies the object to the C heap, outside the garbage collector,
  and returns a pointer. Fields are read and written through it, and the same rules apply: free or defer it, it cannot leave
  the block, use after free is an error. A bloc made this way is read-only. An object that holds a box cannot be copied this way.
</p>

<Example id="unsafe-template" />
