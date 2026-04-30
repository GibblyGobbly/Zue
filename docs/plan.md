# Plan: Hush, a near-pauseless garbage collector

Written 2026-10-30. Numbers marked "measured" come from `bench/gc/measure.sh` on this machine
(16 cores, 23 GiB). Everything else is a target, not a result.

## Name and summary

**Hush GC**: a conservative, non-moving, incremental tri-color mark-sweep collector with an SATB
write barrier, lazy sweep and size-class pages. Marking later moves to a GC thread that runs in
parallel with the program.

## Goals and priorities

Low pause and low memory come first. CPU use and throughput come second and are opt-in.

| Goal | Target |
|---|---|
| Pause time | Under 1 ms for live heaps up to 4 GiB |
| Memory | Peak memory close to live memory, empty pages returned to the OS |
| CPU use | Low by default; more only when asked for |
| Throughput | Raised only by the throughput flag |

## Build flags

The write barrier is emitted by the compiler, so the mode is chosen at build time.

| Flag | Meaning |
|---|---|
| `zue build --gc=lowpause` (default) | Incremental marking with the write barrier; small heap growth ratio; empty pages returned to the OS |
| `zue build --gc=throughput` | No barrier in the generated code; larger heap growth ratio; more CPU spent on parallel marking; fewer collections |

Run-time tuning uses environment variables, like `ZUE_RT_GC_STRESS` and `ZUE_RT_GC_STATS`.
The old stop-the-world collector is removed once Hush works. The throughput mode reuses its
code paths (mark, sweep) without the barrier. There is one collector, with two modes.

## Where we start (measured, old collector)

The old collector is stop-the-world mark-sweep. Program: `bench/gc/live_heap.zu`, which builds a
live heap and then makes 20 million short-lived objects while reading the live data. "Small"
means many 200-byte objects. "Big" means 1 MiB lists. CPU is user plus system time.

| Live heap | Shape | Collections | Longest pause | Total pause | Peak memory | Memory / live | CPU | Churn rate |
|---|---|---|---|---|---|---|---|---|
| 278 MiB | small | 22 | 68.6 ms | 1145 ms | 597 MiB | 2.15 | 3.95 s | 5.5 M/s |
| 1111 MiB | small | 13 | 261.6 ms | 1361 ms | 2374 MiB | 2.14 | 4.64 s | 5.6 M/s |
| 4444 MiB | small | 13 | 932.6 ms | 2579 ms | 7917 MiB | 1.78 | 7.95 s | 5.7 M/s |
| 272 MiB | big | 25 | 41.2 ms | 677 ms | 626 MiB | 2.30 | 3.62 s | 6.4 M/s |
| 1088 MiB | big | 17 | 165.6 ms | 793 ms | 2510 MiB | 2.31 | 4.86 s | 6.4 M/s |
| 4352 MiB | big | 18 | 409.6 ms | 1270 ms | 8769 MiB | 2.01 | 9.50 s | 6.7 M/s |

What this shows:

- The longest pause grows with the live heap: about 0.2 ms per MiB. At 4 GiB it is 933 ms, so
  the goal of 1 ms is roughly 1000 times lower.
- Peak memory is about 2 times the live size, because the next collection waits until as many
  bytes are allocated as are live.
- Throughput of the churn loop does not depend on the heap size. The cost of a big heap shows up
  in pauses and memory, not in the allocation rate.

Earlier audit findings on the large-object path (objects over 8 KiB):

| Problem | Evidence |
|---|---|
| Rounds up to a 64 KiB span and zero-fills all of it | A 9000-byte string loop is about 70 times slower than the 8000-byte one (8.0 s against 0.11 s at 200k iterations) |
| A swept large page keeps its 88-byte descriptor and table entries | 3M large allocations reached 304 MB peak memory |
| The whole span counts toward the collection trigger | About 778 collections in the 200k run |

## Phase 2 result (measured)

Program: build a string of N bytes, then 200,000 times make a new string one byte longer and drop
it. "Old" is the stop-the-world collector as it was at the baseline.

