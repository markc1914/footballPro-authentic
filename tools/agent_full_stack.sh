#!/usr/bin/env bash
# Agent: Full stack automation
# - Runs swift package tests
# - Captures all reference screens via ScreenshotHarness (writes to /tmp/fps_screenshots)
# - Optionally stitches PNGs to MP4 if ffmpeg is available
#
# Usage: tools/agent_full_stack.sh

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="/tmp/full_stack_agent_$(date +%Y%m%d_%H%M%S).log"

echo "[FULL] Starting at $(date)" | tee -a "$LOG"

# Use temp caches to avoid restricted user cache dirs in sandboxed runs
export CLANG_MODULE_CACHE_PATH="/tmp/clang-module-cache"
export SWIFTPM_TEST_CACHE="/tmp/.swiftpm/test-cache"
export SWIFTPM_CACHE_PATH="/tmp/.swiftpm/cache"
export DISABLE_AUDIO=1
export CI=1
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_TEST_CACHE" "$SWIFTPM_CACHE_PATH"

cd "$ROOT_DIR/footballPro"

echo "[FULL] Running swift test (unit/integration)..." | tee -a "$LOG"
swift test --disable-sandbox --parallel | tee -a "$LOG"

echo "[FULL] Capturing reference screens via ScreenshotHarnessTests..." | tee -a "$LOG"
swift test --disable-sandbox --filter ScreenshotHarnessTests/testCaptureAllScreens | tee -a "$LOG"

SCREEN_DIR="/tmp/fps_screenshots"
if [[ -d "$SCREEN_DIR" ]]; then
  echo "[FULL] Screens captured to $SCREEN_DIR" | tee -a "$LOG"
else
  echo "[FULL] WARNING: Screenshot directory not found ($SCREEN_DIR)" | tee -a "$LOG"
fi

# Optional: build MP4 from screenshots if ffmpeg is present
if command -v ffmpeg >/dev/null 2>&1 && ls "$SCREEN_DIR"/*.png >/dev/null 2>&1; then
  echo "[FULL] ffmpeg detected; building MP4 from screenshots..." | tee -a "$LOG"
  ffmpeg -y -pattern_type glob -i "$SCREEN_DIR/*.png" -r 30 -pix_fmt yuv420p /tmp/fps_screenshots.mp4 >/tmp/full_stack_ffmpeg.log 2>&1 \
    && echo "[FULL] MP4 written to /tmp/fps_screenshots.mp4" | tee -a "$LOG" \
    || echo "[FULL] ffmpeg failed, see /tmp/full_stack_ffmpeg.log" | tee -a "$LOG"
else
  echo "[FULL] ffmpeg not available or no screenshots; skipping MP4 stitching." | tee -a "$LOG"
fi

echo "[FULL] Done at $(date)" | tee -a "$LOG"
echo "[FULL] Log: $LOG" | tee -a "$LOG"
