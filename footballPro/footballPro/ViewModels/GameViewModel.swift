//
//  GameViewModel.swift
//  footballPro
//
//  Live game state management
//

import Foundation
import SwiftUI
import Combine // Import Combine for @Published (already implicitly there, but good to be explicit for clarity)

// Import other relevant modules


// MARK: - Game Phase State Machine

public enum GamePhase: Equatable { // Made public
    case playCalling          // Full-screen play calling grid
    case presnap              // Brief pre-snap field view
    case playAnimation        // Full-screen field during play
    case playResult           // Result overlay ON the field
    case refereeCall(String)  // Referee overlay with message
    case specialResult(String) // Drive result (TD, turnover overlay)
    case halftime             // Halftime display
    case gameOver             // Final score
    case paused               // Pause menu overlay
}

@MainActor
public class GameViewModel: ObservableObject { // Made public
    @Published public var game: Game? // Made public
    @Published public var homeTeam: Team? // Made public
    @Published public var awayTeam: Team? // Made public

    @Published public var isUserPossession = false // Made public
    @Published public var currentPhase: GamePhase = .playCalling // Made public
    @Published public var isSimulating = false // Made public

    // Legacy compatibility (accessors for SwiftUI views)
    public var isPlayCallScreenVisible: Bool { // Made public
        get { currentPhase == .playCalling }
        set { if newValue { currentPhase = .playCalling } }
    }
    public var isPaused: Bool { // Made public
        get { if case .paused = currentPhase { return true }; return false }
        set { currentPhase = newValue ? .paused : .playCalling }
    }
    public var showDriveResult: Bool { // Made public
        get { if case .specialResult = currentPhase { return true }; return false }
        set { if !newValue { currentPhase = .playCalling } }
    }
    public var driveResultText: String { // Made public
        get { if case .specialResult(let text) = currentPhase { return text }; return "" }
        set { currentPhase = .specialResult(newValue) }
    }

    @Published public var selectedOffensivePlay: (any PlayCall)? // Changed to protocol
    @Published public var selectedDefensivePlay: (any DefensiveCall)? // Changed to protocol

    // Store the visual play art for animations
    @Published public var selectedPlayArt: PlayArt? // Made public
    @Published public var selectedDefensivePlayArt: DefensivePlayArt? // Made public

    // Animation blueprint for FPSFieldView's TimelineView loop
    @Published public var currentAnimationBlueprint: PlayAnimationBlueprint? // Made public

    @Published public var playByPlay: [PlayResult] = [] // Made public
    @Published public var lastPlayResult: PlayResult? // Made public

    // Phase before pause was entered (to restore on resume)
    private var phaseBeforePause: GamePhase = .playCalling

    private let simulationEngine = SimulationEngine()
    private let aiCoach = AICoach()

    // Track which team the user controls
    private var userTeamId: UUID?

    // New: Authentic Playbook Loader and stored plays
    private var authenticOffensivePlaybook: [AuthenticPlayDefinition] = []
    private var authenticDefensivePlaybook: [AuthenticPlayDefinition] = []

    // Pagination for play calling screen (16 slots per page)
    @Published public var currentPlaybookPage: Int = 0
    public let playsPerPage: Int = 16

    /// Current offensive formation from selected play (for pre-snap display)
    public var currentOffensiveFormation: OffensiveFormation? {
        selectedOffensivePlay?.formation
    }

    /// Current defensive formation from selected play (for pre-snap display)
    public var currentDefensiveFormation: DefensiveFormation? {
        selectedDefensivePlay?.formation
    }

    // MARK: - Game Setup

    public func setupGame(homeTeam: Team, awayTeam: Team, week: Int, seasonYear: Int, userTeamId: UUID, quarterMinutes: Int = 15) { // Made public
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.userTeamId = userTeamId

        simulationEngine.setupGame(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            week: week,
            seasonYear: seasonYear,
            quarterMinutes: quarterMinutes
        )

        self.game = simulationEngine.currentGame

        // Load authentic playbooks
        loadAuthenticPlaybooks()

        simulationEngine.startGame()
        self.game = simulationEngine.currentGame

        // Execute opening kickoff automatically
        Task {
            await self.executeOpeningKickoff() // Added self
        }
    }

