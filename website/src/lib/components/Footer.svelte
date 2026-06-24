<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { base } from '$app/paths';
</script>

<footer>
  <div class="hatch"></div>
  <div class="wrap row">
    <p><strong>Zue</strong> is free software under the GPL-3.0-or-later. Every example on this site was run with the real compiler.</p>
    <p class="links">
      <a href="{base}/learn/hello-world">Learn</a>
      <a href="{base}/internals/memory/">Inside</a>
      <a href="{base}/reference">Reference</a>
      <a href="{base}/playground">Playground</a>
    </p>
  </div>
</footer>

<style>
  footer { margin-top: 5rem; background: var(--paper); }
  .row { display: flex; flex-wrap: wrap; gap: 1rem 2rem; justify-content: space-between; padding-block: 1.4rem 2.4rem; font-size: 0.92rem; }
  p { margin: 0; max-width: 46ch; }
  .links { display: flex; gap: 1.1rem; font-family: var(--mono); font-weight: 700; text-transform: uppercase; font-size: 0.8rem; }
</style>
