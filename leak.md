# Runtime leaks found and fixed (2026-11-02)

Two leaks were found by long-run tests. Both are fixed: the page leak in commit 75efd29, the unsafe-memory leak in
commit 34897d5.

# 1. The page leak in the collector

## Summary

A program with a constant amount of live data grew its resident memory for as long as it ran. No Zue
object was kept alive. What grew was the collector's own bookkeeping for pages it had already emptied.
The leak was in every commit checked, including 4c51431 (before the work of 2026-11-01).

## What was measured

Program: `bench/gc/live_heap.zu`, 256 MiB live, only the number of churn iterations changes. Each run
is one process.

| Churn | Peak RSS before the fix | Pages tracked before | Peak RSS after | Pages tracked after |
|---|---|---|---|---|
| 50 million | 1008 MiB | 50,514 | 997 MiB | 15,708 |
| 200 million | 1265 MiB | 179,904 | 1030 MiB | 16,059 |
| 600 million | 2088 MiB | 585,683 | 1010 MiB | 15,732 |

With a 16 MiB live heap, 160 million allocations: 380 MiB before, 80 MiB after. The 45-second bisect over
the commits of the session (4c51431, d14a4d3, 7acbe92, f61e0ab, 810bf97) showed the same climb in all of
them, so it is not a regression of that session.

## Cause

Memory is cut into 64 KB pages. A page whose objects are all dead goes to a pool of empty pages and can
be reused for any size class. Two functions matter:

- `_new_small_page` takes a pooled page only when `H_MARKING == 0`. While a cycle marks, the GC thread may
  read the page table and the page's mark map, so reusing (and re-initializing) a pooled page then could
  free a map the GC thread is reading. The guard is correct.
- `_pool_trim` gives the memory of old pooled pages back with `madvise`, but keeps them in the pool, with
  their descriptor, their two maps (up to 8 KB for the smallest size class), their page table entry and
  their address range.

With a large heap a cycle is marking for much of the time, so the allocator makes new pages (new
descriptor, new maps, memory from a new chunk) while the pool collects emptied ones. The pool is used
from the top and the cold pages sit at the bottom, so they are almost never taken. Nothing freed them, so
the count of pages tracked grew with the number of allocations: about 2.7 bytes of bookkeeping per
allocation, which is why it took hundreds of millions of allocations to show.

Experiment that confirmed it: with the guard removed (unsafe, only to test the cause) the page count stayed
at about 13,300 and the peak RSS at about 905 MiB for 50, 200 and 600 million iterations.

## Fix (`compiler/runtime/zue_gc.zu`)

`_pool_retire`, called from `_pool_trim`. When no cycle is marking, it takes the oldest cold pooled pages
beyond a quarter of the pages kept ready and, for each: removes its page table entry, frees its two maps,
unmaps its 64 KB, marks the descriptor retired (`PG_IN_LIST == 3`) and removes it from the pool. The
descriptor stays in the list of all pages until the next sweep, which drops it (`_sweep_page`) without a
separate pass over the list. `_census` skips retired pages. `_pool_pending` reports retire work as pending
so the steps keep coming. At most 64 pages and about 20 microseconds per step.

Why this is safe: it runs only with `H_MARKING == 0`, when the GC thread is idle and nothing but the program
thread reads the page table or the maps; the same condition the allocator guard already uses.

Side effect: the pacer estimates the heap it holds from the number of pages tracked. That number was
inflated by the leak and is now accurate.

## Test

`test/test_gc_recycle.zu`, case "a heap of constant size does not grow while the program keeps
allocating": 16 MiB live, 16 million allocations, then 48 million more, and the peak must not grow by more
than a third (plus 10 MiB). Fails 3 of 3 on the old collector, passes 3 of 3 with the fix.

Verification of the fix: 841 tests pass, 340 stress passes (stress 1, 3, 7, 25, with and without the
verifier), the thread-sanitizer race check shows only the expected races.

