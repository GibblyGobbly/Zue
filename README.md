<p align="center">
  <img src="assets/luna.png" alt="Luna logo" width="140">
</p>

<h1 align="center">Luna</h1>

<p align="center">
  A simple, blazing-fast programming language with JavaScript-like syntax that compiles directly to native machine code.
</p>

---

Luna is a compiled, self-hosted programming language with JavaScript-like syntax. The compiler is
written in Luna; it generates LLVM IR, and clang (LLVM) turns that into native machine code. A finished program is an
ordinary executable.

- Dynamically typed, with no implicit conversions: integer overflow is an error, and conditions
  must be booleans.
- Closures, modules, `data` / `template` / `bloc` / `box` types, and `unsafe` blocks for manual
  memory with safety rules.
- How it works inside is described in [docs/architecture.md](docs/architecture.md).

## What you need

| Tool | Why | Version |
|---|---|---|
| Linux on x86-64 | the only platform tested | any recent distribution |
| `clang` | turns LLVM IR into machine code | 18 (generated IR uses opaque pointers) |
| `make` | runs the build | any |
| C library development files (`libc6-dev` on Debian) | the C and math libraries linked into every program | glibc |
| `git` | to download the source | any |

```bash
# Debian / Ubuntu
sudo apt install clang make libc6-dev git

# Fedora
sudo dnf install clang make glibc-devel git

# Arch
sudo pacman -S clang make git
```

Check that `clang --version` reports 18. Optional extras: `llvm-18` (the `opt-18` tool checks
generated IR) and `valgrind`.

## Get Luna and build it

```bash
git clone https://github.com/Bharathsencha/The-Luna-Project.git luna
cd luna
make              # builds bin/luna
make test         # compiles and runs every test; the last lines say "passed N, failed 0"
```

`make` builds the compiler from the two seed files in `bootstrap/` (LLVM IR of the compiler and
the runtime), then rebuilds it once more and checks that the result is identical. To use `luna` from
anywhere, put `bin` on your path:

```bash
export PATH="$PWD/bin:$PATH"
```

## Hello, World

Save this as `hello.lu`:

```javascript
print("Hello, World!")
```

```bash
luna run hello.lu                  # build and run in one step
luna build hello.lu -o hello       # or build a program and run it yourself
./hello
```

| Command | Effect |
|---|---|
| `luna build prog.lu -o prog` | Compile to a native executable |
| `luna build prog.lu -S` | Write the LLVM IR to `C/prog.ll` and stop |
| `luna run prog.lu [args...]` | Build into `C/run/` and run; the exit status is the program's |
| `luna emit prog.lu [-o out.ll]` | Write the LLVM IR only |

Generated files go in a `C/` folder next to where you run `luna`.

## The language in ten minutes

Statements run from the top of the file, one after another. There are no semicolons.

### Variables and strings

`let` makes a variable, `const` a binding you mean to keep. Anything inside `{ }` in a
double-quoted string is calculated and put in. Write `\{` for a literal brace.

```javascript
let hp = 42
const NAME = "Astra"
hp += 8
print("{NAME} has {hp} HP, double is {hp * 2}")
```

### Numbers

Whole numbers are 64-bit. A result that does not fit is an error, never a silent wrap.
`/` between two whole numbers drops the fraction.

```javascript
print(7 / 2)        # 3
print(7.0 / 2)      # 3.5
print(7 % 3)        # 1
print(2 + 3 * 4)    # 14
```

### Decisions and loops

A condition must be `true` or `false`. `if (n)` is an error; write `if (n != 0)`.

```javascript
let n = 7
if (n % 2 == 0) {
    print("even")
} else {
    print("odd")
}

for (let i = 0; i < 3; i++) {
    print("i = {i}")
}

let items = ["a", "b", "c"]
for (let item in items) {
    print(item)
}

let k = 0
while (k < 3) {
    k++
}
print(k)
```

### Functions

Parameters can have default values. A function is a value and can be passed around.

```javascript
func greet(name, greeting = "Hello") {
    return "{greeting}, {name}!"
}

print(greet("Astra"))
print(greet("Astra", "Hi"))

func twice(f, x) {
    return f(f(x))
}
print(twice(func(n) { return n * 3 }, 2))   # 18
```

A function remembers the variables around it (a closure):

```javascript
func make_counter() {
    let count = 0
    return func() {
        count += 1
        return count
    }
}

let next = make_counter()
print(next())   # 1
print(next())   # 2
```

### Lists and maps

