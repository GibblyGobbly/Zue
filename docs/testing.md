# Testing

All tests are Zue programs. Each one is compiled to a native binary, run, and its output is
compared with a recorded copy.

| Command | What it does |
|---|---|
| `make test` | Builds `bin/zue` if needed, runs `compiler/run_tests.sh` on every `test/*.zu` file, then runs the native unit tests |
| `compiler/run_tests.sh test/test_core.zu` | Runs only the named files |
| `RECORD=1 compiler/run_tests.sh test/test_core.zu` | Re-records the expected output of the named files |
| `ZUE_RT_GC_STRESS=1 compiler/run_tests.sh test/test_gc_safety.zu` | Runs with a collection on every allocation (see [gc](gc.md)) |
| `sh test/native/run.sh` | Unit tests of the rule functions in `compiler/runtime/zue_rt_rules.zu`, compiled in the native dialect; prints `[OK] N checks passed` |

## Checking the lexer and the parser

| Command | What it does |
|---|---|
| `zue ast prog.zu` | Prints the syntax tree, one top-level statement per line, so parser output can be read and compared |
| `zue unparse prog.zu` | Writes the program back as source, with every binary expression parenthesized |
| `make round-trip` | Runs `tools/check_round_trip.sh`: for every Zue file in the project, parse, unparse, parse again, and require the same tree |
| `make verify-ir` | Runs the tests and checks every generated IR file with LLVM's verifier (`opt-18`) |
| `make fuzz` | Needs `python3`. `tools/fuzz_expressions.py` builds random int and bool expressions and compares what Zue prints with an independent evaluator; `tools/fuzz_programs.py` does the same for whole programs with loops, branches, functions and scoping, and also runs each program after `zue unparse`; `tools/fuzz_annotations.py` builds random type annotations such as `list<map<float>>` and checks parsing, the unparse round trip, the result, and that a wrong element type is a Type Error |
| `zue run bench/frontend_phases.zu file.zu` | Times the lexer, the parser and the type checker on a file |
| `bench/instruction_count.sh [file.zu]` | Counts the machine instructions the lexer, parser and checker execute (needs valgrind). Counts do not depend on machine load, so they compare cleanly between changes |

`test/test_lexer.zu`, `test/test_syntax.zu` and `test/test_parser_rules.zu` hold the lexer and
parser cases. A case whose recorded output is a `Syntax Error` or `Type Error` is a program the
compiler is meant to reject.

The runner prints one `[PASS]`, `[FAIL]` or `[SKIP]` line per test and a summary such as
`passed 110, failed 0, skipped 0`. It exits non-zero if any test failed, and so does `make test`.

## How a test passes

For each `test/<name>.zu`, `compiler/run_tests.sh`:

1. Compiles it with `bin/zue` (the positional form `zue input.zu output.ll <root>`).
2. Links the IR with the runtime object using clang.
3. Runs the binary from the repository root, with standard input closed and a 60 second limit.
4. Compares standard output, standard error and the exit status with the files in
   `test/expected/`: `<key>.out`, `<key>.err` and `<key>.rc`. The key is the path with every
   character other than letters, digits, `.`, `_` and `-` replaced by `_`
   (`test/test_core.zu` becomes `test_test_core.zu`).

Nothing in the output is masked, except that the temporary file a `# CASE` section runs from
is shown as `/tmp/zue_test_case.zu`. Keep output that depends on time, addresses or memory size
out of the tests.

A test that is expected to fail with a runtime error is recorded like any other: its `.err` file
holds the error message and its `.rc` file holds `1`.

A file with a `<key>.skip` entry in `test/expected/` is reported as `[SKIP]`. A source with a
`.golden` file next to it is instead compared against that file (standard output only).

### Files made of cases

A file made of `# CASE <name>` sections is split: each section is compiled and run as its own
program, and has its own expected files. This is how error messages are tested, because a
runtime error ends the program. For example `test/test_unsafe_errors.zu` has one case per safety
rule, and `test/test_operator_errors.zu` has one case per operator error.

```
# CASE string plus int
let s = "a" + 1
# CASE int plus bool
let b = 1 + true
```

## What the tests cover

| File | Covers |
|---|---|
| `test_core.zu` | Variables, types, chars, loops, `switch`, operators |
| `test_operators.zu`, `test_operator_errors.zu` | Operators, integer division, boolean conditions, and their errors |
| `test_functions.zu`, `test_call_args.zu` | Functions, recursion, closures, argument evaluation order |
| `test_qol.zu` | Compound assignment, negative indexing, default parameters, `for-in`, `range`, maps, interpolation, `data` |
| `test_strings.zu`, `test_math.zu`, `test_vectors.zu`, `test_file_io.zu` | Standard library |
| `test_modules.zu`, `util.zu`, `import_helper.zu`, `modules_fixtures/` | Module resolution, run-once rule, module state |
| `test_use_file.zu`, `test_use_private_error.zu`, `test_import_private_error.zu` | `use` and `import` forms, and the error for a name that is not exported |
| `test_bloc.zu`, `test_box.zu`, `test_template.zu`, `test_data_types.zu` | Structured data types |
| `test_unsafe.zu` | `unsafe` blocks and pointer operations |
| `test_rules.zu` | `bloc` / `box` / `template` / `unsafe` behavior that must work: 10k blocs and boxes, byte access, loop scopes, aliases |
| `test_unsafe_errors.zu` | One case per rule violation (R1 to R10, box, bloc, template) |
| `test_rules_runtime.zu` | Cases for the rule functions in `zue_rt_rules.zu`, run through the language (pointer bounds, box handles, schemas) |
| `test_gc_safety.zu`, `test_gc_large_safety.zu`, `test_gc_callbacks.zu`, `test_gc_recursion.zu` | Collector liveness under churn, large objects, callbacks and deep recursion |
| `test_compiler_blockers.zu` | Features the compiler's own source depends on |
| `test_exit.zu` | `args()` and `exit()` |
| `test_doc_examples.zu` | Examples from the docs |
| `balls.zu` | Keyword aliases |

## Adding a test

1. Create `test/test_<feature>.zu` that prints what it checks. Use `assert()` for conditions;
   a failed assertion exits with status 1, which changes the recorded output.
2. Run `RECORD=1 compiler/run_tests.sh test/test_<feature>.zu`.
3. Read the new files under `test/expected/` (or `git diff test/expected`) before committing:
   a recorded output is only as correct as you checked it to be.
4. Run `compiler/run_tests.sh test/test_<feature>.zu` again; it must pass.

## The compiler's own check

`make` compiles the compiler with itself twice and requires identical IR (stage 1 against
stage 2). That is a consistency check of the compiler, in addition to the tests above.

## Coverage gaps

- There is no independent implementation to compare against. The recorded outputs are the
  oracle, so a wrong recording stays wrong until someone reads it.
- No test covers memory use or speed.
