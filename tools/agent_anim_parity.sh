#!/usr/bin/env bash
# Agent: Animation parity check
# Purpose: smoke-test animation tick pipeline and collect logs for parity review.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT_DIR/footballPro"
LOG="/tmp/anim_parity_agent_$(date +%Y%m%d_%H%M%S).log"
CACHE_ROOT="/tmp/footballpro_cache"

echo "[ANIM_PARITY] Starting at $(date)" | tee -a "$LOG"
cd "$PROJECT_ROOT"

# Run the full Swift test suite; captures warnings about FPSFieldView timing if present.
echo "[ANIM_PARITY] Running swift test (parallel, disable sandbox)…" | tee -a "$LOG"
mkdir -p "$CACHE_ROOT/clang" "$CACHE_ROOT/swift"
export CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang"
export SWIFT_MODULECACHE_PATH="$CACHE_ROOT/swift"
export SWIFTPM_DISABLE_SANDBOX=1
export DISABLE_AUDIO=1

swift test --disable-sandbox --parallel 2>&1 | tee -a "$LOG"

echo "[ANIM_PARITY] NOTE: Visual frame-by-frame parity still needs in-app capture against DOS reference frames." | tee -a "$LOG"
echo "[ANIM_PARITY] Done at $(date)" | tee -a "$LOG"
echo "[ANIM_PARITY] Log: $LOG" | tee -a "$LOG"
