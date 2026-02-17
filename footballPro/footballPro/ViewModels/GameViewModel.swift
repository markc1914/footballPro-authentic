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
    case pregameNarration     // Pre-game intro text from GAMINTRO.DAT
    case coinToss             // Coin toss before opening kickoff
    case playCalling          // Full-screen play calling grid
    case presnap              // Brief pre-snap field view
    case playAnimation        // Full-screen field during play
    case playResult           // Result overlay ON the field
    case refereeCall(String)  // Referee overlay with message
    case specialResult(String) // Drive result (TD, turnover overlay)
    case extraPointChoice     // TD scored — kick PAT or go for 2?
    case halftime             // Halftime display
    case gameOver             // Final score
    case replay               // Instant replay of last play
    case paused               // Pause menu overlay
    case kicking(KickType)    // Kicking minigame (angle + aim bars)
}

// MARK: - Camera Angle (FPS '93 original view options)

public enum CameraAngle: String, CaseIterable {
    case behindOffense = "BEHIND OFFENSE"
    case behindDefense = "BEHIND DEFENSE"
    case sideRight = "SIDE RIGHT"
    case sideLeft = "SIDE LEFT"
    case overhead = "OVERHEAD"
    case behindHome = "BEHIND HOME"
    case behindVisiting = "BEHIND VISITING"
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
    @Published public var narrationText: String = "" // Pre-game narration from GAMINTRO.DAT
    @Published public var playClockSeconds: Int = 25 // Play clock countdown (25 or 40 seconds)
    @Published public var selectedCelebration: String = "EZSPIKE" // Current TD celebration animation

    // Coin toss state
    @Published public var coinTossResult: CoinTossResult?
    /// Whether the current kickoff is the opening kickoff (vs post-score)
    @Published public var isOpeningKickoff: Bool = false

    // In-game settings overlay (F1 key)
    @Published public var showGameSettings = false

    // Phase before pause was entered (to restore on resume)
    private var phaseBeforePause: GamePhase = .playCalling

    private let simulationEngine = SimulationEngine()
    private let aiCoach = AICoach()

    // Track which team the user controls
    private var userTeamId: UUID?

    // New: Authentic Playbook Loader and stored plays
    private var authenticOffensivePlaybook: [AuthenticPlayDefinition] = []
    private var authenticDefensivePlaybook: [AuthenticPlayDefinition] = []

    // Audible system (FPS '93 arrow-key play changes at line of scrimmage)
    @Published public var offensiveAudibles: AudibleSet = .empty
    @Published public var defensiveAudibles: AudibleSet = .empty
    @Published public var audibleCalledText: String? = nil  // Flash text when audible is called

    // Camera system (FPS '93 original has 11 camera angles + zoom)
    @Published var cameraAngle: CameraAngle = .behindOffense
    @Published var zoomLevel: CGFloat = 1.0
    @Published var cameraAngleFlashText: String? = nil

    // Animation state (moved out of FPSFieldView)
    @Published var offAnimStates: [PlayerAnimationState] = Array(repeating: PlayerAnimationState(), count: 11)
    @Published var defAnimStates: [PlayerAnimationState] = Array(repeating: PlayerAnimationState(), count: 11)
    @Published var cameraFocusX: CGFloat = 320

    // On-field player control state
    @Published public var playerControl = PlayerControlState()

    /// Whether the play animation is waiting for user (e.g. QB hasn't thrown yet)
    @Published public var playAnimationHeld: Bool = false

    /// Signal from player control that the play should end early (user-initiated throw completed, etc.)
    @Published public var userEndedPlay: Bool = false

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
        applyTeamColors()
        buildDefaultAudibles()

        // Set default coaching profiles for AI opponent
        setupAICoachingProfiles()

        simulationEngine.startGame()
        self.game = simulationEngine.currentGame

