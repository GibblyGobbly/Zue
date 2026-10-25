#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 Bharath
#
# fuzz_programs.py: checks statements, scoping and function calls against an independent model.
#
# It builds random programs from int variables, if/else, while and for loops with break and
# continue, functions and calls. Python runs the same program structure to get the expected output.
# Luna must print exactly that, both for the program as written and for the same program after
# `luna unparse` has written it back out. A mismatch points at the parser, the code generator or
# the unparser.
#
#   python3 tools/fuzz_programs.py [--programs 50] [--seed 1]
#
# Development tool only: the repository itself needs just clang and make.

import argparse
import os
import random
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUNA = os.path.join(ROOT, "bin", "luna")
LIMIT = 1 << 62


class Discard(Exception):
    """The program would hit a Luna error (zero divisor, overflow); the generator drops it."""


def c_div(x, y):
    q = abs(x) // abs(y)
    return q if (x >= 0) == (y >= 0) else -q


def c_mod(x, y):
    return x - c_div(x, y) * y


class Break(Exception):
    pass


class Continue(Exception):
    pass


class Return(Exception):
    def __init__(self, value):
        self.value = value


# Expressions are tuples. Integer: ("lit", n) ("var", v) ("neg", e) ("bin", op, l, r) ("call", f, args)
# Boolean: ("cmp", op, l, r) ("and", l, r) ("or", l, r) ("not", b) ("blit", bool)

def render(e):
    kind = e[0]
    if kind == "lit":
        return str(e[1])
    if kind == "var":
        return e[1]
    if kind == "neg":
        return "(-%s)" % render(e[1])
    if kind == "bin" or kind == "cmp":
        return "(%s %s %s)" % (render(e[2]), e[1], render(e[3]))
    if kind == "call":
        return "%s(%s)" % (e[1], ", ".join(render(a) for a in e[2]))
    if kind in ("and", "or"):
        return "(%s %s %s)" % (render(e[1]), kind, render(e[2]))
    if kind == "not":
        return "(not %s)" % render(e[1])
    if kind == "blit":
        return "true" if e[1] else "false"
    raise ValueError(kind)


class Machine:
    """Runs the generated program structure with Luna's integer rules."""

    def __init__(self):
        self.out = []
        self.funcs = {}
        self.steps = 0

    def tick(self):
        self.steps += 1
        if self.steps > 20000:
            raise Discard()

    def check(self, v):
        if isinstance(v, int) and not isinstance(v, bool) and abs(v) >= LIMIT:
            raise Discard()
        return v

    def ev(self, e, env):
        self.tick()
        kind = e[0]
        if kind == "lit":
            return e[1]
        if kind == "var":
            return env[e[1]]
        if kind == "neg":
            return self.check(-self.ev(e[1], env))
        if kind == "call":
            fn = self.funcs[e[1]]
            args = [self.ev(a, env) for a in e[2]]
            return self.call(fn, args)
        if kind == "blit":
            return e[1]
        if kind == "not":
            return not self.ev(e[1], env)
        if kind == "and":
            return self.ev(e[1], env) and self.ev(e[2], env)
        if kind == "or":
            return self.ev(e[1], env) or self.ev(e[2], env)
        op = e[1]
        l = self.ev(e[2], env)
        r = self.ev(e[3], env)
        if op in ("/", "%") and r == 0:
            raise Discard()
        if op == "+":
            return self.check(l + r)
        if op == "-":
            return self.check(l - r)
        if op == "*":
            return self.check(l * r)
        if op == "/":
            return c_div(l, r)
        if op == "%":
            return c_mod(l, r)
        return {"<": l < r, ">": l > r, "<=": l <= r, ">=": l >= r, "==": l == r, "!=": l != r}[op]

    def call(self, fn, args):
        name, params, body, ret = fn
        env = dict(zip(params, args))
        self.run_block(body, env)
        return self.ev(ret, env)

    def run_block(self, stmts, env):
        for s in stmts:
            self.run(s, env)

    def run(self, s, env):
        self.tick()
        kind = s[0]
        if kind == "let" or kind == "assign":
            env[s[1]] = self.ev(s[2], env)
        elif kind == "print":
            v = self.ev(s[1], env)
            self.out.append(("true" if v else "false") if isinstance(v, bool) else str(v))
        elif kind == "if":
            self.run_block(s[2] if self.ev(s[1], env) else s[3], env)
        elif kind == "while":
            counter, limit, body = s[1], s[2], s[3]
            env[counter] = 0
            while env[counter] < limit:
                env[counter] += 1
                try:
                    self.run_block(body, env)
                except Break:
                    break
                except Continue:
                    continue
        elif kind == "for":
            var, start, end, body = s[1], s[2], s[3], s[4]
            i = start
            while i < end:
                env[var] = i
                i += 1
                try:
                    self.run_block(body, env)
                except Break:
                    break
                except Continue:
                    continue
        elif kind == "break":
            raise Break()
        elif kind == "continue":
            raise Continue()
        else:
            raise ValueError(kind)


