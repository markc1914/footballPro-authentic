//
//  GameDayView.swift
//  footballPro
//
//  Main game interface — ZStack state machine driven by GamePhase
//

import SwiftUI
import SwiftData
import AppKit

struct GameDayView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = GameViewModel()
    @State private var ballImage: CGImage?   // BALL.SCR — football graphic for FG/PAT
    @State private var kickImage: CGImage?   // KICK.SCR — kicking scene for punt/kickoff

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let game = viewModel.game {
                // State machine: show the right screen for the current phase
                switch viewModel.currentPhase {
                case .pregameNarration:
                    PregameNarrationView(viewModel: viewModel)

                case .coinToss:
                    CoinTossView(viewModel: viewModel)

                case .playCalling:
                    FPSPlayCallingScreen(viewModel: viewModel)

                case .presnap:
                    ZStack {
                        FPSFieldView(viewModel: viewModel)
                        FPSVCRToolbar(viewModel: viewModel)
                        // Pre-snap situation text box (FPS '93 style)
                        FPSPresnapSituationBox(viewModel: viewModel)
                        // Audible flash text (appears when arrow key is pressed)
                        if let audibleText = viewModel.audibleCalledText {
                            FPSAudibleFlash(text: audibleText)
                        }
                    }
                    .onKeyPress(.upArrow) {
                        if viewModel.isUserPossession {
                            viewModel.callOffensiveAudible(direction: .up)
                        } else {
                            viewModel.callDefensiveAudible(direction: .up)
                        }
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        if viewModel.isUserPossession {
                            viewModel.callOffensiveAudible(direction: .down)
                        } else {
                            viewModel.callDefensiveAudible(direction: .down)
                        }
                        return .handled
                    }
                    .onKeyPress(.leftArrow) {
                        if viewModel.isUserPossession {
                            viewModel.callOffensiveAudible(direction: .left)
                        } else {
                            viewModel.callDefensiveAudible(direction: .left)
                        }
                        return .handled
                    }
                    .onKeyPress(.rightArrow) {
                        if viewModel.isUserPossession {
                            viewModel.callOffensiveAudible(direction: .right)
                        } else {
                            viewModel.callDefensiveAudible(direction: .right)
                        }
                        return .handled
                    }
                    // Camera controls during pre-snap
                    .onKeyPress(characters: .init(charactersIn: "cC")) { _ in viewModel.cycleCamera(); return .handled }
                    .onKeyPress(characters: .init(charactersIn: "oO")) { _ in viewModel.toggleOverhead(); return .handled }
                    .onKeyPress(characters: .init(charactersIn: "=+")) { _ in viewModel.zoomIn(); return .handled }
                    .onKeyPress(characters: .init(charactersIn: "-")) { _ in viewModel.zoomOut(); return .handled }

                case .playAnimation:
                    ZStack {
                        FPSFieldView(viewModel: viewModel)
                        // VCR toolbar at top during play animation (FPS '93 style)
                        FPSVCRToolbar(viewModel: viewModel)
                        // Control mode indicator (bottom-left, near player silhouette)
                        PlayerControlModeIndicator(controlState: viewModel.playerControl)
                        // Receiver indicators when in passing mode
                        if viewModel.playerControl.mode == .passingMode {
                            PassingModeHUD(controlState: viewModel.playerControl)
                        }
                    }
                    .focusable()
                    .overlay(
                        PlayAnimationKeyHandler(viewModel: viewModel)
                            .frame(width: 0, height: 0)
                    )

                case .playResult:
                    ZStack {
                        FPSFieldView(viewModel: viewModel)
                        FPSVCRToolbar(viewModel: viewModel)
                        FPSPlayResultOverlay(viewModel: viewModel)
                    }

                case .refereeCall(let message):
                    ZStack {
                        FPSFieldView(viewModel: viewModel)
                        FPSVCRToolbar(viewModel: viewModel)
                        FPSRefereeOverlay(message: message) {
                            viewModel.continueAfterResult()
                        }
                    }

                case .specialResult(let text):
                    ZStack {
                        Color.black.ignoresSafeArea()

                        // BALL.SCR background for field goal / extra point results
                        if isKickingResult(text), let bg = ballImage {
                            Image(decorative: bg, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .opacity(0.4)
                        }

                        // KICK.SCR background for punt results
                        if isPuntResult(text), let bg = kickImage {
                            Image(decorative: bg, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .opacity(0.4)
                        }

                        Text(text)
                            .font(RetroFont.score())
                            .foregroundColor(VGA.digitalAmber)
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                    }

                case .extraPointChoice:
                    ZStack {
                        Color.black.ignoresSafeArea()

                        // BALL.SCR background for extra point choice
                        if let bg = ballImage {
                            Image(decorative: bg, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .opacity(0.35)
                        }

                        FPSDialog("TOUCHDOWN!") {
                            VStack(spacing: 16) {
                                Spacer().frame(height: 8)
                                Text("\(viewModel.possessionTeamName) scored!")
                                    .font(RetroFont.header())
                                    .foregroundColor(VGA.digitalAmber)
                                FPSButton("KICK EXTRA POINT") {
                                    viewModel.startKickingMinigame(.extraPoint)
                                }
                                FPSButton("GO FOR TWO") {
                                    Task { await viewModel.attemptTwoPointConversion() }
                                }
                                Spacer().frame(height: 8)
                            }
                            .padding(24)
                        }
                    }

                case .halftime:
                    ZStack {
                        Color.black.ignoresSafeArea()
                        FPSDialog("HALFTIME") {
                            VStack(spacing: 16) {
                                HStack(spacing: 24) {
                                    VStack(spacing: 4) {
                                        Text(viewModel.awayTeam?.abbreviation ?? "AWY")
                                            .font(RetroFont.header())
                                            .foregroundColor(VGA.lightGray)
                                        Text("\(game.score.awayScore)")
                                            .font(RetroFont.score())
                                            .foregroundColor(VGA.digitalAmber)
                                    }
                                    Text("-")
                                        .font(RetroFont.huge())
                                        .foregroundColor(VGA.darkGray)
                                    VStack(spacing: 4) {
                                        Text(viewModel.homeTeam?.abbreviation ?? "HME")
                                            .font(RetroFont.header())
                                            .foregroundColor(VGA.lightGray)
                                        Text("\(game.score.homeScore)")
                                            .font(RetroFont.score())
                                            .foregroundColor(VGA.digitalAmber)
                                    }
                                }
                                FPSButton("START 2ND HALF") {
                                    viewModel.startSecondHalf()
                                    viewModel.transitionTo(.playCalling)
                                }
                            }
                            .padding(24)
                        }
                    }

                case .gameOver:
                    GameOverView(
                        homeTeam: viewModel.homeTeam,
                        awayTeam: viewModel.awayTeam,
                        game: game,
                        isChampionship: isCurrentGameChampionship,
                        onContinue: {
                            recordGameResult()
                            gameState.currentScreen = .season
                        }
                    )

                case .replay:
                    ZStack {
                        FPSFieldView(viewModel: viewModel)
                        FPSReplayControls(viewModel: viewModel) {
                            viewModel.exitReplay()
                        }
                    }

                case .kicking(let kickType):
                    ZStack {
                        FPSFieldView(viewModel: viewModel)
                        FPSKickingView(viewModel: viewModel, kickType: kickType) { angle, aimOffset in
                            viewModel.completeKick(type: kickType, angle: angle, aimOffset: aimOffset)
                        }
                    }

                case .paused:
                    ZStack {
                        Color.black.ignoresSafeArea()
                        PauseMenuView(viewModel: viewModel)
                    }

                case .kicking(let kickType):
                    FPSKickingView(viewModel: viewModel, kickType: kickType) { angle, aim in
                        // Kick result handled by FPSKickingView internally
                    }
                }

                // Game Over detection (auto-transition)
                if game.gameStatus == .final && viewModel.currentPhase != .gameOver {
                    Color.clear.onAppear {
                        viewModel.transitionTo(.gameOver)
                    }
                }

                // Halftime detection (auto-transition)
                if game.gameStatus == .halftime && viewModel.currentPhase != .halftime &&
                   viewModel.currentPhase != .paused {
                    Color.clear.onAppear {
                        viewModel.transitionTo(.halftime)
                    }
                }

                // Game Settings overlay (F1 key)
                if viewModel.showGameSettings {
                    FPSGameSettingsView(viewModel: viewModel) {
                        viewModel.showGameSettings = false
                    }
                }
            } else {
                Text("No game loaded")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.digitalAmber)
            }
        }
        .onAppear {
            setupGame()
            loadKickingScreens()
        }
        .overlay(
            F1KeyHandler(viewModel: viewModel)
                .frame(width: 0, height: 0)
        )
    }

    private var isCurrentGameChampionship: Bool {
        guard let game = viewModel.game,
              let season = gameState.currentSeason else { return false }
        return season.schedule.first(where: {
            $0.homeTeamId == game.homeTeamId &&
            $0.awayTeamId == game.awayTeamId &&
            $0.week == game.week
        })?.playoffRound == .championship
    }

    private func recordGameResult() {
        guard let game = viewModel.game,
              var season = gameState.currentSeason,
              let userTeam = gameState.userTeam else { return }

        guard let scheduledGame = season.schedule.first(where: {
            $0.homeTeamId == game.homeTeamId &&
            $0.awayTeamId == game.awayTeamId &&
            $0.week == game.week
        }) else { return }

        let result = GameResult(
            homeScore: game.score.homeScore,
            awayScore: game.score.awayScore,
            homeTeamStats: game.homeTeamStats,
            awayTeamStats: game.awayTeamStats,
            winnerId: game.score.homeScore > game.score.awayScore ? game.homeTeamId :
                     game.score.awayScore > game.score.homeScore ? game.awayTeamId : nil,
            loserId: game.score.homeScore > game.score.awayScore ? game.awayTeamId :
                    game.score.awayScore > game.score.homeScore ? game.homeTeamId : nil
        )

        season.recordGameResult(gameId: scheduledGame.id, result: result)

        let currentWeekGames = season.schedule.filter { $0.week == season.currentWeek }
        let completedGames = currentWeekGames.filter { $0.result != nil }
        if completedGames.count == currentWeekGames.count {
            season.advanceWeek()
        }

        gameState.currentSeason = season
        gameState.userTeam = gameState.currentLeague?.teams.first { $0.id == userTeam.id }
        gameState.autoSave(modelContext: modelContext)
    }

    /// Check if specialResult text relates to a field goal or extra point attempt.
    private func isKickingResult(_ text: String) -> Bool {
        let upper = text.uppercased()
        return upper.contains("FIELD GOAL") || upper.contains("EXTRA POINT")
    }

    /// Check if specialResult text relates to a punt.
    private func isPuntResult(_ text: String) -> Bool {
        let upper = text.uppercased()
        return upper.contains("PUNT")
    }

    /// Load BALL.SCR and KICK.SCR from game files (TTM subdirectory).
    private func loadKickingScreens() {
        let gameDir = SCRDecoder.defaultDirectory

        // BALL.SCR — try TTM subdirectory first, then main directory
        if let scr = try? SCRDecoder.decode(at: gameDir.appendingPathComponent("TTM/BALL.SCR")),
           let pal = PALDecoder.loadPalette(named: "GAMINTRO.PAL") {
            ballImage = scr.cgImage(palette: pal)
        } else if let scr = SCRDecoder.load(named: "BALL.SCR"),
                  let pal = PALDecoder.loadPalette(named: "GAMINTRO.PAL") {
            ballImage = scr.cgImage(palette: pal)
        }

        // KICK.SCR — try TTM subdirectory first, then main directory
        if let scr = try? SCRDecoder.decode(at: gameDir.appendingPathComponent("TTM/KICK.SCR")),
           let pal = PALDecoder.loadPalette(named: "GAMINTRO.PAL") {
            kickImage = scr.cgImage(palette: pal)
        } else if let scr = SCRDecoder.load(named: "KICK.SCR"),
                  let pal = PALDecoder.loadPalette(named: "GAMINTRO.PAL") {
            kickImage = scr.cgImage(palette: pal)
        }
    }

    private func setupGame() {
        guard let league = gameState.currentLeague,
              let userTeam = gameState.userTeam,
              let season = gameState.currentSeason,
              let nextGame = season.nextGame(for: userTeam.id) else { return }

        let homeTeam = league.team(withId: nextGame.homeTeamId)!
        let awayTeam = league.team(withId: nextGame.awayTeamId)!

        viewModel.setupGame(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            week: nextGame.week,
            seasonYear: season.year,
            userTeamId: userTeam.id,
            quarterMinutes: gameState.quarterLength.rawValue
        )
    }
}

