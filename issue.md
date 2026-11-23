# Audit findings (2026-11-02)

Audit of HEAD f6e6ed3 in eight areas: runtime leaks, strings, math, unsafe memory, sort/shuffle/collections,
threads and I/O, compiler frontend, compiler backend. Every finding was reproduced by running a program unless
it says "read only". Findings marked "re-checked" were reproduced a second time independently.
Scratch programs: `/tmp/claude-1000/-home-bharath-Desktop-Zue/1263acd9-946b-483b-9a2b-064bb70881e6/scratchpad/`
(subfolders `leaks`, `strings`, `unsafe`, `sort`, `threads`, `frontend`, `backend/d`, `mine`).

Severity: Critical = memory corruption or crash from valid-looking code. High = wrong result, a valid program
rejected, or unbounded memory. Medium = silent wrong behaviour in edge cases. Low = messages, docs, speed.

## Summary

| # | Severity | Area | Issue |
|---|---|---|---|
| U1 | Critical | unsafe | `ptr_offset` on an alloc(bloc/template) pointer forges values, segfault |
| U2 | Critical | unsafe | `ptr_offset` on an `address_of` pointer has no bounds check |
| L1 | High | leaks | Boxes owned by templates/blocs are invisible to the GC pacer |
| U3 | High | unsafe | Rules table never cleared: valid pointers reported as freed |
| U4 | High | unsafe | Use-after-free undetected once an address is reused |
| U5 | High | unsafe | `ptr_offset` multiply overflow skips the bounds check |
| U6 | High | unsafe | Pointers escape `unsafe` through closures, spawn, send, constructors |
| C1 | High | checker | Implicit `null` return ignored |
| C2 | High | checker | Per-call checking mutates shared AST nodes |
| C3 | High | checker | Shadowed or reassigned function names checked against the top-level body |
| B1 | High | backend | Direct calls break when a called function is reassigned |
| B2 | High | backend | Specialized function names collide, clang fails |
| T1 | High | I/O | Write errors are lost and exit status stays 0 |
| M1 | High | math | `mat_mul` reads past a row's end, segfaults on non-list rows |
| S1 | Medium | strings | `substring` overflow gives "out of memory" |
| S2 | Medium | strings | NUL bytes break compare, split, to_int, to_float |
| S3 | Medium | strings/sort | Chars order differently in `<` and in `sort` |
| R1 | Medium | lists | `range` returns a wrong list when its length overflows |
| R2 | Medium | lists | Mutating a list while iterating behaves inconsistently |
| U7 | Medium | unsafe | `store` through `address_of` changes a variable's type |
| U8 | Medium | box | One box given to two templates is freed while in use |
| U9 | Medium | unsafe | Double free through `defer` is silent |
| L2 | Medium | leaks | Threads blocked forever are never reclaimed |
| T2 | Medium | I/O | `write` fails silently and accepts any type |
| T3 | Medium | I/O | Read errors look like an empty file |
| T4 | Medium | I/O | `exit` codes wrap modulo 256 |
| T5 | Medium | I/O | NUL bytes cut paths and shell commands |
| P1 | Medium | parser | No separator required between statements |
| P2 | Medium | parser | Interpolated `use` path crashes the compiler |
| P3 | Medium | unparse | Broken output for some for-loop steps |
| C4 | Medium | checker | Quadratic blowup on many undefined names |
| C5 | Medium | checker | Not flow-sensitive (owner decision) |
| B3 | Medium | backend | Long top-level code makes clang very slow |
| M2 | Medium | math | Inline floor/ceil/round of int literals wrong (770b4d7 regression) |
| M3 | Medium | math | int and float mix at run time (owner decision) |
| -- | Low | all | See the low-severity list at the end |


# Critical

## U1. `ptr_offset` on an alloc(bloc/template) pointer forges values and segfaults (re-checked)

- Where: `compiler/runtime/zue_rt_data.zu:1957` (`lb_ptr_offset`), `:1823` (`_refuse_whole_object`).
- Cause: only the base pointer of an object allocation is refused. `BL_VALS = 8` (`:26`), so 16-byte slots
  do not line up with bloc fields; an offset pointer lets `store` write raw tag/payload pairs into the object.
- Repro (`unsafe/o12.zu`):
  ```
  bloc V { x: int, y: int }
  unsafe {
      let p = alloc(V{1, 2})
      defer(p)
      store(ptr_offset(p, 1), 6)
      let y = p.y
      print(type(y))
      print(len(y))
  }
  ```
  Actual: `list`, then `Fatal Error [E0490] invalid memory access (segmentation fault)`.
  Expected: an error from `ptr_offset` or `store`.
- On a template (`unsafe/o5.zu`), `store(ptr_offset(p, 1), 99)` writes 99 into a `name: string` field and
  skips the field type check. It also changes a read-only bloc.
- Fix: `ptr_offset`, and `load`/`store` on aliases, refuse any pointer record with `PM_OBJ != 0`.