def is_literal_zero(e):
    """True for 0 and for negations of it: the parser folds -(-0) into the literal 0."""
    while e[0] == "neg":
        e = e[1]
    return e[0] == "lit" and e[1] == 0


class Generator:
    def __init__(self, rng):
        self.rng = rng
        self.counter = 0
        self.protected = set()  # loop variables and loop counters: read but never assigned
        self.funcs = []  # (name, params, body, ret) defined so far

    def fresh(self, prefix):
        self.counter += 1
        return "%s%d" % (prefix, self.counter)

    def int_expr(self, vars_, depth):
        rng = self.rng
        if depth <= 0 or rng.random() < 0.3:
            if vars_ and rng.random() < 0.6:
                return ("var", rng.choice(vars_))
            return ("lit", rng.randint(0, 9))
        roll = rng.random()
        if roll < 0.1:
            return ("neg", self.int_expr(vars_, depth - 1))
        if roll < 0.25 and self.funcs:
            name, params, _, _ = rng.choice(self.funcs)
            return ("call", name, [self.int_expr(vars_, depth - 1) for _ in params])
        op = rng.choice(["+", "-", "*", "/", "%"])
        right = self.int_expr(vars_, depth - 1)
        if op in ("/", "%") and is_literal_zero(right):
            right = ("lit", rng.randint(1, 9))
        return ("bin", op, self.int_expr(vars_, depth - 1), right)

    def bool_expr(self, vars_, depth):
        rng = self.rng
        if depth <= 0 or rng.random() < 0.15:
            op = rng.choice(["<", ">", "<=", ">=", "==", "!="])
            return ("cmp", op, self.int_expr(vars_, 1), self.int_expr(vars_, 1))
        roll = rng.random()
        if roll < 0.2:
            return ("not", self.bool_expr(vars_, depth - 1))
        if roll < 0.6:
            return (rng.choice(["and", "or"]), self.bool_expr(vars_, depth - 1), self.bool_expr(vars_, depth - 1))
        op = rng.choice(["<", ">", "<=", ">=", "==", "!="])
        return ("cmp", op, self.int_expr(vars_, 2), self.int_expr(vars_, 2))

    def block(self, vars_, size, depth, in_loop):
        """Statements for one block. vars_ lists the variables visible at its start."""
        rng = self.rng
        visible = list(vars_)
        stmts = []
        for _ in range(size):
            roll = rng.random()
            if roll < 0.25 or not visible:
                name = self.fresh("v")
                stmts.append(("let", name, self.int_expr(visible, 3)))
                visible.append(name)
            elif roll < 0.4:
                writable = [v for v in visible if v not in self.protected]
                if not writable:
                    stmts.append(("print", self.int_expr(visible, 2)))
                else:
                    stmts.append(("assign", rng.choice(writable), self.int_expr(visible, 3)))
            elif roll < 0.6:
                stmts.append(("print", self.int_expr(visible, 3)))
            elif roll < 0.65:
                stmts.append(("print", self.bool_expr(visible, 2)))
            elif roll < 0.77 and depth > 0:
                stmts.append(("if", self.bool_expr(visible, 2),
                              self.block(visible, rng.randint(1, 3), depth - 1, in_loop),
                              self.block(visible, rng.randint(0, 3), depth - 1, in_loop)))
            elif roll < 0.85 and depth > 0:
                counter = self.fresh("c")
                self.protected.add(counter)
                body = self.block(visible + [counter], rng.randint(1, 3), depth - 1, True)
                stmts.append(("while", counter, rng.randint(0, 4), body))
                visible.append(counter)
            elif roll < 0.93 and depth > 0:
                var = self.fresh("i")
                self.protected.add(var)
                start = rng.randint(-2, 2)
                body = self.block(visible + [var], rng.randint(1, 3), depth - 1, True)
                stmts.append(("for", var, start, start + rng.randint(0, 4), body))
            elif in_loop:
                stmts.append(("if", self.bool_expr(visible, 1),
                              [("break",) if rng.random() < 0.5 else ("continue",)], []))
            else:
                stmts.append(("print", self.int_expr(visible, 2)))
        return stmts

    def function(self):
        name = self.fresh("f")
        params = [self.fresh("p") for _ in range(self.rng.randint(0, 3))]
        body = self.block(params, self.rng.randint(1, 4), 1, False)
        visible = list(params)
        for s in body:
            if s[0] in ("let", "while"):
                visible.append(s[1])
        ret = self.int_expr(visible, 3)
        self.funcs.append((name, params, body, ret))
        return self.funcs[-1]

    def program(self):
        funcs = [self.function() for _ in range(self.rng.randint(0, 3))]
        main = self.block([], self.rng.randint(4, 12), 2, False)
        return funcs, main


