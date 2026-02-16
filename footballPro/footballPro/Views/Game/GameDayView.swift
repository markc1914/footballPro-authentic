//
//  GameDayView.swift
//  footballPro
//
//  Main game interface — ZStack state machine driven by GamePhase
//

import SwiftUI
import SwiftData

struct GameDayView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let game = viewModel.game {
                // State machine: show the right screen for the current phase
                switch viewModel.currentPhase {
                case .pregameNarration:
                    PregameNarrationView(viewModel: viewModel)

                case .playCalling:
                    FPSPlayCallingScreen(viewModel: viewModel)

                case .presnap:
                    ZStack {
                        FPSFieldView(viewModel: viewModel)
                        // Pre-snap situation text box (FPS '93 style)
                        FPSPresnapSituationBox(viewModel: viewModel)
                    }

                case .playAnimation:
                    ZStack {
                        FPSFieldView(viewModel: viewModel)
                        // VCR toolbar at top during play animation (FPS '93 style)
                        FPSVCRToolbar(viewModel: viewModel)
                    }

                case .playResult:
                    ZStack {
                        FPSFieldView(viewModel: viewModel)
                        FPSPlayResultOverlay(viewModel: viewModel)
                    }

                case .refereeCall(let message):
                    ZStack {
                        FPSFieldView(viewModel: viewModel)
                        FPSRefereeOverlay(message: message) {
                            viewModel.continueAfterResult()
                        }
                    }

                case .specialResult(let text):
                    ZStack {
                        Color.black.ignoresSafeArea()
                        Text(text)
                            .font(RetroFont.score())
                            .foregroundColor(VGA.digitalAmber)
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                    }

                case .extraPointChoice:
                    ZStack {
                        Color.black.ignoresSafeArea()
                        FPSDialog("TOUCHDOWN!") {
                            VStack(spacing: 16) {
                                Spacer().frame(height: 8)
                                Text("\(viewModel.possessionTeamName) scored!")
                                    .font(RetroFont.header())
                                    .foregroundColor(VGA.digitalAmber)
                                FPSButton("KICK EXTRA POINT") {
                                    Task { await viewModel.kickExtraPoint() }
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

                case .paused:
                    ZStack {
                        Color.black.ignoresSafeArea()
                        PauseMenuView(viewModel: viewModel)
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
            } else {
                Text("No game loaded")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.digitalAmber)
            }
        }
        .onAppear {
            setupGame()
        }
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
                    .padding(.bottom, 50)
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

    var body: some View {
        VStack {
            HStack(spacing: 2) {
                vcrButton("EJECT") { }
                vcrButton("STOP") { }
                vcrButton("#") { }  // Numbers toggle
                vcrButton("BALL") { }  // Follow ball
                vcrButton("CAM") { }   // Camera select

                Spacer().frame(width: 8)

                vcrButton("<<") { }   // Fast reverse
                vcrButton("<") { }    // Reverse
                vcrButton("||") { }   // Pause
                vcrButton(">") { }    // Play
                vcrButton(">>") { }   // Fast forward
                vcrButton("SLO") { }  // Slow motion
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.panelVeryDark.opacity(0.85))

            Spacer()
        }
    }

    private func vcrButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(RetroFont.tiny())
                .foregroundColor(.white)
                .frame(width: 36, height: 22)
                .background(VGA.buttonBg)
                .overlay(
                    Rectangle()
                        .stroke(VGA.buttonHighlight, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    GameDayView()
        .environmentObject(GameState())
        .environmentObject(InputManager())
}
