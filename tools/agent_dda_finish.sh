#!/usr/bin/env bash
# Agent: DDA finish sweep
# Purpose: rerun quick DDA header/1F10 sweeps and log results for remaining LOGOEND/DYNAMIX/CHAMP failures.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="/tmp/dda_finish_agent_$(date +%Y%m%d_%H%M%S).log"

echo "[DDA_FINISH] Starting at $(date)" | tee -a "$LOG"
cd "$ROOT_DIR"

# Quick burst over header + 0x1F10 offsets (fast)
if [[ -x tools/dda_marker_burst_agent.sh ]]; then
  echo "[DDA_FINISH] Running marker burst sweep…" | tee -a "$LOG"
  tools/dda_marker_burst_agent.sh 2>&1 | tee -a "$LOG"
else
  echo "[DDA_FINISH][WARN] tools/dda_marker_burst_agent.sh missing or not executable" | tee -a "$LOG"
fi

# Inspect top candidates (if any) to refresh shortlist
if [[ -x tools/dda_inspect_agent.py ]]; then
  echo "[DDA_FINISH] Re-inspecting candidates for rescoring…" | tee -a "$LOG"
  python3 tools/dda_inspect_agent.py --scores /tmp/dda_top_candidates.txt --top 20 2>&1 | tee -a "$LOG" || true
fi

echo "[DDA_FINISH] Done at $(date)" | tee -a "$LOG"
echo "[DDA_FINISH] Log: $LOG" | tee -a "$LOG"
