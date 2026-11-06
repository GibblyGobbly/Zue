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

## Session result: where the time went and what was done about it (measured 2026-11-01)

`callgrind` of the allocation-only loop (`bench/gc/alloc_only.zu`) showed that LLVM was not the limit. The same
program compiled at `-O0` ran at 6.3 M/s, at `-O1` 7.0, at `-O3` 7.2. The time went into what each operation
does: a 264-byte frame and six saved registers on every allocation, two allocations per list, a runtime call for
every `x[i]` and `len(x)`, and a check of every list item that the compiler already knew was an int.

| Change | Instructions per run | Allocation loop | String loop |
|---|---|---|---|
| Start of this step | 1.345 billion | 6.64 M/s | 7.95 M/s |
| `_gc_alloc` split into a short fast path and `_slow_gc_alloc` | 1.238 | 7.31 | 7.9 |
| A list with up to 32 items is one allocation | 1.149 | 8.4 | 9.0 |
| In-line `x[i]` and `len(x)`; no item check for ints, floats, bools and literals | 0.792 | 10.85 | 12.4 |
| `--release` on top | | 12.0 | 14.2 |

Seen from the start of the session (allocation loop 6.96 M/s, string loop 5.43), the allocation loop is 1.6 times
faster, 1.7 with `--release`, and the string loop 2.3 times, 2.6 with `--release`. The 2 times goal is met for
the string loop and not for the allocation loop.

A bug found on the way, present since before this work: `a + b` on strings called `_str_n` with the length
`la + lb` on the bytes of `a` alone, so it read `lb` bytes past the end of `a`. Harmless inside a page, a crash when
a large string ended where its mapping ended. It made `zue unparse` crash on `diag.zu` and `zue_rt_ops.zu` (and,
after the list change moved the layout, on `zue_rt_math.zu`), which is how `make round-trip` had 3 failures. `+` now
allocates once and copies each operand from its own bytes. `test_string_concat` fails with a crash on the base
commit and passes now; `make round-trip` is 774 same, 0 different.

Not done: concurrent sweep (the program thread still sweeps, 12 to 15 percent of its time at 1 to 4 GiB), an
inlined barrier check, per-thread heaps. At 10 GiB the worst stall with all changes is 1.3 to 2.1 ms with one stall
over 1 ms per run; the program allocates 1.5 times faster now, which puts more pressure on the kernel's memory
compaction, and that cause is likely but not proven.

## What limits the collector now, and what was tried (measured 2026-11-01)

With the mutator faster (see above), the program thread spends about 39 percent of its churn time on the
collector at a 1 GiB live heap (allocation loop, 20 million iterations): 383 ms is the throttle, where the
program is held back because it allocates faster than the marker keeps up, and 290 ms is sweeping, which also runs
on the program thread. Marking takes the collector thread 1.55 s over 13 cycles, 120 ms per cycle, about 87 percent
of the run, so marking is saturated.

Parallel marking was built and measured, then dropped. It had a context per marker, a shared pool for work, an idle
count for termination, and splitting of large ranges when donating (without the split, one marker kept the whole
live array and the others stayed idle: busy time summed to 0.92 of the wall time). With the split the markers worked
at the same time (sum 3.95 times the wall time) and throttling fell from 3,552 steps to 431. Throughput still fell:

| Marker threads | Allocation loop | String loop |
|---|---|---|
| 1 | 10.4 to 11.0 M/s | 11.5 to 12.4 |
| 2 | 9.7 to 10.0 | 10.1 to 10.8 |
| 3 | 9.1 to 9.2 | 9.5 to 10.0 |
| 4 | 8.0 to 8.1 | 8.3 to 8.4 |

The cycle got only 1.6 times shorter (390 to 238 ms) for four times the processor time (392 to 942 ms of marking
per cycle). Marking reads the whole live heap, so it is limited by memory bandwidth, and more markers compete with
each other and with the program for it. Keeping one marker is better on this workload. A write barrier that skips
cells tagged with a scalar was also tried: safe, but no measurable gain, so it was not kept.

What would help, in order of expected gain and of risk:

| Idea | Why | Cost |
|---|---|---|
| Sweep on the collector thread | 16 percent of the program thread's time at 1 to 4 GiB | The sweeper rebuilds the allocator's class lists and page pools; a hand-off of swept pages to the program thread is needed |
| Sweep by bitmap instead of by free list (as Go does) | Sweeping would flip mark bits per page and not touch every dead object | A new allocator fast path: find a free slot with a bit scan, zero on allocation |
| Lists of scalars that the marker does not read | A row of 8 ints is 160 bytes the marker reads and finds nothing in; marking cost per cycle falls with it | The cells would have to live in an atomic object of their own, which gives up the one-object list; a list that gets a pointer item must switch |
| A bigger heap goal | Fewer cycles, so less marking and no throttling | More memory; against the rule that memory comes first |

## Sweep without touching dead objects, and two things found on the way (measured 2026-11-01)

The sweep used to write a link into every dead object to build a free list, a cache miss per dead object, for memory the
allocator was about to write anyway. The free slots of a page are now the zero bytes of its used map below `PG_BUMP`;
`PG_FREE` is the place where the search for the next one starts and `PG_NFREE` counts them. A sweep only clears
bytes of that map. At 1 GiB (allocation loop, 20 million iterations):

| | Before | After |
|---|---|---|
| Sweep time on the program thread | 0.29 s | 0.09 to 0.12 s |
| Collector time on the program thread | 692 ms | 450 to 480 ms |
| Allocation loop | 11.1 M/s | 12.9 to 13.0 M/s |
| String loop | 10.8 to 12.6 | 13.2 to 13.5 |
| Worst pause | 0.2 to 0.3 ms | 0.25 to 0.35 ms |

Found on the way:

- Empty pages went back to the OS only inside the steps of a cycle (`_pool_trim`, 16 pages a step), so how much came
  back depended on how many steps a sweep took. The slow sweep took thousands; the fast one took few, and
  `test_gc_pages_returned` failed one run in two (300 MB resident against 47). Trimming now continues in small steps
  while the pool holds cold pages (`_pool_pending`), cycle or not. 20 runs, 0 failures.
- `ZUE_RT_GC_VERIFY=1` reported "an object can be reached but was not marked" in about a third of the runs of
  `test_gc_span_reuse`, since the helper thread for heap chunks was added (0 of 30 before it). The word that
  reached the object was in the collector's own state block: the address just past the current chunk
  (`H_CHUNK_END`), which is the start of whatever is mapped next to it, here a dead large object. Chunks are now
  kept as a start and a page count. 60 runs, 0 failures. Production runs were never affected (the word only kept
  garbage alive one cycle longer), but the verifier is what shows real collector bugs, so a false alarm in it matters.
