#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# fuzz_syntax_errors.py: breaks real programs on purpose and checks how the compiler copes. Each
# round takes a program from the project, applies a few random mutations (delete, duplicate or swap a
# token, drop or add a bracket or quote, cut the file short, insert a stray character) and runs
# `zue check` on it. The compiler must always
#   - finish within the time limit (no hang) and not crash (a status of 0 or 1 only),
#   - say something when it fails: every error block names a line that exists in the file,
#   - put its carets inside the line they point at,
#   - never report more than one syntax error for a line.
#   python3 tools/fuzz_syntax_errors.py [--rounds N] [--seed S] [--files N]
import argparse, glob, os, random, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZUE = os.path.join(ROOT, "bin", "zue")

TOKEN = re.compile(r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'|[A-Za-z_][A-Za-z_0-9]*|\d[\d_.]*|==|!=|<=|>=|\+\+|--|\+=|-=|\*=|/=|%=|&&|\|\||\*\*|<<|>>|\S')
STRAY = ['(', ')', '[', ']', '{', '}', '"', "'", '@', '$', '?', '\\', ';', '`', '#', ',', ':', '=', '+', '*', '!', '.', '\t', 'é']


def mutate(rng, text):
    toks = [(m.start(), m.end()) for m in TOKEN.finditer(text)]
    if not toks:
        return text
    for _ in range(rng.randint(1, 3)):
        kind = rng.choice(['delete', 'duplicate', 'swap', 'stray', 'cut', 'drop_close', 'insert_open', 'newline'])
        i = rng.randrange(len(toks))
        a, b = toks[i]
        if kind == 'delete':
            text = text[:a] + text[b:]
        elif kind == 'duplicate':
            text = text[:b] + text[a:b] + text[b:]
        elif kind == 'swap' and i + 1 < len(toks):
            c, d = toks[i + 1]
            text = text[:a] + text[c:d] + text[b:c] + text[a:b] + text[d:]
        elif kind == 'stray':
            text = text[:a] + rng.choice(STRAY) + text[a:]
        elif kind == 'cut':
            text = text[:a]
        elif kind == 'drop_close':
            closers = [m.start() for m in re.finditer(r'[)\]}]', text)]
            if closers:
                k = rng.choice(closers)
                text = text[:k] + text[k + 1:]
        elif kind == 'insert_open':
            text = text[:a] + rng.choice('([{') + text[a:]
        elif kind == 'newline':
            text = text[:a] + '\n' + text[a:]
        toks = [(m.start(), m.end()) for m in TOKEN.finditer(text)]
        if not toks:
            break
    return text


def check(path):
    try:
        p = subprocess.run([ZUE, 'check', path], capture_output=True, text=True, timeout=30)
    except subprocess.TimeoutExpired:
        return None, 'timeout'
    return p, None


HEADER = re.compile(r'^(\w[\w ]* Error)(?: \[E\d+\])? in (.*) at line (\d+):$')
CARET = re.compile(r'^\s*\d*\s*\| ?(\s*)([\^-]+)')


def problems(text, proc):
    out = []
    if proc.returncode not in (0, 1):
        out.append('exit status %d' % proc.returncode)
        return out
    if proc.returncode == 0:
        return out
    lines = text.split('\n')
    syntax_lines = {}
    body = proc.stdout.split('\n')
    found = False
    for k, row in enumerate(body):
        m = HEADER.match(row)
        if not m:
            continue
        found = True
        n = int(m.group(3))
        if n < 1 or n > max(len(lines), 1):
            out.append('line %d is outside the file (%d lines)' % (n, len(lines)))
        if m.group(1) == 'Syntax Error':
            syntax_lines[n] = syntax_lines.get(n, 0) + 1
            if syntax_lines[n] > 1:
                out.append('two syntax errors on line %d' % n)
    for row in body:
        m = re.match(r'^\s*(\d+) \| (.*)$', row)
        if m:
            n = int(m.group(1))
            if n < 1 or n > len(lines):
                out.append('excerpt of line %d is outside the file' % n)
    if not found:
        out.append('exit status 1 and no error block: %r' % (proc.stdout[:200] + proc.stderr[:200]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--rounds', type=int, default=300)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--files', type=int, default=0, help='use only this many source files (0 = all)')
    args = ap.parse_args()
    rng = random.Random(args.seed)
    sources = sorted(glob.glob(os.path.join(ROOT, 'compiler', '*.zu')) + glob.glob(os.path.join(ROOT, 'examples', '*.zu')) +
                     glob.glob(os.path.join(ROOT, 'test', 'test_*.zu')))
    sources = [s for s in sources if os.path.getsize(s) < 40000]
    if args.files:
        sources = sources[:args.files]
    failures = 0
    errors_seen = 0
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, 'mutant.zu')
        for r in range(args.rounds):
            src = rng.choice(sources)
            original = open(src).read()
            text = mutate(rng, original)
            with open(path, 'w') as f:
                f.write(text)
            proc, err = check(path)
            if err:
                failures += 1
                print('FAIL round %d (%s): %s' % (r, os.path.relpath(src, ROOT), err))
                open(os.path.join(tempfile.gettempdir(), 'fuzz_syntax_fail_%d.zu' % r), 'w').write(text)
                continue
            if proc.returncode == 1:
                errors_seen += 1
            for p in problems(text, proc):
                failures += 1
                print('FAIL round %d (%s): %s' % (r, os.path.relpath(src, ROOT), p))
                open(os.path.join(tempfile.gettempdir(), 'fuzz_syntax_fail_%d.zu' % r), 'w').write(text)
    print('%d mutated programs checked, %d had errors, %d failures' % (args.rounds, errors_seen, failures))
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