| Object size | Old wall | New wall | Old peak memory | New peak memory |
|---|---|---|---|---|
| 8,000 bytes | 0.15 s | 0.14 s | 20.7 MiB | 20.8 MiB |
| 9,000 bytes | 8.62 s | 0.18 s | 41.5 MiB | 20.7 MiB |
| 40,000 bytes | 8.87 s | 0.86 s | 41.5 MiB | 21.0 MiB |
| 100,000 bytes | 15.42 s | 1.96 s | 40.5 MiB | 21.3 MiB |
| 300,000 bytes | not measured | 5.30 s | not measured | 21.9 MiB |

What changed:

- Size classes now go up to 32752 bytes (31 classes). The five new classes hold 6, 5, 4, 3 and
  2 objects per 64 KiB page. The common 8 to 32 KiB objects no longer take the large path.
- A large object gets whole 64 KiB pages from `mmap`. The kernel zeroes them, so the `memset`
  is gone, and memory is touched only when used.
- A dead large object frees its page table entries and its descriptor. The 88-byte descriptor
  leak is gone. The used and mark bytes now sit inside the descriptor.
- The trigger counts the requested bytes, not the rounded-up span.
- Freed spans go into a cache of at most `g_threshold` bytes of touched memory. The garbage was
  already resident before the sweep, so the peak does not grow. A span that no allocation used
  during a whole collection is returned with `munmap`.
- Removing a cache slot clears its address. Without that, the conservative scan found the stale
  address in the data segment and kept dead objects alive (live bytes were 100 times higher).
- `ZUE_RT_GC_STATS` now also prints the time spent marking and sweeping.
- The page table needed no change: it is two-level and allocated on demand, so it never rehashes.

The live-heap benchmark did not change, as expected: its pauses come from marking and sweeping a
large heap, which phases 5 to 8 address.

| Live heap (4352 MiB, big lists) | Collections | Longest pause | Mark total | Sweep total |
|---|---|---|---|---|
| New collector, run A | 15 | 411 ms | 860 ms | 278 ms |
| New collector, runs B to D | 16 | 636 to 637 ms | 1111 to 1140 ms | 618 to 621 ms |

The longest pause at this size takes one of two values, depending on whether a 16th collection
lands near the peak. The old collector showed 410 to 428 ms with 18 collections. Read pause
figures in this size range as 400 to 640 ms until the collector no longer stops the program.

Known limits of this step: the 32752-byte class limit is a compromise, and the span cache search is
linear (512 slots at most). Neither matters until lazy sweep (phase 5).

## Phase 6 result (measured)

Incremental marking with the write barrier works and is checked. The sweep at the end of each cycle
is still stop-the-world, so the full pause is not under 1 ms yet.

Program: `bench/gc/live_heap.zu`, many small objects (and big lists), incremental mode.

| Live heap | Longest mark step | Cycle start | Cycle end (sweep) | Peak memory / live | CPU | Churn rate |
|---|---|---|---|---|---|---|
| 1181 MiB (small) | 122 us | 24 us | 138 ms | 2.14 | 5.60 s | 4.7 M/s |
| 4722 MiB (small) | 163 us | 26 us | 170 ms | 1.77 | 9.43 s | 4.5 M/s |
| 4785 MiB (big) | 120 us | 27 us | 249 ms | 1.84 | 10.48 s | 5.2 M/s |

Compared with the stop-the-world collector at the same sizes (above): the marking pause fell from
933 ms (4444 MiB) to 163 us. The sweep is the remaining pause (170 to 250 ms). Churn throughput is
about 15 percent lower (4.5 to 4.7 M/s against 5.4 to 5.7 M/s) and CPU use about 15 to 18 percent
higher. Peak memory is unchanged.

Measuring pauses: a mark step is bounded in work, but its wall-clock time sometimes shows 700 to 1000
microseconds. In those runs the thread's CPU time for the same step was 120 to 180 microseconds, so the
extra time is the operating system taking the processor away. `ZUE_RT_GC_STATS` reports both. The
claim of a bound is on CPU time. Wall time cannot be guaranteed in user space.