- A mutation (the fast path no longer marks a recycled slot as used) is not caught by any program-level test I could
  write, although the collector then reports half the live bytes; making that branch return null or skip clearing the
  object does fail `test_gc_recycle`. The line is covered by reading and by the broad suites, not by a test of its own.

What limits the allocation loop now: the throttle (about 320 to 350 ms of 1.54 s) and marking, 1.6 s of collector
thread time for 13 cycles of a 1.5 GB live heap.

## Sweep of heap sizes, 1 to 10 GiB (measured 2026-11-01, one run per row)

The request is the argument of `bench/gc/live_heap.zu` and `alloc_only.zu` (200 bytes per row assumed; the real live data
is about 1.2 times that). 20 million iterations, 23.7 GB machine with about 5 GB in use by other things. Old is the commit
before this session's work (`4a389a9`), new is the build after the list change below.

| Request | Loop | Old M/s | Old peak GB | New M/s | New peak GB | Speed-up | Worst GC pause |
|---|---|---|---|---|---|---|---|
| 1 GiB | allocation | 6.64 | 2.59 | 12.19 | 3.06 | 1.84x | 0.24 ms |
| 1 GiB | string | 4.87 | 2.27 | 13.74 | 2.46 | 2.82x | 0.41 ms |
| 2 GiB | allocation | 6.14 | 4.76 | 13.70 | 5.00 | 2.23x | 0.20 ms |
| 2 GiB | string | 5.37 | 4.42 | 12.63 | 4.57 | 2.35x | 0.19 ms |
| 4 GiB | allocation | 5.74 | 8.61 | 12.34 | 7.96 | 2.15x | 2.14 ms |
| 4 GiB | string | 4.84 | 8.42 | 10.97 | 6.79 | 2.27x | 0.24 ms |
| 6 GiB | allocation | 5.14 | 10.78 | 15.86 | 10.53 | 3.09x | 0.37 ms |
| 6 GiB | string | 4.20 | 10.64 | 8.78 | 9.02 | 2.09x | 0.30 ms |
| 8 GiB | allocation | 3.45 | 12.07 | 5.88 | 12.73 | 1.70x | 0.60 ms |
| 8 GiB | string | 3.78 | 12.35 | 9.49 | 12.14 | 2.51x | 0.26 ms |
| 10 GiB | allocation | 1.89 | 12.62 | 2.60 | 12.93 | 1.38x | 0.58 ms |
| 10 GiB | string | 2.13 | 12.85 | 3.02 | 12.70 | 1.42x | 0.52 ms |

The first sweep showed the new build slower than the old one at 10 GiB (0.86 against 1.89 M/s) with 2 GB more peak
memory. The live data at the end was 15.3 GB against 12.4: the benchmark fills each row by appending 8 items, and a
list that outgrows the room inside its own object leaves that room dead (256 bytes a row against 176). An empty list now
keeps its items apart, as before; only lists made with known contents (literals, slices) share their object.
Above about 8 GiB both builds are limited by the collector and by the memory of the machine (peak 12 to 13 GB of 23.7).

## Pause distributions, adversarial workloads, cost against no collector, blue threads (measured 2026-11-01)

Program `bench/gc/pause_profile.zu` times every iteration of a loop with `clock()` (a normal one takes under a
microsecond) and keeps a histogram; `blue_contention.zu` does the same with many parked blue threads. One run each, on
the 23.7 GB machine with about 5 GB used by other things. The longest run was 15 minutes. Hours were not tried.

| Run | Live data | Loop | Throughput | p99.9 | Iterations over 1 ms | Longest delay | Collector's longest step | Peak memory (÷ live) |
|---|---|---|---|---|---|---|---|---|
| Churn, 5 min | 10.7 GB | short-lived lists | 2.76 M/s | below 200 us | 2 | 1.79 ms | 0.56 ms | 11.9 GB (1.12x) |
| Pointer writes into old rows, 5 min | 9.9 GB | a fresh list stored into an old row each iteration | 0.99 M/s | below 200 us | 5 | 3.09 ms | 2.12 ms | 10.6 GB (1.07x) |
| Aged heap, 6 min | 7.6 GB | rows rebuilt in 4 rounds with random sizes, then as above | 0.57 M/s | below 200 us | 0 | 0.74 ms | 0.73 ms | 11.7 GB (1.53x) |
| Pointer writes, 15 min | 7.1 GB | as above | 3.95 M/s | below 2 us | 1 | 1.64 ms | 1.64 ms | 9.4 GB (1.33x) |

What these show:

- The worst case is not under a millisecond: 1.6 to 3.1 ms in three of four runs, 1 to 5 events in 170 million to
  3.6 billion iterations. The cause of the 1 to 3 ms steps (the collector's own counter shows them) is not known yet.
- The pauses that are common are the throttle. When the program allocates faster than the collector marks, each collector
  step holds the program back for 100 us. In the three big-heap runs the program spent 66 to 73 percent of the run
  in that throttle (217 of 307 s, 201 of 304 s, 261 of 358 s) and ran at 0.6 to 2.8 M/s where the same loop runs at 15
  M/s on a small heap. Between 0.26 and 1.4 percent of iterations were over 100 us in the big runs (0.02 percent in
  the 4 GiB run, which was throttled 8 percent of the time). That is the throughput that buys the small pauses.
- Allocation faster than the collector is answered by throttling, never by a long pause or by letting memory run away.
  Peak memory stayed within 1.07 to 1.53 times the live data.
- No stop-the-world compaction exists: the collector does not move objects, so fragmentation costs memory, not pauses.
  The aged heap needed 1.53 times the live data against 1.07 to 1.12 for the others, and its longest delay was the
  smallest. Pages that are completely empty are given back; partly used ones are not.
- Over the 15 minutes the worst delay of each 30 s interval did not climb: 0.63, 1.64, 0.54 ms for the three thirds of
  the run (median interval 0.32 ms).

Cost against a build that never collects (`alloc_only`, 20 million iterations):

| Request | No collector | Collector | Throughput cost | Peak ÷ live data |
|---|---|---|---|---|
| 1 GiB | 28.10 M/s, 4.36 GB | 13.60 M/s, 2.89 GB (1.85 live) | 52% | 1.56x |
| 2 GiB | 27.67 M/s, 6.09 GB | 12.05 M/s, 4.97 GB (3.38 live) | 56% | 1.47x |
| 4 GiB | 28.35 M/s, 9.41 GB | 12.21 M/s, 7.30 GB (6.28 live) | 57% | 1.16x |

The collector takes more than half of the time of this loop; the loop with no collector is about 2.2 times faster.

Blue threads parked at depth 50 and woken in turn, 1 GiB live data, 40 s:

| Threads | Longest delay | Iterations over 1 ms | Collector's cycle start |
|---|---|---|---|
| 50 (depth 20, 5 s) | 0.70 ms | 0 | 0.20 ms |
| 1,000 | 4.7 ms | 63 | 4.7 ms |
| 5,000 | 21.9 ms | 62 | 21.9 ms |
| 20,000 | 80.1 ms | 58 | 80.0 ms |

The stacks of the threads that are away were scanned in full at the start of every cycle, on the program thread, so the
start grew with their number (about 4 us a thread at this depth). That is fixed: a cycle now scans the running
thread's stack at its start and the stacks of the others in slices (`_blue_scan_step`, 256 KB a step, the same budget
as the `unsafe` buffers). A thread that runs again before the slices reach it is scanned first (`_blue_scan_resumed`),
because it is about to change its stack and the snapshot has to include what the stack holds now. The cycle cannot end
while the slices are on. Same runs after the change (test case 18 fails 3 of 3 without the scan on resume):

