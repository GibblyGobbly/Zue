# Syntax

Zue's syntax looks like JavaScript, without semicolons. One statement per line; blocks use
`{ }`. Comments start with `#` or `//`.

```javascript
# comment
// also a comment
let name = "Zue"
print("Hello, {name}!")
```

A program is compiled to a native executable (see [getting-started](getting-started.md)), then
its top-level statements run in order. Names are looked up when the statement runs: a `func`
is defined when execution reaches it, so calling a function above its definition at the top
level is a `Name Error`. A function may call another one that is defined later in the file, as
long as the call happens after that definition has run.

## Values and types

| Literal | `type()` |
|---|---|
| `42`, `-7`, `9223372036854775807` (integers are 64-bit) | `int` |
| `1.5`, `3.0` | `float` |
| `'c'` | `char` |
| `"text"` | `string` |
| `true`, `false` | `boolean` |
| `null` | `null` |
| `[1, 2, 3]` | `list` |
| `{"key": value}` | `map` |
| `func(x) { return x }` | `function` |
| builtins such as `len` | `native_function` |

Other values report `file` (from `open`), `bloc`, `box`, `template`, `pointer` (inside
`unsafe`), and `map` for a `data` value.

`dense_list(n, init)` creates a contiguous float list for vector math (see
[math](builtins.md#math)); its `type()` is `list`. `data`, `bloc`, `box` and
`template` define structured values (see [data-types](data-types.md)).

Number literals are decimal (`42`), hexadecimal (`0xFF`), binary (`0b1010`) or floating point
(`3.14`, `1e3`, `2.5e-4`). A single `_` may separate digits (`1_000_000`, `0x7FFF_FFFF`). A number
followed directly by a letter (`12abc`) or a value that does not fit in 64 bits is a syntax error.

`/` follows the operand types: two ints give an int that truncates toward zero (`7 / 2` is `3`,
`-7 / 2` is `-3`), and if either side is a float the result is a float (`7 / 2.0` is `3.5`).
`%` takes the sign of the left operand (`-10 % 3` is `-1`) and also works on floats
(`10.5 % 3` is `1.5`).

Floats print with up to six significant digits, as C's `%g` does, and always show that they are
floats: `print(1.0)` prints `1.0`, `print(100.0 / 3)` prints `33.3333` and `print(1234567.0)` prints
`1.23457e+06`.

## Variables

```javascript
let x = 10
const version = "0.1"
x = 20
x += 5                    # also -=, *=, /=, %=
x++
x--
```

`x++` and `x--` used as a value give the old value; `++x` and `--x` give the new one. A name is
declared once per scope: `let x = 1` twice in the same block is a syntax error, but an inner
block may declare its own `x`. Parameters count as declared in the body of their function, and
a standalone `{ ... }` block is a scope of its own.

`const` declares a binding that is meant to stay fixed; reassigning it is currently not
rejected by the compiler.

## Strings

Double-quoted strings interpolate any expression inside `{ }`:

```javascript
let hp = 125
print("next hp = {hp + 1}")           # next hp = 126
print("slot = {[3, 7, 9][1]}")        # slot = 7
```

Escapes: `\n`, `\t`, `\r`, `\"`, `\'`, `\\`, `\{` and `\}`. Any other character after a backslash
is a syntax error. A `{` starts an interpolation, so a literal brace is written `\{` (`{}` with
nothing between is kept as it is). The expression inside `{ }` may contain strings of its own:
`"{len("abc")}"`. A string may span lines. A character literal holds exactly one character or
one escape: `'a'`, `'\n'`, `'\t'`, `'\r'`, `'\0'`, `'\\'`, `'\''`. Only ASCII characters are allowed
outside strings and comments.

Indexing a string returns a `char`, and negative indices count from the end: `"Zue"[0]` is
`'Z'` and `"Zue"[-1]` is `'e'`. The library is in [string](builtins.md#strings).

## Operators

| Kind | Operators |
|---|---|
| Arithmetic | `+ - * / %`, unary `-` |
| Power | `**`, the same as `pow`: `2 ** 10` is `1024`. It is right-associative and binds tighter than a unary minus on its left, so `2 ** 3 ** 2` is `512` and `-2 ** 2` is `-4`. An int to a negative int power is an `Argument Error` (use floats) |
| Bitwise | `& \| ^ << >> ~`, ints only. `~x` is `x ^ -1`. A shift count must be 0 to 63, `>>` keeps the sign, and `<<` that would lose bits is an overflow error. They bind tighter than comparisons (so `x & 1 == 1` works), unlike C |
| Comparison | `== != < <= > >=` |
| Logical | `and` / `&&`, `or` / `\|\|`, `not` / `!` (short-circuit). `not` binds looser than a comparison and tighter than `and`: `not a == b` is `not (a == b)` |
| Assignment | `= += -= *= /= ++ --` |

Operators do no hidden conversions. From loosest to tightest: `or`, `and`, `== !=`, `< <= > >=`,
`|`, `^`, `&`, `<< >>`, `+ -`, `* / %`, then `**` and the unary operators.

| Rule | Example | Result |
|---|---|---|
| Numbers mix: int with float gives a float | `1 + 1.5` | `2.5` |
| `+` joins two strings only | `"a" + 1` | error: build text with `"a{1}"` or `"a" + to_string(1)` |
| Other types don't do arithmetic | `null + 1`, `1 + true` | error |
| Integer overflow is an error, never a wrap-around | `9223372036854775807 + 1` | `integer overflow in '+'` |
| Division or `%` by zero is an error | `1 / 0`, `5 % 0` | `division by zero` |
| `==` / `!=` need the same kind of value; comparing with `null` always works | `1 == "1"` | error |
| `<`, `<=`, `>`, `>=` order two numbers, two strings or two chars | `1 < "a"` | error |
| Conditions (`if`, `while`, `for`, `and`, `or`, `not`) must be booleans | `if (5)` | `condition must be a boolean, got int`: write `if (x != 0)` or `if (len(s) > 0)` |

`1 == 1.0` is `true`. Two lists or maps are equal only when they are the same object.

Between two lists of numbers, `+ - * /` work element by element and return a dense list:
`[1, 2] + [3, 4]` gives `d[4, 6]`.

## Lists and maps

```javascript
let l = [1, 2, 3]
l[-1] = 99                 # negative index from the end
append(l, 4)
print(len(l))

let player = {"name": "Astra", "hp": 100}
print(player["name"], player.hp)   # key or field syntax
map_set(player, "hp", 125)
```

Map keys are strings. Reading or writing a list index outside `0 .. len - 1` (or the negative
equivalent) is an `Index Error`; a list does not grow by assignment. Use `append`.

Map and list functions are listed in [core](builtins.md).

## Control flow

```javascript
if (hp <= 0) {
    print("down")
} else if (hp < 50) {
    print("low")
} else {
    print("ok")
}

while (i < 10) {
    i += 1
}

for (let k = 0; k < 3; k++) {
    print(k)
}

for (let item in [1, 2, 3]) {
    print(item)
}

switch (choice) {
    case 1:
        print("one")
        break
    case 2:
        print("two")
        break
    default:
        print("other")
}
```

`break` and `continue` work in all loops. `for-in` iterates a list, a dense list or a string
(one `char` at a time); to walk a map use `map_keys`, `map_values` or `map_items`.
`range(start, end, step)` builds a list of integers. A `switch` case does not fall through to
the next case, and `break` inside a `switch` leaves it.

A `for-in` or `while` body gets a fresh scope on each iteration, so closures created in the
body capture that iteration's variables. The variable of a C-style `for (let i = ...; ...)`
loop is a single variable shared by every iteration.

## Functions

```javascript
func greet(name, greeting = "Hello") {    # default parameter
    return "{greeting}, {name}"
}

let inc = func(x) { return x + 1 }        # anonymous function

func make_counter() {                     # closure
    let count = 0
    return func() {
        count += 1
        return count
    }
}
```

Functions are values: pass them, return them, and store them in lists. A function without
`return` gives `null`. Calling with the wrong number of arguments is an `Argument Error`
(`f() expects 1 argument, but got 2`). `map`, `filter` and `reduce` take functions:

```javascript
let doubled = map([1, 2, 3], func(x) { return x * 2 })
let total = reduce(doubled, func(acc, x) { return acc + x }, 0)
```

If the file defines a zero-argument `main()`, it runs automatically after the top level.

Recursion is limited to 100000 nested calls; beyond that the program stops with
`stack overflow: recursion is too deep`.

## Scope cleanup with defer

`defer(call(...))` runs the call when the current scope exits, in LIFO order:

```javascript
func save(path, text) {
    let f = open(path, "w")
    defer(close(f))
    write(f, text)
}
```

Inside `unsafe { }`, `defer(ptr)` frees a pointer instead (see
[unsafe](unsafe.md)).

## Output and input

```javascript
print("a")               # one line
let name = input("Name: ")
```

`print` and `input` are ordinary functions, so `let p = print` and `apply(print, x)` work. When
`print` receives several arguments, it prints each one on its own line. Use interpolation for one-line output:
`print("{a} {b}")`. `input(prompt)` writes the prompt and returns one line from standard
input without the newline, or `""` at end of input.

## Keyword aliases

Every keyword below is an exact synonym, mapped in the lexer:

| Alias | Keyword |
|---|---|
| `balls`, `big_balls`, `shared_balls` | `let` |
| `grab_balls` | `func` |
| `if_balls` / `else_balls` | `if` / `else` |
| `spin_balls` | `while` |
| `loop_your_balls` | `for` |
| `switch_balls` | `switch` |
| `drop_balls` | `break` |
| `jiggle_balls` | `continue` |

```javascript
balls x = 10
spin_balls (x < 20) {
    x = x + 1
}
grab_balls area(w, h) {
    return w * h
}
```

`test/balls.zu` covers them.

## Names to avoid

The words `template`, `bloc`, `box`, `unsafe`, `use`, `export`, `import`, `case` and `default`
are keywords and cannot be used as variable or function names. `data`, `in` and `from` are
keywords only where they mean something (`data Name {`, `for (let x in xs)`, `use {a} from`) and
are ordinary names everywhere else. After a `.` any word is a field name: `m.data`, `m.in`.

## Line breaks

A statement ends at the end of its line. A line continues when it ends with a binary operator
or a comma, or when it is inside `( )`, `[ ]` or a `{ }` literal, where line breaks are ignored.
Trailing commas are allowed in lists, maps, calls, parameter lists and `use` lists.

```javascript
let total = 1 +
    2 +
    3
let xs = [
    1,
    2,
]
```

`return` followed by a line break returns nothing: the value must start on the same line.

## Next

- [modules](modules.md): `use`, `export`, `import`
- [data-types](data-types.md): `data`, `bloc`, `box`, `template`
- [unsafe](unsafe.md): manual memory

## Type checking

The compiler checks the types of the main program before it builds it. A mistake it can prove is
a `Type Error` with the line, and the program is not built.

- A variable has the type of its first value and keeps it: after `let x = 10`, `x = "a"` and
  `x = 2.5` are errors. A variable that starts as `null` or has no value (`let x`) takes the type
  of the first value assigned to it.
- A number written in the source adapts to the type it is used as: `sqrt(16)` and `2.5 * 2` are
  fine. A variable never converts: with `let n = 16`, `sqrt(n)` and `n + 1.5` are errors. Write
  `sqrt(float(n))` to convert on purpose.
- Operators need operands of the same type. `"a" + 1`, `"a" * 2`, `-"a"`, `1 == "a"` and
  `3 == 3.0` for a variable are errors, and so is dividing by a zero written in the source.
- `if`, `while`, `for`, `not`, `and` and `or` need a `bool`.
- The math builtins check their arguments: `sqrt(float)`, `pow(int, int)` or `pow(float, float)`,
  `floor(float)` giving an int, `rand(int)`, and so on.
- A function you write is checked at each call, with its parameters bound to the argument types:
  `area(2, "a")` is an error at the call when the body does `w * h`, and the message names the
  call (`in area(int, string), called at line 3`). A call with a number written in the source gives
  that parameter the plain type (`16` is an int, `16.0` a float). The type of a call is the type
  its `return` statements give; a recursive call needs a base case that returns first.
- A list or map literal whose items all have one type has that element type: `[1, 2, 3]` is a
  `list<int>` and `{"a": 1.5}` is a `map<float>`. Reading an item gives the element type, and storing
  or appending another type is an error: after `let xs = [1, 2]`, `xs[0] = "a"` and `append(xs, "a")`
  fail. A list of mixed items, or an empty list, is a plain `list` whose items are not checked.
- A type can be written after a colon on a variable, a parameter or a field: `let xs: list<float> = [1, 2]`,
  `func total(v: list<int>, n: int = 0)`, `template Bag { items: list<int> }`. `list` and `map` take an
  element type in angle brackets and may nest (`map<list<int>>`). The type names are `int`, `float`,
  `bool`, `char`, `string`, `list`, `map`, `function` and the name of a `bloc` or `template`. A plain
  `list` annotation keeps the items unchecked. Whole numbers in the source become floats where a
  float is wanted, so `let xs: list<float> = [1, 2]` holds floats.
- Fields of a typed `bloc` or `template` have their declared types when read (`p.hp` is an int) and
  when assigned (`p.hp = "a"` is an error).
- Builtins with a fixed result type give it: `len` is an int, `split` is a `list<string>`, `range` is a
  `list<int>`, `min`, `max` and `sum` of a `list<int>` are ints.
- Imported modules are checked too, with the error naming the module's file.
- Where the checker cannot tell a type (items of a plain list, the result of a function whose returns
  differ, function values, values from imported modules), it says nothing and the runtime checks
  still apply. The element types are not checked at run time: a list that was handed over by code the
  checker cannot see may hold other items.

### Strict mode

A file whose first lines, before any code, include the comment `# strict` is checked more strictly.
Every parameter needs a type, and a value whose type the checker cannot tell is an error where it is
used: as an operand, in a condition, as an argument of a builtin or of a typed parameter, as the value
given to an untyped `let`, or as the target of an index or a field read. Writing the type
(`let y: int = xs[0]`) is the way to say what the value is. Comparing with `null` is allowed.

### Raw values

A local variable that the checker proves to be an `int`, `float` or `bool`, and that no nested function
uses and no `address_of` call touches, is kept as a raw machine value instead of a 16-byte value.
Expressions made only of such variables and literals are computed without type tests. The results,
errors and line numbers are the same as for the general code. A value that comes from code the checker
cannot see is tested when it is stored: `variable 'n' must be an int, got string`.
