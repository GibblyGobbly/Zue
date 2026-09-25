# Architecture

This page describes how a program becomes a binary. The only external pieces are LLVM 22 (`opt`,
`llc`, `ld.lld`, `llvm-link`), libc and libm. `compiler/llvm_build.sh` runs the LLVM tools.

```
prog.zu
  |  compiler/lexer.zu        tokens
  |  compiler/parser.zu       AST (node templates and lists)
  |  compiler/named_args.zu   named arguments put in the places of their parameters
  |  compiler/check.zu        compile-time type check
  |  compiler/analysis.zu     names used, exports, closure captures
  |  compiler/emit_llvm.zu    LLVM IR text
  v
C/prog.ll ----------------+
                          |   opt -O1, llc -O1, ld.lld
C/zue_rt_native.o -------+-------------->  prog   (native executable, links libc and libm)
  ^
  |  opt -O2, llc -O2
C/zue_rt_native.ll
  ^
  |  zue --native compiler/runtime/*.zu    (compiler/emit_native.zu)
compiler/runtime/*.zu
```

`zue build`, `zue run` and `zue emit` are the driver, `compiler/zuec.zu`. See
[getting-started](getting-started.md) for the commands and [zuec](architecture.md) for the
compiler in detail.

## The compiler (`compiler/`)

