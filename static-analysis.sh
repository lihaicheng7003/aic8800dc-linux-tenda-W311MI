#!/bin/bash
# Static analysis for the aic8800dc driver: sparse + gcc W=1 + cppcheck.
# Advisory only. It prints warnings and never touches the tree.
#
# Needs kernel headers for the running kernel, plus sparse and cppcheck:
#   Debian/Ubuntu: sudo apt-get install sparse cppcheck linux-headers-$(uname -r)
#   Arch:          sudo pacman -S sparse cppcheck linux-headers
#
# Run it from anywhere:  ./static-analysis.sh
# Drop build artifacts afterwards with:  make -C drivers/aic8800 clean

set -u
cd "$(dirname "$0")"

KDIR="/lib/modules/$(uname -r)/build"
BUILD_LOG="/tmp/aic-analyze-build.log"
CPPCHECK_LOG="/tmp/aic-cppcheck.log"

if [ ! -d "$KDIR" ]; then
    echo "kernel headers not found at $KDIR" >&2
    echo "install linux-headers for $(uname -r) and retry" >&2
    exit 1
fi

echo "== sparse + gcc W=1 =="
make -C "$KDIR" M="$(pwd)/drivers/aic8800" W=1 C=1 modules 2>&1 \
    | tee "$BUILD_LOG" || true

echo
echo "== cppcheck =="
if command -v cppcheck >/dev/null 2>&1; then
    cppcheck --enable=warning,performance,portability \
        --inline-suppr --quiet --suppress=missingIncludeSystem \
        drivers/aic8800/aic8800_fdrv drivers/aic8800/aic_load_fw 2>&1 \
        | tee "$CPPCHECK_LOG" || true
else
    echo "cppcheck not installed, skipping" >&2
    : > "$CPPCHECK_LOG"
fi

echo
echo "== summary =="
echo "sparse + W=1 warnings: $(grep -c 'warning:' "$BUILD_LOG" 2>/dev/null || true)"
echo "cppcheck findings:     $(wc -l < "$CPPCHECK_LOG" 2>/dev/null || echo 0)"
echo
echo "logs: $BUILD_LOG , $CPPCHECK_LOG"