## U2. `ptr_offset` on an `address_of` pointer has no bounds check (re-checked)

- Where: `zue_rt_data.zu:1978` (the `else` branch adds the offset unchecked); load/store of `PTR_ADDR`
  records at `:1919` and `:1945` read and write raw memory.
- Repro (`unsafe/t2.zu`, `t2b.zu`):
  ```
  let a = 1
  unsafe { let p = address_of(a); print(load(ptr_offset(p, 1))); store(ptr_offset(p, 100000000), 5) }
  ```
  Actual: reads neighbouring stack cells (garbage, `ptr(0x7...)`), then a segmentation fault. Negative and
  positive offsets around a local read and overwrite other locals.
  Expected: `ptr_add() moved outside the allocation bounds`.
- Fix: treat `PTR_ADDR` as an allocation of one 16-byte cell under the same bounds rule, or refuse
  `ptr_offset` on it.

# High

## L1. Boxes owned by templates/blocs are invisible to the GC pacer (re-checked)

- Where: `zue_rt_data.zu:993-1060` (`_box_promote_owned`, `_box_clone_owned`); box bytes calloc'd at `:942`
  and `:1031`; freed only in `lv_data_gc_hook` after a cycle.
- Cause: a cycle starts only from GC-heap bytes (`MIN_THRESHOLD` = 16 MiB, `zue_gc.zu:78`). A template plus
  its box adds about 100 GC bytes, so the calloc'd box memory never triggers a cycle.
- Repro (`leaks/b4.zu`): `template Holder { name, buf }`, a loop builds `Holder("h", box[65536])`, a ring of
  64 kept live (about 4 MiB really live).

  | Iterations | Peak RSS |
  |---|---|
  | 2,000 | 20 MB |
  | 8,000 | 70 MB |
  | 32,000 | 274 MB |
  | 64,000 | 540 MB |
  | 160,000 | 1.34 GB |

  `ZUE_RT_GC_STATS=1` shows 0 collections. With `box[256]` the peak levels at 215 MB (about 13,000 times the
  live data). Boxes may be 16 MiB each, so a program can run out of memory.
- Fix: add the box bytes to `H_BYTES_SINCE_GC` (subtract on free), or allocate owned box bytes in the GC heap
  with `lv_alloc_atomic`. Add a `test_resource_bounds.zu` case.

## U3. Rules table never cleared: valid pointers reported as freed (re-checked)

- Where: `compiler/runtime/zue_rt_rules.zu:602-676` (`zue_mem_track_alloc`, `_rl_owner`),
  `zue_mem_deref_ok` (`:649`); `_register_alias_meta` (`zue_rt_data.zu:1523`).
- Cause: `rl_entries`, `rl_alloc_map`, `rl_alias_map` are never cleared after `zue_mem_init`, and not by
  `_drop_pointer_records`. `_rl_owner` checks the exact-base map first, so a pointer into a new allocation
  that lands on the base of an old freed one is reported as freed.
- Repro (`leaks/u6.zu`):
  ```
  func step(i) {
      unsafe {
          let a = alloc(4 + (i * 7919) % 500)
          let b = alloc(4 + (i * 104729) % 700)
          let q = ptr_add(b, 3)
          store(q, i)
          free(a)
          free(b)
      }
  }
  for (let i = 0; i < 2000; i++) { step(i) }
  ```
  Actual: `Runtime Error [E0460] pointer was freed or freed twice` at iteration 374 (q equals the base of b
  from iteration 369). Deterministic version: `unsafe/fp.zu`.
- The existing unsafe tests use a fixed `alloc(64)`, so malloc returns the same address and this never shows.
- The table also grows with every distinct address (memory roughly flat in practice: 44.6 to 47.3 MB over
  50k to 800k iterations).
- Fix: clear the three rules tables in `lv_unsafe_end` when `g_block_depth` reaches 0, next to
  `_drop_pointer_records`; on free, remove the base from the exact map and keep the poison in a separate
  freed set. Add u6 as a test.

## U4. Use-after-free undetected once the address is reused (re-checked)

- Where: `zue_rt_rules.zu:604` (`zue_mem_track_alloc` un-poisons the old entry; the old alias still maps to it).
- Repro (`unsafe/t3c.zu`):
  ```
  unsafe { for (let i = 0; i < 10; i++) { free(alloc(2)) }
    let a = alloc(2); let q = ptr_offset(a, 1); free(a)
    let b = alloc(2); defer(b); store(ptr_offset(b, 1), 99)
    print(load(q)); store(q, 5) }
  ```
  Actual: `load(q)` gives 99 (from b) and `store(q, 5)` writes into b. Expected: use-after-free error.
- Fix: delay the real `free()` until the outermost block ends, or keep a generation number per allocation in
  each pointer record and check it.

## U5. `ptr_offset` multiply overflow skips the bounds check