// MARK: - Pause Menu (FPS '93 Style)

struct PauseMenuView: View {
    @ObservedObject var viewModel: GameViewModel
    @EnvironmentObject var gameState: GameState
    @Environment(\.modelContext) private var modelContext
    @State private var showSaveConfirmation = false
    @State private var saveError: String?

    var body: some View {
        FPSDialog("GAME PAUSED") {
            VStack(spacing: 12) {
                Spacer().frame(height: 8)

                FPSButton("RESUME", width: 200) {
                    viewModel.togglePause()
                }

                FPSButton("SAVE GAME", width: 200) {
                    saveGame()
                }

                if showSaveConfirmation {
                    Text("GAME SAVED!")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.green)
                }

                if let error = saveError {
                    Text("SAVE FAILED: \(error)")
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.brightRed)
                        .lineLimit(2)
                }

                FPSButton("QUIT TO MENU", width: 200) {
                    gameState.navigateTo(.mainMenu)
                }

                Spacer().frame(height: 8)
            }
            .padding()
        }
    }

    private func saveGame() {
        guard let league = gameState.currentLeague,
              let season = gameState.currentSeason,
              let userTeam = gameState.userTeam else {
            saveError = "NO ACTIVE GAME"
            return
        }

        do {
            let saveService = SaveGameService(modelContext: modelContext)
            try saveService.quickSave(league: league, season: season, userTeamId: userTeam.id)
            showSaveConfirmation = true
            saveError = nil

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showSaveConfirmation = false
            }
        } catch {
            saveError = error.localizedDescription.uppercased()
            showSaveConfirmation = false
        }
    }
}

