#!/usr/bin/env bash
# Targeted sweep for DDA payload offsets near the known 0x1F10/header locations.
# Designed to be quicker than the full extended sweep; focuses on missing files.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$REPO_ROOT/footballPro/footballPro/Resources/GameData"
LOG="/tmp/dda_marker_burst.log"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

files=(
  "DYNAMIX.DDA"
  "CHAMP.DDA"
  "TTM/LOGOEND.DDA"
  "TTM/LOGOSPIN.DDA"
  "INTROPT1.DDA"
  "INTROPT2.DDA"
)

offsets=(0x1F10 0x1E90 0x1F90 0x2010)

echo "[$(timestamp)] marker burst sweep start" | tee "$LOG"

run_file() {
  local rel="$1"
  local path="$PROJECT_ROOT/$rel"
  local stem
  stem=$(basename "$rel" .DDA)

  local header_off=""
  header_off=$(python3 - "$path" <<'PY'
import struct, sys
data = open(sys.argv[1], "rb").read(32)
if data[:4] == b"DDA:" and len(data) >= 0x14:
    print(struct.unpack_from("<I", data, 0x10)[0])
PY
)

  for off in "${offsets[@]}"; do
    echo "[$(timestamp)] $stem offset=$off" | tee -a "$LOG"
    python3 "$REPO_ROOT/tools/dda_bruteforce.py" "$path" --payload-offset "$((off))" --width 320 --height 200 --max-candidates 3 >>"$LOG" 2>&1 || true
  done

  if [[ -n "$header_off" ]]; then
    for delta in -0x100 -0x80 0 0x80 0x100 0x180; do
      local off_dec=$((header_off + delta))
      echo "[$(timestamp)] $stem header offset=0x$(printf '%x' "$off_dec")" | tee -a "$LOG"
      python3 "$REPO_ROOT/tools/dda_bruteforce.py" "$path" --payload-offset "$off_dec" --width 320 --height 200 --max-candidates 3 >>"$LOG" 2>&1 || true
    done
  fi
}

for rel in "${files[@]}"; do
  run_file "$rel"
done

echo "[$(timestamp)] marker burst sweep done" | tee -a "$LOG"
