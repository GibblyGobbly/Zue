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
"$TMP/rules_unit"
