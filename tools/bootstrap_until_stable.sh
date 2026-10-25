#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 Bharath
#
# bootstrap_until_stable.sh: use after a change to how the compiler generates code. Then the seed
# compiler and the compiler it builds emit different IR for the compiler's own source, and make
# stops with "boot1.ll boot2.ll differ". This builds the compiler from its own output again and
# again until two stages emit identical IR, and writes that IR to bootstrap/.
#   make                              (fails with the message above)
#   tools/bootstrap_until_stable.sh   (writes bootstrap/lunac.ll and bootstrap/luna_rt_native.ll)
#   make && make test

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
OUT=C
[ -f $OUT/boot2.ll ] && [ -f $OUT/boot_rt.ll ] || { echo "[ERROR] run make first"; exit 1; }
prev=$OUT/boot2.ll
n=2
while [ $n -le 8 ]; do
    clang -O1 -w "$prev" $OUT/boot_rt.ll -lm -lpthread -ldl -o $OUT/luna_stage$n || exit 1
    next=$OUT/boot$((n + 1)).ll
    $OUT/luna_stage$n compiler/lunac.lu "$next" . || exit 1
    if cmp -s "$prev" "$next"; then
        cp "$prev" bootstrap/lunac.ll
        cp $OUT/boot_rt.ll bootstrap/luna_rt_native.ll
        echo "[OK] stage $n and stage $((n + 1)) are identical; wrote bootstrap/lunac.ll and bootstrap/luna_rt_native.ll"
        exit 0
    fi
    prev=$next
    n=$((n + 1))
done
echo "[ERROR] the compiler did not reach a fixed point in 8 stages"
exit 1
