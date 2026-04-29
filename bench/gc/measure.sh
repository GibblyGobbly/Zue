#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly
#
# measure.sh: builds bench/gc/live_heap.zu once and runs it for several live-heap sizes, printing
# wall time, CPU time (user + system), peak memory and the collector's own statistics.
#   bench/gc/measure.sh [build flags]       e.g. bench/gc/measure.sh --gc=throughput
#   SIZES="256 1024 4096" CHURN=20000000 bench/gc/measure.sh
# The flags go to `zue build`. MODE=big uses a few huge lists instead of many small objects.

ROOT=$(cd "$(dirname "$0")/.." && pwd)/..
cd "$ROOT" || exit 1
SIZES=${SIZES:-"256 1024 4096"}
CHURN=${CHURN:-20000000}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
bin/zue build "$@" bench/gc/live_heap.zu -o "$TMP/live_heap" || exit 1
for mb in $SIZES; do
    extra=""
    [ "$MODE" = big ] && extra=big
    echo "== live ${mb} MiB, churn ${CHURN}, mode ${MODE:-small} $*"
    ZUE_RT_GC_STATS=1 /usr/bin/time -f "wall_s %e  user_s %U  sys_s %S  peak_rss_kib %M" \
        "$TMP/live_heap" "$mb" "$CHURN" $extra 2>&1
done
