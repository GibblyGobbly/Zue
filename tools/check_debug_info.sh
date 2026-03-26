#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# check_debug_info.sh: builds the examples with `zue build -g`, runs them, and checks that the line
# table names the Zue file and that the IR passes LLVM's verifier. Needs llvm-dwarfdump-18 and opt-18.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail=0
for f in examples/*.zu; do
    name=$(basename "$f" .zu)
    if ! bin/zue build -g "$f" -o "$TMP/$name" >/dev/null 2>"$TMP/err"; then
        echo "[FAIL] $f: build with -g failed"; cat "$TMP/err" | head -5; fail=1; continue
    fi
    if ! llvm-dwarfdump-18 --debug-line "$TMP/$name" 2>/dev/null | grep -q "$name.zu"; then
        echo "[FAIL] $f: the line table does not name $name.zu"; fail=1; continue
    fi
    if ! opt-18 -passes=verify "C/$name.ll" -disable-output 2>"$TMP/err"; then
        echo "[FAIL] $f: the IR does not verify"; head -3 "$TMP/err"; fail=1; continue
    fi
    echo "[PASS] $f (debug info)"
done
exit $fail
