#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# bootstrap_new_interface.sh: use after a change to what generated code and the runtime agree on (a
# symbol of the runtime that generated code names, or its kind, such as a variable that becomes one per
# thread). Then the code the seed compiler generates no longer links with the runtime of the current
# sources, and make stops at the link of stage 1. This builds stage 1 with the runtime of the seed
# instead, lets it compile the new runtime and the compiler, and goes on until two stages emit the
# same IR. Then it writes the seeds.
#   tools/bootstrap_new_interface.sh   (writes bootstrap/zuec.ll and bootstrap/zue_rt_native.ll)
#   make && make test                  (if a test fails: git checkout bootstrap/)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
OUT=C
BUILD=compiler/llvm_build.sh
mkdir -p $OUT bin
echo "[1] seed compiler from bootstrap/"
$BUILD -O1 -o $OUT/zue_seed bootstrap/zuec.ll bootstrap/zue_rt_native.ll || exit 1
echo "[2] the seed compiles the compiler: its code still fits the seed's runtime"
$OUT/zue_seed compiler/zuec.zu $OUT/boot1.ll . || exit 1
$BUILD -O1 -o $OUT/zue_stage1 $OUT/boot1.ll bootstrap/zue_rt_native.ll || exit 1
echo "[3] stage 1 compiles the new runtime and the compiler, with the new interface"
$OUT/zue_stage1 --native $(ls compiler/runtime/*.zu | sort) -o $OUT/boot_rt.ll || exit 1
prev=$OUT/boot2.ll
$OUT/zue_stage1 compiler/zuec.zu $prev . || exit 1
n=2
while [ $n -le 8 ]; do
    $BUILD -O1 -o $OUT/zue_stage$n "$prev" $OUT/boot_rt.ll || exit 1
    next=$OUT/boot$((n + 1)).ll
    $OUT/zue_stage$n compiler/zuec.zu "$next" . || exit 1
    if cmp -s "$prev" "$next"; then
        $OUT/zue_stage$n --native $(ls compiler/runtime/*.zu | sort) -o $OUT/boot_rt_check.ll || exit 1
        cmp -s $OUT/boot_rt.ll $OUT/boot_rt_check.ll || { echo "[ERROR] stage 1 and stage $n compile the runtime differently"; exit 1; }
        cp "$prev" bootstrap/zuec.ll
        cp $OUT/boot_rt.ll bootstrap/zue_rt_native.ll
        echo "[OK] stage $n and stage $((n + 1)) are identical; wrote bootstrap/zuec.ll and bootstrap/zue_rt_native.ll"
        exit 0
    fi
    prev=$next
    n=$((n + 1))
done
echo "[ERROR] the compiler did not reach a fixed point in 8 stages"
exit 1
