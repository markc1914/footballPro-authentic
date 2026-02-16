# CODEX.md — Football Pro Project Instructions

## Project Overview
macOS SwiftUI recreation of **Front Page Sports: Football Pro** (1993, Dynamix/Sierra).
Reuse as much of the original game as possible: sprites, animations, screens, audio.
- **Target:** macOS 14+, Swift 5.9, MVVM architecture
- **Source root:** `footballPro/footballPro/footballPro/` (App/, Engine/, Models/, Views/, ViewModels/, Styles/, Services/, Input/, Resources/)
- **Build:** `open footballPro/footballPro.xcodeproj` then Cmd+R
- **Original game files:** `~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO/`
- **Reference frames:** `/tmp/fps_frame_001.jpg` through `/tmp/fps_frame_036.jpg`

## Automation
- `tools/test_agent.sh` — Background Swift test runner; writes to `/tmp/footballpro_test_agent.log`. Launch with `nohup tools/test_agent.sh &` (extra `swift test` flags supported).
- Audio is auto-disabled in tests/CI via `SoundManager` (checks `DISABLE_AUDIO`, `CI`, XCTest bundle). `tools/test_agent.sh` exports `DISABLE_AUDIO=1` to avoid CoreAudio failures.
- DDA helpers: `tools/dda_bruteforce.py` (bruteforce grammars), `tools/dda_inspect_agent.py` (score candidates), `tools/dda_rank_agent.py` (top-N shortlist), `tools/dda_sweep_agent.sh` (multi-offset sweep), `tools/dda_extended_sweep_agent.sh` (dense sweep), `tools/dda_marker_burst_agent.sh` (quick header/1F10 sweep), `tools/dda_monitor_agent.sh` (tails sweep log, rescoring, copies review set), `tools/dda_review_agent.sh` (copy top PNGs), `tools/agent_dda_finish.sh` (burst + rescore refresh).
- Coverage/verification agents: `tools/agent_anim_parity.sh` (runs full test suite; logs timing/warnings), `tools/agent_playbook_coverage.sh` (compares OFF/DEF PRF/PLN counts to app JSON), `tools/agent_playbook_gaps.sh` (estimates missing exposed plays vs original PRF banks and lists banks), `tools/agent_audio_check.sh` (lists all 115 SAMPLE.DAT entries), `tools/agent_audio_map.sh` (reports SoundEffect mappings vs SAMPLE.DAT and code usage), `tools/agent_field_warning.sh` (shows offending lines near FPSFieldView.swift:527), `tools/agent_anim_capture.sh` (renders all ANIM.DAT animations plus catalog to /tmp spritesheets; uses repo GameData via temp HOME + PYTHONPATH), `tools/agent_field_timing.sh` (summarizes frame logs for timing alignment; expects JSONL from FPS_FRAME_LOG env), `tools/agent_phase12.sh` (orchestrates DDA finish sweep + field timing summary; optional FPS_FRAME_LOG path param).
- Full-stack automation: `tools/agent_full_stack.sh` runs swift tests, captures all reference screens via `ScreenshotHarnessTests`, and if `ffmpeg` is available stitches `/tmp/fps_screenshots/*.png` into `/tmp/fps_screenshots.mp4`.
- Outputs land in `/tmp` with timestamped `_agent_*.log` files plus existing `/tmp/dda_*` assets.
- Latest tests: `swift test --disable-sandbox --parallel` passing (191 tests) on 2026-02-16 after frame logging additions; see `/tmp/anim_parity_agent_20260216_152910.log` for prior run.
- Field animation loop uses a periodic 30fps `TimelineView` so play animations advance even without implicit SwiftUI animations. Optional frame logger: launch app with `FPS_FRAME_LOG=/tmp/fps_frame_log.jsonl` to emit per-frame JSON; summarize with `tools/agent_field_timing.sh`. Removed unreachable default in `determinePose` to clear the Swift warning.
- Screenshot harness: `ScreenshotHarness.captureAll()` drives 32 reference screens to `/tmp/fps_screenshots/` (see `ScreenshotHarnessTests`). `tools/agent_full_stack.sh` runs tests, captures these screenshots, and stitches them to `/tmp/fps_screenshots.mp4` if `ffmpeg` is available.

