# Garbage Collector

Every compiled Zue program carries a garbage collector. It is part of the runtime, written in
Zue: `compiler/runtime/zue_gc.zu`. It is a conservative, non-moving mark-and-sweep collector with a
write barrier (named Hush in [plan](plan.md)). By default a GC thread marks while the program runs. It does not need type maps from the
compiler: it treats every aligned word it scans as a possible pointer.

## Memory domains

| Domain | Holds | Lifetime |
|---|---|---|
| GC heap | strings, lists, dense lists, maps, closures and their captured cells, templates, blocs | traced and freed by the collector |
| Box table | `box` buffers | freed when their scope ends, by `free`, or with their owning template |
| `alloc()` buffers | raw memory from `unsafe` blocks | freed by `free` / `defer`; registered as root ranges, never freed by the collector |

## Heap layout

- **Small objects** (up to 32752 bytes) are served from 64 KB pages. A page holds objects of one
  size class; there are 31 classes from 16 to 32752 bytes. The five largest hold 6, 5, 4, 3 and 2 objects per page. A page keeps a bump index for objects
  never handed out and a free list of recycled ones.
- **Atomic objects** (strings, doubles, byte buffers, dense list data) are allocated from
  separate pages and are never scanned for pointers.
- **Large objects** (over 32752 bytes) get a span of their own: whole 64 KB pages mapped with `mmap`,
  which the kernel zeroes, and touched only when used. A freed span goes into a cache of at most
  `g_threshold` bytes of touched memory and is reused (and cleared) by the next large allocation; a
  cached span that no allocation used during a whole collection is returned with `munmap`. The
  used and mark bytes of a large object sit at the end of its descriptor, and the descriptor and
  its page table entries are freed with it.
- Small-object pages are cut from 2 MB chunks of anonymous memory that the kernel zeroes, and each
  chunk is marked as a candidate for huge pages. That means far fewer page faults than one
  allocation per page. A page that was emptied and reused is cleared again.
- A page table (two levels, indexed by bits 32 to 47 and 16 to 31 of the address) answers "is this
  word a pointer into the heap, and to which object?" with two loads. The object index inside a page
  is found with a multiply by a per-page reciprocal, not a division. Interior pointers keep an object alive. Every allocation is one
  byte larger than requested, so a pointer just past the end still points inside the object.
- New memory is zeroed: fresh pages come zeroed from the kernel, and a recycled object is cleared
  when it is handed out again.
- A page whose objects are all dead is returned to a pool and can be reused for any size class.

## Collection

A collection is triggered inside an allocation. It happens when the bytes allocated since the
last collection exceed a threshold: 16 MiB at the start, then the value the pacer works out (see
"The pacer"). (With `ZUE_RT_GC_STRESS`, see below, also every Nth allocation.)

1. **Roots.** The data segment (all module-level variables and constants of the program and the
   runtime), every registered root range (the `alloc()` buffers), the machine stack of the
   thread running the program, and the registers (spilled to the stack first) are scanned. The stacks
   of the blue threads that are away are scanned too, from the stack pointer saved when they gave up
   the processor, and so are the registers they saved (kept in a ucontext object on the heap).
2. **Mark.** Each scanned word that points into a live object marks it, and the object's
   contents are scanned in turn, using an explicit mark stack. Atomic objects are marked but
   not scanned.
3. **Data hook.** Boxes owned by templates that were not marked are freed.
4. **Sweep.** Unmarked objects go back to their page's free list. Empty pages go to the pool.

Because the collector is conservative, a stale integer that looks like an address can keep an
object alive longer than needed. It can never free a live object, as long as every pointer is
kept in a scanned location (the stack, registers, the data segment, a registered range, or a
reachable heap object).

