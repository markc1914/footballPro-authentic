# GEMINI.md — Project Handoff & Next Steps

## 1. Project Goal & History

The primary objective is to create a faithful recreation of the 1993 classic **Front Page Sports: Football Pro** using modern technologies (SwiftUI on macOS).

The project has progressed in phases:
- **Initial Scaffolding (Claude):** The core Swift application structure, UI components (`FPSFieldView`, `FPSPlayCallingScreen`, etc.), and visual style (`RetroStyle`) were established. The original game's data files were identified, and a high-level plan was created.
- **Reverse Engineering (Codex):** A significant effort was made to decode the original game's playbook files. This phase successfully produced decoders that can read and index the authentic playbooks.

## 2. Current Status - What is COMPLETE

As of this handoff, the project has successfully reverse-engineered the structure of the playbook files (`.PLN` and `.PRF`) and implemented a decoder for play scripts, and has now **fully decoded the `ANIM.DAT` file for player sprite animations**. A comprehensive testing infrastructure has also been established, with all test suites passing.

**Key Achievements:**
- **`PRFDecoder.swift`:** A Swift module that can parse the binary structure of the original `.PRF` (play data) and `.PLN` (play index) files.
- **`AuthenticPlaybookLoader.swift`:** A high-level service that uses `PRFDecoder` to load the complete, authentic playbooks for both offense (76 plays) and defense (74 plays) from the original game's `FBPRO_ORIGINAL` directory.
- **`RouteScriptDecoder.swift`:** This module is now fully implemented. It takes raw play script bytes, interprets action codes and states, tracks player movements across the grid, and generates `PlayRoute` objects. It is formation-aware and includes initial logic for nuanced route interpretation (e.g., `.cut` route type).
- **`ANIM.DAT` Decoding (COMPLETED):** The LZ77 compression for `ANIM.DAT` (player animation data) has been fully cracked and reverse-engineered. The complete rendering pipeline from the original A.EXE has been understood, including sprite indexing, frame data, and the application of color tables and mirroring.
- **`AnimDecoder.swift`:** A Swift module that can parse the index table, sprite metadata, and perform LZ77 decompression for `ANIM.DAT`, including handling of color tables and horizontal mirroring flags.
- **`SpriteCache.swift`:** Implemented for efficient caching and retrieval of decoded sprites as `CGImage` instances, applying gameplay palettes and handling transparency.
- **Protocol Refactoring:** `PlayCall` and `DefensiveCall` are now protocols, with `StandardPlayCall` and `StandardDefensiveCall` structs for standard plays, and `AuthenticPlayCall` struct for authentic plays.
- **Public Access Modifications:** Extensive `public` access modifiers have been added to numerous structs and enums across `Game.swift`, `Team.swift`, `Player.swift`, `Play.swift`, `DefensivePlayArt.swift`, `PlayAnimationBlueprint.swift`, `PlayerRole.swift`, and `FPSFieldView.swift` to resolve integration issues.
- **`mapPrfFormationToOffensiveFormation` Moved:** This helper function has been moved from `GameViewModel.swift` to `Play.swift` as a static method on `OffensiveFormation`, resolving `@MainActor` isolation warnings.
- **`FPSPlayer.id` Public Access:** The `id` property of `FPSPlayer` in `FPSFieldView.swift` has been made public.
- **Comprehensive Testing Infrastructure:**
    -   14 test files in `footballPro/Tests/` using Swift `Testing` framework.
    -   `ScreenshotHarness` captures 32 mock screenshots.
    -   `generate_test_fixtures.py` creates fixture data for visual comparison.
    -   New test suites (`AnimDecoderTests`, `SpriteCacheTests`, `VisualComparisonTests`, `GameFlowTests`, `SpriteIntegrationTests`) have been implemented and are passing.
- **Compilation, Testing & Warning Resolution:** The entire project now compiles with **0 errors and 0 warnings**. All existing and new unit tests pass. All warnings related to redundant `public` modifiers, explicit module imports, unused variables, and asynchronous function usage have been resolved.
- **Corrected Schedule Generation:** The `SeasonGenerator` has been updated to correctly generate schedules ensuring each team plays the expected number of games (14 games for an 8-team league in the current setup).
- **Corrected Win Percentage Calculation:** The `winPercentage` calculation in `TeamRecord` has been corrected to properly account for ties.

## 3. The Core Unfinished Task: Play Art Integration & Refinement, and Sprite Animation



The `RouteScriptDecoder` is complete in its initial implementation, but integrating its output into the game's visual and simulation loops, along with refining its interpretation logic, remains. Furthermore, with `ANIM.DAT` fully decoded and `AnimDecoder.swift` and `SpriteCache.swift` implemented, the next critical task is to integrate these authentic sprites into the `FPSFieldView` and build the animation state machine to bring the players to life.



-   **The Problem:** While play script decoding is functional, semantic interpretation might need refinement. More critically, the authentic player sprites are decoded but not yet rendered in the game, nor is there a system for frame-by-frame animation during play execution.

-   **The Goal:** Seamlessly integrate the `PlayRoute` output from `RouteScriptDecoder` into `PlayBlueprintGenerator` and the game loop, ensuring visual authenticity and accurate simulation based on the decoded plays. Concurrently, integrate authentic player sprites into `FPSFieldView`, correctly mapping player movement to animation frames and directions, and implement an animation state machine to handle frame-by-frame updates and animation transitions.

## 4. Next Steps & Plan for Gemini

The immediate and primary tasks involve finalizing the integration of decoded play art and, crucially, integrating the newly decoded `ANIM.DAT` sprites into the game's visual representation and implementing the animation state machine.

**Action Plan:**
1.  **Integrate Decoded Play Art (Continued Refinement):**
    -   Ensure `GameViewModel.swift` correctly feeds the `PlayRoute` array from `RouteScriptDecoder` to `PlayBlueprintGenerator`.
    -   Verify the visual representation of authentic plays on the field via `FPSFieldView`.
    -   Refine the `interpretRoute` logic within `RouteScriptDecoder` as needed, by analyzing more complex play scripts and comparing generated routes to expected outcomes.
2.  **Integrate Authentic Player Sprites (Phase D from CLAUDE.md):**
    -   Replace geometric player shapes in `FPSFieldView` with authentic sprites loaded via `AnimDecoder.swift` and `SpriteCache.swift`.
    -   Correctly map player movement direction to the appropriate sprite view index (8 compass directions).
    -   Map game state (e.g., pre-snap, running, passing, blocking) to specific animation names (e.g., `LMSTAND`, `SKRUN`, `QBBULIT`).
    -   Ensure sprites are scaled correctly through `PerspectiveProjection` and drawn in depth order.
3.  **Implement Animation State Machine (Phase E from CLAUDE.md):**
    -   Develop a robust `AnimationState` system per player to manage `currentAnimation`, `currentFrame`, and `currentView`.
    -   Implement an animation tick system (~15 fps) to drive frame-by-frame updates.
    -   Handle instant animation switches based on game events (e.g., player changes direction, ball is snapped).
    -   Manage two-player animations (e.g., `L2*` animations) by syncing paired players.
4.  **Further Reverse Engineering (Phases F & G from CLAUDE.md):** Once core play art and sprite animation are integrated, focus will shift to other game assets like screen graphics (`SCR`/`DDA`) and audio (`SAMPLE.DAT`).

## 5. Next Major Reverse Engineering Targets

-   Screen graphics (`*.SCR`, `*.DDA` for cutscenes)
-   Audio (`SAMPLE.DAT`)
-   Other game data files (rosters, graphics, UI elements)