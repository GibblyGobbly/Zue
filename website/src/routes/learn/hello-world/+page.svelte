<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>Hello, World · Learn Zue</title></svelte:head>

<LessonHead title="Hello, World" lead="Your first program is one line. Press RUN, change the text, and run it again." />

<Example id="hello" />

<p>
  <code>print</code> writes its argument and a newline. There are no semicolons: one statement per line, and
  blocks use <code>{'{ }'}</code>. A comment starts with <code>#</code> or <code>//</code>.
</p>

<h2>Putting values into text</h2>

<p>
  A double-quoted string runs any expression written inside <code>{'{ }'}</code>. A second form fills
  empty <code>{'{}'}</code> slots from the values that follow the string.
</p>

<Example id="hello-name" />

<Callout kind="rule" title="print with several arguments">
  <p>
    <code>print(a, b, c)</code> prints each argument on its own line. For one line, use interpolation:
    <code>print("{'{a}'} {'{b}'}")</code>. The <code>{'{}'}</code> form needs exactly one value for each slot.
  </p>
</Callout>

<h2>A program that runs top to bottom</h2>

<p>
  The top-level statements run in order. If the file also defines a function called <code>main</code> that takes no
  arguments, it runs by itself after the top level finishes.
</p>

<Example id="hello-main" />
