#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# gc_race_check.sh: builds programs and the runtime with ThreadSanitizer (function by function, at -O0 so that
# the frames are exact) and runs them with the GC thread slowed down. The data races the concurrent collector
# has by design are listed in gc_race_pairs.py; any other race fails the check.
#   tools/gc_race_check.sh [prog.zu ...]     default: test/test_gc_barrier.zu test/test_gc_safety.zu
# Needs clang with the thread sanitizer and python3.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
[ $# -eq 0 ] && set -- test/test_gc_barrier.zu test/test_gc_safety.zu
tsan_ir() { sed -E 's/^(define .*) \{$/\1 sanitize_thread {/' "$1" > "$2"; }
bin/zue --native $(ls compiler/runtime/*.zu | sort) -o "$TMP/rt.ll" || exit 1
tsan_ir "$TMP/rt.ll" "$TMP/rt_tsan.ll"
status=0
for prog in "$@"; do
    name=$(basename "$prog" .zu)
    bin/zue emit "$prog" -o "$TMP/$name.ll" > /dev/null || exit 1
    tsan_ir "$TMP/$name.ll" "$TMP/${name}_tsan.ll"
    clang -O0 -w -g -fsanitize=thread "$TMP/${name}_tsan.ll" "$TMP/rt_tsan.ll" -lm -lpthread -ldl -o "$TMP/$name" || exit 1
    for cfg in "ZUE_RT_GC_STRESS=25" "ZUE_RT_GC_STRESS=7 ZUE_RT_GC_SLOW=50"; do
        echo "== $name ($cfg)"
        env $cfg TSAN_OPTIONS="halt_on_error=0 report_signal_unsafe=0" "$TMP/$name" > "$TMP/out.txt" 2> "$TMP/err.txt"
        rc=$?
        [ $rc -ne 0 ] && [ $rc -ne 66 ] && { echo "[FAIL] $name exited with $rc"; status=1; }
        python3 tools/gc_race_pairs.py < "$TMP/err.txt" || status=1
    done
done
[ $status -eq 0 ] && echo "[OK] only the expected races"
exit $status
