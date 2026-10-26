# Getting Started

Zue is a compiled language. The Zue compiler turns a program into LLVM IR, and `clang` turns
the IR into a native executable.

## Choosing the LLVM version

`make` uses `clang` (18 here). To build and test with another installed version, pass it by number:
`make LLVM=22` and `make test LLVM=22` use `clang-22` and `opt-22`. Objects built by one version are
not reused by another, so run `make clean` when switching. `bench/numeric_benchmarks.sh 22 -O2`
times the programs in `bench/numeric` with a chosen version and optimization level.

## Requirements

Linux. The project is developed and tested on x86-64 with glibc.

| Tool | Used for |
|---|---|
| `clang` (LLVM 18) | Compiling the generated IR and the runtime, and building the first compiler from the seeds |
| `make` | Building `bin/zue` and running the tests |

Compiled programs link libc, libm, libpthread and libdl.

On Ubuntu or Debian:

```bash
sudo apt install clang make libc6-dev
```

## Build

```bash
make            # builds bin/zue (parallel by default)
make test       # compiles and runs every test
make seed       # refreshes bootstrap/*.ll after changing compiler/ or compiler/runtime/
make clean      # removes bin/ and C/
```

`make` does this, in order:

1. Builds a seed compiler from `bootstrap/zuec.ll` and `bootstrap/zue_rt_native.ll` with clang.
2. Uses it to compile the runtime and the compiler sources of the working tree.
3. Builds that compiler (stage 1), uses it to compile the compiler again (stage 2), and
   requires the two IR files to be identical.
4. Copies stage 1 to `bin/zue`.

If the seeds are older than the sources, `make` prints a `[WARN]`. Run `make seed` and commit
the new seeds together with the change that needs them. See [architecture](architecture.md).

## Use

```bash
./bin/zue build prog.zu -o prog     # native binary
./prog

./bin/zue run prog.zu a b           # build into C/run/prog and run it with arguments a and b
./bin/zue emit prog.zu              # write the LLVM IR to C/prog.ll
./bin/zue build prog.zu -S          # same, through build
```

| Command | Effect |
|---|---|
| `zue build prog.zu -o out` | Write `C/prog.ll`, then build `out` with clang. Without `-o` the output is named after the file |
| `zue build prog.zu -S` | Write `C/prog.ll` and stop |
| `zue run prog.zu [args...]` | Build into `C/run/prog`, run it, and exit with its status |
| `zue emit prog.zu [-o out.ll]` | Write the IR only; the default is `C/prog.ll` |

Generated IR is written to a `C/` directory in the current directory (it is git-ignored in this
repository), so it can be read before a binary exists. Set `CC` to use another C compiler
driver for the final step (the default is `clang`).

### Where zue finds the runtime

`zue` finds `compiler/runtime` and `compiler/build_runtime.sh` next to its own binary: the
directory above the one holding `zue` (`bin/zue` finds the project it was built in). Set
`ZUE_HOME` to use another tree. The first build also compiles the runtime to
`C/zue_rt_native.o` in that tree; it is rebuilt only when a runtime or compiler source is newer.
The project folder may contain spaces, and so may program names.

### A first program

```javascript
let name = input("Name: ")
print("Hello, {name}!")

func main() {           # runs automatically after the top level
    for (let i in range(3)) {
        print("tick {i}")
    }
}
```

`input` returns one line from standard input, without the newline (or `""` at end of input).
`args()` returns the command-line arguments after the program name as a list of strings.
`exit(code)` stops the program with that status.

### Errors

A syntax error stops the compile: `zue` prints the message and exits with status 1, and no
binary is written. A runtime error (type error, index error, division by zero, ...) prints the
message with the source line to standard error and the program exits with status 1:

```
Type Error in prog.zu at line 1:
  cannot use '+' on string and int

   1 | print("a" + 1)

Hint: Both sides must be numbers, or both strings. Build text with "{x}" or to_string(x).
```

## Verify

```bash
make test
compiler/run_tests.sh test/test_core.zu     # one test
```

See [testing](testing.md).

## Next

- [syntax](syntax.md): the language
- [builtins](builtins.md): the builtin functions
- [architecture](architecture.md): how the pieces fit