def stmt_source(s, depth):
    pad = "    " * depth
    kind = s[0]
    if kind == "let":
        return "%slet %s = %s\n" % (pad, s[1], render(s[2]))
    if kind == "assign":
        return "%s%s = %s\n" % (pad, s[1], render(s[2]))
    if kind == "print":
        return "%sprint(%s)\n" % (pad, render(s[1]))
    if kind == "break" or kind == "continue":
        return "%s%s\n" % (pad, kind)
    if kind == "if":
        text = "%sif (%s) {\n%s%s}" % (pad, render(s[1]), block_source(s[2], depth + 1), pad)
        if s[3]:
            text += " else {\n%s%s}" % (block_source(s[3], depth + 1), pad)
        return text + "\n"
    if kind == "while":
        return "%slet %s = 0\n%swhile (%s < %d) {\n%s    %s += 1\n%s%s}\n" % (
            pad, s[1], pad, s[1], s[2], pad, s[1], block_source(s[3], depth + 1), pad)
    if kind == "for":
        return "%sfor (let %s = %d; %s < %d; %s++) {\n%s%s}\n" % (
            pad, s[1], s[2], s[1], s[3], s[1], block_source(s[4], depth + 1), pad)
    raise ValueError(kind)


def block_source(stmts, depth):
    return "".join(stmt_source(s, depth) for s in stmts)


def program_source(funcs, main):
    text = ""
    for name, params, body, ret in funcs:
        text += "func %s(%s) {\n%s    return %s\n}\n" % (name, ", ".join(params), block_source(body, 1), render(ret))
    return text + block_source(main, 0)


def expected_output(funcs, main):
    m = Machine()
    for f in funcs:
        m.funcs[f[0]] = f
    m.run_block(main, {})
    return m.out


def luna_run(path):
    done = subprocess.run([LUNA, "run", path], capture_output=True, text=True, cwd=ROOT, timeout=120)
    return done


def luna_unparse(path):
    done = subprocess.run([LUNA, "unparse", path], capture_output=True, text=True, cwd=ROOT, timeout=60)
    return done.stdout


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--programs", type=int, default=50)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()
    if not os.path.exists(LUNA):
        sys.exit("bin/luna is missing: run make first")
    os.makedirs(os.path.join(ROOT, "C"), exist_ok=True)
    rng = random.Random(args.seed)
    ran = failures = 0
    while ran < args.programs:
        gen = Generator(rng)
        funcs, main_block = gen.program()
        try:
            want = expected_output(funcs, main_block)
        except Discard:
            continue
        if not want:
            continue
        source = program_source(funcs, main_block)
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "program.lu")
            with open(path, "w") as f:
                f.write(source)
            variants = [("as written", path)]
            unparsed = luna_unparse(path)
            if unparsed:
                round_path = os.path.join(tmp, "unparsed.lu")
                with open(round_path, "w") as f:
                    f.write(unparsed)
                variants.append(("after unparse", round_path))
            for label, p in variants:
                done = luna_run(p)
                got = done.stdout.split("\n")[:-1]
                if done.returncode != 0 or got != want:
                    failures += 1
                    keep = os.path.join(ROOT, "C", "fuzz_program_failed.lu")
                    with open(keep, "w") as f:
                        f.write(source)
                    print("FAILED (%s), program saved in C/fuzz_program_failed.lu" % label)
                    print("  exit %d, expected %d lines, got %d" % (done.returncode, len(want), len(got)))
                    print("  " + (done.stdout + done.stderr)[:300].replace("\n", "\n  "))
                    break
        ran += 1
    print("%d programs checked, %d failures" % (ran, failures))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