- Where: `zue_rt_data.zu:1972` (`n*16` unchecked).
- Repro (`unsafe/t1.zu`): on `alloc(2)`, `ptr_offset(buf, 1152921504606846977)` returns slot 1 and loads its
  value; `ptr_offset(buf, 2^60)` returns `buf`. Expected: the R3 bounds error.
- Fix: refuse `|n| >= 2^59` (or check the multiply for overflow) before multiplying.

## U6. Pointers escape `unsafe` blocks (R2 holes)

- Paths that carry a pointer out of its block:
  - Closure-captured variable: `store_name` "cap" branch (`compiler/emit_llvm.zu:896`) has no escape check.
    `func(v) { keep = v }` called inside unsafe, then `getter()` after the block returns the pointer. In a
    later block that reuses the address, `load(g())` returns the new allocation's value and `store(g(), 7)`
    overwrites it (`unsafe/e4.zu`); without reuse, "pointer is not registered" (`e1.zu`).
  - `spawn(worker, b)`: the thread returns the pointer after the block (`s1.zu`).
  - `send(ch, b)` then `recv` after the block (`s2b.zu`).
  - Template and data constructors: `keep = T(b)`, `D(b)` (`s3b.zu`).
- Correctly refused: lists, maps, template field assignment, globals (`s5`, `s6`, `s7`, `s9`).
- Doc: `docs/builtins.md:101` says send inside unsafe is an error; it is only when send has to wait.
- Fix: call `lvp_ptr_escape_check` on captured-variable stores, and `_ptr_store_check` on constructor
  arguments, spawn arguments and send. A generation per allocation (U4) also closes the aliasing case.

## C1. Checker ignores the implicit `null` return (re-checked)

- Where: `compiler/check.zu`, `check_body` / `join_returns` (around lines 1036 and 1145).
- Repro:
  ```
  func f(c) { if (c) { return 1 } }
  let y = f(false)
  print(y)
  ```
  Actual: `Type Error [E0204] variable 'y' must be an int, got null`, exit 1 (also with `--no-spec`).
  Expected: `null`. Adding `y = "s"` gives a false "cannot assign string to 'y', which is int".
- Fix: in `check_body`, when `not always_returns(fn.body)`, add `"null"` to the return types.

## C2. Per-call checking mutates shared AST nodes (re-checked)

- Where: `check.zu` `adapt_to` (216-243). A function body is checked once per argument-type list; a literal
  adapted to float for one call stays float for the next.
- Repro:
  ```
  func f(v) {
    let x = v
    x = 1
    return x
  }
  print(f(1.5))
  print(f(2))
  ```
  Actual: `cannot assign a float constant to 'x', which is int`. Expected: `1.0` and `1`.
  Same with `append(xs, 3)` on `xs = [v]`. It likely also changes the code generated for the int call.
- Fix: do not mutate nodes during per-call checks (copy them, or record the adaptation per signature like
  `stys`).

## C3. Shadowed or reassigned function names checked against the top-level body (re-checked)

- Where: `check.zu` `ck_call` (961-966) looks up `fn:<name>` without checking it is the same declaration.
- Repro:
  ```
  func f() { return 1 }
  func g(f) { return f() + "x" }
  print(g(func() { return "s" }))
  ```
  Actual: `cannot use '+' on int and string`. Expected: `sx`. Same for a local `let f = func(){...}` and for
  `f = func(){...}`. The emitter calls the right function.
- Related, both modes: `func g(n){return n+1}; func h(n){return "x"}; g = h; let a = g(1)` dies with
  "variable 'a' must be an int": the checker trusts the inferred result of a reassigned function name.
- Fix: use the `fn:` entry only when `scope_index("fn:"+name) == scope_index(name)`, and drop the entry when
  the name is assigned anywhere.

## B1. Direct calls break when a called function is reassigned (re-checked)

- Where: `compiler/ll_typed.zu:437` (`tex_spec_call`), `emit_llvm.zu:1277` (`st_return_raw`), and the
  checker's memoized result types (`spec_site`).
- Cause: the run-time guard checks only that `f` still holds its own closure. `f`'s specialized body was
  compiled assuming each function it calls keeps its proven result type.
- Repro (`backend/d/t11.zu`):
  ```
  func g(n) { return n + 1 }
  func f(n) { return g(n) }
  func h(n) { return "s{n}" }
  print(f(1))
  g = h
  print(f(1))
  ```
  `--no-spec`: `2`, `s1`, rc 0. Default build: `2`, then `Type Error [E0204] line 2: variable 'g' must be an
  int, got string`, rc 1.
- Same pattern: `t9` (condition error text differs from `--no-spec`), `t12` (float), `t13`
  (`let a = g(n)` in the body), `t7` (error on another line with another code). Error output is therefore
  not byte-identical between the two modes.
- Fix: specialize a function, and trust its result type in other bodies, only when its name is never
  assigned anywhere in the module (nested functions and spawned code included). `spec_prescan` can mark such
  names; the checker should stop trusting memoized results for them (see C3).

## B2. Specialized function names collide; clang fails (re-checked)

