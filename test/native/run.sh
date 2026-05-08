#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
# Builds test/native/rules_unit.zu together with compiler/runtime/zue_rt_rules.zu in the
# native dialect and runs it. Exits non-zero when a check fails.
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ZUEC=${ZUEC:-$ROOT/bin/zue}
[ -x "$ZUEC" ] || { echo "[ERROR] $ZUEC is not built; run make"; exit 1; }
"$ZUEC" --native "$ROOT/compiler/runtime/zue_rt_rules.zu" "$ROOT/test/native/rules_unit.zu" -o "$TMP/rules_unit.ll" || exit 1
"${CC:-clang}" -O1 -w "$TMP/rules_unit.ll" -o "$TMP/rules_unit" || exit 1
"$TMP/rules_unit" || exit 1

# The atomic intrinsics: the values, and that the IR really has atomic instructions with the intended ordering.
"$ZUEC" --native "$ROOT/test/native/atomics_unit.zu" -o "$TMP/atomics_unit.ll" || exit 1
for want in "load atomic i64, ptr %.* acquire" "load atomic i8, ptr %.* acquire" "store atomic i64 .* release" \
            "store atomic i8 .* release" "cmpxchg ptr .* seq_cst seq_cst" "fence seq_cst"; do
    grep -q "$want" "$TMP/atomics_unit.ll" || { echo "[FAIL] atomics_unit.ll has no '$want'"; exit 1; }
done
"${CC:-clang}" -O1 -w "$TMP/atomics_unit.ll" -o "$TMP/atomics_unit" || exit 1
"$TMP/atomics_unit"
