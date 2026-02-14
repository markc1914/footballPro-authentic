# Codex Progress Log

Last updated: 2026-02-13
Owner: Codex

## Important
Primary handoff document:
- `/Users/markcornelius/projects/claude/footballPro/footballPro/REVERSE_ENGINEERING_HANDOFF.md`

Read that first if chat context is unavailable.

## Current Focus
Reverse engineering FPS '93 PRF/PLN and converting it into executable Swift loaders.

## Completed
- Added `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro/Services/PRFDecoder.swift`.
- Added `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro/Services/AuthenticPlaybookLoader.swift`.
- Added `/Users/markcornelius/projects/claude/footballPro/footballPro/Tests/PRFDecoderTests.swift`.
- Added `/Users/markcornelius/projects/claude/footballPro/footballPro/Tests/AuthenticPlaybookLoaderTests.swift`.
- Updated `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro.xcodeproj/project.pbxproj` for new sources.
- Documented full technical handoff in `/Users/markcornelius/projects/claude/footballPro/footballPro/REVERSE_ENGINEERING_HANDOFF.md`.

## Validation
- `swift test --filter "PRF|Authentic"` passes.
- `swift build` passes.

## Resolved Model
- `prfOffset` high bit selects bank:
  - 0 => bank 1 (`OFF1/DEF1`)
  - 1 => bank 2 (`OFF2/DEF2`)
- `virtualOffset = prfOffset & 0x7FFF`

## Remaining Work
1. Decode script semantics behind `virtualOffset + size`.
2. Translate script bytes into route/waypoint structures.
3. Integrate decoded authentic play routes into gameplay path with fallback.

## Notes
- Existing untracked file still present: `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro.xcodeproj/project.pbxproj.new`.
- Existing unrelated suite failures remain outside PRF/auth scope.
