#!/usr/bin/env bash
# Quick agent to summarize DDA sweep status and refresh ranked candidates.
# Writes a short log to /tmp/dda_monitor_agent.log and copies top PNGs into /tmp/dda_review.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="/tmp/dda_monitor_agent.log"
SWEEP_LOG="/tmp/dda_extended_sweep.log"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

{
  echo "[$(timestamp)] monitor start"

  if [[ -f "$SWEEP_LOG" ]]; then
    echo "[$(timestamp)] sweep log tail:"
    tail -n 5 "$SWEEP_LOG"
  else
    echo "[$(timestamp)] no sweep log found at $SWEEP_LOG"
  fi

  echo "[$(timestamp)] rescoring candidates"
  python3 "$REPO_ROOT/tools/dda_inspect_agent.py"

  echo "[$(timestamp)] ranking candidates"
  python3 "$REPO_ROOT/tools/dda_rank_agent.py"

  echo "[$(timestamp)] copying review set"
  bash "$REPO_ROOT/tools/dda_review_agent.sh"

  echo "[$(timestamp)] monitor done"
} | tee "$LOG"
