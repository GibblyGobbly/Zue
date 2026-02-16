# Unsafe Memory

`unsafe { ... }` gives Luna manual memory: raw buffers you allocate, read, write and free
yourself. Most programs never need it. Lists, maps, strings and `dense_list` cover normal work.

The runtime side is `compiler/runtime/luna_rt_data.lu`, which performs allocation, loads,
stores and frees. Every operation is first checked by the rule functions in
`compiler/runtime/luna_rt_rules.lu` (the allocation table and the ten pointer rules). The
`address_of` call is compiled specially by the compiler (`compiler/emit_llvm.lu`), which also
inserts the check that stops a pointer from leaving its block.

Your own functions may be called inside a block. A pointer is always tied to the block that made it,
and every `alloc` must be freed before that block ends.

## Functions

Available only inside `unsafe { }`:

| Function | Meaning |
|---|---|
| `alloc(n)` | Allocate `n` value slots; returns a pointer |
| `free(ptr)` | Free an allocation |
| `defer(ptr)` | Free `ptr` when the block exits |
| `load(ptr)` | Read the value at `ptr` |
| `store(ptr, value)` | Write `value` at `ptr` |
| `ptr_offset(ptr, n)` | Pointer `n` slots past `ptr`, bounds-checked |
| `address_of(name)` | Pointer to a named variable |
| `int(ptr)` | The only allowed pointer cast |

The older names `deref`, `ptr_add` and `addr` still work as aliases.

Outside `unsafe`, `defer(call(...))` schedules a call for scope exit, for example
`defer(close(file))`. Deferred calls run in LIFO order.

## Boundary with the GC

- A buffer from `alloc()` is memory from `calloc`, not from the GC heap: the collector never
  frees it, only `free` or `defer` does. It is registered as a root range, so Luna values
  stored in its slots stay alive while the buffer exists.
- Normal Luna values inside an `unsafe` block are still GC-managed as usual.
- A raw pointer may not be stored in a list, map or other GC value (R2), so the collector
  never sees one.

## Templates and blocs made by hand

`alloc(object)` with a `template` or `bloc` value copies the object to the C heap, outside the
garbage collector, and returns a pointer. Fields are read and written through it, and the same
rules apply as for any allocation (free or defer it, it cannot leave the block, use after free is an
error):

```javascript
template Player { name: string, hp: int }

unsafe {
    let p = alloc(Player("Astra", 100))
    defer(p)
    p.hp = p.hp - 20
    print(p.hp)          # 80
}
```

A `bloc` made this way is read-only. An object that holds a `box` cannot be copied this way. Typed
field checks still apply. `load` and `store` do not work on a whole object. A `bloc` can be made
inside `unsafe`; a `box` cannot.

## Lifecycle Example

```javascript
unsafe {
    let buf = alloc(2)
    defer(buf)

    store(buf, 12)
    let next = ptr_offset(buf, 1)
    store(next, 34)

    print(load(buf))
    print(load(next))
}
```

This is the usual flow:

- allocate with `alloc(...)`
- register cleanup with `defer(...)`
- write with `store(...)`
- read with `load(...)`

| Function | Description | Example |
|----------|-------------|---------|
| `alloc(n)` | Allocates `n` Luna value slots and returns a pointer | `let buf = alloc(4)` |
| `free(ptr)` | Frees an allocation pointer manually | `free(buf)` |
| `defer(ptr)` | Schedules a pointer to be freed when the current `unsafe` block ends | `defer(buf)` |
| `load(ptr)` | Reads the value stored at a pointer | `let x = load(buf)` |
| `store(ptr, value)` | Writes a value to a pointer slot | `store(buf, 10)` |
| `ptr_offset(ptr, offset)` | Moves `offset` slots forward inside the same allocation | `let p2 = ptr_offset(buf, 2)` |
| `address_of(name)` | Takes the address of a named variable | `let p = address_of(score)` |
| `int(ptr)` | Returns the raw integer address of a pointer | `print(int(buf))` |

## Scope Defer

Deferred calls are available in normal Luna code and are separate from pointer
cleanup in `unsafe`.

```javascript
func write_log(path, text) {
    let file = open(path, "w")
    defer(close(file))
    write(file, text)
}
```

The call expression inside `defer(...)` is captured immediately, and the
cleanup runs when the current scope exits.

## Valid and Invalid Use

### Valid

```javascript
unsafe {
    let buf = alloc(2)
    defer(buf)

    store(buf, 12)
    store(ptr_offset(buf, 1), 34)

    print(load(buf))
    print(load(ptr_offset(buf, 1)))
}
```

### Invalid: `alloc()` outside `unsafe`

```javascript
let buf = alloc(2)   # invalid
```

### Invalid: `address_of()` on a temporary

```javascript
unsafe {
    let p = address_of(1 + 2)   # invalid
}
```

### Invalid: pointer escaping the block

```javascript
let escaped = null

unsafe {
    let buf = alloc(1)
    escaped = buf   # invalid
}
```

### Invalid: storing pointers inside GC values

```javascript
unsafe {
    let buf = alloc(1)
    let items = [buf]   # invalid
}
```

## Safety Rules

| Rule | Meaning |
|---|---|
| `R1` | No pointer-to-pointer through `address_of()` |
| `R2` | A pointer stays inside the `unsafe` block that made it: it cannot be assigned to a variable declared outside the block, returned from it, or stored in a global, list or map |
| `R3` | `ptr_offset()` cannot go out of bounds |
| `R4` | No use-after-free and no double free |
| `R5` | `address_of()` only works on named values, and only inside `unsafe` |
| `R6` | `unsafe` blocks cannot be nested in the source: the outer block already allows everything. This is a compile-time error. A function that has its own `unsafe` block can still be called from inside another one |
| `R7` | `alloc()` size must be a positive integer |
| `R8` | Ordered pointer comparisons need the same base allocation |
| `R9` | Pointers may only be cast with `int(ptr)` |
| `R10` | Every `alloc()` is freed, with `free` or `defer`, before its block ends; a leak is an error that names the line of the `alloc` |

