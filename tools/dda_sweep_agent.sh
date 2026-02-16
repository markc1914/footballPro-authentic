#!/usr/bin/env bash
# Background sweep over DDA files with multiple payload offsets/grammars.
# Logs to /tmp/dda_sweep_agent.log and emits candidate PNG/CSVs in /tmp.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$REPO_ROOT/footballPro/footballPro/Resources/GameData"
LOG="/tmp/dda_sweep_agent.log"

files=(
  "DYNAMIX.DDA"
  "CHAMP.DDA"
  "TTM/LOGOSPIN.DDA"
  "TTM/LOGOEND.DDA"
)

# Commonly observed/guessed offsets
base_offsets=(0x10 0x200 0x400 0x800 0x1000 0x1F10 0x2F20 0x3F30 0x4F40 0x6F60 0x9F90)

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

echo "[$(timestamp)] sweep start" | tee -a "$LOG"

for rel in "${files[@]}"; do
  path="$PROJECT_ROOT/$rel"
  stem=$(basename "$rel" .DDA)

  # Derive header offset if magic matches
  header_offset=$(python3 - "$path" <<'PY'
import struct, sys
data = open(sys.argv[1], "rb").read(32)
if data.startswith(b"DDA:"):
    off = struct.unpack_from("<I", data, 0x10)[0]
    print(off)
PY
)

  offsets=("${base_offsets[@]}")
  if [[ -n "$header_offset" ]]; then
    offsets+=("$header_offset")
    offsets+=($(($header_offset + 0x200)) $(($header_offset - 0x200)))
  fi

  for off in "${offsets[@]}"; do
    printf "[%s] %s offset=0x%x\n" "$(timestamp)" "$stem" "$off" | tee -a "$LOG"
    python3 "$REPO_ROOT/tools/dda_bruteforce.py" "$path" --payload-offset "$off" --width 320 --height 200 --max-candidates 4 >>"$LOG" 2>&1 || true
  done
done

echo "[$(timestamp)] sweep done" | tee -a "$LOG"