What was done to make it safe:

- Barrier sites found by reading every pointer-width store in the runtime (about 160) and every
  compiled store into a heap cell. The list is in [gc](gc.md).
- Mutation tests: switching off the cell, word or range barrier each makes `test_gc_barrier.zu` fail
  under the verifier. Before that test existed, the cell barrier could be switched off and the whole
  suite still passed.
- The compiler compiling itself (15 MB of IR) gives identical output under incremental mode with the
  verifier on, with up to 848 collections. The whole suite passes with the verifier on and a collection
  step every 25 allocations.

Open items: a mark step starts at a fixed 8 KB of allocation with no pacing
against how fast the program allocates; the barrier makes every cell write test one flag.

## Phase 5 result (measured)

The sweep now runs in steps of at most 50 microseconds between allocations, and cached large-object
memory is given back at most 1 MiB per step. In incremental mode no single pause is longer than about
0.5 ms in the benchmark, at every size up to 4.7 GiB of live data.

Program: `bench/gc/live_heap.zu`, incremental mode (now `--gc=lowpause`, the default). All times are the longest
single stop; the pause is the longest of the columns before it.

| Live heap | Shape | Cycle start | Mark step | Cycle end | Sweep step | Longest pause | Peak memory / live | CPU | Churn rate |
|---|---|---|---|---|---|---|---|---|---|
| 295 MiB | small | 40 us | 137 us | 6 us | 521 us | 521 us | 2.11 | 4.42 s | 5.1 M/s |
| 1181 MiB | small | 26 us | 126 us | 5 us | 527 us | 527 us | 2.15 | 5.06 s | 5.2 M/s |
| 4722 MiB | small | 26 us | 220 us | 4 us | 425 us | 425 us | 1.56 | 8.96 s | 4.9 M/s |
| 288 MiB | big | 29 us | 256 us | 6 us | 471 us | 471 us | 2.41 | 4.03 s | 5.5 M/s |
| 1152 MiB | big | 28 us | 71 us | 6 us | 350 us | 350 us | 2.14 | 5.43 s | 5.3 M/s |
| 4609 MiB | big | 37 us | 79 us | 5 us | 190 us | 190 us | 1.87 | 10.22 s | 5.3 M/s |

After this table the release chunk was cut from 4 MiB to 1 MiB; six runs at 1 GiB then gave longest
pauses of 151 to 392 microseconds.

Compared with the stop-the-world collector at the same sizes: the longest pause fell from 933 ms to
under 0.5 ms (4.4 GiB, small) and from 410 to 636 ms to 190 us (4.6 GiB, big). Churn throughput is
about 5 percent lower (4.9 to 5.5 M/s against 5.4 to 6.4 M/s), CPU use is about the same, and peak
memory is unchanged at about twice the live size (the trigger ratio is phase 3).

How the sweep was checked: a mutation test that makes the sweeper sweep pages created during a sweep
makes the tests crash; the whole suite passes with the verifier on and a step every 25 allocations;
the compiler compiling itself (15 MB of IR) gives identical output, with and without stress.

What still limits the claim: the numbers are for one benchmark on one machine; the longest wall-clock
pause can be longer when the operating system takes the processor away (the stats line reports
CPU time separately); `lv_data_gc_hook` (freeing the boxes of dead templates) runs in one piece at the
end of marking and its time grows with the number of live boxes (at most 4096); a very large root range
from `unsafe` is scanned in one piece at the start of a cycle.

## Phase 7 result (measured)

One collector remains. `--gc=lowpause` (default) runs cycles in steps with the write barrier;
`--gc=throughput` runs each cycle in one piece and the compiler leaves the barrier out. The separate
stop-the-world collector, the `ZUE_RT_GC_INCR` switch and the unused `lv_gc_collect` are gone.

Program: `bench/gc/live_heap.zu`, 20 million short-lived objects over a live heap, same machine as
the baseline. "Old" is the stop-the-world collector from the baseline table.