Rules are checked when the operation runs, except R6, which is a compile-time error. A rule
violation stops the program with exit status 1. `box` and `bloc` values are rejected inside `unsafe` blocks.

Together the rules say three things. A pointer never outlives its block (R1, R2, R5). Every
access stays inside a live allocation (R3, R4, R7, R8). And nothing turns a pointer into another
kind of value, except its address as an int (R9). R10 makes sure memory is given back. R6 keeps the
idea of "the block" simple: there is one block at a time in the source.

`free` may appear anywhere, including inside a condition or a loop. Calling your own functions is
allowed, with pointers as arguments or results, as long as R2 holds. A function that returns a
pointer it made returns it into the block that called it.

`test/test_unsafe_errors.lu` has one case per rule, compared against the recorded output in
`test/expected/` (see [testing](testing.md)), and `test/test_unsafe_blocks.lu` shows what is allowed.

## Error Cases

These examples intentionally fail. The message shown is the recorded one.

### R1: `address_of()` of a pointer

```javascript
unsafe {
    let buf = alloc(1)
    defer(buf)
    let bad = address_of(buf)
}
```

Expected message: `cannot take address_of() of a pointer value`

### R2: a pointer leaving its block

```javascript
func f() {
    let outer = null
    unsafe {
        let buf = alloc(1)
        defer(buf)
        outer = buf          # assigned to a variable declared outside the block
    }
}
```

The same message appears for `return buf` inside the block, for assigning to a global, and (with
the message `pointers cannot be stored inside GC-managed values`) for `[buf]` or `{"k": buf}`.

Expected message: `pointer cannot escape the current unsafe block`

### R3: out-of-bounds `ptr_offset()`

```javascript
unsafe {
    let buf = alloc(1)
    defer(buf)
    let bad = ptr_offset(buf, 1)
}
```

Expected message: `ptr_add() moved outside the allocation bounds` (the message uses the older
name of `ptr_offset`)

### R4: use after free, double free

```javascript
unsafe {
    let buf = alloc(1)
    free(buf)
    load(buf)
}
```

Expected message: `pointer was freed or freed twice`

### R5: `address_of()` on a temporary

```javascript
unsafe {
    let bad = address_of(1 + 2)
}
```

Expected message: `address_of() only works on named values`

### R6: unsafe inside unsafe

```javascript
unsafe {
    unsafe {
    }
}
```

Expected message: `unsafe blocks cannot be nested: the enclosing unsafe block already allows unsafe operations`

### R7: invalid allocation size

```javascript
unsafe {
    let buf = alloc(0)
}
```

Expected message: `alloc() size must be a positive integer`

### R8: ordered compare across different allocations

```javascript
unsafe {
    let left = alloc(1)
    let right = alloc(1)
    defer(left)
    defer(right)
    let bad = left < right
}
```

Expected message: `ordered pointer comparisons need the same base allocation`

### R9: invalid pointer cast

```javascript
unsafe {
    let buf = alloc(1)
    defer(buf)
    let bad = float(buf)
}
```

Expected message: `pointers may only be cast to int`

### R10: memory that was never freed

```javascript
unsafe {
    let buf = alloc(4)
    store(buf, 1)
}
```

Expected message: `1 alloc() call(s) in this unsafe block were never freed; the first is at line 2`.
Write `defer(buf)` right after `alloc`, or call `free(buf)` before the block ends. When a function
with its own `unsafe` block is called from another block, each block checks the memory made inside it.

## Example 1: Basic Allocate, Store, Read

```javascript
unsafe {
    let buf = alloc(3)
    defer(buf)

    store(buf, 10)
    store(ptr_offset(buf, 1), 20)
    store(ptr_offset(buf, 2), 30)

    print(load(buf))
    print(load(ptr_offset(buf, 1)))
    print(load(ptr_offset(buf, 2)))
}
```

## Example 2: Editing a Variable Through `address_of()`

```javascript
let score = 5

unsafe {
    let p = address_of(score)
    let current = load(p)
    store(p, current + 10)
}

print(score)   # 15
```

## Example 3: Fill a Buffer with a Loop

```javascript
unsafe {
    let buf = alloc(5)
    defer(buf)

    for (let i = 0; i < 5; i++) {
        let slot = ptr_offset(buf, i)
        store(slot, i * i)
    }

    for (let i = 0; i < 5; i++) {
        print("slot", i, "=", load(ptr_offset(buf, i)))
    }
}
```

## Example 4: Compare Pointers Inside One Allocation

```javascript
unsafe {
    let buf = alloc(4)
    defer(buf)

    let a = buf
    let b = ptr_offset(buf, 1)
    let c = ptr_offset(buf, 2)

    print(a < b)
    print(b < c)
    print(c >= b)
}
```

## Example 5: Build and Scan a Small Table

```javascript
unsafe {
    let width = 3
    let height = 3
    let total = width * height
    let grid = alloc(total)
    defer(grid)

    for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
            let index = y * width + x
            let cell = ptr_offset(grid, index)
            store(cell, x + y)
        }
    }

    for (let y = 0; y < height; y++) {
        let row = []
        for (let x = 0; x < width; x++) {
            let index = y * width + x
            append(row, load(ptr_offset(grid, index)))
        }
        print(row)
    }
}
```
