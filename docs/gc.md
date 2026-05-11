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
last collection exceed a threshold: 16 MiB at the start, and after each collection the larger
of 16 MiB and the growth percentage of the live bytes that survived. The growth percentage is 45 with
`--gc=lowpause` and 200 with `--gc=throughput`; `ZUE_RT_GC_GROWTH=N` sets it. (With `ZUE_RT_GC_STRESS`, see below, also every
Nth allocation.)

1. **Roots.** The data segment (all module-level variables and constants of the program and the
   runtime), every registered root range (the `alloc()` buffers), the machine stack of the
   thread running the program, and the registers (spilled to the stack first) are scanned.
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

## Collector modes

There is one collector with two ways of running a cycle. The mode is chosen when the program is built.

| Build option | What a cycle does | Write barrier in the program | Use it when |
|---|---|---|---|
| `--gc=lowpause` (default) | A GC thread marks while the program runs; the program sweeps in short steps between allocations | Yes | Pause time matters |
| `--gc=throughput` | Runs the whole cycle in one piece when the threshold is reached | No | Pauses do not matter |

```bash
zue build prog.zu -o prog                    # lowpause
zue build --gc=throughput prog.zu -o prog    # throughput
GC_MODE=throughput compiler/run_tests.sh     # the whole test suite built that way
```

The option goes before the file name. The run-time variable `ZUE_RT_GC_MODE=throughput` makes any program
run its cycles in one piece; this is always safe. The other way round is not possible, because a program
built with `--gc=throughput` has no barrier.

## How a cycle runs

In `lowpause` mode the GC thread marks and the program thread sweeps in short steps. A cycle works like this:

1. **Start.** The program thread marks the data segment (without `lv_frames`, which never holds heap
   pointers), the root ranges and its own stack and registers. This is the snapshot. It takes about 25
   microseconds. It then wakes the GC thread.
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

Not needed: stores to the stack, to globals and to root ranges (they are scanned at the start of the
cycle), initial stores into a new object (its old contents are zero), and dense lists, strings and box
bytes (they hold no heap pointers). A new store of a pointer into a heap object must call a barrier
function; the tests below fail when one is missing.

## Environment variables

Read once at program start, by the compiled program itself:

| Variable | Effect |
|---|---|
| `ZUE_RT_GC_STRESS=N` | Collect on every Nth allocation. `1` collects on every allocation. Used to find missing roots |
| `ZUE_RT_GC_STATS=1` | At exit, print `ZUE_RT_GC_STATS,<n> collections,<bytes> live bytes,<pages> pages,<ns> total pause ns,<ns> max pause ns,<ns> mark ns,<ns> sweep ns,<ns> max cycle end ns,<ns> max cycle start ns,<n> mark stack grows,<ns> max sweep step ns,<ns> longest cycle ns` to standard error. A pause is one stop of the program thread (a step, or the start or end of a cycle). `mark ns` is the GC thread's marking time. A second line, `ZUE_RT_GC_THROTTLE`, gives how many steps were held back, the total and longest hold, and how much of the longest pause was that hold. `ZUE_RT_GC_STATS=2` also prints a `ZUE_RT_GC_CYCLE` line per cycle (wall time, GC thread time, bytes allocated during and before the cycle). The collector's pause counter does not see time the program waits inside the write barrier; `bench/gc/stalls.zu` times every loop iteration and shows what the program itself sees |
| `ZUE_RT_GC_GROWTH=N` | Start the next collection after N percent of the live bytes have been allocated (default 45, or 200 with `--gc=throughput`) |
| `ZUE_RT_GC_SLOW=N` | The GC thread sleeps N microseconds after each piece of marking. For tests: it widens the time the program and the GC thread overlap |
| `ZUE_RT_GC_CAPDIV=N` | The program may allocate 1/N of the heap (plus 64 MiB) during a cycle before it is held back (default 25). A smaller N is faster and uses more memory; a large N holds the program back more. At 4 GiB: 25 is 9% faster than before with 2% more memory, 4 is 24% faster with 27% more, 1 is 27% faster with 25% more |
| `ZUE_RT_GC_MODE=throughput` | Run every cycle in one piece (see "Collector modes") |
| `ZUE_RT_GC_VERIFY=1` | At the end of each marking walk the heap again and stop with an error if a reachable object is not marked. Freed objects are filled with `0xDD` so a use after free shows. A stale word on the stack that points at an unmarked object is skipped, because the program cannot reach the object through it |

```bash
ZUE_RT_GC_STATS=1 ./prog
ZUE_RT_GC_STRESS=1 compiler/run_tests.sh test/test_gc_safety.zu
ZUE_RT_GC_VERIFY=1 ZUE_RT_GC_STRESS=1 compiler/run_tests.sh test/test_gc_barrier.zu
```

## Threads

The GC thread is created when the program starts (not with `--gc=throughput`). It sleeps on a condition
variable between cycles, so an idle program uses no CPU for it. If the thread cannot be created, every
cycle runs in one piece, as with `--gc=throughput`.

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
- Sweeping is still done by the program thread, and `--gc=throughput` has no GC thread.
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
| Now, `ZUE_RT_GC_MODE=throughput` | 0.28 s | 100 MB |

The mode of a program does not change how fast `zue` compiles it. The two builds of the compiler's IR
differ by 35 bytes, and `clang -O1` took 7.26 s (`lowpause`) and 7.51 s (`throughput`) for it.
Measure your own program with `ZUE_RT_GC_STATS=1`.