| Live heap (shape) | Collector | Longest pause | Peak memory / live | CPU | Churn rate |
|---|---|---|---|---|---|
| 4444 MiB (small) | old | 933 ms | 1.78 | 7.95 s | 5.65 M/s |
| 4722 MiB (small) | `lowpause` | 340 us | 1.56 | 9.62 s | 4.53 M/s |
| 4444 MiB (small) | `throughput` | 1554 ms | 1.76 | 10.16 s | 4.53 M/s |
| 4352 MiB (big) | old | 410 ms | 2.01 | 9.50 s | 6.73 M/s |
| 4610 MiB (big) | `lowpause` | 241 us | 1.87 | 10.95 s | 4.85 M/s |
| 4352 MiB (big) | `throughput` | 1186 ms | 1.95 | 12.28 s | 4.93 M/s |

At 1 GiB: `lowpause` 254 us (small) and 344 us (big); `throughput` 415 ms and 314 ms.
At 256 MiB: `lowpause` 188 us and 210 us; `throughput` 104 ms and 81 ms.

What this shows, without softening:

- `lowpause` meets the pause goal in this benchmark: every size stayed under 0.35 ms.
- `lowpause` costs throughput against the old collector: about 15 to 20 percent fewer churn
  iterations per second on small objects and 20 to 28 percent on big lists, and 10 to 20 percent more CPU.
- **Slowdown against the old collector: cause found and fixed (2026-10-31).** Neither suspect was the
  cause. The old compiler inlined `_mark_word` into the scan loop; with the barrier functions as extra
  callers it became a real call, made once per scanned word (44 M calls in a 64 MiB run), although most
  words (tags, ints) are not heap addresses. `_scan_range` now checks the heap range inline and calls
  `_mark_word` only for words inside it. Instructions in a 64 MiB run with 1 M churn: old 2.78 G, before
  the fix 3.49 G, after 2.94 G. At 1 GiB live, churn went from 4.9 to 5.74 M/s (`lowpause`) and from 4.8
  to 5.58 M/s (`throughput`); the old collector did 5.65 M/s. Mark time halved (1.66 s to 0.87 s). The
  suite passes (756 tests). A mutant of the new filter crashed the compiler's self-build.
- **`throughput` is still not faster than `lowpause`** in churn rate (5.58 against 5.74 M/s), so the
  barrier is not what costs throughput here. Its one-piece pause is long (265 ms at 1 GiB). Not yet
  measured: the 4 GiB runs after the fix, and where the last 5 percent of instructions against the old
  collector goes. Decide what the flag is for after that.
- Peak memory is still about twice the live size in both modes (phase 3).

Compile speed is not affected by the mode: compiling the compiler takes 0.31 s with `lowpause` and
0.30 s with `ZUE_RT_GC_MODE=throughput`, against 0.33 s with the collector before this work.

Checked on the final code: the whole suite passes in both modes (756 tests), also with the verifier on and a
collection every 25 allocations; the box, bloc, template and unsafe tests (141 cases) pass in both modes
at a collection every 3 allocations with the verifier on; the compiler's 15 MB self-build is
byte-identical in both modes and under stress; five mutants (the three barrier functions, allocate-black and
the sweep epoch) each make `test_gc_barrier.zu` fail. `test_gc_barrier.zu` with `ZUE_RT_GC_STRESS=1`
in `throughput` mode with the verifier takes 107 s (a full collection and a full check on every
allocation), longer than the test runner's 60 s limit; it passes when run directly.

## How Hush works

| Technique | What it does |
|---|---|
| Conservative scanning | Any aligned word on the stack may be a pointer. This is why nothing moves |
| Size-class pages | 64 KiB pages that each hold one object size (already used) |
| Tri-color marking | White (unseen), grey (on the mark stack), black (done); marking can stop and resume |
| SATB write barrier | Before a pointer in the heap is overwritten, the old value is recorded, so nothing alive when the cycle started can be lost |
| Allocate black | Objects created during a cycle start marked and survive it |
| Lazy sweep | Pages are swept when allocation needs them, not all at once |
| Chunked scanning | A big object is scanned in pieces of about 4 KiB |
| Pacing | Allocation does collector work in proportion to bytes allocated, so a cycle finishes in time |

