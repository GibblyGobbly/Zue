<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Link from '$lib/components/Link.svelte';
  import Listing from '$lib/components/Listing.svelte';
</script>

<svelte:head><title>Input and arguments · Learn Zue</title></svelte:head>

<LessonHead title="Input and arguments" lead="How a program reads what the user types, and what you can pass to it on the command line." />

<h2>Asking for input</h2>

<p>
  <code>input(prompt)</code> writes the prompt and returns one line from standard input, without the newline. At
  the end of input it returns an empty string. Here the recorded run was given the single line
  <code>Astra</code>, so the second <code>input</code> gets nothing.
</p>

<Example id="ask-name" />

<h2>Arguments, and building a program</h2>

<p>
  <code>args()</code> returns the command-line arguments after the program name, as a list of strings. Nothing
  was passed here, so the list is empty.
</p>

<Example id="args-demo" />

<p>On your own machine, the same files turn into programs with the <code>zue</code> command:</p>

<Listing lang="bash" file="terminal" code={`zue run hello.zu            # build and run
zue build hello.zu -o hello # write a native program
./hello
zue check hello.zu          # find every error without building`} />

<p>
  <code>zue run prog.zu a b</code> passes <code>a</code> and <code>b</code> to <code>args()</code>. The full list
  of commands is in the <Link href="/reference/commands/">reference</Link>.
</p>