| File | Role |
|---|---|
| `zuec.zu` | Driver: `build`, `run`, `emit`, and the internal `--native` and positional forms. Builds the command line for `compiler/llvm_build.sh` |
| `lexer.zu`, `token.zu` | Source text to `Token` templates, each with its line, column and end; a string token holds its text and interpolations in `parts` (`StrPart`). Keyword and operator tables, including the keyword aliases. A lexical error is recorded and lexing goes on |
| `diag.zu` | The error reporter shared by the lexer, the parser and the checker: an error has a place (a span), labels, a hint and notes; they are collected, sorted by position and printed with the source line and carets. Also `suggest`, the "did you mean" search |
| `error_codes.zu` | Generated from `error_codes.txt` by `tools/gen_error_codes.py`: the error codes with their explanations, and `code_for(message)`. The runtime has the matching `zue_rt_codes.zu` |
| `parser.zu` | Recursive descent with precedence climbing; produces the AST. `x[a:b]` becomes an `NSlice` node, `x[i]` an `NIndex` node. After an error it skips to the next statement (panic mode) so that one run reports every syntax error without false follow-up errors |
| `ast_nodes.zu` | The AST node type: one typed `template Node` for every kind, with the fields of every kind (63); `k` says the kind, and the fields its kind does not use are empty. A `mk_*` function per kind builds it, and `NODE_FIELDS` lists the fields each kind uses. `line`, `col`, `eline` and `ecol` are its place in the source; fields ending in `span` hold a `Span`, the place of a name, an operator or a type for the checker. A literal keeps its value as text in `v`. A template string's parts are `text` nodes and the expressions between them; a switch's cases are `case` nodes (value in `e`, statements in `body`). In a list of strings, `""` stands for no type (`ptypes`, `ftypes`) or no name (a call's `names`). `node_children` gives the nodes inside a node and `nodes_under` every node below a list, so the tree walkers are typed. One type for every node lets the checker know the type of any node |
| `named_args.zu` | Turns named arguments into positional ones before the checker runs, from the parameters of the function (this file or an imported one), the fields of a template, or the names of a builtin; a parameter with a default that is left out gets an absent value (a null with payload 1) |
| `check.zu` | The compile-time type checker for the main program and imported modules: variable types, operators, conditions, the signatures of the math builtins, and names that are declared nowhere. Each imported file is checked once in its own context, and a call of a function it exports is checked there for the call's argument types, so types cross files. It reports every error it can prove, in source order. See [syntax](syntax.md#type-checking) and [errors](errors.md) |
| `analysis.zu` | Which names a function reads and writes, exports, and which variables closures capture |
| `emit_llvm.zu`, `ll_state.zu`, `ll_scope.zu` | The LLVM IR backend: expressions, statements, functions, modules, scopes and deferred calls |
| `emit_native.zu` | The native backend, used to compile the runtime (see [zuec](architecture.md)) |
| `ranges.zu` | `cut(x, a, b)`: part of a string or list from offset a to b, counting from 0, clamped. The compiler uses it where the builtin `slice` (from 1, both ends included) would not fit |
| `state.zu`, `shared.zu`, `util.zu` | Shared state, the list of builtin names (`BUILTINS`), path and file helpers, error formatting |
| `build_runtime.sh` | Builds `C/zue_rt_native.o` from the runtime sources when they changed and prints the link input |
| `run_tests.sh` | The test runner behind `make test` |

The compiler reads imported modules while compiling, so one IR file holds the program and every
module it uses.

The lexer does its work per token, not per character. A table indexed by byte code says what a
token starts with, and the runs inside a token (identifier bytes, digits, blanks, comments, string
bodies) are skipped by the builtins `skip_chars` and `index_of_any`, which scan in native code and
keep a lookup table for each recent set string. Operator tokens reuse tables built at start-up
(`ONE_TEXT`, `TWO_KIND`, `TWO_TEXT`), so lexing an operator allocates nothing but the token.

## How errors get their place

The lexer gives each token a line, a column and an end (columns count bytes from 1). The parser gives
each node the same, and the checker and the reporter in `diag.zu` use them to draw carets under the
exact text. At run time the generated code records where the running operation is: one 64-bit number
(line, column, length, and for a binary operation the offset of its operator) stored in the global
`lv_pos` before an operation that can fail. The in-line fast paths for int and float arithmetic store
it only on their slow path, so a loop of additions pays nothing. `lvp_call` also keeps a shadow stack
of the calls that are running (the place of the call, the module and the function name), and `lv_error`
prints the source line, the carets and that stack. See [errors](errors.md).

## The runtime (`compiler/runtime/`)

The runtime is compiled by the native backend into `C/zue_rt_native.ll`, then to an object,
and linked into every program.

| File | Contents |
|---|---|
| `zue_gc.zu` | The garbage collector. See [gc](gc.md) |
| `zue_rt_core.zu` | Value layouts, errors, strings, lists, maps, `to_string` |
| `zue_rt_ops.zu` | Operators, indexing, slicing (`lvp_slice`), iteration, calls, recursion limit, program entry |
| `zue_rt_lib.zu` | Builtins: conversions, maps, lists, `sort` (insertion, merge and radix sort), strings and the scanning builtins, `args`, `exit`, `system`, `clock` |
| `zue_rt_math.zu` | Math, files, dense lists, vector math, random numbers (`rand`/`srand` on xoroshiro128++, `trand`/`tshuffle` on `getrandom`), `shuffle` and `ssort` |
| `zue_rt_data.zu` | `data`, `template`, `bloc`, `box` and `unsafe` |
| `zue_rt_blue.zu` | Blue threads: the scheduler, thread stacks and switching, channels, and the builtins `spawn`, `wait`, `yield`, `channel`, `send`, `recv`, `channel_close` |
| `zue_rt_rules.zu` | The validation rules behind them: bloc and template schemas, the box handle table, the allocation table and the ten pointer rules. Each rule returns 0 or an error code, which `zue_rt_data.zu` turns into the error message |

Every builtin `name` listed in `compiler/shared.zu` is a runtime function `lb_name(self, argc,
argv)` that returns a value. Operators are runtime calls too (`lvp_add_fast`, `lvp_lt_fast` and
so on), which is where the type checks and the overflow checks live.

### Values

Every Zue value is a 16-byte cell, `%LV = { i64 tag, i64 payload }`. Generated code keeps each
value in a stack slot and passes pointers to the runtime.

| Tag | Kind | Payload |
|---|---|---|
| 0 | null | none |
| 1 | boolean | 0 or 1 |
| 2 | int | 64-bit integer |
| 3 | float | the bit pattern of a double |
| 4 | char | the byte |
| 5 | string | pointer to the string object (length and bytes) |
| 6 | list | pointer to a list object: count, capacity and the pointer to the item cells. A list made with known contents (a literal, a slice) of up to 32 items keeps its cells in the same object, 32 bytes after its start; one that outgrows them moves its cells to an object of their own. An empty list that is filled by appending keeps its cells apart from the start |
| 7 | map | pointer to a map object |
| 8 | function | pointer to a function object: code, name, captured cells; native builtins use the same kind |
| 9 | file | pointer to a file object |
| 10 | dense list | pointer to a float array object |
| 11, 13 | bloc type, `data` type | the type descriptor |
| 12 | bloc | pointer to a bloc object |
| 14 | template | pointer to a template object |
| 15 | box | a handle with a slot index and a generation |
| 16 | pointer | only inside `unsafe`: the number of an entry of the allocation table (high 32 bits) and a slot in it (low 32 bits); see `zue_rt_rules.zu` |
| 18 | thread | pointer to a blue thread object (`zue_rt_blue.zu`) |
| 19 | channel | pointer to a channel object |

The tags are constants at the top of `zue_rt_core.zu`.

### Program start

`lv_main` (in `zue_rt_ops.zu`) initializes the data runtime, seeds the random generator from OS
entropy, then runs the program on a new thread with a 1 GiB stack, so deep recursion works. The
program thread registers its stack with the collector, runs the generated `entry` function, and
flushes standard output. The recursion limit is 100000 nested calls.

### Errors

Runtime errors are raised by `lv_error` in `zue_rt_core.zu`: it prints the error class
(`Type Error`, `Runtime Error`, ...), the source file and line, the message, the source line and
a hint, to standard error, and exits with status 1. The line comes from position data that
generated code stores before calls and operations.

## Bootstrap

`bootstrap/zuec.ll` and `bootstrap/zue_rt_native.ll` are the LLVM IR of the compiler and the
runtime, kept in git. They are the only way to build the first compiler without an existing
`zue`. `make` builds from the seeds, then from its own output, and requires the second output
to equal the first; `make seed` refreshes the seeds. See [zuec](architecture.md#bootstrap).

## The native dialect

A function whose name starts with `_slow_` is compiled `noinline cold`. It is the rarely taken part of a hot
function (for example `_slow_gc_alloc` behind `_gc_alloc`), and it stays a call so that the hot function does not
carry its registers and stack frame. Without this, LLVM folded a function that has one call site back into its
caller, and every allocation paid for a 264-byte frame and six saved registers.

The runtime is written in Zue syntax with one type, the 64-bit word, and memory intrinsics.

A native file is ordinary Zue syntax with one type, the 64-bit word. Integers, pointers and
doubles (as bit patterns) are words, and memory is read and written through intrinsics.

```javascript
const CELL = 16                          // compile-time constant
let counter = 0                          // module-level word
extern("snprintf", "i32", "ptr,i64,ptr,...")   // declare a C function
space("lv_depth", 4)                     // zeroed global bytes
table("sizes", "i32", 16, 32, 48)        // constant array

func lvp_int(o, i) {                     // exported; a leading _ makes it internal
    st64(o, 2)                           // tag word
    st64(o + 8, i)                       // payload word
}

func lb_len(self_p, argc_i, argv_p) {    // _p is a pointer parameter, _i a C int
    let o = stack_buf(16)
    st64(o, 2)
    st64(o + 8, ld64(ld64(argv_p + 8) + 0))
    retp(o)                              // return the LV at o by value
}
```

| Group | Intrinsics |
| --- | --- |
| Memory | `ld8 ld16 ld32 ld64 lds8 lds16 lds32 st8 st16 st32 st64`, `p[i]` and `p[i] = v` on words |
| Shared between threads | `ld8a ld64a` (acquire loads), `st8a st64a` (release stores), `cas8(p, expected, new)` (1 when the byte was swapped, full ordering), `fence()`. Plain `ld`/`st` have no ordering between threads |
| Bits | `band bor bxor shl shr sar bnot` |
| Unsigned | `ult ule ugt uge udiv urem` |
| Overflow | `addof subof mulof` (1 when the signed result overflows) |
| Doubles | `fadd fsub fmul fdiv fneg flt fle fgt fge feq fne i2f f2i`, `dbl(x)` to pass a double to a variadic call |
| Symbols | `cstr("text")`, `addr_of("sym")`, `fn_addr("fn")` |
| Frames | `stack_buf(n)`, `frame_addr`, `stack_ptr`, `spill_regs` |
| Calls | `call_ptr(f, args...)`, `callv(out, f, args...)` for LV-returning functions |
| Returns | `retv(tag, payload)`, `retp(ptr)` |

`and`/`or` short-circuit, `/` and `%` are signed, and calls may span lines. A function containing
`retv` or `retp` returns a 16-byte LV in two registers, as the generated code expects.

## LLVM IR design

- Every value is an `LV` in memory (`%LV = { i64 tag, i64 payload }`). An expression compiles to
  a pointer to its `LV` slot; slots are entry-block allocas.
- Generated code never passes an `LV` by value to the runtime: it passes pointers (`lvp_*`).
- Globals are `internal global %LV`. The GC scans the data segment and stack conservatively, so
  globals and allocas are roots.
- Variables captured by closures live in heap cells.

## Make targets

| Target | Effect |
| --- | --- |
| `make` | build `bin/zue` from the seeds with LLVM's tools only; stage 1 and stage 2 must emit identical IR |
| `make seed` | refresh `bootstrap/zuec.ll` and `bootstrap/zue_rt_native.ll` |
| `make test` | run every test in `test/` against the recorded output, then the native unit tests |
| `make clean` | remove `bin/` and `C/` |

In a compiled program, `ZUE_RT_GC_STRESS=N` collects every N allocations and
`ZUE_RT_GC_STATS=1` prints counts at exit. `opt-22 -passes=verify x.ll -disable-output` checks IR.

## Repository layout

| Path | Contents |
|---|---|
| `compiler/` | The compiler, the test runner, and `compiler/runtime/` |
| `bootstrap/` | The seed IR files |
| `test/` | Test programs, `test/expected/`, and `test/native/` (unit tests of runtime functions) |
| `docs/` | Documentation |
| `assets/` | The README banner |
| `bin/`, `C/` | Build output: the `zue` binary, and generated IR and objects (git-ignored) |