| Threads | Longest delay | Iterations over 1 ms | Collector's cycle start |
|---|---|---|---|
| 1,000 | 0.41 ms | 0 | 0.024 ms |
| 5,000 | 0.53 ms | 0 | 0.026 ms |
| 20,000 | 0.45 ms | 0 | 0.025 ms |

There are no safepoints to wait for: the program thread does its own collector steps, and the marker is a separate
thread.


## Replacing the collector: conservative Immix (decided 2026-11-04)

The old collector (size-class pages, one marker, sweep in steps on the program thread) is replaced, not
tuned. Baseline of the old collector, `bench/gc/mutator_utilization.zu <live MiB> 30000000`, one run each:

| Live asked | Real live | Iterations/s | Stopped | p99 stop | Longest | MMU 1 ms | MMU 10 ms | MMU 1 s | Metered p99 | Peak / live | Marker share of CPU |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 256 MiB | 0.48 GB | 5.53 M | 16.6% | 108 us | 1.38 ms | 0% | 5.1% | 80% | 55 ms | 2.40 | 27% |
| 1 GiB | 1.84 GB | 5.90 M | 11.3% | 72 us | 0.58 ms | 6.7% | 10.1% | 74% | 171 ms | 2.22 | 30% |
| 4 GiB | 6.87 GB | 5.14 M | 15.3% | 101 us | 0.54 ms | 3.7% | 7.0% | 31% | 670 ms | 1.61 | 35% |
| 10 GiB | 13.6 GB | 3.21 M | 24.3% | 110 us | 8.45 ms | 0% | 5.9% | 9.7% | 1.92 s | 1.44 | 44% |

Where the program thread's stops went (256 MiB): clearing reused pages 538 ms, throttle spin 160 ms, sweep
steps 148 ms, giving memory back 128 ms, new pages 46 ms. At 1 GiB the throttle spin was first (579 ms).

### Stages

| Stage | Work | Done when |
|---|---|---|
| I | Immix heap and sweep on the GC thread; marking as before (one marker, SATB barrier, throttle) | `make test`, verify mode and the race check pass; the table above is measured again |
| II | Several markers, their number chosen from the measured mark and allocation rates; assists replace the throttle spin | MMU at 1 and 10 ms well above the old values at every size |
| III | Exact heap scanning: an object header with its layout, filled by every allocation site | The heap is scanned by tags; stacks stay conservative |
| IV | String space, opportunistic moving of objects not pointed to from stacks, young generation | Each measured against the stage before |

The old `zue_gc.zu` is deleted in stage I: the new file has the same name and the same entry points, so the
compiler and the rest of the runtime do not change.

### Heap layout (stage I)

| Unit | Size | Notes |
|---|---|---|
| Granule | 16 bytes | Objects start on a granule and take whole granules (request + 1 byte, rounded up) |
| Line | 128 bytes | A line is free when no live object touches it; the allocator also reuses gaps inside live lines |
| Block | 32 KB, 256 lines | Holds normal objects or atomic objects (never scanned), not both |
| Chunk | 2 MB, 64 blocks | Aligned to 2 MB; made ahead by the helper thread as before |
| Medium object | 129 bytes to 8 KB | Bump allocated; one that does not fit the current gap goes to the overflow block |
| Large object | over 8 KB | Its own span of 64 KB pages, as before |

Each chunk has a descriptor (calloc, never scanned) with one bit per granule in four bitmaps (object start,
object end, object mark, object made during the cycle), one byte per line (the epoch of the cycle that last saw
it live, 0 when free), and a few bytes per block (kind, sweep epoch, zeroed, gaps). That is 3.9 percent of the
chunk. The page table maps each 64 KB of address space to a chunk or large-object
descriptor, as before.

A word is a pointer to an object when the page table knows its 64 KB, a start bit is found at or before it in
the same block, and the first end bit after that start is at or after it.

### Allocation

The fast path is a bump: cursor plus size against the end of the gap, then the start and end bits. A gap is
the space from the end of one live object to the start of the next (found in the start bitmap). There is no
clearing per object: a gap is cleared once when it is taken (fresh chunk memory and blocks given back to the
system are already zero). While a cycle marks, each new object also gets its bit in the map of new objects and
its lines get the cycle's epoch, so nothing allocated during the cycle is freed by it. Only the program thread
writes that map. The collector's state holds the cursor and the bytes left in the gap, never the gap's end: the end is often
the start of an object, and the conservative scan of the data segment would keep it alive.

### Sweep

After the marks are final the GC thread sweeps every block that was in use. The program thread can sweep a
block itself when it needs one before the GC thread got to it; a block is claimed under the collector mutex.
Sweeping a block: clear the start and end bits of every object that is neither marked nor new, in every line
(an object that starts in a line that becomes free can end in a live one); then clear the epoch of every free
line; clear the mark bits and the map of new objects; count free lines, and note whether a line that stays live
lost an object (BI_GAPS). A block with no live line goes to the free list, one with free lines or gaps to the
recycle list of its kind. The GC thread then gives back the memory of
free blocks beyond what the pacer expects the program to need before the next cycle (madvise), off the
program thread.

### What stays

Snapshot-at-the-beginning barrier (`lv_wb_cell`, `lv_wb_word`, `lv_wb_range`), the local batch handed to the
GC thread, root ranges scanned in steps, blue thread stacks scanned in steps, `lv_gc_note_external`, the box
hook at the end of marking, `--gc=lowmem`, the pacer's measures, `ZUE_RT_GC_STATS`, `_STRESS`, `_SLOW` and
`_VERIFY`. `lv_gc_is_marked` counts an object made during the cycle as marked.

