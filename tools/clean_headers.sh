# Remove conflicting sched types header
#!/bin/bash
set -eu

export ANDROID_BUILD_TOP="$PWD"

./bionic/libc/kernel/tools/clean_header.py -u \
    "$1/usr/include/asm/signal.h" \
    "$1/usr/include/asm-generic/signal.h"
echo "Removing conflicting linux/sched/types.h"; find "$@" -path "*/linux/sched/types.h" -delete 2>/dev/null || true
