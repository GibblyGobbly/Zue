# How Zue's front end was built and checked

This page records the techniques behind the lexer, the parser, the type checker, the memory rules
and the test tools, the results they gave, and where the ideas came from.

## Credit

Zue is designed and owned by GibblyGobbly, who set the language rules: strict and explicit, no
implicit conversion, no inf or NaN, a variable keeps its type, no null, and the memory model of
`box`, `bloc` and `template`. Much of the implementation from October 2026 onward was written with
Claude Code, Anthropic's AI coding assistant (model Claude Sonnet 5.5), working from those rules and
checked against the tests below. That covers the lexer and parser rewrite, the type checker, the
`unsafe` redesign, typed fields, the stack `box`, and the verification tools. Every change is
covered by tests in `test/`.

## Techniques

### Lexer and parser

| Technique | Where | Why |
|---|---|---|
| Hand-written lexer with tables indexed by byte code | `compiler/lexer.zu` | No string or map work for operators |
| Tokens as `template` objects, not maps | `compiler/lexer.zu` | About 5 times faster to make and 4 times smaller than a map |
| Syntax tree nodes as `template` objects, built by `mk_*` functions (one type per kind until phase 4 of Zue 2; now one `Node` for every kind, see below) | `compiler/ast_nodes.zu` | A node is made in one call with fixed field places: 2.5 times fewer instructions than building a map. With the faster template field read, the lexer, parser and checker run 7 to 9 percent fewer instructions, and compiling the compiler itself 4 percent fewer |
| Inline cache for template field reads: each `obj.field` site remembers the template type and field index it saw last | `lvp_field_ic` in `compiler/runtime/zue_rt_ops.zu`, `ll_ic` in `compiler/ll_state.zu` | A hit is a pointer compare and a copy, not a scan of the field names. About 7 percent fewer instructions compiling the compiler |
| Interpolation and `join` of strings built with one exact-size allocation | `lv_interp`, `lb_join` | No scratch buffer to grow and copy. The final join of the whole IR no longer doubles a buffer repeatedly |
| GC pages cut from 2 MB huge-page-advised chunks, a two-level page table, a reciprocal multiply for the object index | `compiler/runtime/zue_gc.zu` | Fewer page faults, cheaper pointer checks while marking |
| Recursive descent with a Pratt (precedence climbing) table for binary operators | `compiler/parser.zu` | One table row per operator; adding `**` and the bitwise operators was a one-line change each |
| The current token and its kind kept in variables | `compiler/parser.zu` | Asking "what is the next token?" is a comparison, not a call |
| Line breaks ignored inside brackets by lowering the bracket depth before the closing token | `compiler/parser.zu` | Multi-line calls and literals without a continuation character |
| Contextual keywords (`data`, `in`, `from`) | `compiler/parser.zu` | They stay usable as names |
| Strings scanned in one pass, with a nested-string scanner for `"{...}"` | `compiler/lexer.zu` | Quotes inside an interpolation work |
| One dispatch on a byte class (operator, identifier, digit, blank, newline, quote, `#`, `/`), operator tokens from tables built at start-up | `compiler/lexer.zu` | A token costs one table read, and an operator allocates nothing but the token |
| Runs inside a token (identifier, digits, blanks, string bodies, comments) skipped by native builtins `skip_chars`, `index_of_any` and `index_of`, which keeps a 256-byte lookup table for each recent set and uses `memmem` | `compiler/runtime/zue_rt_lib.zu` | The lexer is about 1.85 times faster with identical tokens on 90 files |
| Slice syntax `x[a:b]` parsed in the same postfix branch as `x[i]`; one runtime function `lvp_slice` for strings and lists | `compiler/parser.zu`, `compiler/runtime/zue_rt_ops.zu` | A slice is an `NSlice` node, checked by the type checker and printed back by `unparse` |

### Errors

