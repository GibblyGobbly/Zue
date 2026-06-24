<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { inline } from '$lib/inline.js';
  // Documentation text with `code` spans.
  let { text } = $props();
</script>

{#each inline(text) as p}{#if p.code}<code>{p.text}</code>{:else}{p.text}{/if}{/each}
