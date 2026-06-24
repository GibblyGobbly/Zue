<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>Functions · Learn Zue</title></svelte:head>

<LessonHead title="Functions" lead="Define a function, give a parameter a default value, and call it." />



<h2>Definitions, defaults, anonymous functions</h2>

<Example id="func-basics" />

<p>
  A parameter with a default must come after the ones without. Calling with the wrong number of arguments is an
  <code>Argument Error</code> that names the function: <code>area() expects 2 arguments, but got 1</code>.
</p>

<Example id="errors-arity" shown />

<h2>Order matters at the top level</h2>

<Callout kind="rule" title="a func exists once execution reaches it">
  <p>
    Names are looked up when the statement runs. A <code>func</code> is defined when execution gets to it, so calling a
    function above its definition at the top level is a <code>Name Error</code>. A function can call another that is
    defined later in the file, as long as the call happens after that definition ran.
  </p>
</Callout>

<Example id="func-order" shown />

<Example id="func-order-ok" />
