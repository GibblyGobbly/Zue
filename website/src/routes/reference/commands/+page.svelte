<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import ref from '$lib/generated/reference.json';
  import Rich from '$lib/components/Rich.svelte';
</script>

<svelte:head><title>Commands · Reference · Zue</title></svelte:head>

<h1>Commands</h1>
<p class="lead">What you type in a terminal.</p>

<div class="table-scroll">
  <table>
    <thead><tr><th>Command</th><th>What it does</th></tr></thead>
    <tbody>{#each ref.cli as c}<tr><td><Rich text={c.command} /></td><td><Rich text={c.effect} /></td></tr>{/each}</tbody>
  </table>
</div>

<style>
  .lead { max-width: 60ch; font-size: 1.1rem; margin: 0.9rem 0 1.6rem; }
</style>
