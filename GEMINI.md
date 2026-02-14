# GEMINI.md — Project Handoff & Next Steps

## 1. Project Goal & History

The primary objective is to create a faithful recreation of the 1993 classic **Front Page Sports: Football Pro** using modern technologies (SwiftUI on macOS).

The project has progressed in phases:
- **Initial Scaffolding (Claude):** The core Swift application structure, UI components (`FPSFieldView`, `FPSPlayCallingScreen`, etc.), and visual style (`RetroStyle`) were established. The original game's data files were identified, and a high-level plan was created.
- **Reverse Engineering (Codex):** A significant effort was made to decode the original game's playbook files. This phase successfully produced decoders that can read and index the authentic playbooks.

## 2. Current Status - What is COMPLETE

As of this handoff, the project has successfully reverse-engineered the structure of the playbook files (`.PLN` and `.PRF`) and implemented a decoder for play scripts.

**Key Achievements:**
- **`PRFDecoder.swift`:** A Swift module that can parse the binary structure of the original `.PRF` (play data) and `.PLN` (play index) files.
- **`AuthenticPlaybookLoader.swift`:** A high-level service that uses `PRFDecoder` to load the complete, authentic playbooks for both offense (76 plays) and defense (74 plays) from the original game's `FBPRO_ORIGINAL` directory.
- **`RouteScriptDecoder.swift`:** This module is now fully implemented. It takes raw play script bytes, interprets action codes and states, tracks player movements across the grid, and generates `PlayRoute` objects. It is formation-aware and includes initial logic for nuanced route interpretation (e.g., `.cut` route type).
- **Protocol Refactoring:** `PlayCall` and `DefensiveCall` are now protocols, with `StandardPlayCall` and `StandardDefensiveCall` structs for standard plays, and `AuthenticPlayCall` struct for authentic plays.
- **Public Access Modifications:** Extensive `public` access modifiers have been added to numerous structs and enums across `Game.swift`, `Team.swift`, `Player.swift`, `Play.swift`, `DefensivePlayArt.swift`, `PlayAnimationBlueprint.swift`, `PlayerRole.swift`, and `FPSFieldView.swift` to resolve integration issues.
- **`mapPrfFormationToOffensiveFormation` Moved:** This helper function has been moved from `GameViewModel.swift` to `Play.swift` as a static method on `OffensiveFormation`, resolving `@MainActor` isolation warnings.
- **`FPSPlayer.id` Public Access:** The `id` property of `FPSPlayer` in `FPSFieldView.swift` has been made public.
- **Compilation, Testing & Warning Resolution:** The entire project now compiles with **0 errors and 0 warnings**. All existing unit tests (`PRFDecoderTests`, `AuthenticPlaybookLoaderTests`, `RouteScriptDecoderTests`, `SimulationEngineTests`, `LeagueTests`, `TeamTests`) pass. All warnings related to redundant `public` modifiers, explicit module imports, unused variables, and asynchronous function usage have been resolved.
- **Corrected Schedule Generation:** The `SeasonGenerator` has been updated to correctly generate schedules ensuring each team plays the expected number of games (14 games for an 8-team league in the current setup).
- **Corrected Win Percentage Calculation:** The `winPercentage` calculation in `TeamRecord` has been corrected to properly account for ties.

## 3. The Core Unfinished Task: Play Art Integration & Refinement

The `RouteScriptDecoder` is complete in its initial implementation, but integrating its output into the game's visual and simulation loops, along with refining its interpretation logic, remains.

- **The Problem:** While the decoding is functional, the semantic interpretation of complex `ActionCode` sequences might need further refinement to perfectly match the original game's route trees. The integration into the actual game animation and simulation is also ongoing.
- **The Goal:** Seamlessly integrate the `PlayRoute` output from `RouteScriptDecoder` into `PlayBlueprintGenerator` and the game loop, ensuring visual authenticity and accurate simulation based on the decoded plays.

## 4. Next Steps & Plan for Gemini

The immediate and primary tasks involve finalizing the integration of decoded play art and addressing remaining warnings.

**Action Plan:**
1.  **Integrate Decoded Play Art:**
    -   Ensure `GameViewModel.swift` correctly feeds the `PlayRoute` array from `RouteScriptDecoder` to `PlayBlueprintGenerator`.
    -   Verify the visual representation of authentic plays on the field via `FPSFieldView`.
    -   Refine the `interpretRoute` logic within `RouteScriptDecoder` as needed, by analyzing more complex play scripts and comparing generated routes to expected outcomes.
2.  **Further Reverse Engineering:** Once core play art is integrated, focus will shift to other game assets like `ANIM.DAT`.

## 5. Next Major Reverse Engineering Targets

-   `ANIM.DAT` (Player animation data)
-   Other game data files (rosters, graphics, audio, UI elements)