```javascript
let nums = [5, 3, 8]
append(nums, 1)
print(nums[0])          # 5
print(nums[-1])         # 1, negative indexes count from the end
print(len(nums))        # 4
sort(nums)
print(nums)             # [1, 3, 5, 8]
print(map(nums, func(n) { return n * 10 }))
print(filter(nums, func(n) { return n > 3 }))
print(reduce(nums, func(sum, n) { return sum + n }, 0))

let player = {"name": "Astra", "hp": 100}
print(player.name)
map_set(player, "hp", 125)
print(map_keys(player))
```

### Your own types

`data` groups named values.

```javascript
data Point { x, y }

let p = Point(3, 4)
print("({p.x}, {p.y})")
```

### Files and modules

Split a program over files and share names with `export`:

```javascript
# utils.lu
export func shout(text) {
    return to_upper(text) + "!"
}
```

```javascript
# main.lu
use { shout } from "utils.lu"
print(shout("hello"))
```

The full language is in [docs/syntax.md](docs/syntax.md), [docs/modules.md](docs/modules.md)
and [docs/data-types.md](docs/data-types.md).

## Math

```javascript
print(abs(-5))             # 5
print(min(2, 7))           # 2
print(max(2, 7))           # 7
print(pow(2, 10))          # 1024
print(sqrt(16))            # 4
print(floor(3.7))          # 3
print(round(2.5))          # 3
print(clamp(15, 0, 10))    # 10
print(sin(0))              # 0
print(rand(1, 6))          # a random whole number from 1 to 6, both included
```

## Strings

Strings are bytes with a length. Indexing gives a one-character value.

```javascript
let s = "Hello, Luna"
print(len(s))                       # 11
print(to_upper(s))                  # HELLO, LUNA
print(substring(s, 7, 4))           # Luna
print(index_of(s, "Luna"))          # 7
print(replace(s, "Luna", "World"))  # Hello, World
print(split("a,b,c", ","))          # [a, b, c]
print(join(["x", "y", "z"], "-"))   # x-y-z
print(trim("   padded  "))          # padded
print(pad_left("7", 3, "0"))        # 007
print(starts_with(s, "Hello"))      # true
print(s[0])                         # H
print(int("42") + 1)                # 43
print(to_string(3.5) + "!")         # 3.5!
```

All builtin functions are listed in [docs/builtins.md](docs/builtins.md).

## Small programs

The [examples](examples) folder has these ready to run with `luna run examples/<name>.lu`.

### Quicksort

```javascript
func quicksort(items) {
    if (len(items) <= 1) {
        return items
    }
    let pivot = items[0]
    let smaller = []
    let larger = []
    for (let i = 1; i < len(items); i++) {
        if (items[i] < pivot) {
            append(smaller, items[i])
        } else {
            append(larger, items[i])
        }
    }
    let result = quicksort(smaller)
    append(result, pivot)
    for (let x in quicksort(larger)) {
        append(result, x)
    }
    return result
}

let numbers = [34, 7, 23, 32, 5, 62, 32, 7, 1]
print("before: {numbers}")
print("after:  {quicksort(numbers)}")
```

```
before: [34, 7, 23, 32, 5, 62, 32, 7, 1]
after:  [1, 5, 7, 7, 23, 32, 32, 34, 62]
```

### More

| File | What it shows |
|---|---|
| [hello.lu](examples/hello.lu) | the smallest program |
| [fizzbuzz.lu](examples/fizzbuzz.lu) | loops and conditions |
| [primes.lu](examples/primes.lu) | a sieve over a list of booleans |
| [wordcount.lu](examples/wordcount.lu) | maps and `split` |
| [quicksort.lu](examples/quicksort.lu) | recursion and lists |

## Documentation

Everything is in [docs](docs/README.md): the language pages, the builtin functions, how the
compiler and the runtime work, the garbage collector, `unsafe` memory, and how to run and add
tests. [development](docs/development.md) lists the techniques and tools used to build and check the
front end, with results and credit.

## How Luna got here

Luna began as a tree-walking interpreter written in C: it read the program and acted on it
directly. That was simple but slow. Next came a bytecode virtual machine, which turned the
program into compact instructions first and ran them on a small machine; it was much faster,
and it came with its own garbage collector. The last step was to stop running programs at all:
Luna now compiles them to native code through LLVM, and the compiler and the runtime were
rewritten in Luna itself. Each step kept the same language and the same error messages; only
the way programs run changed.

## License

Luna is free software under the GNU General Public License, version 3 or (at your option) any
later version. The full text is in [LICENSE](LICENSE). Copyright (c) 2026 Bharath. Source files
start with an `SPDX-License-Identifier: GPL-3.0-or-later` line.

Compiled programs link the Luna runtime, which is part of this project.