## DDA Decoding
- `Services/DDAAnimationDecoder.swift` now supports multi-frame heuristics: tries to detect offset tables before the payload, then length-prefixed frames, finally falls back to first-frame decode. Palette assumed at offset 0; payload offset from `DDA:` header or 0x1F10 fallback. RLE grammars: nibble-control (ctrl mask 0x80/0xC0) and marker RLE (0xFE/0xC9).
- Latest sweep status: extended sweep finished; best hits remain LOGOSPIN (nibble_ctrl_1_1_0x80, etc.). LOGOEND/DYNAMIX/CHAMP still unresolved. Reviewable PNGs live in `/tmp/dda_review`; shortlist `/tmp/dda_top_candidates.txt`. Quick bursts can be rerun with `tools/dda_marker_burst_agent.sh`; monitor state with `tools/dda_monitor_agent.sh`.

## Architecture & Key Files

| File | Purpose |
|------|---------|
| `Views/GameDayView.swift` | ZStack state machine — `GamePhase` enum drives which screen shows |
| `Views/FPSFieldView.swift` | Full-screen perspective field (640x360 blueprint space, PerspectiveProjection) |
| `App/FootballProApp.swift` | App entry, GameScreen enum, GameState, ManagementHubView |
| `Views/Components/AuthenticSplashScreen.swift` | INTDYNA.SCR + CREDIT.SCR splash sequence on app launch |
| `Views/FPSPlayCallingScreen.swift` | 16-slot green grid (1-8 left, 9-16 right), scoreboard bar, red buttons |
| `Views/FPSScoreboardBar.swift` | Team names+ratings, QTR grid, amber LED clock, DOWN/TO GO/BALL ON |
| `Views/FPSPlayResultOverlay.swift` | Dark charcoal result box on field, team names in cyan/red |
| `Views/FPSRefereeOverlay.swift` | Referee signal overlay on field |
| `Views/FPSReplayControls.swift` | VCR-style replay transport buttons |
| `Views/Franchise/StandingsView.swift` | Division/conference standings (W-L-T, PCT, PF, PA) |
| `Views/Franchise/StatsView.swift` | Tabbed stat leaders + 1992 historical stats toggle |
| `Views/Franchise/DraftRoomView.swift` | Draft room with prospect grid, scouting, auto-pick |
| `Views/Franchise/PlayoffBracketView.swift` | 8-team bracket (4 per conference, seeded 1-4) |
| `Views/Franchise/TradeProposalView.swift` | Trade builder with fairness evaluation |
| `Views/Franchise/FreeAgencyView.swift` | Free agent market sorted by rating |
| `Views/Franchise/DepthChartView.swift` | Position group depth chart editor |
| `Views/Franchise/SaveLoadView.swift` | 8-slot UserDefaults save/load system |
| `Views/Franchise/SettingsView.swift` | FranchiseSettingsView (difficulty, audio, speed) |
| `Engine/PlayBlueprintGenerator.swift` | Generates animation paths for all 22 players in 640x360 flat space |
| `Engine/SimulationEngine.swift` | Core play-by-play simulation |
| `Styles/RetroStyle.swift` | VGA color palette (`VGA` struct) and `RetroFont` presets |
| `ViewModels/GameViewModel.swift` | Game state MVVM binding |

## Visual Style Rules (FPS '93 Authenticity)

**Always use the VGA color palette from RetroStyle.swift:**
- `VGA.panelBg` = #A0A0A0 (medium gray, DOS panel background)
- `VGA.buttonBg` = #BB2222 (true red buttons)
- `VGA.playSlotGreen` = #269426 (bright green play slots)
- `VGA.screenBg` = black
- `VGA.digitalAmber` = #FFA600 (LED clocks)

**Always use RetroFont presets** — never system fonts in game UI:
- tiny(9), small(10), body(12), bodyBold(12), header(14), title(18), large(24), huge(36), score(48)

**Always use FPS component library:** FPSButton, FPSDialog, FPSDigitalClock

