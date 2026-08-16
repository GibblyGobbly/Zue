#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# install.sh: sets up a machine to build and test Zue. Installs LLVM 22 (opt, llc, ld.lld) from apt.llvm.org,
# the C library's development files and the tools the scripts use, then builds bin/zue and runs the tests.
# For Debian, Ubuntu and the systems built on them (Linux Mint, Pop!_OS). Run it from the repository:
#   sh install.sh              install, build, test
#   sh install.sh --no-test    install and build only
# The optional tools (clang for tools/gc_race_check.sh, gdb, valgrind for bench/instruction_count.sh) are
# installed too; a failure there does not stop the script.
set -e
cd "$(dirname "$0")"
RUN_TESTS=1
[ "$1" = "--no-test" ] && RUN_TESTS=0

if ! command -v apt-get > /dev/null; then
    echo "[ERROR] this script needs apt-get (Debian, Ubuntu, Mint). Install LLVM 22 (opt, llc, ld.lld), make, python3 and the C library headers (glibc-devel), then run make"
    exit 1
fi
SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO=sudo

# apt.llvm.org names its repositories after Debian and Ubuntu releases. Mint and Pop!_OS give the Ubuntu
# release they are built on in UBUNTU_CODENAME.
. /etc/os-release
CODENAME=${UBUNTU_CODENAME:-$VERSION_CODENAME}
if [ -z "$CODENAME" ]; then
    echo "[ERROR] cannot tell the release from /etc/os-release"
    exit 1
fi
echo "== release $CODENAME"

$SUDO apt-get update
$SUDO apt-get install -y wget ca-certificates make python3 git libc6-dev

if ! command -v opt-22 > /dev/null || ! command -v ld.lld-22 > /dev/null; then
    echo "== LLVM 22 from apt.llvm.org"
    wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | $SUDO tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc > /dev/null
    echo "deb http://apt.llvm.org/$CODENAME/ llvm-toolchain-$CODENAME-22 main" | $SUDO tee /etc/apt/sources.list.d/llvm-22.list > /dev/null
    $SUDO apt-get update
    $SUDO apt-get install -y llvm-22 lld-22
fi
$SUDO apt-get install -y clang-22 gdb valgrind || echo "[WARN] an optional tool did not install; the build does not need it"
if ! command -v clang > /dev/null && command -v clang-22 > /dev/null; then
    echo "[NOTE] tools/gc_race_check.sh calls clang: link it with  sudo ln -s \$(command -v clang-22) /usr/local/bin/clang"
fi

echo "== build"
make
if [ $RUN_TESTS -eq 1 ]; then
    echo "== test"
    make test
fi
echo "[OK] bin/zue is built. Try: bin/zue run examples/hello.zu"
