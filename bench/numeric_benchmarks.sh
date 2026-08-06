#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# numeric_benchmarks.sh: compile and time the programs in bench/numeric with a chosen LLVM version
# and optimization level, so changes to the generated code or the toolchain can be compared.
#   bench/numeric_benchmarks.sh [llvm-version] [opt-level]     e.g. 23 -O2   (default: the version of
#   compiler/llvm_build.sh, -O1)
# Prints the best of three run times and the compile time (opt, llc, ld.lld) for each program.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
VER=$1
LEVEL=${2:--O1}
if [ -n "$VER" ]; then LLVM=$VER; export LLVM; fi
BUILD=compiler/llvm_build.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
RT=$(compiler/build_runtime.sh) || exit 1
echo "toolchain: $($("$BUILD" --which opt) --version | grep -i "llvm version" | head -1 | sed 's/^ *//')  level: $LEVEL"
printf '%-14s %10s %10s\n' program run_s compile_s
for f in bench/numeric/*.zu; do
    name=$(basename "$f" .zu)
    bin/zue emit "$f" -o "$TMP/$name.ll" > /dev/null || exit 1
    t0=$(date +%s.%N)
    "$BUILD" $LEVEL -o "$TMP/$name" "$TMP/$name.ll" "$RT" || exit 1
    t1=$(date +%s.%N)
    best=999999
    for run in 1 2 3; do
        s=$(date +%s.%N)
        "$TMP/$name" > /dev/null
        e=$(date +%s.%N)
        best=$(echo "$best $s $e" | awk '{d=$3-$2; if (d<$1) print d; else print $1}')
    done
    printf '%-14s %10.3f %10.3f\n' "$name" "$best" "$(echo "$t0 $t1" | awk '{print $2-$1}')"
done
