# Reverse Engineering Handoff (PRF/PLN)

Last updated: 2026-02-13
Scope: FPS '93 playbook reverse engineering for `OFF.PLN` / `DEF.PLN` + `OFF1/2.PRF` / `DEF1/2.PRF`

## Read This First
If chat context is gone, start here and then open:
1. `/Users/markcornelius/projects/claude/footballPro/footballPro/CODEX_PROGRESS.md`
2. `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro/Services/PRFDecoder.swift`
3. `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro/Services/AuthenticPlaybookLoader.swift`
4. `/Users/markcornelius/projects/claude/footballPro/footballPro/Tests/PRFDecoderTests.swift`
5. `/Users/markcornelius/projects/claude/footballPro/footballPro/Tests/AuthenticPlaybookLoaderTests.swift`

## What Was Implemented
### 1) Binary decoders
`PRFDecoder.swift` now decodes:
- PRF headers/footers, 20x18 cell grid, 7 pages per bank, phase grouping helpers.
- PLN headers, 86-slot offset table, 18-byte entries, `prfPage/prfOffset/size` fields.
- Action and formation display mappings.

### 2) High-level playbook resolver
`AuthenticPlaybookLoader.swift` now loads full authentic playbooks from `FBPRO_ORIGINAL` and resolves each play to:
- bank (`first` / `second`)
- page (`0...6`)
- raw offset
- normalized virtual offset
- size
- page signature fingerprint

### 3) Tests
- `PRFDecoderTests.swift` verifies PRF/PLN structural decode.
- `AuthenticPlaybookLoaderTests.swift` verifies reference resolution and known OFF/DEF counts.

## Reverse-Engineered Findings
## PRF file structure
Observed from original files:
- Header: 0x28 (40) bytes
- Payload: 15120 bytes
- Footer marker: `#I93:`
- Page count per PRF: 7
- Grid shape per page: 20 rows x 18 columns
- Cell size: 6 bytes

Cell lookup formula (implemented):
- `groupIndex = row * 18 + column`
- `groupOffset = 0x28 + groupIndex * 42`
- `recordOffset = groupOffset + playIndex * 6`

Where:
- `42 = 6 bytes * 7 pages`
- `playIndex` is the PRF page index `0...6`

## PLN file structure
Observed from original files:
- Header: 12 bytes (`G93:` + config bytes)
- Offset table: 86 entries * 2 bytes = 172 bytes
- Entry area starts at byte 184 (`0xB8`)
- Entry size: 18 bytes

PLN entry format (implemented):
- bytes 0..1: formation code (LE u16)
- bytes 2..3: formation mirror/subtype (LE u16)
- bytes 4..11: 8-byte null-terminated ASCII name
- bytes 12..15: PRF reference raw (LE u32)
  - high word: `prfPage`
  - low word: `prfOffset`
- bytes 16..17: play size (LE u16)

## Critical address model (resolved)
`prfOffset` low word has bank selector embedded in its high bit:
- `rawOffset & 0x8000 == 0` => first bank (`OFF1.PRF` / `DEF1.PRF`)
- `rawOffset & 0x8000 != 0` => second bank (`OFF2.PRF` / `DEF2.PRF`)

Normalized virtual offset:
- `virtualOffset = rawOffset & 0x7FFF`

This model is encoded in:
- `AuthenticPlaybookLoader.resolveBank(forRawOffset:)`
- `AuthenticPlaybookLoader.normalizedVirtualOffset(from:)`

## Validation evidence captured in tests
Current expected splits:
- OFF: 76 plays total
  - bank 1: 39
  - bank 2: 37
- DEF: 74 plays total
  - bank 1: 51
  - bank 2: 23

## What Is Still Not Fully Decoded
These parts are not yet finished:
1. Semantic decode of the script payload represented by `virtualOffset + size`.
2. Exact translation from script bytes to route vectors/waypoints per player.
3. Full runtime replacement of hardcoded UI play art with decoded authentic routes.

Important: PRF page-level decode is complete, but payload script semantics for individual named plays are only partially interpreted.

## Files Added/Modified
Added:
- `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro/Services/PRFDecoder.swift`
- `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro/Services/AuthenticPlaybookLoader.swift`
- `/Users/markcornelius/projects/claude/footballPro/footballPro/Tests/PRFDecoderTests.swift`
- `/Users/markcornelius/projects/claude/footballPro/footballPro/Tests/AuthenticPlaybookLoaderTests.swift`
- `/Users/markcornelius/projects/claude/footballPro/footballPro/CODEX_PROGRESS.md`
- `/Users/markcornelius/projects/claude/footballPro/footballPro/REVERSE_ENGINEERING_HANDOFF.md`

Modified:
- `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro.xcodeproj/project.pbxproj`

Unrelated pre-existing untracked file:
- `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro.xcodeproj/project.pbxproj.new`

## Commands To Reproduce/Verify
From `/Users/markcornelius/projects/claude/footballPro/footballPro`:

```bash
swift test --filter "PRF|Authentic"
swift build
```

Optional decode inspection (legacy script):
```bash
python3 decode_prf.py
```

## API Usage Examples
### Load offense playbook
```swift
let dataURL = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")
let offBook = try AuthenticPlaybookLoader.load(from: dataURL, kind: .offense)
print(offBook.plays.count)
```

### Read resolved reference for a play
```swift
if let fg = offBook.plays.first(where: { $0.name == "FGPAT" }) {
    print(fg.reference.bank, fg.reference.page, fg.reference.rawOffset, fg.reference.virtualOffset, fg.reference.size)
}
```

## Resume Plan (If Picking Up Later)
1. Keep `PRFDecoder` and `AuthenticPlaybookLoader` stable.
2. Add a `RouteScriptDecoder` layer that reads script bytes from normalized `virtualOffset + size`.
3. Convert decoded script to `PlayRoute` + waypoint data.
4. Add fallback strategy:
   - Use authentic decoded play when available.
   - Fall back to current hardcoded `PlayArtDatabase` if decode fails.
5. Integrate into:
   - `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro/Views/Game/FPSPlayCallingScreen.swift`
   - `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro/ViewModels/GameViewModel.swift`
6. Add integration tests for known named plays across OFF and DEF.

## Risks and Caveats
- `isSpecialTeams` classification currently uses mixed signal (formation/mirror + name heuristic).
- Full semantic correctness of `virtualOffset + size` script decode is still outstanding.
- Main test suite has unrelated historical failures; use targeted filters for PRF/auth work.

## Quick Recovery Checklist
- [ ] Open this file and `CODEX_PROGRESS.md`
- [ ] Run `swift test --filter "PRF|Authentic"`
- [ ] Confirm OFF=76 and DEF=74 with expected bank splits
- [ ] Continue at `RouteScriptDecoder` implementation
- [ ] Do not delete `project.pbxproj.new` unless explicitly desired
