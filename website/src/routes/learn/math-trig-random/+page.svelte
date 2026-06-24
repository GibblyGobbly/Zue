<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Angles and random numbers · Learn Zue</title></svelte:head>

<LessonHead title="Angles and random numbers" lead="Sine and cosine, and random numbers that you can repeat or not." />

<h2>Trigonometry</h2>

<Example id="math-trig" />

<p>
  Angles are in radians and every result is a float. <code>asin</code> and <code>acos</code> need an argument between
  -1 and 1. <code>sinh</code>, <code>cosh</code> and <code>tanh</code> are the hyperbolic functions, and
  <code>lerp(a, b, t)</code> is linear interpolation.
</p>

<h2>Random numbers</h2>

<Example id="math-random" />

<div class="table-scroll">
  <table>
    <thead><tr><th>Call</th><th>Gives</th></tr></thead>
    <tbody>
      <tr><td><code>rand()</code></td><td>A float in <code>[0, 1)</code></td></tr>
      <tr><td><code>rand(max)</code>, <code>rand(min, max)</code></td><td>An int, both ends included. Arguments must be ints</td></tr>
      <tr><td><code>srand(seed)</code></td><td>Seeds the generator, so a sequence repeats. <code>srand()</code> reseeds from the OS</td></tr>
      <tr><td><code>trand()</code>, <code>trand(max)</code>, <code>trand(min, max)</code></td><td>The same shapes, from the operating system's entropy source (<code>getrandom</code>). Cannot be repeated, and <code>srand</code> does not affect it</td></tr>
    </tbody>
  </table>
</div>

<p>
  The generator is xoroshiro128++, and <code>srand</code> expands the seed with SplitMix64. Ranges are exact: a draw
  that would favour small values is thrown away and drawn again. The seed 7 gives 17 and then 100 on every
  run. <code>trand</code> costs a system call per number, so use <code>rand</code> in a hot loop.
</p>

<Example id="math-dice" />
