# CLAUDE.md — Football Pro Project Instructions

## Project Overview
macOS SwiftUI recreation of **Front Page Sports: Football Pro** (1993, Dynamix/Sierra).
Reuse as much of the original game as possible: sprites, animations, screens, audio.
- **Target:** macOS 14+, Swift 5.9, MVVM architecture
- **Source root:** `footballPro/footballPro/footballPro/` (App/, Engine/, Models/, Views/, ViewModels/, Styles/, Services/, Input/, Resources/)
- **Build:** `open footballPro/footballPro.xcodeproj` then Cmd+R
- **Original game files:** `~/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO/`
- **Reference frames:** `/tmp/fps_frame_001.jpg` through `/tmp/fps_frame_036.jpg`

## Architecture & Key Files

| File | Purpose |
|------|---------|
| `Views/GameDayView.swift` | ZStack state machine — `GamePhase` enum drives which screen shows |
| `Views/FPSFieldView.swift` | Full-screen perspective field (640x360 blueprint space, PerspectiveProjection) |
| `Views/FPSPlayCallingScreen.swift` | 16-slot green grid (1-8 left, 9-16 right), scoreboard bar, red buttons |
| `Views/FPSScoreboardBar.swift` | Team names+ratings, QTR grid, amber LED clock, DOWN/TO GO/BALL ON |
| `Views/FPSPlayResultOverlay.swift` | Dark charcoal result box on field, team names in cyan/red |
| `Views/FPSRefereeOverlay.swift` | Referee signal overlay on field |
| `Views/FPSReplayControls.swift` | VCR-style replay transport buttons |
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
- Current: RetroPlayerSprite geometric shapes (TEMPORARY — to be replaced by original sprites)
- Green number box overlay on ball carrier (matching original FPS '93 style)
- Amber LED clocks at bottom corners only

## Important Patterns & Rules

- `isFieldFlipped = !viewModel.isUserPossession` — flips field when user is on defense
- `switchPossession()` already calls `fieldPosition.flip()` — **never double-flip**
- Sack yards count as rushingYards (NFL rules), penalty yards go to separate counters
- GameClock has `displayTime` (String "M:SS") for display
- PlayBlueprintGenerator generates in 640x360 flat space — PerspectiveProjection handles screen mapping
- **New Swift files must be manually added to Xcode .pbxproj** (use the Python script or Xcode)

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
| `ANIM.DAT` | 985KB | LZ77 decompression verified, rendering pipeline TBD | 71 animations, 8-direction views |
| `*.SCR` | 3-29KB | Header known: `SCR:` + `BIN:` compressed | Full-screen VGA graphics |
| `*.DDA` | 34-429KB | Unexamined | Dynamix Delta Animation cutscenes |
| `SAMPLE.DAT` | 855KB | Partially decoded: 8-bit unsigned PCM | ~115 audio samples |
| `STOCK.DAT` | — | Unexamined | Stock team/player data |
| `1992.DAT/.IDX` | — | Unexamined | Season/roster data with index |

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
  - 2751 sprites across 71 animations, all decode successfully

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
| *.SCR | 3-29KB | Header: `SCR:` + `BIN:` compressed bitmap | Full-screen VGA graphics (title, intro, championship) |
| *.DDA | 34-429KB | Unexamined | Dynamix Delta Animation scripts (cutscenes) |
| SAMPLE.DAT | 855KB | Partially decoded: offset table + 8-bit unsigned PCM | ~115 audio samples (crowd, whistle, hits) |

---

## Implementation Phases

### Phase A: Crack the Sprite Compression (Research — IN PROGRESS)
**Goal:** Decode the sprite pixel compression so we can render actual bitmaps.
**Status:** LZ77 decompression VERIFIED via EXE disassembly. Shapes recognizable, horizontal striping from rendering pipeline TBD.
**Python decoder:** `tools/anim_decoder.py`

**LZ77/LZSS compression (verified from A.EXE at 0x40A5D):**
- Sprite header: 2 bytes (width, height)
- LZ77 stream: uint16 LE (groups_m1) + uint8 (tail_bits)
- Per group: 1 flag byte, 8 decisions MSB first
- Decision bit=0: LITERAL — 1 byte, remapped through 64-entry color table
- Decision bit=1: BACK-REF — uint16 LE, high 12 = distance, low 4+3 = copy length (3-18)
- Copy from output[current_pos - distance - 1]
- Output bounded to width × height bytes
- All 71 animations / ~2751 sprites decompress within data boundaries

**Color tables (5 × 64 bytes at A.EXE offset 0x4091D):**
- CT0: outline only (maps 46→0x2E, 47→0x2F, all else→0)
- CT1-4: team color variants (skin, jersey A/B, equipment, highlights)
- CT1-4 map indices 46-47 to 0 (transparent) — causes outline pixels to vanish
- Game likely uses two-pass or no-CT rendering to preserve outlines

**Remaining issue:** Horizontal striping from transparent pixels in outline rows.
Need to examine the adraw renderer (0x08845) and Mode X VGA output (0x2B254) to understand the full rendering pipeline.

**EXE key offsets:**
| Offset | Content |
|--------|---------|
| 0x40A5D | LZ77 decompressor WITH color table |
| 0x40B49 | LZ77 decompressor WITHOUT color table |
| 0x4091D | 5 × 64-byte color tables |
| 0x08845 | adraw function (sprite draw entry point) |
| 0x2B254 | Mode X VGA renderer |
| 0x046630 | Source filenames (anim.c, adraw.c, draw.c, shape.c, color.c) |

### Phase B: AnimDecoder.swift — Index Parser
**Goal:** Swift decoder for ANIM.DAT index table + sprite metadata (not pixel data yet).
**Output:** `AnimDecoder.swift` (SVC023/SRC058) with:
- `AnimationEntry`: name, frameCount, viewCount
- `SpriteReference`: spriteID, xOffset, yOffset
- `SpriteHeader`: width, height, drawnRows
- `AnimDatabase`: all 71 animations indexed by name
**Depends on:** Nothing (index format is fully decoded)

### Phase C: Sprite Bitmap Decoder
**Goal:** Implement pixel decompression in Swift.
**Depends on:** Phase A + Phase B
**Approach:**
1. Port Python decompressor to Swift
2. Decode sprite pixels into `[UInt8]` arrays (VGA palette indices)
3. Apply PAL palette to convert to RGBA pixel buffers
4. Cache decoded sprites as `CGImage` instances
5. Support transparency (palette index 0 = transparent)

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

### Phase E: Animation State Machine
**Goal:** Frame-by-frame animation during play execution.
**Depends on:** Phase D
**Approach:**
1. `AnimationState` per player: currentAnimation, currentFrame, currentView
2. Animation tick system (~15 fps to match original game feel)
3. Instant animation switches on events (matching original — no interpolation)
4. Two-player animations (L2*): sync paired players to same clock
5. Ball carrier highlight: green number box overlay (already implemented)

### Phase F: Screen Graphics (SCR/DDA)
**Goal:** Use original title screens, intro, and championship graphics.
**Depends on:** Partially on Phase A (BIN: compression may be shared)
**Approach:**
1. Decode BIN: compressed bitmaps in SCR files (320×200 VGA)
2. Apply PAL palette for correct colors
3. Replace SwiftUI title/intro screens with original VGA art
4. Decode DDA for animated intro sequences (INTROPT1.DDA = 429KB, INTROPT2.DDA = 135KB)

### Phase G: Audio (SAMPLE.DAT)
**Goal:** Add original game sound effects.
**Depends on:** Nothing (independent track)
**Approach:**
1. Decode SAMPLE.DAT offset table (1B count + N×4B LE offsets + 8-bit unsigned PCM)
2. Extract samples, identify by listening: crowd, whistle, hits
3. Wire into game events via AVAudioPlayer
4. ~115 samples, 855KB total, likely 11025 Hz mono 8-bit

---

## Implementation Priority

```
Phase B (index parser)  ──────────────────→ Can build immediately
Phase A (crack compression) ──────────────→ LZ77 verified, rendering pipeline TBD
Phase C (sprite bitmap decoder) ──────────→ Blocked on A (rendering pipeline)
Phase D (render sprites) ─────────────────→ Blocked on C (but algorithm proven)
Phase E (animation state machine) ────────→ Blocked on D
Phase F (screen graphics) ────────────────→ LZ77 shared with sprites, partially unblocked
Phase G (audio) ──────────────────────────→ Independent, can start anytime
```

**Critical path:** A (finish) → C → D → E
**Parallel:** Phase B + Phase G can start immediately

## Fallback Strategy

If sprite compression proves too difficult to crack statically:
1. **DOSBox extraction:** Run game in DOSBox, set breakpoints on decompression routine, dump decoded sprites from memory
2. **DOSBox screenshot capture:** Run each animation in-game, capture frames, slice into sprite sheets
3. **Hybrid approach:** Pre-extracted PNG sprite sheets (~5MB) instead of runtime decompression (~963KB)

## Validation

- Compare rendered sprites against reference frames at `/tmp/fps_frame_001.jpg` through `/tmp/fps_frame_036.jpg`
- Match sprite scale, position, and color to original game screenshots
- Verify 8-direction view mapping matches original camera perspective
- Test with PAL palette from NFLPA93.PAL (already decoded)