What stays inside a pause: scanning the program's stack and registers, and draining the barrier
buffer at the end. Both depend on stack depth, not heap size.

### Program and collector in parallel

The program already runs on its own thread (see [memory](memory.md)). Hush adds one GC thread.
This does not make the language multi-threaded: there is still one thread running Zue code.

Order of work, because correctness matters more than speed:

1. **Incremental on one thread.** Marking runs in short time slices between program work. It is
   deterministic, so the barrier and the verify mode can be tested without races.
2. **Move marking to the GC thread.** The program thread keeps allocating and keeps the barrier
   buffer. Shared state (mark bytes, the page table, the mark stack hand-off) is made safe first.
   The program thread scans its own stack at the start of a cycle, then marking runs in parallel.

## Correctness: not freeing live objects

The rule to preserve: **an object that is reachable at the start of a cycle, or allocated during
it, is never freed in that cycle.**

| Case | Handling |
|---|---|
| A pointer is overwritten in a heap object | SATB barrier records the old value while a cycle is marking |
| A pointer is overwritten in a closure cell or variable box | The compiler emits the same barrier |
| A new object is created during a cycle | It starts marked (black) |
| A new object is initialised | No barrier: its old fields are null |
| The stack | Scanned once at cycle start; later changes are covered by SATB and allocate-black |
| An object dies during the cycle | It stays until the next cycle (floating garbage); never freed early |

Verification, in order of cost:

- **Verify mode** (`ZUE_RT_GC_VERIFY=1`): after each cycle a full stop-the-world mark runs, and the
  program stops with an error if the full mark finds a live object that the cycle freed.
- `ZUE_RT_GC_STRESS=1` on `test_gc_safety.zu`, `test_gc_large_safety.zu`, `test_template.zu`,
  `test_core.zu`, and the whole suite.
- An audit of every runtime store that can write a pointer into a heap object (`st64` in
  `compiler/runtime/`). Each is either given the barrier or shown not to need it.
- `make` itself: the compiler compiles itself twice and the output must be identical.

## unsafe, box, bloc and template

Decisions made from reading [memory](memory.md), [unsafe](unsafe.md) and the data hook in
`zue_rt_data.zu`.

| Kind | Where it lives | Decision |
|---|---|---|
| `bloc` | Small immutable GC object | Needs no barrier after construction; the fields never change. Allocated black like any new object |
| `template` | GC object with mutable fields | Field stores get the SATB barrier. Allocated black |
| `box` | Raw bytes outside the heap (stack frame or C heap) | Holds bytes, not Zue values, so it is never scanned. Needs no barrier |
| Box owned by a template | Freed by the data hook when the template is unmarked | The hook runs only when marking has finished (cycle end), so a live template is never seen as unmarked. A template that dies mid-cycle keeps its box one more cycle |
| `alloc()` buffer (unsafe) | C heap, registered as a root range | The range is scanned in full at cycle start, so a store into it needs no barrier (everything it held was marked). A range registered during a cycle is scanned immediately. A very large buffer makes the cycle start slower; it is not scanned in steps because a freed range would then be read after `free` |
| `alloc(object)` copy of a template or bloc | C heap root range | Same as an `alloc()` buffer |
| `address_of` pointers | Point into the stack | Never reach the heap, so no GC handling |
| Raw pointers in GC values | Forbidden by rule R2 | The collector never sees one, and this is unchanged |

The unsafe `store` is already checked by the rule functions, so adding the barrier there costs
almost nothing. Anything that is unclear after the audit is treated as needing the barrier.

## Latency that is not the collector

