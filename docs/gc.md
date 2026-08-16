# Garbage Collector

Every compiled Zue program carries a garbage collector. It is part of the runtime, written in
Zue: `compiler/runtime/zue_gc.zu`. It is a conservative, non-moving Immix collector with a write barrier.
A GC thread marks while the program runs, and then sweeps. It does not need type maps from the
compiler: it treats every aligned word it scans as a possible pointer.

## Memory domains

| Domain | Holds | Lifetime |
|---|---|---|
| GC heap | strings, lists, dense lists, maps, closures and their captured cells, templates, blocs | traced and freed by the collector |
| Box table | `box` buffers | freed when their scope ends, by `free`, or with their owning template |
| `alloc()` buffers | raw memory from `unsafe` blocks | freed by `free` / `defer`; registered as root ranges, never freed by the collector |

## Heap layout

| Unit | Size | What it is |
|---|---|---|
| Granule | 16 bytes | Objects start on a granule and take whole granules |
| Line | 128 bytes | The unit of reuse: a line is free when no live object touches it |
| Block | 32 KB (256 lines) | Holds normal objects or atomic objects, not both |
| Chunk | 2 MB (64 blocks) | Aligned to 2 MB, asked for as a huge page |
| Large object | over 8 KB | A span of whole 64 KB pages of its own |

- **Size.** Every request is one byte larger than asked, rounded up to whole granules, so a pointer just
  past the end still points inside the object. A list header (24 bytes) takes 32; the items of 8 values
  (128 bytes) take 144.
- **Atomic objects** (strings, doubles, byte buffers, dense list data) are allocated in blocks of their own
  and never scanned for pointers.
- **Allocation** is a bump of a cursor through a hole, a run of free lines. When the hole is used up the
  allocator looks for the next hole in its block, then takes another block: a block with holes, then a
  free block, then a free block whose memory was given back, then a new block cut from a chunk. An object
  over one line that does not fit the current hole goes to a second allocator that only takes free blocks,
  so the holes of a block are not skipped for it.
- **New memory is zero.** Fresh chunks come zeroed from the kernel, and a hole is cleared when it is taken,
  not each object.
- **Chunk descriptors** live outside the heap (allocated with `calloc`, never scanned). For each granule
  they keep three bits: an object starts here, an object ends here, and the mark. For each line they keep
  the number of the cycle that last found it live (0 when free), and one bit for lines allocated during a
  cycle. That is 3.1 percent of the chunk.
- **Finding an object.** A page table (two levels, indexed by bits 32 to 47 and 16 to 31 of the address)
  maps each 64 KB of address space to a chunk or a large object. Inside a chunk, a word points into an
  object when a start bit is found at or before it in the same block, and the first end bit after that
  start is at or after it. Interior pointers keep an object alive.
- **Large objects** are mapped with `mmap`, which the kernel zeroes, and touched only when used. A dead one
  leaves the page table and is unmapped by the GC thread.

## Collection

A collection is triggered inside an allocation. It happens when the bytes allocated since the
last collection exceed a threshold: 16 MiB at the start, then the value the pacer works out (see
"The pacer"). (With `ZUE_RT_GC_STRESS`, see below, also every Nth allocation.)

1. **Roots.** The data segment (all module-level variables and constants of the program and the
   runtime), every registered root range (the `alloc()` buffers), the machine stack of the
   thread running the program, and the registers (spilled to the stack first) are scanned. The stacks
   of the blue threads that are away are scanned too, from the stack pointer saved when they gave up
   the processor, and so are the registers they saved (kept in a ucontext object on the heap).
2. **Mark.** Each scanned word that points into a live object marks it and the lines it touches, and the
   object's contents are scanned in turn, using an explicit mark stack. Atomic objects are marked but not
   scanned.
3. **Data hook.** Boxes owned by templates that were not marked are freed.
4. **Sweep.** In every block, unmarked objects lose their start and end bits, and lines no live object
   touches become free. A block with no live line is free; one with free lines can be allocated into again.

Because the collector is conservative, a stale integer that looks like an address can keep an
object alive longer than needed. It can never free a live object, as long as every pointer is
kept in a scanned location (the stack, registers, the data segment, a registered range, or a
reachable heap object).

