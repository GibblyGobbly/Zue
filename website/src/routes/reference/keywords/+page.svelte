<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { keywords } from '$lib/content/language.js';
</script>

<svelte:head><title>Keywords · Reference · Zue</title></svelte:head>

<h1>Keywords</h1>
<p class="lead">Words with a fixed meaning. You cannot use them as names of variables or functions.</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Word</th><th>Meaning</th></tr></thead>
    <tbody>{#each keywords as [k, d]}<tr><td><code>{k}</code></td><td>{d}</td></tr>{/each}</tbody>
  </table>
</div>

<p class="note">
  <code>template</code>, <code>bloc</code>, <code>box</code>, <code>unsafe</code>, <code>use</code>, <code>export</code>, <code>import</code>,
  <code>case</code> and <code>default</code> are always reserved. <code>data</code>, <code>in</code> and <code>from</code> are keywords only where they
  mean something. The alternative spellings such as <code>grab_balls</code> are reserved too.
</p>

<style>
  .lead { max-width: 56ch; font-size: 1.1rem; margin: 0.9rem 0 1.6rem; }
  .note { max-width: 66ch; margin-top: 1.6rem; }
</style>
