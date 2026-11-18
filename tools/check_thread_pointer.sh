#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# Checks that no function that can give up its worker keeps the address of thread data in a register.
#
# A blue thread can stop on one worker (operating system thread) and go on on another. Thread data (lv_pos,
# lv_depth, _wk0 and the other tspace and per_thread words) is reached through the thread pointer %fs, and
# LLVM takes the thread pointer to stay the same inside a function. An access written %fs:name@TPOFF reads the
# pointer again and is always right; an address made from it (movq %fs:0, reg) is the old worker's address
# after a switch. So a function that can switch, or call something that can, must not make one.
#
# Which functions can switch is worked out from the machine code: lvn_switch_stack (switch_stack) switches,
# a call through a pointer can run any Zue function, and a function that calls (or jumps to) one that can
# switch can switch too. The runtime and the files given are looked at as one program, so a call from
# generated code to a runtime function counts. Allowed, with the reason:
#   _blue_idle_loop, _blue_worker  run on the worker's own stack, which never goes to another worker
#   _thread_main     runs the program's own thread, which stays on the first worker (CO_PIN)
#   _blue_switch, _slow_blue_exit  make the address before the switch only; checked here as well: no
#                    function uses %fs:0 after its call of lvn_switch_stack (except _blue_idle_loop)
#
# Usage: tools/check_thread_pointer.sh [file.ll ...]
#   With no file: the compiler's own IR (C/boot1.ll, from make), which holds every form the code generator
#   writes. The runtime (C/zue_rt_native.ll, from compiler/build_runtime.sh) is always included.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OPT=$("$ROOT/compiler/llvm_build.sh" --which opt)
LLC=$("$ROOT/compiler/llvm_build.sh" --which llc)
TRIPLE=x86_64-pc-linux-gnu
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ $# -eq 0 ]; then
    set -- "$ROOT/C/boot1.ll"
fi
"$ROOT/compiler/build_runtime.sh" > /dev/null || exit 1

# Appends the machine code of $1, optimized as a build does ($2: -O2 for the runtime, -O1 for programs).
asm() {
    if [ ! -f "$1" ]; then
        echo "[ERROR] $1 does not exist; run make first" >&2
        exit 1
    fi
    "$OPT" -mtriple="$TRIPLE" "$2" "$1" -o "$TMP/o.bc" || exit 1
    "$LLC" -mtriple="$TRIPLE" -O2 "$TMP/o.bc" -o - >> "$TMP/all.s" || exit 1
}
: > "$TMP/all.s"
asm "$ROOT/C/zue_rt_native.ll" -O2
for f in "$@"; do
    asm "$f" -O1
done

awk -v files="the runtime and $*" '
    FNR == NR {
        if ($1 == ".type" && $2 ~ /@function$/) {
            name = $2
            sub(/,@function$/, "", name)
            isfn[name] = 1
        }
        next
    }
    /^[^ \t.#][^ \t]*:/ {
        label = $1
        sub(/:$/, "", label)
        if (label in isfn) {
            cur = label
            after[cur] = 0
        }
        next
    }
    cur == "" { next }
    /^\t(callq|jmp)\t/ {
        target = $2
        sub(/@PLT$/, "", target)
        if (target ~ /^\*/) {
            indirect[cur] = 1
        } else if (target in isfn) {
            calls[cur] = calls[cur] " " target
            if (target == "lvn_switch_stack") {
                after[cur] = 1
            }
        }
    }
    /%fs:0,/ {
        fs0[cur]++
        if (after[cur] && cur != "_blue_idle_loop") {
            late[cur] = 1
        }
    }
    END {
        allowed["_blue_idle_loop"] = 1
        allowed["_blue_worker"] = 1
        allowed["_thread_main"] = 1
        allowed["_blue_switch"] = 1
        allowed["_slow_blue_exit"] = 1
        sw["lvn_switch_stack"] = 1
        for (fn in indirect) {
            sw[fn] = 1
        }
        changed = 1
        while (changed) {
            changed = 0
            for (fn in calls) {
                if (fn in sw) {
                    continue
                }
                n = split(calls[fn], cs, " ")
                for (i = 1; i <= n; i++) {
                    if (cs[i] in sw) {
                        sw[fn] = 1
                        changed = 1
                        break
                    }
                }
            }
        }
        bad = 0
        for (fn in fs0) {
            if ((fn in sw) && !(fn in allowed)) {
                printf "[FAIL] %s can switch blue threads and keeps the thread pointer (%d times %%fs:0)\n", fn, fs0[fn]
                bad = 1
            }
        }
        for (fn in late) {
            printf "[FAIL] %s uses %%fs:0 after switch_stack\n", fn
            bad = 1
        }
        nsw = 0
        for (fn in sw) {
            nsw++
        }
        if (!bad) {
            printf "[OK] thread pointer: %d functions of %s can switch blue threads, none keeps the thread pointer\n", nsw, files
        }
        exit bad
    }
' "$TMP/all.s" "$TMP/all.s"