Only one thread runs Zue code. By default one more thread, the GC thread, does the marking (see
[Threads](#threads)); the sweep runs in short steps on the program's thread.

## The pacer

There is one collector and no options for it. A GC thread marks while the program runs, and the program
sweeps in short steps. When to start a cycle, and how much the program may allocate before it is held
back, are worked out at the end of every cycle from what was measured, not from fixed percentages.

| Step | What the pacer does |
|---|---|
| Measure | The allocation rate of the program (bytes per millisecond between two cycle ends) and the cost of a cycle (nanoseconds from its start to the end of its sweep, per MiB of live data). Each is averaged with the last value |
| Estimate | `a`, the bytes the program will allocate during the next cycle: rate times the cycle time for the live size |
| Goal | Twice `a`, but at least 32 MiB, at most the live size (or 32 MiB for a small heap), and at most half of the free memory of the machine (`sysconf`) |
| Start | The next cycle starts when the goal minus `a` has been allocated, at least 16 MiB |
| Hold back | While a cycle runs, the program is slowed down in 100 microsecond steps only once the bytes allocated since the last cycle end pass the goal |

A slow marker therefore starts earlier and a fast one later, and a large heap gets only the room it needs.
The numbers that remain are the factor 2, the half of free memory and the 16 MiB floor. The memory limit
set by `ulimit -v` is not read yet.

## How a cycle runs

The GC thread marks and the program thread sweeps in short steps. A cycle works like this:

1. **Start.** The program thread marks the data segment (without `lv_frames`, which never holds heap
   pointers) and its own stack and registers. This is the snapshot. It takes about 25 microseconds,
   whatever the size of the `unsafe` buffers. It then wakes the GC thread. The root ranges (the `alloc()`
   buffers) are part of the snapshot too, but they are scanned in slices of 256 KB, one slice per
   collector step on the program thread, and the cycle cannot end before the last slice. A store into a
   buffer shades the value it overwrites (the barrier in `_cp`). A buffer that is freed, or moved in the
   table of ranges, before its scan reached it is scanned to the end first.
2. **Marking.** The GC thread scans from its mark stack while the program keeps running. New objects are
   allocated already marked, so they survive the cycle. Pages that are empty are not reused for new
   objects while a cycle marks.
3. **Write barrier.** While a cycle marks, any code that is about to overwrite a pointer inside a heap
   object first marks the object it points to (snapshot at the beginning) and puts it in a batch. The
   batch goes to the GC thread when it holds 256 objects and at every step. Without this an object that
   the program moves out of a heap location, and holds only in a local, could be freed.
4. **Steps.** After every 8 KB of allocation the program thread hands over its batch and asks whether the
   GC thread has run dry. If the program allocates more than a share of the heap during the cycle (one
   twenty-fifth by default, plus 64 MiB), each step holds it back for 100 microseconds (a spin, not a
   sleep: a sleep can overshoot by milliseconds, and `sched_yield` can hand the core to another thread for
   a whole time slice) until the GC thread catches up. This bounds memory and keeps every step short.
5. **End of marking.** When the GC thread has nothing left and nothing was handed over, the marks are
   final. The boxes of dead templates are freed and the sweep is set up. This takes a few microseconds.
6. **Sweep in steps.** Each step (every 8 KB of allocation) sweeps pages for up to 50 microseconds, then
   returns. The class lists start empty and each swept page with room goes back on its list, so the
   allocator only uses swept pages; a page created during the sweep has the current epoch and is not
   swept again. A dead large object gives its span to the cache, and the cache gives expired spans back
   with `munmap`, at most 1 MiB per step.

Where the barrier is applied:

| Place | How |
|---|---|
| Every value cell written by `_set` or `_cp` | `lv_wb_cell` before the write (whether the cell is on the stack or in a heap object) |
| List items pointer, map entries pointer, map index pointer, map entry key | `lv_wb_word` before the store |
| Map rehash, list `remove`, sort copy-back | `lv_wb_range` over the cells that are overwritten or moved |
| Compiled assignment to a captured variable | the compiler emits a call to `lv_wb_cell` (`ll_copy_heap`) |

A new cycle cannot begin while one is marking or sweeping. `ZUE_RT_GC_STRESS` starts a cycle every Nth
allocation and looks at the collector at every allocation (one page of sweeping per step), and
`ZUE_RT_GC_SLOW` makes the GC thread slow, so the program interleaves with the collector as much as possible.

Not needed: stores to the stack and to globals (they are scanned at the start of the cycle), initial stores into a new object (its old contents are zero), and dense lists, strings and box
bytes (they hold no heap pointers). A new store of a pointer into a heap object must call a barrier
function; the tests below fail when one is missing.

## Environment variables

Read once at program start, by the compiled program itself:

| Variable | Effect |
|---|---|
| `ZUE_RT_GC_STRESS=N` | Collect on every Nth allocation. `1` collects on every allocation. Used to find missing roots |
| `ZUE_RT_GC_STATS=1` | At exit, print `ZUE_RT_GC_STATS,<n> collections,<bytes> live bytes,<pages> pages,<ns> total pause ns,<ns> max pause ns,<ns> mark ns,<ns> sweep ns,<ns> max cycle end ns,<ns> max cycle start ns,<n> mark stack grows,<ns> max sweep step ns,<ns> longest cycle ns` to standard error. A pause is one stop of the program thread (a step, or the start or end of a cycle). `mark ns` is the GC thread's marking time. A second line, `ZUE_RT_GC_THROTTLE`, gives how many steps were held back, the total and longest hold, and how much of the longest pause was that hold. A third line, `ZUE_RT_GC_CHUNKS`, gives how many 2 MB chunks of heap memory the helper thread had ready and how many the program thread had to make itself. `ZUE_RT_GC_STATS=2` also prints a `ZUE_RT_GC_CYCLE` line per cycle (wall time, GC thread time, bytes allocated during and before the cycle). The collector's pause counter does not see time the program waits inside the write barrier; `bench/gc/stalls.zu` times every loop iteration and shows what the program itself sees |
| `ZUE_RT_GC_SLOW=N` | The GC thread sleeps N microseconds after each piece of marking. For tests: it widens the time the program and the GC thread overlap |
| `ZUE_RT_GC_VERIFY=1` | At the end of each marking walk the heap again and stop with an error if a reachable object is not marked. Freed objects are filled with `0xDD` so a use after free shows. A stale word on the stack that points at an unmarked object is skipped, because the program cannot reach the object through it |

```bash
ZUE_RT_GC_STATS=1 ./prog
ZUE_RT_GC_STRESS=1 compiler/run_tests.sh test/test_gc_safety.zu
ZUE_RT_GC_VERIFY=1 ZUE_RT_GC_STRESS=1 compiler/run_tests.sh test/test_gc_barrier.zu
```

## Threads

The GC thread is created when the program starts. It sleeps on a condition variable between cycles, so an
idle program uses no CPU for it. If the thread cannot be created the program stops with
`Runtime Error: cannot start the garbage collector thread`; there is no other way to collect.

| State | Who uses it | How it is shared |
|---|---|---|
| Mark stack | The GC thread during a cycle; the program thread at the start of a cycle | The program thread touches it only while the GC thread sleeps |
| Batches of marked objects | The program thread fills a local batch; the GC thread takes the shared one | Handed over under a mutex |
| Mark bytes | Both threads | `cas8`, so an object is queued once |
| Page table, heap bounds | The program thread writes; both read | Release stores, acquire loads; a page is complete before the table shows it |
| Page descriptors and object contents | The GC thread reads them while the program may change them | Not synchronised, on purpose (see below) |

The scan reads object contents and two page descriptor fields (the number of objects handed out and their
used flags) while the program writes them. That is safe: the snapshot is taken at the start, the write
barrier marks what the program overwrites, and an object allocated during a cycle is marked at birth.
`tools/gc_race_check.sh` builds programs with ThreadSanitizer and fails on any race other than these two.

## Testing the collector

`test_gc_safety.zu`, `test_gc_large_safety.zu`, `test_gc_callbacks.zu`, `test_gc_span_reuse.zu` and
`test_gc_recursion.zu` build and drop many objects and check that live data stays intact.
`test_gc_barrier.zu` moves objects out of lists, maps, closure cells, template fields, `remove` and
`sort`, overwrites the old location, and keeps the object elsewhere; it is the test for the write barrier.
Switching off any one barrier function makes it fail under `ZUE_RT_GC_VERIFY=1 ZUE_RT_GC_STRESS=1`. Run
them under `ZUE_RT_GC_STRESS=1`, and with `ZUE_RT_GC_STRESS=7 ZUE_RT_GC_SLOW=50`, after any change to `zue_gc.zu`, to a runtime function that
allocates, or to how generated code keeps values in memory. `tools/gc_race_check.sh` runs the GC tests under ThreadSanitizer. `make` also exercises the collector:
the compiler compiles itself twice, and the two outputs must be identical.

## Known limits

- One GC thread marks at about 4 GB of live data per second. A program that allocates faster than that is
  slowed down, or (with a larger share allowed) holds more memory, because what it allocates during a
  cycle stays until the next one. Several marking threads or a generational layer would help (see [plan](plan.md)).
- Sweeping is still done by the program thread.
- No compaction. Fragmented pages are reused through their free lists.
- The growth percentage trades memory for speed. At 1 GiB live, `lowpause` peaks at about 1.5 times
  the live size; a lower percentage costs speed because every collection scans all live data.
- Empty pages go back to the OS (`madvise`) a few per collector step, keeping as many as the next
  cycle can allocate.

## Measured cost

Compiling the compiler (`bin/zue emit compiler/zuec.zu`, 15 MB of generated IR), best of three:

| Build | Wall time | Peak memory |
|---|---|---|
| Before the incremental collector (commit 432c756) | 0.33 s | 111 MB |
| Now, `lowpause` (default) | 0.28 s | 86 MB |

Measure your own program with `ZUE_RT_GC_STATS=1`.

## Heap chunks come ready

Small-object pages are cut from 2 MB chunks. The first touch of a chunk asks the kernel for a huge page,
which it must find (sometimes by compacting memory) and zero. Measured on the program thread at a 10 GiB
heap, that took up to 55 ms and was the cause of every stall over 1 ms: 131 chunk faults over 1 ms against 137
program stalls over 1 ms in the same run. A helper thread now maps, hints and touches chunks ahead of time
and hands them over through a ring of 16 slots with acquire and release stores. It keeps two chunks ready
once the program has asked for a second one, and doubles that (up to 16) each time the ring was empty. The
first chunk and any chunk the ring cannot supply are made on the program thread, as before. The helper's
state is in its own `calloc` block, which the collector does not scan.

| 10 GiB request, `bench/gc/stalls.zu`, 20 million iterations | Worst stall | Stalls over 1 ms |
|---|---|---|
| Before (3 runs) | 5.7 to 15.7 ms | 58 to 635 |
| With the helper (5 runs) | 0.32 to 1.37 ms | 0 to 2 |
| Hugepage hint removed (5 runs) | 0.35 to 1.0 ms | 0 to 1 |

Removing the hint is as good for stalls but made a 1 GiB run 22 percent slower (7.13 s against 5.85 s), so the
hint stays on, and the helper turns it off by itself when it costs too much. It times every chunk it makes. A
chunk that takes more than 1 ms is a spike (`SPIKE_NS`). After 3 spikes (`HINT_SPIKES`) the chunks made from then
on ask for no huge pages (`MADV_NOHUGEPAGE`) and the program carries on. The rule has no size limit: the
kernel documentation ties these stalls to fragmentation of free memory, not to the size of the heap, and
a size limit of 8 GiB gave the same result as no limit in the runs below (the spikes only appeared past it).
`ZUE_RT_GC_CHUNKS` shows how many chunks were spikes, the longest time to make one, and the chunk number at which
the hint went off (0 when it never did).

Measured with `bench/gc/stalls.zu`, 20 million iterations, 3 runs per row:

| Request | Rule | Worst stall | Stalls over 1 ms | Chunks over 1 ms | Hint off at chunk |
|---|---|---|---|---|---|
| 1 GiB | hint always on | 0.19 to 0.28 ms | 0 | 0 | never |
| 1 GiB | 3 spikes | 0.19 to 0.26 ms | 0 | 0 | never |
| 4 GiB | hint always on | 0.12 to 0.58 ms | 0 | 0 | never |
| 4 GiB | 3 spikes | 0.17 to 0.20 ms | 0 | 0 to 1 | never |
| 10 GiB | hint always on | 1.19 to 22.15 ms | 1 to 3 | 214 to 354 | never |
| 10 GiB | 3 spikes | 0.39 to 1.76 ms | 0 to 2 | 3 | about 6,400 |
| 10 GiB | 3 spikes and a heap of 8 GiB or more | 0.36 to 0.63 ms | 0 | 3 | about 6,300 to 6,400 |

Some stalls of 1 to 2 ms remain when the kernel compacts memory, which moves pages of the heap (the kernel
counters showed up to 993 compaction stalls in a run). That cause is likely but not proven.

## The allocation path

`_gc_alloc` is the short path almost every allocation takes: a small object, no collector work due, a page of
the size class with a free slot or room to bump. Everything else (setting up the collector, running a step,
mapping a page, a large object) is `_slow_gc_alloc`, which is a call and not part of the fast path (see the native
dialect in [architecture](architecture.md)). A list made with known contents, of up to 32 items, is one object: the header and
the cells together, so `[a, b, c, d]` costs one allocation. An empty list that is filled by appending is not: it usually grows
past its first items, and the space inside the header object would then be dead weight (a row of 8 appended items took 256
bytes that way against 176, and a 10 GiB run ended with 15.3 GB live against 12.4). When such a list grows, its cells move to an object of their own
(`_list_push` allocates and copies; it does not use `lv_realloc`, because the cells are not an object), the
elements it held are shaded by the write barrier (`lv_wb_range`) and the old cells are cleared so that they do
not keep elements alive. `test_list_layout` fails under `ZUE_RT_GC_STRESS=1` when that barrier is left out.

## Free slots and returning memory

After a sweep the free slots of a small-object page are the zero bytes of its used map below `PG_BUMP`. The
allocator searches that map from `PG_FREE`; `PG_NFREE` counts the free slots, so the search always ends. The sweep
does not write into dead objects; the allocator clears an object when it hands it out. Empty pages go to a pool and are
given back to the system a few at a time whenever the pool holds more than the collector keeps for reuse, also
between cycles (`_pool_pending`).