### Stage I result (measured 2026-11-04, one run each, same benchmark as the baseline)

| Live asked | Iterations/s | Stopped | Stops | p99 stop | Longest | MMU 1 ms | MMU 10 ms | MMU 1 s | Peak | Throttle spin |
|---|---|---|---|---|---|---|---|---|---|---|
| 256 MiB | 4.70 M | 1.1% | 2,704 | 143 us | 0.36 ms | 6.2% | 10.9% | 96.5% | 1.20 GB | 0.20 s |
| 1 GiB | 4.81 M | 3.3% | 4,227 | 101 us | 0.42 ms | 5.7% | 10.0% | 83.3% | 4.80 GB | 0.91 s |
| 4 GiB | 4.60 M | 11.2% | 9,675 | 101 us | 0.62 ms | 3.7% | 10.4% | 32.6% | 13.3 GB | 3.76 s |
| 10 GiB | out of memory while the live heap was built (killed at 19.3 GB on a 23 GB machine) | | | | | | | | | |

Against the old collector: 85 to 90 percent fewer stops and no long stalls, but 10 to 18 percent less
throughput and 4 to 21 percent more memory. Two causes, measured:

- Memory: the benchmark's garbage (the item arrays a growing list leaves behind) lies between live objects in
  the same lines, so nearly every line stays live with about half of its bytes dead. Line reuse alone does not
  get those bytes back.
- Throughput: marking costs more per byte (the bitmap search), so the one marker falls further behind and the
  throttle spins longer.

Two fixes found on the way: the program thread sweeping blocks until it found room took up to 36 ms in one
stop (it now sweeps at most one block per request), and the pacer counted live data in whole lines (2.78 GB
for 1.84 GB of objects), which made it allow a larger heap (it now uses the bytes the cycle marked).

### Step a result (measured 2026-11-04, one run each, same benchmark)

Allocation into the gaps between live objects; an object made during a cycle is marked from birth.

| Live asked | Iterations/s | Stopped | Stops | p99 stop | Longest | MMU 1 ms | MMU 10 ms | MMU 1 s | Peak | Throttle spin |
|---|---|---|---|---|---|---|---|---|---|---|
| 256 MiB | 4.61 M | 2.3% | 4,825 | 101 us | 0.36 ms | 6.3% | 10.5% | 94.7% | 1.01 GB | 0.17 s |
| 1 GiB | 4.70 M | 2.8% | 6,095 | 101 us | 0.43 ms | 6.4% | 10.6% | 87.8% | 4.05 GB | 0.71 s |
| 4 GiB | 4.53 M | 8.4% | 10,839 | 101 us | 0.59 ms | 3.8% | 10.1% | 52.2% | 11.1 GB | 2.94 s |

Peak memory is about 16 percent below stage I and back to the old collector's (1.15, 4.08 and 11.1 GB).
Throughput is about the same as stage I, still 10 to 20 percent below the old collector: that is step b.
The longest stop stays under 0.6 ms. 10 GiB was not run (it needs about 20 GB on a 23 GB machine).

### Stage II result: several markers (measured 2026-11-04, 8 cores / 16 threads)

Marking threads with a mark stack each and a shared pool; a marker gives half its stack away when another
waits. Default 2 markers (4 or more CPUs), `ZUE_RT_GC_MARKERS` to change it. Three runs each with 2 markers,
one with 1:

| Live asked | Markers | Iterations/s | Stopped | Longest | p99 stop | MMU 1 ms | MMU 10 ms | MMU 1 s | Throttle spin | Peak |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 GiB | 1 | 4.82 M | 0.6% | 0.13 ms | 100 us | 7.3% | 49.6% | 98.5% | 0.57 s | 3.99 GB |
| 1 GiB | 2 | 4.86 to 4.87 M | 0.4% | 0.11 to 0.21 ms | 32 to 37 us | 76 to 85% | 91 to 92% | 98.8 to 98.9% | 0.02 to 0.05 s | 3.62 to 3.65 GB |
| 4 GiB | 1 | 5.01 M | 1.5% | 0.22 ms | 101 us | 5.6% | 8.8% | 96.9% | 2.22 s | 11.4 GB |
| 4 GiB | 2 | 4.35 to 4.72 M | 0.1 to 0.3% | 0.08 to 0.22 ms | 70 to 174 us | 76 to 86% | 93 to 97% | 99.4 to 99.6% | 0.02 to 0.12 s | 10.2 to 10.3 GB |

What it gives: the throttle spin is nearly gone and the MMU for short windows goes from under 10 percent to
about 80 percent; peak memory falls 9 to 10 percent (cycles end sooner). What it does not give: throughput.

Throughput, measured round-robin (the builds take turns, so machine drift hits all of them), median
iterations/s:

| Live asked | Old collector | Stage I | Step a | Stage II, 1 marker | Stage II, 2 markers |
|---|---|---|---|---|---|
| 256 MiB | 5.64 M | 4.98 M | 4.85 M | 4.72 M | 4.84 M |
| 1 GiB | 5.91 M | 5.11 M | 4.94 M | 4.84 M | 4.94 M |
| 4 GiB | 5.47 M | 4.90 M | 4.81 M | 4.14 M | 4.18 M |

Every Immix build is 10 to 16 percent slower than the old collector, although the program is stopped far
less (4 GiB: 12 percent of the run with the old collector, 0.4 percent now); that gap is in the program's own
allocation and barrier path. The extra loss of stage II at 4 GiB is a different thing: every slow run had
twice the system time (4 s against 1.9 s) and a lower peak, which is the huge page hint switched off
(`ZUE_RT_GC_CHUNKS` shows "chunks made when the hint went off"). The helper counted the time of the
descriptor's `calloc` (up to 12 ms) as the cost of the chunk, so three slow descriptors switched huge pages
off. It now times only the chunk. After that fix, 3 of 6 runs at 4 GiB were still slow in the same way
(4.08 to 4.37 M against 4.57 to 4.76 M); the cause is not proven yet. The likely one is that the kernel's own
slow chunk mappings switch the hint off, and that rule (three chunks over 1 ms switch it off for good) needs
a better test.

Found on the way, each measured with `ZUE_RT_GC_LOCK` or timing of the step:

- With more than one marker the sweep never ran: the sweep start woke one waiting thread, often not the GC
  thread. All markers are woken now.
- One small allocation searched thousands of recycled blocks with only small gaps (15 ms). The sweep now
  records each block's largest gap and sorts blocks into two lists (step a's flaw; the sweep takes 0.7 s more
  of the GC thread's time at 4 GiB, none of the program's).
- `calloc` of a chunk descriptor on the program thread, with the mutex held, took up to 8 ms while other
  threads allocated. The helper makes the descriptors now.
