#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# check_error_examples.py: runs the example of every entry of compiler/error_codes.txt and checks
# that the error it causes carries that entry's code, so the explanations stay true.
#   python3 tools/check_error_examples.py
import os, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZUE = os.path.join(ROOT, "bin", "zue")

def entries():
    out, cur, field = [], None, None
    for raw in open(os.path.join(ROOT, "compiler", "error_codes.txt")).read().split("\n"):
        if raw.startswith("== "):
            cur = {"code": raw[3:].strip(), "example": ""}
            out.append(cur)
            field = None
        elif cur is not None and raw.startswith("    ") and field == "example":
            cur["example"] += raw[4:] + "\n"
        elif cur is not None:
            field = raw.partition(":")[0].strip() if ":" in raw and not raw.startswith(" ") else None
    return out

def main():
    bad = 0
    with tempfile.TemporaryDirectory() as tmp:
        for e in entries():
            ex = e["example"]
            if not ex.strip() or "..." in ex:
                print("[SKIP] %s" % e["code"])
                continue
            path = os.path.join(tmp, "example.zu")
            open(path, "w").write(ex)
            # Each line of an example that is on its own may be a separate error; run the whole text.
            p = subprocess.run([ZUE, "run", path], capture_output=True, text=True, timeout=60, cwd=tmp)
            text = p.stdout + p.stderr
            if "[%s]" % e["code"] in text:
                print("[PASS] %s" % e["code"])
            else:
                bad += 1
                print("[FAIL] %s: expected [%s] in:\n%s" % (e["code"], e["code"], text[:400]))
    sys.exit(1 if bad else 0)

main()
