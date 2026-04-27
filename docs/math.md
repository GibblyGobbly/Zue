# Math

Every math function in Zue, with five complete programs that show how they fit together.
The short reference is in [builtins](builtins.md#math); this page lists everything in one place
and explains it.

## The rules

| Rule | What it means |
|---|---|
| Ints and floats do not convert for you | `sqrt(n)` with an int variable `n` is an error. A number written in the source adapts (`sqrt(16)` is fine), a variable never does. Use `float(n)` or `int(x)` to convert |
| No infinity and no NaN | An argument outside a function's domain is an `Argument Error` (`sqrt(-4)`, `ln(0)`, `asin(2)`). A result too large for a float is a `Runtime Error` (`float overflow in exp()`) |
| Integer overflow is an error | `9223372036854775807 + 1` stops with `integer overflow in '+'`. It never wraps |
| Division by zero is an error | `1 / 0`, `5 % 0` and `mod(5, 0)` all stop the program |
| Floats print with up to six significant digits | `sqrt(2)` prints `1.41421`. A float with no fraction prints with `.0` (`sqrt(16)` prints `4.0`). For more digits use `fixed(x, decimals)` or `to_string(x, digits)` |
| Zue has no negative zero | `-0.0` is `0.0` |

Operators: `+ - * / %`, `**` (power), and the bitwise `& | ^ << >> ~` on ints. `/` on two ints
is integer division and `%` keeps the sign of the left side. See [syntax](syntax.md#operators).

## Function reference

### Numbers

| Function | Returns | Notes |
|---|---|---|
| `abs(x)` | same type as `x` | `abs(-10)` is `10` |
| `sign(x)` | int | `-1`, `0` or `1` |
| `min(a, b)`, `max(a, b)` | same type | Both ints or both floats |
| `min(list)`, `max(list)` | item | A non-empty list, all ints or all floats |
| `clamp(x, lo, hi)` | same type | `lo` above `hi` is an `Argument Error` |
| `sum(list)` | same type as the items | Ints overflow-check; floats use a compensated sum |
| `mean(list)` | float | Always a float |
| `lerp(a, b, t)` | float | `lerp(0, 100, 0.5)` is `50.0` |

### Integers and division

| Function | Returns | Notes |
|---|---|---|
| `gcd(a, b)`, `lcm(a, b)` | int | Never negative. `lcm` with a zero is `0` |
| `isqrt(n)` | int | The largest `r` with `r * r <= n` |
| `mod(x, y)` | same type | Floored remainder: the sign of `y`. `mod(-7, 3)` is `2`, while `-7 % 3` is `-1` |
| `floor_div(x, y)` | same type | Division rounded down: `floor_div(-7, 3)` is `-3` |
| `divmod(x, y)` | list | `[floor_div(x, y), mod(x, y)]` |

### Powers, roots and logarithms

| Function | Returns | Notes |
|---|---|---|
| `pow(base, exp)` | int or float | Two ints with `exp >= 0` give an exact int; otherwise a float |
| `sqrt(x)`, `cbrt(x)` | float | `sqrt` of a negative number is an error |
| `exp(x)` | float | e to the power `x` |
| `ln(x)`, `log10(x)` | float | `x <= 0` is an `Argument Error` |

### Rounding

| Function | Returns | Notes |
|---|---|---|
| `floor(x)`, `ceil(x)`, `trunc(x)` | int | Down, up, toward zero |
| `round(x)` | int | Halves away from zero: `round(2.5)` is `3`, `round(-2.5)` is `-3` |
| `round(x, digits)` | float | 0 to 15 places: `round(3.14159, 3)` is `3.142` |
| `fract(x)` | float | The part after the point, with the sign of `x` |

A rounded result outside the 64-bit int range is a `Runtime Error`.

### Trigonometry

Angles are in radians. All return floats.

| Function | Notes |
|---|---|
| `sin`, `cos`, `tan` | |
| `asin`, `acos`, `atan` | `asin` and `acos` need `x` from -1 to 1 |
| `atan2(y, x)` | Arc tangent with the right quadrant |
| `sinh`, `cosh`, `tanh` | |
| `deg_to_rad(d)`, `rad_to_deg(r)` | Angle conversion |

### Random numbers

| Function | Returns | Notes |
|---|---|---|
| `rand()` | float | In `[0, 1)` |
| `rand(max)`, `rand(min, max)` | int | Both ends included, bounds swapped if reversed |
| `srand(seed)` | null | Same seed, same sequence. `srand()` reseeds from the OS |
| `trand()` | int | A 64-bit int from the OS entropy source |
| `trand(max)`, `trand(min, max)` | int | Like `rand`, but from the OS, so it cannot be repeated |
| `shuffle(list)` | null | Fisher-Yates in place with the seeded generator |
| `tshuffle(list)` | null | The same, with OS entropy |

`rand` runs on xoroshiro128++ and takes about 5 ns a call. `trand` makes a system call each time
(about 0.5 microseconds). Every range is exact: each integer from `min` to `max` is equally likely.

### Vectors and matrices

| Function | Returns | Notes |
|---|---|---|
| `dense_list(n, fill)` | dense list | `n` copies of a float |
| `vec_add`, `vec_sub`, `vec_mul`, `vec_div` | dense list | Element by element; the lists must have the same length |
| `vec_mul_inline(a, b)` | dense list | Multiplies `a` by `b` in place |
| `mat_mul(a, b)` | list of dense rows | Matrix product; the sizes must fit |

### Related

`sort(list)` and `ssort(list)` are in [builtins](builtins.md#lists). `int(x)` and `float(x)` convert
between the two number types on purpose.

## Programs

Each program below was run, and the output shown is what it printed.

### Program 1: Number theory

Prime numbers, simplifying a fraction, and the difference between `%` and `mod`.

```javascript
# Number theory: gcd, lcm, isqrt, mod, divmod

func is_prime(n) {
    if (n < 2) {
        return false
    }
    let limit = isqrt(n)
    for (let d = 2; d <= limit; d++) {
        if (n % d == 0) {
            return false
        }
    }
    return true
}

func simplify(num, den) {
    let g = gcd(num, den)
    return "{num / g}/{den / g}"
}

let primes = []
for (let n = 2; n < 50; n++) {
    if (is_prime(n)) {
        append(primes, n)
    }
}
print("primes below 50: {primes}")
print("12/18 simplifies to {simplify(12, 18)}")
print("lcm(4, 6) = {lcm(4, 6)}, gcd(-12, 18) = {gcd(-12, 18)}")
print("isqrt(99) = {isqrt(99)}, isqrt(100) = {isqrt(100)}")
print("-7 % 3 = {-7 % 3}, mod(-7, 3) = {mod(-7, 3)}")
print("divmod(-7, 3) = {divmod(-7, 3)}")
print("2^10 = {pow(2, 10)}, 2^0.5 = {pow(2.0, 0.5)}")
```

Output:

```
primes below 50: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47]
12/18 simplifies to 2/3
lcm(4, 6) = 12, gcd(-12, 18) = 6
isqrt(99) = 9, isqrt(100) = 10
-7 % 3 = -1, mod(-7, 3) = 2
divmod(-7, 3) = [-3, 2]
2^10 = 1024, 2^0.5 = 1.41421
```

How it works:

- `isqrt(n)` gives the largest whole number whose square fits in `n`. Testing divisors only up to it is enough to decide if `n` is prime.
- `gcd(num, den)` finds the common factor, so `12/18` becomes `2/3`. `num / g` is integer division because both are ints.
- `-7 % 3` is `-1` (the sign of the left side), but `mod(-7, 3)` is `2` (the sign of the right side). Use `mod` when you wrap around a range.
- `divmod(-7, 3)` returns the quotient and the remainder together: `[-3, 2]`. They satisfy `-7 == -3 * 3 + 2`.
- `pow(2, 10)` with two ints is an exact int. `pow(2.0, 0.5)` is a float, printed as `1.41421`.

### Program 2: Statistics

The count, sum, mean, extremes, median and spread of a list of floats.

```javascript
# Statistics of a list of numbers

func median(sorted_values) {
    let n = len(sorted_values)
    let mid = floor_div(n, 2)
    if (n % 2 == 1) {
        return sorted_values[mid]
    }
    return (sorted_values[mid - 1] + sorted_values[mid]) / 2.0
}

func variance(values) {
    let m = mean(values)
    let total = 0.0
    for (let v in values) {
        let d = v - m
        total += d * d
    }
    return total / float(len(values))
}

let scores = [72.0, 88.5, 91.0, 65.5, 88.5, 79.0, 94.5]
let ordered = slice(scores, 0, len(scores) - 1)
sort(ordered)
print("count    {len(scores)}")
print("sum      {sum(scores)}")
print("mean     {round(mean(scores), 2)}")
print("min/max  {min(scores)} / {max(scores)}")
print("sorted   {ordered}")
print("median   {median(ordered)}")
print("std dev  {round(sqrt(variance(scores)), 2)}")
print("clamped  {clamp(105.0, 0.0, 100.0)}")
```

Output:

```
count    7
sum      579.0
mean     82.71
min/max  65.5 / 94.5
sorted   [65.5, 72.0, 79.0, 88.5, 88.5, 91.0, 94.5]
median   88.5
std dev  10.0
clamped  100.0
```

How it works:

- `slice(scores, 0, len(scores) - 1)` copies the list, so `sort(ordered)` does not disturb the original.
- `sum` and `mean` take a list of numbers. `mean` is always a float, and `round(x, 2)` rounds it to two places.
- `floor_div(n, 2)` is the middle index. An odd count uses that item; an even count averages the two in the middle.
- The variance adds up each squared distance from the mean, and `sqrt` turns it into the standard deviation. `float(len(values))` converts the count on purpose, because ints and floats do not mix.
- `clamp(105.0, 0.0, 100.0)` keeps a value inside a range.

### Program 3: Points, angles and vectors

Distances, angles, interpolation, a circle, and a rotation by a matrix product.

```javascript
# Points, angles and vectors

func distance(ax, ay, bx, by) {
    let dx = bx - ax
    let dy = by - ay
    return sqrt(dx * dx + dy * dy)
}

let a = [0.0, 0.0]
let b = [3.0, 4.0]
print("distance      {distance(a[0], a[1], b[0], b[1])}")
print("angle degrees {round(rad_to_deg(atan2(b[1], b[0])), 2)}")
print("halfway       {lerp(a[0], b[0], 0.5)}, {lerp(a[1], b[1], 0.5)}")

let r = 2.5
let pi = deg_to_rad(180.0)
print("circle area   {round(pi * r * r, 3)}")
print("sin 30 deg    {round(sin(deg_to_rad(30.0)), 4)}")
print("cos 60 deg    {round(cos(deg_to_rad(60.0)), 4)}")

print("vec_add       {vec_add([1.0, 2.0, 3.0], [10.0, 20.0, 30.0])}")
print("vec_mul       {vec_mul([1.0, 2.0, 3.0], [4.0, 5.0, 6.0])}")

# Rotate (1, 0) by 90 degrees with a 2x2 matrix product.
let t = deg_to_rad(90.0)
let rot = [[cos(t), -sin(t)], [sin(t), cos(t)]]
let point = [[1.0], [0.0]]
let out = mat_mul(rot, point)
print("rotated       {round(out[0][0], 6)}, {round(out[1][0], 6)}")
```

Output:

```
distance      5.0
angle degrees 53.13
halfway       1.5, 2.0
circle area   19.635
sin 30 deg    0.5
cos 60 deg    0.5
vec_add       d[11.0, 22.0, 33.0]
vec_mul       d[4.0, 10.0, 18.0]
rotated       0.0, 1.0
```

How it works:

- `sqrt(dx * dx + dy * dy)` is the distance between two points. The points are `(0, 0)` and `(3, 4)`, so the answer is exactly `5.0`.
- `atan2(y, x)` gives the angle with the right quadrant, in radians. `rad_to_deg` turns it into degrees: about 53.13.
- `lerp(a, b, t)` moves from `a` to `b`; `t = 0.5` is halfway.
- Trigonometry uses radians, so degrees go through `deg_to_rad` first. `round(..., 4)` hides tiny floating point error such as `0.49999999`.
- `vec_add` and `vec_mul` work element by element and return a dense list, printed as `d[...]`.
- `mat_mul(rot, point)` multiplies a 2 by 2 rotation matrix by a column. Rotating `(1, 0)` by 90 degrees gives `(0, 1)`.

### Program 4: Rounding and clock arithmetic

Prices and cents, the four ways to drop a fraction, and converting seconds into days, hours and minutes.

```javascript
# Rounding: money, and clock arithmetic with floor_div and mod

func cents(price) {
    return round(price * 100.0)
}

let price = 19.987
print("round 2 places  {round(price, 2)}")
print("floor / ceil    {floor(price)} / {ceil(price)}")
print("trunc / fract   {trunc(price)} / {round(fract(price), 3)}")
print("cents           {cents(price)}")
print("round halves    {round(2.5)} {round(-2.5)} {round(3.5)}")
print("negative floor  {floor(-5.1)} {ceil(-5.9)} {trunc(-5.9)}")

let seconds = 98765
let days = floor_div(seconds, 86400)
let rest = mod(seconds, 86400)
let hours = floor_div(rest, 3600)
let minutes = floor_div(mod(rest, 3600), 60)
print("{seconds}s = {days}d {hours}h {minutes}m {mod(rest, 60)}s")

# Wrapping around: what day is 10 days after day 5 of a 7 day week?
let day = mod(5 + 10 - 1, 7) + 1
print("day {day}")
print("mod(-1, 7) = {mod(-1, 7)}")
print("divmod(100, 7) = {divmod(100, 7)}")
```

Output:

```
round 2 places  19.99
floor / ceil    19 / 20
trunc / fract   19 / 0.987
cents           1999
round halves    3 -3 4
negative floor  -6 -5 -5
98765s = 1d 3h 26m 5s
day 1
mod(-1, 7) = 6
divmod(100, 7) = [14, 2]
```

How it works:

- `round(x, 2)` keeps two decimals. `round(x)` with one argument returns an int, with halves going away from zero (`round(2.5)` is `3`, `round(-2.5)` is `-3`).
- `floor` goes down, `ceil` goes up, `trunc` goes toward zero. They only differ for negative numbers: `floor(-5.1)` is `-6`, `trunc(-5.9)` is `-5`.
- `fract(x)` is what is left after `trunc(x)`, so `x == trunc(x) + fract(x)`.
- `floor_div` and `mod` split a number into whole units and the remainder: days from seconds, then hours from what is left.
- `mod(-1, 7)` is `6`, never negative, which is what makes it right for wrapping around a week or a clock.

### Program 5: Random numbers

A repeatable dice game, a true random roll, and two kinds of shuffle.

```javascript
# Random numbers: a reproducible game, a true random roll, and shuffles

func roll_many(count) {
    let faces = [0, 0, 0, 0, 0, 0, 0]
    for (let i = 0; i < count; i++) {
        faces[rand(1, 6)] += 1
    }
    return faces
}

srand(2024)
let first = roll_many(6000)
srand(2024)
let second = roll_many(6000)
print("same seed, same rolls: {first[1] == second[1] and first[6] == second[6]}")

let total = 0
for (let f = 1; f <= 6; f++) {
    print("face {f}: {first[f]}")
    total += first[f]
}
print("total {total}")

# trand does not use the seed, so this changes on every run.
let t = trand(1, 6)
print("a true random roll is between 1 and 6: {t >= 1 and t <= 6}")

srand(7)
let deck = range(1, 11)
shuffle(deck)
print("seeded shuffle: {deck}")
sort(deck)
print("sorted again:   {deck}")

let secret = range(1, 11)
tshuffle(secret)
print("tshuffle keeps 10 cards: {len(secret)}")
print("rand(): a float below 1: {rand() < 1.0}")
```

Output:

```
same seed, same rolls: true
face 1: 1038
face 2: 1012
face 3: 957
face 4: 1003
face 5: 990
face 6: 1000
total 6000
a true random roll is between 1 and 6: true
seeded shuffle: [8, 10, 9, 1, 5, 2, 4, 6, 3, 7]
sorted again:   [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
tshuffle keeps 10 cards: 10
rand(): a float below 1: true
```

How it works:

- `srand(2024)` fixes the sequence. Running the same code after the same seed gives the same rolls, which is how you test a game.
- `rand(1, 6)` includes both 1 and 6. Over 6000 rolls each face comes up close to 1000 times, and the counts add up to 6000.
- `trand(1, 6)` reads the OS entropy source. It ignores `srand`, so it differs on every run, and that is why the program prints only a true/false check about it.
- `shuffle` uses the seeded generator, so after `srand(7)` the deck order is always the same. `tshuffle` uses OS entropy, so it is different every time and can reach every ordering of a list of any length.
- `sort(deck)` puts the cards back in order. For 256 or more non-negative ints it uses a radix sort.
