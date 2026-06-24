<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import '../app.css';
  import '$lib/code.css';
  import Header from '$lib/components/Header.svelte';
  import Footer from '$lib/components/Footer.svelte';

  let { children } = $props();
</script>

<a class="skip sr-only" href="#main">Skip to the content</a>
<Header />
<main id="main">{@render children()}</main>
<Footer />

<style>
  .skip:focus { position: fixed; z-index: 50; top: 0.5rem; left: 0.5rem; width: auto; height: auto; clip: auto; background: var(--blue); color: var(--blue-ink); padding: 0.5rem 1rem; }
</style>
