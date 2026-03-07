#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# package_release.sh: builds dist/zue-<version>-linux-x86_64.tar.gz from the built compiler.
#
# The compiler finds its runtime relative to itself (bin/zue -> ../compiler/build_runtime.sh), so
# the archive keeps that layout. The runtime object is built here, so the first program does not
# have to compile it. Needs a built bin/zue (run make first) and clang.
#
# Usage: tools/package_release.sh
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
VERSION=$(cat VERSION)
NAME=zue-$VERSION-linux-x86_64
STAGE=dist/$NAME

[ -x bin/zue ] || { echo "[ERROR] bin/zue is not built; run make" >&2; exit 1; }
compiler/build_runtime.sh > /dev/null

rm -rf dist
mkdir -p "$STAGE/bin" "$STAGE/compiler/runtime" "$STAGE/C"
cp bin/zue "$STAGE/bin/"
cp compiler/build_runtime.sh "$STAGE/compiler/"
cp compiler/runtime/*.zu "$STAGE/compiler/runtime/"
cp C/zue_rt_native.o C/zue_rt_native.cc "$STAGE/C/"
cp -r examples "$STAGE/"
cp LICENSE README.md VERSION "$STAGE/"
# the prebuilt object must not look older than the sources it was made from
touch "$STAGE/C/zue_rt_native.o"

tar -C dist -czf "dist/$NAME.tar.gz" "$NAME"
(cd dist && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
echo "[OK] dist/$NAME.tar.gz"
