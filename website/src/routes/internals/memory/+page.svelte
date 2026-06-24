<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import ValueCell from '$lib/components/ValueCell.svelte';
</script>

<svelte:head><title>Value cells · Zue</title></svelte:head>

<LessonHead title="Value cells" lead="Every value in Zue is stored in a 16-byte cell." />

<div class="table-scroll">
  <table>
    <thead><tr><th>Where</th><th>What lives there</th><th>Who frees it</th></tr></thead>
    <tbody>
      <tr><td>The call stack</td><td>local variables, temporaries, call frames</td><td>automatic, when the function returns</td></tr>
      <tr><td>The garbage-collected heap</td><td>strings, lists, maps, dense lists, closures, templates, blocs</td><td>the garbage collector</td></tr>
      <tr><td>The box table</td><td><code>box</code> byte buffers</td><td>the end of the scope, <code>free</code>, or the owning template</td></tr>
      <tr><td>Raw <code>alloc()</code> memory</td><td>buffers made inside <code>unsafe</code> blocks</td><td>you, with <code>free</code> or <code>defer</code></td></tr>
    </tbody>
  </table>
</div>

<h2>Every value is a 16-byte cell</h2>

<p>
  A cell is a tag that says what the value is, and a payload. Numbers, booleans, chars and <code>null</code> sit directly in the
  cell. Strings, lists, maps and the rest are a pointer in the payload to an object on the heap.
</p>

<ValueCell rows={[
  { label: 'int 42', tag: '2', payload: '42' },
  { label: 'float 1.5', tag: '3', payload: 'bits of the double' },
  { label: 'boolean', tag: '1', payload: '0 or 1' },
  { label: 'null', tag: '0', payload: '-' },
  { label: '"Zue"', tag: '5', payload: 'pointer', ptr: true, points: 'length + bytes' },
  { label: '[1, 2]', tag: '6', payload: 'pointer', ptr: true, points: 'count, capacity, items' }
]} />

<div class="table-scroll">
  <table>
    <thead><tr><th>Tag</th><th>Kind</th><th>Payload</th></tr></thead>
    <tbody>
      <tr><td>0</td><td>null</td><td>none</td></tr>
      <tr><td>1</td><td>boolean</td><td>0 or 1</td></tr>
      <tr><td>2</td><td>int</td><td>the 64-bit integer</td></tr>
      <tr><td>3</td><td>float</td><td>the bit pattern of a double</td></tr>
      <tr><td>4</td><td>char</td><td>the byte</td></tr>
      <tr><td>5</td><td>string</td><td>pointer to the string object</td></tr>
      <tr><td>6</td><td>list</td><td>pointer to a list object: count, capacity, pointer to the item cells</td></tr>
      <tr><td>7</td><td>map</td><td>pointer to a map object</td></tr>
      <tr><td>8</td><td>function</td><td>pointer to a function object: code, name, captured cells</td></tr>
      <tr><td>9</td><td>file</td><td>pointer to a file object</td></tr>
      <tr><td>10</td><td>dense list</td><td>pointer to a float array object</td></tr>
      <tr><td>11, 13</td><td>bloc type, <code>data</code> type</td><td>the type descriptor</td></tr>
      <tr><td>12</td><td>bloc</td><td>pointer to a bloc object</td></tr>
      <tr><td>14</td><td>template</td><td>pointer to a template object</td></tr>
      <tr><td>15</td><td>box</td><td>a handle with a slot index and a generation</td></tr>
      <tr><td>16</td><td>pointer</td><td>a raw pointer, only inside <code>unsafe</code></td></tr>
      <tr><td>18</td><td>thread</td><td>pointer to a blue thread object</td></tr>
      <tr><td>19</td><td>channel</td><td>pointer to a channel object</td></tr>
    </tbody>
  </table>
</div>

<h2>Sharing and copying</h2>

<ul>
  <li>Assigning or passing a list, map, <code>data</code> or <code>template</code> value shares it: both names refer to the same object.</li>
  <li>Numbers, booleans and chars are copied.</li>
  <li>Strings cannot change in place. Every string function returns a new string.</li>
  <li>Blocs are immutable copies of their fields.</li>
</ul>

<Example id="memory-sharing" />
