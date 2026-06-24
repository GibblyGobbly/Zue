<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Link from '$lib/components/Link.svelte';
</script>

<svelte:head><title>Changing text · Learn Zue</title></svelte:head>

<LessonHead title="Changing text" lead="Upper and lower case, trimming, replacing, splitting and joining. Each one gives you a new string." />

<h2>Making new strings</h2>

<Example id="strings-edit" />

<ul>
  <li><code>replace</code> always replaces every match. There is no single-occurrence version, and an empty <code>old</code> changes nothing.</li>
  <li><code>split</code> drops empty pieces, and an empty delimiter splits into characters.</li>
  <li><code>to_int</code> and <code>to_float</code> read the whole text, spaces around it allowed. Text that is not a number, a number outside the 64-bit range, and the words <code>nan</code> and <code>inf</code> are all errors.</li>
  <li><code>fixed(x, decimals)</code> and <code>to_string(x, digits)</code> format floats. See <Link href="/learn/values/">Values and variables</Link>.</li>
</ul>

<h2>Two example programs</h2>

<p>A username check that returns early on each bad case:</p>

<Example id="strings-validator" />

<p>A title banner and a word filter:</p>

<Example id="strings-banner" />
