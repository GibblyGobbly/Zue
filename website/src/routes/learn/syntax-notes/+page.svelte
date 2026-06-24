<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
</script>

<svelte:head><title>Small syntax notes · Learn Zue</title></svelte:head>

<LessonHead title="Small syntax notes" lead="The alternative keyword spellings, and where a line ends." />

<h2>The alternative spellings</h2>

<p>
  Every keyword below is an exact synonym for another, mapped in the lexer. They are reserved too, so a variable
  cannot be called <code>balls</code>.
</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Alias</th><th>Keyword</th></tr></thead>
    <tbody>
      <tr><td><code>balls</code>, <code>big_balls</code>, <code>shared_balls</code></td><td><code>let</code></td></tr>
      <tr><td><code>grab_balls</code></td><td><code>func</code></td></tr>
      <tr><td><code>if_balls</code> / <code>else_balls</code></td><td><code>if</code> / <code>else</code></td></tr>
      <tr><td><code>spin_balls</code></td><td><code>while</code></td></tr>
      <tr><td><code>loop_your_balls</code></td><td><code>for</code></td></tr>
      <tr><td><code>switch_balls</code></td><td><code>switch</code></td></tr>
      <tr><td><code>drop_balls</code></td><td><code>break</code></td></tr>
      <tr><td><code>jiggle_balls</code></td><td><code>continue</code></td></tr>
    </tbody>
  </table>
</div>

<h2>Where a statement ends</h2>

<p>
  A statement ends at the end of its line. A line continues when it ends with a binary operator or a comma, or when
  it is inside <code>( )</code>, <code>[ ]</code> or a <code>{'{ }'}</code> literal. Trailing commas are allowed in lists, maps,
  calls, parameter lists and <code>use</code> lists. <code>return</code> followed by a line break returns nothing: the
  value must start on the same line.
</p>