    private func loadAuthenticPlaybooks() {
        do {
            let fbproOriginalURL = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")
            authenticOffensivePlaybook = try AuthenticPlaybookLoader.load(from: fbproOriginalURL, kind: .offense).plays // Static call
            authenticDefensivePlaybook = try AuthenticPlaybookLoader.load(from: fbproOriginalURL, kind: .defense).plays // Static call
            print("Loaded \(authenticOffensivePlaybook.count) authentic offensive plays.")
            print("Loaded \(authenticDefensivePlaybook.count) authentic defensive plays.")
        } catch {
            print("Error loading authentic playbooks: \(error)")
        }
    }

    // NEW: Placeholder for opening kickoff logic
    internal func executeOpeningKickoff() async {
        print("Executing opening kickoff...")
        // This will be implemented fully later. For now, it just advances the game.
        _ = await simulationEngine.executeKickoff()
        self.game = simulationEngine.currentGame
        updatePossessionStatus()
    }

    private func updatePossessionStatus() {
        guard let game = game, let userTeamId = userTeamId else {
            isUserPossession = true // Default to offense if something's wrong
            return
        }
        isUserPossession = game.possessingTeamId == userTeamId
        currentPlaybookPage = 0 // Reset pagination on possession change
    }

    // MARK: - Play Calling

    /// All non-special-teams offensive plays from authentic FPS '93 playbook
    public var availableOffensivePlays: [AuthenticPlayCall] {
        authenticOffensivePlaybook
            .filter { !$0.isSpecialTeams }
            .map { AuthenticPlayCall(play: $0) }
    }

    /// All non-special-teams defensive plays from authentic FPS '93 playbook
    public var availableDefensivePlays: [AuthenticDefensiveCall] {
        authenticDefensivePlaybook
            .filter { !$0.isSpecialTeams }
            .map { AuthenticDefensiveCall(play: $0) }
    }

    /// Special teams plays (kickoff, punt, FG/PAT) from authentic playbook
    public var availableSpecialTeamsPlays: [AuthenticPlayCall] {
        authenticOffensivePlaybook
            .filter { $0.isSpecialTeams }
            .map { AuthenticPlayCall(play: $0) }
    }

    // MARK: - Pagination Helpers

    /// Plays for the current page (16 per page) based on offense/defense/ST mode
    public func currentPagePlays(isSpecialTeams: Bool) -> [String] {
        let allPlays: [String]
        if isUserPossession {
            let source = isSpecialTeams ? availableSpecialTeamsPlays : availableOffensivePlays
            allPlays = source.map { $0.displayName }
        } else {
            allPlays = availableDefensivePlays.map { $0.displayName }
        }

        let start = currentPlaybookPage * playsPerPage
        guard start < allPlays.count else { return [] }
        let end = min(start + playsPerPage, allPlays.count)
        return Array(allPlays[start..<end])
    }

    /// Total pages for current play list
    public func totalPages(isSpecialTeams: Bool) -> Int {
        let count: Int
        if isUserPossession {
            count = isSpecialTeams ? availableSpecialTeamsPlays.count : availableOffensivePlays.count
        } else {
            count = availableDefensivePlays.count
        }
        return max(1, (count + playsPerPage - 1) / playsPerPage)
    }

    public func nextPage(isSpecialTeams: Bool) {
        let total = totalPages(isSpecialTeams: isSpecialTeams)
        if currentPlaybookPage < total - 1 {
            currentPlaybookPage += 1
        }
    }

    public func previousPage(isSpecialTeams: Bool) {
        if currentPlaybookPage > 0 {
            currentPlaybookPage -= 1
        }
    }

    public func selectOffensivePlay(_ play: any PlayCall) { // Changed to protocol
        selectedOffensivePlay = play
    }

    public func selectDefensivePlay(_ play: any DefensiveCall) { // Changed to protocol
        selectedDefensivePlay = play
    }

