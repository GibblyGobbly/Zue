<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { page } from '$app/state';
  import { base } from '$app/paths';
  import ThemeToggle from './ThemeToggle.svelte';

  const links = [
    { href: '/learn/hello-world', label: 'Learn', match: '/learn' },
    { href: '/internals/memory', label: 'Inside', match: '/internals' },
    { href: '/reference', label: 'Reference', match: '/reference' },
    { href: '/playground', label: 'Playground', match: '/playground' }
  ];
  let open = $state(false);
</script>

<header>
  <div class="wrap bar">
    <a class="mark" href="{base}/" aria-label="Zue, home">ZUE<span>.</span></a>
    <button class="burger" type="button" aria-expanded={open} aria-controls="nav" onclick={() => (open = !open)}>menu</button>
    <nav id="nav" class:open aria-label="Main">
      {#each links as l}
        <a href="{base}{l.href}" class:here={page.url.pathname.startsWith(base + l.match)} onclick={() => (open = false)}>{l.label}</a>
      {/each}
    </nav>
    <div class="theme"><ThemeToggle /></div>
  </div>
</header>

<style>
  header {
    position: sticky;
    top: 0;
    z-index: 20;
    background: var(--paper);
    border-bottom: var(--line) solid var(--ink);
  }
  .bar { display: flex; align-items: center; gap: 1.2rem; min-height: 3.6rem; }
  .mark {
    font-family: var(--display);
    font-weight: 900;
    font-stretch: 125%;
    font-size: 1.9rem;
    letter-spacing: -0.02em;
    text-decoration: none;
    line-height: 1;
    padding: 0.1rem 0.3rem;
  }
  .mark span { color: var(--blue); }
  .mark { color: var(--ink); }
  .mark:hover { background: var(--blue); color: var(--blue-ink); }
  .mark:hover span { color: var(--blue-ink); }
  nav { display: flex; gap: 0.2rem; margin-left: auto; }
  nav a {
    font-family: var(--mono);
    font-weight: 700;
    font-size: 0.85rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    text-decoration: none;
    padding: 0.35rem 0.7rem;
    border: 2px solid transparent;
  }
  nav a { color: var(--ink); }
  nav a:hover { background: var(--blue); color: var(--blue-ink); }
  nav a.here { border-color: var(--ink); background: var(--slab); box-shadow: 3px 3px 0 var(--ink); }
  nav a.here:hover { background: var(--blue); color: var(--blue-ink); }
  .burger {
    display: none;
    margin-left: auto;
    font-family: var(--mono);
    font-weight: 700;
    text-transform: uppercase;
    font-size: 0.8rem;
    background: var(--slab);
    color: var(--ink);
    border: var(--line) solid var(--ink);
    padding: 0.3rem 0.6rem;
  }
  @media (max-width: 52rem) {
    .burger { display: block; }
    nav {
      display: none;
      position: absolute;
      left: 0;
      right: 0;
      top: 100%;
      flex-direction: column;
      background: var(--paper);
      border-bottom: var(--line) solid var(--ink);
      padding: 0.6rem 1rem 1rem;
    }
    nav.open { display: flex; }
    .theme { order: 3; }
  }
</style>
