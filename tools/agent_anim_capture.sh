#!/usr/bin/env bash
# Agent: Animation capture
# Purpose: generate spritesheets for all ANIM.DAT animations (and catalog) using python decoder, sourcing data from repo GameData.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GAMEDATA="$ROOT_DIR/footballPro/footballPro/Resources/GameData"
TMP_HOME="/tmp/anim_capture_home"
LOG="/tmp/anim_capture_agent_$(date +%Y%m%d_%H%M%S).log"
USER_SITE_DEFAULT="$(python3 - <<'PY'
import site, json
print(site.getusersitepackages())
PY
)"

echo "[ANIM_CAPTURE] Starting at $(date)" | tee -a "$LOG"

# Prepare fake home so anim_decoder finds files at ~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO
TARGET="$TMP_HOME/Downloads/front-page-sports-football-pro/DYNAMIX"
mkdir -p "$TARGET"
rm -rf "$TARGET/FBPRO"
ln -s "$GAMEDATA" "$TARGET/FBPRO"

export HOME="$TMP_HOME"
export PYTHONPATH="$USER_SITE_DEFAULT${PYTHONPATH:+:$PYTHONPATH}"

cd "$ROOT_DIR"
echo "[ANIM_CAPTURE] Using data dir: $GAMEDATA" | tee -a "$LOG"
echo "[ANIM_CAPTURE] HOME set to $HOME" | tee -a "$LOG"
echo "[ANIM_CAPTURE] PYTHONPATH includes user site: $PYTHONPATH" | tee -a "$LOG"

echo "[ANIM_CAPTURE] Rendering all animations to /tmp via anim_decoder.py…" | tee -a "$LOG"
python3 tools/anim_decoder.py 2>&1 | tee -a "$LOG"

echo "[ANIM_CAPTURE] Rendering catalog (grid) to /tmp/anim_catalog.png…" | tee -a "$LOG"
python3 tools/anim_decoder.py --catalog 2>&1 | tee -a "$LOG"

echo "[ANIM_CAPTURE] Done at $(date)" | tee -a "$LOG"
echo "[ANIM_CAPTURE] Log: $LOG" | tee -a "$LOG"
