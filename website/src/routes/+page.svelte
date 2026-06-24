<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import { base } from '$app/paths';
  import Example from '$lib/components/Example.svelte';
  import SyntaxTabs from '$lib/components/SyntaxTabs.svelte';
  import Bars from '$lib/components/Bars.svelte';

  const tabs = [
    { label: 'Text', id: 'strings-basic' },
    { label: 'Closures', id: 'func-closure' },
    { label: 'Records', id: 'template-basic' },
    { label: 'Threads', id: 'threads-pipeline' },
    { label: 'Unsafe', id: 'unsafe-basic' }
  ];

  const points = [
    {
      n: '01',
      title: 'Error messages that point at the problem',
      text: 'Zue shows the line and underlines the part that is wrong, then gives a hint. If a file has five mistakes, you see all five at once, so you fix them in one go.',
      href: '/learn/errors/',
      link: 'Reading an error'
    },
    {
      n: '02',
      title: 'You never free memory',
      text: 'Zue cleans up the memory your program has finished with, while the program keeps running.',
      href: '/internals/gc/',
      link: 'How the cleanup works'
    },
    {
      n: '03',
      title: 'Wrong numbers stop the program',
      text: 'If a number is too big to store, or a calculation has no answer, like the square root of -1, Zue stops and tells you. It does not carry on with a wrong value.',
      href: '/learn/numbers/',
      link: 'Numbers'
    },
    {
      n: '04',
      title: 'Many jobs in one program',
      text: 'Blue threads let a program do several things in turns. One test started twenty thousand of them.',
      href: '/learn/blue-threads/',
      link: 'Blue threads'
    },
    {
      n: '05',
      title: 'Low-level control when you want it',
      text: 'Most programs never need it. When yours does, unsafe lets you manage memory by hand, with ten checks that catch the usual mistakes.',
      href: '/learn/unsafe/',
      link: 'unsafe'
    },
    {
      n: '06',
      title: 'Zue is written in Zue',
      text: 'The compiler, and the part of Zue that runs inside every program, are Zue programs themselves.',
      href: '/internals/self-hosting/',
      link: 'How Zue builds itself'
    }
  ];
</script>

<svelte:head>
  <title>Zue, a programming language that explains its errors</title>
  <meta name="description" content="Zue is a programming language. You write a text file, and Zue turns it into a program your computer runs. Its error messages show the exact line and say how to fix it." />
</svelte:head>

<section class="hero wrap">
  <div class="copy">
    <p class="kicker">A programming language</p>
    <h1>Zue explains its errors.</h1>
    <p class="sub">
      You write your program in a text file, and Zue turns it into a program your computer can run. When something is wrong,
      Zue shows you the exact line and says how to fix it.
    </p>
    <p class="go">
      <a class="btn primary" href="{base}/learn/hello-world/">Start learning</a>
      <a class="btn" href="{base}/reference/">Look something up</a>
    </p>
  </div>
  <div class="live">
    <Example id="hello-name" title="main.zu" />
    <p class="hint">Press RUN. This output was recorded from the real compiler.</p>
  </div>
</section>

<div class="hatch"></div>

<section class="wrap tour">
  <div class="tourtext">
    <h2>What a program looks like</h2>
    <p>
      This one makes a list of three names, defines a function that builds a greeting, and prints one greeting for each name.
      There are no semicolons and no type declarations.
    </p>
    <p>New to programming? The tutorial starts from <code>print("Hello, World!")</code> and goes one step at a time.</p>
  </div>
  <Example id="home-tour" shown />
</section>

