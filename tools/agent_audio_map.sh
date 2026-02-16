#!/usr/bin/env bash
# Agent: Audio mapping report
# Purpose: show which SoundEffect cases are mapped to SAMPLE.DAT IDs, which are unmapped, and which are referenced in code.
# Usage: tools/agent_audio_map.sh

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SOUND_MANAGER="$ROOT_DIR/footballPro/footballPro/Services/SoundManager.swift"
SAMPLE_SERVICE="$ROOT_DIR/footballPro/footballPro/Services/SampleAudioService.swift"
SAMPLE_DAT="$ROOT_DIR/footballPro/footballPro/Resources/GameData/SAMPLE.DAT"
LOG="/tmp/audio_map_agent_$(date +%Y%m%d_%H%M%S).log"

echo "[AUDIO_MAP] Starting at $(date)" | tee -a "$LOG"

python3 - <<'PY' 2>&1 | tee -a "$LOG"
import re, pathlib, struct, os

root = pathlib.Path(os.environ["ROOT_DIR"])
mgr_path = pathlib.Path(os.environ["SOUND_MANAGER"])
svc_path = pathlib.Path(os.environ["SAMPLE_SERVICE"])
sample_path = pathlib.Path(os.environ["SAMPLE_DAT"])

enum_src = mgr_path.read_text()
service_src = svc_path.read_text()

enum_block = enum_src.split("enum SoundEffect", 1)[1]
enum_block = enum_block.split("// MARK: - Sound Manager", 1)[0]
effects = re.findall(r"case\s+([A-Za-z0-9_]+)", enum_block)
effects = [e.strip() for e in effects]

map_block = service_src.split("effectSampleMap", 1)[1]
map_block = map_block.split("]", 1)[0]
mapping = dict(re.findall(r"\.(\w+)\s*:\s*(\d+)", map_block))
mapped = {k: int(v) for k, v in mapping.items()}

def parse_sample_count(path: pathlib.Path):
    try:
        data = path.read_bytes()
        if len(data) < 4:
            return 0
        return struct.unpack_from("<H", data, 0)[0]
    except FileNotFoundError:
        return 0

sample_count = parse_sample_count(sample_path)

# Find uses in codebase
swift_files = list(root.glob("footballPro/footballPro/**/*.swift"))
use_regex = re.compile(r"\.play\s*\(\s*\.([A-Za-z0-9_]+)")
uses = []
for f in swift_files:
    try:
        text = f.read_text()
    except UnicodeDecodeError:
        continue
    for m in use_regex.finditer(text):
        uses.append(m.group(1))
use_set = set(uses)

effects_set = set(effects)
mapped_set = set(mapped.keys())

print(f"SoundEffect cases ({len(effects_set)}): {sorted(effects_set)}")
print(f"Mapped in SampleAudioService ({len(mapped_set)}): {sorted(mapped_set)}")
unmapped = effects_set - mapped_set
if unmapped:
    print(f"Unmapped SoundEffects: {sorted(unmapped)}")
unused_map = mapped_set - effects_set
if unused_map:
    print(f"Mappings for non-existent effects (check cleanup): {sorted(unused_map)}")

print()
print(f"Code references to play(.effect): {len(use_set)} unique -> {sorted(use_set)}")
missing_refs = use_set - effects_set
if missing_refs:
    print(f"WARNING: References to non-enum effects: {sorted(missing_refs)}")
unused_effects = effects_set - use_set
if unused_effects:
    print(f"Effects never referenced in code: {sorted(unused_effects)}")

print()
print(f"SAMPLE.DAT present: {'yes' if sample_count else 'no'}, samples: {sample_count}")
if sample_count and mapped:
    max_mapped = max(mapped.values())
    if max_mapped >= sample_count:
        print(f"WARNING: mapping uses sample id >= count ({max_mapped} vs {sample_count-1} max index)")
PY

echo "[AUDIO_MAP] Done at $(date)" | tee -a "$LOG"
echo "[AUDIO_MAP] Log: $LOG" | tee -a "$LOG"
