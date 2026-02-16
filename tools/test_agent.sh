#!/usr/bin/env bash
# Lightweight background test runner ("agent") for Football Pro.
# Usage: tools/test_agent.sh [extra swift test args]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$REPO_ROOT/footballPro"
LOG_FILE="/tmp/footballpro_test_agent.log"
CACHE_ROOT="/tmp/footballpro_cache"

mkdir -p "$CACHE_ROOT/clang" "$CACHE_ROOT/swift"
export CLANG_MODULE_CACHE_PATH="$CACHE_ROOT/clang"
export SWIFT_MODULECACHE_PATH="$CACHE_ROOT/swift"
export SWIFTPM_DISABLE_SANDBOX=1
export DISABLE_AUDIO=1

cd "$PROJECT_ROOT"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] starting swift test $*" | tee -a "$LOG_FILE"
# Run tests in parallel; disable sandbox to avoid sandbox-exec failures in CI; forward extra args.
swift test --disable-sandbox --parallel "$@" 2>&1 | tee -a "$LOG_FILE"
STATUS=${PIPESTATUS[0]}
echo "[$(date '+%Y-%m-%d %H:%M:%S')] finished swift test status=$STATUS" | tee -a "$LOG_FILE"

exit "$STATUS"
