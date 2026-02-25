# Memory Management

Zue manages memory for you. You allocate by writing values; the runtime frees what is no
longer reachable. Four places hold data, and each has its own rules.

| Where | What lives there | Who frees it |
|---|---|---|
| The call stack | local variables, temporaries, call frames | automatic, when the function returns |
| The garbage-collected heap | strings, lists, maps, dense lists, closures, templates, blocs | the garbage collector |
| The box table | `box` byte buffers | the end of the scope, `free`, or the owning template |
| Raw `alloc()` memory | buffers made inside `unsafe` blocks | you, with `free` or `defer` |

## Values

Every value is a 16-byte cell: a tag saying what it is, and a payload. Numbers, booleans,
chars and `null` sit directly in the cell. Strings, lists, maps and the rest are pointers to
objects on the heap (see [architecture](architecture.md#values) for the tags).

- Assigning or passing a list, map, `data` or `template` value shares it: both names refer to
  the same object, so a change through one is seen through the other.
- Numbers, booleans and chars are copied.
- Strings cannot be changed in place. `s[0] = "x"` is an error, and every string function
  returns a new string.
- `bloc` values are immutable copies of their fields.

```javascript
let a = [1, 2]
let b = a
append(b, 3)
print(a)             # [1, 2, 3], a and b are the same list
```

## The call stack

A program runs on its own thread with a 1 GiB stack, so deep recursion works. If the system
will not give that much address space (for example under `ulimit -v`), the runtime tries 256
MiB, 64 MiB and 16 MiB.

- A function call nested more than 100000 deep stops with
  `stack overflow: recursion is too deep`.
- Running out of stack space earlier (very large functions, or a small stack) gives the same
  error instead of a crash.

## The heap and the garbage collector

Objects are allocated when you create them and freed by the collector once nothing can reach
them. You do not call it, and there is no destructor. The collector starts inside an
allocation when 16 MiB or more has been allocated since the last collection (or the live size,
if larger). It finds live objects from the stack, the registers and every module-level
variable, and frees the rest.

- Cycles are collected: two lists that point at each other are freed once nothing else refers
  to them.
- A collection pauses the program. Pauses grow with the amount of live data.
- Large strings and lists are fine, but a request that cannot be met stops the program with
  `Runtime Error: out of memory` (for example `range(0, 3000000000)`, or any single allocation
  above 64 TiB).
- Lists of numbers can be stored as `dense_list`s, which hold raw doubles and are never scanned,
  so they cost the collector nothing.

Details of the collector (size classes, pages, roots, tuning) are in [gc](gc.md).

### Watching and stressing the collector

| Variable | Effect |
|---|---|
| `ZUE_RT_GC_STATS=1` | At exit, print the number of collections, live bytes, pages and pause times to standard error |
| `ZUE_RT_GC_STRESS=N` | Collect on every Nth allocation, to find bugs in how a program keeps values |

## Files

An open file is an object holding a C file handle. The collector does not close files. Call
`close(file)` when you are done; a handle that is never closed stays open until the program
exits. Reading or writing a closed file is an error (`read() on a closed file`).

## Boxes: fixed buffers with an owner

`box[n]` makes a zeroed buffer of 1 to 4096 bytes, outside the collected heap. When `n` is a
number written in the source (`box[16]`), the bytes live in the function's own stack frame, so
making a box costs no allocation. When the size is a variable (`box[n]`) the bytes come from the
C heap instead. Either way a table of 4096 handles tracks the live boxes, and freed slots are
reused. A box is freed when:

- the scope that made it ends,
- you call `free(box)` (once; freeing twice is an error), or
- the template that owns it is collected.

A box may not outlive its scope: returning it, storing it in a list or map, or assigning it to a
global from inside a function is an error. Putting it in a `template` hands ownership to the
template. After a free, any use is a use-after-free error. A template that takes a box copies
the bytes of a stack box to the heap, so the box stays valid after the function returns.

## Blocs: small values stored inline

A `bloc` is a record of up to 32 bytes of numbers, booleans, chars or other blocs. Its fields
are fixed on first use, it is immutable, and it lives on the heap like any small object.

## Raw memory: `unsafe`, `alloc`, `free`, `defer`

Inside `unsafe { }` you can allocate cells with `alloc(n)`, read and write them with `load` and
`store`, move with `ptr_offset` / `ptr_add`, and take the address of a variable with
`address_of`. This memory is yours: nothing collects it, and it must be freed with `free(ptr)`
exactly once. `defer(ptr)` frees it when the block ends, even on an early exit.

Twelve safety rules are checked at run time and give an error instead of memory corruption:
bounds, use after free, double free, pointers escaping the block, pointers stored in lists or
maps, bad casts, and more. They are listed in [unsafe](unsafe.md).

The collector scans `alloc()` buffers, so a Zue value stored in one stays alive.

## Scope cleanup: `defer`

`defer(call)` outside `unsafe` runs a call when the enclosing scope ends, in reverse order, for
any exit (`return`, `break`, `continue`, or falling off the end). It is the usual way to close a
file:

```javascript
let f = open("notes.txt", "w")
defer(close(f))
write(f, "saved")
```

## Out of memory and limits

| Limit | Value | Result |
|---|---|---|
| Call depth | 100000 | `stack overflow: recursion is too deep` |
| Stack | 1 GiB (smaller when address space is limited) | the same error |
| One allocation | 64 TiB | `Runtime Error: out of memory` |
| Elements in one list or dense list | 2^42 | `Runtime Error: out of memory` |
| Box size | 1 to 4096 bytes | `box size must be between 1 and 4096 bytes` |
| Live boxes | 4096 | `box allocation failed: more than 4096 boxes are live at once` |
| Bloc size | 32 bytes | `Bloc '...' exceeds the 32-byte cache-line cap` |
| Integer | 64-bit signed | `integer overflow in '+'` (and `-`, `*`, ...) |

When the machine runs out of real memory the program stops with `Runtime Error: out of memory`
or is ended by the operating system; Zue does not recover from that.
