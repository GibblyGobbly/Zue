#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
# Every program is compiled to a native binary and run, and stdout, stderr and the exit code
# must equal the recorded files in test/expected/. Files made of "# CASE <name>" sections run
# each case on its own.
# Usage: compiler/run_tests.sh [file.zu ...]   (default: test/*.zu)
# VERIFY_IR=1 compiler/run_tests.sh   also runs $OPT (default opt-18) -passes=verify on every generated IR file.
# RECORD=1 compiler/run_tests.sh   writes test/expected/ from the compiled programs. Read the
#                                  diff (git diff test/expected) before committing it.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
[ $# -eq 0 ] && set -- test/*.zu
RT=compiler/runtime
EXT=ll; CC=${CC:-clang}; OPT=${OPT:-opt-18}
RTSRC=$("$ROOT/compiler/build_runtime.sh") || exit 1
CASE_FILE="$TMP/case.zu"
EXPECT=test/expected
mkdir -p "$EXPECT"
ZUEC="$ROOT/bin/zue"
[ -x "$ZUEC" ] || { echo "[ERROR] $ZUEC is not built; run make"; exit 1; }
pass=0; fail=0; skip=0

# check_one <source> <label>: compiles and runs <source> on both engines. A compile-time error
# ("Type Error in ..." and so on) counts as the program's output: its text is recorded as
# stdout with exit status 1, and the program is not built.
check_one() {
    src=$1; label=$2; name=bin_$$
    key=$(printf '%s' "$label" | sed 's/[^A-Za-z0-9._-]/_/g')
    if ! "$ZUEC" "$src" "$TMP/$name.$EXT" . > "$TMP/cerr" 2>&1; then
        if grep -q "not supported by zuec" "$TMP/cerr"; then
            skip=$((skip + 1)); echo "[SKIP] $label"; return
        fi
        if ! head -1 "$TMP/cerr" | grep -q '^[A-Za-z ]* Error in '; then
            fail=$((fail + 1)); echo "[FAIL] $label (zuec)"; head -3 "$TMP/cerr"; return
        fi
        cp "$TMP/cerr" "$TMP/c.out"; : > "$TMP/c.err"; cc=1
    else
        # VERIFY_IR=1 also checks the generated IR with LLVM's verifier.
        if [ -n "$VERIFY_IR" ] && ! "$OPT" -passes=verify -disable-output "$TMP/$name.$EXT" 2> "$TMP/gerr"; then
            fail=$((fail + 1)); echo "[FAIL] $label (IR verifier)"; head -5 "$TMP/gerr"; return
        fi
        if ! $CC -O1 -w "$TMP/$name.$EXT" "$RTSRC" \
             -lm -lpthread -ldl -o "$TMP/$name" 2> "$TMP/gerr"; then
            fail=$((fail + 1)); echo "[FAIL] $label (clang)"; head -5 "$TMP/gerr"; return
        fi
        timeout 60 "$TMP/$name" > "$TMP/c.out" 2> "$TMP/c.err" < /dev/null; cc=$?
    fi
    # Error messages name the source file; the recorded outputs use this fixed name.
    sed -i "s|$CASE_FILE|/tmp/zue_test_case.zu|g" "$TMP/c.out" "$TMP/c.err"
    if [ -n "$RECORD" ]; then
        rm -f "$EXPECT/$key".*
        cp "$TMP/c.out" "$EXPECT/$key.out"; cp "$TMP/c.err" "$EXPECT/$key.err"; echo "$cc" > "$EXPECT/$key.rc"
        pass=$((pass + 1)); echo "[REC ] $label"
        return
    fi
    if [ -f "$EXPECT/$key.skip" ]; then
        skip=$((skip + 1)); echo "[SKIP] $label"; return
    fi
    if [ ! -f "$EXPECT/$key.rc" ]; then
        fail=$((fail + 1)); echo "[FAIL] $label (no recorded output; run RECORD=1 compiler/run_tests.sh)"; return
    fi
    want=$(cat "$EXPECT/$key.rc")
    if [ "$want" -eq "$cc" ] && cmp -s "$EXPECT/$key.out" "$TMP/c.out" && cmp -s "$EXPECT/$key.err" "$TMP/c.err"; then
        pass=$((pass + 1)); echo "[PASS] $label"
    else
        fail=$((fail + 1)); echo "[FAIL] $label (exit want=$want got=$cc)"
        diff "$EXPECT/$key.out" "$TMP/c.out" | head -6
        diff "$EXPECT/$key.err" "$TMP/c.err" | head -12
    fi
}

# check_golden <source>: compiled output must equal <source minus .zu>.golden.
check_golden() {
    src=$1; name=gold_$$
    gold="${src%.zu}.golden"
    if ! "$ZUEC" "$src" "$TMP/$name.$EXT" . > "$TMP/cerr" 2>&1 ||
       ! $CC -O1 -w "$TMP/$name.$EXT" "$RTSRC" \
            -lm -lpthread -ldl -o "$TMP/$name" 2> "$TMP/gerr"; then
        fail=$((fail + 1)); echo "[FAIL] $src (build)"; head -3 "$TMP/cerr" "$TMP/gerr"; return
    fi
    "$TMP/$name" > "$TMP/c.out" 2> "$TMP/c.err" < /dev/null
    if cmp -s "$TMP/c.out" "$gold"; then
        pass=$((pass + 1)); echo "[PASS] $src (golden)"
    else
        fail=$((fail + 1)); echo "[FAIL] $src (golden)"; diff "$gold" "$TMP/c.out" | head -6
    fi
}

for f in "$@"; do
    if [ -f "${f%.zu}.golden" ]; then
        check_golden "$f"
    elif grep -q '^# CASE ' "$f"; then
        # Run each case in this shell so the counters survive.
        i=0
        total=$(grep -c '^# CASE ' "$f")
        while [ $i -lt $total ]; do
            i=$((i + 1))
            awk -v idx=$i '
                /^# CASE / { n++; next }
                n == idx { print }
            ' "$f" > "$CASE_FILE"
            label="$f:case $i ($(grep '^# CASE ' "$f" | sed -n "${i}p" | sed 's/^# CASE //'))"
            check_one "$CASE_FILE" "$label"
        done
    else
        check_one "$f" "$f"
    fi
done
rm -f "$CASE_FILE"
echo "passed $pass, failed $fail, skipped $skip"
[ $fail -eq 0 ]
