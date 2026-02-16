#!/usr/bin/env bash
# Agent: Field warning locator
# Purpose: surface the compiler-warning region in FPSFieldView.swift for quick cleanup.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="/tmp/field_warning_agent_$(date +%Y%m%d_%H%M%S).log"
FILE="$ROOT_DIR/footballPro/footballPro/Views/Game/FPSFieldView.swift"

echo "[FIELD_WARN] Starting at $(date)" | tee -a "$LOG"

if [[ ! -f "$FILE" ]]; then
  echo "[FIELD_WARN][ERROR] $FILE not found" | tee -a "$LOG"
  exit 1
fi

echo "[FIELD_WARN] Showing lines around 520-540 (compiler reported ~527)…" | tee -a "$LOG"
nl -ba "$FILE" | sed -n '515,545p' | tee -a "$LOG"

echo "[FIELD_WARN] Done at $(date)" | tee -a "$LOG"
echo "[FIELD_WARN] Log: $LOG" | tee -a "$LOG"
