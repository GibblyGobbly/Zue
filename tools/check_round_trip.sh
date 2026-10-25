#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 Bharath
#
# check_round_trip.sh: parses every Luna file, writes it back with `luna unparse`, parses that, and
# requires the same syntax tree (line numbers are ignored because the layout changes).
#   tools/check_round_trip.sh [file.lu ...]     default: every .lu file in the project

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
LUNA=bin/luna
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if [ $# -eq 0 ]; then
    set -- $(find compiler test examples bench -name '*.lu' | sort)
fi
same=0; bad=0
for f in "$@"; do
    # Files that hold several programs, one per "# CASE", are checked case by case.
    if grep -q '^# CASE ' "$f"; then
        total=$(grep -c '^# CASE ' "$f")
        i=0
        while [ $i -lt $total ]; do
            i=$((i + 1))
            awk -v idx=$i '/^# CASE /{n++; next} n==idx{print}' "$f" > "$TMP/case.lu"
            label="$f case $i"
            src="$TMP/case.lu"
            if ! $LUNA ast "$src" > "$TMP/a1.txt" 2> /dev/null; then
                continue    # the case is meant to be rejected by the parser
            fi
            if ! $LUNA unparse "$src" > "$TMP/round.lu" 2> "$TMP/err.txt" || ! $LUNA ast "$TMP/round.lu" > "$TMP/a2.txt" 2>> "$TMP/err.txt"; then
                bad=$((bad + 1)); echo "[FAIL] $label: $(head -2 "$TMP/err.txt" | tr '\n' ' ')"; continue
            fi
            sed 's/@[0-9]*//g' "$TMP/a1.txt" > "$TMP/b1.txt"; sed 's/@[0-9]*//g' "$TMP/a2.txt" > "$TMP/b2.txt"
            if cmp -s "$TMP/b1.txt" "$TMP/b2.txt"; then same=$((same + 1)); else bad=$((bad + 1)); echo "[FAIL] $label: trees differ"; fi
        done
        continue
    fi
    if ! $LUNA ast "$f" > "$TMP/a1.txt" 2> /dev/null; then
        continue
    fi
    if ! $LUNA unparse "$f" > "$TMP/round.lu" 2> "$TMP/err.txt" || ! $LUNA ast "$TMP/round.lu" > "$TMP/a2.txt" 2>> "$TMP/err.txt"; then
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
