# Modules

A module is any `.zu` file. It marks its public names with `export`. Everything else stays
private to the file.

```javascript
# math_mod.zu
export let BASE = 10
export func scale(x) {
    return x * BASE
}
```

Bring in the whole file:

```javascript
# main.zu
use "math_mod.zu"
print(scale(4))     # 40
print(BASE)         # 10
```

Or pick only the names you need:

```javascript
use { scale } from "math_mod.zu"
print(scale(4))     # 40
```

Either way, only exported names are visible. A name the module does not export is undefined
in the importing file, even with `use "file.zu"`.

## Rules

- **Paths are relative to the importing file**, not the working directory. A module in
  `sub/wrapper.zu` that writes `use { x } from "../helper.zu"` finds `helper.zu` next to `sub/`.
- **Modules are part of the binary.** The compiler reads every imported file while it compiles
  the program, and compiles it into the same executable. The `.zu` files are not read again at
  run time, and a program built from `main.zu` runs without the sources next to it. A file
  that cannot be read at compile time is reported when the `use` statement runs, not when the
  program is compiled: `Could not import file 'nope.zu'`.
- **Each file runs once.** The first `use` executes the module's top-level statements. Later
  imports, from any file, reuse the same bindings. Module-level state therefore persists: an
  exported counter function keeps counting across every importer.
- **Only exported names are visible.** Asking for a name the module does not export with
  `use { name } from` is an error: `Module 'helper.zu' does not export 'hidden'`. Using a name
  that was never imported is `Variable 'name' is not defined`.
- **Circular imports are reported** as an error (`Circular import detected: 'a.zu' is already
  loading`) instead of recursing.
- `import "util.zu"` is an older spelling of `use "util.zu"`: it brings in the exported names
  only.
- An imported name is a copy of the module's binding made when `use` runs. If the module
  later reassigns an exported variable, the importer's copy does not change. Export a function
  that reads or updates the state instead (see below).

## State shared between modules

Exported constants and functions are safe to share. A module's own variables stay in the
module, and its exported functions see and change them:

```javascript
# counter.zu
let n = 0
export func bump() {
    n += 1
    return n
}
```

For state that several modules change, keep the data in a list or map owned by one module
and pass it to the functions that need it.

## Tests

- `test/test_modules.zu`: constants, cross-module calls, persistent state through a wrapper
- `test/test_use_file.zu`: `use "file.zu"` and `use { name } from` on the same module
- `test/test_use_private_error.zu`: a non-exported name is undefined after `use "file.zu"`
- `test/test_import_private_error.zu`: the same for `import`
- `test/test_qol.zu`: `import` and `use` together
