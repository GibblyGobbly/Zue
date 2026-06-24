<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { page } from '$app/state';
  import { base } from '$app/paths';
  import { groups, lessons } from '$lib/content/nav.js';
  import SideNav from '$lib/components/SideNav.svelte';
  import PrevNext from '$lib/components/PrevNext.svelte';

  let { children } = $props();
  const path = $derived(page.url.pathname.replace(base, ''));
  const index = $derived(lessons.findIndex((l) => path === `${l.href}/`));
</script>

<div class="wrap layout">
  <SideNav {groups} area="learn" label="Tutorial" numbered />
  <article class="content prose">
    {@render children()}
    <PrevNext prev={lessons[index - 1]} next={lessons[index + 1]} />
  </article>
</div>

<style>
  .layout { display: grid; grid-template-columns: 15.5rem minmax(0, 1fr); gap: 3rem; padding-top: 2.4rem; align-items: start; }
  .content { min-width: 0; max-width: none; }
  .content > :global(*) { max-width: 100%; }
  .content > :global(p), .content > :global(ul), .content > :global(ol), .content > :global(h2), .content > :global(h3) { max-width: var(--measure); }
  @media (max-width: 60rem) { .layout { grid-template-columns: 1fr; gap: 1.6rem; } }
</style>