| Technique | Where | Why |
|---|---|---|
| Every token and node knows its line, column and end; the node constructors take them, instead of setting fields afterwards | `compiler/lexer.zu`, `compiler/ast_nodes.zu` | Setting three fields after building a node cost about 50 ns a node against 13 ns in the constructor; the parser's extra cost fell from 36 % to 16 % |
| One `Node` template for every kind of node (63 fields, the unused ones empty), built by `node()` and then setting the fields of its kind | `compiler/ast_nodes.zu` | Every node has one type the checker knows. Compiling the compiler: 151 MB to about 205 MB of memory, 0.85 s to about 0.92 s. Setting fields after `node()` costs more than passing them to the constructor; a compact node (docs/plan.md, phase 4) is the larger saving |
| A token is used as a span (it has the same line, col, eline and ecol), so no span object is allocated for names, operators and arguments | `compiler/parser.zu` | Nothing extra to allocate or mark in the garbage collector |
| Panic-mode recovery: the first error in a statement mutes the parser until the statement ends; a forgotten closing bracket is found where the next line starts; at most one syntax error per line | `compiler/parser.zu` | Several real errors in one run, no false follow-up errors (the idea Go's parser and rustc use) |
| Declarations are noted when a block starts, and a name used but declared nowhere is judged at the end of the check | `compiler/check.zu` | A function may use a global declared below it; only real typos are reported, with no extra walk of the tree |
| Edit distance with swapped neighbours for "did you mean" | `compiler/diag.zu` | `itms` suggests `items`; a difference in case alone counts |
| The place of a running operation is one 64-bit store (line, column, length, operator offset); in-line int and float arithmetic stores it only on its slow path | `compiler/ll_state.zu`, `compiler/runtime/zue_rt_core.zu` | Exact carets at run time with no cost on the fast path; run speed is unchanged |
| A shadow stack in `lvp_call` (place, module, function name) | `compiler/runtime/zue_rt_ops.zu` | The call stack under every run-time error costs three stores a call |
| The error codes come from one text file; a script generates the compiler table, the runtime lookup and the list in `errors.md` | `compiler/error_codes.txt`, `tools/gen_error_codes.py` | One place to edit; `make codes-check` runs every example |
| A signal handler on its own stack | `compiler/runtime/zue_rt_ops.zu` | A crash, including running out of stack, is reported with the line and the calls |
| Line tables in the IR, attached to the existing position stores | `compiler/ll_state.zu` | `zue build -g` costs one metadata node per distinct place and nothing when it is off |

### Type checking

| Technique | Where |
|---|---|
| Gradual checking: report only what can be proved, leave the rest to run-time checks | `compiler/check.zu` |
| Untyped number constants: a literal adapts to the type its context needs, a variable never converts (the Go rule) | `compiler/check.zu` |
| Checking a function body once per distinct list of argument types, remembered in a table, with a base-case rule for recursion (the idea behind C++ templates and Zig's `comptime`) | `compiler/check.zu` |
| Literal adaptation rewrites the syntax tree: `Vec{1, 2}` becomes floats for float fields | `compiler/check.zu` |

### Memory and `unsafe`

| Technique | Where | Inspired by |
|---|---|---|
| Generation-checked handles: a handle holds a slot number and a generation, so a freed box is detected as a stale handle | `zue_rt_data.zu` | Vale's generational references |
| A table of every raw allocation with a "freed" mark, so use-after-free and double free are errors | `zue_rt_data.zu`, `zue_rt_rules.zu` | Zig's debug allocator |
| A leak rule: every `alloc` must be freed or deferred before its block ends | `zue_rt_data.zu` | Zig's leak detection |
| Pointer escape checked where a value is assigned or returned, using the scope of each variable | `compiler/emit_llvm.zu` | Rust's rule that a reference cannot outlive its scope |
| `box[n]` with a literal size lives in the function's own stack frame (`alloca`) | `compiler/emit_llvm.zu` | Zig and C stack arrays |
| A chunked box table with a free list, so slot addresses never move and no limit on live boxes | `zue_rt_data.zu` | |
| A creation stack for scope release, so ending a scope looks only at the newest boxes | `zue_rt_data.zu` | |

### Speed

| Technique | Effect |
|---|---|
| Profile first with `valgrind --tool=callgrind` and count instructions, which do not depend on machine load | `bench/instruction_count.sh` |
| Inline the common case in generated code: reading a defined global and testing a boolean condition are plain loads, and the runtime is called only for the error | Every program |
| Fast paths for string and character comparisons in the runtime | Lexer and parser |
| LSD radix sort (8-bit digits, passes skipped when a digit is the same everywhere) when a list has 256 or more non-negative ints; the scan that decides this stops at the first item that does not qualify | `sort` of 100,000 ints 8 ms to 2.2 ms; 1,000,000 ints 95 ms to 23 ms. Below 256 items the insertion and merge sort is faster, so it stays |
| `getrandom` for OS entropy in one system call, read in 2 KB blocks for `tshuffle` | `trand()` 12 microseconds to about 0.5 |
| Unbiased integers by rejection: a draw below 2^64 mod range is thrown away | Every value of `rand(a, b)`, `trand(a, b)` and every shuffle index is equally likely |
| Replace maps with templates for tokens | 38 % faster lexing, 54 % less memory |

### Checking the work

| Tool | What it proves |
|---|---|
| Golden-file tests: output, errors and exit status of every program are recorded and compared | Behaviour does not change by accident |
| Runtime checks: a test (or a `# CASE`) that contains the line `# test: no-strict` is compiled with `zue --no-strict`, which keeps strict mode silent, so the test can hide a type (`func pass(v) { return [v, null][0] }`) and reach a check the runtime makes itself. The switch is for the test suite only, not part of the language | The runtime's own type checks, which guard values the checker cannot see, keep their tests |
| Syntax matrix (`test/test_syntax.zu`) with hand-checked outputs | Every construct and every precedence pair |
| Round trip (`make round-trip`): parse, print back as source, parse again, require the same tree | The parser and the printer agree on all 620 project files and cases |
| Mutation fuzzing (`tools/fuzz_syntax_errors.py`): real programs are broken at random and `zue check` must not crash, hang or name a line that does not exist | The error paths of the lexer, the parser and the checker hold up on thousands of broken programs |
| Differential fuzzing (`make fuzz`): random expressions and whole programs are run by Zue and by an independent Python model | Precedence, scoping, loops and functions are right. Runs of 12,000 expressions and 750 programs found no compiler bug |
| LLVM verifier (`make verify-ir`) on the IR of every test | The code generator never writes malformed IR |
| Testing the tests: a deliberately wrong rule is fed to each fuzzer, which must fail | A passing run means something |
| Self-hosting fixed point: the compiler builds itself until two stages emit identical IR (`tools/bootstrap_until_stable.sh`) | The compiler is stable and reproducible |

## Results

Measured on a 188 KB file of 56,000 tokens, and by instruction count.

| Measure | Before | After |
|---|---|---|
| Lexing | 0.053 s | 0.028 s |
| Parsing | 0.047 s | 0.038 s |
| Type checking | 0.022 s | 0.008 s |
| Instructions, generated 2,000-line file | 176.7 M | 102.1 M (42 % fewer) |
| Instructions, `emit_llvm.zu` | 114.9 M | 65.5 M (43 % fewer) |
| 300,000 small boxes in a loop | 0.079 s (heap) | 0.047 s (stack) |
| 100,000 tokens as maps against templates | 0.050 s, 67 MB | 0.0095 s, 16 MB |
| Lexing 5 source files | 35.5 ms | about 19 ms |
| Compiling the compiler (time, peak memory) | 340 ms, 112 MB | 210 ms, 85 MB |
| String benchmark | 450 ms | 230 ms |
| `sort` of 1,000,000 random ints | 95 ms | 23 ms |
| `trand()` | 12 microseconds | about 0.5 microseconds |
| Compiling the compiler after the error work (instructions) | 2,191 M | 2,228 M (+1.7 %); the IR grows 2.9 % because of the position stores, and the compile takes about 10 % longer |
| Programs at run time (fib 32 and a list loop) | 0.071 s | 0.071 s |

The runtime figures compare the commit before the runtime work (`6a3b3b9`) with the current one,
on the same machine (an AMD Ryzen 7 7435HS).

## Where the time goes

Compiling the compiler is about 1,805 million instructions. The garbage collector is not the
cause: with it switched off the time is the same (see [gc](gc.md#measured-cost)).

| Phase | Share of the instructions |
|---|---|
| Reading and splitting the source | 1.7 % |
| Lexing | 5.2 % |
| Parsing | 7.3 % |
| Type checking | 5.9 % |
| Tree walks (names used, nested functions, address use) | 16 % |
| Emitting and joining the IR text | about 64 % |

Inside emission the hot spots are making register names (`ll_reg`, 13.7 %, through `snprintf`),
escaping string constants one character at a time (`ll_cstr`, 10.1 %), and `ll` (9 %). The IR text is
held three times (the per-function joins, the whole join, and the final newline), which is most of
the 35 MB live at exit. These are known and not yet changed.

## The memory model

| Type | Lives | May hold | In `unsafe` |
|---|---|---|---|
| `box` | Stack (literal size) or heap, up to 16 MiB | Bytes only | Not allowed |
| `bloc` | Heap, garbage collected, immutable, up to 64 bytes | `int`, `float`, `bool`, `char`, `string`, other blocs, `box[N]` (a read-only copy) | Allowed; `alloc(bloc)` for hand-managed |
| `template` | Heap, garbage collected | Anything, including blocs, boxes and other templates | Allowed; `alloc(template)` for hand-managed |

The ten `unsafe` rules are listed in [unsafe](unsafe.md).

## Releases

The version is in the `VERSION` file. The workflow in `.github/workflows/release.yml` does not run on
ordinary pushes or pull requests. It runs when a tag that starts with `v` is pushed. It builds, checks
that the seeds follow the sources, runs `make test`, packages the build with `tools/package_release.sh`
and publishes the archive and its checksum as a GitHub release.

```bash
echo 0.0.4 > VERSION        # change the version, commit it
git tag v0.0.4              # the tag must match VERSION or the workflow stops
git push origin main v0.0.4
```

## The website

`website/` is a SvelteKit site (Svelte 5, static output) with the tutorial, the internals pages, the reference and a
playground. It needs `bin/zue`, so run `make` first.

| Command (in `website/`) | Effect |
|---|---|
| `npm install` | Install the packages |
| `npm run record` | Run every program in `website/examples/` with the real compiler and store the code with its true output. A file named `name.err.zu` must fail, any other must exit 0. `name.in` is the standard input and `name.env` holds `KEY=value` lines. A folder with a `main.zu` is a multi-file example |
| `npm run reference` | Build the reference tables from `docs/builtins.md`, `docs/unsafe.md`, `docs/errors.md`, `docs/getting-started.md` and `docs/gc.md` |
| `npm run check` | Fail when a builtin of `compiler/shared.zu` is missing from the reference or from every example |
| `npm run dev`, `npm run build`, `npm run preview` | Develop, build to `website/build/`, and serve the build. `build` runs `record` and `reference` first |

The Run button shows the recorded output of an unchanged program. Changed code needs a run server, which is not
built yet: set `VITE_RUN_URL` to its address and the page will POST `{files, stdin}` to it and show the answer.

## Sources

Ideas used, with the pages they came from:

- Pratt parsing and precedence climbing: [Norvell, From Precedence Climbing to Pratt Parsing](https://www.engr.mun.ca/%7Etheo/Misc/pratt_parsing.htm).
- Allocation-light compilers: [Zig's flat syntax tree](https://git.jakstys.lt/motiejus/zig/commit/4dca99d3f6b732c415d270f0c97def144ed6d3b7.patch) and [Tweede Golf on data-oriented design](https://tweedegolf.nl/en/blog/88/data-oriented-design/).
- Generation-checked handles: [Vale, generational references](https://vale.dev/blog/generational-references).
- Debug allocators that find leaks and double frees: [Zig allocators](https://www.mintlify.com/ziglang/zig/stdlib/allocators).
- What `unsafe` should allow: [The Rust Book, Unsafe Rust](https://rust-lang.github.io/book/ch20-01-unsafe-rust.html).
- Grammar-based and differential testing of compilers: [TENSURE](https://arxiv.org/pdf/2603.18372) and [the Kotlin compiler study](https://arxiv.org/pdf/2401.06653).
- Instruction counts as a stable speed measure: [rustc performance reports](https://github.com/rust-lang/rust/pull/88069).
- Why dynamic languages are slow and how unboxed values help: [Bigot and Debray](https://www2.cs.arizona.edu/~debray/Publications/unboxopt.html). This is the motivation for the typed code generation planned next; it is not built yet.