// MARK: - Game Over View (FPS '93 Style)

struct GameOverView: View {
    let homeTeam: Team?
    let awayTeam: Team?
    let game: Game
    var isChampionship: Bool = false
    let onContinue: () -> Void

    @State private var champImage: CGImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // CHAMP.SCR background for championship games
            if isChampionship, let bg = champImage {
                Image(decorative: bg, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.4)
            }

            FPSDialog(isChampionship ? "CHAMPIONS!" : "FINAL SCORE") {
                VStack(spacing: 16) {
                    Spacer().frame(height: 8)

                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text(awayTeam?.abbreviation ?? "AWAY")
                                .font(RetroFont.header())
                                .foregroundColor(VGA.lightGray)
                            Text("\(game.score.awayScore)")
                                .font(RetroFont.score())
                                .foregroundColor(game.score.awayScore > game.score.homeScore ? VGA.green : VGA.white)
                        }

                        Text("-")
                            .font(RetroFont.huge())
                            .foregroundColor(VGA.darkGray)

                        VStack(spacing: 4) {
                            Text(homeTeam?.abbreviation ?? "HOME")
                                .font(RetroFont.header())
                                .foregroundColor(VGA.lightGray)
                            Text("\(game.score.homeScore)")
                                .font(RetroFont.score())
                                .foregroundColor(game.score.homeScore > game.score.awayScore ? VGA.green : VGA.white)
                        }
                    }