- A thread woken while the waker held the mutex delayed the waker; a program thread sleeping on the mutex
  waited up to 2.2 ms. Wakes come after the mutex is let go, and the program thread spins for it.

Open: with 4 markers, half the runs still had one stop of 1.5 to 2 ms (the program thread waiting for the
mutex), and 4 GiB throughput fell to 4.1 to 4.7 M. Assists (the program marking instead of the throttle spin)
are not built: with two markers the spin is 1 percent of the run or less.

### Next, in order

| Step | Work |
|---|---|
| a | Done (see above): allocate into the gaps between live objects; an object made during a cycle gets its mark bit at birth instead of a black line |
| b | Done (see above): several markers. Next: measure the program's allocation and barrier path for the throughput gap; assists only if the spin comes back |
| c | Default mode keeps low pauses and high throughput and may use more memory; `--gc=lowmem` keeps low pauses and low memory and gives up throughput |
| d | Stage III, exact heap scanning, then moving the worst blocks in short pauses. Concurrent compaction (a load barrier in generated code and the runtime, about 4,000 to 5,000 lines) only if fragmentation still shows after that |

### Throughput and stops after the program got faster (measured 2026-11-11, 16 threads, 23 GB)

`bench/gc/mutator_utilization.zu <live MiB> 30000000`, normal build, one run each (three at 4 GiB).

| Live asked | Before: iterations/s | Longest stop | After: iterations/s | Longest stop | MMU 1 ms | MMU 10 ms | Peak before | Peak after |
|---|---|---|---|---|---|---|---|---|
| 1 MiB | 7.20 M | 0.79 ms | 13.63 M | 0.22 ms | 75.5% | 96.2% | not kept | 47 MB |
| 256 MiB | 5.37 M | 1.44 ms | 11.88 M | 0.22 ms | 77.8% | 95.6% | 0.97 GB | 1.06 GB |
| 1 GiB | 5.64 M | 0.47 ms | 13.08 M | 0.24 ms | 75.4% | 97.0% | 3.74 GB | 3.75 GB |
| 4 GiB | 5.90 M | 0.19 ms | 12.75 to 12.91 M | 0.22 to 0.31 ms | 61.6 to 76.8% | 94.5 to 96.1% | 11.25 GB | 8.97 to 9.05 GB |

10 GiB was not run: it does not fit this machine. The throttle did not run in any of the runs after.

What was wrong, each found by measuring, in the order found:

| Cause | Evidence | Fix |
|---|---|---|
| The IR names no target, so LLVM took the C library to be missing and made every `memcpy` and `memset` of the runtime a loop over single bytes | `lv_list_of` took 345 instructions for a list of four items, 320 of them the byte loop; the binary had no `memcpy` symbol | `llvm_build.sh` gives `opt` and `llc` the target. List literal loop 47.1 to 19.6 ns, string loop 26.1 to 21.0 ns |
| A local of a function made every outer variable of the same spelling a captured cell | The benchmark's top-level `i` was a heap cell, made new at every iteration, because `mmu()` has its own `i`: twice the calls of `_gc_alloc` against the same loop in a file without such functions | `analysis.zu` gives a function its free names only. 256 MiB: 6.50 M to 11.92 M iterations/s |
| One `munmap` of a dead 64 MB large object held the kernel's lock on the address space for 5.4 ms | `strace -T`: the GC thread's `munmap` and the program thread's `mmap`, waiting, ended in the same microsecond | Large objects are unmapped 2 MB at a time. 4 GiB longest stop 9.5 to 13.8 ms, then 1.1 ms |
| A chunk the program thread made itself waited in the kernel while the helper's huge page took 5 to 8 ms | `ZUE_RT_GC_OWN_CHUNK`: 5.1 ms, all of it the mapping; then, with the mapping gone, 1.47 ms in `calloc` of the descriptor | A reserve of ready chunks that grows with the heap, and an arena of address space and descriptors from which a chunk is cut without a call into the kernel. Longest stop 0.30 to 0.51 ms at every size |
| Three slow huge pages switched the hint off for the rest of the run | Runs with "chunks made when the hint went off" were 15 to 25 percent slower (4 GiB: 7.1 to 7.5 M) | The hint goes off only after three chunks the program made itself. 4 GiB: 9.6 to 10.0 M |
| The program was held back at the pacer's goal although memory was free | 4 GiB: 2,900 to 4,400 holds of 100 microseconds in the loop, the same with 3, 4 and 6 markers | Default mode holds back only at the machine's memory limit; `--gc=lowmem` at the goal. 4 GiB: 12.75 to 12.91 M, peak 9.0 GB |

One guess was wrong and was taken back before the cause was measured: that the 5 ms stop was the huge page
hint on the program thread's own chunk (switching it off there changed nothing, tried twice).

`--gc=lowmem`, same benchmark, one run each:

| Live asked | Iterations/s | Peak | Peak in default mode | Held back | Longest stop |
|---|---|---|---|---|---|
| 256 MiB | 3.71 M | 0.38 GB | 1.06 GB | 60.9% of the run | 1.12 ms |
| 1 GiB | 3.90 M | 1.55 GB | 3.75 GB | 54.9% | 1.03 ms |
| 4 GiB | 3.62 M | 6.16 GB | 9.0 GB | 61.2% | 1.23 ms |

Open in lowmem: more than half of the run is the hold-back spin, and each run had one stop just over a
millisecond that the collector's own counters do not show (longest pause 0.14 to 0.36 ms, longest wait for the
mutex 0.08 ms).

Assists were tried and taken out (2026-11-11): the program thread marked from the pool for the 100 microseconds
of each hold. Holds and throughput did not change (256 MiB 3.60 M, 1 GiB 3.51 M, 4 GiB 3.33 M). The reason,
measured at 1 GiB in lowmem with 1, 2, 4 and 8 markers: 3.35, 3.57, 3.35 and 2.84 M iterations/s, while the
markers' CPU time went from 11.2 to 15.7, 20.3 and 25.8 s. More marking threads do not shorten a cycle on this
heap, so one more (the program) does not either. Not yet measured: why. The likely cause is the heap's shape,
one list of 5 million rows: its items are one mark item that stays on one marker's stack, and a marker gives
away half of its items, not half of a large one. With 8 markers there were stops of 2 to 3 ms.

Checked: `make test` (1174), the suite under `ZUE_RT_GC_VERIFY=1`, the GC and blue thread tests under
`ZUE_RT_GC_STRESS=7 ZUE_RT_GC_SLOW=50 ZUE_RT_GC_VERIFY=1`, `tools/gc_race_check.sh`, round-trip, verify-ir, fuzz,
codes-check. The capture change was not mutation-tested; `test_capture_scopes.zu` (9 cases) gives the same
output with the compiler before the change.

