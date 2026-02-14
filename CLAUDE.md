# CLAUDE.md — Football Pro Project Instructions

## Project Overview
macOS SwiftUI recreation of **Front Page Sports: Football Pro** (1993, Dynamix/Sierra).
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
- RetroPlayerSprite: Home=blue jersey/dark helmet/red pants, Away=white jersey/silver helmet/gray pants
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

### Playbook Files (PRF/PLN — already decoded)
| File | Description |
|------|-------------|
| `OFF.PLN` | Offensive playbook index (76 plays, 22 formations) |
| `OFF1.PRF` | Offensive play routes, bank 1 |
| `OFF2.PRF` | Offensive play routes, bank 2 |
| `DEF.PLN` | Defensive playbook index |
| `DEF1.PRF` | Defensive play routes, bank 1 |
| `DEF2.PRF` | Defensive play routes, bank 2 |

Working Python decoder: `footballPro/decode_prf.py` (319 lines)
- **PRF format:** 40B header + 7 plays x 20x18 grid x 6B cells + footer. 5-phase route system.
- **PLN format:** 12B header + 86-slot offset table + 18B entries (formation, name, PRF ref) + footer

### Other Game Data Files
| File | Description |
|------|-------------|
| `1992.DAT` / `1992.IDX` | Season/roster data with index |
| `STOCK.DAT` / `STPL.DAT` | Stock team/player data |
| `ANIM.DAT` | Player animation data |
| `CITIES.DAT` | City/team location data |
| `NAMEF.DAT` / `NAMEL.DAT` | First/last name databases |
| `INJURY.DAT` | Injury types and durations |
| `CALENDER.DAT` | Season schedule template |
| `MAGAZINE.DAT` | In-game magazine/news text |
| `MSG.DAT` | Game message strings |
| `SAMPLE.DAT` | Audio sample data |
| `HELP1-3.DAT` / `HELPLK1-3.DAT` | Help system text and links |
| `*.LGE` / `*.PYF` / `*.PYR` | League configs (8/10/12/18 team variants) |
| `*.SCR` / `*.PAL` / `*.DDA` | Screen graphics, palettes, animation scripts |

These files are binary — formats are not yet fully decoded except PRF/PLN. Exploring them could unlock authentic rosters, schedules, animations, and more.

## Next Project Steps (Priority Order)

### Phase 1 — Swift PRF/PLN Decoder
- Port `decode_prf.py` to Swift as `PRFDecoder.swift`
- Read original .PRF files and extract 5-phase route data
- Read .PLN files to get play names, formations, PRF references
- Feed authentic routes into PlayBlueprintGenerator

### Phase 2 — Authentic Playbook Integration
- Replace hardcoded 18-play playbook with 76+ plays from OFFPA1.PLN
- Map formation codes to visual formations
- Add defensive playbook from DEFPA1.PLN

### Phase 3 — Git & Build Hygiene
- Initialize git repository
- Fix resource warnings (TeamData.json, PlaybookData.json)
- Clean up scattered markdown docs (consolidate into this file)

### Phase 4 — Gameplay Polish
- Penalty flag animations
- Weather visual effects
- Instant replay (rewind animation frames)
- Timeout management UI
- 2-point conversion option

### Phase 5 — Franchise Mode
- Multi-season play with player progression/aging
- Expanded playoffs (6-7 team format)
- Historical stats and career records
- Custom team creation
