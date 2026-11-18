#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
# Runs the blue thread benchmarks in Zue and, when Go is installed, the same programs in Go.
# One line per run: wall time, processor time (user + system) and peak memory.
#
# Usage: bench/blue/compare.sh [name...]      (default: all)
#   ZUE_RT_BLUE_WORKERS and GOMAXPROCS are passed on, so `ZUE_RT_BLUE_WORKERS=1 GOMAXPROCS=1 compare.sh`
#   compares one worker with one.
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

args_of() {
    case "$1" in
        spawn_wait) echo 200000 ;;
        ping_pong) echo 500000 ;;
        ring) echo 1000 1000000 ;;
        cpu_bound) echo 16 38 ;;
        producers_consumers) echo 8 200000 ;;
        parked) echo 100000 ;;
        uneven_load) echo 38 ;;
    esac
}

names=${*:-spawn_wait ping_pong ring cpu_bound producers_consumers parked uneven_load}
have_go=0
if command -v go > /dev/null 2>&1; then
    (cd "$here/go" && go build -o "$tmp/gobench" .) && have_go=1
fi
for n in $names; do
    a=$(args_of "$n")
    if [ -z "$a" ]; then
        echo "no benchmark named $n" >&2
        exit 2
    fi
    "$root/bin/zue" build "$here/$n.zu" -o "$tmp/$n" > /dev/null || exit 1
    printf '%-20s zue  ' "$n"
    /usr/bin/time -f '%e s  cpu %U+%S s  %M KB' "$tmp/$n" $a 2>&1 > /dev/null | tail -1
    if [ $have_go = 1 ]; then
        printf '%-20s go   ' "$n"
        /usr/bin/time -f '%e s  cpu %U+%S s  %M KB' "$tmp/gobench" "$n" $a 2>&1 > /dev/null | tail -1
    fi
done