- Where: `compiler/ll_spec.zu:63` (`spec_symbol`). `f` with `int,int>int` and `f_int` with `int>int` both
  become `@sp_g_f_int_int_to_int`.
- Repro (`backend/d/t15.zu`):
  ```
  func f(a, b) { return a + b }
  func f_int(a) { return a * 10 }
  print(f(1, 2) + 0)
  print(f_int(3) + 0)
  ```
  Default build: `error: invalid redefinition of function 'sp_g_f_int_int_to_int'`, internal compiler
  error. `--no-spec`: `3`, `30`.
- Fix: use a separator that cannot appear in identifiers, e.g. `@"sp.{sym}.{key}"`.

## T1. Write errors are lost and exit status stays 0 (re-checked)

- Where: `zue_rt_math.zu:711` (close ignores `fclose`), `:783` (flush ignores `fflush`), `:761` (write
  checks only the buffered count), `zue_rt_ops.zu:1058` (final `fflush` ignored, `return 0`).
- Repro: `print("hello")` built and run with `> /dev/full` exits 0. `f = open("/dev/full", "w");
  print(write(f, "abc")); flush(f); close(f)` prints `true` and close succeeds.
- Expected: a Runtime Error such as "close() failed: No space left on device", and exit 1 when the final
  stdout flush fails.
- Fix: check `fclose`, `fflush` and `ferror`, raise errors with `strerror(errno)`; at exit, exit 1 if
  `fflush(stdout)` fails or `ferror(stdout)` is set.

# Medium

## S1. `substring` overflow gives "out of memory" (re-checked)

- Where: `zue_rt_lib.zu:1027`. `start + n` wraps negative, the clamp is skipped, `_str_n` gets a huge length.
- Repro: `substring(pass("abc"), 1, pass(9223372036854775807))` gives `Runtime Error: out of memory`
  (no line). Expected `"bc"`.
- Also: a negative start is silently clamped to 0 (`substring("abc", -5, 2)` gives `"ab"`), undocumented and
  against rule 8.
- Fix: `if (n > ld64(s) - start) { n = ld64(s) - start }`; make a negative start an Index Error or document it.

## S2. NUL bytes break string compare, split, to_int, to_float

- With `a = "a\0b"`, `c = "a\0c"`:
  - `a == c`, `a < c`, `a > c` are all false: `_order` uses `strcmp` (`zue_rt_ops.zu:446`). `sort` leaves
    `["a\0c", "a\0b"]` unsorted.
  - `split(a, ",")` drops everything after the NUL: `strtok_r` (`zue_rt_lib.zu:1428-1436`).
  - `to_int("12\0xyz")` gives 12, `to_float("1.5\0xyz")` gives 1.5 (`zue_rt_lib.zu:280`, `:352`).
- Fix: compare with `memcmp` on the shorter length then the lengths; write `split` with `memchr` over the
  full length; in the parsers, reject when the end position is not `S_DATA + len`.

## S3. Chars order differently in `<` and in `sort` (re-checked)

- Where: `zue_rt_ops.zu:451-452`: `_order` reads chars with `lds8` (signed); `lvp_lt_fast` uses `ld8`.
- Repro: `let hi = "é"[0]`; `hi > 'a'` is `true`, but `sort([hi, 'a'])` puts hi (195) first. Strings
  (strcmp, unsigned) sort é last, so chars and strings disagree. Affects `sort`, `min`, `max`.
- Fix: use `ld8` in `_order`.

## R1. `range` returns a wrong list when its length overflows (re-checked)

- Where: `zue_rt_lib.zu:588-593`; `end - start + step - 1` wraps.
- Repro: `range(-2^63, 2^63-1, 2^63-1)` gives `[]` (expected 3 items); `range(-2^63, 2^63-1, 2^62)` gives
  `[]` (expected 4); `range(0, 2^63-1, 2^62)` gives `Runtime Error: out of memory` with no line (expected
  `[0, 4611686018427387904]`).
- Fix: compute the span unsigned (`d = end - start`, `n = udiv(d - 1, step) + 1`), and give a located
  Argument Error when n is too large.

## R2. Mutating a list while iterating behaves inconsistently

- `map()` re-reads the count each step (`zue_rt_lib.zu:946`): a callback that appends to the list loops
  forever. `filter` has the same pattern (`:961`, read only).
- `for-in` takes the length once: appended items are ignored (`[1,2,3,1,2,3]`), but removing items gives
  "Index 3 is out of bounds for list of length 2" at the `for` line.
- Fix: map and filter take the count once; for-in clamps to the live count or raises "list changed during
  iteration".

## U7. `store` through `address_of` changes a variable's type

- Where: `zue_rt_data.zu:1945`.
- Repro (`unsafe/r10.zu`): `let z = 2.5; unsafe { store(address_of(z), 3) }; print(type(z), z * 2.0)` prints
  `int` and `6.0`. A string stored this way makes a later `+` fail (`t2c.zu`, `r8.zu`).