        // Generate pre-game narration from authentic GAMINTRO.DAT
        if let narration = GameIntroDecoder.randomIntro(
            homeCity: homeTeam.city,
            homeMascot: homeTeam.name,
            homeCoach: homeTeam.coachName,
            homeRecord: "0-0",
            awayCity: awayTeam.city,
            awayMascot: awayTeam.name,
            awayCoach: awayTeam.coachName,
            awayRecord: "0-0",
            stadium: homeTeam.stadiumName
        ) {
            // Append weather conditions to narration text
            if let gw = game?.gameWeather {
                narrationText = narration + "\n\nWeather: \(gw.narrativeDescription)."
            } else {
                narrationText = narration
            }
            currentPhase = .pregameNarration
        } else {
            // No narration available — skip straight to kickoff
            Task {
                await self.executeOpeningKickoff()
            }
        }
    }

    func loadAuthenticPlaybooks() {
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

    /// Set up default coaching profiles for AI play calling
    /// Uses OFF1 (conservative) + DEF1 (conservative) by default.
    /// Can be switched via setAICoachingProfiles() before game starts.
    private func setupAICoachingProfiles() {
        let offProfile = CoachingProfileDefaults.off1
        let defProfile = CoachingProfileDefaults.def1
        aiCoach.setProfiles(offensive: offProfile, defensive: defProfile)
        print("AI coaching profiles set: \(offProfile.name) offense (\(offProfile.offensiveSituationCount) situations), \(defProfile.name) defense (\(defProfile.defensiveSituationCount) situations)")
    }

    /// Allow external callers (e.g., exhibition setup) to change the AI coaching profiles
    public func setAICoachingProfiles(offensiveName: String, defensiveName: String) {
        let allProfiles = CoachingProfileDefaults.allProfiles
        let offProfile = allProfiles.first { $0.name == offensiveName } ?? CoachingProfileDefaults.off1
        let defProfile = allProfiles.first { $0.name == defensiveName } ?? CoachingProfileDefaults.def1
        aiCoach.setProfiles(offensive: offProfile, defensive: defProfile)
    }

    /// Apply team colors to sprite cache (home = color table 1, away = color table 2)
    func applyTeamColors() {
        guard let home = homeTeam, let away = awayTeam else { return }

        func rgb(_ hex: String) -> (UInt8, UInt8, UInt8) {
            let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: cleaned).scanHexInt64(&int)
            let r, g, b: UInt64
            switch cleaned.count {
            case 3:
                (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6, 8:
                (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default:
                (r, g, b) = (0, 0, 0)
            }
            return (UInt8(r), UInt8(g), UInt8(b))
        }

        let homeColors: [(UInt8, UInt8, UInt8)] = [
            rgb(home.colors.primary),
            rgb(home.colors.secondary),
            rgb(home.colors.accent),
            rgb(home.colors.primary),
            rgb(home.colors.secondary)
        ]
        let awayColors: [(UInt8, UInt8, UInt8)] = [
            rgb(away.colors.primary),
            rgb(away.colors.secondary),
            rgb(away.colors.accent),
            rgb(away.colors.primary),
            rgb(away.colors.secondary)
        ]

        SpriteCache.shared.setTeamColors(homeColors: homeColors, awayColors: awayColors)
    }

    // MARK: - Camera Controls

    /// Cycle to the next camera angle and flash the name briefly.
    public func cycleCamera() {
        let allCases = CameraAngle.allCases
        if let idx = allCases.firstIndex(of: cameraAngle) {
            cameraAngle = allCases[(idx + 1) % allCases.count]
        } else {
            cameraAngle = .behindOffense
        }
        flashCameraName()
    }

    /// Toggle overhead view (O key shortcut).
    public func toggleOverhead() {
        if cameraAngle == .overhead {
            cameraAngle = .behindOffense
        } else {
            cameraAngle = .overhead
        }
        flashCameraName()
    }

    /// Zoom in by 0.1 (max 2.0).
    public func zoomIn() {
        zoomLevel = min(2.0, zoomLevel + 0.1)
    }

    /// Zoom out by 0.1 (min 0.5).
    public func zoomOut() {
        zoomLevel = max(0.5, zoomLevel - 0.1)
    }

    /// Resolve the effective camera orientation for the current game state.
    /// Returns whether the camera should be "behind defense" (i.e. flipped from offense view).
    public var effectiveCameraIsBehindDefense: Bool {
        switch cameraAngle {
        case .behindOffense:
            return false
        case .behindDefense:
            return true
        case .behindHome:
            // Behind home team -- if home is on offense, same as behind offense
            return !(game?.isHomeTeamPossession ?? true)
        case .behindVisiting:
            // Behind visiting team -- if away is on offense, same as behind offense
            return game?.isHomeTeamPossession ?? true
        case .sideRight, .sideLeft, .overhead:
            return false  // Side/overhead don't use behind-offense logic
        }
    }

    /// Whether the current camera is a sideline view.
    public var isSidelineCamera: Bool {
        cameraAngle == .sideRight || cameraAngle == .sideLeft
    }

    /// Whether the current camera is overhead.
    public var isOverheadCamera: Bool {
        cameraAngle == .overhead
    }

    /// Flash the camera angle name for 1.5 seconds.
    private func flashCameraName() {
        cameraAngleFlashText = cameraAngle.rawValue
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.cameraAngleFlashText = nil
        }
    }

    // MARK: - Prose Result Generator (FPS '93 authentic style)

    /// Generate continuous prose play result matching original FPS '93 format
    public func generateProseResult() -> String {
        guard let game = game, let result = lastPlayResult else { return "Play complete." }

        let possTeam = game.isHomeTeamPossession ? homeTeam : awayTeam
        let oppTeam = game.isHomeTeamPossession ? awayTeam : homeTeam
        let possCity = possTeam?.city ?? "Team"
        let oppCity = oppTeam?.city ?? "Opponent"

        var parts: [String] = []

        // 1. Play description (from SimulationEngine)
        let playDesc = result.description.hasSuffix(".") ? result.description : result.description + "."
        parts.append(playDesc)

        // 2. Possession + field position
        let yardLine = game.fieldPosition.yardLine
        if yardLine == 50 {
            parts.append("\(possCity)'s ball on the 50 yard line.")
        } else if yardLine < 50 {
            parts.append("\(possCity)'s ball on their \(yardLine) yard line.")
        } else {
            parts.append("\(possCity)'s ball on the \(oppCity) \(100 - yardLine) yard line.")
        }

        // 3. Down and distance (spelled out)
        let downWords = ["First", "Second", "Third", "Fourth"]
        let downWord = game.downAndDistance.down >= 1 && game.downAndDistance.down <= 4
            ? downWords[game.downAndDistance.down - 1] : "\(game.downAndDistance.down)th"
        let goalToGo = game.downAndDistance.lineOfScrimmage + game.downAndDistance.yardsToGo >= 100
        let distText = goalToGo ? "goal" : "\(game.downAndDistance.yardsToGo)"
        parts.append("\(downWord) and \(distText) to go.")

        // 4. Time remaining
        let quarterWords = ["first", "second", "third", "fourth"]
        let quarterWord = game.clock.quarter >= 1 && game.clock.quarter <= 4
            ? quarterWords[game.clock.quarter - 1] : "overtime"
        parts.append("\(game.clock.displayTime) left in the \(quarterWord) quarter.")

        // 5. Score
        let possScore = game.isHomeTeamPossession ? game.score.homeScore : game.score.awayScore
        let oppScore = game.isHomeTeamPossession ? game.score.awayScore : game.score.homeScore
        parts.append("The score is \(possCity) \(possScore), \(oppCity) \(oppScore).")

        return parts.joined(separator: " ")
    }

    // MARK: - AI Play Hint (for opponent grid display)

    /// Simplified hint text for the AI opponent's play (e.g., "Run left", "Goal line run")
    public var aiPlayHintText: String? {
        guard let result = lastPlayResult else { return nil }
        // Generate a simplified hint from the play type
        switch result.playType {
        case .insideRun, .draw, .counter, .qbSneak:
            return "Run middle"
        case .outsideRun, .sweep:
            return "Run left"
        case .shortPass, .screen:
            return "Short pass"
        case .mediumPass, .rollout:
            return "Pass right"
        case .deepPass:
            return "Deep pass"
        case .playAction:
            return "Play action"
        case .kneel:
            return "Kneel"
        case .spike:
            return "Spike"
        case .kickoff:
            return "Kickoff"
        case .punt:
            return "Punt"
        case .fieldGoal, .extraPoint:
            return "Field goal"
        default:
            return "Regular play"
        }
    }

    // MARK: - Kickoff Animation Pipeline

    /// Execute a kickoff with full field animation (opening or post-score)
    internal func executeKickoffWithAnimation() async {
        guard let game = game else { return }

        isSimulating = true
        defer { isSimulating = false }

        // Start crowd ambient sound on opening kickoff
        if isOpeningKickoff {
            SoundManager.shared.startCrowdAmbient()
        }
        SoundManager.shared.play(.whistle)

        // Run the simulation
        let result = await simulationEngine.executeKickoff()
        self.game = simulationEngine.currentGame
        lastPlayResult = result
        playByPlay.append(result)

        // Generate kickoff animation blueprint
        let losX: Int = 35  // Kickoff from 35-yard line
        currentAnimationBlueprint = PlayBlueprintGenerator.generateKickoffBlueprint(
            result: result,
            los: losX
        )

        // Show the field animation
        currentPhase = .playAnimation

        // Wait for the animation to complete
        try? await Task.sleep(nanoseconds: UInt64((currentAnimationBlueprint?.totalDuration ?? 4.0) * 1_000_000_000))

        // Whistle at end
        SoundManager.shared.play(.whistle)

        // Show the result overlay
        currentPhase = .playResult
        SoundManager.shared.playSoundForResult(result)

        // Handle kick return TD
        if result.isTouchdown {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await handleSpecialSituations()
        } else {
            // Normal kickoff return -- after result display, go to play calling
            // The result overlay will call continueAfterResult() when tapped
        }

        isOpeningKickoff = false
        updatePossessionStatus()
    }

    /// Legacy: silent kickoff for simulations (no animation)
    internal func executeOpeningKickoff() async {
        print("Executing opening kickoff...")
        SoundManager.shared.startCrowdAmbient()
        SoundManager.shared.play(.whistle)
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

    /// Called when user taps "START GAME" on pre-game narration screen
    public func startGameAfterNarration() {
        isOpeningKickoff = true
        currentPhase = .coinToss
    }

    /// Called after coin toss completes — user chose kick or receive
    public func startKickoffAfterCoinToss(userElectsToReceive: Bool) {
        guard let game = game else { return }

        // If user elects to receive and their team is away (default receiver), no change needed.
        // If user elects to kick, we need to swap possession so user's team kicks.
        let userIsHome = userTeamId == game.homeTeamId

        if userElectsToReceive {
            // User wants to receive: make sure user's team is the receiving team
            // In kickoff, possessingTeamId = kicking team, receiving team gets ball after
            // After executeKickoff, possession switches to receiving team
            // Currently: away team has possession (will receive after kickoff logic)
            // We need kicking team to have possession during kickoff setup
            if userIsHome {
                // User is home and wants to receive — away kicks (current: away has poss, good)
                // Actually SimulationEngine.startGame sets possessingTeamId = awayTeamId
                // and executeKickoff switches to the other team. So away "has possession" means
                // away receives. We need home to receive = away to kick.
                // Set kicking team as away (they have possession before kickoff flips it)
                simulationEngine.currentGame?.possessingTeamId = game.awayTeamId
            } else {
                // User is away and wants to receive — home kicks
                simulationEngine.currentGame?.possessingTeamId = game.homeTeamId
            }
        } else {
            // User wants to kick
            if userIsHome {
                // Home kicks — home has possession before kickoff
                simulationEngine.currentGame?.possessingTeamId = game.homeTeamId
            } else {
                // Away kicks — away has possession before kickoff
                simulationEngine.currentGame?.possessingTeamId = game.awayTeamId
            }
        }
        self.game = simulationEngine.currentGame

        Task {
            await executeKickoffWithAnimation()
        }
    }

    // MARK: - Timeout Management

    public func callTimeout() {
        guard var game = game else { return }
        let isPossessing = game.isHomeTeamPossession

        // Check if timeouts remain
        let remaining = isPossessing ? game.homeTimeouts : game.awayTimeouts
        guard remaining > 0 else { return }

        // Decrement
        if isPossessing {
            game.homeTimeouts -= 1
        } else {
            game.awayTimeouts -= 1
        }

        // Stop the clock
        game.clock.isRunning = false
        self.game = game
        simulationEngine.currentGame = game

        // Show referee call
        let teamName = isPossessing ? (homeTeam?.name ?? "Home") : (awayTeam?.name ?? "Away")
        currentPhase = .refereeCall("TIMEOUT — \(teamName)")
    }

    /// Returns remaining timeouts for the possessing team
    public var possessingTeamTimeouts: Int {
        guard let game = game else { return 3 }
        return game.isHomeTeamPossession ? game.homeTimeouts : game.awayTimeouts
    }

    // MARK: - Two-Point Conversion

    public func kickExtraPoint() async {
        await attemptExtraPoint()
    }

    public func attemptTwoPointConversion() async {
        isSimulating = true
        defer { isSimulating = false }

        let success = await simulationEngine.executeTwoPointConversion()
        let text = success ? "TWO-POINT CONVERSION IS GOOD!" : "TWO-POINT CONVERSION FAILED!"
        showDriveResult(text: text)
        self.game = simulationEngine.currentGame

        // Kickoff will be handled by handleSpecialSituations via continueAfterResult
        updatePossessionStatus()
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

            // Hike/snap sound at play start
            SoundManager.shared.play(.hike)

            try? await Task.sleep(nanoseconds: UInt64((currentAnimationBlueprint?.totalDuration ?? 3.0) * 1_000_000_000))

            // Whistle at end of play
            SoundManager.shared.play(.whistle)

            currentPhase = .playResult

            // Play result-specific sound effects (TD fanfare, turnover, big play, etc.)
            SoundManager.shared.playSoundForResult(result)
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
            // Check if user's team scored the TD
            if isUserPossession {
                // Show choice dialog — user decides PAT vs 2PT
                pickCelebration()
                currentPhase = .extraPointChoice
                return // Don't auto-advance; user will call kickExtraPoint() or attemptTwoPointConversion()
            } else {
                // AI team: auto-kick PAT (unless trailing by specific amounts late)
                let shouldGoForTwo = shouldAIAttemptTwoPoint()
                if shouldGoForTwo {
                    let success = await simulationEngine.executeTwoPointConversion()
                    let text = success ? "Two-point conversion is GOOD!" : "Two-point conversion FAILED!"
                    showDriveResult(text: text)
                } else {
                    let success = await simulationEngine.executeExtraPoint()
                    let text = success ? "Extra point is GOOD!" : "Extra point MISSED!"
                    showDriveResult(text: text)
                }
                self.game = simulationEngine.currentGame
            }
        }

        if self.game?.isKickoff == true {
            // Check if AI kicking team should attempt onside kick
            let kickSituation = currentSituation()
            let aiIsKicking = !isUserPossession
            if aiIsKicking && aiCoach.shouldAttemptOnsideKick(situation: kickSituation) {
                let kickResult = await simulationEngine.executeOnsideKick()
                self.game = simulationEngine.currentGame
                lastPlayResult = kickResult
                playByPlay.append(kickResult)
            } else {
                // Post-score kickoff with field animation
                await executeKickoffWithAnimation()
                return // executeKickoffWithAnimation handles phase transitions
            }
        }

        // Show injury notification if the last play had one
        if let result = lastPlayResult, result.description.contains("INJURY —") {
            // Extract injury text from description
            if let injuryRange = result.description.range(of: "INJURY —") {
                let injuryText = String(result.description[injuryRange.lowerBound...])
                currentPhase = .refereeCall(injuryText)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }

        if self.game?.gameStatus == .halftime {
            showDriveResult(text: "HALFTIME")
        }

        if self.game?.gameStatus == .final {
            showDriveResult(text: "FINAL")
        }
    }

    /// AI decision: go for 2 if trailing by 1, 2, 4, 5, or 8+ points in Q4
    private func shouldAIAttemptTwoPoint() -> Bool {
        guard let game = game else { return false }
        let situation = currentSituation()
        // scoreDifferential is from possessing team's perspective (negative = trailing)
        let deficit = -situation.scoreDifferential
        let isLate = game.clock.quarter >= 4

        if isLate {
            // Go for 2 when trailing by amounts where 2 pts helps more than 1
            return deficit == 2 || deficit == 5 || deficit >= 8
        }
        return false
    }

    // MARK: - Kicking Minigame

    /// Start the interactive kicking minigame for the given kick type
    public func startKickingMinigame(_ type: KickType) {
        currentPhase = .kicking(type)
    }

    /// Called when the kicking minigame completes with angle and aim values
    public func completeKick(type: KickType, angle: Double, aimOffset: Double) {
        Task {
            await executeKickWithParameters(type: type, angle: angle, aimOffset: aimOffset)
        }
    }

    /// Execute a kick using the angle/aim from the minigame
    private func executeKickWithParameters(type: KickType, angle: Double, aimOffset: Double) async {
        let aimAccuracy = 1.0 - abs(aimOffset)
        let angleDelta = abs(angle - 45.0) / 20.0
        let distanceModifier = 1.0 - (angleDelta * 0.3)

        switch type {
        case .fieldGoal:
            await attemptFieldGoalWithKick(aimAccuracy: aimAccuracy, distanceModifier: distanceModifier)
        case .extraPoint:
            await attemptExtraPointWithKick(aimAccuracy: aimAccuracy)
        case .punt:
            await puntWithKick(distanceModifier: distanceModifier)
        case .kickoff:
            await kickoffWithKick(distanceModifier: distanceModifier)
        }
    }

    private func attemptFieldGoalWithKick(aimAccuracy: Double, distanceModifier: Double) async {
        guard let game = game else { return }

        isSimulating = true
        defer { isSimulating = false }

        let distance = 100 - game.fieldPosition.yardLine + 17
        let aimThreshold = 0.3
        var success: Bool
        if aimAccuracy < aimThreshold {
            success = false
        } else {
            success = await simulationEngine.executeFieldGoal(from: game.fieldPosition.yardLine)
            if !success && aimAccuracy > 0.8 && distanceModifier > 0.9 && distance <= 45 {
                success = Double.random(in: 0...1) < 0.3
            }
        }

        let text: String
        if success {
            text = "\(distance)-yard field goal is GOOD!"
        } else if aimAccuracy < aimThreshold {
            text = "\(distance)-yard field goal is WIDE \(Double.random(in: 0...1) < 0.5 ? "LEFT" : "RIGHT")!"
        } else {
            text = "\(distance)-yard field goal is NO GOOD!"
        }

        showDriveResult(text: text)
        self.game = simulationEngine.currentGame
        updatePossessionStatus()
    }

    private func attemptExtraPointWithKick(aimAccuracy: Double) async {
        isSimulating = true
        defer { isSimulating = false }

        var success: Bool
        if aimAccuracy < 0.2 {
            success = false
        } else {
            success = await simulationEngine.executeExtraPoint()
        }

        let text = success ? "Extra point is GOOD!" : "Extra point MISSED!"
        showDriveResult(text: text)
        self.game = simulationEngine.currentGame
        updatePossessionStatus()
    }

    private func puntWithKick(distanceModifier: Double) async {
        isSimulating = true
        defer { isSimulating = false }

        let result = await simulationEngine.executePunt()
        lastPlayResult = result
        playByPlay.append(result)
        showDriveResult(text: "Punt: \(result.description)")
        self.game = simulationEngine.currentGame
        updatePossessionStatus()
    }

    private func kickoffWithKick(distanceModifier: Double) async {
        await executeKickoffWithAnimation()
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

        // Kickoff will be handled by handleSpecialSituations via continueAfterResult
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

    public func executeOnsideKick() async {
        isSimulating = true
        defer { isSimulating = false }

        let result = await simulationEngine.executeOnsideKick()
        lastPlayResult = result
        playByPlay.append(result)
        showDriveResult(text: result.description)
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
                // Check if kicking team should attempt onside kick
                let kickScoreDiff = game.isHomeTeamPossession ?
                    game.score.homeScore - game.score.awayScore :
                    game.score.awayScore - game.score.homeScore
                let kickSit = GameSituation(
                    down: 1, yardsToGo: 10, fieldPosition: 35,
                    quarter: game.clock.quarter,
                    timeRemaining: game.clock.timeRemaining,
                    scoreDifferential: kickScoreDiff,
                    isRedZone: false
                )
                if aiCoach.shouldAttemptOnsideKick(situation: kickSit) {
                    _ = await simulationEngine.executeOnsideKick()
                } else {
                    _ = await simulationEngine.executeKickoff()
                }
            } else if game.isExtraPoint {
                _ = await simulationEngine.executeExtraPoint()
            } else {
                guard let offTeam = game.isHomeTeamPossession ? homeTeam : awayTeam,
                      let defTeam = game.isHomeTeamPossession ? awayTeam : homeTeam else {
                    break
                }

                let situation = currentSituation()

                if game.downAndDistance.down == 4 {
                    let kicker = offTeam.starter(at: .kicker)
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

        let ownTimeouts = game.isHomeTeamPossession ? game.homeTimeouts : game.awayTimeouts
        let oppTimeouts = game.isHomeTeamPossession ? game.awayTimeouts : game.homeTimeouts

        return GameSituation(
            down: game.downAndDistance.down,
            yardsToGo: game.downAndDistance.yardsToGo,
            fieldPosition: game.fieldPosition.yardLine,
            quarter: game.clock.quarter,
            timeRemaining: game.clock.timeRemaining,
            scoreDifferential: game.isHomeTeamPossession ?
                game.score.homeScore - game.score.awayScore :
                game.score.awayScore - game.score.homeScore,
            isRedZone: game.fieldPosition.isRedZone,
            ownTimeouts: ownTimeouts,
            opponentTimeouts: oppTimeouts
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
        } else if game?.isKickoff == true {
            // Post-score kickoff — animate it on the field
            Task { await handleSpecialSituations() }
        } else if game?.isExtraPoint == true {
            // Extra point choice after TD
            Task { await handleSpecialSituations() }
        } else {
            // Check if AI has the ball on 4th down — auto-execute punt/FG
            if !isUserPossession, let game = game, game.downAndDistance.down == 4,
               game.gameStatus == .inProgress, !game.isKickoff, !game.isExtraPoint {
                Task { await handleAIFourthDown() }
            } else {
                resetPlayClock()
                currentPhase = .playCalling
            }
        }
    }

    /// AI 4th-down decision during interactive play: punt, FG, or go for it
    private func handleAIFourthDown() async {
        guard let game = game else {
            resetPlayClock()
            currentPhase = .playCalling
            return
        }

        let offTeam = game.isHomeTeamPossession ? homeTeam : awayTeam
        let kicker = offTeam?.starter(at: .kicker)
        let situation = currentSituation()
        let decision = aiCoach.fourthDownDecision(situation: situation, kicker: kicker)

        switch decision {
        case .punt:
            currentPhase = .refereeCall("4th down — \(offTeam?.name ?? "Offense") will punt")
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await punt()
        case .fieldGoal:
            currentPhase = .refereeCall("4th down — \(offTeam?.name ?? "Offense") will attempt a field goal")
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await attemptFieldGoal()
        case .goForIt:
            // AI goes for it — show play calling as normal
            resetPlayClock()
            currentPhase = .playCalling
        }
    }

    public func startSecondHalf() { // Made public
        simulationEngine.startSecondHalf()
        self.game = simulationEngine.currentGame
    }

    /// Reset play clock to default (25 seconds) when entering play calling
    public func resetPlayClock() {
        playClockSeconds = 25
    }

    /// Pick a random celebration for touchdown
    public func pickCelebration() {
        selectedCelebration = SpriteCache.randomCelebration()
    }

    // MARK: - On-Field Player Control

    /// Initialize player control when play animation starts.
    /// Called from FPSFieldView when animation begins.
    public func initializePlayerControl(blueprint: PlayAnimationBlueprint) {
        playerControl.reset()
        userEndedPlay = false
        playAnimationHeld = false

        if isUserPossession {
            // Find QB index (typically index 5 in offensive formation, after 5 OL)
            let qbIndex = blueprint.offensivePaths.firstIndex(where: { $0.role == .quarterback }) ?? 5

            // Find eligible receiver indices (WR, TE, RB — not OL)
            let receiverIndices = blueprint.offensivePaths.enumerated().compactMap { idx, path -> Int? in
                switch path.role {
                case .receiver, .tightend, .runningback, .runningBack, .fullback:
                    return idx
                default:
                    return nil
                }
            }

            playerControl.beginOffensiveControl(qbIndex: qbIndex, receiverIndices: receiverIndices)
        } else {
            // Defense: control nearest defender to the ball (start with first LB)
            let lbIndex = blueprint.defensivePaths.firstIndex(where: { $0.role == .linebacker }) ?? 4
            let startPos = blueprint.defensivePaths[lbIndex].position(at: 0)
            playerControl.beginDefensiveControl(nearestDefenderIndex: lbIndex, currentPosition: startPos)
        }
    }

    /// Handle Space key during play animation.
    public func handleActionButton() {
        switch playerControl.mode {
        case .quarterback:
            playerControl.enterPassingMode()
        case .passingMode:
            playerControl.cycleReceiver()
        case .ballCarrier:
            playerControl.actionPressed = true
        case .defender:
            playerControl.actionPressed = true
        case .none:
            break
        }
    }

    /// Handle X key during play animation (stiff arm / switch defender).
    public func handleSecondaryButton() {
        playerControl.secondaryPressed = true
    }

    /// Handle number key (1-5) for throwing to a receiver.
    public func handleThrowToReceiver(_ number: Int) {
        guard playerControl.mode == .passingMode || playerControl.mode == .quarterback else { return }
        let idx = number - 1  // 1-based to 0-based
        guard idx >= 0 && idx < playerControl.eligibleReceiverIndices.count else { return }
        playerControl.throwTarget = idx

        // After throw, ball carrier switches to that receiver
        let receiverPlayerIdx = playerControl.eligibleReceiverIndices[idx]
        // Delay the switch to allow the throw animation to play
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s for throw
            if playerControl.mode == .passingMode || playerControl.mode == .quarterback {
                if let blueprint = currentAnimationBlueprint {
                    let recPos = blueprint.offensivePaths[receiverPlayerIdx].position(at: 0.6)
                    playerControl.switchToBallCarrier(index: receiverPlayerIdx, currentPosition: recPos)
                }
            }
        }
    }

    /// Switch to nearest defender to ball carrier.
    public func switchToNearestDefender(ballPosition: CGPoint, defensivePaths: [AnimatedPlayerPath], progress: Double) {
        guard playerControl.mode == .defender else { return }

        var closestIdx = 0
        var closestDist = CGFloat.infinity

        for (idx, path) in defensivePaths.enumerated() {
            let pos = path.position(at: progress)
            let dx = pos.x - ballPosition.x
            let dy = pos.y - ballPosition.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < closestDist {
                closestDist = dist
                closestIdx = idx
            }
        }

        let pos = defensivePaths[closestIdx].position(at: progress)
        playerControl.switchDefender(toIndex: closestIdx, currentPosition: pos)
    }

    /// Enter instant replay mode for the last play
    public func enterReplay() {
        guard currentAnimationBlueprint != nil else { return }
        phaseBeforePause = currentPhase
        currentPhase = .replay
    }

    /// Exit instant replay and return to previous phase
    public func exitReplay() {
        currentPhase = phaseBeforePause
    }

    /// Whether the last play was a "big play" worthy of auto-replay
    public var lastPlayWasBigPlay: Bool {
        guard let result = lastPlayResult else { return false }
        let yards = abs(result.yardsGained)
        return result.isTouchdown || result.isTurnover || yards >= 20
    }

    // MARK: - Audible System (FPS '93 arrow-key play changes)

    /// Build default audibles from the current playbook, matching play types to arrow directions.
    public func buildDefaultAudibles() {
        // Offensive audibles: Up=Deep Pass, Down=Short Pass, Left=Outside Run, Right=Inside Run
        let offPlays = availableOffensivePlays
        offensiveAudibles = AudibleSet(
            up: findAudibleSlot(in: offPlays, matching: [.deepPass, .mediumPass, .playAction]),
            down: findAudibleSlot(in: offPlays, matching: [.shortPass, .screen]),
            left: findAudibleSlot(in: offPlays, matching: [.outsideRun, .sweep]),
            right: findAudibleSlot(in: offPlays, matching: [.insideRun, .draw, .counter])
        )

        // Defensive audibles: Up=Man Coverage, Down=Zone, Left=Outside Run D, Right=Inside Run D
        let defPlays = availableDefensivePlays
        defensiveAudibles = AudibleSet(
            up: findDefensiveAudibleSlot(in: defPlays, matching: [.manCoverage]),
            down: findDefensiveAudibleSlot(in: defPlays, matching: [.coverTwo, .coverThree, .coverFour]),
            left: findDefensiveAudibleSlot(in: defPlays, blitzing: false),
            right: findDefensiveAudibleSlot(in: defPlays, blitzing: true)
        )
    }

    private func findAudibleSlot(in plays: [AuthenticPlayCall], matching types: [PlayType]) -> AudibleSlot? {
        for type in types {
            if let idx = plays.firstIndex(where: { $0.playType == type }) {
                let play = plays[idx]
                return AudibleSlot(
                    playName: play.displayName,
                    playType: play.playType,
                    formationName: play.formationDisplayName,
                    playbookIndex: idx
                )
            }
        }
        return nil
    }

    private func findDefensiveAudibleSlot(in plays: [AuthenticDefensiveCall], matching types: [PlayType]) -> AudibleSlot? {
        for type in types {
            if let idx = plays.firstIndex(where: { $0.coverage == type }) {
                let play = plays[idx]
                return AudibleSlot(
                    playName: play.displayName,
                    playType: type,
                    formationName: play.formation.rawValue,
                    playbookIndex: idx
                )
            }
        }
        return nil
    }

    private func findDefensiveAudibleSlot(in plays: [AuthenticDefensiveCall], blitzing: Bool) -> AudibleSlot? {
        if let idx = plays.firstIndex(where: { $0.isBlitzing == blitzing }) {
            let play = plays[idx]
            return AudibleSlot(
                playName: play.displayName,
                playType: play.coverage,
                formationName: play.formation.rawValue,
                playbookIndex: idx
            )
        }
        return nil
    }

    /// Call an offensive audible from the pre-snap field view (arrow key direction).
    public func callOffensiveAudible(direction: AudibleDirection) {
        let slot: AudibleSlot?
        switch direction {
        case .up: slot = offensiveAudibles.up
        case .down: slot = offensiveAudibles.down
        case .left: slot = offensiveAudibles.left
        case .right: slot = offensiveAudibles.right
        }
        guard let audible = slot else { return }
        let plays = availableOffensivePlays
        guard audible.playbookIndex >= 0 && audible.playbookIndex < plays.count else { return }
        selectedOffensivePlay = plays[audible.playbookIndex]
        showAudibleFlash(audible.playName)
    }

    /// Call a defensive audible from the pre-snap field view (arrow key direction).
    public func callDefensiveAudible(direction: AudibleDirection) {
        let slot: AudibleSlot?
        switch direction {
        case .up: slot = defensiveAudibles.up
        case .down: slot = defensiveAudibles.down
        case .left: slot = defensiveAudibles.left
        case .right: slot = defensiveAudibles.right
        }
        guard let audible = slot else { return }
        let plays = availableDefensivePlays
        guard audible.playbookIndex >= 0 && audible.playbookIndex < plays.count else { return }
        selectedDefensivePlay = plays[audible.playbookIndex]
        showAudibleFlash(audible.playName)
    }

    private func showAudibleFlash(_ playName: String) {
        audibleCalledText = "AUDIBLE! \(playName)"
        SoundManager.shared.play(.hike)
        // Clear after 1.5 seconds
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if audibleCalledText?.contains(playName) == true {
                audibleCalledText = nil
            }
        }
    }

    // MARK: - Substitution System

    /// Swap a starter with a bench player at the given position on the specified team.
    /// Returns true if the substitution was successful.
    @discardableResult
    public func substitutePlayer(teamIsHome: Bool, position: Position, starterIndex: Int, replacementId: UUID) -> Bool {
        if teamIsHome {
            guard var team = homeTeam else { return false }
            team.depthChart.setStarter(replacementId, at: position)
            homeTeam = team
            return true
        } else {
            guard var team = awayTeam else { return false }
            team.depthChart.setStarter(replacementId, at: position)
            awayTeam = team
            return true
        }
    }

    /// Get the current starters and backups for the user's team, grouped by position.
    public var userTeamForSubstitution: Team? {
        guard let game = game, let uid = userTeamId else { return nil }
        if game.homeTeamId == uid { return homeTeam }
        return awayTeam
    }

    /// Whether the user's team is home
    public var isUserHome: Bool {
        guard let game = game, let uid = userTeamId else { return true }
        return game.homeTeamId == uid
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
        case .run:
            let upper = play.name.uppercased()
            if upper.contains("SW") || upper.contains("SL") || upper.contains("PI") {
                return .outsideRun
            }
            return .insideRun
        case .pass:
            let upper = play.name.uppercased()
            if upper.contains("DP") || upper.contains("FL") {
                return .deepPass
            }
            if upper.contains("OW") || upper.contains("CR") {
                return .mediumPass
            }
            return .shortPass
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
    public var displayName: String {
        return play.humanReadableName
    }
    public var formationDisplayName: String { play.formationName }
}

// MARK: - Coin Toss Result
public struct CoinTossResult {
    public let calledHeads: Bool
    public let wasHeads: Bool
    public var userWon: Bool { calledHeads == wasHeads }
    public let winnerTeamName: String
    public let loserTeamName: String
    public let winnerElectsToReceive: Bool
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
    public var displayName: String {
        let formationLabel = formation.rawValue
        return "\(formationLabel): \(play.humanReadableName)"
    }
}