| Source | Fix |
|---|---|
| Zero-filling a huge new allocation | Skip the `memset` for fresh `mmap` memory, which the kernel already zeroed |
| Growing a huge list by copying | `mremap`, or chunked lists |
| `munmap` and `madvise` on big spans | Do them in slices |
| A very deep stack | Document a stack limit; root scanning time depends on it |

## Phases

Each phase ends with `make test` green, then `make seed` only when the tests pass.

| Phase | Work | Done when |
|---|---|---|
| 1 | Baseline with `bench/gc/measure.sh` | The table above (done) |
| 2 | Large-object fixes: size classes up to 32 KiB, `mmap` spans without `memset`, dead descriptors and table entries freed, real bytes counted toward the trigger, a bounded cache of freed spans | Done. See "Phase 2 result" |
| 3 | Memory trigger: configurable heap growth ratio replaces "equal to live"; return empty pages with `madvise` | Peak memory under 1.5 times live in `lowpause` |
| 4 | Move collector state out of module-level globals into one struct | Tests pass; no behaviour change |
| 5 | Lazy sweep and chunked scanning of large objects | Done (in incremental mode). See "Phase 5 result" |
| 6 | Incremental marking on one thread: SATB barrier (runtime and compiler), allocate black, pacing, verify mode | Done. See "Phase 6 result" |
| 7 | `--gc=lowpause` and `--gc=throughput` flags; remove the old collector | Done. See "Phase 7 result" |
| 8 | Marking on the GC thread, in parallel with the program | Longest pause under 1 ms at 4 GiB; verify mode clean |
| 9 | Optional generational layer (sticky mark bits and card marking) | Throughput gain measured |

## Comparison to fill in

For each phase from 3 onward, run `bench/gc/measure.sh` for the old collector, `lowpause` and
`throughput`, and record these in this file:

| Metric | Source |
|---|---|
| Longest and total pause | `ZUE_RT_GC_STATS` |
| Peak memory and memory / live | `/usr/bin/time` and live bytes from the statistics |
| CPU use | user plus system time from `/usr/bin/time` |
| Throughput | churn iterations per second, printed by the program |

## After the collector: ZueG

Light green processes come after Hush is done. Each process gets its own small heap, its own
collection, and its own stack. Large strings and lists live outside process heaps with a
reference count so messages can share them. Stack checks in function prologues and at loop ends
give overflow detection and preemption. Hush's state moves into a struct in phase 4 so that a
process can own one.

## Risks

| Risk | Handling |
|---|---|
| A missing barrier frees a live object | Verify mode, stress runs, the store audit. Atomic objects hold no pointers and need no barrier |
| A race once marking moves to a thread | Phase 8 comes after the single-thread version is verified; shared state is listed and made safe first |
| Barrier and slicing cost throughput | Measured in phase 6; the throughput flag removes the barrier |
| Fragmentation, since nothing is compacted | Size classes, page reuse, `madvise` |
| The OS adds latency (scheduling, page faults) | Cannot be removed in user space; track the maximum pause over long runs |
| The compiler and runtime are compiled by themselves | Follow the seed rules in CLAUDE.md |

## References

| Topic | Source |
|---|---|
| Go concurrent GC | https://dev.to/tamizuddin/inside-gos-concurrent-gc-visualizing-heap-traversal-and-latency-implications-58g1 |
| Mostly-parallel conservative GC | https://www.cs.purdue.edu/homes/hosking/ismm2000/papers/printezis.pdf |
| G1 (SATB, regions) | https://docs.oracle.com/en/java/javase/26/gctuning/garbage-first-g1-garbage-collector1.html |
| Generational ZGC | https://openjdk.org/jeps/439 |
| Azul C4 | https://www.azul.com/sites/default/files/images/c4_paper_acm.pdf |
| Erlang per-process heaps | https://www.erlang-factory.com/upload/presentations/765/EFSF2013Hitchhikers-Tour-of-the-BEAM.pdf |
| Pony ORCA | https://tutorial.ponylang.io/runtime-basics/garbage-collection |
| Verona regions | https://arxiv.org/pdf/2309.02983 |
