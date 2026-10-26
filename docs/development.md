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
| Recursive descent with a Pratt (precedence climbing) table for binary operators | `compiler/parser.zu` | One table row per operator; adding `**` and the bitwise operators was a one-line change each |
| The current token and its kind kept in variables | `compiler/parser.zu` | Asking "what is the next token?" is a comparison, not a call |
| Line breaks ignored inside brackets by lowering the bracket depth before the closing token | `compiler/parser.zu` | Multi-line calls and literals without a continuation character |
| Contextual keywords (`data`, `in`, `from`) | `compiler/parser.zu` | They stay usable as names |
| Strings scanned in one pass, with a nested-string scanner for `"{...}"` | `compiler/lexer.zu` | Quotes inside an interpolation work |

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
| Replace maps with templates for tokens | 38 % faster lexing, 54 % less memory |

### Checking the work

| Tool | What it proves |
|---|---|
| Golden-file tests: output, errors and exit status of every program are recorded and compared | Behaviour does not change by accident |
| Syntax matrix (`test/test_syntax.zu`) with hand-checked outputs | Every construct and every precedence pair |
| Round trip (`make round-trip`): parse, print back as source, parse again, require the same tree | The parser and the printer agree on all 381 project files and cases |
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

## The memory model

| Type | Lives | May hold | In `unsafe` |
|---|---|---|---|
| `box` | Stack (literal size) or heap, up to 16 MiB | Bytes only | Not allowed |
| `bloc` | Heap, garbage collected, immutable, up to 64 bytes | `int`, `float`, `bool`, `char`, `string`, other blocs, `box[N]` (a read-only copy) | Allowed; `alloc(bloc)` for hand-managed |
| `template` | Heap, garbage collected | Anything, including blocs, boxes and other templates | Allowed; `alloc(template)` for hand-managed |

The ten `unsafe` rules are listed in [unsafe](unsafe.md).

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
