<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { base } from '$app/paths';
  // An internal link that keeps working when the site is served from a sub-path.
  let { href, children } = $props();
</script>

<a href="{base}{href}">{@render children?.()}</a>
