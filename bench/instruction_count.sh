#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# instruction_count.sh: how many machine instructions the lexer, parser and type checker execute on a
# file. Instruction counts do not depend on machine load, so they compare cleanly between changes.
#   bench/instruction_count.sh [file.zu]       default: a generated 2000-line file
# Needs valgrind.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
FILE=$1
if [ -z "$FILE" ]; then
    FILE=$TMP/generated.zu
    i=0
    while [ $i -lt 2000 ]; do
        echo "let v$i = $i + $i"
        i=$((i + 1))
    done > "$FILE"
fi
bin/zue build bench/frontend_phases.zu -o "$TMP/phases" > /dev/null || exit 1
valgrind --tool=callgrind --callgrind-out-file="$TMP/cg.out" "$TMP/phases" "$FILE" 2>&1 | grep "Collected" | sed 's/.*Collected : /instructions: /'
