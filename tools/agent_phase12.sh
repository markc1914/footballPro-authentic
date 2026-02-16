#!/usr/bin/env bash
# Agent: Phase 1+2 orchestrator
# Purpose:
#   1) Refresh DDA decoding sweep/rescore to chase remaining cutscenes.
#   2) Summarize field-play timing from a captured FPS_FRAME_LOG JSONL.
#
# Usage:
#   tools/agent_phase12.sh [/path/to/frame_log.jsonl]
# Notes:
#   - Step 1 uses existing agent_dda_finish.sh (burst sweep + rescoring shortlist).
#   - Step 2 uses agent_field_timing.sh; to collect a log, launch the app with:
#       FPS_FRAME_LOG=/tmp/fps_frame_log.jsonl open footballPro/footballPro.xcodeproj
#     then run this agent with the same path.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="/tmp/phase12_agent_$(date +%Y%m%d_%H%M%S).log"
FRAME_LOG_PATH="${1:-/tmp/fps_frame_log.jsonl}"

echo "[PHASE12] Starting at $(date)" | tee -a "$LOG"
echo "[PHASE12] Using frame log: $FRAME_LOG_PATH" | tee -a "$LOG"

# Step 1: DDA finish sweep + rescore
if [[ -x "$ROOT_DIR/tools/agent_dda_finish.sh" ]]; then
  echo "[PHASE12] Running agent_dda_finish.sh ..." | tee -a "$LOG"
  "$ROOT_DIR/tools/agent_dda_finish.sh" | tee -a "$LOG"
else
  echo "[PHASE12] WARNING: agent_dda_finish.sh not found or not executable." | tee -a "$LOG"
fi

# Step 2: Field timing summary
if [[ -x "$ROOT_DIR/tools/agent_field_timing.sh" ]]; then
  echo "[PHASE12] Running agent_field_timing.sh ..." | tee -a "$LOG"
  "$ROOT_DIR/tools/agent_field_timing.sh" "$FRAME_LOG_PATH" | tee -a "$LOG"
else
  echo "[PHASE12] WARNING: agent_field_timing.sh not found or not executable." | tee -a "$LOG"
fi

echo "[PHASE12] Done at $(date)" | tee -a "$LOG"
echo "[PHASE12] Log: $LOG" | tee -a "$LOG"
