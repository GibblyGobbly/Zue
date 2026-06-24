<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
<!-- Copyright (c) 2026 GibblyGobbly -->
<script>
  import LessonHead from '$lib/components/LessonHead.svelte';
  import Listing from '$lib/components/Listing.svelte';
</script>

<svelte:head><title>Zue written in Zue · Zue</title></svelte:head>

<LessonHead title="Zue written in Zue" lead="What the compiler and runtime are made of." />



<h2>What is written in Zue</h2>

<div class="table-scroll">
  <table>
    <thead><tr><th>Directory</th><th>What it is</th></tr></thead>
    <tbody>
      <tr><td><code>compiler/</code></td><td>The compiler: lexer, parser, type checker, analysis, and the code generator</td></tr>
      <tr><td><code>compiler/runtime/</code></td><td>The runtime: the garbage collector, values, strings, lists and maps, operators, builtins, blue threads, and the rules behind <code>unsafe</code>, <code>bloc</code>, <code>box</code> and <code>template</code></td></tr>
      <tr><td><code>bootstrap/</code></td><td>Committed text files, the compiler and the runtime already compiled. The only way to build the first <code>zue</code></td></tr>
    </tbody>
  </table>
</div>

<h2>The pipeline</h2>

<Listing lang="text" file="what zue does to prog.zu" code={`prog.zu
  lexer.zu      tokens, each with line, column and end
  parser.zu     the tree (AST), one template per kind of node
  check.zu      the compile-time type check (main file and imports)
  analysis.zu   which names a function reads and writes, exports, closure captures
  emit_llvm.zu  the program as LLVM IR text
  -> linked with the runtime into a native program`} />

<p>
  The compiler reads imported modules while it compiles, so one output file holds the program and every module it uses.
  A syntax error does not stop the lexer or the parser: the error is recorded, the parser skips to the start of the next
  statement, and every error in the file is reported in one run.
</p>

<h2>Two dialects</h2>

<p>
  The compiler turns ordinary Zue into native code with <code>emit_llvm.zu</code>. The <strong>runtime</strong> cannot be written in the
  ordinary language, because it is what implements the ordinary language: it has to read and write raw memory. So it is written in the
  <em>native dialect</em>: Zue syntax with one 64-bit word type and memory intrinsics such as <code>ld64</code>, <code>st64</code>,
  <code>ld8</code> and <code>stack_buf</code>. A second backend, <code>emit_native.zu</code>, compiles that dialect. It compiles the runtime
  and nothing else.
</p>

<Listing file="from compiler/runtime/zue_gc.zu" code={`func _class_size(c) {
    return ld32(addr_of("_class_sizes") + c * 4)
}

# The page descriptor is a block of fields at fixed offsets.
const PG_BASE = 0
const PG_OBJ = 8
const PG_NOBJS = 16       # u32`} />
