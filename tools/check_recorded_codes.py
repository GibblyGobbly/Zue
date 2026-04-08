#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# check_recorded_codes.py: every error in the recorded test output must carry an error code, so a
# new message that no family in compiler/error_codes.txt matches is found by `make codes-check`.
import glob, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEADER = re.compile(r'^[A-Za-z ]* Error in ')
bad = []
for path in sorted(glob.glob(os.path.join(ROOT, 'test', 'expected', '*'))):
    if path.endswith('.rc'):
        continue
    lines = open(path, errors='replace').read().split('\n')
    for i, line in enumerate(lines):
        if HEADER.match(line):
            bad.append('%s: %s' % (os.path.basename(path), (lines[i + 1] if i + 1 < len(lines) else '').strip()))
for b in bad:
    print('no code:', b)
print('%d recorded errors without a code' % len(bad))
sys.exit(1 if bad else 0)
