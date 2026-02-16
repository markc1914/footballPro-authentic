#!/usr/bin/env bash
# Agent: Audio sample sanity check
# Purpose: list SAMPLE.DAT entries to confirm decoder coverage.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="/tmp/audio_check_agent_$(date +%Y%m%d_%H%M%S).log"

echo "[AUDIO] Starting at $(date)" | tee -a "$LOG"
cd "$ROOT_DIR"

if [[ ! -f footballPro/footballPro/Resources/GameData/SAMPLE.DAT ]]; then
  echo "[AUDIO][ERROR] SAMPLE.DAT not found under Resources/GameData" | tee -a "$LOG"
  exit 1
fi

echo "[AUDIO] Listing samples via sample_decoder.py…" | tee -a "$LOG"
python3 tools/sample_decoder.py -i footballPro/footballPro/Resources/GameData/SAMPLE.DAT --list 2>&1 | tee -a "$LOG"

echo "[AUDIO] Done at $(date)" | tee -a "$LOG"
echo "[AUDIO] Log: $LOG" | tee -a "$LOG"
