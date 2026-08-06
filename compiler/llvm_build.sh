#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
# Turns LLVM IR into a native program with LLVM's own tools, without a C compiler: opt optimizes
# each .ll file, llc makes an object file of it, and ld.lld links the objects with the C library.
#
# Usage: compiler/llvm_build.sh [-O1|-O2] [-c] [--one-module] -o OUT INPUT...
#   INPUT is a .ll file (compiled first) or a .o file (linked as it is).
#   -c makes one object file from one .ll file and stops.
#   --one-module joins all the .ll files into one module with llvm-link before optimizing, so that
#   functions of one file can be inlined into another (zue build --release).
#        compiler/llvm_build.sh --which TOOL
#   prints the command used for TOOL (opt, llc, ld.lld, llvm-link or another LLVM tool such as
#   llvm-dwarfdump), so that other scripts use the same LLVM version.
# LLVM=N picks the LLVM version (default 22): opt-N, llc-N, ld.lld-N and llvm-link-N, or the plain
# opt, llc, ld.lld and llvm-link when those are version N (Fedora and Arch name them so). OPT, LLC,
# LLD and LLVM_LINK name the tools directly.
LLVM=${LLVM:-22}

# The command for tool $1 of version $LLVM.
pick() {
    if command -v "$1-$LLVM" > /dev/null 2>&1; then
        echo "$1-$LLVM"
    elif command -v "$1" > /dev/null 2>&1 && "$1" --version 2>/dev/null | grep -Eq "(version|LLD) $LLVM\."; then
        echo "$1"
    else
        echo "$1-$LLVM"
    fi
}

OPT=${OPT:-$(pick opt)}
LLC=${LLC:-$(pick llc)}
LLD=${LLD:-$(pick ld.lld)}
LLVM_LINK=${LLVM_LINK:-$(pick llvm-link)}

if [ "$1" = "--which" ]; then
    case "$2" in
        opt) echo "$OPT" ;;
        llc) echo "$LLC" ;;
        ld.lld) echo "$LLD" ;;
        llvm-link) echo "$LLVM_LINK" ;;
        *) pick "$2" ;;
    esac
    exit 0
fi

level=-O1
only_object=0
one_module=0
out=
while [ $# -gt 0 ]; do
    case "$1" in
        -O0|-O1|-O2|-O3) level=$1 ;;
        -c) only_object=1 ;;
        --one-module) one_module=1 ;;
        -o) out=$2; shift ;;
        *) break ;;
    esac
    shift
done
if [ -z "$out" ] || [ $# -eq 0 ]; then
    echo "usage: compiler/llvm_build.sh [-O1|-O2] [-c] [--one-module] -o OUT INPUT..." >&2
    exit 2
fi
for tool in "$OPT" "$LLC" "$LLD"; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        echo "[ERROR] $tool is not installed. Zue needs LLVM $LLVM (Debian and Ubuntu: sudo apt install llvm-$LLVM lld-$LLVM), or set LLVM to the installed version" >&2
        exit 1
    fi
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Compiles one .ll file to the object file $2.
compile() {
    "$OPT" "$level" "$1" -o "$TMP/opt.bc" || exit 1
    "$LLC" "$level" -filetype=obj -relocation-model=pic "$TMP/opt.bc" -o "$2" || exit 1
}

if [ "$one_module" = 1 ]; then
    if ! command -v "$LLVM_LINK" > /dev/null 2>&1; then
        echo "[ERROR] $LLVM_LINK is not installed. Zue needs LLVM $LLVM: sudo apt install llvm-$LLVM" >&2
        exit 1
    fi
    "$LLVM_LINK" "$@" -o "$TMP/joined.bc" || exit 1
    compile "$TMP/joined.bc" "$TMP/joined.o"
    set -- "$TMP/joined.o"
fi

if [ "$only_object" = 1 ]; then
    compile "$1" "$out"
    exit 0
fi

# Each input becomes an object file, kept in the argument list in its place.
n=$#
i=0
while [ $i -lt $n ]; do
    i=$((i + 1))
    f=$1
    shift
    case "$f" in
        *.o) set -- "$@" "$f" ;;
        *) compile "$f" "$TMP/$i.o"; set -- "$@" "$TMP/$i.o" ;;
    esac
done

# The dynamic loader and the folder of the C library's start files are asked from the system:
# ldd of /bin/sh names the loader (the one line with a full path and no "=>") and libc.so.6,
# whose folder also holds Scrt1.o, crti.o and crtn.o when the C development files are installed.
deps=$(ldd /bin/sh)
loader=$(printf '%s\n' "$deps" | awk '$1 ~ /^\// && $2 != "=>" { print $1; exit }')
libc=$(printf '%s\n' "$deps" | awk '$1 == "libc.so.6" && $2 == "=>" { print $3; exit }')
libdir=$(dirname "$libc")
if [ -z "$loader" ] || [ -z "$libc" ]; then
    echo "[ERROR] cannot find the dynamic loader and the C library from 'ldd /bin/sh'" >&2
    exit 1
fi
for f in Scrt1.o crti.o crtn.o; do
    if [ ! -f "$libdir/$f" ]; then
        echo "[ERROR] $libdir/$f is missing: install the C library development files (sudo apt install libc6-dev)" >&2
        exit 1
    fi
done

"$LLD" --hash-style=gnu --build-id --eh-frame-hdr -pie -dynamic-linker "$loader" -o "$out" \
    "$libdir/Scrt1.o" "$libdir/crti.o" "$@" -L"$libdir" -lm -lpthread -ldl -lc "$libdir/crtn.o" || exit 1
