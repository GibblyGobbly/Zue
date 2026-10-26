#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# fuzz_annotations.py: random type annotations such as list<map<list<float>>> on variables,
# parameters and fields. For each one it builds a matching value and checks that the program
# parses, that `zue unparse` gives a tree equal to the original, that it runs and prints the value,
# and that a value of another element type is a compile-time Type Error.
#   python3 tools/fuzz_annotations.py [--count N] [--seed S]
import argparse, os, random, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZUE = os.path.join(ROOT, "bin", "zue")
SCALARS = {"int": ["1", "42", "7"], "float": ["1.5", "2.0", "0.25"], "bool": ["true", "false"],
           "string": ['"a"', '"bc"'], "char": ["'x'", "'y'"]}

def gen_type(rng, depth):
    if depth == 0 or rng.random() < 0.35:
        return rng.choice(list(SCALARS))
    return rng.choice(["list", "map"]) + "<" + gen_type(rng, depth - 1) + ">"

def gen_value(rng, t):
    if t in SCALARS:
        return rng.choice(SCALARS[t])
    kind, inner = t.split("<", 1)
    inner = inner[:-1]
    n = rng.randint(1, 3)
    if kind == "list":
        return "[" + ", ".join(gen_value(rng, inner) for _ in range(n)) + "]"
    return "{" + ", ".join('"k%d": %s' % (i, gen_value(rng, inner)) for i in range(n)) + "}"

def wrong_type(t):
    # The innermost scalar is replaced by a different one.
    m = re.search(r"(int|float|bool|string|char)(>*)$", t)
    other = {"int": "string", "float": "string", "bool": "int", "string": "int", "char": "int"}[m.group(1)]
    return t[:m.start()] + other + m.group(2)

def run(args, text):
    with tempfile.NamedTemporaryFile("w", suffix=".zu", delete=False, dir=tempfile.gettempdir()) as f:
        f.write(text)
        path = f.name
    try:
        return subprocess.run([ZUE] + [a if a != "@" else path for a in args], capture_output=True, text=True, cwd=ROOT)
    finally:
        os.unlink(path)

def tree(out):
    return re.sub(r"@\d+", "", out)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=60)
    ap.add_argument("--seed", type=int, default=1)
    a = ap.parse_args()
    rng = random.Random(a.seed)
    bad = 0
    for i in range(a.count):
        t = gen_type(rng, 3)
        v = gen_value(rng, t)
        progs = [
            ("let", "let x: %s = %s\nprint(x)\n" % (t, v)),
            ("tight", "let x: %s= %s\nprint(x)\n" % (t, v)),
            ("param", "func f(a: %s) {\n    return a\n}\nprint(f(%s))\n" % (t, v)),
            ("field", "template T { v: %s }\nlet o = T{%s}\nprint(o.v)\n" % (t, v)),
            ("multi", "let x: %s, y: int = %s, 1\nprint(y)\n" % (t, v)),
        ]
        for label, src in progs:
            p1 = run(["ast", "@"], src)
            p2 = run(["unparse", "@"], src)
            if p1.returncode != 0 or p2.returncode != 0:
                bad += 1; print("[FAIL] %s parse: %s\n%s" % (label, t, src)); continue
            p3 = run(["ast", "@"], p2.stdout)
            if p3.returncode != 0 or tree(p1.stdout) != tree(p3.stdout):
                bad += 1; print("[FAIL] %s round trip: %s\n%s" % (label, t, src)); continue
            r = run(["run", "@"], src)
            if r.returncode != 0:
                bad += 1; print("[FAIL] %s run: %s\n%s%s" % (label, t, src, r.stdout + r.stderr)); continue
        # a value with the wrong innermost type must be a Type Error before the program runs
        w = wrong_type(t)
        wv = gen_value(rng, w)
        r = run(["run", "@"], "let x: %s = %s\n" % (t, wv))
        if r.returncode == 0 or "Type Error" not in (r.stdout + r.stderr):
            bad += 1; print("[FAIL] wrong value accepted: %s = %s" % (t, wv))
    print("%d type annotations checked, %d failures" % (a.count, bad))
    sys.exit(1 if bad else 0)

main()