## Zue 2: types, immutability and memory (plan, 2026-11-04; phases 1 to 4 done 2026-11-06)

The language changes after the collector work. The aim: every type known when the program is built, values
that cannot change unless they say so, conversions with one clear meaning, named arguments, and memory that
is freed exactly, with no double free, no two names changing one value and no cycles. The language stays
simple: no generics syntax, no classes or interfaces, no `?` types or operators.

### Decided by the owner

| Topic | Decision |
|---|---|
| Changing a variable | `let a = ...` never changes; `let mut a = ...` may |
| How deep | Deep: nothing reachable through a `let` changes, not its items, not its fields. `let mut b = a` gives `b` its own value |
| Loops | `for (let mut i = 0; i < n; i++)` stays; `for (let x in xs)` gives a fresh `x` each round |
| Conversions | `x as T` and `T(x)` both valid, with the same strict meaning |
| A conversion that may fail | `let n = s as int else { ...; return }`, or `if (let n = s as int) { ... } else { ... }` |
| Named arguments | `greet("Ann", greeting: "Hi")`, `range(0, 10, step: 2)` |
| Anything that may be missing | `else` and `if (let ...)` work for every value that may be missing: a conversion, a map key, `find`, `open`, a template field that may be empty |
| Reusable templates | No generics syntax: a field without a type takes the type of the value the template is made with (`Stack([1])` holds ints, `Stack(["a"])` strings), as untyped parameters do per call |
| One of several kinds | One template with a `kind` field that holds the fields of every kind (no union types) |
| Left out, to keep the language simple | Generics syntax, union types, classes and interfaces, `?` types and operators (`int?`, `as?`, `??`, `?.`), enums with `match`, errors as values (`try`, `catch`), distinct types, method syntax, tuples, destructuring, short closures |

### Taken as the default until the owner says otherwise

| Topic | Default | Why |
|---|---|---|
| Types on functions | Optional. A typed parameter is checked against its type; an untyped one takes the type of the argument at each call, and the body is checked for those types (as the checker does today). The result type is inferred | Every type is still known when the program is built, and one function works for a list of ints and a list of strings without generics syntax |
| Unknown types | None: a value whose type cannot be told is a compile error (strict mode today becomes the rule) | `any` is what keeps types unknown today |
| `null` | A typed value is never `null`. Something that may be missing is handled where it happens, with `else` or `if (let ...)` | No `?` types needed |
| Shadowing | Allowed with `let` only: `let age = age as int` declares a new `age` | Conversions read naturally and no variable needs `mut` for them |
| Failures that are bugs | Overflow, index out of range, a failed `as` without `else`: the program stops, as today | A bug should not be ignored |

### What exists to build on

| Exists | Where |
|---|---|
| Type annotations on variables, parameters and fields; `list<T>`, `map<T>`, templates, blocs | `check.zu`, docs/syntax.md "Type checking" |
| Per-call checking of untyped parameters | `check.zu` (MEMO, per list of argument types) |
| Strict mode per file (`# strict`): unknown values are errors | `check.zu`; becomes the rule in phase 3 |
| Raw values: an int, float or bool local the checker proves is kept as a machine value | `ll_typed.zu` |
| Number literals that adapt (`sqrt(16)`) | `check.zu` (`int~`, `float~`) |
| Default parameters (`func greet(name, greeting = "Hello")`) | parser, `emit_llvm.zu`; named arguments build on them |

### Phase 1: conversions (done)

Done as below, with one difference: `int(p)` stays the pointer cast (no `address(p)`), and `to_int` and
`to_float` stayed as older names of `int` and `float` until 2026-11-05, when they were removed (using one
is an error that says what to write). Templates typed per value (from phase 4) are done too.

`x as T` and `T(x)` succeed only when the value means exactly the same as a `T`. Anything else is an error,
and a compile error when the checker can see it can never work (`[1] as int`).

| From, to | Result |
|---|---|
| int to float | `5 as float` is 5.0; an int above 2^53 that has no exact float is an error |
| float to int | Only a whole float: `3.0 as int` is 3; `3.5 as int` is an error naming `round`, `floor`, `ceil` and `trunc` |
| Rounding | `round(x)`, `floor(x)`, `ceil(x)`, `trunc(x)` give an int; the rounding is in the name |
| string to int or float | The whole text must be the number: `"42" as int` is 42, `"4x" as int` is an error naming the text |
| any value to string | `x as string` or `string(x)`; formatting with options stays a function (`fixed`, `to_string(x, digits)`) |
| char and int | `code(c)` and `char(n)`; `c as int` is an error (a char is not a number) |
| bool to int | Removed; write an `if` |
| pointer to int | `address(p)`, inside `unsafe` |

When a conversion may fail, the program says what happens instead of stopping:

```javascript
let age = input("age? ") as int else {     // the block must leave: return, break or continue
    print("please type a number")
    return
}

if (let n = input("n? ") as int) {         // n exists only here, and is an int
    print(n * 2)
} else {
    print("not a number")
}
```

`int(x)` and `float(x)` keep their names with the strict meaning (`int(3.7)` becomes an error: write
`trunc(3.7)`). `to_int(s)` and `to_float(s)` go: they are `s as int` and `s as float`. The old forms stay one
release with a message saying what to write.

### Phase 2: everything that may be missing (done)

Done as below, with these additions: a list or string index out of range (`xs[i]`) and `last_index_of`
are missing values too, a value that is `null` counts as missing (a map key holding `null` as well as
an empty field), and a function of the program's own named `find` or `open` counts `null` as missing.

`else` and `if (let ...)` from phase 1 also take: a map read (`m[k]`), `find`, `index_of`, `open`, and a template
field that may be empty. A field may be empty when the template was made without it or it was set to
`null`; reading it without `if (let ...)` or `else` stops the program when it is empty, as today.

```javascript
if (let v = m["key"]) { print(v) } else { print("no key") }
let f = open("data.txt") else { print("no file"); return }
if (let l = node.left) { walk(l) }
```

### Phase 3: named arguments (done)

Done as below, with these choices: named arguments go in the order of the parameters (so they run in the
order they are written; this can be relaxed later without breaking programs), a parameter with a default
can be left out before a named one (the call passes an absent value, a null with payload 1, and the
function uses its default), template and bloc fields take names, and the callee must be known when the
program is built (a function declared with func here or in an imported file and never assigned, a
template, or a builtin). Builtins that take different argument lists (`min`, `max`, `rand`, `trand`,
`slice`, `contains`), any number (`print`, `spawn`) or work inside `unsafe` take no names. `default` is a
keyword, so `map_get`'s third parameter is named `fallback`. The pass is `compiler/named_args.zu`, run
before the checker; errors are `E0125`.

