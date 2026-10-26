# Builtin Functions

Every builtin is a runtime function; the names are listed in `compiler/shared.lu`.

## Core
Builtins are always available and need no import. The compiler knows their names (the
`BUILTINS` list in `compiler/shared.lu`), and each one is implemented as a function named
`lb_<name>` in `compiler/runtime/`. Strings, math and files have their own pages:
[string](builtins.md#strings), [math](builtins.md#math), [file](builtins.md#files).

A call with the wrong number of arguments is an `Argument Error` such as
`min() expects 2 arguments, but got 1`. An argument of the wrong type is a `Type Error` such
as `sqrt() argument 1 must be a number, got string`.

### Values and types

| Function | Returns |
|---|---|
| `print(a, ...)` | Prints each argument on its own line; returns `null` |
| `input(prompt)` | One line read from standard input, without the newline, as a string; `""` at end of input. The prompt is optional (`input()`), and `input` is a keyword like `print` |
| `type(v)` | Type name: `"int"`, `"float"`, `"char"`, `"string"`, `"boolean"`, `"null"`, `"list"`, `"map"`, `"function"`, `"native_function"`, `"file"`, `"bloc"`, `"box"`, `"template"`, `"pointer"`. A dense list reports `"list"` and a `data` value reports `"map"` |
| `shape(v)` | Constructor name of a `data` / `bloc` / `template` value, for example `"Vec2"`; `null` for other values |
| `int(v)` | Integer from a float (truncated toward zero), char (its code), boolean (0 or 1) or string (the whole text must be a base-10 integer, otherwise an error). Also the only allowed pointer cast |
| `float(v)` | Float from an int, char, boolean or string (the whole text must be a number such as `"3.5"` or `"1e3"`, otherwise an error) |
| `to_string(v)`, `to_int(s)`, `to_float(s)` | Conversions (see [string](builtins.md#strings)) |
| `debug(v)` | Prints `value = <v>` and returns `v` unchanged, so it can wrap an expression |
| `assert(cond)` | Stops the program with `Assertion failed` when `cond` is false |
| `len(v)` | Length of a string, list, dense list, map or box; anything else is a `Type Error` |
| `clock()` | Monotonic time in seconds, as a float. The zero point is arbitrary: subtract two readings |
| `args()` | The command-line arguments after the program name, as a list of strings |
| `exit(code)` | Flushes standard output and ends the program with that status (default 0) |
| `system(cmd)` | Runs `cmd` with the shell and returns its exit status as an int |

Floats are printed with up to six significant digits and always show a point or an exponent (`print(1.0)` prints `1.0`).

### Lists

| Function | Effect |
|---|---|
| `append(list, v)` / `list_append(list, v)` | Add to the end |
| `remove(list, i)` | Remove and return the element at `i` (negative counts from the end); an index out of range is an `Index Error` |
| `find(list, v)` | Index of the first equal element, or `-1`. Lists only |
| `slice(list, a, b)` | New list of elements `a` to `b - 1`; the bounds are clamped, and `a >= b` gives `[]`. Also works on strings |
| `range(end)`, `range(start, end)`, `range(start, end, step)` | List of integers; `step` may be negative and must not be 0 |
| `map(list, fn)`, `filter(list, fn)`, `reduce(list, fn, init)` | Higher-order helpers; return new values. `reduce` needs all three arguments |
| `sort(list)` | In-place ascending sort of numbers or of strings; returns `null`. Mixing numbers and strings is an error |
| `shuffle(list)` | In-place Fisher-Yates shuffle |
| `ssort(list)` | Stalin sort, in place: deletes every element smaller than the last one kept, leaving a non-decreasing list. Returns `null`. Works on dense lists too |
| `dense_list(n, fill)` | Contiguous float list of `n` copies of the float `fill`, for vector math (see [math](builtins.md#math)) |

`contains(list, v)` and `join(list, sep)` also work on lists; see [string](builtins.md#strings).

### Maps

Maps use string keys. `m["k"]` and `m.k` read a key; `m["k"] = v` and `m.k = v` write one.

| Function | Effect |
|---|---|
| `map_set(m, key, v)` | Insert or replace |
| `map_get(m, key)` | Value for `key`, or `null` |
| `map_has(m, key)` | `true` if present |
| `map_delete(m, key)` | Remove; returns `true` if the key existed |
| `map_keys(m)`, `map_values(m)` | Lists of keys or values |
| `map_items(m)` | List of `[key, value]` pairs |

A `for-in` loop does not iterate a map directly: loop over `map_keys(m)`.

### Memory

`alloc`, `free`, `load`, `deref`, `store`, `ptr_offset`, `ptr_add`, `address_of` and
`defer(ptr)` work only inside `unsafe { }`; see [unsafe](unsafe.md).
`defer(call(...))` for scope cleanup works everywhere
([syntax](syntax.md#scope-cleanup-with-defer)). `free` also frees a
`box` (see [data-types](data-types.md)).

## Strings
Text manipulation, searching and formatting. All of these are builtins. Strings are
byte strings: `len("héllo")` is 6, and indexing is zero-based by byte. `to_upper` and
`to_lower` change ASCII letters only.

### Inspection

| Function | Description | Example |
|---|---|---|
| `len(x)` | Length of a string, list, map or box | `len("abc")` is `3` |
| `str_len(s)` | Length of a string (same as `len` for strings) | `str_len("abc")` is `3` |
| `is_empty(s)` | `true` if the string has length 0; a non-string is a `Type Error` | `is_empty("")` is `true` |
| `is_digit(s)`, `is_alpha(s)`, `is_alnum(s)`, `is_space(s)` | `true` if the string (or char) is non-empty and every character is in the class | `is_digit("123")` is `true`, `is_digit("1a")` is `false` |

### Slicing and access

| Function | Description | Example |
|---|---|---|
| `char_at(s, i)` | The character at index `i` as a one-character string; `""` when out of range | `char_at("ABC", 1)` is `"B"` |
| `substring(s, start, n)` | `n` characters starting at `start`; the result is cut at the end of the string | `substring("Hello", 0, 2)` is `"He"` |
| `slice(s, start, end)` | From `start` up to, not including, `end` (bounds are clamped) | `slice("Hello", 1, 4)` is `"ell"` |

`s[i]` returns a `char` (not a string): `"Luna"[0]` is `'L'` and `"Luna"[-1]` is `'a'`. A
`char` and a one-character string are different types: `'a' == "a"` is an error, but both
work with `contains`, `index_of`, `starts_with` and `ends_with`.

### Searching

| Function | Description | Example |
|---|---|---|
| `contains(s, sub)` | `true` if `sub` is found in `s`; also works on a list | `contains("Team", "ea")` is `true` |
| `index_of(s, sub)` | Index of the first occurrence, `-1` if none | `index_of("banana", "nan")` is `2` |
| `last_index_of(s, sub)` | Index of the last occurrence, `-1` if none | `last_index_of("banana", "a")` is `5` |
| `starts_with(s, pre)` | `true` if `s` starts with `pre` | `starts_with("file.txt", "file")` is `true` |
| `ends_with(s, suf)` | `true` if `s` ends with `suf` | `ends_with("file.txt", ".txt")` is `true` |

### Manipulation

| Function | Description | Example |
|---|---|---|
| `concat(s1, s2)` | Joins two strings; both must be strings | `concat("He", "llo")` is `"Hello"` |
| `to_upper(s)`, `to_lower(s)` | Case conversion (ASCII) | `to_upper("abc")` is `"ABC"` |
| `trim(s)`, `trim_left(s)`, `trim_right(s)` | Remove whitespace from both ends, the start or the end | `trim("  hi  ")` is `"hi"` |
| `replace(s, old, new)` | Replaces all occurrences of `old` with `new`. An empty `old` changes nothing | `replace("foobar", "o", "a")` is `"faabar"` |
| `reverse(s)` | Reverses a string (also a list) | `reverse("Luna")` is `"anuL"` |
| `repeat(s, n)` | `n` copies of `s`; `""` when `n` is 0 or less | `repeat("Na", 3)` is `"NaNaNa"` |
| `pad_left(s, w, ch)` | Pads the start of `s` with the character `ch` up to width `w` | `pad_left("7", 3, "0")` is `"007"` |
| `pad_right(s, w, ch)` | Pads the end of `s` | `pad_right("Ok", 5, ".")` is `"Ok..."` |
| `format(s, ...)` | Replaces each `{}` with the next argument; extra placeholders stay as `{}` | `format("Hi {}", "Luna")` is `"Hi Luna"` |
| `to_string(v)` | Text of any value | `to_string(12)` is `"12"` |
| `to_int(s)`, `to_float(s)` | Parse the whole text as a number (spaces around it are allowed). Text that is not a number, a value outside the 64-bit range, and the names `nan`, `inf` and hex digits are errors | `to_int("12")` is `12` |

`replace` always replaces every match; there is no single-occurrence version. `+` joins two
strings only: `"a" + 1` is a `Type Error`, so write `"a{1}"` or `"a" + to_string(1)`.

### Lists and strings

| Function | Description | Example |
|---|---|---|
| `split(s, delim)` | Splits into a list of strings. Empty pieces are dropped. An empty delimiter splits into characters | `split("a,b,c", ",")` is `["a", "b", "c"]` |
| `join(list, delim)` | Joins list items (converted to text) with the delimiter | `join(["a", "b", "c"], "-")` is `"a-b-c"` |

### Interpolation

A string literal evaluates any expression written inside `{ }` and inserts its text.

| Syntax | Result |
|---|---|
| `"Hello {name}"` | `"Hello Luna"` when `name` is `"Luna"` |
| `"sum = {1 + 2}"` | `"sum = 3"` |
| `"slot = {items[0]}"` | `"slot = 7"` when `items` is `[7]` |

The text inside `{ }` is parsed as a normal Luna expression. Write `\{` for a literal opening
brace. `format()` is still useful when you want positional `{}` placeholders.

Values print as follows: integers in decimal, floats with up to six significant digits
(`1.0` prints as `1.0`), `true` / `false`, `null`, lists as `[1, 2]` (strings inside a list are
not quoted), and maps as `{"key": value}`.

```javascript
let name = "Nova"
let hp = 87
let items = [3, 4]

print("Pilot {name} has {hp} hp")
print("next={hp + 1}, first={items[0]}")
print(replace("one one one", "one", "two"))
```

Output:

```
Pilot Nova has 87 hp
next=88, first=3
two two two
```

### Example: username validator

```javascript
func validate_username(username) {
    let clean = trim(username)
    if (is_empty(clean)) {
        print("Error: username cannot be empty")
        return false
    }
    let n = len(clean)
    if (n < 3) {
        print("Error: username too short (min 3 characters)")
        return false
    }
    if (n > 20) {
        print("Error: username too long (max 20 characters)")
        return false
    }
    if (is_digit(char_at(clean, 0))) {
        print("Error: username cannot start with a number")
        return false
    }
    print("username valid: {clean}")
    return true
}

validate_username("  john123  ")
validate_username("a")
validate_username("9gamer")
```

### Example: text formatter

```javascript
func format_title(text) {
    let upper = to_upper(text)
    let border = repeat("=", len(upper) + 4)
    print(border)
    print("| " + upper + " |")
    print(border)
}

func censor_text(text, bad_word) {
    return replace(text, bad_word, repeat("*", len(bad_word)))
}

format_title("welcome to luna")
print(join(["apples", "bread", "milk"], ", "))
print(censor_text("This is a darn good example", "darn"))
```

## Math
Numeric functions, random numbers, and vector math. All of these are builtins. Arguments must
be numbers (an int or a float); anything else is a `Type Error` such as
`sqrt() argument 1 must be a number, got string`. Luna has no infinity and no NaN: a call whose
argument is outside the function's domain is an `Argument Error` (`sqrt() argument must not be
negative`), and a float result that is too large is a `Runtime Error` (`float overflow in
exp()`, `float overflow in '*'`). Results that are not whole numbers print
with up to six significant digits, so `sqrt(2)` prints `1.41421`, and a float without a
fractional part prints with `.0` (`sqrt(16)` prints `4.0`).

### Basic utilities

| Function | Description | Example |
|---|---|---|
| `abs(x)` | Absolute value, same type as `x` | `abs(-10)` is `10` |
| `min(a, b)` | The smaller of two values; both ints or both floats | `min(10, 5)` is `5` |
| `max(a, b)` | The larger of two values; both ints or both floats | `max(10, 5)` is `10` |
| `min(list)`, `max(list)` | The smallest or largest item of a list of numbers. The list must not be empty and its items must all be ints or all be floats | `max([3, 1, 2])` is `3` |
| `sum(list)` | Sum of a list of numbers, same type as the items. Ints raise `integer overflow in 'sum'`; floats are added with Neumaier's compensated sum, so `sum([1.0, 1e100, 1.0, -1e100])` is `2.0` | `sum([1, 2, 3])` is `6` |
| `mean(list)` | Average of a list of numbers, always a float | `mean([1, 2, 4])` is `2.33333` |
| `gcd(a, b)` | Greatest common divisor of two ints, never negative; `gcd(0, 0)` is `0` | `gcd(-12, 18)` is `6` |
| `lcm(a, b)` | Least common multiple of two ints, never negative; `0` if either is `0`; overflow is an error | `lcm(4, 6)` is `12` |
| `isqrt(n)` | Exact integer square root, the largest `r` with `r * r <= n`; a negative `n` is an `Argument Error` | `isqrt(17)` is `4` |
| `clamp(x, lo, hi)` | Constrains `x` to the range `[lo, hi]`; `lo` greater than `hi` is an `Argument Error` | `clamp(15, 0, 10)` is `10` |
| `sign(x)` | `-1`, `0` or `1` | `sign(-50)` is `-1` |

### Powers and roots

All return a float except `pow` with two ints.

| Function | Description | Example |
|---|---|---|
| `pow(base, exp)` | `base` raised to `exp`. Two ints with `exp >= 0` give an exact int (`integer overflow in 'pow'` when it does not fit); otherwise a float. `pow(0, -1)` is a division-by-zero error, and a negative base with a fractional exponent is an `Argument Error` | `pow(2, 3)` is `8` (int), `pow(2.0, 0.5)` is `1.414...` |
| `sqrt(x)` | Square root; a negative argument is an `Argument Error` | `sqrt(16)` is `4.0` |
| `cbrt(x)` | Cube root | `cbrt(27)` is `3.0` |
| `exp(x)` | e raised to `x`; too large is a float overflow error | `exp(1)` is `2.718...` |
| `ln(x)` | Natural logarithm; `x <= 0` is an `Argument Error` | `ln(10)` is `2.302...` |
| `log10(x)` | Base-10 logarithm; `x <= 0` is an `Argument Error` | `log10(100)` is `2.0` |

### Rounding

Luna has no negative zero: `-0.0` and any result of `-0.0` is `0.0`.

`floor`, `ceil`, `round` (with one argument) and `trunc` return an int; a result outside the 64-bit int range is a
`Runtime Error` (`floor() result does not fit in a 64-bit int`). `fract` and `mod` return a float.

| Function | Description | Example |
|---|---|---|
| `floor(x)` | Rounds down | `floor(5.9)` is `5` |
| `ceil(x)` | Rounds up | `ceil(5.1)` is `6` |
| `round(x)` | Nearest integer, halves away from zero | `round(5.5)` is `6`, `round(-5.5)` is `-6` |
| `round(x, digits)` | A float rounded to `digits` decimal places (0 to 15), halves away from zero. The scaling is done in binary, so `1.005` (really `1.00499...`) rounds down. An int `x` is returned unchanged | `round(3.14159, 3)` is `3.142` |
| `trunc(x)` | Removes the fractional part (toward 0) | `trunc(5.9)` is `5` |
| `fract(x)` | The fractional part, with the sign of `x`, so `x == trunc(x) + fract(x)` | `fract(-5.9)` is `-0.9` |
| `mod(x, y)` | Floored remainder: the result has the sign of `y`, so `mod(-7, 3)` is `2` (while `-7 % 3` is `-1`). Both arguments are ints (result int) or both floats (result float); mixing is a Type Error. A zero divisor is an error | `mod(7, 3)` is `1`, `mod(5.5, 2.0)` is `1.5`, `float(mod(7, 3))` is `1.0` |
| `floor_div(x, y)` | Division rounding down, so `x == floor_div(x, y) * y + mod(x, y)`. Same argument rules; `INT_MIN` by `-1` is an overflow error | `floor_div(-7, 3)` is `-3` |
| `divmod(x, y)` | `[floor_div(x, y), mod(x, y)]` | `divmod(-7, 3)` is `[-3, 2]` |

### Trigonometry

Angles are in radians. All of these return a float.

| Function | Description |
|---|---|
| `sin(x)`, `cos(x)`, `tan(x)` | Sine, cosine, tangent |
| `asin(x)`, `acos(x)`, `atan(x)` | Inverse functions; `asin` and `acos` need `x` between -1 and 1, otherwise an `Argument Error` |
| `atan2(y, x)` | Arc tangent of `y / x` with the correct quadrant: `atan2(10, 10)` is `0.785...` |
| `sinh(x)`, `cosh(x)`, `tanh(x)` | Hyperbolic functions |
| `deg_to_rad(d)`, `rad_to_deg(r)` | Angle conversion: `deg_to_rad(180)` is `3.14159...` |
| `lerp(a, b, t)` | Linear interpolation: `lerp(0, 100, 0.5)` is `50.0` |

### Random numbers

| Function | Description |
|---|---|
| `rand()` | A float in `[0, 1)` |
| `rand(max)` | An integer from `0` to `max`, both ends included; `max` must be an int |
| `rand(min, max)` | An integer from `min` to `max`, both ends included (swapped if `min > max`); both must be ints |
| `srand(seed)` | Seeds the generator, for reproducible sequences; `seed` must be an int. `srand()` reseeds from the OS |
| `trand()` | A 64-bit integer read from the OS entropy source (`/dev/urandom`) |

The generator is xoroshiro128++, and `srand` expands the seed with SplitMix64. Without `srand`,
every program run starts from an OS-entropy seed. `shuffle(list)` and `sort(list)` are in
[core](builtins.md).

```javascript
srand(7)
print(rand(1, 100))   # 17
print(rand(1, 100))   # 100
```

Numbers from a seed are fixed by the generator, so the same seed gives the same numbers on
every run.

### Dense lists and vector math

A dense list is a contiguous array of floats, created with `dense_list(n, fill)` (the fill
value must be a float). It prints as `d[...]`, its `type()` is `list`, indexing works as on a
list, and its size is fixed: `append` does not accept it.

| Function | Description |
|---|---|
| `dense_list(size, fill)` | `dense_list(3, 1.5)` is `d[1.5, 1.5, 1.5]` |
| `vec_add(a, b)`, `vec_sub(a, b)`, `vec_mul(a, b)`, `vec_div(a, b)` | Element-wise operation on two lists of numbers of the same length; returns a new dense list. Different lengths, a non-number element, a division by zero and a float overflow are errors |
| `vec_mul_inline(a, b)` | Multiplies dense list `a` by dense list `b` in place, without allocating; both must have the same length |
| `mat_mul(a, b)` | Matrix product of two lists of rows (lists or dense lists); returns a list of dense rows |

`+ - * /` between two lists of numbers do the same as the `vec_*` functions:
`[1, 2] + [3, 4]` is `d[4, 6]`.

```javascript
print(vec_mul([1, 2], [3, 4]))                      # d[3, 8]
print(mat_mul([[1, 2], [3, 4]], [[5, 6], [7, 8]]))  # [d[19, 22], d[43, 50]]
```

`mat_mul` is a plain triple loop that runs on one thread. If the column count of `a` does not
equal the row count of `b`, it is an `Argument Error` (`mat_mul() dimension mismatch`).

### Example: distance between two points

```javascript
func distance(x1, y1, x2, y2) {
    let dx = x2 - x1
    let dy = y2 - y1
    return sqrt(pow(dx, 2) + pow(dy, 2))
}

print(distance(0, 0, 3, 4))   # 5
```

### Example: dice statistics

```javascript
func roll_dice(num_rolls) {
    srand(42)
    let total = 0
    let lowest = 6
    let highest = 1
    for (let i = 0; i < num_rolls; i++) {
        let roll = rand(1, 6)
        total += roll
        lowest = min(lowest, roll)
        highest = max(highest, roll)
    }
    print("total {total}")
    print("average {float(total) / float(num_rolls)}")
    print("min {lowest}, max {highest}")
}

roll_dice(10)
```

### Example: shuffle and sort

```javascript
let deck = range(1, 11)
shuffle(deck)
print(len(deck))      # 10
sort(deck)
print(deck)           # [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
```

## Files
Text files, through the C library's buffered streams. File paths are relative to the working
directory of the running program, not to the source file.

### Reference

| Function | Description |
|---|---|
| `open(path, mode)` | Opens a file in mode `"r"`, `"w"` or `"a"`. Returns a file handle, or `null` if it cannot be opened. Any other mode is an `Argument Error` |
| `close(handle)` | Flushes and closes the file. Closing twice is a runtime error |
| `write(handle, text)` | Writes a string to the file |
| `read(handle)` | Reads the rest of the file into one string |
| `read_line(handle)` | Reads the next line without its newline; `null` at end of file |
| `file_exists(path)` | `true` if the path exists |
| `remove_file(path)` | Deletes the file; `true` on success, `false` on failure |
| `flush(handle)` | Writes buffered data out without closing the file |

A file handle has `type()` `"file"`. Using a handle after `close` is a runtime error
(`write() on a closed file`, `close() on a closed file`). Handles are not closed
automatically, so close every file you open, or use `defer(close(f))`.

### Modes

| Mode | Behavior |
|---|---|
| `"r"` | Reads an existing file. `open` returns `null` if it does not exist |
| `"w"` | Creates the file or truncates an existing one |
| `"a"` | Appends to the file, creating it if needed |

### Checking a handle

Conditions must be booleans, so compare the handle with `null`; `if (file)` is a type error.

```javascript
let file = open("data.txt", "w")
if (file != null) {
    write(file, "Header\n")
    write(file, "\tIndented item\n")
    write(file, "Quote: \"Hello World\"\n")
    close(file)
} else {
    print("Failed to open file.")
}
```

Escape sequences such as `\n`, `\t` and `\"` are part of the string literal, not of `write`.

### Reading

Whole file:

```javascript
let reader = open("data.txt", "r")
if (reader != null) {
    print(read(reader))
    close(reader)
}
```

Line by line:

```javascript
let file = open("data.txt", "r")
if (file != null) {
    let line = read_line(file)
    while (line != null) {
        print("Line: {line}")
        line = read_line(file)
    }
    close(file)
}
```

`read()` loads everything into memory; for large files prefer `read_line()`.

### Existence and deletion

```javascript
if (file_exists("old.txt")) {
    remove_file("old.txt")
}
```

### Example: a small configuration file

```javascript
let path = "app.cfg"

let cfg = open(path, "w")
if (cfg == null) {
    print("[ERROR] cannot create {path}")
    exit(1)
}
write(cfg, "mode=production\n")
write(cfg, "threads=8\n")
flush(cfg)
close(cfg)

let reader = open(path, "r")
let count = 0
let line = read_line(reader)
while (line != null) {
    let parts = split(line, "=")
    print("{parts[0]} -> {parts[1]}")
    count += 1
    line = read_line(reader)
}
close(reader)
print("[OK] loaded {count} entries")

remove_file(path)
```

Output:

```
mode -> production
threads -> 8
[OK] loaded 2 entries
```

### Best practices

1. Compare the result of `open` with `null` before using it.
2. Close every file, or `defer(close(f))` right after opening it.
3. `read_line` returns `null` at the end of the file, and an empty line is `""`.
4. Check `file_exists` before `remove_file` if you need to tell the two cases apart.
