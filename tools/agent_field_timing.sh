#!/usr/bin/env bash
# Summarize field-play frame logs for timing alignment.
# Usage: tools/agent_field_timing.sh [log_path]
# Default log path: /tmp/fps_frame_log.jsonl
# Capture frames by launching the app with:
#   FPS_FRAME_LOG=/tmp/fps_frame_log.jsonl open footballPro/footballPro.xcodeproj

set -euo pipefail

LOG_PATH=${1:-/tmp/fps_frame_log.jsonl}

if [[ ! -s "$LOG_PATH" ]]; then
  echo "⚠️  No frame log found at $LOG_PATH"
  echo "Generate one by running the app with FPS_FRAME_LOG=$LOG_PATH (plays will log per-frame JSON)."
  exit 1
fi

python3 - <<'PY' "$LOG_PATH"
import json, sys, math

path = sys.argv[1]
frames = []
with open(path, "r") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            frames.append(json.loads(line))
        except json.JSONDecodeError:
            continue

if not frames:
    print("⚠️  Frame log is empty or malformed.")
    sys.exit(1)

frames.sort(key=lambda f: f.get("elapsed", 0.0))
elapsed = [f.get("elapsed", 0.0) for f in frames]
phases = {}
for f in frames:
    phases[f.get("phase", "unknown")] = phases.get(f.get("phase", "unknown"), 0) + 1

start, end = elapsed[0], elapsed[-1]
duration = max(end - start, 1e-6)
fps = (len(frames) - 1) / duration if len(frames) > 1 else 0

def fmt_phases():
    total = sum(phases.values())
    lines = []
    for name, count in sorted(phases.items(), key=lambda kv: kv[0]):
        pct = (count / total) * 100 if total else 0
        lines.append(f"    {name:14s}: {count:4d} frames ({pct:4.1f}%)")
    return "\n".join(lines)

# Ball travel stats
ball_depths = []
for f in frames:
    b = f.get("ballScreen", {})
    ball_depths.append(b.get("y", 0))

print("Field Timing Summary")
print(f"  Frames:    {len(frames)}")
print(f"  Duration:  {duration:.3f}s (elapsed {start:.3f} -> {end:.3f})")
print(f"  Measured FPS: {fps:.2f}")
print("  Phases:")
print(fmt_phases())
print(f"  Ball screen Y range: {min(ball_depths):.1f} .. {max(ball_depths):.1f}")

PY
