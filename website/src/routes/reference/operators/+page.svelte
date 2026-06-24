<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { operators, precedence } from '$lib/content/language.js';
</script>

<svelte:head><title>Operators · Reference · Zue</title></svelte:head>

<h1>Operators</h1>
<p class="lead">{precedence}</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Kind</th><th>Operators</th><th>Rules</th></tr></thead>
    <tbody>{#each operators as [k, o, d]}<tr><td>{k}</td><td><code>{o}</code></td><td>{d}</td></tr>{/each}</tbody>
  </table>
</div>

<style>
  .lead { max-width: 60ch; font-size: 1.1rem; margin: 0.9rem 0 1.6rem; }
</style>