    // MARK: - Play Execution

    public func runPlay() async { // Made public
        guard let game = game else { return }

        isSimulating = true
        defer { isSimulating = false }

        let offensiveCall: any PlayCall // Changed to protocol
        let defensiveCall: any DefensiveCall // Changed to protocol

        if isUserPossession {
            // User is on offense
            guard let userPlay = selectedOffensivePlay else { return }
            offensiveCall = userPlay

            let defTeam = game.isHomeTeamPossession ? awayTeam! : homeTeam!
            let situation = currentSituation()
            defensiveCall = aiCoach.selectDefensivePlay(for: defTeam, situation: situation, playbook: authenticDefensivePlaybook)

            // NEW: Use AuthenticPlaybookLoader and RouteScriptDecoder for PlayArt
            if let authenticCall = userPlay as? AuthenticPlayCall { // Cast to AuthenticPlayCall
                let authenticPlay = authenticCall.play // Get the underlying AuthenticPlayDefinition

                do {
                    let prfFileName = authenticPlay.reference.bank == .first ? "OFF1.PRF" : "OFF2.PRF"
                    let fbproOriginalURL = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")
                    let prfFileUrl = fbproOriginalURL.appendingPathComponent(prfFileName)
                    let prfData = try Data(contentsOf: prfFileUrl)
                    
                    if let playGrid = RouteScriptDecoder.extractPlayGrid(
                        from: prfData,
                        prfBaseOffset: 0x28, // Constant from decode_prf.py
                        playIndex: Int(authenticPlay.reference.page)
                    ) {
                        let decodedRoutes = RouteScriptDecoder.decode(grid: playGrid, formationCode: authenticPlay.formationCode)
                        
                        // Map UInt16 formation code to OffensiveFormation enum
                        let offensiveFormation = OffensiveFormation.fromPrfFormationCode(authenticPlay.formationCode)

                        selectedPlayArt = PlayArt(
                            playName: authenticPlay.name,
                            playType: offensiveCall.playType, // Use the simulation playType from the protocol
                            formation: offensiveFormation,
                            routes: decodedRoutes,
                            description: "Authentic: \(authenticPlay.name)",
                            expectedYards: 5 // Placeholder, needs to be derived
                        )
                         print("Generated authentic PlayArt for \(authenticPlay.name) with \(decodedRoutes.count) routes.")
                    }
                } catch {
                    print("Error decoding authentic play art for \(authenticPlay.name): \(error)")
                    // Fallback to random hardcoded play art if decoding fails
                    selectedPlayArt = PlayArtDatabase.shared.randomPlay(for: offensiveCall.playType)
                }
            } else {
                // Fallback to random hardcoded play art for standard plays
                selectedPlayArt = PlayArtDatabase.shared.randomPlay(for: offensiveCall.playType)
            }
        } else {
            // User is on defense
            guard let userDefense = selectedDefensivePlay else { return }
            defensiveCall = userDefense

            let offTeam = game.isHomeTeamPossession ? homeTeam! : awayTeam!
            let situation = currentSituation()
            offensiveCall = aiCoach.selectOffensivePlay(for: offTeam, situation: situation, playbook: authenticOffensivePlaybook)

            // Decode AI's offensive play art from PRF if it picked an authentic play
            if let aiAuthenticCall = offensiveCall as? AuthenticPlayCall {
                selectedPlayArt = decodeOffensivePlayArt(for: aiAuthenticCall.play, playType: offensiveCall.playType)
            } else {
                selectedPlayArt = PlayArtDatabase.shared.randomPlay(for: offensiveCall.playType)
            }

            // Decode user's defensive play art from DEF PRF if authentic
            if let userAuthenticDef = userDefense as? AuthenticDefensiveCall {
                selectedDefensivePlayArt = decodeDefensivePlayArt(for: userAuthenticDef.play, formation: defensiveCall.formation)
            } else {
                selectedDefensivePlayArt = DefensivePlayArtDatabase.shared.randomDefensivePlay(for: defensiveCall.formation)
            }
        }

        // Execute the play
        let preLOS = game.fieldPosition.yardLine
        if let result = await simulationEngine.executePlay(
            offensiveCall: offensiveCall,
            defensiveCall: defensiveCall
        ) {
            self.game = simulationEngine.currentGame

            playByPlay.insert(result, at: 0)
            lastPlayResult = result

            currentAnimationBlueprint = PlayBlueprintGenerator.generateBlueprint(
                playArt: selectedPlayArt,
                defensiveArt: selectedDefensivePlayArt,
                result: result,
                los: preLOS
            )

            currentPhase = .playAnimation

            try? await Task.sleep(nanoseconds: UInt64((currentAnimationBlueprint?.totalDuration ?? 3.0) * 1_000_000_000))

            currentPhase = .playResult
        } else {
            self.game = simulationEngine.currentGame
        }

        await handleSpecialSituations()

        // Clear selections
        selectedOffensivePlay = nil
        selectedDefensivePlay = nil
        selectedPlayArt = nil
        selectedDefensivePlayArt = nil

        updatePossessionStatus()
    }