- Fix: check the stored tag against the variable's current tag.

## U8. One box given to two templates is freed while still in use

- Repro (`unsafe/b10.zu`): `let t = T(b); let u = T(b); return u`, then GC churn, then `u.b[0]` gives
  `box was already freed (use-after-free)` while u is alive.
- Fix: a second ownership transfer is an error, or the box is copied.

## U9. Double free through `defer` is silent

- Where: `zue_mem_run_defers` ignores errors (`zue_rt_rules.zu:819`).
- Repro: `defer(b); defer(b)`, `defer(b); free(b)`, `free(b); defer(b)` all succeed (`unsafe/d1.zu`, `d2.zu`,
  `d5.zu`). Contradicts rule R4 and the docs' "exactly once".
- Fix: refuse a defer of a pointer already deferred or freed.

## L2. Threads blocked forever are never reclaimed

- Where: `g_blue_all` (`zue_rt_blue.zu:358`); a stack is unmapped only when its thread finishes.
- Repro (`leaks/t1.zu`): spawn a thread that `recv`s on a fresh channel nobody sends to, drop the handle.
  5,000 threads 41 MB, 20,000 140 MB, 40,000 269 MB (about 6.5 KB each). Each holds 2 VMAs, so with the
  default `vm.max_map_count` of 65530, spawn fails near 32,000 such threads.
- Same as a Go goroutine leak. Fix: document it; optionally, in verify mode, report threads waiting on a
  channel reachable only from blocked threads.

## T2. `write` fails silently and accepts any type

- Where: `zue_rt_math.zu:756-765`.
- Repro: `f = open(p, "r"); print(write(f, "zzz"))` prints `false`; `write(f, 42)` is accepted. The boolean
  result is not in the docs. Breaks rule 8.
- Fix: require a string (`_arg_str`) and raise an error on a short write.

## T3. Read errors look like an empty file

- Where: `zue_rt_math.zu:725-729`, `:741-747`.
- Repro: `h = open("adir", "r")` returns a file; `read(h)` gives `""`, `read_line(h)` gives `null`. `read` on
  a file opened `"w"` gives `""`.
- Fix: check `ferror(fp)` after reading and raise with `strerror(errno)`; in `open`, `fstat` and reject
  directories.

## T4. `exit` codes wrap modulo 256 (re-checked)

- Where: `zue_rt_lib.zu:620-627`.
- Repro (built binary): `exit(256)` gives 0, `exit(257)` 1, `exit(-1)` 255, `exit(99999999999)` 255. A
  failure code can become success.
- Fix: Argument Error outside 0..255.

## T5. NUL bytes cut paths and shell commands

- Where: `zue_rt_math.zu:696, 770, 777`, `zue_rt_lib.zu:638`, `debug` at `zue_rt_lib.zu:564`.
- Repro: `file_exists("/etc/passwd" + to_string('\0') + "nonsense")` is `true`; `system("a\0; echo INJECT")`
  runs only `a` with no error; `debug("ab\0cd")` prints `value = ab`.
- Fix: Argument Error when the string's length differs from its `strlen`; `debug` writes with `fwrite`.

## P1. No separator required between statements (re-checked)

- Where: `compiler/parser.zu` `p_block_body` (782-797), `parse_program`.
- Repro: `let a = 5` / `let x = a--1` / `print(x)` prints 5 and `a` becomes 4 (`1` is a separate statement).
  `print(1) print(2)` and `let y = 3 4` are accepted.
- Fix: in `p_stmt_end`, require newline, `}` or end of file (or `;`/`)` in a for header).

## P2. Interpolated `use` path crashes the compiler

- Where: `parser.zu` `p_use` (1182); `pt.v[0]` can be an interpolation part.
- Repro: `let p = "a"` / `use "{p}.zu"`. Actual: the compiler fails with "starts_with() argument 1 must be a
  string, got map" in `util.zu:26` and a stack trace.
- Fix: reject the path unless `len(pt.v) == 1` and it is a string, as `p_map_literal` does for keys.

## P3. `zue unparse` writes broken text for some for-loop steps

- Where: `compiler/ast_unparse.zu` `simple_text` (195-203) handles only let and assign.
- Repro: `for (let i = 0; i < 3; a[0] += 1) {...}` or `for (; false; m.if += 1)` unparse to
  `<unknown setidx>`, which does not parse. The round-trip corpus has no such case.
- Fix: route through `stmt_body`.

## C4. Quadratic blowup on many undefined names

- Where: `check.zu` `report_undefined` / `name_candidates`, `diag.zu` `suggest`. Each pending name copies the
  scopes, each undefined name computes edit distance against every candidate, even past the 100 printed errors.
- Timings, N declared plus N undefined: 250 1.6 s, 500 5.7 s, 1000 23.3 s, 3000 over 120 s.
- Fix: stop suggesting after the printed errors, cache candidates, keep a scope reference instead of
  `cut(SCOPES...)`.

## C5. Checker is not flow-sensitive (owner decision)

