# Architecture

This page describes how a program becomes a binary. The only external pieces are clang
(LLVM 18), libc and libm.

```
prog.zu
  |  compiler/lexer.zu        tokens
  |  compiler/parser.zu       AST (node templates and lists)
  |  compiler/check.zu        compile-time type check
  |  compiler/analysis.zu     names used, exports, closure captures
  |  compiler/emit_llvm.zu    LLVM IR text
  v
C/prog.ll ----------------+
                          |   clang -O1
C/zue_rt_native.o -------+-------------->  prog   (native executable, links libc and libm)
  ^
  |  clang -c
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
| `zuec.zu` | Driver: `build`, `run`, `emit`, and the internal `--native` and positional forms. Builds the clang command line |
| `lexer.zu`, `token.zu` | Source text to tokens; keyword and operator tables, including the keyword aliases |
| `parser.zu` | Recursive descent with precedence climbing; produces the AST |
| `ast_nodes.zu` | The AST node types: one `template` per kind of node (`NBin`, `NLet`, ...) with its `mk_*` constructor, and `NODE_FIELDS`, the fields of each kind. A node always has `k` (the kind) and `line`; reading a field its kind does not have is an error |
| `check.zu` | The compile-time type checker for the main program and imported modules: variable types, operators, conditions and the signatures of the math builtins. See [syntax](syntax.md#type-checking) |
| `analysis.zu` | Which names a function reads and writes, exports, and which variables closures capture |
| `emit_llvm.zu`, `ll_state.zu`, `ll_scope.zu` | The LLVM IR backend: expressions, statements, functions, modules, scopes and deferred calls |
| `emit_native.zu` | The native backend, used to compile the runtime (see [zuec](architecture.md)) |
| `state.zu`, `shared.zu`, `util.zu` | Shared state, the list of builtin names (`BUILTINS`), path and file helpers, error formatting |
| `build_runtime.sh` | Builds `C/zue_rt_native.o` from the runtime sources when they changed and prints the link input |
| `run_tests.sh` | The test runner behind `make test` |

The compiler reads imported modules while compiling, so one IR file holds the program and every
module it uses.

## The runtime (`compiler/runtime/`)

The runtime is compiled by the native backend into `C/zue_rt_native.ll`, then to an object,
and linked into every program.

| File | Contents |
|---|---|
| `zue_gc.zu` | The garbage collector. See [gc](gc.md) |
| `zue_rt_core.zu` | Value layouts, errors, strings, lists, maps, `to_string` |
| `zue_rt_ops.zu` | Operators, indexing, iteration, calls, recursion limit, program entry |
| `zue_rt_lib.zu` | Builtins: conversions, maps, lists, strings, `args`, `exit`, `system`, `clock` |
| `zue_rt_math.zu` | Math, files, dense lists, vector math, random numbers |
| `zue_rt_data.zu` | `data`, `template`, `bloc`, `box` and `unsafe` |
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
| 6 | list | pointer to a list object (count and item cells) |
| 7 | map | pointer to a map object |
| 8 | function | pointer to a function object: code, name, captured cells; native builtins use the same kind |
| 9 | file | pointer to a file object |
| 10 | dense list | pointer to a float array object |
| 11, 13 | bloc type, `data` type | the type descriptor |
| 12 | bloc | pointer to a bloc object |
| 14 | template | pointer to a template object |
| 15 | box | a handle with a slot index and a generation |
| 16 | pointer | a raw pointer, only inside `unsafe` |

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
| `make` | build `bin/zue` from the seeds with clang only; stage 1 and stage 2 must emit identical IR |
| `make seed` | refresh `bootstrap/zuec.ll` and `bootstrap/zue_rt_native.ll` |
| `make test` | run every test in `test/` against the recorded output, then the native unit tests |
| `make clean` | remove `bin/` and `C/` |

In a compiled program, `ZUE_RT_GC_STRESS=N` collects every N allocations and
`ZUE_RT_GC_STATS=1` prints counts at exit. `opt-18 -passes=verify x.ll -disable-output` checks IR.

## Repository layout

| Path | Contents |
|---|---|
| `compiler/` | The compiler, the test runner, and `compiler/runtime/` |
| `bootstrap/` | The seed IR files |
| `test/` | Test programs, `test/expected/`, and `test/native/` (unit tests of runtime functions) |
| `docs/` | Documentation |
| `assets/` | The README banner |
| `bin/`, `C/` | Build output: the `zue` binary, and generated IR and objects (git-ignored) |
