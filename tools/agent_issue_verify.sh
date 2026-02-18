#!/usr/bin/env bash
# Agent: issue-driven visual verification using screenshot/reference comparison.
#
# This agent:
# 1) Optionally captures fresh harness screenshots (audio disabled)
# 2) Uses compare-screenshot-reference-frames skill script for scoring
# 3) Writes issue-focused summaries based on ISSUES.md priorities
#
# Usage:
#   tools/agent_issue_verify.sh [--issue ISSUE_KEY] [--skip-capture] [--output-dir DIR]

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT_DIR/footballPro"
REFERENCE_DIR="$ROOT_DIR/reference_frames/vGlkUSrFcGU"
SCREENSHOT_DIR="/tmp/fps_screenshots"
COMPARE_SCRIPT="${HOME}/.codex/skills/compare-screenshot-reference-frames/scripts/compare_frames.py"
ISSUE="all"
SKIP_CAPTURE=0
OUT_DIR=""

usage() {
  cat <<'EOF'
Usage: tools/agent_issue_verify.sh [options]

Options:
  --issue KEY           One of: all, playcalling, field_geometry, overlay_styling, referee_popup, menu_endstate
  --skip-capture        Reuse existing /tmp/fps_screenshots and skip swift screenshot capture
  --reference-dir DIR   Override reference frame directory (default: reference_frames/vGlkUSrFcGU)
  --screenshots-dir DIR Override screenshot directory (default: /tmp/fps_screenshots)
  --output-dir DIR      Output directory (default: /tmp/fps_issue_reports/<timestamp>)
  --compare-script PATH Override compare_frames.py path
  --help                Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      ISSUE="${2:-}"
      shift 2
      ;;
    --skip-capture)
      SKIP_CAPTURE=1
      shift
      ;;
    --reference-dir)
      REFERENCE_DIR="${2:-}"
      shift 2
      ;;
    --screenshots-dir)
      SCREENSHOT_DIR="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --compare-script)
      COMPARE_SCRIPT="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "[ISSUES_AGENT] Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

case "$ISSUE" in
  all|playcalling|field_geometry|overlay_styling|referee_popup|menu_endstate)
    ;;
  *)
    echo "[ISSUES_AGENT] Invalid --issue value: $ISSUE" >&2
    exit 2
    ;;
esac

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="/tmp/fps_issue_reports/$(date +%Y%m%d_%H%M%S)"
fi
mkdir -p "$OUT_DIR"

LOG="$OUT_DIR/agent_issue_verify.log"
COMPARE_JSON="$OUT_DIR/compare_results.json"
COMPARE_CSV="$OUT_DIR/compare_results.csv"
SUMMARY_SCRIPT="$ROOT_DIR/tools/issue_summary.py"
MANIFEST_PATH="$REFERENCE_DIR/manifest.txt"

echo "[ISSUES_AGENT] Starting at $(date)" | tee -a "$LOG"
echo "[ISSUES_AGENT] ISSUE=$ISSUE" | tee -a "$LOG"
echo "[ISSUES_AGENT] OUT_DIR=$OUT_DIR" | tee -a "$LOG"

if [[ ! -f "$COMPARE_SCRIPT" ]]; then
  echo "[ISSUES_AGENT] Missing comparison script: $COMPARE_SCRIPT" | tee -a "$LOG" >&2
  exit 2
fi
if [[ ! -f "$SUMMARY_SCRIPT" ]]; then
  echo "[ISSUES_AGENT] Missing summary script: $SUMMARY_SCRIPT" | tee -a "$LOG" >&2
  exit 2
fi
if [[ ! -d "$REFERENCE_DIR" ]]; then
  echo "[ISSUES_AGENT] Missing reference directory: $REFERENCE_DIR" | tee -a "$LOG" >&2
  exit 2
fi

# Keep swift caches in /tmp and force audio off for headless runs.
CACHE_ROOT="/tmp/footballpro_cache"
mkdir -p "$CACHE_ROOT/clang" "$CACHE_ROOT/swift" "/tmp/clang-module-cache" "/tmp/.swiftpm/cache" "/tmp/.swiftpm/test-cache"
export CLANG_MODULE_CACHE_PATH="/tmp/clang-module-cache"
export SWIFT_MODULECACHE_PATH="$CACHE_ROOT/swift"
export SWIFTPM_CACHE_PATH="/tmp/.swiftpm/cache"
export SWIFTPM_TEST_CACHE="/tmp/.swiftpm/test-cache"
export SWIFTPM_DISABLE_SANDBOX=1
export DISABLE_AUDIO=1
export CI=1

if [[ "$SKIP_CAPTURE" -eq 0 ]]; then
  echo "[ISSUES_AGENT] Capturing screenshots via ScreenshotHarnessTests..." | tee -a "$LOG"
  cd "$PROJECT_ROOT"
  swift test --disable-sandbox --filter ScreenshotHarnessTests/testCaptureAllScreens 2>&1 | tee -a "$LOG"
fi

if ! ls "$SCREENSHOT_DIR"/*.png >/dev/null 2>&1; then
  echo "[ISSUES_AGENT] No screenshots found in $SCREENSHOT_DIR" | tee -a "$LOG" >&2
  exit 2
fi

echo "[ISSUES_AGENT] Running comparison skill script..." | tee -a "$LOG"
python3 "$COMPARE_SCRIPT" \
  --screenshots "$SCREENSHOT_DIR/*.png" \
  --references "$REFERENCE_DIR" \
  --manifest "$MANIFEST_PATH" \
  --output-json "$COMPARE_JSON" \
  --output-csv "$COMPARE_CSV" \
  --edge-weight 0.65 \
  --min-gap-seconds 1.5 \
  --green-min 0.25 \
  --std-min 0.12 \
  --edge-min 0.015 \
  --top-k 5 2>&1 | tee -a "$LOG"

echo "[ISSUES_AGENT] Building issue summaries..." | tee -a "$LOG"
python3 "$SUMMARY_SCRIPT" \
  --compare-json "$COMPARE_JSON" \
  --output-dir "$OUT_DIR" \
  --issue "$ISSUE" 2>&1 | tee -a "$LOG"

echo "[ISSUES_AGENT] Done at $(date)" | tee -a "$LOG"
echo "[ISSUES_AGENT] Outputs:" | tee -a "$LOG"
echo "[ISSUES_AGENT] - $COMPARE_JSON" | tee -a "$LOG"
echo "[ISSUES_AGENT] - $COMPARE_CSV" | tee -a "$LOG"
echo "[ISSUES_AGENT] - $OUT_DIR/issues_summary.json" | tee -a "$LOG"
echo "[ISSUES_AGENT] - $OUT_DIR/issues_summary.md" | tee -a "$LOG"
echo "[ISSUES_AGENT] Log: $LOG" | tee -a "$LOG"