                    if let winner = game.score.homeScore > game.score.awayScore ? homeTeam : awayTeam {
                        Text(isChampionship ? "\(winner.fullName) ARE CHAMPIONS!" : "\(winner.fullName) WIN!")
                            .font(RetroFont.title())
                            .foregroundColor(isChampionship ? VGA.yellow : VGA.digitalAmber)
                    } else if game.score.isTied {
                        Text("TIE GAME")
                            .font(RetroFont.title())
                            .foregroundColor(VGA.orange)
                    }

                    Spacer().frame(height: 8)

                    FPSButton("CONTINUE TO SEASON") {
                        onContinue()
                    }

                    Spacer().frame(height: 8)
                }
                .padding(24)
            }
        }
        .onAppear {
            if isChampionship {
                loadChampBackground()
            }
        }
    }

    private func loadChampBackground() {
        if let scr = SCRDecoder.load(named: "CHAMP.SCR"),
           let pal = PALDecoder.loadPalette(named: "CHAMP.PAL") {
            champImage = scr.cgImage(palette: pal)
        }
    }
}

// MARK: - Play Type Button (legacy compat)

struct PlayTypeButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        FPSButton(title, action: action)
    }
}

// MARK: - Pre-game Narration with GAMINTRO.SCR Background

struct PregameNarrationView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var backgroundImage: CGImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // GAMINTRO.SCR background (helmet matchup screen)
            if let bg = backgroundImage {
                Image(decorative: bg, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .opacity(0.5)
            }

            // Narration text and button overlaid
            VStack(spacing: 24) {
                Spacer()
                Text(viewModel.narrationText)
                    .font(RetroFont.body())
                    .foregroundColor(VGA.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
                    .shadow(color: .black, radius: 2, x: 1, y: 1)
                Spacer()
                FPSButton("START GAME") {
                    viewModel.startGameAfterNarration()
                }
                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            loadBackground()
        }
    }

    private func loadBackground() {
        if let scr = SCRDecoder.load(named: "GAMINTRO.SCR"),
           let pal = PALDecoder.loadPalette(named: "GAMINTRO.PAL") {
            backgroundImage = scr.cgImage(palette: pal)
        }
    }
}