<section class="wrap points" aria-labelledby="why">
  <h2 id="why" class="sr-only">What you get</h2>
  {#each points as p, i}
    <div class="point" class:big={i === 0}>
      <span class="n" aria-hidden="true">{p.n}</span>
      <div>
        <h3>{p.title}</h3>
        <p>{p.text}</p>
        <a href="{base}{p.href}">{p.link}</a>
      </div>
    </div>
  {/each}
</section>

<section class="wrap syntax">
  <h2>More programs to try</h2>
  <p class="lead">Click a tab, read the code, press RUN.</p>
  <SyntaxTabs {tabs} />
</section>

<section class="wrap gc">
  <div class="gcnote">
    <h2>How long does cleanup hold the program up?</h2>
    <p>
      Memory cleanup runs on its own thread, so your program seldom waits for it. We timed a loop that keeps millions of rows in
      memory and creates new data all the time.
    </p>
    <p>
      The bars show the longest wait the loop saw in a 20 second run, next to the same program written in Go. These come from one
      machine and one run each. Zue also used more memory than Go in this test.
    </p>
    <a class="btn" href="{base}/internals/gc-measured/">See the full numbers</a>
  </div>
  <Bars unit=" ms" items={[
    { label: 'Zue, 4.8 M rows', value: 0.56, tone: 'blue' },
    { label: 'Go, 4.8 M rows', value: 11.8 },
    { label: 'Zue, 19 M rows', value: 1.01, tone: 'blue' },
    { label: 'Go, 19 M rows', value: 3.1 }
  ]} />
</section>

<style>
  .hero { display: grid; grid-template-columns: minmax(0, 5fr) minmax(0, 6fr); gap: 3rem; padding-block: 3.4rem 3.6rem; align-items: start; }
  .kicker { font-family: var(--mono); font-weight: 700; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.1em; color: var(--blue); margin: 0 0 1rem; }
  h1 { font-size: clamp(2.6rem, 5.4vw, 4.8rem); text-transform: none; font-stretch: 112%; line-height: 0.98; }
  .sub { font-size: 1.22rem; max-width: 34rem; margin: 1.4rem 0 0; }
  .go { display: flex; flex-wrap: wrap; gap: 0.9rem; margin: 2rem 0 0; }
  .hint { font-family: var(--mono); font-size: 0.78rem; color: var(--mute); margin: 0.9rem 0 0; }
  .live :global(.ex) { margin-top: 0; }

  .tour { display: grid; grid-template-columns: minmax(0, 5fr) minmax(0, 6fr); gap: 3rem; padding-block: 3.2rem 2rem; align-items: start; }
  .tourtext p { max-width: 40ch; }
  .tourtext h2 { margin-bottom: 1rem; }

  .points { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 3rem; padding-block: 2rem 3rem; }
  .point { display: grid; grid-template-columns: 3.6rem 1fr; gap: 1rem; padding: 1.4rem 0; border-top: var(--line) solid var(--ink); }
  .point.big { grid-column: 1 / -1; padding-block: 2rem; }
  .point:last-child { grid-column: 1 / -1; }
  .point.big h3 { font-size: clamp(1.7rem, 3.6vw, 2.6rem); max-width: 24ch; }
  .point.big p { font-size: 1.15rem; max-width: 60ch; }
  .n { font-family: var(--display); font-weight: 900; font-stretch: 125%; font-size: 2.3rem; line-height: 1; color: transparent; -webkit-text-stroke: 2px var(--ink); }
  .point h3 { font-size: 1.3rem; margin-bottom: 0.5rem; }
  .point p { margin: 0 0 0.7rem; max-width: 46ch; }
  .point a { font-family: var(--mono); font-weight: 700; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.05em; }

  .syntax { padding-block: 2rem 3rem; }
  .syntax .lead { max-width: 54ch; margin: 0.8rem 0 1.4rem; font-size: 1.1rem; }

  .gc { display: grid; grid-template-columns: minmax(0, 5fr) minmax(0, 6fr); gap: 3rem; padding-block: 2rem; align-items: start; border-top: var(--line) solid var(--ink); }
  .gcnote h2 { margin-bottom: 1rem; }
  .gcnote p { max-width: 44ch; margin: 0 0 1rem; }

  @media (max-width: 62rem) {
    .hero, .gc, .tour { grid-template-columns: 1fr; gap: 2rem; }
    .points { grid-template-columns: 1fr; }
  }
</style>
