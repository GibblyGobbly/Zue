#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
# Builds the runtime and prints the object file a program must link against.
#
# The runtime is written in Zue (compiler/runtime/*.zu). It is compiled with `zue --native`
# and clang into C/zue_rt_native.o, and rebuilt only when a runtime file or a compiler file is
# newer than the object.
#
# Usage: compiler/build_runtime.sh     prints the object path
# ZUEC=path names the compiler to use (default: bin/zue in the same tree).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
RT="$ROOT/compiler/runtime"
OUT="$ROOT/C"
OBJ="$OUT/zue_rt_native.o"
LL="$OUT/zue_rt_native.ll"
ZUEC=${ZUEC:-$ROOT/bin/zue}
CC=${CC:-clang}
STAMP="$OUT/zue_rt_native.cc"

mkdir -p "$OUT"
# The object is rebuilt when a different C compiler (or LLVM version) made it.
if [ ! -f "$OBJ" ] || [ "$(cat "$STAMP" 2>/dev/null)" != "$CC" ] || [ -n "$(find "$RT" "$ROOT/compiler" -maxdepth 1 -name '*.zu' -newer "$OBJ" 2>/dev/null)" ] \
    || [ -n "$(find "$RT" -name '*.zu' -newer "$OBJ" 2>/dev/null)" ]; then
    if [ ! -x "$ZUEC" ]; then
        echo "[ERROR] the compiler $ZUEC is not built; run make" >&2
        exit 1
    fi
    rm -f "$LL"
    "$ZUEC" --native "$RT"/*.zu -o "$LL" >&2 || exit 1
    "$CC" -O2 -w -c "$LL" -o "$OBJ" >&2 || exit 1
    echo "$CC" > "$STAMP"
fi
echo "$OBJ"
