# Strings

Every string function in Zue, with five complete programs that show how they fit together. The
short reference is in [builtins](builtins.md#strings); this page lists everything in one place and
explains it.

## The rules

| Rule | What it means |
|---|---|
| A string is a sequence of bytes | `len("héllo")` is 6. Indexing counts bytes. `to_upper` and `to_lower` change ASCII letters only |
| Strings never change | Every function returns a new string. `s[0] = "x"` is an error |
| `s[i]` gives a `char` | `"Zue"[0]` is `'Z'`; `"Zue"[-1]` is `'e'`. A `char` and a one-letter string are different: `'a' == "a"` is an error |
| `+` joins strings only | `"a" + 1` is a `Type Error`. Write `"a{1}"` or `"a" + to_string(1)` |
| No hidden conversion | `to_int`, `to_float` and `to_string` do it on purpose, and a bad text is an error, never `0` |
| Positions in `s[a:b]` start at 1 | Both ends are included. Everywhere else, positions start at 0 |

### Interpolation

Any expression inside `{ }` in a string literal is evaluated and its text inserted:
`"sum = {1 + 2}"` is `"sum = 3"`. Write `\{` for a literal brace.

### Slices with `s[a:b]`

| Code | Result for `s = "bug"` |
|---|---|
| `s[1:3]` | `bug` |
| `s[2:3]` | `ug` |
| `s[:2]` | `bu` (from the first position) |
| `s[2:]` | `ug` (to the last position) |
| `s[:]` | `bug` |

A start of 0 or less, an end past `len`, or a start after the end is an `Index Error`. The builtin
`slice(s, start, end)` follows the same rules: `slice(s, 2, 3)` is `s[2:3]`.

## Function reference

### Inspection

| Function | Returns | Notes |
|---|---|---|
| `len(x)`, `str_len(s)` | int | Length in bytes |
| `is_empty(s)` | bool | A non-string is a `Type Error` |
| `is_digit(s)`, `is_alpha(s)`, `is_alnum(s)`, `is_space(s)` | bool | `true` when the text (or char) is not empty and every character is in the class |

### Access and slicing

| Function | Returns | Notes |
|---|---|---|
| `s[i]` | char | Zero-based; a negative `i` counts from the end |
| `char_at(s, i)` | string | One character; `""` when out of range |
| `substring(s, start, n)` | string | `n` bytes from `start`, cut at the end |
| `slice(s, start, end)` | string | Positions from 1, both ends included; same as `s[a:b]` |
| `s[a:b]` | string | Positions from 1, both ends included |

### Searching

| Function | Returns | Notes |
|---|---|---|
| `contains(s, sub)` | bool | Also works on a list |
| `index_of(s, sub)` | int | First match, `-1` if none. An optional third argument is the start index |
| `last_index_of(s, sub)` | int | Last match, `-1` if none |
| `index_of_any(s, set)` | int | First byte that is in `set`, `-1` if none. Optional `start` |
| `skip_chars(s, set)` | int | First byte that is not in `set`, or `len(s)`. Optional `start` |
| `starts_with(s, pre)`, `ends_with(s, suf)` | bool | |

`index_of_any` and `skip_chars` scan in native code, so they are the fast way to walk over a run of
characters (the lexer uses them).

### Changing text

| Function | Returns | Notes |
|---|---|---|
| `to_upper(s)`, `to_lower(s)` | string | ASCII letters only |
| `trim(s)`, `trim_left(s)`, `trim_right(s)` | string | Remove spaces, tabs and line breaks |
| `replace(s, old, new)` | string | Replaces every match. An empty `old` changes nothing |
| `reverse(s)` | string | Also works on a list |
| `repeat(s, n)` | string | `""` when `n` is 0 or less |
| `pad_left(s, w, ch)`, `pad_right(s, w, ch)` | string | Pad to width `w` with the character `ch` |
| `concat(a, b)` | string | Both must be strings |

### Converting

| Function | Returns | Notes |
|---|---|---|
| `to_string(v)` | string | Any value |
| `to_int(s)`, `to_float(s)` | int, float | The whole text must be a number. Spaces around it are allowed. Anything else is an error |
| `int(s)`, `float(s)` | int, float | The same rules for strings; they also take other types |

### Strings and lists

| Function | Returns | Notes |
|---|---|---|
| `split(s, delim)` | list | Empty pieces are dropped. An empty `delim` splits into characters |
| `join(list, delim)` | string | Items are converted to text |

## Programs

Each program below was run, and the output shown is what it printed.

### Program 1: Checking text

Validating user names and passwords with the character classes.

```javascript
# Checking text: trim, len, is_* classes, starts_with, contains

func check_password(pw) {
    if (len(pw) < 8) {
        return "too short"
    }
    let has_digit = false
    let has_alpha = false
    let has_space = false
    for (let i = 0; i < len(pw); i++) {
        let c = pw[i]
        if (is_digit(c)) {
            has_digit = true
        }
        if (is_alpha(c)) {
            has_alpha = true
        }
        if (is_space(c)) {
            has_space = true
        }
    }
    if (has_space) {
        return "no spaces allowed"
    }
    if (not has_digit) {
        return "needs a digit"
    }
    if (not has_alpha) {
        return "needs a letter"
    }
    return "ok"
}

func check_username(raw) {
    let name = trim(raw)
    if (is_empty(name)) {
        return "empty"
    }
    if (not is_alnum(name)) {
        return "letters and digits only"
    }
    if (is_digit(name[0])) {
        return "cannot start with a digit"
    }
    return "ok"
}

for (let u in ["  zue_fan ", "  ", "9lives", "  Nova7  "]) {
    print("user '{u}': {check_username(u)}")
}
for (let p in ["short1", "longenough", "12345678", "has space 1", "Secret123"]) {
    print("password '{p}': {check_password(p)}")
}
print(starts_with("https://zue.dev", "https://"))
print(contains("user@example.com", "@"))
```

Output:

```
user '  zue_fan ': letters and digits only
user '  ': empty
user '9lives': cannot start with a digit
user '  Nova7  ': ok
password 'short1': too short
password 'longenough': needs a digit
password '12345678': needs a letter
password 'has space 1': no spaces allowed
password 'Secret123': ok
true
true
```

How it works:

- `trim` removes the spaces around a name before it is checked, and `is_empty` catches a name that was only spaces.
- `is_alnum(name)` is true only when every character is a letter or a digit, so `zue_fan` fails because of the underscore.
- `pw[i]` is a `char`, and `is_digit`, `is_alpha` and `is_space` accept a char as well as a string.
- A function returns as soon as one rule fails, so the checks run in order: length, spaces, digit, letter.
- `starts_with` and `contains` answer yes or no questions about a string.

### Program 2: Counting words

Cleaning a sentence and counting how often each word appears.

```javascript
# Counting words: to_lower, replace, split, maps, sort, join

let text = "The cat sat. The dog sat! The cat ran, and the dog ran."
let clean = to_lower(text)
for (let p in [".", "!", ","]) {
    clean = replace(clean, p, "")
}
let words = split(clean, " ")
let counts = {}
for (let w in words) {
    if (map_has(counts, w)) {
        counts[w] += 1
    } else {
        counts[w] = 1
    }
}
let keys = map_keys(counts)
sort(keys)
print("{len(words)} words, {len(keys)} different")
for (let k in keys) {
    print("{pad_right(k, 5, ".")} {counts[k]}")
}
print(join(keys, ", "))
print("first word, upper case: {to_upper(keys[0])}")
```

Output:

```
13 words, 6 different
and.. 1
cat.. 2
dog.. 2
ran.. 2
sat.. 2
the.. 4
and, cat, dog, ran, sat, the
first word, upper case: AND
```

How it works:

- `to_lower` makes `The` and `the` the same word. `replace` removes each punctuation mark; it replaces every match.
- `split(clean, " ")` turns the text into a list of words.
- A map holds the counts: `map_has` tells if the word was seen, and `counts[w] += 1` adds one.
- `map_keys` gives the words, and `sort(keys)` puts them in alphabetical order.
- `pad_right(k, 5, ".")` lines the counts up in a column, and `join(keys, ", ")` makes one line.

### Program 3: A report table

Aligned columns, a ruled line, and a total.

```javascript
# A report table: pad_left, pad_right, repeat, print placeholders, to_string

let names = ["Apples", "Bread", "Milk"]
let prices = [1.5, 2.25, 0.99]
let counts = [4, 1, 12]

let line = repeat("-", 30)
print(line)
print(pad_right("Item", 12, " ") + pad_left("Qty", 6, " ") + pad_left("Total", 12, " "))
print(line)
let grand = 0.0
for (let i = 0; i < len(names); i++) {
    let total = prices[i] * float(counts[i])
    grand += total
    print(pad_right(names[i], 12, " ") + pad_left(to_string(counts[i]), 6, " ") + pad_left(to_string(round(total, 2)), 12, " "))
}
print(line)
print(pad_left("Total " + to_string(round(grand, 2)), 30, " "))
print("{} items, {} lines", sum(counts), len(names))
print("id: " + pad_left(to_string(42), 6, "0"))
print(to_upper("receipt") + " " + repeat("*", 3))
```

Output:

```
------------------------------
Item           Qty       Total
------------------------------
Apples           4         6.0
Bread            1        2.25
Milk            12       11.88
------------------------------
                   Total 20.13
17 items, 3 lines
id: 000042
RECEIPT ***
```

How it works:

- `repeat("-", 30)` builds a ruled line of any width.
- `pad_right(text, w, " ")` fills the right side so a column starts at the same place, and `pad_left` fills the left side so numbers line up on the right.
- Numbers are not strings, so `to_string(counts[i])` converts them before padding. `round(total, 2)` keeps two decimals.
- `float(counts[i])` converts the quantity on purpose, because `prices[i] * counts[i]` would mix a float with an int.
- `print("{} items, {} lines", ...)` fills each `{}` with the next value and prints one line, and `pad_left(to_string(42), 6, "0")` makes `000042`.

### Program 4: Transforming text

Reversing, a palindrome test, and a Caesar cipher.

```javascript
# Transforming text: reverse, a palindrome check and a Caesar cipher

let ALPHABET = "abcdefghijklmnopqrstuvwxyz"

func is_palindrome(text) {
    let letters = ""
    for (let i = 0; i < len(text); i++) {
        let c = to_lower(char_at(text, i))
        if (is_alpha(c)) {
            letters = letters + c
        }
    }
    return letters == reverse(letters)
}

func shift_letter(c, k) {
    let i = index_of(ALPHABET, c)
    if (i < 0) {
        return c
    }
    return char_at(ALPHABET, mod(i + k, 26))
}

func caesar(text, k) {
    let out = ""
    for (let i = 0; i < len(text); i++) {
        out = out + shift_letter(char_at(text, i), k)
    }
    return out
}

print(reverse("Zue"))
print(is_palindrome("A man, a plan, a canal: Panama"))
print(is_palindrome("not a palindrome"))
let secret = caesar("attack at dawn", 3)
print(secret)
print(caesar(secret, -3))
print(to_upper(secret))
```

Output:

```
euZ
true
false
dwwdfn dw gdzq
attack at dawn
DWWDFN DW GDZQ
```

How it works:

- `reverse` returns a new string; the original does not change.
- `is_palindrome` keeps only the letters, in lower case, and compares them with their reverse. Punctuation and spaces are ignored.
- `index_of(ALPHABET, c)` finds a letter's place in the alphabet, or `-1` if `c` is not a letter, and then the letter is passed through unchanged.
- `mod(i + k, 26)` wraps past `z` back to `a`, and it also works for a negative shift, so `caesar(secret, -3)` undoes the encoding.
- Strings are built with `out = out + piece`: each `+` makes a new string, and the old one is dropped.

### Program 5: Taking text apart

A tokenizer, a key=value reader, and slices.

```javascript
# Taking text apart: a tokenizer with skip_chars and index_of_any, and slices

func tokens(src) {
    let out = []
    let i = 0
    while (i < len(src)) {
        i = skip_chars(src, " ", i)
        if (i >= len(src)) {
            break
        }
        if (is_digit(src[i])) {
            let j = skip_chars(src, "0123456789", i)
            append(out, "num:{substring(src, i, j - i)}")
            i = j
        } else if (is_alpha(src[i])) {
            let j = skip_chars(src, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_", i)
            append(out, "name:{slice(src, i + 1, j)}")
            i = j
        } else {
            append(out, "op:{substring(src, i, 1)}")
            i = i + 1
        }
    }
    return out
}

print(tokens("total = price * 12 + tax"))

# key=value lines
let line = "mode = fast"
let eq = index_of(line, "=")
print("key '{trim(substring(line, 0, eq))}' value '{trim(slice(line, eq + 2, len(line)))}'")

# Slices count from 1 and include both ends.
let word = "language"
print(word[1:4])
print(word[5:])
print(word[:3])
print(index_of_any("name@host.com", "@."))
print(last_index_of("a.b.c", "."))
print(ends_with("photo.png", ".png"))
print(split("2026-10-26", "-"))
print(to_int("2026") + 1)
```

Output:

```
[name:total, op:=, name:price, op:*, num:12, op:+, name:tax]
key 'mode' value 'fast'
lang
uage
lan
4
3
true
[2026, 10, 26]
2027
```

How it works:

- `skip_chars(src, set, i)` returns the first index at or after `i` whose character is not in `set`. It skips blanks and finds the end of a number or a name in one native call.
- `substring(src, i, n)` takes `n` bytes from `i`, and `slice(src, a, b)` takes positions `a` to `b`, counting from 1 and including both. `substring` counts from 0.
- `index_of(line, "=")` splits `mode = fast` into the key and the value, and `trim` removes the spaces around each.
- `word[1:4]` is `lang`: positions start at 1 and both ends are included. `word[5:]` runs to the end and `word[:3]` starts at the first character.
- `index_of_any("name@host.com", "@.")` finds the first of several characters, `last_index_of` finds the last match, and `split("2026-10-26", "-")` gives a list of text pieces that `to_int` can read.
