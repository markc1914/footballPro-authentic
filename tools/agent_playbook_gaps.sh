#!/usr/bin/env bash
# Agent: Playbook gaps report
# Purpose: quantify missing offensive/defensive plays exposed in PlaybookData.json
#          relative to original PRF banks (7 plays per PRF file) and list the banks.
# Usage: tools/agent_playbook_gaps.sh

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DATA="$ROOT_DIR/footballPro/footballPro/Resources/GameData"
PLAYBOOK_JSON="$ROOT_DIR/footballPro/footballPro/Resources/PlaybookData.json"
LOG="/tmp/playbook_gaps_agent_$(date +%Y%m%d_%H%M%S).log"

echo "[PLAYBOOK_GAPS] Starting at $(date)" | tee -a "$LOG"

python3 - <<'PY' 2>&1 | tee -a "$LOG"
import json, pathlib

import os
root = pathlib.Path(os.environ["ROOT_DIR"])
game = pathlib.Path(os.environ["GAME_DATA"])
play_json = pathlib.Path(os.environ["PLAYBOOK_JSON"])

def list_prf(prefix):
    return sorted([p.name for p in game.glob(f"{prefix}*.PRF")])

off_prf = list_prf("OFF")
def_prf = list_prf("DEF")

with play_json.open() as f:
    data = json.load(f)

off_json = data.get("offensivePlays", [])
def_json = data.get("defensivePlays", [])

OFF_PLAYS_PER_PRF = 7  # format spec: 7 plays per bank

off_total_available = len(off_prf) * OFF_PLAYS_PER_PRF
def_total_available = len(def_prf) * OFF_PLAYS_PER_PRF

print(f"Original PRF banks (GameData):")
print(f"  Offensive PRF files ({len(off_prf)}): {', '.join(off_prf)}")
print(f"  Defensive PRF files ({len(def_prf)}): {', '.join(def_prf)}")
print()
print(f"App exposure (PlaybookData.json):")
print(f"  Offensive plays exposed: {len(off_json)} / ~{off_total_available} available")
print(f"  Defensive plays exposed: {len(def_json)} / ~{def_total_available} available")
print()

def top_formations(entries, label):
    from collections import Counter
    c = Counter(e.get("formation") for e in entries if isinstance(e, dict))
    top = ", ".join(f"{k}:{v}" for k, v in c.most_common())
    print(f"{label} formation counts: {top}")

top_formations(off_json, "Offense")
top_formations(def_json, "Defense")

missing_off = max(off_total_available - len(off_json), 0)
missing_def = max(def_total_available - len(def_json), 0)
print()
print(f"Approx. plays still to surface: offense {missing_off}, defense {missing_def}")
PY

echo "[PLAYBOOK_GAPS] Done at $(date)" | tee -a "$LOG"
echo "[PLAYBOOK_GAPS] Log: $LOG" | tee -a "$LOG"
