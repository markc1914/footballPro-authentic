# ISSUES.md

## Context

These findings come from automated visual comparison between:

- Captured app screens: `/tmp/fps_screenshots/*.png` (32 images)
- Scene-change reference frames from YouTube gameplay video `vGlkUSrFcGU`:
  `/tmp/fps_frame_001.jpg` ... `/tmp/fps_frame_220.jpg`
- Filtered gameplay key-moment subset used for final scoring: 42 frames

Final report file:

- `/tmp/fps_compare_results_gameplay_only.json`

## Summary Metrics

- Overall mean similarity (combined score): `0.3875`
- Gameplay-only mean similarity: `0.4259`
- UI-only mean similarity: `0.3492`

Interpretation:

- Gameplay is moderately aligned but still clearly divergent.
- UI is less aligned, expected because the source video focuses on gameplay and includes watermark/compression artifacts.

## Highest-Priority Visual Gaps

### 1) Play-calling screen mismatch

- Impact: High
- Evidence:
  - `03_playcalling_kickoff.png` was the lowest gameplay match (`0.3769`)
  - Prior inspection showed layout/behavior differences vs original flow.
- Likely causes:
  - Different button bar structure and placement.
  - Opponent grid content/behavior not matching original patterns.

### 2) Field presentation does not match original geometry/details

- Impact: High
- Evidence:
  - `04_field_kickoff.png`, `16_fieldgoal_kick.png`, `19_field_kickoff_return.png` cluster near `0.4222`.
  - References emphasize yard numbers, field markings, and sideline composition not reproduced exactly.
- Likely causes:
  - Missing/incorrect yard-number paint.
  - Perspective and field detail model still simplified.

### 3) Play result and overlay styling divergence

- Impact: High
- Evidence:
  - `05_play_result.png` (`0.4294`), `11_play_result_injury.png` (`0.4450`), `14_play_result_4thdown.png` (`0.4478`).
- Likely causes:
  - Overlay panel styling, size, positioning, and typography differ from the original frames.

### 4) Referee popup style mismatch

- Impact: Medium
- Evidence:
  - `08_referee_firstdown.png` and `17_referee_good.png` both at `0.4348`.
- Likely causes:
  - Referee window framing and text treatment not matching original inset style.

### 5) Main menu and end-state UI remain non-authentic

- Impact: Medium
- Evidence:
  - Historically low/unstable UI matches in prior runs.
  - Manual review still shows menu/game-over structure different from original game flow.
- Likely causes:
  - Modernized menu option structure and simplified end-game panel.

## Comparison Quality Notes

- The YouTube source includes watermark/compression, which limits exact pixel parity.
- Scene-change extraction can over-sample short bursts; filtering by gameplay heuristics and time gap reduced bias.
- For tighter parity measurement, ideal next step is curated frame-to-screen mapping (known timestamp pairs) instead of global nearest-neighbor matching.

## Recommended Next Steps

1. Lock a canonical 32-frame reference set mapped 1:1 to harness screens.
2. Fix play-calling layout/content parity first.
3. Add authentic field yard numbers and refine field-detail composition.
4. Tune play-result/referee overlays to match original panel framing.
5. Re-run comparison and track deltas against this baseline report.

## Agents & Verification Commands

These agents run headless visual verification with audio disabled (`DISABLE_AUDIO=1`) and use the screenshot/reference comparison skill script:

- Skill script path:
  - `~/.codex/skills/compare-screenshot-reference-frames/scripts/compare_frames.py`
- Reference frames used:
  - `reference_frames/vGlkUSrFcGU/`

### Full Issue Sweep

- Run all issues:
  - `tools/agent_issues_sweep.sh`
- Reuse existing screenshots (skip capture):
  - `tools/agent_issues_sweep.sh --skip-capture`

### Per-Issue Agents

- Play-calling mismatch:
  - `tools/agent_issue_playcalling.sh`
- Field geometry/details mismatch:
  - `tools/agent_issue_field.sh`
- Play result/overlay styling:
  - `tools/agent_issue_overlays.sh`
- Referee popup style:
  - `tools/agent_issue_referee.sh`
- Main menu/end-state UI:
  - `tools/agent_issue_menu_endstate.sh`

### Output Artifacts

Each run writes a timestamped folder in:

- `/tmp/fps_issue_reports/<timestamp>/`

Key artifacts:

- `compare_results.json` (raw compare output)
- `compare_results.csv` (flat scores)
- `issues_summary.json` (issue-grouped stats)
- `issues_summary.md` (human-readable summary)
- `issue_<issue_key>.json` (per-issue details)
- `agent_issue_verify.log` (run log)
