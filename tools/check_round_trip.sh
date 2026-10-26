#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# check_round_trip.sh: parses every Zue file, writes it back with `zue unparse`, parses that, and
# requires the same syntax tree (line numbers are ignored because the layout changes).
#   tools/check_round_trip.sh [file.zu ...]     default: every .zu file in the project

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
ZUE=bin/zue
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if [ $# -eq 0 ]; then
    set -- $(find compiler test examples bench -name '*.zu' | sort)
fi
same=0; bad=0
for f in "$@"; do
    # Files that hold several programs, one per "# CASE", are checked case by case.
    if grep -q '^# CASE ' "$f"; then
        total=$(grep -c '^# CASE ' "$f")
        i=0
        while [ $i -lt $total ]; do
            i=$((i + 1))
            awk -v idx=$i '/^# CASE /{n++; next} n==idx{print}' "$f" > "$TMP/case.zu"
            label="$f case $i"
            src="$TMP/case.zu"
            if ! $ZUE ast "$src" > "$TMP/a1.txt" 2> /dev/null; then
                continue    # the case is meant to be rejected by the parser
            fi
            if ! $ZUE unparse "$src" > "$TMP/round.zu" 2> "$TMP/err.txt" || ! $ZUE ast "$TMP/round.zu" > "$TMP/a2.txt" 2>> "$TMP/err.txt"; then
                bad=$((bad + 1)); echo "[FAIL] $label: $(head -2 "$TMP/err.txt" | tr '\n' ' ')"; continue
            fi
            sed 's/@[0-9]*//g' "$TMP/a1.txt" > "$TMP/b1.txt"; sed 's/@[0-9]*//g' "$TMP/a2.txt" > "$TMP/b2.txt"
            if cmp -s "$TMP/b1.txt" "$TMP/b2.txt"; then same=$((same + 1)); else bad=$((bad + 1)); echo "[FAIL] $label: trees differ"; fi
        done
        continue
    fi
    if ! $ZUE ast "$f" > "$TMP/a1.txt" 2> /dev/null; then
        continue
    fi
    if ! $ZUE unparse "$f" > "$TMP/round.zu" 2> "$TMP/err.txt" || ! $ZUE ast "$TMP/round.zu" > "$TMP/a2.txt" 2>> "$TMP/err.txt"; then
        bad=$((bad + 1)); echo "[FAIL] $f: $(head -2 "$TMP/err.txt" | tr '\n' ' ')"; continue
    fi
    sed 's/@[0-9]*//g' "$TMP/a1.txt" > "$TMP/b1.txt"; sed 's/@[0-9]*//g' "$TMP/a2.txt" > "$TMP/b2.txt"
    if cmp -s "$TMP/b1.txt" "$TMP/b2.txt"; then
        same=$((same + 1))
    else
        bad=$((bad + 1)); echo "[FAIL] $f: trees differ"; diff "$TMP/b1.txt" "$TMP/b2.txt" | head -4 | cut -c1-200
    fi
done
echo "round trip: $same same, $bad different"
[ $bad -eq 0 ]
