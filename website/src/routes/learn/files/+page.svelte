<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Example from '$lib/components/Example.svelte';
  import Callout from '$lib/components/Callout.svelte';
</script>

<svelte:head><title>Files · Learn Zue</title></svelte:head>

<LessonHead title="Files" lead="Read and write text files." />

<h2>Files</h2>

<p>
  Paths are relative to the working directory of the running program, not to the source file. A file handle has
  <code>type()</code> <code>"file"</code>.
</p>

<Example id="io-files" />

<div class="table-scroll">
  <table>
    <thead><tr><th>Function</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>open(path, mode)</code></td><td>Mode <code>"r"</code>, <code>"w"</code> or <code>"a"</code>. Returns a handle, or <code>null</code> if it cannot be opened. Another mode is an <code>Argument Error</code></td></tr>
      <tr><td><code>close(handle)</code></td><td>Flushes and closes. Closing twice is a run-time error</td></tr>
      <tr><td><code>write(handle, text)</code></td><td>Writes a string</td></tr>
      <tr><td><code>read(handle)</code></td><td>The rest of the file as one string</td></tr>
      <tr><td><code>read_line(handle)</code></td><td>The next line without its newline. <code>null</code> at the end of the file. An empty line is <code>""</code></td></tr>
      <tr><td><code>file_exists(path)</code></td><td><code>true</code> if the path exists</td></tr>
      <tr><td><code>remove_file(path)</code></td><td>Deletes the file. <code>true</code> on success</td></tr>
      <tr><td><code>flush(handle)</code></td><td>Writes buffered data without closing</td></tr>
    </tbody>
  </table>
</div>

<Callout kind="rule" title="four habits">
  <p>Compare the result of <code>open</code> with <code>null</code> before using it: <code>if (file)</code> is a type error, since a condition must be a boolean.</p>
  <p>Close every file, or write <code>defer(close(f))</code> right after opening it. The collector never closes files.</p>
  <p><code>read()</code> loads everything into memory, so for a large file use <code>read_line()</code>.</p>
  <p>Using a handle after <code>close</code> is an error: <code>write() on a closed file</code>.</p>
</Callout>

<p>
  Modes: <code>"r"</code> reads an existing file (<code>open</code> returns <code>null</code> if it is missing),
  <code>"w"</code> creates the file or truncates it, and <code>"a"</code> appends, creating it if needed.
</p>