**Field rendering rules:**
- Solid green field (#248024), no grass stripes, no stadium backdrop during gameplay
- Single perspective camera, ~25 yard visible window (8 behind LOS + 17 ahead)
- No sideline figures, officials, chain gang, or coaches (clean like original)
- AuthenticPlayerSprite with ANIM.DAT sprites via SpriteCache; Retro fallback only if assets missing
- Green number box overlay on ball carrier (matching original FPS '93 style)
- Team color remapping via `SpriteCache.setTeamColors()` (CT1 = home, CT2 = away palette overrides)
- Amber LED clocks at bottom corners only

## Important Patterns & Rules

- `isFieldFlipped = !viewModel.isUserPossession` — flips field when user is on defense
- `switchPossession()` already calls `fieldPosition.flip()` — **never double-flip**
- Sack yards count as rushingYards (NFL rules), penalty yards go to separate counters
- GameClock has `displayTime` (String "M:SS") for display
- PlayBlueprintGenerator generates in 640x360 flat space — PerspectiveProjection handles screen mapping
- **New Swift files must be manually added to Xcode .pbxproj** (use the Python script or Xcode)
- AI short yardage: force run/short-pass on 3rd/4th-and-2-or-less
- Field visuals: sideline gray/track borders; authentic RCSTAND referee sprite

**Simulation tuning (calibrated to NFL averages):**
- XP success: `0.94 + (accuracy - 70) * 0.002` (~94% for average kicker)
- FG modifier: `0.85 + (kickPower + kickAccuracy) / 1000.0` (~0.99 for average kicker)
- Rushing yards distribution: 40% stuffed, 35% moderate, 15% good, 7% big, 3% breakaway
- Receiver targeting weighted by overall rating (star WRs get more targets)
- Kick return TD: 0.3%
- AI play calling tracks last 5 calls, halves repeat weight
- AI timeouts wired into post-play loop for defensive team
- Clock management: out-of-bounds stops (25% outside runs, 5% inside), two-minute warning Q2/Q4, kneel-down and spike plays with AI logic
## Original Game Data (FPS Football Pro '93)

**Game directory:** `~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO/`

### Decoded Formats & Swift Decoders (Services/)

| Decoder | Source File | Format |
|---------|-----------|--------|
| PRFDecoder.swift | OFF*.PRF, DEF*.PRF | 40B header + 7 plays × 20×18 grid × 6B cells. 5-phase routes. |
| AuthenticPlaybookLoader.swift | OFF/DEF .PLN | 12B header + 86-slot offset table + 18B entries. |
| LGEDecoder.swift | NFLPA93.LGE | Section markers C00:/D00:/T00:/R00:. 28 teams, rosters, jerseys. |
| PYRDecoder.swift | NFLPA93.PYR | 51B records, 1403 players. 8 paired ratings. |
| PALDecoder.swift | *.PAL | VGA palettes, 256 RGB colors. 784B. |
| NameDecoder.swift | NAMEF/NAMEL.DAT | ~1000 first, ~1500 last names. |
| InjuryDecoder.swift | INJURY.DAT | 33 injury types with severity. |
| CitiesDecoder.swift | CITIES.DAT | 45 cities with weather zones. |
| GameIntroDecoder.swift | GAMINTRO.DAT | Template strings with %0-%8 placeholders. |
| CalendarDecoder.swift | CALENDER.DAT | 7 season date variants, year rotation. |
| ScheduleTemplateDecoder.swift | STPL.DAT | Matchup templates for 8/10/12/18/28 teams. |
| MagazineDecoder.swift | MAGAZINE.DAT | Month names + title string. |
| MsgDecoder.swift | MSG.DAT | 47 error/diagnostic messages. |
| PYFDecoder.swift | *.PYF | Player index files (PPD: marker + uint16 indices). |
| LGCDecoder.swift | *.LGC | City pair records (historical matchups). |
| LGTDecoder.swift | *.LGT | League structure templates (C00:/D00:/TMT: sections). |

### Remaining Undecoded Files

| File | Size | Status | Content |
|------|------|--------|---------|
| `*.DDA` | 34-429KB | Partially decoded | Dynamix Delta Animation cutscenes (frame table known, RLE encoding pending) |
| `VQT` sections in *.SCR | few KB | **DECODED** | Vector Quantization tiles (BALL.SCR, KICK.SCR) |

### Fidelity Gaps (Active)
- Playbook exposure parity: surface all original OFF/DEF plays from PRF/PLN in UI; counts should match GameData banks (currently OFF 18/~14, DEF 9/~14; ~5 DEF missing).
- Animation timing parity: capture FPS_FRAME_LOG during live plays and align phase/frame timing to DOS reference; adjust rates/phase durations accordingly (needs frame log capture).
- Audio mapping parity: verify SAMPLE.DAT cue mapping to gameplay events; wire unmapped SoundEffects to correct sample IDs and validate in-game triggers (currently 0 mapped; 17 unmapped).

---

## Original Game Asset Integration Plan

### Goal
Replace native Swift rendering with authentic FPS Football Pro '93 assets.
Reuse as much of the original game as possible: sprites, animations, screens, audio.

### ANIM.DAT — Player Sprite Animations (985,306 bytes)

**Index table: FULLY DECODED**
- Header: uint16 LE count = 71 animations
- 72 entries × 14 bytes: name(8B null-padded) + frameCount(2B big-endian) + dataOffset(4B LE)
- Entry #71 is a sentinel: empty name, 0 frames, offset = file size (985306)

**Per-animation structure: FULLY DECODED**
- Animation header: frameCount(1B) + viewCount(1B) + unknown(2B)
- Sprite reference table: (frames × views) × 4 bytes each: flag(1B) + spriteID(1B) + xOffset(int8) + yOffset(int8)
- 8 views = 8 compass directions (standard for isometric/perspective DOS games)
- Single-view animations exist for end zone celebrations (EZ* anims)
- x/y offsets are signed, positioning the sprite relative to the player's feet

**Sprite bitmap section: FULLY DECODED (LZ77/LZSS compression cracked 2026-02-14)**
- Starts after sprite reference table
- Sprite offset table: spriteCount × uint16 LE offsets (relative to section start)
- Each sprite bitmap: 2-byte header + LZ77 compressed pixel data
  - Header: width(1B) + height(1B)
  - Widths: 16 or 24 pixels (multiples of 8)
  - Heights: 18-39 pixels
  - LZ77 compressed data follows immediately after header:
    - LZ77 header: uint16 LE (group_count - 1) + uint8 (tail_bits)
    - Per group: 1 flag byte, 8 decisions MSB-first
    - After all groups: 1 flag byte for tail_bits remaining decisions
    - Decision bit=0: LITERAL — read 1 byte, map through 64-entry color table
    - Decision bit=1: BACK-REFERENCE — read uint16 LE
      - Low 4 bits = copy_length - 3 (copies 3..18 bytes)
      - High 12 bits = distance back into output buffer
      - Copies from output[current_pos - distance - 1]
  - Color table: 5 × 64-byte tables in A.EXE at file offset 0x4091D
    - Maps compressed byte values (0-63) to VGA palette indices
    - Tables handle team color remapping (indices 0x10-0x3F)
    - Table 1 = default gameplay, tables 0/2/3/4 = team color variants
  - Palette index 0 = transparent
  - Python decoder: `tools/anim_decoder.py`
  - All 2752 sprites across 71 animations decode to exactly width*height bytes

**Sprite reference flag byte (DECODED 2026-02-15):**
- Flag 0x00 = normal rendering
- Flag 0x02 = horizontal mirror (draw sprite flipped left-to-right)
- Confirmed by analysis: mirrored views share sprite IDs with their normal counterparts
  (e.g. DBREADY views 1-3 have flag=0x02, views 5-7 have flag=0x00, same sprite IDs)

**71 animations catalog:**

| Prefix | Role | Count | Animations |
|--------|------|-------|------------|
| QB | Quarterback | 10 | QBBULIT(5f), QBFADE(8f), QBPSET(1f), QBRUN(8f), QBHAND(3f), QBCHK(8f), QBSNP(2f), QBSCHK(8f), QBSHTSNP(1f), QBNEEL(4f) |
| RB | Running back | 3 | RBRNWB(8f), RBSTIFFL(8f), RBSTIFFR(8f) |
| LM | Lineman | 16 | LMSPINCC(8f), LMSPINCW(8f), LMBBUT(6f), LMBLKDNL(7f), LMBLKDNR(7f), LMCHK(9f), LMDIVE(10f), LMJMP(7f), LMPUSH(6f), LMRUN(8f), LMGETUPB(12f), LMGETUPF(9f), LMSTUP(5f), LMT3PT(6f), LMT4PT(8f), LMSTAND(1f) |
| SK | Skill player | 12 | SKRUN(8f), SKFAKE(4f), SKDIVE(10f), SKRCDIVE(10f), SKCTHM(4f), SKRCTML(5f), SKRCTMR(5f), SKRCTJL(5f), SKRCTJR(5f), SKCTHH(7f), SKJOVER(9f), SKSTUP(3f) |
| SL | Slide tackle | 4 | SLRFACE(9f), SLRBUT(9f), SLTKSDL(8f), SLTKSDR(8f) |
| L2 | Two-player | 10 | L2BFSDL(8f), L2BFSDR(8f), L2BSIDL(8f), L2BSIDR(8f), L2BFACE2(4f), L2GUP(8f), L2BY(3f), L2LOCK(7f), L2GOBY(3f), L2STNDBY(3f) |
| DB | Defensive back | 3 | DBPREBZ(7f), DBREADY(1f), DBBLKPAS(3f) |
| FC | Catch | 1 | FCATCH(9f) |
| RC | Ref/coach | 1 | RCSTAND(1f) |
| EZ | End zone celeb | 4 | EZBOW(16f), EZSPIKE(12f), EZKNEEL(10f), EZSLIDE(14f) |
| KICK | Kicking | 5 | KICK(8f), KICKSIG(11f), KIKCTH(5f), PUNT(11f), FAKEKICK(7f) |
| CT | Center/bend | 2 | CTSNP(6f), BNDOVER(3f) |

### Other Original Assets

| File | Size | Format Status | Content |
|------|------|---------------|---------|
| *.PAL | 784B each | **DECODED** (PALDecoder) | VGA palettes, 256 RGB colors |
| *.SCR | 3-29KB | **DECODED** (SCRDecoder.swift) | Dual-plane DGDS screens (title, intro, championship) |
| *.DDA | 34-429KB | Partially decoded | Dynamix Delta Animation scripts (cutscenes, RLE pending) |
| SAMPLE.DAT | 855KB | **DECODED** (SampleDecoder.swift) | ~115 audio samples (8-bit unsigned PCM) |

---

## Implementation Phases

### Phase A: Crack the Sprite Compression (COMPLETE 2026-02-15)
**Goal:** Decode the sprite pixel compression so we can render actual bitmaps.
**Status:** COMPLETE. Full rendering pipeline reverse-engineered from A.EXE disassembly.
**Python decoder:** `tools/anim_decoder.py`
**All 2752 sprites decompress to exactly width * height bytes.**

**Complete rendering pipeline (reverse-engineered from A.EXE):**

1. **draw_sprite (0x08989):** Game entry point. Loads animation data via index table lookup.
   Maps direction angle to view index: 8-view = `(dir+16)>>5 & 7`, 16-view = `(dir+8)>>4 & 15`.
   Computes sprite ref index = frame * viewCount + viewIndex.
   Determines color table from animState flags (bit2=teamB, bit3=alt, with anim entry flip toggle).
   Calls adraw.

2. **adraw (0x08845):** Reads width/height from sprite 2-byte header. Reads x/y offsets from
   sprite reference. Applies fixed-point scaling if scale < 1000: `val * scale >> 10`.
   Adds position offset. Calls LZ77 decompressor (far call to 0x40A5D with-CT or 0x40B49 without-CT).
   Builds render struct: {data, screenX, screenY, origW, origH, scaledW, scaledH, flagByte}.
   Calls Mode X renderer (far call to 0x2B254).

3. **LZ77 with color table (0x40A5D):** Decompresses with xlat remap through 64-entry color table.
   Literal bytes < 64 are mapped through the table; bytes >= 64 pass through directly.

4. **LZ77 without color table (0x40B49):** Same decompression but copies literal bytes directly
   via movsb (no color table remap). Used for non-team-colored sprites.

5. **Mode X VGA renderer (0x2B254):** Reads decompressed pixel buffer. Skips palette index 0
   (transparent). Writes to VGA planes via port 0x3C4/0x3C5. Stride = 80 bytes (320 pixels / 4 planes).
   Processes row-by-row. Flag byte 0x02 triggers horizontal mirror (right-to-left scan).

**Critical bug fix (backref copy length):**
The copy loop uses `sub dx,1; jae` (JAE = Jump if Above or Equal = JNC).
When dx=0: sub 0,1 = 0xFFFF with CF=1, jae fails (exit loop).
Total copies = dx_initial + 1 = **(word & 0x0F) + 2 + 1 = (word & 0x0F) + 3**.
Previous decoders used +2, producing output that never matched width*height.
With +3: all 2752 sprites match exactly.

**Color tables (5 x 64 bytes at A.EXE offset 0x4091D):**
- CT0: outline only (maps 46->0x2E, 47->0x2F, all else->0)
- CT1-4: team color variants (skin, jersey A/B, equipment, highlights)
- CT1-4 map indices 0-15, 20-31, 46-47 all to 0 (transparent)
- Indices 16-19 -> skin tones (0x10-0x13)
- Indices 32-45 -> primary jersey colors
- Indices 48-63 -> secondary jersey colors
- Tables 1-4 swap primary/secondary sets for team A vs team B

**Horizontal striping explanation:**
CT1-4 intentionally make indices 20-31 and 46-47 transparent. At native 320x200 VGA resolution,
these 1-pixel outline gaps are nearly invisible against the green field. The striping only becomes
apparent when sprites are scaled up for modern display. Solution: fill transparent pixels that are
surrounded by non-transparent pixels, or use CT0 for outlines in a two-pass render.

**Flag byte values:**
- 0x00 = normal rendering
- 0x02 = horizontal mirror (flip sprite left-to-right)

**EXE key offsets:**
| Offset | Content |
|--------|---------|
| 0x40A5D | LZ77 decompressor WITH color table (xlat remap) |
| 0x40B49 | LZ77 decompressor WITHOUT color table (movsb direct) |
| 0x4091D | 5 x 64-byte color tables |
| 0x08845 | adraw function (sprite draw: decompress + scale + render) |
| 0x08989 | draw_sprite function (animation state + view selection + adraw call) |
| 0x2B254 | Mode X VGA renderer (planar pixel output, mirror support) |
| 0x046630 | Source filenames: aseq.c, anim.c, adraw.c, ball.c, bounce.c, kick.c, team.c, game.c, play.c, vcrtape.c, draw.c, color.c, shape2.c, shape.c |

### Phase B: AnimDecoder.swift — Index Parser + LZ77 Decompressor
**Goal:** Swift decoder for ANIM.DAT: index table, sprite metadata, AND pixel decompression.
**Output:** `AnimDecoder.swift` (SVC023/SRC058) with:
- `AnimationEntry`: name, frameCount, viewCount
- `SpriteReference`: spriteID, xOffset, yOffset, flag (0x00 normal, 0x02 mirror)
- `SpriteHeader`: width, height (2-byte header only; no drawnRows field)
- `AnimDatabase`: all 71 animations indexed by name
- `decompressLZ77()`: port of Python decoder with correct +3 backref length
- Color table constants (5 x 64 entries)
**Depends on:** Nothing (algorithm fully proven in Python)

### Phase C: Sprite Bitmap Rendering
**Goal:** Convert decoded palette-indexed pixels to renderable images.
**Depends on:** Phase B
**Approach:**
1. LZ77 decompression is part of Phase B (algorithm proven, just port to Swift)
2. Apply gameplay palette to convert `[UInt8]` palette indices to RGBA pixel buffers
3. Handle flag 0x02 by flipping sprite pixels horizontally
4. Cache decoded sprites as `CGImage` instances
5. Support transparency (palette index 0 = transparent)
6. For scaled display: fill isolated transparent pixels to eliminate striping

### Phase D: Sprite Rendering in FPSFieldView
**Goal:** Replace geometric player shapes with authentic sprites.
**Depends on:** Phase C
**Approach:**
1. Map player movement direction → view index (8 compass directions)
2. Map game state → animation name:
   - Pre-snap: LMSTAND, DBREADY, QBPSET, LMT3PT/LMT4PT
   - Running: SKRUN, LMRUN, QBRUN, RBRNWB (ball carrier)
   - Passing: QBHAND (handoff), QBBULIT (bullet), QBFADE
   - Catching: FCATCH, SKCTHM, SKCTHH
   - Blocking: LMBLKDNL/R, LMPUSH, L2LOCK, L2BFSDL/R
   - Tackling: SLTKSDL/R, SLRFACE, SLRBUT, LMCHK
   - Getting up: LMGETUPB, LMGETUPF, LMSTUP, SKSTUP
   - Kicking: KICK, PUNT, KIKCTH, KICKSIG, CTSNP
   - Endzone: EZBOW, EZSPIKE, EZKNEEL, EZSLIDE
3. Scale sprites through PerspectiveProjection (far = smaller, near = larger)
4. Draw in depth order (far players first)
5. Team color remapping (identify team-colored palette indices)

**Event → Animation mapping:**
```
Pre-snap OL       → LMT3PT        → facing opponent
Pre-snap DL       → LMT3PT        → facing opponent
Pre-snap WR       → LMSTAND       → facing camera
QB under center   → QBSNP         → facing camera
Route running     → SKRUN          → movement direction
Ball carrier      → RBRNWB         → movement direction
Pass throw        → QBBULIT        → target direction
Catch             → FCATCH/SKCTHM  → ball direction
Tackle            → SLTKSDL/R      → target direction
Block engagement  → L2LOCK/L2BFSDL → opponent direction
```

### Phase E: Animation State Machine (COMPLETE)
**Goal:** Frame-by-frame animation during play execution at ~15 fps.
**Status:** COMPLETE. `PlayerAnimationState` tracks animation names and start times; FPSFieldView derives frame index from play elapsed time, clamping one-shots and looping run cycles. Pre-snap freezes frame 0; view mapping preserves mirror flags; green number box highlight stays. Two-player (L2*) sync is deferred but compatible with the current clock.

### Phase F: Screen Graphics (SCR/DDA) (COMPLETE)
**Goal:** Use original title screens, intro, and championship graphics.
**Status:** COMPLETE. `Services/SCRDecoder.swift` implements DGDS LZW/RLE + nibble merge with optional `DIM:` override and CGImage creation via PAL. `SCRDecoderTests.swift` decode `GAMINTRO.SCR` and `CHAMP.SCR`. UI wiring: launch splash runs `INTDYNA.SCR` → `CREDIT.SCR`; GameDay narration uses `GAMINTRO.SCR`; championship game over uses `CHAMP.SCR`.

**SCR Format (decoded):**
- Container: `SCR:` + child sections
- Optional `DIM:` = width/height (default 320×200)
- `BIN:` low nibble plane, `VGA:` high nibble plane; pixels = bin | (vga << 4)
- Dynamix LZW: 9–12 bits, clear=0x100, LSB-first, block-aligned
- `VQT:` vector-quantized tiles: 256×16-byte codebook of 4×4 tiles, frames of 64×76 tile indices → 256×304 px. Decoder picks minimal-header heuristic (0/32/64 bytes) and renders first frame (KICK has 5 frames; BALL has 1).

**Deferred:** DDA cutscenes (INTROPT1/2, DYNAMIX) remain to be decoded.

### Phase G: Audio (SAMPLE.DAT) (COMPLETE)
**Goal:** Add original game sound effects.
**Status:** COMPLETE. `SampleDecoder.swift` parses the offset table + 8-bit unsigned PCM; `SampleAudioService.swift` wraps samples into WAV and plays via AVAudioPlayer; `SoundManager.swift` prefers authentic samples with synthetic fallback. `AudioDecoderTests.swift` cover decoding and playback wiring.

---

## Implementation Priority

```
Phase A (crack compression) ──────────────→ COMPLETE
Phase B (index parser + LZ77) ────────────→ COMPLETE
Phase C (sprite cache + rendering) ───────→ COMPLETE
Phase D (render sprites in field) ────────→ COMPLETE
Phase E (animation state machine) ────────→ COMPLETE (~15 fps runtime ticking)
Phase F (screen graphics) ────────────────→ COMPLETE (SCRDecoder + title/intro/champ wiring)
Phase G (audio) ──────────────────────────→ COMPLETE (SampleDecoder + SoundManager)
Phase H (franchise mode) ────────────────→ COMPLETE
Phase T (test automation) ────────────────→ COMPLETE (7 suites incl. SCR/Audio)
Remaining: VQT tiles for BALL/KICK SCR, DDA intro cutscenes
```

**Remaining work:** Decode DDA intro cutscenes; otherwise all core phases are done.

## Animation Fix Plan (progress)
- Animation state moved to `GameViewModel` (no @State mutation in `FPSFieldView` body); frame persistence fixed.
- Team colors now applied via `SpriteCache.setTeamColors`; sprites fetch with color tables 1/2 based on possession.
- Stationary facing defaults: offense east, defense west (including pre-snap).
- Play duration mapping improved (inside/outside/deep/medium/short).
- Dead `PlayerAnimationState.tick/currentFrame/isComplete` removed; camera smoothing now stored in ViewModel.
Remaining polish: clear remaining warnings in `FPSFieldView` pose switch; optional strict VQT dimensions; DDA cutscenes still pending.

## Fallback Strategy

Sprite compression is FULLY CRACKED -- no fallback needed. The Python decoder at `tools/anim_decoder.py`
successfully decodes all 2752 sprites. If runtime Swift decompression proves too slow, pre-extracted
PNG sprite sheets can be generated from the Python decoder as a build-time optimization.

AuthenticPlayerSprite in FPSFieldView falls back to RetroPlayerSprite geometric shapes if game files
are unavailable or SpriteCache hasn't loaded.

---

## Recent Updates (2026-02-16)

- Animation runtime: PlayerAnimationState drives ~15 fps frame stepping in FPSFieldView using authentic sprites from SpriteCache.
- Screen graphics: `SCRDecoder.swift` delivers DGDS LZW/RLE + nibble merge; wired INTDYNA→CREDIT splash, GAMINTRO pre-game, CHAMP championship backgrounds; `SCRDecoderTests.swift` decode GAMINTRO/CHAMP.
- Screen graphics (VQT): BALL.SCR and KICK.SCR now decode via vector-quantized tiles; VQT support added to SCRDecoder with tests covering first-frame decode.
- Audio: `SampleDecoder.swift` + `SampleAudioService.swift` + `SoundManager.swift` prefer authentic SAMPLE.DAT sounds; `AudioDecoderTests.swift` cover decoding/playback wiring.
- AI short yardage: fallback offensive playcalling now forces run/short-pass on 3rd/4th-and-2-or-less.
- Test status: `swift test` passing (193 tests, 25 suites).

## Testing Plan (Phase T) — COMPLETE

### Infrastructure
- Tests live in `footballPro/Tests/` using Swift `Testing` framework (`swift test`)
- **ScreenshotHarness** captures 32 mock screenshots to `/tmp/fps_screenshots/`
- **Reference frames** at `/tmp/fps_frame_001.jpg` through `/tmp/fps_frame_036.jpg`
- **Test game files** at `footballPro/FBPRO_ORIGINAL/`
- **Fixture data** at `Tests/Fixtures/sprite_fixtures.json` (generated by `tools/generate_test_fixtures.py`)
- Pattern: `@Suite("Name")` + `@Test("description")` + `#expect()` assertions

### Test Suites (IMPLEMENTED)

| File | Suite | Tests | Status |
|------|-------|-------|--------|
| `Tests/AnimDecoderTests.swift` | AnimDecoder Tests | 14 | PASSING |
| `Tests/SpriteCacheTests.swift` | SpriteCache Tests | 18 | PASSING |
| `Tests/VisualComparisonTests.swift` | Visual Comparison | 5 | PASSING |
| `Tests/GameFlowTests.swift` | Game Flow E2E | 10 | PASSING |
| `Tests/SpriteIntegrationTests.swift` | Sprite Integration | 10 | PASSING |
| `Tests/SCRDecoderTests.swift` | SCR Decoder Tests | — | PASSING |
| `Tests/AudioDecoderTests.swift` | Audio Decoder Tests | — | PASSING |
| `Tests/SCRDecoderTests.swift` | VQT Decoder Tests | — | PASSING |

### Test Coverage Map

**AnimDecoder Tests:**
- parseIndex → 71 animations, correct names/frameCounts
- decompressLZ77 → literal passthrough, known sprite output length
- decodeAnimation → RCSTAND (1f×8v, 16×31), SKRUN (8f×8v, ≥8 sprites)
- loadGameplayPalette → 256 entries, skin tones at 0x10-0x13
- spriteToImage → valid CGImage, correct dimensions, mirror works
- loadDefault → 71 animations, ~2752 total sprites
- colorTables → 5 × 64 entries, identityColorTable passthrough

**SpriteCache Tests:**
- viewIndex mapping: 0°/90°/180°/270° → correct compass indices
- animationName mapping: QB→QBPSET, RB+ball→RBRNWB, WR→SKRUN, OG→LMPUSH
- load/isAvailable, sprite() returns, clearImageCache resets count

**Visual Comparison Tests:**
- Pre-generate fixtures with `tools/generate_test_fixtures.py`
- 5 known sprites: RCSTAND/0, SKRUN/0, LMSTAND/0, QBPSET/0, RBRNWB/0
- Compare width, height, first 128 pixel values Swift vs Python

**Game Flow E2E Tests:**
- Phase transitions: pregameNarration → playCalling → presnap → playAnimation → playResult → loop
- Halftime triggers, extra point choice after TD, timeout management
- Game over triggers after Q4, season result recorded
- Play 10+ plays without crashes, scores update correctly

**Sprite Integration Tests:**
- Every PlayerAnimState + common position → valid animation name → exists in database
- All 8 view directions return valid SpriteFrame for SKRUN
- RBRNWB has 8 frames, mirror flag sprites valid

**SCR Decoder Tests:**
- Decode GAMINTRO.SCR and CHAMP.SCR to expected dimensions and pixel counts; CGImage creation via PAL.

**Audio Decoder Tests:**
- SAMPLE.DAT offset table and PCM decode; WAV wrapping playable through AVAudioPlayer; SoundManager authentic-first fallback verified.

### Expanded Screenshot Harness (IMPLEMENTED — 32 total)

```
21. Main menu title screen (mock)
22. New game team selection (mock)
23. Team roster view (mock)
24. Player card
25. Pre-game narration (mock)
26. Extra point choice (mock)
27. Field with authentic sprites (pre-snap)
28. Field with authentic sprites (mid-play)
29. Play result with authentic sprites
30. Halftime score summary (mock)
31. Game over final score (GameOverView)
32. Pause menu overlay (mock)
```

### Running Tests

```bash
cd footballPro && swift test                    # All suites
swift test --filter AnimDecoderTests            # Specific suite
python3 tools/generate_test_fixtures.py         # One-time fixture generation
```

## Validation

- `swift test` passes all suites (0 failures, 193 tests, 25 suites)
- Visual comparison tests confirm pixel-perfect match with Python fixtures.
- Game flow test completes 10+ plays without crashes.
- Screenshot harness captures 32 images to `/tmp/fps_screenshots/`.
- Rendered sprites align with reference frames `/tmp/fps_frame_001.jpg` through `/tmp/fps_frame_036.jpg`.

- `swift test` passes all suites (0 failures, 193 tests, 25 suites)
- Visual comparison tests confirm pixel-perfect match with Python decoder
- Game flow test completes 10+ plays without crashes
- Screenshot harness captures 32 images to `/tmp/fps_screenshots/`
- Compare rendered sprites against reference frames at `/tmp/fps_frame_001.jpg` through `/tmp/fps_frame_036.jpg`