## Why it was not caught

The collector's tests checked three properties: no live object is freed (stress and verify modes), pauses
are short, and memory falls after a large structure is dropped. None checked that the collector's own
bookkeeping stays bounded over a long run. The language rules (types, overflow, unsafe) govern programs, not
the runtime library. This is a known class of bug in concurrent collectors that keep metadata for pages.

## Improvements: done and still to do

Done (commit 34897d5):
1. A long-run test for every resource the runtime owns: `test/test_resource_bounds.zu`, nine cases (strings, maps,
   large objects, boxes, unsafe memory, threads, channels, closures, dense lists). Each checks that the peak
   resident memory does not keep growing.
2. In verify mode (`ZUE_RT_GC_VERIFY=1`) the collector checks, at the end of each cycle, that nothing is left to
   scan; after each sweep, that the pool of empty pages is consistent; when a page is given up, that no cycle is
   marking; and when a given-up page is dropped, that the page table no longer points to it. Mutations M10 (pages
   stay in the pool), M11 (pages given up while a cycle marks) and M12 (page table entry not cleared) are caught.

Still to do:
3. A memory-trend check on the benchmarks: flag any benchmark whose resident memory keeps climbing after warm-up.
4. A written list of every resource the runtime owns, what bounds it, and which test proves it.

Resources not yet audited: the mark stack and the pool array (they grow and never shrink), the second-level tables
of the page table (never freed). The box table, channels, closures, threads, large-object spans, strings, maps and
dense lists are covered by `test_resource_bounds.zu` and showed no growth.

## Mutation M8: an equivalent mutant, not a test gap

M8 removes the check that the shared mark queue is empty before a cycle ends. No test catches it, and none can:
the GC thread reports idle (state 2) only after it has taken everything from the shared queue, and any hand-over
of new work under the lock switches it out of state 2 first, so the check is always true. 72 runs under verify,
slow-GC and stress modes never saw the invariant broken. The check stays as defence in depth.

# 2. The unsafe-memory leak

Program: a loop of `unsafe { let p = alloc(64); store(p, i); free(p) }`, nothing live.

| alloc/free pairs | Peak RSS before the fix | After |
|---|---|---|
| 200,000 | 30 MiB | 4 MiB |
| 800,000 | 108 MiB | 4 MiB |
| 1,600,000 | 211 MiB | 4 MiB |

Cause: every `alloc()` appends a 56-byte pointer record (`g_ptrs`), an entry in the pointer index (`g_ptr_map`)
and a flags array (`calloc(cells, 1)`). `free` marks the record freed but nothing ever removes it, and the flags
array is never freed. About 130 bytes per alloc, for the life of the program. The rules table in
`zue_rt_rules.zu` reuses an entry when an address returns and was not affected.

Fix (`zue_rt_data.zu`): `_drop_pointer_records`, called when the outermost unsafe block ends. It frees the flags
array of each allocation, clears the index and frees the record array. This is safe because no pointer can outlive
its block (rule R2) and every alloc() is freed by then (rule R10), so nothing refers to the records afterwards.

Known limit: records are kept until the outermost block ends. A single very long unsafe block that allocates and
frees without end still grows until it ends. Fixing that needs the flags array to be freed at `free`, which
needs a check that no alias record still points to it.

Test: `test_resource_bounds.zu`, case "unsafe memory allocated and freed does not grow the peak". It showed
`grew: true` before the fix.

# Soak result after both fixes

Constant live heap, nonstop churn, resident memory sampled every 5 seconds. The memory goes up and down with each
cycle (a sawtooth) and does not climb. 1 GiB: 4.27 billion allocations in 300 s, 2.7 to 3.5 GiB. 4 GiB: 4.22
billion allocations, 11.4 to 14.0 GiB, with the peaks rising from 13.1 to 13.8 GiB over the 5 minutes while the
troughs stayed flat; a longer soak is needed to say whether that levels off.
