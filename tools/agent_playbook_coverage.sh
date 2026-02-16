#!/usr/bin/env bash
# Agent: Playbook coverage audit
# Purpose: compare original OFF/DEF playbooks to current JSON-backed play selection.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DATA="$ROOT_DIR/footballPro/footballPro/Resources/GameData"
PLAYBOOK_JSON="$ROOT_DIR/footballPro/footballPro/Resources/PlaybookData.json"
LOG="/tmp/playbook_coverage_agent_$(date +%Y%m%d_%H%M%S).log"

echo "[PLAYBOOK] Starting at $(date)" | tee -a "$LOG"

python3 - <<PY 2>&1 | tee -a "$LOG"
import json, pathlib
from collections import Counter

root = pathlib.Path("${ROOT_DIR}")
game = root / "footballPro/footballPro/Resources/GameData"
play_json = root / "footballPro/footballPro/Resources/PlaybookData.json"

def count_files(pattern):
    return sorted([p.name for p in game.glob(pattern)])

off_prf = count_files("OFF*.PRF")
def_prf = count_files("DEF*.PRF")
pln = count_files("*.PLN")

with play_json.open() as f:
    data = json.load(f)
off_json = data.get("offensivePlays", [])
def_json = data.get("defensivePlays", [])

print(f"GameData OFF*.PRF files: {len(off_prf)} -> {off_prf}")
print(f"GameData DEF*.PRF files: {len(def_prf)} -> {def_prf}")
print(f"GameData *.PLN files: {len(pln)} -> {pln}")
print(f"App offensivePlays count: {len(off_json)}")
print(f"App defensivePlays count: {len(def_json)}")

# Formation tally from JSON (helps spot breadth gaps)
form_counts = Counter(p.get("formation") for p in off_json if isinstance(p, dict))
print("Offensive formations present:", dict(form_counts))
PY

echo "[PLAYBOOK] Done at $(date)" | tee -a "$LOG"
echo "[PLAYBOOK] Log: $LOG" | tee -a "$LOG"