| Rule | Example |
|---|---|
| Any parameter can be named at the call | `greet("Ann", greeting: "Hi")` |
| Named ones come after the positional ones | `greet(greeting: "Hi", "Ann")` is an error |
| Each parameter is given once | `greet("Ann", name: "Bo")` is an error |
| An unknown name is a compile error that lists the names | `greet("Ann", greting: "Hi")`: `greet has no parameter 'greting' (name, greeting)` |
| Builtins have names too | `range(0, 10, step: 2)`, `to_string(x, digits: 3)`, `split(s, sep: ",")` |

### Phase 4: every type known when the program is built

| Rule | Example |
|---|---|
| Locals are inferred | `let n = 5` is an int, `let xs = [1.5]` a `list<float>` |
| Parameter types may be written | `func area(w: float, h: float)`; untyped ones are checked per call |
| A result type may be written | `func area(w: float, h: float) -> float` |
| No unknown types | A value the checker cannot tell is a compile error where its type matters |
| Mixed lists stay (owner, 2026-11-05) | `["Ann", 30, true]` is allowed; an item read from it has no type until it is converted: `person[1] as int` (or `as int else { ... }`). `person[1] + 1` is a compile error that says to convert first. A list of one type keeps its element type |
| Types cross files | A function, template or constant brought in with `use` keeps its types; a call of an imported function is checked for its argument types in its own file's context; each error names its file |
| An empty list needs its type | `let xs: list<int> = []` |
| Typed values are never `null` | `let x: int = null` is an error (as today) |

The checker becomes flow-sensitive where it matters for `if (let ...)` and `else` (a name exists only where
the conversion worked). Strict mode is made the rule file by file, the compiler's own files first.

A template field without a type takes the type of the value it is made with, per value: `Stack([1])` and
`Stack(["a"])` are both Stacks, one of ints and one of strings, and each is checked as such. Values of one
template with different field types can be mixed only where the field is not used.

The compiler keeps nodes of different templates in one list (a block's statements). With no unknown types
and no union types, they become one `Node` template with a `kind` field and the fields of every kind.

Steps, each its own commit:

| Step | Work | State |
|---|---|---|
| 1 | Types cross files: the checker checks each imported file in its own context and calls of its exported functions per argument types | Done 2026-11-05 |
| 2a | Strict mode follows the rule for parameters: an untyped parameter of a named function is checked per call, so only function values need typed parameters; the pass with unknown parameters reports only proven errors. Parsing and the named-argument pass stop only on their own errors, so the checker reports errors in every imported file | Done 2026-11-06 |
| 2b | The checker infers more by itself: a list that starts empty takes its first appended type (another type makes it mixed); a `type(x)` test leaves out the branch that cannot run; recursive functions returning a template (or null); builtin results (`args`, `read`, `map_get`, ...). `zue check --list-types` prints the element type of lists that start empty | Done 2026-11-06 |
| 3 | Result types may be written: `func area(w: float, h: float) -> float`; checked at every return and on every path (E0212); a call has that type | Done 2026-11-06 |
| 4a | A typed template field may be empty (null) | Done 2026-11-06 |
| 4 | One `Node` template in the compiler, 63 typed fields; literal values kept as text; places kept as `Span` | Done 2026-11-06 |
| 5 | The compiler's files pass strict mode, small files first, a seed after each group | Done 2026-11-06 (5a to 5i): 3,285 unknown uses to 0 |
| 6 | Strict is the rule; mixed-list items need `as`. Tests that hide a type to reach a run-time error (`[v, null][0]`) become compile-error tests, or get their value from `input()` where the run-time check itself is what is tested | Done 2026-11-06, with a change: those tests keep the run-time checks covered with the test-only switch `zue --no-strict` (line `# test: no-strict`), because the runner has no input and the runtime's own checks still guard values the checker cannot see |

Step 5 typed the compiler's own code: maps and mixed lists used as records became templates (Module, Var,
Ctx, Token, Diag, Scope, Call, Ref, SpecEntry, NState and others), the tree walkers became typed walks over
`Node`, and every function got typed parameters. On the way the checker learned what the typed code needed
(each change with its own seed): an empty value of a template type anywhere a field of that type may be
empty; types of an imported file read in that file and kept for the whole compilation; a function returning
a string, list, map or function value, or null, keeps that type; narrowing after `if (type(x) == ...) {
return }` and after `if (x == null) { return }`; function bodies checked after the rest of their block;
`m.key` on a map; `open()` gives a file. It found real mistakes: a bool parameter that held 0 or 1, a list
annotated `list<map>` that also held strings, a switch that pushed a loop with a null label.

Step 6 made strict the rule and added what ordinary programs need under it: result types for every builtin
(new type names `pointer`, `channel`, `thread`, `file`), `x as int` of a value of unknown type, maps that
start empty taking their value type, `alloc` of a template keeping the template's type, a box's `len`,
`cap` and bytes, pointer ordering and `int(p)`, untyped bloc fields typed per value like a template's,
`slice` and `reverse` of a string, `exit` ending a path, a return inside `unsafe { }`, a recursive function
checked once more when its result type is settled, and no second "type not known" error for a value whose
expression already had one. Values the checker cannot know (`recv`, `wait`, `load`, `reduce`, the result of
a function value, an item of a mixed list) are given their type where they are taken: `let n: int = recv(ch)`
or `xs[1] as int`.

Later improvements found on the way: typed channels and threads (`channel<int>`, `thread<int>`, so `recv`
and `wait` need no written type); function types (`func(int) -> string`), so a function value's result is
known; parameters of a function value passed straight to `map`, `filter` or `reduce` taken from the list's
element type; whole-file imports (`use "x.zu"`) keeping typo checks (the explicit `use { a } from` list is
the standard for now).

Step 4 uses one wide `Node`: a field for every field of every kind (63), the unused ones empty. It keeps the
compiler's code as it reads today (`n.cond`, `n.target`). Its cost is memory: every field is a 16-byte value,
also when empty. Measured: compiling the compiler went from 151 MB to about 205 MB of memory and from 0.85 s to about 0.92 s.
The count of unknown uses went only from 3,418 to 3,303: the nodes have one type now, but the lists that hold
them are made empty (`let stmts = []`), so their items are unknown. Typed empty lists are step 2b.

