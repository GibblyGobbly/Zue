<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Looking inside text · Learn Zue</title></svelte:head>

<LessonHead title="Looking inside text" lead="Measure a string, test what it contains, and find where something is." />

<h2>Looking at a string</h2>

<Example id="strings-inspect" />

<p>
  Strings are bytes: <code>len("héllo")</code> is 6, because the <code>é</code> takes two bytes, and indexing is by byte.
  <code>to_upper</code> and <code>to_lower</code> change ASCII letters only.
</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Function</th><th>What it does</th></tr></thead>
    <tbody>
      <tr><td><code>len(x)</code>, <code>str_len(s)</code></td><td>Length of a string. <code>len</code> also takes lists, maps and boxes</td></tr>
      <tr><td><code>is_empty(s)</code></td><td><code>true</code> for length 0. A non-string is a <code>Type Error</code></td></tr>
      <tr><td><code>is_digit</code>, <code>is_alpha</code>, <code>is_alnum</code>, <code>is_space</code></td><td><code>true</code> if the string (or char) is non-empty and every character is in the class</td></tr>
      <tr><td><code>char_at(s, i)</code></td><td>The character at <code>i</code> as a one-character string, <code>""</code> when out of range</td></tr>
      <tr><td><code>substring(s, start, n)</code></td><td><code>n</code> characters from <code>start</code>, cut at the end of the string</td></tr>
      <tr><td><code>slice(s, a, b)</code></td><td>The same as <code>s[a:b]</code></td></tr>
    </tbody>
  </table>
</div>

<h2>Searching</h2>

<Example id="strings-search" />

<ul>
  <li><code>index_of(s, sub, start)</code> takes an optional start position, and returns <code>-1</code> when there is none.</li>
  <li><code>index_of_any(s, set)</code> finds the first byte that is in the string <code>set</code>.</li>
  <li><code>skip_chars(s, set)</code> finds the first byte that is <em>not</em> in <code>set</code> and returns <code>len(s)</code> if there is none. Together these two are what the Zue lexer uses to skip over identifiers and spaces.</li>
</ul>