- `let x` then `if (c) { x = 1 } else { x = "a" }` is rejected. `let g`, an uncalled `func setg() { g = 1 }`,
  then `g = "s"` is rejected (the body is checked at its definition and fixes g's type). Both are valid at
  run time, against "report only what it can prove". May be intended.
- Also: `min(1, 2.5)` passes the check but fails at run time while `clamp(5, 0, 2.5)` works (builtin
  arguments are never adapted); `[1] == [1.0]` is a compile error but `false` at run time;
  `let x: int = null` passes the check and fails at run time.

## B3. Long top-level code makes clang very slow

- All top-level code goes into one `main`. clang -O1: 1,401 lines 1.4 s / 151 MB, 2,801 lines 5.0 s / 220 MB,
  5,601 lines 27 s / 561 MB; an 18,230-line program took about 7 minutes. Zue's own emit stays at 0.24 s.
  Deep nesting is fine.
- Fix: split long top-level code into chunk functions, or reuse slots.

# Math

Oracle: commit `770b4d7^` built in the scratchpad. A differential script (`math/diff.py`) compared new, old,
`--no-spec`, and typed vs hidden-through-`pass()` on 43 edge values each. sqrt, cbrt, exp, ln, log10, sin,
cos, tan, asin, acos, atan, sinh, cosh, tanh, fract, deg_to_rad: no mismatch. Not differential-tested:
floor, ceil, round, trunc, abs, sign (checked by hand), rad_to_deg (60%), the binary raw-float paths (pow,
atan2, mod, operators). The audit was stopped early.

## M1. High: `mat_mul` reads past the end of a row and segfaults (re-checked)

- Where: `zue_rt_math.zu:878` (`_row_at`), `:925-941`. Every row is read with `cols_a` from the first row,
  without checking that row's length or type.
- Repro, silent wrong result:
  ```
  let r = [3.0, 99.0]
  remove(r, 1)
  print(mat_mul([[1.0, 2.0], r], [[1.0], [1.0]]))
  ```
  Actual: `[d[3.0], d[102.0]]` (the stale 99.0 is read). Expected: a dimension error.
- Repro, crash: `mat_mul(pass([[1.0], 5]), [[1.0]])` and `mat_mul([[1.0, 2.0]], [[1.0], pass(7)])` give
  `Fatal Error [E0490] segmentation fault` (rc 139).
- Also: a short row says "cannot store a null in a dense list"; longer rows are silently truncated;
  `mat_mul([[1.0]], [])` returns `[]`; ints become floats (`mat_mul([[MAX]], [[2]])` gives `1.84467e+19`
  instead of an overflow error); an overflow in the `+` step is reported as `'*'`.
- Fix: check every row is a list or dense list with exactly `cols` numeric items; raise E0420 on any mismatch,
  including an empty second argument.

## M2. Medium: inline path changes floor/ceil/round of int literals (regression from 770b4d7, re-checked)

- Where: `compiler/ll_typed.zu:274` (`math_spec` accepts `a.k == "num"` for kind round) and `:307` (the
  literal is rewritten as a float).
- Repro: `print(floor(9223372036854775807))` now gives `floor() result does not fit in a 64-bit int` (rc 1).
  The old compiler and `floor(pass(...))` print `9223372036854775807`. `floor(9007199254740993)` gives
  `...992`; old and runtime give `...993`. Same with `--no-spec`, so it is the typed path.
- Fix: for kind round, do not inline literals with a whole-number value (the runtime returns ints
  unchanged), or accept a literal only when `skind == "float"`.

## M3. Medium (policy): int and float mix at run time in operators and comparisons

- Where: `zue_rt_ops.zu:180` (`lvp_add`; the same `_is_num` branch in `-`, `*`, `/`, `%`, `<`, `==`).
- Repro: `pass(1.0) + pass(1)` gives `2.0`; `pass(7) % pass(2.0)` gives `1.0`;
  `pass(9007199254740993) == pass(9007199254740992.0)` is `true`. Builtins too: `sqrt(pass(4))` gives `2.0`.
- The typed form `a + b` is a Type Error, so the result depends on whether the checker saw the types.
  Rule 8 says int and float never mix; literal adaptation is done at compile time, so the runtime could reject
  mixed tags. Owner decision.

## M4. Low/Medium: `clamp` mixes types

- Where: `zue_rt_math.zu:184`.
- Repro: `clamp(pass(5), pass(1.0), pass(10))` gives `5`; `clamp(pass(5.0), pass(1), pass(10))` gives `5.0`.
  Docs say "same type".
- Fix: apply `_same_number_type` to all three arguments.

## M5. Low/Medium: float `floor_div` and `mod` disagree

- Where: `zue_rt_math.zu:618` (`floor(a/b)`) vs `:578` (`fmod`).
- Repro: `divmod(1.0, 0.1)` gives `[10.0, 0.0999...]`, so q*b + r = 1.1 (Python: `(9.0, 0.0999...)`).
  `mod(-1e-300, 1e300)` returns `1e300`, equal to the divisor.
- Fix: derive q from fmod, `q = (a - r) / b` rounded.

## M6. Low: overflow in an intermediate step when the result is finite

- `sum([1e308, 1e308, -1e308])`, `mean([1e308, 1e308])` (`zue_rt_math.zu:136-182`),
  `lerp(-1e308, 1e308, 0.5)` (`b - a` overflows, `:665`), `deg_to_rad(1.7e308)` (`x*pi` before `/180`, `:274`).
- Fix: divide first; lerp as `a*(1-t) + b*t`.

## M7. Low: vector arithmetic converts ints to floats silently

- Where: `zue_rt_ops.zu:125` (`_list_arith`).
- `[1, 2] + [3, 4]` gives `d[4.0, 6.0]`; `vec_add([1, 2], [MAX, 1])` gives `9.22337e+18` with no overflow
  error; `[1, 2.5]` mixes types. `vec_add([], [])` returns `[]` while the dense branch returns `d[]`.

## M8. Low: messages

- `int(pass(1e19))` says "to_int() of a float that does not fit" (names to_int for an int() call).
- `dense_list` with a huge size gives "Runtime Error: out of memory" with no line.

## Math: checked and correct

- abs, sqrt, cbrt, exp, ln, log10, trig, hyperbolic: domain and overflow errors, no NaN or inf, -0 normalized.
- pow and `**`: (-2)^63 exact, 2^63 overflows, 0^-1 division by zero, negative base with fractional exponent
  a domain error, 10.0^400 overflow.
- min, max reject mixed int and float; sign, isqrt, gcd, lcm correct including INT64_MIN.
- Int `+ - * /` and unary `-`: every overflow is an error, `-MIN` included. Shifts by 64 or -1 are errors,
  `3<<62` overflows, `~MIN` correct. `floor_div(MIN, -1)` overflows, `mod(MIN, -1)` is 0, `% 0` is an error.
- int, float, to_int, to_float reject nan, inf, 0x and overflowing strings. vec length, type, /0 and overflow
  checks hold; vec_mul_inline correct.
- Leaks: 2M and 8M iterations over all of the above kept peak RSS flat at 87 MB.
- math-review.md items marked fixed are confirmed fixed.

# Low

Strings
- `pad_left`, `pad_right`, `join` name the wrong argument in type errors: `_text_str(..., argv + 32, 0, ...)`
  (`zue_rt_lib.zu:1374`) and `(argv_p + 16, 0, ...)` (`:1444`); the index should be 2 and 1. The caret
  (`lv_err_arg`) points at the wrong argument too. Fixing it means re-recording tests.
- `pad_*` uses only the first byte of a longer pad (`pad_left("7", 3, "ab")` gives `"aa7"`; `"é"` writes
  0xC3 twice, invalid UTF-8; an empty pad returns s unchanged). Docs say "the character ch".
- `split` treats the delimiter as a set of characters (`split("a-b,c", "-,")` gives 3 pieces) and drops
  empty pieces; the comment at `zue_rt_lib.zu:1410` says they are kept.
- `str_len` accepts lists and maps; `concat` accepts chars; `to_int(12.7)` gives 12; docs say otherwise.
- `repeat` and `pad` copy through a doubling buffer then copy again: two 200 MB strings took 2.7 s and
  1.05 GB peak. Allocate once.
- `""[0:]` says "Slice start 0 is after its end -1"; with inclusive ends `s[len(s):]` always fails.
- Huge sizes (`repeat("ab", 40000000000000)`) end with a bare "out of memory", no line.
- `to_string` of a map does not escape quotes: `{"a\"b": "x\"y"}` prints `{"a"b": x"y}`.
- `trim` also strips `\v` and `\f` (undocumented). `to_float("1e-400")` silently gives 0.0.

Lists, sort, random
- `sort` on mixed int/float above 2^53 is not transitive (`_sort_cmp` converts ints to float).
- `remove` (`zue_rt_lib.zu:766-768`) and `ssort` (`zue_rt_math.zu:1206`) leave old values in slots past the
  end, which keeps them alive (read only). Zero the slots.
- Docs claim a seeded shuffle reaches every order of up to 34 items; `_seed()` (`zue_rt_math.zu:1066`) uses
  one 64-bit value, so it is 20 (read only).
- `slice(dense, 0, 1)` says "argument 1 must be a string, got list"; `d[0:1]` "cannot slice a value of type
  list" (`zue_rt_lib.zu:790`).
- `rand(-3)` returns values in [-3, 0]; docs say "from 0 to max".
- The `len()` Type Error has no `[E0xxx]` code (`zue_rt_lib.zu:167`).

Unsafe, box, bloc
- One long unsafe block grows about 86 bytes per alloc (known limit in leak.md): 100k pairs 12.5 MB, 1.6M
  141 MB.
- Imprecise errors: `free(ptr_offset(c, 1))` says "pointer is not registered" (it is not a base pointer);
  storing a pointer into alloc memory says "stored inside GC-managed values"; `defer(address_of(x))` gives
  "Variable 'address_of' is not defined".
- A never-written slot reads as `null` (`zue_rt_data.zu:1915`), against rule 8; the `PM_FLAGS` calloc result
  is unchecked.
- A recursive function containing unsafe fails at depth 65 ("nested more than 64 deep"), undocumented.
- `alloc` in a helper function called from inside unsafe works; docs say only inside `unsafe { }`.
- Stale docs: box limit is 1 to 16777216 bytes and more than 4096 boxes may live (memory.md:80, 133, 134;
  data-types.md:121, 122 say 4096). Bloc cap is 64 bytes (data-types.md:95, 103 and memory.md:97, 135 say
  32). An untyped bloc rejects a string but a typed one accepts it. unsafe.md:184 and data-types.md:147 say a
  bloc cannot be made in unsafe; it can. memory.md:107 says twelve safety rules; there are ten.
  data-types.md:150 repeats a line.

Threads and I/O
- `read` peaks at about 3.8 times the file size (600 MiB file: 2.28 GB). `fstat` and size once.
- `read_line` keeps `\r`, `input` strips all trailing `\r\n`; `read_line` returns `null` at EOF and on error.
- `yield`, `send`, `recv`, `wait` are rejected inside unsafe only when the thread actually switches
  (`zue_rt_blue.zu:393, 455-462, 485-501`); docs/builtins.md:101 says always.
- Thread error call stacks end with "called at line 0" (`_blue_main`, `zue_rt_blue.zu:205`).
- `system` returns `-1` on failure (`zue_rt_lib.zu:639-640`), against rule 8. `open` returns `null` (documented).
- Deferred calls do not run on `exit()` or after an error (undocumented); an error inside a deferred call
  points at the `return` line with no caret; the `defer(close(f))` example in docs/syntax.md:258 has no null
  check.
- `recv` does not clear the slot it read (`zue_rt_blue.zu:486-489`), so the value stays reachable (read only).
- File handles are never closed by the GC (documented); under `ulimit -n`, unrelated calls like `system`
  then fail.
- `channel(-1)` error has no `[E04xx]` code.

Compiler
- Parser: a second `default:` silently replaces the first; duplicate `case` values and map keys are silent.
- Lexer: `1e0000001`, `0e9999999`, `1.7976931348623158e308` wrongly "do not fit" (`lexer.zu:401-446`).
  `"\é"` prints half a UTF-8 char in the error (`lexer.zu:235`). "Unexpected token 'eof'" inside `"{1 +}"`
  is misleading.
- About 20,000 nested parentheses print an internal parser stack trace instead of a syntax error.
- `diag.zu`: cost is quadratic in the error count (10k errors about 2 s); errors from different files are
  sorted by line only.
- Error codes: 6 recorded runtime errors have no code (deadlock, wait-for-self, closed-channel send/recv,
  negative channel size, `len()`); compile errors "break/continue outside loop" and "defer expects a call"
  have none.
- `analysis.zu` captures names that are a nested function's own parameters and locals (speed only, read only).
- `func f()` and `switch (x)` do not accept a newline before `{`; `else` accepts only one newline (read only).
- Duplicate template fields are caught only at run time (E0470).
- Functions with no parameters are never specialized (speed only).
- Makefile has no fixed-point check for the runtime seed: if `emit_native.zu` changes, the stale-seed
  warning stays silent (read only).
- `build_runtime.sh` rewrites `C/zue_rt_native.ll` and `.o` with no lock; `zue build` writes
  `C/<basename>.ll`, so same-named programs in different folders overwrite each other.
- The recursion-limit call stack ends in "called at line 0".

Tests
- `test_resource_bounds.zu` `grew()` allows +33% plus 16 MiB: a per-use leak under about 180 B (threads),
  110 B (channels), 18 B (boxes) would pass. No case covers template-owned boxes, varying alloc sizes,
  `ptr_add`, blocked threads, files, or VMA count.

# Checked and correct

- Seeds in sync with sources; `make` and `make test` (856 passed) in a copy; round-trip 840 same, 0 different.
- Every one of the 135 builtins has a runtime function and a docs entry; `error_codes.zu` is current.
- Raw int/float arithmetic: about 2,600 edge cases match the boxed runtime path.
- Direct-call guard: reassignment, shadowing, spawned threads, GC stress do not fool it (except B1).
- GC pages, scoped boxes, per-block alloc/free, thread stacks (1M spawns), channels, strings (4M iterations
  of 20 functions) stay flat in memory.
- sort: correct against a Python reference up to 1M items, stable, no slow pattern; shuffle/rand uniform with
  no modulo bias; srand repeatable.
- GC stress and verify modes pass on sort, shuffle, map, filter, channels, parked threads, values in alloc
  memory.
- Deadlock detection, wait errors, closed-channel errors, stdout flushed before errors, system and exit.
