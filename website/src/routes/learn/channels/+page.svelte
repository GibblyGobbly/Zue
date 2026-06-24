<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
</script>

<svelte:head><title>Channels · Learn Zue</title></svelte:head>

<LessonHead title="Channels" lead="Send values from one thread to another." />

<h2>A pipeline</h2>

<p>The producer, the squarer and the main thread are three stages joined by two channels.</p>

<Example id="threads-pipeline" />

<h2>A channel with no room: the handover</h2>

<p>
  <code>channel()</code> holds nothing, so a <code>send</code> and a <code>recv</code> have to meet. The sender prints only
  after the main thread has taken the value.
</p>

<Example id="threads-rendezvous" />

<h2>Closing a channel</h2>

<Example id="threads-close" />
