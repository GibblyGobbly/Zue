#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
# Builds test/native/rules_unit.zu together with compiler/runtime/zue_rt_rules.zu in the
# native dialect and runs it. Exits non-zero when a check fails.
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ZUEC=${ZUEC:-$ROOT/bin/zue}
BUILD="$ROOT/compiler/llvm_build.sh"
[ -x "$ZUEC" ] || { echo "[ERROR] $ZUEC is not built; run make"; exit 1; }
"$ZUEC" --native "$ROOT/compiler/runtime/zue_rt_rules.zu" "$ROOT/test/native/rules_unit.zu" -o "$TMP/rules_unit.ll" || exit 1
"$BUILD" -O1 -o "$TMP/rules_unit" "$TMP/rules_unit.ll" || exit 1
"$TMP/rules_unit" || exit 1

# The atomic intrinsics: the values, and that the IR really has atomic instructions with the intended ordering.
"$ZUEC" --native "$ROOT/test/native/atomics_unit.zu" -o "$TMP/atomics_unit.ll" || exit 1
for want in "load atomic i64, ptr %.* acquire" "load atomic i8, ptr %.* acquire" "store atomic i64 .* release" \
            "store atomic i8 .* release" "cmpxchg ptr .* seq_cst seq_cst" "fence seq_cst"; do
    grep -q "$want" "$TMP/atomics_unit.ll" || { echo "[FAIL] atomics_unit.ll has no '$want'"; exit 1; }
done
"$BUILD" -O1 -o "$TMP/atomics_unit" "$TMP/atomics_unit.ll" || exit 1
"$TMP/atomics_unit"

# The collector's size classes: a request of 16 * 2^k bytes lands in a class just above it.
"$ZUEC" --native "$ROOT/compiler/runtime/zue_gc.zu" "$ROOT/test/native/gc_classes_unit.zu" -o "$TMP/gc_classes_unit.ll" || exit 1
"$BUILD" -O1 -o "$TMP/gc_classes_unit" "$TMP/gc_classes_unit.ll" || exit 1
"$TMP/gc_classes_unit"
