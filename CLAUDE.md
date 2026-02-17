# CLAUDE.md — Football Pro Project Instructions

## Project Overview
macOS SwiftUI recreation of **Front Page Sports: Football Pro** (1993, Dynamix/Sierra).
Reuse as much of the original game as possible: sprites, animations, screens, audio.
- **Target:** macOS 14+, Swift 5.9, MVVM architecture
- **Source root:** `footballPro/footballPro/footballPro/` (App/, Engine/, Models/, Views/, Views/Franchise/, ViewModels/, Styles/, Services/, Input/, Resources/)
- **Build:** `open footballPro/footballPro.xcodeproj` then Cmd+R
- **Original game files:** `~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO/`
- **Reference frames:** `/tmp/fps_frame_001.jpg` through `/tmp/fps_frame_036.jpg`

## Automation
- `tools/test_agent.sh` — Background Swift test runner; writes to `/tmp/footballpro_test_agent.log`. Launch with `nohup tools/test_agent.sh &`. Exports `DISABLE_AUDIO=1` to avoid CoreAudio failures.
- `tools/agent_full_stack.sh` — Runs swift tests, captures all reference screens via `ScreenshotHarnessTests`, stitches `/tmp/fps_screenshots/*.png` into MP4 if `ffmpeg` available.
- DDA helpers: `tools/dda_bruteforce.py`, `tools/dda_inspect_agent.py`, `tools/dda_rank_agent.py`, `tools/dda_sweep_agent.sh`, `tools/dda_extended_sweep_agent.sh`, `tools/dda_marker_burst_agent.sh`, `tools/dda_monitor_agent.sh`, `tools/dda_review_agent.sh`, `tools/agent_dda_finish.sh`.
- Coverage agents: `tools/agent_anim_parity.sh`, `tools/agent_playbook_coverage.sh`, `tools/agent_audio_check.sh`, `tools/agent_audio_map.sh`, `tools/agent_anim_capture.sh`.
- Audio auto-disabled in tests/CI via `SoundManager` (checks `DISABLE_AUDIO`, `CI`, XCTest bundle).
- Latest tests: `swift test --disable-sandbox --parallel` passing (193 tests, 25 suites).
- Field animation uses periodic 30fps `TimelineView`. Optional frame logger: `FPS_FRAME_LOG=/tmp/fps_frame_log.jsonl`.

## Architecture & Key Files

| File | Purpose |
|------|---------|
| `Views/GameDayView.swift` | ZStack state machine — `GamePhase` enum drives which screen shows |
| `Views/FPSFieldView.swift` | Full-screen perspective field (640x360 blueprint space, PerspectiveProjection) |
| `Views/FPSPlayCallingScreen.swift` | 2×8 green grid (slots 1-8 left, 9-16 right), 3-button bar, scoreboard |
| `Views/FPSScoreboardBar.swift` | Two-row layout (away top, home bottom), QTR grid, amber LED clock, situation block |
| `Views/FPSPlayResultOverlay.swift` | Dark charcoal result box on field, team names in cyan/red |
| `Views/FPSRefereeOverlay.swift` | Referee signal overlay on field |
| `Views/FPSReplayControls.swift` | VCR-style replay transport buttons |
| `Engine/PlayBlueprintGenerator.swift` | Generates animation paths for all 22 players in 640x360 flat space; uses authentic STOCK.DAT routes when available |
| `Views/Components/AuthenticSplashScreen.swift` | INTDYNA.SCR + CREDIT.SCR splash sequence on app launch |
| `Engine/SimulationEngine.swift` | Core play-by-play simulation |
| `Engine/PlayerAnimationState.swift` | Per-player animation state machine (~15fps sprite cycling) |
| `Styles/RetroStyle.swift` | VGA color palette (`VGA` struct) and `RetroFont` presets |
| `ViewModels/GameViewModel.swift` | Game state MVVM binding, GamePhase enum state machine |
| `App/FootballProApp.swift` | App entry, GameScreen enum, GameState, ManagementHubView |
| `Views/Franchise/StandingsView.swift` | Division/conference standings (W-L-T, PCT, PF, PA) |
| `Views/Franchise/StatsView.swift` | Tabbed stat leaders + 1992 historical stats toggle |
| `Views/Franchise/DraftRoomView.swift` | Draft room with prospect grid, scouting, auto-pick |
| `Views/Franchise/PlayoffBracketView.swift` | 8-team bracket (4 per conference, seeded 1-4) |
| `Views/Franchise/TradeProposalView.swift` | Trade builder with fairness evaluation |
| `Views/Franchise/FreeAgencyView.swift` | Free agent market sorted by rating |
| `Views/Franchise/DepthChartView.swift` | Position group depth chart editor |
| `Views/Franchise/SaveLoadView.swift` | 8-slot UserDefaults save/load system |
| `Views/Franchise/SettingsView.swift` | FranchiseSettingsView (difficulty, audio, speed) |