    private func handleSpecialSituations() async {
        guard game != nil else { return }

        if self.game?.isExtraPoint == true {
            let success = await simulationEngine.executeExtraPoint()
            let text = success ? "Extra point is GOOD!" : "Extra point MISSED!"
            showDriveResult(text: text)
            self.game = simulationEngine.currentGame
        }

        if self.game?.isKickoff == true {
            let result = await simulationEngine.executeKickoff()
            self.game = simulationEngine.currentGame
            lastPlayResult = result
            playByPlay.append(result)
        }

        if self.game?.gameStatus == .halftime {
            showDriveResult(text: "HALFTIME")
        }

        if self.game?.gameStatus == .final {
            showDriveResult(text: "FINAL")
        }
    }

    // MARK: - Special Teams

    public func attemptFieldGoal() async { // Made public
        guard let game = game else { return }

        isSimulating = true
        defer { isSimulating = false }

        let success = await simulationEngine.executeFieldGoal(from: game.fieldPosition.yardLine)
        let distance = 100 - game.fieldPosition.yardLine + 17
        let text = success ?
            "\(distance)-yard field goal is GOOD!" :
            "\(distance)-yard field goal is NO GOOD!"

        showDriveResult(text: text)
        self.game = simulationEngine.currentGame
        updatePossessionStatus()
    }

    public func attemptExtraPoint() async { // Made public
        isSimulating = true
        defer { isSimulating = false }

        let success = await simulationEngine.executeExtraPoint()
        let text = success ? "Extra point is GOOD!" : "Extra point MISSED!"
        showDriveResult(text: text)
        self.game = simulationEngine.currentGame

        if self.game?.isKickoff == true {
            let result = await simulationEngine.executeKickoff()
            self.game = simulationEngine.currentGame
            lastPlayResult = result
            playByPlay.append(result)
        }
        updatePossessionStatus()
    }

    public func punt() async { // Made public
        isSimulating = true
        defer { isSimulating = false }

        let result = await simulationEngine.executePunt()
        lastPlayResult = result
        playByPlay.append(result)
        showDriveResult(text: "Punt: \(result.description)")
        self.game = simulationEngine.currentGame
        updatePossessionStatus()
    }

    // MARK: - Simulation

