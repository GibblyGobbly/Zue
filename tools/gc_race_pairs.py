# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# gc_race_pairs.py: reads ThreadSanitizer reports on standard input and sorts the data races into the one
# kind the concurrent collector has by design, and everything else. Exits 1 when anything else appears.
#   expected: the GC thread scanning an object (_scan_range, called from _scan_top) while the program writes it.
#   The object bitmaps, line epochs and block kinds the GC thread reads while the program allocates are read and
#   written with atomic loads and stores, so they make no report.
import re
import sys

text = sys.stdin.read()
ACCESS = re.compile(r"(?:Previous )?(?:[Aa]tomic )?(write|read) of size (\d+) at 0x[0-9a-f]+ by (?:main thread|thread T\d+)[^\n]*:\n\s+#0 (\S+)[^\n]*\n(?:\s+#1 (\S+))?", re.I)
seen = {}
bad = {}
for block in text.split("WARNING: ThreadSanitizer: data race")[1:]:
    head = block.split("Location is")[0].split("Thread T")[0]
    acc = [(m.group(1).lower(), m.group(3), m.group(4)) for m in ACCESS.finditer(head)][:2]
    if len(acc) < 2:
        bad[("unparsed", block[:200])] = bad.get(("unparsed", block[:200]), 0) + 1
        continue
    scan = [a for a in acc if a[1] == "_scan_range" and a[2] == "_scan_top" and a[0] == "read"]
    other = [a for a in acc if a not in scan]
    if scan and len(other) == 1 and other[0][0] == "write":
        seen["object contents"] = seen.get("object contents", 0) + 1
    else:
        bad[tuple(acc)] = bad.get(tuple(acc), 0) + 1
for k, v in sorted(seen.items()):
    print("expected: %d reports, %s" % (v, k))
for k, v in bad.items():
    print("UNEXPECTED: %d reports: %s" % (v, k))
sys.exit(1 if bad else 0)
