<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import ref from '$lib/generated/reference.json';
  import Rich from '$lib/components/Rich.svelte';
</script>

<svelte:head><title>Environment variables · Reference · Zue</title></svelte:head>

<h1>Environment variables</h1>
<p class="lead">Settings read when a program or the compiler starts.</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Variable</th><th>What it does</th></tr></thead>
    <tbody>{#each ref.env as c}<tr><td><Rich text={c.name} /></td><td><Rich text={c.effect} /></td></tr>{/each}</tbody>
  </table>
</div>

<style>
  .lead { max-width: 60ch; font-size: 1.1rem; margin: 0.9rem 0 1.6rem; }
</style>
