#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 Bharath
#
# fuzz_expressions.py: checks the lexer, parser and operators against an independent evaluator.
#
# It builds random int and bool expressions, writes them as Luna source with only the parentheses
# that Luna's precedence rules require, runs the program with bin/luna, and compares every printed
# value with what Python computes from the same expression tree. A mismatch means the parser (or an
# operator) disagrees with the language rules written in this file.
#
#   python3 tools/fuzz_expressions.py [--programs 20] [--per-program 100] [--seed 1]
#
# This is a development tool: the repository itself needs only clang and make.

import argparse
import os
import random
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUNA = os.path.join(ROOT, "bin", "luna")

LIMIT = 1 << 62  # keep values far from the 64-bit overflow errors

# Binding power, loosest first. This table is the language rule the parser is checked against.
LEVEL = {
    "or": 1, "and": 2,
    "==": 3, "!=": 3,
    "<": 4, ">": 4, "<=": 4, ">=": 4,
    "+": 5, "-": 5,
    "*": 6, "/": 6, "%": 6,
}
NOT = 2.5  # not binds tighter than and, looser than a comparison: not a == b is not (a == b)
UNARY = 7  # unary minus binds tighter than every binary operator
ATOM = 8

VARIABLES = {"a": 3, "b": -4, "c": 7}


class Node:
    pass


class Lit(Node):
    def __init__(self, value):
        self.value = value  # an int or a bool


class Var(Node):
    def __init__(self, name):
        self.name = name


class Neg(Node):
    def __init__(self, operand):
        self.operand = operand


class Not(Node):
    def __init__(self, operand):
        self.operand = operand


class Bin(Node):
    def __init__(self, op, left, right):
        self.op, self.left, self.right = op, left, right


def c_div(x, y):
    q = abs(x) // abs(y)
    return q if (x >= 0) == (y >= 0) else -q


def c_mod(x, y):
    return x - c_div(x, y) * y


def evaluate(n):
    """The value of n under Luna's rules, or None when it would be an error."""
    if isinstance(n, Lit):
        return n.value
    if isinstance(n, Var):
        return VARIABLES[n.name]
    if isinstance(n, Neg):
        v = evaluate(n.operand)
        return None if v is None else -v
    if isinstance(n, Not):
        v = evaluate(n.operand)
        return None if v is None else (not v)
    l = evaluate(n.left)
    if l is None:
        return None
    if n.op == "and":
        if l is False:
            return False
        return evaluate(n.right)
    if n.op == "or":
        if l is True:
            return True
        return evaluate(n.right)
    r = evaluate(n.right)
    if r is None:
        return None
    op = n.op
    if op in ("/", "%") and r == 0:
        return None
    result = {
        "+": lambda: l + r, "-": lambda: l - r, "*": lambda: l * r,
        "/": lambda: c_div(l, r), "%": lambda: c_mod(l, r),
        "==": lambda: l == r, "!=": lambda: l != r,
        "<": lambda: l < r, ">": lambda: l > r, "<=": lambda: l <= r, ">=": lambda: l >= r,
    }[op]()
    if isinstance(result, int) and not isinstance(result, bool) and abs(result) >= LIMIT:
        return None
    return result


def is_bool(n):
    if isinstance(n, Lit):
        return isinstance(n.value, bool)
    if isinstance(n, Not):
        return True
    if isinstance(n, Bin):
        return n.op in ("and", "or", "==", "!=", "<", ">", "<=", ">=")
    return False


def gen_int(rng, depth):
    if depth <= 0 or rng.random() < 0.25:
        if rng.random() < 0.3:
            return Var(rng.choice(sorted(VARIABLES)))
        return Lit(rng.randint(0, 9))
    roll = rng.random()
    if roll < 0.12:
        return Neg(gen_int(rng, depth - 1))
    op = rng.choice(["+", "-", "*", "/", "%"])
    left, right = gen_int(rng, depth - 1), gen_int(rng, depth - 1)
    # The compiler rejects a literal zero divisor even in a branch that never runs.
    if op in ("/", "%") and isinstance(right, Lit) and right.value == 0:
        right = Lit(rng.randint(1, 9))
    return Bin(op, left, right)