// MARK: - Pre-Snap Situation Text Box (FPS '93 style — dark charcoal overlay on field)

struct FPSPresnapSituationBox: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        if let game = viewModel.game {
            VStack {
                Spacer()

                Text(situationText(game: game))
                    .font(RetroFont.body())
                    .foregroundColor(VGA.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 480)
                    .background(VGA.panelVeryDark.opacity(0.88))
                    .modifier(DOSPanelBorder(.raised, width: 1))

                Spacer()
            }
        }
    }

    private func situationText(game: Game) -> String {
        let teamName = viewModel.possessionTeamName
        let yardDesc = game.fieldPosition.displayYardLine.lowercased()
        let down = game.downAndDistance.displayDownAndDistance
        let timeLeft = game.clock.displayTime
        let qtr: String
        switch game.clock.quarter {
        case 1: qtr = "first"
        case 2: qtr = "second"
        case 3: qtr = "third"
        case 4: qtr = "fourth"
        default: qtr = "overtime"
        }
        return "\(teamName)'s ball on the \(yardDesc) yard line. \(down) to go. \(timeLeft) left in the \(qtr) quarter."
    }
}

// MARK: - VCR Toolbar (Red icon bar at top during play animation, FPS '93 style)

struct FPSVCRToolbar: View {
    @ObservedObject var viewModel: GameViewModel

    /// Whether the play animation is currently running (highlights the Play button)
    private var isPlaying: Bool {
        if case .playAnimation = viewModel.currentPhase { return true }
        return false
    }