    public func simulateDrive() async { // Made public
        guard var game = game else { return }

        isSimulating = true
        defer { isSimulating = false }

        let driveStartTeam = game.possessingTeamId

        while game.possessingTeamId == driveStartTeam &&
              game.gameStatus == .inProgress &&
              !game.isExtraPoint &&
              !game.isKickoff {
            let offTeam = game.isHomeTeamPossession ? homeTeam! : awayTeam!
            let defTeam = game.isHomeTeamPossession ? awayTeam! : homeTeam!
            let situation = currentSituation()

            if game.downAndDistance.down == 4 {
                let kicker = offTeam.starter(at: .kicker) // Still using .kicker, fix this
                let decision = aiCoach.fourthDownDecision(situation: situation, kicker: kicker)

                switch decision {
                case .punt:
                    let result = await simulationEngine.executePunt()
                    lastPlayResult = result
                    playByPlay.append(result)
                    game = simulationEngine.currentGame!
                    self.game = game
                    break
                case .fieldGoal:
                    _ = await simulationEngine.executeFieldGoal(from: game.fieldPosition.yardLine)
                    game = simulationEngine.currentGame!
                    self.game = game
                    break
                case .goForIt:
                    break
                }

                if decision != .goForIt {
                    break
                }
            }

            let offCall = aiCoach.selectOffensivePlay(for: offTeam, situation: situation, playbook: authenticOffensivePlaybook)
            let defCall = aiCoach.selectDefensivePlay(for: defTeam, situation: situation, playbook: authenticDefensivePlaybook)

            if let result = await simulationEngine.executePlay(offensiveCall: offCall, defensiveCall: defCall) {
                playByPlay.insert(result, at: 0)
            }

            game = simulationEngine.currentGame!
            self.game = game

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        await handleSpecialSituations()
    }

    public func simulateToHalftime() async { // Made public
        guard game != nil else { return }

        isSimulating = true
        defer { isSimulating = false }

        while simulationEngine.currentGame?.clock.quarter ?? 3 <= 2 &&
              simulationEngine.currentGame?.gameStatus == .inProgress {
            await simulateDrive()
        }

        self.game = simulationEngine.currentGame
    }

    public func simulateToEnd() async { // Made public
        guard var game = game else { return }

        isSimulating = true
        defer { isSimulating = false }

        var playCount = 0
        let maxPlays = 300

        while game.gameStatus != .final && playCount < maxPlays {
            playCount += 1

            if game.gameStatus == .halftime {
                simulationEngine.startSecondHalf()
                if let updatedGame = simulationEngine.currentGame {
                    game = updatedGame
                    self.game = game
                }
                continue
            }

            if game.isKickoff {
                _ = await simulationEngine.executeKickoff()
            } else if game.isExtraPoint {
                _ = await simulationEngine.executeExtraPoint()
            } else {
                guard let offTeam = game.isHomeTeamPossession ? homeTeam : awayTeam,
                      let defTeam = game.isHomeTeamPossession ? awayTeam : homeTeam else {
                    break
                }

                let situation = currentSituation()

                if game.downAndDistance.down == 4 {
                    let kicker = offTeam.starter(at: .kicker) // Still using .kicker, fix this
                    let decision = aiCoach.fourthDownDecision(situation: situation, kicker: kicker)

                    switch decision {
                    case .punt:
                        let result = await simulationEngine.executePunt()
                        lastPlayResult = result
                        playByPlay.insert(result, at: 0)
                        if let updatedGame = simulationEngine.currentGame {
                            game = updatedGame
                            self.game = game
                        }
                        continue
                    case .fieldGoal:
                        _ = await simulationEngine.executeFieldGoal(from: game.fieldPosition.yardLine)
                        if let updatedGame = simulationEngine.currentGame {
                            game = updatedGame
                            self.game = game
                        }
                        continue
                    case .goForIt:
                        break
                    }
                }

                let offCall = aiCoach.selectOffensivePlay(for: offTeam, situation: situation, playbook: authenticOffensivePlaybook)
                let defCall = aiCoach.selectDefensivePlay(for: defTeam, situation: situation, playbook: authenticDefensivePlaybook)

                if let result = await simulationEngine.executePlay(offensiveCall: offCall, defensiveCall: defCall) {
                    playByPlay.insert(result, at: 0)
                    lastPlayResult = result
                }
            }

            if let updatedGame = simulationEngine.currentGame {
                game = updatedGame
                self.game = game
            }

            if playCount % 5 == 0 {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }

        if playCount >= maxPlays {
            simulationEngine.currentGame?.gameStatus = .final
            self.game = simulationEngine.currentGame
        }
    }

    // MARK: - Helpers

    private func currentSituation() -> GameSituation {
        guard let game = game else {
            return GameSituation(
                down: 1, yardsToGo: 10, fieldPosition: 25,
                quarter: 1, timeRemaining: 900, scoreDifferential: 0, isRedZone: false
            )
        }

        return GameSituation(
            down: game.downAndDistance.down,
            yardsToGo: game.downAndDistance.yardsToGo,
            fieldPosition: game.fieldPosition.yardLine,
            quarter: game.clock.quarter,
            timeRemaining: game.clock.timeRemaining,
            scoreDifferential: game.isHomeTeamPossession ?
                game.score.homeScore - game.score.awayScore :
                game.score.awayScore - game.score.homeScore,
            isRedZone: game.fieldPosition.isRedZone
        )
    }

    private func showDriveResult(text: String) {
        currentPhase = .specialResult(text)

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if case .specialResult = currentPhase {
                continueAfterResult()
            }
        }
    }



    // MARK: - Game Information

    public var scoreDisplay: String { // Made public
        guard let game = game else { return "0 - 0" }
        return "\(game.score.awayScore) - \(game.score.homeScore)"
    }

    public var clockDisplay: String { // Made public
        guard let game = game else { return "15:00" }
        return game.clock.displayTime
    }

    public var quarterDisplay: String { // Made public
        guard let game = game else { return "1st" }
        return game.clock.quarterDisplay
    }

    public var downAndDistanceDisplay: String { // Made public
        guard let game = game else { return "1st & 10" }
        return game.downAndDistance.displayDownAndDistance
    }

    public var fieldPositionDisplay: String { // Made public
        guard let game = game else { return "OWN 25" }
        return game.fieldPosition.displayYardLine
    }

    public var possessionTeamName: String { // Made public
        guard let game = game else { return "" }
        if game.isHomeTeamPossession {
            return homeTeam?.name ?? "Home"
        }
        return awayTeam?.name ?? "Away"
    }

    // MARK: - Phase Transitions

    public func transitionTo(_ phase: GamePhase) { // Made public
        currentPhase = phase
    }

    public func togglePause() { // Made public
        if case .paused = currentPhase {
            currentPhase = phaseBeforePause
        } else {
            phaseBeforePause = currentPhase
            currentPhase = .paused
        }
    }

    public func continueAfterResult() { // Made public
        if game?.gameStatus == .final {
            currentPhase = .gameOver
        } else if game?.gameStatus == .halftime {
            currentPhase = .halftime
        } else {
            currentPhase = .playCalling
        }
    }

    public func startSecondHalf() { // Made public
        simulationEngine.startSecondHalf()
        self.game = simulationEngine.currentGame
    }

    // MARK: - PRF Play Art Decoding Helpers

    private let fbproOriginalURL = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")

    /// Decode offensive play art from an authentic PRF play definition
    private func decodeOffensivePlayArt(for play: AuthenticPlayDefinition, playType: PlayType) -> PlayArt? {
        do {
            let prfFileName = play.reference.bank == .first ? "OFF1.PRF" : "OFF2.PRF"
            let prfFileUrl = fbproOriginalURL.appendingPathComponent(prfFileName)
            let prfData = try Data(contentsOf: prfFileUrl)

            if let playGrid = RouteScriptDecoder.extractPlayGrid(
                from: prfData,
                prfBaseOffset: 0x28,
                playIndex: Int(play.reference.page)
            ) {
                let decodedRoutes = RouteScriptDecoder.decode(grid: playGrid, formationCode: play.formationCode)
                let offensiveFormation = OffensiveFormation.fromPrfFormationCode(play.formationCode)

                let art = PlayArt(
                    playName: play.name,
                    playType: playType,
                    formation: offensiveFormation,
                    routes: decodedRoutes,
                    description: "Authentic: \(play.name)",
                    expectedYards: 5
                )
                print("Decoded authentic offensive art for \(play.name) with \(decodedRoutes.count) routes.")
                return art
            }
        } catch {
            print("Error decoding offensive play art for \(play.name): \(error)")
        }
        return PlayArtDatabase.shared.randomPlay(for: playType)
    }

    /// Decode defensive play art from an authentic DEF PRF play definition
    private func decodeDefensivePlayArt(for play: AuthenticPlayDefinition, formation: DefensiveFormation) -> DefensivePlayArt? {
        do {
            let prfFileName = play.reference.bank == .first ? "DEF1.PRF" : "DEF2.PRF"
            let prfFileUrl = fbproOriginalURL.appendingPathComponent(prfFileName)
            let prfData = try Data(contentsOf: prfFileUrl)

            if let playGrid = RouteScriptDecoder.extractPlayGrid(
                from: prfData,
                prfBaseOffset: 0x28,
                playIndex: Int(play.reference.page)
            ) {
                let decodedRoutes = RouteScriptDecoder.decode(grid: playGrid, formationCode: play.formationCode)

                // Map decoded routes to DefensiveRoute using position index
                let defPositions: [DefensivePlayerPosition] = [
                    .leftEnd, .leftTackle, .rightTackle, .rightEnd,
                    .willLB, .mikeLB, .samLB,
                    .leftCorner, .freeSafety, .strongSafety, .rightCorner
                ]
                let defRoutes: [DefensiveRoute] = decodedRoutes.enumerated().compactMap { index, route in
                    let pos = index < defPositions.count ? defPositions[index] : .mikeLB
                    let assignment: DefensiveAssignment = route.route == .block || route.route == .passBlock
                        ? .passRush : .zoneCoverage
                    let side: DefensiveSide = route.direction == .left ? .left
                        : route.direction == .right ? .right : .middle
                    return DefensiveRoute(position: pos, assignment: assignment, depth: route.depth, side: side)
                }

                let art = DefensivePlayArt(
                    playName: play.name,
                    formation: formation,
                    coverage: play.name,
                    assignments: defRoutes,
                    description: "Authentic DEF: \(play.name)"
                )
                print("Decoded authentic defensive art for \(play.name) with \(defRoutes.count) assignments.")
                return art
            }
        } catch {
            print("Error decoding defensive play art for \(play.name): \(error)")
        }
        return DefensivePlayArtDatabase.shared.randomDefensivePlay(for: formation)
    }
}

// Helper struct to wrap an AuthenticPlay as a PlayCall
public struct AuthenticPlayCall: PlayCall { // Made public, conforms to new PlayCall protocol
    public let play: AuthenticPlayDefinition // Corrected type