def gen_bool(rng, depth):
    if depth <= 0 or rng.random() < 0.15:
        return Lit(rng.random() < 0.5)
    roll = rng.random()
    if roll < 0.15:
        return Not(gen_bool(rng, depth - 1))
    if roll < 0.65:
        op = rng.choice(["and", "or"])
        return Bin(op, gen_bool(rng, depth - 1), gen_bool(rng, depth - 1))
    if roll < 0.72:
        op = rng.choice(["==", "!="])
        return Bin(op, gen_bool(rng, depth - 1), gen_bool(rng, depth - 1))
    op = rng.choice(["==", "!=", "<", ">", "<=", ">="])
    return Bin(op, gen_int(rng, depth - 1), gen_int(rng, depth - 1))


def power(n):
    if isinstance(n, Bin):
        return LEVEL[n.op]
    if isinstance(n, Neg):
        return UNARY
    if isinstance(n, Not):
        return NOT
    return ATOM


def render(n, minimal=True):
    """Luna source for n. With minimal=True it uses only the parentheses precedence requires."""
    if isinstance(n, Lit):
        if isinstance(n.value, bool):
            return "true" if n.value else "false"
        return str(n.value)
    if isinstance(n, Var):
        return n.name
    if isinstance(n, (Neg, Not)):
        inner = render(n.operand, minimal)
        word = "-" if isinstance(n, Neg) else "not "
        floor = UNARY if isinstance(n, Neg) else NOT
        if not minimal or power(n.operand) < floor:
            return "%s(%s)" % (word, inner)
        # "- -x" needs a space: "--" is the decrement token.
        if isinstance(n, Neg) and inner.startswith("-"):
            return "- " + inner
        return word + inner
    level = LEVEL[n.op]
    left = render(n.left, minimal)
    right = render(n.right, minimal)
    # Binary operators are left-associative: the right operand needs parentheses at equal level.
    if not minimal or power(n.left) < level:
        left = "(" + left + ")"
    if not minimal or power(n.right) <= level:
        right = "(" + right + ")"
    return "%s %s %s" % (left, n.op, right)


def build_program(rng, count, minimal, depth):
    """Returns (source, expected lines, expression texts)."""
    lines = ["let %s = %d" % (k, v) for k, v in sorted(VARIABLES.items())]
    expected, texts = [], []
    while len(expected) < count:
        n = gen_bool(rng, depth) if rng.random() < 0.5 else gen_int(rng, depth)
        value = evaluate(n)
        if value is None:
            continue
        text = render(n, minimal)
        lines.append("print(%s)" % text)
        expected.append(("true" if value else "false") if isinstance(value, bool) else str(value))
        texts.append(text)
    return "\n".join(lines) + "\n", expected, texts


def run_luna(source):
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "fuzz.lu")
        with open(path, "w") as f:
            f.write(source)
        done = subprocess.run([LUNA, "run", path], capture_output=True, text=True, cwd=ROOT, timeout=120)
    return done


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--programs", type=int, default=20)
    ap.add_argument("--per-program", type=int, default=100)
    ap.add_argument("--depth", type=int, default=5)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()
    if not os.path.exists(LUNA):
        sys.exit("bin/luna is missing: run make first")
    rng = random.Random(args.seed)
    checked = failures = 0
    for p in range(args.programs):
        for minimal in (True, False):
            source, expected, texts = build_program(rng, args.per_program, minimal, args.depth)
            done = run_luna(source)
            got = done.stdout.split("\n")[:-1] if done.stdout else []
            if done.returncode != 0 or len(got) != len(expected):
                failures += 1
                print("PROGRAM %d (%s parentheses) failed to run cleanly:" % (p, "minimal" if minimal else "full"))
                print((done.stdout + done.stderr)[:600])
                with open(os.path.join(ROOT, "C", "fuzz_failed.lu"), "w") as f:
                    f.write(source)
                continue
            for text, want, have in zip(texts, expected, got):
                checked += 1
                if want != have:
                    failures += 1
                    print("MISMATCH  %s\n  expected %s, Luna printed %s" % (text, want, have))
    print("%d expressions checked, %d failures" % (checked, failures))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "C"), exist_ok=True)
    main()
