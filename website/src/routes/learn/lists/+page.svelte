<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>Lists · Learn Zue</title></svelte:head>

<LessonHead title="Lists" lead="An ordered collection. A list is shared, so two names can point at one list." />



<h2>Lists</h2>

<Example id="lists-basics" />

<div class="table-scroll">
  <table>
    <thead><tr><th>Function</th><th>Effect</th></tr></thead>
    <tbody>
      <tr><td><code>append(list, v)</code>, <code>list_append(list, v)</code></td><td>Add to the end. The two names are the same</td></tr>
      <tr><td><code>remove(list, i)</code></td><td>Remove and return the item at <code>i</code> (negative counts from the end). Out of range is an <code>Index Error</code></td></tr>
      <tr><td><code>find(list, v)</code></td><td>Index of the first equal item, or <code>-1</code></td></tr>
      <tr><td><code>slice(list, a, b)</code></td><td>The same as <code>list[a:b]</code>: from 0, both ends included</td></tr>
      <tr><td><code>contains(list, v)</code>, <code>join(list, sep)</code></td><td>Also work on lists</td></tr>
      <tr><td><code>range(...)</code></td><td>A list of ints</td></tr>
      <tr><td><code>len(list)</code></td><td>The number of items</td></tr>
    </tbody>
  </table>
</div>

<Callout kind="rule" title="a list does not grow by assignment">
  <p>
    Reading or writing outside <code>0 .. len - 1</code> (or the negative equivalent) is an <code>Index Error</code>.
    Use <code>append</code> to add an item. Assigning a list to a second name shares it, as the last lines of the example
    show: <code>a</code> grew when <code>b</code> was appended to.
  </p>
</Callout>

<p>
  Two lists or maps are equal only when they are the same object. A slice of a list is a new list, but its items are
  not copied deeply.
</p>

<h2>The vector shortcut</h2>

<p>
  Two lists of numbers can be added, subtracted, multiplied and divided with the operators. The result is a dense
  list of floats. <code>vec_add</code> is the function behind <code>+</code>, and <code>list_append</code> the other
  name of <code>append</code>:
</p>

<Example id="lists-alias" />