Only one thread runs Zue code. One more thread, the GC thread, marks and sweeps (see [Threads](#threads)).

## The pacer

There is one collector and no options for it. When to start a cycle, and how much the program may allocate
before it is held back, are worked out at the end of every cycle from what was measured, not from fixed
percentages.

| Step | What the pacer does |
|---|---|
| Measure | The allocation rate of the program (bytes per millisecond between two cycle ends) and the cost of a cycle (nanoseconds from its start to the end of its sweep, per MiB of live data). Each is averaged with the last value |
| Estimate | `a`, the bytes the program will allocate during the next cycle: rate times the cycle time for the live size |
| Goal | Four times `a`, but at least 32 MiB, at most twice the live size (an eighth of it with `--gc=lowmem`), and at most what the free memory of the machine (85 percent of it, `sysconf`) and `ulimit -v` (70 percent) allow |
| Start | The next cycle starts when the goal minus `a` has been allocated, at least 16 MiB |
| Hold back | While a cycle runs, the program is slowed down in 100 microsecond steps only once the bytes allocated since the last cycle end pass the goal |
| Keep | Free blocks up to the start threshold stay ready; the GC thread gives the memory of the rest back to the system |

## How a cycle runs

1. **Start.** The program thread marks the data segment (without `lv_frames`, which never holds heap
   pointers) and its own stack and registers. This is the snapshot. It then wakes the GC thread. The root
   ranges (the `alloc()` buffers) are part of the snapshot too, but they are scanned in slices of 256 KB,
   one slice per collector step on the program thread, and the cycle cannot end before the last slice. A
   store into a buffer shades the value it overwrites (the barrier in `_cp`). A buffer that is freed, or
   moved in the table of ranges, before its scan reached it is scanned to the end first.
2. **Marking.** The GC thread scans from its mark stack while the program keeps running. Every hole the
   program takes during the cycle, and the rest of the current hole from the next line on, is black: its
   lines are live in this cycle, and the objects in it count as marked and are not scanned (what they point
   to was reachable at the snapshot or is new too). A large object made during the cycle is black too.
3. **Write barrier.** While a cycle marks, any code that is about to overwrite a pointer inside a heap
   object first marks the object it points to (snapshot at the beginning) and puts it in a batch. The
   batch goes to the GC thread when it holds 256 objects and at every step. Without this an object that
   the program moves out of a heap location, and holds only in a local, could be freed.
4. **Steps.** After every 8 KB of allocation the program thread hands over its batch and asks whether the
   GC thread has run dry. A program that has allocated past the pacer's goal is held back for 100
   microseconds per step (a spin, not a sleep: a sleep can overshoot by milliseconds, and `sched_yield` can
   hand the core to another thread for a whole time slice) until the GC thread catches up.
5. **End of marking.** When the GC thread has nothing left and nothing was handed over, the marks are
   final. The boxes of dead templates are freed. The allocators let go of their blocks, and the GC thread is
   woken to sweep.
6. **Sweep.** The GC thread sweeps the blocks in groups of 64 that it claims under the collector's mutex.
   When the program needs a block before the GC thread got to it, it claims and sweeps one itself. A block
   taken during the sweep is not swept. Then dead large objects are unmapped, and the memory of free blocks
   beyond what the pacer keeps is given back with `madvise`. The program thread runs the pacer at its next
   step after the sweep is done; the next cycle can begin after that.

Where the barrier is applied:

| Place | How |
|---|---|
| Every value cell written by `_set` or `_cp` | `lv_wb_cell` before the write (whether the cell is on the stack or in a heap object) |
| List items pointer, map entries pointer, map index pointer, map entry key | `lv_wb_word` before the store |
| Map rehash, list `remove`, sort copy-back | `lv_wb_range` over the cells that are overwritten or moved |
| Compiled assignment to a captured variable | the compiler emits a call to `lv_wb_cell` (`ll_copy_heap`) |

A new cycle cannot begin while one is marking or sweeping. `ZUE_RT_GC_STRESS` starts a cycle every Nth
allocation and looks at the collector at every allocation, and `ZUE_RT_GC_SLOW` makes the GC thread slow, so
the program interleaves with the collector as much as possible.

Not needed: stores to the stack and to globals (they are scanned at the start of the cycle), initial stores
into a new object (its old contents are zero), and dense lists, strings and box bytes (they hold no heap
pointers). A new store of a pointer into a heap object must call a barrier function; the tests below fail
when one is missing.

## Environment variables

Read once at program start, by the compiled program itself:

| Variable | Effect |
|---|---|
| `ZUE_RT_GC_STRESS=N` | Collect on every Nth allocation. `1` collects on every allocation. Used to find missing roots |
| `ZUE_RT_GC_STATS=1` | At exit, print `ZUE_RT_GC_STATS,<n> collections,<bytes> live bytes,<n> chunks,<ns> total pause ns,<ns> max pause ns,<ns> mark ns,<ns> sweep ns,<ns> max cycle end ns,<ns> max cycle start ns,<n> mark stack grows,<bytes> large object bytes,<ns> longest cycle ns` to standard error. A pause is one stop of the program thread in a collector step. `mark ns` and `sweep ns` are the GC thread's time. Live bytes count whole lines. A second line, `ZUE_RT_GC_THROTTLE`, gives how many steps were held back, the total and longest hold, and how much of the longest pause was that hold. A third line, `ZUE_RT_GC_CHUNKS`, gives how many 2 MB chunks the helper thread had ready and how many the program thread had to make itself. `ZUE_RT_GC_STATS=2` also prints a `ZUE_RT_GC_CYCLE` line per cycle (wall time, GC thread time, bytes allocated during and before the cycle). `ZUE_RT_GC_STATS=3` instead prints a `ZUE_RT_GC_CENSUS` line after each sweep: chunks, blocks in use (full and with holes), the share of their lines that is live, free blocks, blocks whose memory was given back, and large objects. The collector's pause counter does not see time the program waits inside the write barrier; `bench/gc/stalls.zu` times every loop iteration and shows what the program itself sees, and `bench/gc/mutator_utilization.zu` records every stop over 10 microseconds and prints the minimum mutator utilization (MMU, the smallest share of any 0.1 ms to 1 s window in which the program ran) and the metered latency (how far requests arriving at an even rate fall behind) |
| `ZUE_RT_GC_SLOW=N` | The GC thread sleeps N microseconds after each piece of marking. For tests: it widens the time the program and the GC thread overlap |
| `ZUE_RT_GC_VERIFY=1` | At the end of each marking walk the heap again and stop with an error if a reachable object is neither marked nor black. Dead objects and free lines are filled with `0xDD` so a use after free shows. A stale word on the stack that points at an unmarked object is skipped, because the program cannot reach the object through it. After each sweep the block lists are checked |

```bash
ZUE_RT_GC_STATS=1 ./prog
ZUE_RT_GC_STRESS=1 compiler/run_tests.sh test/test_gc_safety.zu
ZUE_RT_GC_VERIFY=1 ZUE_RT_GC_STRESS=1 compiler/run_tests.sh test/test_gc_barrier.zu
```

## Threads

The GC thread is created when the program starts. It sleeps on a condition variable between cycles, so an
idle program uses no CPU for it. If the thread cannot be created the program stops with
`Runtime Error: cannot start the garbage collector thread`; there is no other way to collect. A helper
thread makes 2 MB chunks ahead of time, so that the first touch of a huge page is not paid by the program.

| State | Who uses it | How it is shared |
|---|---|---|
| Mark stack | The GC thread during a cycle; the program thread at the start of a cycle and in the verifier | The program thread touches it only while the GC thread waits |
| Batches of marked objects | The program thread fills a local batch; the GC thread takes the shared one | Handed over under a mutex |
| Mark bits | Both threads | `cas8` on the byte, so an object is queued once |
| Start and end bits, line epochs, block kinds | The program thread writes them while allocating; the GC thread reads them while marking | Atomic loads and stores |
| Block lists, the sweep's cursor, the page table, the lists of chunks and large objects | Both threads | Under the mutex; the page table is also read without it (release stores, acquire loads; a descriptor is complete before the table shows it) |
| Object contents | The GC thread reads them while the program may change them | Not synchronised, on purpose (see below) |

The scan reads object contents while the program writes them. That is safe: the snapshot is taken at the
start, the write barrier marks what the program overwrites, and an object allocated during a cycle is black.
`tools/gc_race_check.sh` builds programs with ThreadSanitizer and fails on any other race.

## Testing the collector

`test_gc_safety.zu`, `test_gc_large_safety.zu`, `test_gc_callbacks.zu`, `test_gc_span_reuse.zu` and
`test_gc_recursion.zu` build and drop many objects and check that live data stays intact.
`test_gc_barrier.zu` moves objects out of lists, maps, closure cells, template fields, `remove` and
`sort`, overwrites the old location, and keeps the object elsewhere; it is the test for the write barrier.
`test/native/gc_heap_unit.zu` checks object sizes and that every address inside an object finds it and none
outside does. Run the GC tests under `ZUE_RT_GC_VERIFY=1`, and with `ZUE_RT_GC_STRESS=7 ZUE_RT_GC_SLOW=50`,
after any change to `zue_gc.zu`, to a runtime function that allocates, or to how generated code keeps values
in memory. `tools/gc_race_check.sh` runs the GC tests under ThreadSanitizer. `make` also exercises the
collector: the compiler compiles itself twice, and the two outputs must be identical.

## Known limits

- One GC thread marks. A program that allocates faster than it marks is held back by the throttle (stage II
  of the plan replaces it with several markers and assists, see [plan](plan.md)).
- No compaction. A block with a few live lines stays in use; its free lines are reused.
- Chunks are never unmapped; the memory of their free blocks is given back.
- Freed large spans are unmapped, not kept for reuse.
