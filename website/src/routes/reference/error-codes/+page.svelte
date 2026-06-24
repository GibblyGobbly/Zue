<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import ref from '$lib/generated/reference.json';
</script>

<svelte:head><title>Error codes · Reference · Zue</title></svelte:head>

<h1>Error codes</h1>
<p class="lead">Every error message has a code like <code>E0201</code>. Run <code>zue explain E0201</code> to see an example and the fix.</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Code</th><th>Meaning</th></tr></thead>
    <tbody>
      {#each ref.errorCodes as e}<tr id={e.code}><td><code>{e.code}</code></td><td>{e.meaning}</td></tr>{/each}
    </tbody>
  </table>
</div>

<style>
  .lead { max-width: 60ch; font-size: 1.1rem; margin: 0.9rem 0 1.6rem; }
  tr:target td { background: color-mix(in srgb, var(--blue) 22%, var(--slab)); }
</style>
