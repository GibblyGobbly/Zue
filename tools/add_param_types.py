#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# add_param_types.py: writes the type of each untyped parameter that zue check --param-types found called
# with one type. A parameter given several types, or only null, is listed for the programmer to decide.
#   python3 tools/add_param_types.py prog.zu [more.zu ...]
# Each program is checked on its own (with its imports); the files are changed in place.
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZUE = os.path.join(ROOT, "bin", "zue")
NULLABLE = ("string", "list", "map", "function")


def written(t):
    # the type as a program writes it: a template's own name, without the types of its fields
    if t.startswith("list") or t.startswith("map"):
        return t
    return re.sub(r"<.*>$", "", t)


def choose(types):
    # any comes from a caller whose own parameters were not known yet
    ts = [t for t in types if t not in ("null", "unset", "any")]
    # lists (or maps) of several item types: a plain list (or map) parameter takes each call's type
    for kind in ("list", "map"):
        if len(ts) > 1 and all(t == kind or t.startswith(kind + "<") for t in ts):
            return kind
    if len(ts) != 1:
        return None
    t = ts[0]
    if "null" in types and t in ("int", "float", "bool", "char"):
        return None
    return written(t)


def run_check(prog, no_strict):
    cmd = [ZUE] + (["--no-strict"] if no_strict else []) + ["check", "--param-types", prog]
    r = subprocess.run(cmd, capture_output=True, text=True)
    out = []
    for line in r.stdout.splitlines():
        m = re.match(r"^(.*):(\d+):(\d+) (\w+) (.+)$", line)
        if m:
            out.append((m.group(1), int(m.group(2)), int(m.group(3)), m.group(4), m.group(5).split("|")))
    return out


def report(prog):
    text = open(prog).read()
    no_strict = re.search(r"^# test: no-strict$", text, re.M) is not None
    lines = text.split("\n")
    starts = [i for i, l in enumerate(lines) if l.startswith("# CASE ")]
    if not starts:
        return run_check(prog, no_strict)
    # a file of "# CASE" sections: each case is its own program, checked from a file next to it
    out = []
    tmp = os.path.join(os.path.dirname(os.path.abspath(prog)), ".param_types_case.zu")
    for k, st in enumerate(starts):
        end = starts[k + 1] if k + 1 < len(starts) else len(lines)
        open(tmp, "w").write("\n".join(lines[st + 1:end]) + "\n")
        try:
            for path, line, col, name, types in run_check(tmp, no_strict):
                if os.path.abspath(path) == tmp:
                    out.append((prog, line + st + 1, col, name, types))
        finally:
            os.remove(tmp)
    return out


def main():
    edits = {}
    left = []
    for prog in sys.argv[1:]:
        for path, line, col, name, types in report(prog):
            t = choose(types)
            if t is None:
                left.append("%s:%d:%d %s %s" % (path, line, col, name, "|".join(types)))
            else:
                edits.setdefault(path, {})[(line, col)] = (name, t)
    for path, places in edits.items():
        lines = open(path).read().split("\n")
        # right to left on each line, so earlier columns stay where they are
        for (line, col) in sorted(places, reverse=True):
            name, t = places[(line, col)]
            text = lines[line - 1]
            start = col - 1
            if text[start:start + len(name)] != name:
                left.append("%s:%d:%d %s (not found there)" % (path, line, col, name))
                continue
            end = start + len(name)
            if text[end:end + 1] == ":":
                continue
            lines[line - 1] = text[:end] + ": " + t + text[end:]
        open(path, "w").write("\n".join(lines))
        print("%s: %d parameters typed" % (path, len(places)))
    for l in sorted(set(left)):
        print("decide by hand:", l)


main()