## Visual Style Rules (FPS '93 Authenticity)

**Always use the VGA color palette from RetroStyle.swift:**
- `VGA.panelBg` = #A0A0A0 (medium gray, DOS panel background)
- `VGA.buttonBg` = #BB2222 (true red buttons)
- `VGA.playSlotGreen` = #269426 (bright green play slots)
- `VGA.screenBg` = black
- `VGA.digitalAmber` = #FFA600 (LED clocks)
- `VGA.teamCyan` = #55BBFF (possessing team name highlight)
- `VGA.teamRed` = #DD3333 (opposing team name highlight)

**Always use RetroFont presets** — never system fonts in game UI:
- tiny(9), small(10), body(12), bodyBold(12), header(14), title(18), large(24), huge(36), score(48)

**Always use FPS component library:** FPSButton, FPSDialog, FPSDigitalClock

**Field rendering rules:**
- Solid green field (#248024), no grass stripes, no stadium backdrop during gameplay
- Single perspective camera, ~25 yard visible window (8 behind LOS + 17 ahead)
- No sideline figures, officials, chain gang, or coaches (clean like original)
- AuthenticPlayerSprite renders original ANIM.DAT sprites (falls back to RetroPlayerSprite if files missing)
- Green number box overlay on ball carrier (matching original FPS '93 style)
- Team color remapping via SpriteCache.setTeamColors() (CT1=home, CT2=away palette overrides)
- Amber LED clocks at bottom corners only (play clock wired to viewModel.playClockSeconds)

## Important Patterns & Rules

- `isFieldFlipped = !viewModel.isUserPossession` — flips field when user is on defense
- `switchPossession()` already calls `fieldPosition.flip()` — **never double-flip**
- Sack yards count as rushingYards (NFL rules), penalty yards go to separate counters
- GameClock has `displayTime` (String "M:SS") for display
- PlayBlueprintGenerator generates in 640x360 flat space — PerspectiveProjection handles screen mapping
- **New Swift files must be manually added to Xcode .pbxproj** (use the Python script or Xcode)

**Simulation tuning (calibrated to NFL averages):**
- XP success: `0.94 + (accuracy - 70) * 0.002` (~94% for average kicker)
- FG modifier: `0.85 + (kickPower + kickAccuracy) / 1000.0` (~0.99 for average kicker)
- Rushing yards: right-skewed distribution (40% stuffed, 35% moderate, 15% good, 7% big, 3% breakaway)
- Receiver targeting: weighted by overall rating (star WRs get more targets)
- Kick return TD: 0.3% (NFL average)
- AI play calling: tracks last 5 calls, reduces repeat weight by 50%
- AI timeouts: wired into post-play loop for defensive team
- AI short yardage: forces run/short-pass on 3rd/4th-and-2-or-less
- Player ratings wired: breakTackle/trucking (extra rush yards), catchInTraffic/spectacularCatch (completion%), hitPower (fumble forcing), playRecognition (run defense), playAction (PA bonus), press/release (route matchup)
- Clock management: out-of-bounds stops (25% outside runs, 5% inside), two-minute warning Q2/Q4, kneel-down and spike plays with AI logic
- Field visuals: sideline gray/track borders, stadium backdrop near end zones, authentic RCSTAND referee sprite

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
| SCRDecoder.swift | *.SCR | DGDS LZW/RLE + VQT quadtree, nibble merge, CGImage via PAL. 320x200/640x350. |
| SampleDecoder.swift | SAMPLE.DAT | Offset table + 8-bit unsigned PCM. ~115 samples. |
| SampleAudioService.swift | (runtime) | WAV wrapping + AVAudioPlayer playback for decoded samples. |
| StockDATDecoder.swift | STOCK.DAT/MAP | 1002 play/formation records. 25B header + 11 variable-length player entries with routes, motion, assignments. |
| SeasonStatsDecoder.swift | 1992.DAT/IDX/PYR/XGE | 3442 × 20B stat records (rushing, passing, receiving, defense, kicking). B-tree index. Real 1992 NFL stats. |

### Remaining Undecoded Files

| File | Size | Status | Content |
|------|------|--------|---------|
| `*.DDA` | 34-429KB | Partially decoded | Dynamix Delta Animation cutscenes (frame table known, RLE encoding pending) |

### DDA Decoding Status
- `Services/DDAAnimationDecoder.swift` supports multi-frame heuristics: offset tables, length-prefixed frames, first-frame fallback
- RLE grammars: nibble-control (ctrl mask 0x80/0xC0) and marker RLE (0xFE/0xC9)
- Best hits: LOGOSPIN via nibble_ctrl grammars. LOGOEND/DYNAMIX/CHAMP still unresolved
- Reviewable PNGs in `/tmp/dda_review`; shortlist `/tmp/dda_top_candidates.txt`
- Tools: `tools/dda_bruteforce.py`, `tools/dda_marker_burst_agent.sh`, `tools/dda_monitor_agent.sh`

All other game data formats are fully decoded: ANIM.DAT (sprites), SCR (screens + VQT tiles), SAMPLE.DAT (audio), PAL (palettes), LGE/PYR (teams/players), PRF/PLN (playbooks), STOCK.DAT/MAP (play routes), 1992.DAT (season stats), and 10+ supporting data files.

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
| *.SCR | 3-29KB | **DECODED** (SCRDecoder) BIN:/VGA: LZW + VQT: quadtree | Full-screen VGA graphics (title, intro, championship, ball, kick) |
| *.DDA | 34-429KB | Partially decoded | Dynamix Delta Animation cutscenes (frame table + RLE encoding) |
| SAMPLE.DAT | 855KB | **DECODED** (SampleDecoder + SampleAudioService) | ~115 audio samples (crowd, whistle, hits) |

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
**Status:** COMPLETE. `PlayerAnimationState` tracks animation names and start times in `GameViewModel` (not @State). FPSFieldView derives frame index from play elapsed time, clamping one-shots and looping run cycles. Pre-snap freezes frame 0; view mapping preserves mirror flags; green number box highlight stays. Two-player (L2*) sync deferred.

### Phase F: Screen Graphics (SCR/DDA) — COMPLETE
**Goal:** Use original title screens, intro, and championship graphics.
**Status:** COMPLETE. All decodable SCR screens wired into SwiftUI views.
**Files:**
- `Services/SCRDecoder.swift`: DGDS LZW/RLE decoder, nibble merge, CGImage via PAL
- `Tests/SCRDecoderTests.swift`: Decodes GAMINTRO.SCR and CHAMP.SCR

**SCR Format (decoded):**
- Container: `SCR:` (8B) + child sections
- Optional `DIM:` (8B + 4B data) = uint16 LE width + uint16 LE height (default 320x200)
- `BIN:` section: type(1B=0x02) + uncomp_size(4B LE) + Dynamix LZW data → low nibbles
- `VGA:` section: same format → high nibbles
- Pixels are 4-bit nibble-packed (2 per byte). Final pixel = bin_nibble | (vga_nibble << 4)
- VQT: sections use recursive quadtree decomposition with adaptive color tables (DECODED)
- Dynamix LZW: 9-bit initial, max 12-bit, clear=0x100, no end code, LSB-first, block-aligned

**Decoded screens:**
- GAMINTRO.SCR (320x200): Pre-game helmet matchup screen
- CHAMP.SCR (320x200): Championship trophy
- INTDYNA.SCR (320x200): Dynamix logo splash
- CREDIT.SCR (640x350): "Front Page Sports" title/credits

**Wired screens:**
- `AuthenticSplashScreen.swift`: INTDYNA.SCR → CREDIT.SCR splash sequence on app launch
- `GameDayView.swift`: GAMINTRO.SCR as pre-game narration background
- `GameDayView.swift`: CHAMP.SCR as championship game-over background

**VQT format (DECODED):**
- Vector-quantized tiles: 256×16-byte codebook of 4×4 tiles, frames of 64×76 tile indices → 256×304 px
- Decoder picks minimal-header heuristic (0/32/64 bytes), renders first frame
- BALL.SCR (football) and KICK.SCR (kicking scene) both decode perfectly

**Deferred (low priority):**
- DDA animated intro sequences (INTROPT1.DDA, INTROPT2.DDA, DYNAMIX.DDA) — frame table decoded, RLE in progress
- Best DDA hits: LOGOSPIN via nibble_ctrl grammars. LOGOEND/DYNAMIX/CHAMP still unresolved.

### Phase G: Audio (SAMPLE.DAT) — COMPLETE
**Goal:** Add original game sound effects.
**Status:** COMPLETE. Decoder + playback + SoundManager all wired.
**Files:**
- `Services/SampleDecoder.swift`: SAMPLE.DAT decoder (offset table + 8-bit unsigned PCM)
- `Services/SampleAudioService.swift`: WAV wrapping + AVAudioPlayer playback
- `Services/SoundManager.swift`: Prefers authentic samples, falls back to synthetic tones
- `Tests/AudioDecoderTests.swift`: Decoder + playback tests passing

### Phase H: Franchise Mode — COMPLETE
**Goal:** Full franchise management UI (9 screens).
**Status:** COMPLETE. All views wired into ManagementHubView navigation.
**Files:**
- `Views/Franchise/StandingsView.swift`: Division/conference standings
- `Views/Franchise/StatsView.swift`: Tabbed stat leaders
- `Views/Franchise/DraftRoomView.swift`: Draft room with scouting + auto-pick
- `Views/Franchise/PlayoffBracketView.swift`: 8-team seeded bracket
- `Views/Franchise/TradeProposalView.swift`: Trade builder with AI evaluation
- `Views/Franchise/FreeAgencyView.swift`: Free agent market
- `Views/Franchise/DepthChartView.swift`: Position group depth chart editor
- `Views/Franchise/SaveLoadView.swift`: 8-slot UserDefaults save/load
- `Views/Franchise/SettingsView.swift`: FranchiseSettingsView (difficulty, audio, speed)
**Navigation:** `ManagementHubView` in `FootballProApp.swift` uses `ManagementScreen` enum (hub, freeAgency, trade, draft, standings, stats, depthChart, saveLoad, settings)

### Gameplay Polish — COMPLETE
- **Celebrations:** Random end zone animations (EZBOW, EZSPIKE, EZKNEEL, EZSLIDE)
- **Play clock:** 25-second countdown displayed on scoreboard
- **Team colors:** Palette override system via SpriteCache.setTeamColors() (CT1=home, CT2=away)
- **Replay:** GamePhase.replay with FPSReplayControls VCR transport, auto-trigger on big plays
- **Player progression:** Age-based rating changes, retirement logic (age >36 or age >34 + low rating)

### Bug Fixes (Feb 2026)
- **Play animation race condition fixed** — runPlay() and executeKickoff() now set `currentPhase = .playAnimation` BEFORE setting `currentAnimationBlueprint`, with a 50ms yield between. Previously the blueprint was set first and the phase changed second, causing the new FPSFieldView's `.onChange` handler to miss the blueprint (already set before the view mounted). Plays now animate for their full 4.5-6s duration instead of skipping to the result.

---

## Implementation Priority

```
Phase A (crack compression) ──────────────→ COMPLETE
Phase B (index parser + LZ77) ────────────→ COMPLETE (AnimDecoder.swift)
Phase C (sprite cache + rendering) ───────→ COMPLETE (SpriteCache.swift)
Phase D (render sprites in field) ────────→ COMPLETE (FPSFieldView wired)
Phase E (animation state machine) ────────→ COMPLETE (PlayerAnimationState.swift + 15fps cycling)
Phase F (screen graphics) ────────────────→ COMPLETE (SCRDecoder + splash/intro/champ screens)
Phase G (audio) ──────────────────────────→ COMPLETE (SampleDecoder + SoundManager)
Phase H (franchise mode) ────────────────→ COMPLETE (9 franchise views + ManagementHubView)
Phase T (test automation) ────────────────→ COMPLETE (193 tests, 25 suites)
Gameplay polish ──────────────────────────→ COMPLETE (celebrations, play clock, team colors, replay, progression)
Animation fixes ─────────────────────────→ COMPLETE (state in ViewModel, team colors, facing, durations)
```

**All core phases complete.** Remaining work: DDA intro cutscenes; visual accuracy refinement (see below).

## Testing

- 211 tests, 26 suites: `swift test --disable-sandbox --parallel`
- ScreenshotHarness captures 32 screenshots to `/tmp/fps_screenshots/`
- Reference frames at `/tmp/fps_frame_001.jpg` through `/tmp/fps_frame_036.jpg`
- Test game files at `footballPro/FBPRO_ORIGINAL/`

---

## Recently Implemented Features

### Gameplay Core (Feb 2026)
- **Route-based simulation** — PlayResolver uses STOCK.DAT routes for OL/DL trench matchups, receiver separation, QB read progression under pressure. Falls back to rating-based resolution without game files.
- **STOCK.DAT-driven animations** — PlayBlueprintGenerator uses actual assignments (block, route, rush, coverage, zone) to drive distinct player paths. Pre-snap motion support. Ball arc targets actual designed receiver.
- **On-field player control** — WASD movement during plays. QB: move in pocket, Space for passing mode, 1-5 to throw to receivers. Ball carrier: WASD run, X stiff arm. Defense: WASD move, Space tackle, Tab switch player. `PlayerControlState` in Input/.
- **Kickoff animation** — Kickoffs show on-field with 22-player coverage/return animation (5.5s). Post-score kickoffs also animated.
- **Coin toss** — 5-phase DOS-style UI (call → flip → result → choose kick/receive → summary). `CoinTossView.swift`.
- **Exhibition mode** — Main menu: Quick Start (BUF vs DAL), Exhibition (team picker), League Play. `ExhibitionSetupView.swift`, `ExhibitionGameDayView` in FootballProApp.
- **Kicking controls** — Angle bar (vertical, 25-65°) + aim bar (horizontal) with oscillating cursors. Accuracy affects FG/punt/kick outcomes. `FPSKickingView.swift`.
- **Weather system** — Temperature, wind, humidity, rain/snow generated from city weather zones. Affects completion% (-10/-15%), fumbles (+25/35%), kick distance, injuries, speed. `WeatherSystem.swift`.
- **Audibles** — Arrow keys change play at line of scrimmage during pre-snap. Auto-picks plays by type. "AUDIBLE!" amber flash. `FPSEditAudiblesPanel.swift`.
- **Substitution window** — DOS-style panel with POS/NO/NAME/OVR/ENERGY bars. Tap to see/swap backups. `FPSSubstitutionPanel.swift`.
- **Player/team editing** — Rating bars (0-99) with +/- controls, edit locking after season starts. Team editor for name/stadium/colors. `PlayerEditorView.swift`.
- **Pass routes fixed** — Routes reference `losX` not `start.x`. Receivers go downfield properly.
- **RB depth fixed** — Sqrt compression + 45px clamp. RB at ~7 yards back (was 17).
- **DOS-style franchise views** — Replaced rounded corners, native pickers, sheet modals with DOSPanelBorder overlays across all 9 franchise views.

### Authenticity Features (Feb 2026)
- **Play diagrams** — Green slots show miniature Xs-and-Os route diagrams from STOCK.DAT. Primary receiver route in amber. `PlayDiagramView.swift` + `MiniDiagramCache`.
- **Coaching Profiles** — 2,520 situational AI decisions (6 time × 4 down × 5 distance × 7 field zone × 3 score diff). 4 default profiles (OFF1/OFF2 conservative/aggressive, DEF1/DEF2). `CoachingProfile.swift`.
- **Camera angles** — 7 camera views: Behind Offense/Defense, Side Right/Left, Overhead, Behind Home/Visiting. C/O keys cycle. +/- zoom (0.5x-2.0x). `CameraAngle` enum + `PerspectiveProjection` extensions.
- **Game Settings (F1)** — 4-tab overlay: View, Field Detail (hash marks/numbers/end zones), Audio (SFX/crowd/whistle), Field Conditions. `FPSGameSettingsView.swift`.

### New Files Added This Session
| File | Purpose |
|------|---------|
| `Views/Game/CoinTossView.swift` | 5-phase coin toss before kickoff |
| `Views/Game/FPSKickingView.swift` | Angle bar + aim bar kicking controls |
| `Views/Game/FPSEditAudiblesPanel.swift` | Audible assignment editor overlay |
| `Views/Game/FPSSubstitutionPanel.swift` | In-game substitution overlay |
| `Views/Game/FPSGameSettingsView.swift` | F1 in-game settings (view/field/audio/conditions) |
| `Views/Game/PlayDiagramView.swift` | Mini Xs-and-Os route diagrams in play slots |
| `Views/Franchise/PlayerEditorView.swift` | Player rating + team data editor |
| `Views/MainMenu/ExhibitionSetupView.swift` | Exhibition team picker |
| `Models/WeatherSystem.swift` | Weather model + gameplay modifiers |
| `Models/CoachingProfile.swift` | 2,520-situation AI coaching profiles |
| `Input/PlayerControlState.swift` | On-field player control state machine |
| `Views/Franchise/TrainingCampView.swift` | Off-season training camp (8 groups × 8 ratings) |
| `Engine/FastSimEngine.swift` | Quick game resolution from team ratings |

### League & Roster Features (Feb 2026)
- **Training Camp** — 8 position groups × 8 ratings, 100 points per group, age-based improvement toward potential. Auto-allocate option. `TrainingCampView.swift`.
- **Fast Sim** — `FastSimEngine.fastSimGame()` generates realistic scores, quarter-by-quarter, box score stats from team rating averages. Used for CPU-vs-CPU weeks.
- **Career vs Single-season** — `LeagueType` enum on League. Single-season hides draft/trade/free agency in management hub. Career mode unchanged.
- **47-slot roster** — 34 assigned (QB2/RB2/FB1/WR3/TE2/OL5/DL4/LB5/DB7/K1/P1) + 11 open + 2 IR. `RosterSlot`/`SlotType` on Team. DepthChartView shows slot counts and IR management.
- **Catch zone** — Orange circle with X at pass target during ball flight. `CatchZoneIndicator` in FPSFieldView.

## Known Issues & Gaps (vs Original Game)

### High Priority (Visual Accuracy)
- **Play calling button bar layout** — Original has only TIME OUT + READY-BREAK! centered wide. Ours has 5 buttons (TIME OUT, SUBS, AUDIBLES, spacer, READY-BREAK). Move SUBS/AUDIBLES to separate access (e.g., keyboard shortcuts or within opponent grid area)
- **Opponent play grid shows nothing** — Original shows opponent's play choices in their bottom grid (e.g., "Squib kick / Onside kick / Kickoff" in rows 3-4). Our bottom half is blank green with only a text notification overlay
- **Field yard line numbers** — Original has large white "10 20 30 40 50" painted on the field. Our field has hash marks but yard numbers not visible
- **Referee popup window** — Original shows referee in a popup window inset on the field with "First down, Buffalo" text below. Our referee overlay may not match this exact bordered-window style
- **Main menu structure** — Original: QuickStart, Exhibition Play, League Play, Play Editor, Change QuickStart, Restart Saved Game. Ours: NEW GAME, LOAD GAME, SETTINGS, QUIT

### Medium Priority (Polish)
- **Scoreboard contrast** — Original scoreboard has very dark (near-black) background with high-contrast amber/red text. Ours could be darker
- **Player sprite perspective scaling** — Original shows noticeably smaller sprites for far-field players. Our sprites may not scale enough with distance
- **Field sideline detail** — Original shows stadium/sideline borders with crowd elements. Our field has gray sideline but minimal detail
- **Game over screen** — Our final score is a bare gray panel. Should show CHAMP.SCR trophy background for championship games
- **Play diagram readability** — Mini X-O diagrams in green slots are quite small/hard to read compared to original

### Remaining Features
- **Play Editor** — Full play design tool with logic scripting
- **Practice mode** — Practice Field accessible from Play Editor
- **Free-floating camera** — Mouse-controlled camera during play
- **Roster drag-and-drop** — Original lets you drag players between slots

### Low Priority
- **Supplemental Draft** — Additional rounds after College Draft
- **Game Plans** — 64 plays each loaded before game (partially implemented via playbooks)
- **Team passwords** — Password protection for human-owned teams
- **Computer Manager** — Toggle AI management of roster moves
- OL sprites appear slightly lighter due to pixel value distribution in LMT3PT views

## Reference Materials
- **Game manual PDF**: `/tmp/fps_manual.pdf` (downloaded from oldgamesdownload.com)
- **Detailed feature reference**: `memory/original-game-features.md`
- **Wiki**: https://dynamix.fandom.com/wiki/Front_Page_Sports:_Football_Pro