    public var name: String { return play.name }
    public var playType: PlayType {
        switch play.category {
        case .run: return .insideRun
        case .pass: return .shortPass
        case .screen: return .screen
        case .draw: return .draw
        case .playAction: return .playAction
        case .specialTeams:
            let upper = play.name.uppercased()
            if upper.contains("KICK") { return .kickoff }
            if upper.contains("PUNT") { return .punt }
            return .fieldGoal
        case .unknown: return .insideRun
        }
    }
    public var formation: OffensiveFormation {
        // Map the UInt16 formationCode from AuthenticPlayDefinition to OffensiveFormation
        // Access static helper from GameViewModel
        return OffensiveFormation.fromPrfFormationCode(play.formationCode) // Now static
    }
    public var isAudible: Bool { return false } // Authentic plays are not audibles
    public var displayName: String { return play.name }
}

// Helper struct to wrap an AuthenticPlay as a DefensiveCall
public struct AuthenticDefensiveCall: DefensiveCall {
    public let play: AuthenticPlayDefinition

    public var formation: DefensiveFormation {
        DefensiveFormation.fromPrfFormationCode(play.formationCode)
    }
    public var coverage: PlayType {
        // Infer coverage from formation
        switch formation {
        case .dime, .prevent: return .coverFour
        case .nickel: return .coverThree
        default: return .coverTwo
        }
    }
    public var isBlitzing: Bool {
        let upper = play.name.uppercased()
        return upper.contains("BL") || upper.contains("BLITZ") || upper.contains("FIRE")
    }
    public var blitzTarget: Position? { nil }
    public var displayName: String { play.name }
}