    var body: some View {
        VStack {
            HStack(spacing: 1) {
                // Utility group (green buttons)
                vcrButton("\u{25B3}", isGreen: true) { }       // Eject
                vcrButton("\u{25A0}", isGreen: false) { }      // Stop
                vcrButton("#", isGreen: true) { }               // Numbers toggle
                vcrButton("\u{25CF}", isGreen: true) { }       // Ball follow
                vcrButton("C", isGreen: true) { }               // Camera

                Spacer().frame(width: 4)

                // Transport group (red buttons, Play highlighted green when active)
                vcrButton("\u{25C0}\u{25C0}", isGreen: false) { }  // Rewind
                vcrButton("\u{25C0}", isGreen: false) { }           // Step back
                vcrButton("||", isGreen: false) { }                  // Pause
                vcrButton("\u{25B6}", isGreen: isPlaying) { }       // Play
                vcrButton("\u{25B6}\u{25B6}", isGreen: false) { }  // Fast forward
                vcrButton("SLO", isGreen: false) { }                // Slow
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(VGA.panelVeryDark.opacity(0.85))

            Spacer()
        }
    }

    private func vcrButton(_ label: String, isGreen: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 24, height: 18)
                .background(isGreen ? VGA.playSlotGreen : VGA.buttonBg)
                .overlay(
                    Rectangle()
                        .stroke(VGA.buttonHighlight, lineWidth: 0.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Audible Flash Overlay (FPS '93 style — flashes on field when audible is called)

struct FPSAudibleFlash: View {
    let text: String

    @State private var opacity: Double = 1.0

    var body: some View {
        VStack {
            Text(text)
                .font(RetroFont.header())
                .foregroundColor(VGA.digitalAmber)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(VGA.panelVeryDark.opacity(0.9))
                .modifier(DOSPanelBorder(.raised, width: 1))
                .opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                opacity = 0.0
            }
        }
    }
}

// MARK: - Play Animation Key Handler (NSEvent-based for proper key up/down tracking)

struct PlayAnimationKeyHandler: NSViewRepresentable {
    @ObservedObject var viewModel: GameViewModel

    func makeNSView(context: Context) -> PlayAnimationKeyView {
        let view = PlayAnimationKeyView()
        view.viewModel = viewModel
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: PlayAnimationKeyView, context: Context) {
        nsView.viewModel = viewModel
    }
}

class PlayAnimationKeyView: NSView {
    weak var viewModel: GameViewModel?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let vm = viewModel else { return }
        // Prevent key repeat for action buttons
        let isRepeat = event.isARepeat

        switch event.keyCode {
        // Arrow keys
        case 126: vm.playerControl.movement.up = true       // Up
        case 125: vm.playerControl.movement.down = true     // Down
        case 123: vm.playerControl.movement.left = true     // Left
        case 124: vm.playerControl.movement.right = true    // Right
        // WASD
        case 13: vm.playerControl.movement.up = true        // W
        case 1:  vm.playerControl.movement.down = true      // S
        case 0:  vm.playerControl.movement.left = true      // A
        case 2:  vm.playerControl.movement.right = true     // D
        // Space (action) — no repeat
        case 49:
            if !isRepeat { vm.handleActionButton() }
        // X (secondary) — no repeat
        case 7:
            if !isRepeat { vm.handleSecondaryButton() }
        // Tab — switch defender
        case 48:
            if !isRepeat {
                if let bp = vm.currentAnimationBlueprint {
                    let ballPos = bp.ballPath.flatPosition(
                        at: 0.5,
                        offensivePaths: bp.offensivePaths,
                        defensivePaths: bp.defensivePaths
                    )
                    vm.switchToNearestDefender(
                        ballPosition: ballPos,
                        defensivePaths: bp.defensivePaths,
                        progress: 0.5
                    )
                }
            }
        // Number keys 1-5 for throwing
        case 18: if !isRepeat { vm.handleThrowToReceiver(1) }
        case 19: if !isRepeat { vm.handleThrowToReceiver(2) }
        case 20: if !isRepeat { vm.handleThrowToReceiver(3) }
        case 21: if !isRepeat { vm.handleThrowToReceiver(4) }
        case 23: if !isRepeat { vm.handleThrowToReceiver(5) }
        // Camera controls (FPS '93 original game settings)
        case 8:  if !isRepeat { vm.cycleCamera() }           // C — cycle camera angle
        case 31: if !isRepeat { vm.toggleOverhead() }         // O — toggle overhead view
        case 24: vm.zoomIn()                                   // + / = key
        case 27: vm.zoomOut()                                  // - key
        default:
            break
        }
    }

    override func keyUp(with event: NSEvent) {
        guard let vm = viewModel else { return }

        switch event.keyCode {
        // Arrow keys
        case 126: vm.playerControl.movement.up = false
        case 125: vm.playerControl.movement.down = false
        case 123: vm.playerControl.movement.left = false
        case 124: vm.playerControl.movement.right = false
        // WASD
        case 13: vm.playerControl.movement.up = false
        case 1:  vm.playerControl.movement.down = false
        case 0:  vm.playerControl.movement.left = false
        case 2:  vm.playerControl.movement.right = false
        default:
            break
        }
    }
}

// MARK: - Player Control Mode Indicator (bottom-left HUD during play animation)

struct PlayerControlModeIndicator: View {
    @ObservedObject var controlState: PlayerControlState

    private var modeText: String {
        switch controlState.mode {
        case .none: return ""
        case .quarterback: return "QB CONTROL"
        case .ballCarrier: return "BALL CARRIER"
        case .defender: return "DEFENSE"
        case .passingMode: return "PASSING MODE"
        }
    }

    private var hintText: String {
        switch controlState.mode {
        case .none: return ""
        case .quarterback: return "WASD:Move  SPACE:Pass Mode  1-5:Throw"
        case .ballCarrier: return "WASD:Run  SPACE:Dive  X:Stiff Arm"
        case .defender: return "WASD:Move  SPACE:Tackle  TAB:Switch"
        case .passingMode: return "SPACE:Cycle  1-5:Throw to WR"
        }
    }

    var body: some View {
        if controlState.mode != .none {
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(modeText)
                            .font(RetroFont.small())
                            .foregroundColor(VGA.digitalAmber)
                        Text(hintText)
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.lightGray)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VGA.panelVeryDark.opacity(0.85))
                    .modifier(DOSPanelBorder(.raised, width: 1))

                    Spacer()
                }
                .padding(.leading, 8)
                .padding(.bottom, 36) // Above the clock displays
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Passing Mode HUD (shows receiver numbers when QB is in passing mode)

struct PassingModeHUD: View {
    @ObservedObject var controlState: PlayerControlState

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                ForEach(0..<controlState.eligibleReceiverIndices.count, id: \.self) { i in
                    let isHighlighted = i == controlState.highlightedReceiverIndex
                    Text("\(i + 1)")
                        .font(RetroFont.header())
                        .foregroundColor(isHighlighted ? VGA.digitalAmber : VGA.lightGray)
                        .frame(width: 24, height: 24)
                        .background(isHighlighted ? VGA.playSlotGreen : VGA.panelVeryDark)
                        .overlay(
                            Rectangle()
                                .stroke(isHighlighted ? VGA.digitalAmber : VGA.darkGray, lineWidth: 1.5)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(VGA.panelVeryDark.opacity(0.9))
            .modifier(DOSPanelBorder(.raised, width: 1))

            Spacer()
        }
        .padding(.top, 28) // Below VCR toolbar
        .allowsHitTesting(false)
    }
}

// MARK: - F1 Key Handler (NSEvent-based for function key detection)

struct F1KeyHandler: NSViewRepresentable {
    @ObservedObject var viewModel: GameViewModel

    func makeNSView(context: Context) -> F1KeyView {
        let view = F1KeyView()
        view.viewModel = viewModel
        return view
    }

    func updateNSView(_ nsView: F1KeyView, context: Context) {
        nsView.viewModel = viewModel
    }
}

class F1KeyView: NSView {
    weak var viewModel: GameViewModel?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard let vm = viewModel, !event.isARepeat else {
            super.keyDown(with: event)
            return
        }

        // F1 key = keyCode 122
        if event.keyCode == 122 {
            DispatchQueue.main.async {
                vm.showGameSettings.toggle()
            }
            return
        }

        super.keyDown(with: event)
    }
}

#Preview {
    GameDayView()
        .environmentObject(GameState())
        .environmentObject(InputManager())
}
