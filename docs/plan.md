# Plan: Hush, a near-pauseless garbage collector

Written 2026-10-30. Numbers marked "measured" come from `bench/gc/measure.sh` on this machine
(16 cores, 23 GiB). Everything else is a target, not a result.

## Name and summary

**Hush GC**: a conservative, non-moving, incremental tri-color mark-sweep collector with an SATB
write barrier, lazy sweep and size-class pages. Marking later moves to a GC thread that runs in
parallel with the program.

## Goals and priorities

Low pause and low memory come first. CPU use and throughput come second.

| Goal | Target |
|---|---|
| Pause time | Under 1 ms for live heaps up to 4 GiB |
| Memory | Peak memory close to live memory, empty pages returned to the OS |
| CPU use | The GC thread may use another core; no program-side work that scales with heap size (phase 9) |
| Throughput | At least twice at the same pause, later |

## Options

There are no collector flags. The write barrier is always emitted. The policy (when to start a cycle,
how much the program may allocate during one) is worked out at run time by the pacer (see "Phase 8b
result"). Run-time tuning uses environment variables for tests only: `ZUE_RT_GC_STRESS`, `_STATS`,
`_VERIFY`, `_SLOW`.

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

## Phase 3 result (measured)

The next collection now starts after a percentage of the live bytes has been allocated (`ZUE_RT_GC_GROWTH`;
before it was 100). Defaults: 45 for `lowpause`, 200 for `throughput`. Empty pages are given back with
`madvise(MADV_DONTNEED)`, 16 per collector step, keeping as many as the next cycle can allocate.

At 1 GiB live (1.24 GB real), 20 M churn iterations, `lowpause`:

| Growth | Peak memory | Peak / live | Churn rate |
|---|---|---|---|
| 25 | 1.59 GB | 1.28 | 3.7 M/s |
| 40 | 1.84 GB | 1.49 | 4.4 M/s |
| 50 | 1.90 GB | 1.54 | 4.9 M/s |
| 100 (before) | 2.60 GB | 2.1 | 5.7 M/s |
| 200 | 3.85 GB | 3.1 | 6.1 M/s |

Final defaults: `lowpause` (45) peak 1.84 GB (1.49 times live), 4.29 M/s, longest pause 0.24 ms;
`throughput` (200) peak 3.55 GB, 5.97 M/s, longest pause 378 ms. The test `test_gc_pages_returned.zu`
checks that resident memory falls under half of the peak after a large structure is dropped
(373 MB to 29 MB); with the trim disabled it fails.

What this shows, without softening:

- Memory is bought with speed: `lowpause` at 45 is about 25 percent slower than at 100. Moving the work
  to a GC thread (phase 8) is what should win that back.
- Raising the ratio is a weak lever for speed: 200 instead of 100 gives about 8 percent. It cannot reach
  the 2 times throughput goal.
- Unbounded trimming at the end of a cycle made one sweep step 7.3 ms; trimming 16 pages per step keeps
  the longest pause at 0.24 ms.
- Earlier "peak is 1.5 times live at 4 GiB" was an artifact: that run allocates less garbage than the
  threshold, so the peak was never reached.
- `test_gc_pages_returned.zu` takes over 60 s with a full collection every 25 allocations in
  `throughput` mode, so it is left out of that stress run; it passes in `lowpause` under stress.

## Phase 4 result (measured)

All 55 module-level variables of the collector, the class lists and the span cache are now one
zero-filled block of 17336 bytes (`_heap0`) in `zue_gc.zu`. A field is read with `ld64(h + H_NAME)`
where `h = _heap()`. `_gc_setup` sets the four fields that start non-zero (heap low bound, threshold,
growth percentage, limit); `lv_gc_set_mode` runs it first. The only use outside the file is the stack
check in `zue_rt_ops.zu`. Nothing else changed, which was the goal: the suite passes (757 tests), the
GC tests pass in both modes under stress and the verifier, and the 1 GiB benchmark gives the same
number of collections (20 and 8) and the same peak memory as before, at 4.46 and 6.17 M/s (4.29
and 5.97 before). A mutant that gave two fields the same offset crashed the compiler's self-build.

For a process to own its own collector (blue threads) or a GC thread to use the state, `_heap()` is the one
place to change: it returns the block in use.

## Phase 8 stage 1: concurrent marking (plan, then result below)

Measured first (4 GiB live, `lowpause`, 20 M churn): wall 9.97 s, of which the collector takes 4.24 s
(marking 3.58 s, sweeping 0.65 s). With all of that off the program thread the run would be about
5.7 s, so a concurrent collector alone gives at most 1.75 times; the 2 times goal needs cheaper
allocation as well. Marking is 85 percent of the collector's time, so it goes first.

Stage 1, concurrent marking, sweep stays incremental on the program thread:

| Part | Design |
|---|---|
| GC thread | One thread, started with the program, asleep on a condition variable between cycles. It owns the mark stack |
| Cycle start | The program thread scans its own stack, registers, data segment and root ranges (the snapshot), then wakes the GC thread. Short pause, same as today |
| Mark bytes | Set with a compare-and-swap, so an object is pushed once whichever thread gets there first |
| Write barrier | Still the SATB barrier, but it no longer touches the mark stack: it sets the mark byte and appends the object to a buffer that the GC thread drains |
| Root ranges added during a cycle | Scanned by the program thread through the same buffer |
| New pages | A page descriptor is completely written before it is put in the page table (a store fence between), so the GC thread never sees a half-made page |
| Cycle end | When the GC thread's stack is empty it says so. At the next allocation check the program thread drains the buffer; if nothing new arrived, marks are final and the sweep starts. Short pause |
| Backpressure | If the program allocates more than a set share of the live size during a cycle (allocate-black), it waits for the GC thread instead of growing memory without bound |
| Verify mode | Stays: at cycle end, with the program thread stopped, the heap is walked again |
| Thread tests | A mode that makes the GC thread slow (sleep between objects) so races show up; the whole suite runs under it |

Stage 2, later: concurrent sweeping, which touches the page lists the allocator uses and is harder.

Not changed: only one thread runs Zue code. Pause goal is still under 1 ms at 4 GiB.

## Phase 8 result (measured)

Marking now runs on a GC thread in `lowpause` mode; sweeping stays in steps on the program thread. First
the new pieces: atomic intrinsics in the native dialect (`ld8a ld64a st8a st64a cas8 fence`, with a
unit test and a mutant that weakens the ordering), the GC thread with a mutex and two condition
variables, mark bytes set with a compare-and-swap, the page table published with release stores, a
local batch of objects the barrier marked that is handed to the GC thread, and a throttle for a program
that allocates faster than the thread marks.

Audit (2026-10-31, after a first version of these numbers was questioned): single runs were misleading, so
every figure below is the mean of 5 interleaved runs with the range, 20 M churn iterations, and the old
`lowpause` is the committed collector built from the previous commit. "4 GiB" is only the request: the real
live data was 4.54 GB (`throughput`), 4.95 GB (old `lowpause`) and 5.0 to 6.0 GB (new, because what is
allocated during a long cycle stays until the next one), so compare peaks for the same workload, not ratios.

| 4 GiB requested | Wall time | Churn rate | Peak memory | Longest pause |
|---|---|---|---|---|
| old `lowpause` | 9.68 s (9.65-9.72) | 4.49 M/s | 7.33 GB | 0.27 ms (0.22-0.34) |
| new, cap 1/25 (default) | 8.82 s (8.50-8.93) | 4.91 M/s | 7.49 GB | 0.25 ms (0.22-0.30) |
| new, cap 1/4 | 7.37 s (7.17-7.69) | 5.78 M/s | 9.32 GB | 0.27 ms (0.18-0.36) |
| new, cap 1/1 | 7.05 s (6.94-7.10) | 6.12 M/s | 9.17 GB | 0.18 ms (0.17-0.18) |
| old and new `throughput` (same code) | 6.90 and 6.87 s | 7.68 and 7.59 M/s | 9.32 GB | 788 and 793 ms |

At 1 GiB (earlier version of the throttle): old 5.76 s and 1.84 GB, new default 4.84 s and 2.07 GB, cap 1/4
4.42 s and 2.55 GB.

What this shows, without softening:

- **The two `throughput` rows are the noise baseline**: the same code, 0.5 percent apart. Differences
  above about 2 percent are real.
- **At the old memory the wall time is about 9 percent shorter** (the churn rate about 10 percent higher). One GC thread marks about 4 GB per second while
  the program allocates about 1 GB per second, so a cycle at 4.5 GB takes 0.8 to 1.2 s and everything
  allocated meanwhile stays until the next cycle. The cap (the throttle) holds that back and costs speed:
  in the default run it held the program back 13,700 times for 2.1 s in total, a quarter of the run.
- **Speed can be bought with memory.** With a loose cap the wall time is 24 to 27 percent shorter (the churn rate 29 to 36 percent higher) and
  reaches the speed of `throughput` mode (7.05 against 6.90 s) with a 0.2 ms pause instead of 790 ms, for
  25 to 27 percent more memory than the old `lowpause` and the same as `throughput`.
- **The growth percentage hardly changes memory now** (1 GiB: 2.1 GB at 15, 2.5 GB at 45), because
  floating garbage dominates.
- **The GC thread alone cannot give 2 times.** The collector's work was 4.2 s of the old 9.97 s run; moving
  it off the program thread cannot give more than about 1.75 times, and the single marker is too slow to
  get there without much more memory. Next steps for speed: faster marking (prefetching, several marking
  threads), concurrent sweeping, cheaper allocation, the generational layer.

Mistakes found and fixed during the audit:

- The first version waited for the GC thread when the program ran ahead. That made a 154 ms pause (the
  program stopped until marking finished), so it became a throttle.
- The throttle slept with `usleep`, which overshoots: one run in five had a pause of 3 ms. A spin made the
  pause 0.25 ms.
- The spin called `sched_yield`, which handed the core away: the program saw one stall of 1.4 to 2.2 ms in
  4 of 5 runs (old collector: none over 0.4 ms). Found by tracing the program thread's system calls
  (`strace`) and by `bench/gc/stalls.zu`, which times every iteration; without the yield the worst stall
  is 0.28 to 0.40 ms in 6 of 6 runs at 1 GiB and 0.32 to 0.39 ms at 4 GiB, the same as before.
- The collector's pause counter does not include the program waiting inside the write barrier, so it
  under-reports; judge pauses with `bench/gc/stalls.zu`.
- My first "no throttle" test divided by a huge number, which shrinks the cap; the loose settings are
  small divisors.

How it was checked:

- The suite passes (757 tests) and the GC tests pass under `ZUE_RT_GC_STRESS` 3, 7 and 25, with the
  verifier, with `ZUE_RT_GC_SLOW` set, three times over.
- Mutants run against the test programs alone (the compiler built from good sources): the barrier that
  does not mark (`test_gc_barrier.zu` fails), no hand-over at the end of a cycle and no allocate-black
  (all GC tests fail). A guard against recycling pooled pages during a cycle is not covered by any test;
  without it memory was the same and nothing failed, so it is defence in depth that no test shows to be needed.
- `tools/gc_race_check.sh` builds with ThreadSanitizer and reports only two kinds of race, both intended
  (the scan reading object contents, and the page lookup reading the used count and used flags while an
  object is handed out). Mutants with a plain store in the page table, a plain mark store instead of the
  compare-and-swap, and a hand-over without the mutex are each reported.
- With the program sleeping in `system("sleep 3")` the process used 0.02 s of CPU, so the GC thread sleeps
  when idle.

Not changed: only one thread runs Zue code.

## One collector (2026-10-31)

The one-piece (stop-the-world) cycle was removed: `_gc_full`, `_mark_some`, `_cache_trim_all`, the
no-barrier code generation of `--gc=throughput` and the fallback when the GC thread cannot be created.
There is one collector. `--gc=throughput` (and `ZUE_RT_GC_MODE=throughput`) now only sets two numbers:
collect after the heap grew by 200 percent (45 for `lowpause`), and let the program allocate a whole heap
during a cycle before it is held back (1/25 for `lowpause`). If the GC thread cannot be created the program
stops with a precise error (checked by making `pthread_create` fail through `LD_PRELOAD`).

Final measurements, 5 interleaved runs each, mean (range), live data requested 4096 MiB:

| | Wall time | Churn rate | Peak memory | Longest pause |
|---|---|---|---|---|
| before this phase, `lowpause` | 9.73 s (9.67-9.82) | 4.46 M/s | 7.33 GB | 0.26 ms (0.20-0.34) |
| now, `lowpause` | 9.22 s (9.12-9.31) | 4.65 M/s | 7.81 GB | 0.30 ms (0.22-0.47) |
| before this phase, `throughput` | 6.88 s (6.86-6.90) | 7.64 M/s | 9.32 GB | 785 ms (780-791) |
| now, `throughput` | 6.28 s (6.26-6.31) | 7.37 M/s | 9.78 GB | 0.16 ms (0.16-0.17) |

At 1 GiB requested: `lowpause` 5.71 to 4.96 s, 1.84 to 2.07 GB, pause 0.31 to 0.40 ms (worst single run
0.85 ms); `throughput` 4.19 to 3.98 s, 3.55 to 5.01 GB, pause 355 ms to 0.19 ms.

What this shows, without softening:

- `throughput` is now 9 percent faster than the old stop-the-world one and its pause fell from 785 ms to
  0.16 ms, for 5 percent more memory. It is 55 percent faster than the old `lowpause` (6.28 against 9.73 s).
- `lowpause` is only 5 percent faster than before at 7 percent more memory in this batch (an earlier batch
  gave 9 percent at 2 percent; the machine's clock varies between batches, within a batch the runs agree).
  Its worst pause at 1 GiB reached 0.85 ms in one run: under the 1 ms goal, with little margin.
- At 1 GiB the throughput profile uses 5.0 GB for 1.5 GB of live data. A fixed 200 percent growth is
  memory-hungry on small heaps.
- The whole suite passes built with either profile (757 tests), and the GC tests pass under stress in
  both, including the page-return test that used to time out in the one-piece mode.

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
| 3 | Memory trigger: configurable heap growth ratio replaces "equal to live"; return empty pages with `madvise` | Done. See "Phase 3 result" |
| 4 | Move collector state out of module-level globals into one struct | Done. See "Phase 4 result" |
| 5 | Lazy sweep and chunked scanning of large objects | Done (in incremental mode). See "Phase 5 result" |
| 6 | Incremental marking on one thread: SATB barrier (runtime and compiler), allocate black, pacing, verify mode | Done. See "Phase 6 result" |
| 7 | `--gc=lowpause` and `--gc=throughput` flags; remove the old collector | Done. See "Phase 7 result"; since phase 8 `throughput` is a profile of the one collector, not a different one |
| 8 | Marking on the GC thread, in parallel with the program | Stage 1 done (marking). See "Phase 8 result". Concurrent sweeping and more marking threads not done |
| 8b | The pacer replaces fixed growth and throttle numbers; `--gc` flags removed | Done. See "Phase 8b result" |
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

## After the collector: blue threads

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
| Barrier and slicing cost throughput | Measured in phase 6 and 8 |
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

## Phase 8b result: the pacer

The growth percentage (45 or 200), `CAPDIV` and the 64 MiB slack are gone, and so are `--gc=throughput`,
`ZUE_RT_GC_MODE`, `_GROWTH` and `_CAPDIV`. `_after_sweep` measures the allocation rate and the cycle cost
per MiB of live data and sets the next start and the heap goal (see `docs/gc.md`, "The pacer").

Program `bench/gc/stalls.zu`, 20 million iterations, one run per build and size, `ulimit -v 22000000`.
Live is the collector's own count, which differs between the builds. Ratios computed by script.

| Request | Wall old to new | Peak / live old to new | Worst stall old to new | Throttle old to new |
|---|---|---|---|---|
| 100 MiB | 4.44 to 4.64 s | 2.11 to 2.06 | 0.60 to 0.33 ms | 0 to 0.01 s |
| 1 GiB | 5.52 to 5.57 s | 1.61 to 1.50 | 0.30 to 0.26 ms | 0.59 to 0.10 s |
| 4 GiB | 9.27 to 8.87 s | 1.49 to 1.50 | 0.37 to 0.22 ms | 1.93 to 0.46 s |
| 8 GiB | 14.67 to 15.59 s | 1.31 to 1.23 | 0.37 to 0.69 ms | 3.82 to 1.67 s |
| 10 GiB | 16.40 to 19.89 s | 1.50 to 1.15 | 3.43 to 0.43 ms | 4.13 to 3.44 s |

- The old build stalled at 10 GiB (3.43 ms, 5 stalls over 1 ms, peak 16.5 GB) and again in two earlier runs
  at 8 GiB (14 ms once). The cause is not proven; the stall went away when the peak fell to 14.1 GB.
- Peak memory falls at 10 GiB only. The pacer runs more cycles there (22 against 16) and each marks all
  live data again, so user CPU rose from 20.2 to 31.9 s and wall time by 21 percent. Phase 9 targets this.
- Not done: `ulimit -v` is not read; the constants 2 (margin), one half of free memory and 16 MiB remain;
  no test checks the pacer's numbers, only that every collector test passes (also with stress and verify).

## Blue threads, version 1

`compiler/runtime/zue_rt_blue.zu`. Coroutines on the one program thread and the one heap: each has a 1 MiB
mapped stack with a guard page, `swapcontext` switches, and a thread gives up the processor only in `wait`,
`yield`, `send` and `recv`. Channels are buffered or unbuffered. User-facing builtins: `spawn wait yield
channel send recv channel_close` (see `docs/builtins.md`). The threads and channels are collector objects.
At the start of a cycle `_scan_stack` also scans the stacks of the threads that are away.

- Per-thread state that is saved and restored at a switch: the call depth and frames, the current position,
  and the stack limits. Errors end the program, so no unwinding state exists. A switch inside an `unsafe`
  block is an error, because its deferred calls and boxes are kept on stacks shared by all threads.
- Test: `test/test_blue_threads.zu` (18 cases). Case 17 holds data only on the stack of a thread that is
  away. With the scan of away stacks removed it fails under `ZUE_RT_GC_STRESS=1` (checked).
- Not done: preemption, running threads on several OS threads, per-thread heaps (phase 2 of this work),
  a closed-channel receive that is not an error, `sleep`, and a limit on the number of threads other than
  the operating system's.

## Next steps

The order of work after blue threads version 1. Each step says how to know it is done.

| Step | Work | Done when |
|---|---|---|
| 1 | Prove or rule out the stall of 3 to 6 ms at 10 GiB (default mode, peak 14 to 16 GB). Repeat the run 5 times and record the stall times with `/proc/vmstat` deltas, `MemAvailable` and the transparent hugepage setting; try `MADV_NOHUGEPAGE` on the heap. `perf` is blocked here, so counters are the evidence | An experiment shows the cause, or it is logged as unexplained. A fix only if the cause is in our code |
| 2 | Blue thread hardening: a long churn test (threads created and finished for minutes, with a multi-GB heap); document that `system()` and file reads stop every thread; add `sleep(seconds)` with a timer queue | The churn test shows no growth in memory and no long pause |
| 3 | Throughput toward 2 times at the same pause: profile first with `callgrind` (`bench/instruction_count.sh`) on the churn benchmark, then the cheapest fixes in order: a faster allocation path, the barrier check inlined in generated code, concurrent sweep, parallel marking | A benchmark named beforehand reaches 2 times at the same worst stall |
| 4 | Per-thread heaps: the runtime globals (about 54) and the compiler's globals become per-thread contexts, messages are copied, each thread has its own collector | A design is shown first. Then a thread's pause depends only on its own data |

Open decisions:

| Decision | Options |
|---|---|
| How a receiver learns that a channel is closed | `channel_closed(ch)`; or `for (let v in ch)` ending when the channel is closed and empty (needs a parser change and a seed cycle); or keep the error |
| Which benchmark defines 2 times | The churn loop in `bench/gc/stalls.zu`, or another |
| Whether `sleep` is needed in version 1 | Now or later |

A generational layer stays out unless step 3 shows that marking is still the main cost. A page lookup in the
write barrier cost 29 percent on a write-heavy loop (0.67 s to 0.87 s for 100 passes over 200000 lists).

## Blue threads against goroutines

What Go's runtime does by itself, and where blue threads version 1 stands:

| Go does by itself | Blue threads (version 1) |
|---|---|
| Spreads goroutines across all cores | No. Everything runs on one OS thread |
| Switches a goroutine at almost any point (preemption) | No. A thread switches only at `wait`, `yield`, `send` and `recv`. A loop that never waits starves the others |
| Grows and shrinks stacks | No. Each stack is fixed at 1 MiB of address space, and a thread can nest only about 1200 calls |
| Starts and stops OS threads and GC workers to fit the load | No. The GC thread is the only helper |

In Go, too, the programmer starts goroutines (`go f()`); here it is `spawn(f)`.

## Decision: no collector inside a blue thread

The idea was to collect small heaps in a light thread on the program's own thread and to switch to the GC
thread past 0.5 ms. It is dropped:

- The GC thread is cheap. A program that prints one line starts in 1.24 ms against 0.56 ms for an empty C
  program, and the GC thread is a few percent of that (not measured on its own).
- 0.5 ms of marking is about 2 MB of live data (marking runs at about 4.6 GB/s), so only tiny heaps would qualify.
- Two ways to collect means more code and more states, and the switch in the middle of a run was never proved.

The related idea that stays: the pacer sizing the number of GC workers to the heap (none, one, or several marking in
parallel). It belongs to step 3 above (parallel marking) and has not been measured.

## Goal: blue threads like Go's, and a compiler that uses them

The goal: blue threads that behave like goroutines but cost less, so that the compiler itself runs on them and
becomes faster and safer. The steps, each to be shown as a design first:

| Step | Work | Needs |
|---|---|---|
| T1 | Preemption: the compiler emits a check of a flag at loop ends and calls, and the scheduler sets the flag on a timer | A cheap check in generated code, measured |
| T2 | Stacks that do not cost 1 MiB each: the collector scans stacks conservatively and does not move objects, so a stack cannot be copied. Options: a larger reservation with lazy commit, or a chain of stack pieces | A design and a measurement of both |
| T3 | Per-thread heaps and contexts (step 4 above) | The list of about 54 runtime globals and the compiler's globals |
| T4 | Run blue threads on several OS threads, with a queue per OS thread and stealing | T1 and T3 |
| T5 | The compiler uses them | See below |

Where the compiler spends its time (measured, `bin/zue emit compiler/zuec.zu`, 3 runs, and `clang -O1` on the
15 MB of IR it writes, 2 runs):

| Stage | Time |
|---|---|
| Zue front end: lex, parse, check, emit | 0.29 s (0.28 s user), 94 MB peak |
| `clang -O1` on the IR | about 7.0 s |

The Zue part is about 4 percent of the compile. Running it on blue threads can save at most a fraction of
0.29 s. The large gain is the clang step: split the IR into pieces and compile them in parallel. That needs
processes, not blue threads, and it loses optimization across pieces (inlining), so the speed of the compiled
program must be measured before and after. Neither has been tried.

"Safer" comes from threads that share nothing and talk through channels (T3), so there are no data races. It is
not a property of version 1, where threads share one heap but cannot run at the same moment.

## Session result: stalls, unsafe roots, throughput (measured 2026-11-01)

Machine: 16 cores, 23 GB. All counts below are from runs on it. The whole suite passes (787 cases, also under
`ZUE_RT_GC_STRESS=1`), and `tools/gc_race_check.sh` shows only the expected races.

| Change | Before | After |
|---|---|---|
| Heap chunks made ready by a helper thread (10 GiB) | worst stall 5.7 to 15.7 ms, 58 to 635 stalls over 1 ms | 0.32 to 1.37 ms, 0 to 2 |
| Root ranges scanned in slices (976 MiB `unsafe` buffer) | cycle start 225 ms | cycle start 24 microseconds, worst pause 0.23 ms |
| `ptr_offset` used the pointer table after it had grown (freed memory) | crash after about 4,000 pointers | fixed |
| Own int to text, one-allocation `"k{i}"` | string loop 5.43 M/s | 8.36 M/s (1.54 times) |
| `--release` (program and runtime optimized as one module) | allocation loop 6.97 M/s, string loop 8.36 M/s | 7.7 to 8.3 and 9.2 to 9.6 M/s |

The allocation-only loop (`bench/gc/alloc_only.zu`) did not change with the int to text work (6.96 against
6.97 M/s). Its profile: `_gc_alloc` 29 percent of instructions, `lvp_index` 16, the write barrier's shading 6.
The 2 times goal is not reached: the string loop is at 1.54 times and the allocation loop at 1.0 times (1.15
times with `--release`). Not done: a cheaper allocation path, an inlined barrier check, concurrent sweep,
per-thread heaps. The pointer table bug was found by a new test; two more tests (`test_gc_chunks`,
`test_gc_unsafe_roots`) were checked by breaking the code on purpose and seeing them fail.

