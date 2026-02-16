#!/usr/bin/env bash
# Parallelized extended sweep over DDA files with broader payload offsets.
# Uses existing grammars in dda_bruteforce.py.
# Outputs to /tmp/dda_extended_sweep.log and candidate PNG/CSVs in /tmp.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$REPO_ROOT/footballPro/footballPro/Resources/GameData"
LOG="/tmp/dda_extended_sweep.log"

files=(
  "DYNAMIX.DDA"
  "CHAMP.DDA"
  "TTM/LOGOSPIN.DDA"
  "TTM/LOGOEND.DDA"
)

# Generate offsets 0x10..0x10000 step 0x200
offsets=()
for ((off=0x10; off<=0x10000; off+=0x200)); do
  offsets+=("$off")
done

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

echo "[$(timestamp)] extended sweep start" | tee -a "$LOG"

run_file() {
  local rel="$1"
  local path="$PROJECT_ROOT/$rel"
  local stem
  stem=$(basename "$rel" .DDA)

  # header-based offset if present
  local header_offset=""
  header_offset=$(python3 - "$path" <<'PY'
import struct, sys
data = open(sys.argv[1], "rb").read(32)
if data.startswith(b"DDA:") and len(data) >= 0x14:
    print(struct.unpack_from("<I", data, 0x10)[0])
PY
)

  for off in "${offsets[@]}"; do
    echo "[$(timestamp)] $stem offset=0x$(printf '%x' "$off")" >>"$LOG"
    python3 "$REPO_ROOT/tools/dda_bruteforce.py" "$path" --payload-offset "$off" --width 320 --height 200 --max-candidates 2 >>"$LOG" 2>&1 || true
  done

  if [[ -n "$header_offset" ]]; then
    for delta in -0x100 -0x80 0 0x80 0x100 0x200; do
      off=$((header_offset + delta))
      echo "[$(timestamp)] $stem header-sweep offset=0x$(printf '%x' "$off")" >>"$LOG"
      python3 "$REPO_ROOT/tools/dda_bruteforce.py" "$path" --payload-offset "$off" --width 320 --height 200 --max-candidates 2 >>"$LOG" 2>&1 || true
    done
  fi
}

# Run per file in parallel subshells
for rel in "${files[@]}"; do
  ( run_file "$rel" ) &
done

wait

echo "[$(timestamp)] extended sweep done" | tee -a "$LOG"