Possible improvement later, a compact node as in Zig's compiler: every node has only a kind, the place of its
main token and two small slots (`lhs`, `rhs`) whose meaning depends on the kind; a node with more parts keeps
them in one shared list (`extra_data`), and nodes live in one array and point to each other by index. It
uses far less memory and is faster to walk, but the code reads `n.lhs` where it reads `n.cond` now, so it
needs a reading function per kind and part. A middle way is about 25 to 30 fields shared by kinds of close
meaning. Sources: Zig's `lib/std/zig/Ast.zig` (github.com/ziglang/zig), the Ziggit thread "What is the state
of AST processing?", r/ProgrammingLanguages "Flat AST and state machines over recursion" (claims Zig's
compiler went from about 10 GB to 3 GB; not confirmed). Phase 7 (8-byte ints and floats) shrinks every
value, so it is measured first.

Measured after 2a, with `# strict` in every compiler file and the compiler checked from `zuec.zu`: 3,418 uses
of a value of unknown type. 1,775 are field reads, most on syntax-tree nodes of mixed kinds (step 4); the
rest follow from them (a node's kind, its name) or from builtins and fields whose type is not known (2b).

Step 1 found two calls of `die` in `emit_llvm.zu` with one argument instead of three (they would have
crashed instead of reporting an internal error); they are fixed.

### Before phase 5 (owner, 2026-11-06)

Phase 5 is not started until its options are discussed: how `let`/`let mut` treats parameters, loops,
closures, fields and collections, and what other languages chose.

### Core data kinds (owner, 2026-11-06; after phase 6)

`data` is removed (an untyped template does the same). `bloc` and `box` stay for programs that need an exact
layout or raw memory. Four core kinds, with the compiler as their first user:

| Kind | What it is | First use in the compiler |
|---|---|---|
| `template` | The ordinary record | Everything today |
| `table` | Struct of arrays: each field a packed column, whole-column operations with SIMD (Odin `#soa`, Zig MultiArrayList) | The syntax tree, instead of the 65-field Node (replaces the compact-node idea above) |
| `history` | Versioned values with snapshots and undo, sharing what did not change (persistent structures as in Clojure) | The checker's assume-and-roll-back (Log, MarkEntry) |
| `decimal` | Exact decimal numbers for money | Users and examples, not the compiler |

Order: `table`, `history`, `decimal`. They depend on value semantics, so they come after phase 6.

### Phase 5: immutability

| Rule | Example |
|---|---|
| `let` never changes | `let xs = [1]` then `append(xs, 2)`, `xs[0] = 5` or `xs = []` is a compile error |
| `let mut` may | `let mut xs = [1]`, then `append(xs, 2)` |
| Fields follow the variable | `let p = Player(...)`: `p.hp = 1` is an error; with `let mut p` it is allowed |
| Parameters do not change | `func f(xs: list<int>)` cannot change `xs`; `func f(mut xs: list<int>)` changes the caller's variable, and the call says so: `f(mut xs)` |
| One change at a time | While `xs` is passed as `mut`, the function cannot reach it another way |
| Closures | Capture a copy; a closure cannot change an outer `let mut` |
| `const` | A value known when the program is built: `const MAX = 100` |

Until phase 6 makes copies automatic, `let mut b = a` with a list, map or template `a` is written
`let mut b = copy(a)`, so a `let` value can never be changed through a second name.

### Phase 6: values and memory

| Rule | What it gives |
|---|---|
| Assignment copies: `let mut b = a` is a new value | No two names change one value |
| Copy on write underneath: a count per object, and a copy only when a shared object is about to change; a value with one owner changes in place | Copies cost nothing until they are needed |
| The last use of a variable hands its value over without a copy (found by the compiler, no keyword) | No cost for values that are passed on |
| Values hold values, never references to variables | Cycles cannot be built, so counting frees everything exactly; graphs use ids (indexes into a list) |
| `unsafe`: `free(p)` uses up `p`, and an `alloc` must be freed exactly once on every path | Double free and use after free are compile errors |
| Files and boxes are freed or closed when their owner ends | `defer(close(f))` is not needed |

The tracing collector is then needed only for what counting cannot see; how much of it stays is decided when
phase 6 is measured.

### Phase 7: speed

Typed ints and floats as 8-byte machine values everywhere, not 16-byte cells.

### Order and steps

The compiler compiles itself, so every phase goes the same way: (1) the compiler accepts the new form and the
old one still works, (2) `make seed`, (3) the compiler's own source moves to the new form, (4) `make seed`,
(5) the old form becomes an error, tests are re-recorded on purpose, docs and error codes are updated, (6) a
commit with all checks passing. A broken step goes back one commit.

| Phase | Work | Size | Risk |
|---|---|---|---|
| 1 | Conversions: `as`, `T(x)`, `else`, `if (let ...)`, named rounding | Small | Low |
| 2 | `else` and `if (let ...)` for map reads, `find`, `open` and empty fields | Small | Low |
| 3 | Named arguments, for user functions and builtins | Small | Low |
| 4 | Every type known; templates typed per value; one `Node` template in the compiler; strict mode as the rule | Largest | Medium: the compiler must check itself at each step |
| 5 | `let` and `let mut`, `mut` parameters, shadowing; the compiler's 1,803 `let`s reviewed (a tool adds `mut` where the checker says) | Small to medium | Low |
| 6 | Copying values with copy on write, no cycles, exact freeing, `unsafe` pointers checked when built; the collector reduced | Large | High: changes what programs mean |
| 7 | 8-byte ints and floats | Large | Medium |

A tool `zue migrate file.zu` rewrites old programs where the change is mechanical (adds `mut`, rewrites
`int(x)` of a float as `trunc(x)`, `to_int(s)` as `s as int`), so user programs and the examples move with
the language.

Each phase is tested the usual way: a test file per feature with `# CASE` sections (and error cases with
their messages), `make test`, `ZUE_RT_GC_VERIFY=1`, round-trip, fuzzers, `verify-ir`, `codes-check`, and
`ast_unparse.zu` and `ast_dump.zu` taught each new form.

### Sources

Conversions: [Rust casts](https://cppcheatsheet.readthedocs.io/en/latest/notes/rust/rust_casting.html),
[Swift Int(exactly:)](https://developer.apple.com/documentation/swift/int/init(exactly:)-7qdwf.md),
[Go constants](https://go101.org/article/constants-and-variables.html). Static typing:
[HM or bidirectional](https://thunderseethe.dev/posts/how-to-choose-between-hm-and-bidir),
[flow typing](https://www.wikipedia.org/wiki/Flow-sensitive_typing). Memory:
[Hylo](https://github.com/hylo-lang/hylo-lang.github.io/blob/main/index.md),
[Swift exclusivity](https://github.com/apple/swift-evolution/blob/master/proposals/0176-enforce-exclusive-access-to-memory.md),
[Perceus](https://www.microsoft.com/en-us/research/publication/perceus-garbage-free-reference-counting-with-reuse/),
[Nim move on last use](https://nim-lang.org/docs/destructors.html).
