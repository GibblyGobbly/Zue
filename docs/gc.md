# Garbage Collector

Every compiled Zue program carries a garbage collector. It is part of the runtime, written in
Zue: `compiler/runtime/zue_gc.zu`. It is a conservative, non-moving, incremental mark-and-sweep
collector with a write barrier (named Hush in [plan](plan.md)). It does not need type maps from the
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
of 16 MiB and the live bytes that survived. (With `ZUE_RT_GC_STRESS`, see below, also every
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

The collector runs on the program's single thread.

## Collector modes

There is one collector with two ways of running a cycle. The mode is chosen when the program is built.

| Build option | What a cycle does | Write barrier in the program | Use it when |
|---|---|---|---|
| `--gc=lowpause` (default) | Marks and sweeps in short steps between allocations | Yes | Pause time matters |
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

In `lowpause` mode the collector marks and sweeps in short steps. A cycle works like this:

1. **Start.** The data segment (without `lv_frames`, which never holds heap pointers), the root
   ranges and the stack and registers are marked. This is the snapshot. It takes about 25 microseconds.
2. **Steps.** After every 8 KB of allocation the collector scans up to 16384 words (a larger object
   is scanned in pieces of 4 KB). New objects are allocated already marked, so they survive the cycle.
3. **Write barrier.** While a cycle marks, any code that is about to overwrite a pointer inside a heap
   object first marks the object it points to (snapshot at the beginning). Without this an object that
   the program moves out of a heap location, and holds only in a local, could be freed.
4. **End of marking.** When nothing is left to scan the marks are final. The boxes of dead templates
   are freed and the sweep is set up. This takes a few microseconds.
5. **Sweep in steps.** Each step (every 8 KB of allocation) sweeps pages for up to 50 microseconds, then
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

A new cycle cannot begin while one is marking or sweeping. `ZUE_RT_GC_STRESS` makes the steps tiny (64
words of marking, one page of sweeping) so the program interleaves with the collector as much as possible.

Not needed: stores to the stack, to globals and to root ranges (they are scanned at the start of the
cycle), initial stores into a new object (its old contents are zero), and dense lists, strings and box
bytes (they hold no heap pointers). A new store of a pointer into a heap object must call a barrier
function; the tests below fail when one is missing.

## Environment variables

Read once at program start, by the compiled program itself:

| Variable | Effect |
|---|---|
| `ZUE_RT_GC_STRESS=N` | Collect on every Nth allocation. `1` collects on every allocation. Used to find missing roots |
| `ZUE_RT_GC_STATS=1` | At exit, print `ZUE_RT_GC_STATS,<n> collections,<bytes> live bytes,<pages> pages,<ns> total pause ns,<ns> max pause ns,<ns> mark ns,<ns> sweep ns,<ns> max mark step ns,<ns> max cycle end ns,<ns> max cycle start ns,<ns> max step cpu ns,<n> mark stack grows,<ns> max sweep step ns` to standard error. In incremental mode a pause is one stop (a step, or the start or end of a cycle); `max step cpu` is the longest mark step in thread CPU time, which excludes time the operating system took the processor away |
| `ZUE_RT_GC_MODE=throughput` | Run every cycle in one piece (see "Collector modes") |
| `ZUE_RT_GC_VERIFY=1` | At the end of each marking walk the heap again and stop with an error if a reachable object is not marked. Freed objects are filled with `0xDD` so a use after free shows. A stale word on the stack that points at an unmarked object is skipped, because the program cannot reach the object through it |

```bash
ZUE_RT_GC_STATS=1 ./prog
ZUE_RT_GC_STRESS=1 compiler/run_tests.sh test/test_gc_safety.zu
ZUE_RT_GC_VERIFY=1 ZUE_RT_GC_STRESS=1 compiler/run_tests.sh test/test_gc_barrier.zu
```

## Testing the collector

`test_gc_safety.zu`, `test_gc_large_safety.zu`, `test_gc_callbacks.zu`, `test_gc_span_reuse.zu` and
`test_gc_recursion.zu` build and drop many objects and check that live data stays intact.
`test_gc_barrier.zu` moves objects out of lists, maps, closure cells, template fields, `remove` and
`sort`, overwrites the old location, and keeps the object elsewhere; it is the test for the write barrier.
Switching off any one barrier function makes it fail under `ZUE_RT_GC_VERIFY=1 ZUE_RT_GC_STRESS=1`. Run
them under `ZUE_RT_GC_STRESS=1` after any change to `zue_gc.zu`, to a runtime function that
allocates, or to how generated code keeps values in memory. `make` also exercises the collector:
the compiler compiles itself twice, and the two outputs must be identical.

## Known limits

- Single-threaded: the collector runs on the program's thread, in steps. There is no generational mode
  and no GC thread yet. `--gc=throughput` is not faster than `--gc=lowpause` yet (see [plan](plan.md)).
- No compaction. Fragmented pages are reused through their free lists.
- The threshold rule (the larger of 16 MiB and the live size) is not tuned.
- The heap can grow to about twice the live size before a collection, because the threshold is the
  live size of the last collection.

## Measured cost

Compiling the compiler (`bin/zue emit compiler/zuec.zu`, 15 MB of generated IR), best of three:

| Build | Wall time | Peak memory |
|---|---|---|
| Before the incremental collector (commit 432c756) | 0.33 s | 111 MB |
| Now, `lowpause` (default) | 0.31 s | 86 MB |
| Now, `ZUE_RT_GC_MODE=throughput` | 0.30 s | 83 MB |

The mode of a program does not change how fast `zue` compiles it. The two builds of the compiler's IR
differ by 35 bytes, and `clang -O1` took 7.26 s (`lowpause`) and 7.51 s (`throughput`) for it.
Measure your own program with `ZUE_RT_GC_STATS=1`.
