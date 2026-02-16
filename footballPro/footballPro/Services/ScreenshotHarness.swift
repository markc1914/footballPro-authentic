//
//  ScreenshotHarness.swift
//  footballPro
//
//  Orchestrator that sets up mock game state for each screen and captures it.
//  Produces 32 screenshots matching original FPS '93 reference frames at /tmp/fps_screenshots/.
//

import SwiftUI

@MainActor
struct ScreenshotHarness {

    /// Progress callback: (currentIndex, totalCount, filename)
    typealias ProgressCallback = (Int, Int, String) -> Void

    // MARK: - Mock Data Helpers

    /// Create a minimal Team for screenshot purposes (no full roster needed)
    private static func mockTeam(name: String, city: String, abbr: String, primary: String, secondary: String, stadium: String, coach: String) -> Team {
        Team(
            name: name,
            city: city,
            abbreviation: abbr,
            colors: TeamColors(primary: primary, secondary: secondary, accent: "FFFFFF"),
            stadiumName: stadium,
            coachName: coach,
            divisionId: UUID()
        )
    }

    /// Create mock teams matching the reference frames (Buffalo vs Dallas)
    private static func mockTeams() -> (home: Team, away: Team) {
        let buffalo = mockTeam(
            name: "Bills", city: "Buffalo", abbr: "BUF",
            primary: "00338D", secondary: "C60C30",
            stadium: "Rich Stadium", coach: "Marv Levy"
        )
        let dallas = mockTeam(
            name: "Cowboys", city: "Dallas", abbr: "DAL",
            primary: "003594", secondary: "869397",
            stadium: "Texas Stadium", coach: "Jimmy Johnson"
        )
        return (home: buffalo, away: dallas)
    }

    /// Configure a GameViewModel with specific game state for a screenshot
    private static func configureViewModel(
        homeTeam: Team,
        awayTeam: Team,
        phase: GamePhase,
        quarter: Int = 1,
        timeRemaining: Int = 900,
        down: Int = 1,
        yardsToGo: Int = 10,
        yardLine: Int = 25,
        homeScore: Int = 0,
        awayScore: Int = 0,
        isUserPossession: Bool = true,
        lastPlayDescription: String? = nil,
        lastPlayYards: Int = 0,
        lastPlayIsFirstDown: Bool = false,
        blueprint: PlayAnimationBlueprint? = nil
    ) -> GameViewModel {
        let vm = GameViewModel()
        vm.homeTeam = homeTeam
        vm.awayTeam = awayTeam
        vm.isUserPossession = isUserPossession
        vm.currentPhase = phase

        // Build a mock Game struct with the desired state
        var game = Game(
            homeTeamId: homeTeam.id,
            awayTeamId: awayTeam.id,
            week: 1,
            seasonYear: 1993
        )
        game.clock = GameClock(quarter: quarter, timeRemaining: timeRemaining, isRunning: false, quarterLengthSeconds: 900)
        game.score = GameScore(homeScore: homeScore, awayScore: awayScore)
        game.fieldPosition = FieldPosition(yardLine: yardLine)
        game.downAndDistance = DownAndDistance(down: down, yardsToGo: yardsToGo, lineOfScrimmage: yardLine)
        game.possessingTeamId = isUserPossession ? homeTeam.id : awayTeam.id
        game.isKickoff = false
        game.isExtraPoint = false
        game.gameStatus = .inProgress
        game.homeTimeouts = 3
        game.awayTimeouts = 3
        vm.game = game
        vm.loadAuthenticPlaybooks()

        // Set last play result if provided
        if let desc = lastPlayDescription {
            vm.lastPlayResult = PlayResult(
                playType: .insideRun,
                description: desc,
                yardsGained: lastPlayYards,
                timeElapsed: 8,
                quarter: quarter,
                timeRemaining: timeRemaining,
                isFirstDown: lastPlayIsFirstDown
            )
        }

        if let bp = blueprint {
            vm.currentAnimationBlueprint = bp
        }

        return vm
    }

    /// Build a simple mock animation blueprint with 22 stationary players at the LOS
    private static func mockBlueprint(losYard: Int) -> PlayAnimationBlueprint {
        let losX = 32.0 + (CGFloat(losYard) / 100.0) * 576.0 // flatEndZone + fraction * playField
        let centerY: CGFloat = 180

        // Offensive positions (rough I-formation)
        let offPositions: [(CGFloat, CGFloat, PlayerRole)] = [
            (losX - 6, centerY,      .lineman),      // C
            (losX - 6, centerY - 20, .lineman),      // LG
            (losX - 6, centerY + 20, .lineman),      // RG
            (losX - 6, centerY - 40, .lineman),      // LT
            (losX - 6, centerY + 40, .lineman),      // RT
            (losX - 20, centerY + 60, .receiver),     // WR left
            (losX - 20, centerY - 60, .receiver),     // WR right
            (losX - 8, centerY + 50, .tightend),      // TE
            (losX - 18, centerY, .quarterback),        // QB
            (losX - 30, centerY, .runningback),        // RB
            (losX - 24, centerY + 8, .fullback),       // FB
        ]

        // Defensive positions (4-3)
        let defPositions: [(CGFloat, CGFloat, PlayerRole)] = [
            (losX + 6, centerY - 15, .lineman),       // DE
            (losX + 6, centerY - 5, .lineman),         // DT
            (losX + 6, centerY + 5, .lineman),         // DT
            (losX + 6, centerY + 15, .lineman),        // DE
            (losX + 20, centerY - 20, .linebacker),     // OLB
            (losX + 20, centerY, .linebacker),           // MLB
            (losX + 20, centerY + 20, .linebacker),      // OLB
            (losX + 40, centerY - 60, .cornerback),       // CB
            (losX + 40, centerY + 60, .cornerback),       // CB
            (losX + 50, centerY - 15, .safety),            // FS
            (losX + 50, centerY + 15, .safety),            // SS
        ]

        func makePath(x: CGFloat, y: CGFloat, index: Int, role: PlayerRole) -> AnimatedPlayerPath {
            AnimatedPlayerPath(
                playerIndex: index,
                role: role,
                waypoints: [
                    AnimationWaypoint(position: CGPoint(x: x, y: y), time: 0.0, speed: .slow),
                    AnimationWaypoint(position: CGPoint(x: x, y: y), time: 1.0, speed: .slow),
                ]
            )
        }

        let offPaths = offPositions.enumerated().map { i, p in makePath(x: p.0, y: p.1, index: i, role: p.2) }
        let defPaths = defPositions.enumerated().map { i, p in makePath(x: p.0, y: p.1, index: i, role: p.2) }

        let ballPath = BallAnimationPath(segments: [
            .held(byPlayerIndex: 8, isOffense: true, startTime: 0.0, endTime: 1.0) // QB holds ball
        ])

        return PlayAnimationBlueprint(
            offensivePaths: offPaths,
            defensivePaths: defPaths,
            ballPath: ballPath,
            totalDuration: 3.0,
            phases: [
                AnimationPhase(name: .preSnap, startTime: 0.0, endTime: 1.0)
            ]
        )
    }

    // MARK: - Capture All Screenshots

    /// Capture all 32 screenshots matching reference frames.
    /// Returns the number of screenshots successfully captured.
    static func captureAll(progress: ProgressCallback? = nil) async -> Int {
        let teams = mockTeams()
        let home = teams.home
        let away = teams.away
        var captured = 0
        let totalScreenshots = 32

        // Helper to report progress
        func report(_ index: Int, _ filename: String) {
            progress?(index, totalScreenshots, filename)
        }

        // --- 01: Splash Screen ---
        do {
            report(1, "01_splash.png")
            let splash = SplashScreen(onComplete: {})
            try ScreenshotService.captureView(splash, filename: "01_splash.png")
            captured += 1
        } catch { print("[Harness] 01_splash failed: \(error)") }

        // --- 02: Game Dialog ---
        do {
            report(2, "02_game_dialog.png")
            let dialog = gameDialogView()
            try ScreenshotService.captureView(dialog, filename: "02_game_dialog.png")
            captured += 1
        } catch { print("[Harness] 02_game_dialog failed: \(error)") }

        // --- 03: Play Calling - Kickoff ---
        do {
            report(3, "03_playcalling_kickoff.png")
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playCalling,
                                        quarter: 1, timeRemaining: 900, yardLine: 35)
            vm.game?.isKickoff = true
            let view = FPSPlayCallingScreen(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "03_playcalling_kickoff.png")
            captured += 1
        } catch { print("[Harness] 03_playcalling_kickoff failed: \(error)") }

        // --- 04: Field - Kickoff Play ---
        do {
            report(4, "04_field_kickoff.png")
            let bp = mockBlueprint(losYard: 35)
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playAnimation,
                                        quarter: 1, timeRemaining: 892, yardLine: 35,
                                        blueprint: bp)
            let view = FPSFieldView(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "04_field_kickoff.png")
            captured += 1
        } catch { print("[Harness] 04_field_kickoff failed: \(error)") }

        // --- 05: Play Result - Kickoff ---
        do {
            report(5, "05_play_result.png")
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playResult,
                                        quarter: 1, timeRemaining: 885, yardLine: 22,
                                        lastPlayDescription: "Dallas kickoff. Buffalo return by A. Smith to the BUF 22.",
                                        lastPlayYards: 22)
            let view = ZStack {
                FPSFieldView(viewModel: vm)
                FPSPlayResultOverlay(viewModel: vm)
            }
            try ScreenshotService.captureView(view, filename: "05_play_result.png")
            captured += 1
        } catch { print("[Harness] 05_play_result failed: \(error)") }

        // --- 06: Play Calling - Defense ---
        do {
            report(6, "06_playcalling_defense.png")
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playCalling,
                                        quarter: 1, timeRemaining: 885, down: 1, yardsToGo: 10,
                                        yardLine: 22, isUserPossession: false)
            let view = FPSPlayCallingScreen(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "06_playcalling_defense.png")
            captured += 1
        } catch { print("[Harness] 06_playcalling_defense failed: \(error)") }

        // --- 07: Presnap Field ---
        do {
            report(7, "07_presnap.png")
            let bp = mockBlueprint(losYard: 22)
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .presnap,
                                        quarter: 1, timeRemaining: 880, down: 1, yardsToGo: 10,
                                        yardLine: 22, blueprint: bp)
            let view = FPSFieldView(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "07_presnap.png")
            captured += 1
        } catch { print("[Harness] 07_presnap failed: \(error)") }

        // --- 08: Referee - First Down ---
        do {
            report(8, "08_referee_firstdown.png")
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .refereeCall("First down, Buffalo"),
                                        quarter: 1, timeRemaining: 860, yardLine: 35)
            let view = ZStack {
                FPSFieldView(viewModel: vm)
                FPSRefereeOverlay(message: "First down, Buffalo", onDismiss: {})
            }
            try ScreenshotService.captureView(view, filename: "08_referee_firstdown.png")
            captured += 1
        } catch { print("[Harness] 08_referee_firstdown failed: \(error)") }

        // --- 09: Replay Controls ---
        do {
            report(9, "09_replay_controls.png")
            let bp = mockBlueprint(losYard: 35)
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playAnimation,
                                        quarter: 1, timeRemaining: 855, yardLine: 35, blueprint: bp)
            let view = ZStack {
                FPSFieldView(viewModel: vm)
                FPSReplayControls(viewModel: vm, onExit: {})
            }
            try ScreenshotService.captureView(view, filename: "09_replay_controls.png")
            captured += 1
        } catch { print("[Harness] 09_replay_controls failed: \(error)") }

        // --- 10: Presnap - Different Formation ---
        do {
            report(10, "10_presnap_formation2.png")
            let bp = mockBlueprint(losYard: 45)
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .presnap,
                                        quarter: 1, timeRemaining: 820, down: 2, yardsToGo: 7,
                                        yardLine: 45, blueprint: bp)
            let view = FPSFieldView(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "10_presnap_formation2.png")
            captured += 1
        } catch { print("[Harness] 10_presnap_formation2 failed: \(error)") }

        // --- 11: Play Result with Injury ---
        do {
            report(11, "11_play_result_injury.png")
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playResult,
                                        quarter: 1, timeRemaining: 810, down: 2, yardsToGo: 3,
                                        yardLine: 48,
                                        lastPlayDescription: "J. Kelly pass to A. Reed for 7 yards. INJURY — A. Reed, Knee Sprain (1 week)",
                                        lastPlayYards: 7, lastPlayIsFirstDown: true)
            let view = ZStack {
                FPSFieldView(viewModel: vm)
                FPSPlayResultOverlay(viewModel: vm)
            }
            try ScreenshotService.captureView(view, filename: "11_play_result_injury.png")
            captured += 1
        } catch { print("[Harness] 11_play_result_injury failed: \(error)") }

        // --- 12: Play Calling - Offense ---
        do {
            report(12, "12_playcalling_offense.png")
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playCalling,
                                        quarter: 2, timeRemaining: 600, down: 1, yardsToGo: 10,
                                        yardLine: 55, homeScore: 7, awayScore: 3)
            let view = FPSPlayCallingScreen(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "12_playcalling_offense.png")
            captured += 1
        } catch { print("[Harness] 12_playcalling_offense failed: \(error)") }

        // --- 13: Presnap - Goal Line ---
        do {
            report(13, "13_presnap_goalline.png")
            let bp = mockBlueprint(losYard: 95)
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .presnap,
                                        quarter: 2, timeRemaining: 120, down: 1, yardsToGo: 5,
                                        yardLine: 95, homeScore: 7, awayScore: 3, blueprint: bp)
            let view = FPSFieldView(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "13_presnap_goalline.png")
            captured += 1
        } catch { print("[Harness] 13_presnap_goalline failed: \(error)") }

        // --- 14: Play Result - 4th Down ---
        do {
            report(14, "14_play_result_4thdown.png")
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playResult,
                                        quarter: 3, timeRemaining: 450, down: 4, yardsToGo: 3,
                                        yardLine: 68, homeScore: 14, awayScore: 10,
                                        lastPlayDescription: "T. Thomas run up the middle for 2 yards.",
                                        lastPlayYards: 2)
            let view = ZStack {
                FPSFieldView(viewModel: vm)
                FPSPlayResultOverlay(viewModel: vm)
            }
            try ScreenshotService.captureView(view, filename: "14_play_result_4thdown.png")
            captured += 1
        } catch { print("[Harness] 14_play_result_4thdown failed: \(error)") }

        // --- 15: Play Calling - Special Teams ---
        do {
            report(15, "15_playcalling_specialteams.png")
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playCalling,
                                        quarter: 3, timeRemaining: 445, down: 4, yardsToGo: 1,
                                        yardLine: 70, homeScore: 14, awayScore: 10)
            let view = FPSPlayCallingScreen(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "15_playcalling_specialteams.png")
            captured += 1
        } catch { print("[Harness] 15_playcalling_specialteams failed: \(error)") }

        // --- 16: Field Goal Kick ---
        do {
            report(16, "16_fieldgoal_kick.png")
            let bp = mockBlueprint(losYard: 85)
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playAnimation,
                                        quarter: 3, timeRemaining: 440, yardLine: 85,
                                        homeScore: 14, awayScore: 10, blueprint: bp)
            let view = FPSFieldView(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "16_fieldgoal_kick.png")
            captured += 1
        } catch { print("[Harness] 16_fieldgoal_kick failed: \(error)") }

        // --- 17: Referee - Field Goal Good ---
        do {
            report(17, "17_referee_good.png")
            let vm = configureViewModel(homeTeam: home, awayTeam: away,
                                        phase: .refereeCall("FIELD GOAL IS GOOD!"),
                                        quarter: 3, timeRemaining: 438, yardLine: 85,
                                        homeScore: 17, awayScore: 10)
            let view = ZStack {
                FPSFieldView(viewModel: vm)
                FPSRefereeOverlay(message: "FIELD GOAL IS GOOD!", onDismiss: {})
            }
            try ScreenshotService.captureView(view, filename: "17_referee_good.png")
            captured += 1
        } catch { print("[Harness] 17_referee_good failed: \(error)") }

        // --- 18: Play Calling - Post Score Kickoff ---
        do {
            report(18, "18_playcalling_postscore.png")
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playCalling,
                                        quarter: 3, timeRemaining: 435, yardLine: 35,
                                        homeScore: 17, awayScore: 10)
            vm.game?.isKickoff = true
            let view = FPSPlayCallingScreen(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "18_playcalling_postscore.png")
            captured += 1
        } catch { print("[Harness] 18_playcalling_postscore failed: \(error)") }

        // --- 19: Field - Kickoff Return ---
        do {
            report(19, "19_field_kickoff_return.png")
            let bp = mockBlueprint(losYard: 35)
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playAnimation,
                                        quarter: 3, timeRemaining: 430, yardLine: 35,
                                        homeScore: 17, awayScore: 10, blueprint: bp)
            let view = FPSFieldView(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "19_field_kickoff_return.png")
            captured += 1
        } catch { print("[Harness] 19_field_kickoff_return failed: \(error)") }

        // --- 20: Play Calling - Defense 2 ---
        do {
            report(20, "20_playcalling_defense2.png")
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playCalling,
                                        quarter: 4, timeRemaining: 300, down: 2, yardsToGo: 6,
                                        yardLine: 48, homeScore: 17, awayScore: 17,
                                        isUserPossession: false)
            let view = FPSPlayCallingScreen(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "20_playcalling_defense2.png")
            captured += 1
        } catch { print("[Harness] 20_playcalling_defense2 failed: \(error)") }

        // --- 21: Main Menu Title Screen (standalone recreation) ---
        do {
            report(21, "21_main_menu.png")
            let view = mainMenuMockView()
            try ScreenshotService.captureView(view, filename: "21_main_menu.png")
            captured += 1
        } catch { print("[Harness] 21_main_menu failed: \(error)") }

        // --- 22: New Game Team Selection (standalone recreation) ---
        do {
            report(22, "22_team_selection.png")
            let view = teamSelectionMockView()
            try ScreenshotService.captureView(view, filename: "22_team_selection.png")
            captured += 1
        } catch { print("[Harness] 22_team_selection failed: \(error)") }

        // --- 23: Team Roster (standalone recreation using PlayerCardGrid) ---
        do {
            report(23, "23_roster_view.png")
            let view = rosterMockView()
            try ScreenshotService.captureView(view, filename: "23_roster_view.png")
            captured += 1
        } catch { print("[Harness] 23_roster_view failed: \(error)") }

        // --- 24: Player Card ---
        do {
            report(24, "24_player_card.png")
            let player = PlayerGenerator.generate(position: .quarterback, tier: .starter)
            let view = ZStack {
                Color.black.ignoresSafeArea()
                PlayerCard(player: player)
                    .frame(width: 400, height: 300)
            }
            try ScreenshotService.captureView(view, filename: "24_player_card.png")
            captured += 1
        } catch { print("[Harness] 24_player_card failed: \(error)") }

        // --- 25: Pre-game Narration (standalone recreation) ---
        do {
            report(25, "25_pregame_narration.png")
            let view = pregameNarrationMockView(home: home, away: away)
            try ScreenshotService.captureView(view, filename: "25_pregame_narration.png")
            captured += 1
        } catch { print("[Harness] 25_pregame_narration failed: \(error)") }

        // --- 26: Extra Point Choice (standalone recreation) ---
        do {
            report(26, "26_extra_point_choice.png")
            let view = extraPointChoiceMockView(home: home, away: away)
            try ScreenshotService.captureView(view, filename: "26_extra_point_choice.png")
            captured += 1
        } catch { print("[Harness] 26_extra_point_choice failed: \(error)") }

        // --- 27: Field with Authentic Sprites (Pre-snap Standing) ---
        do {
            report(27, "27_field_sprites_presnap.png")
            SpriteCache.shared.load()
            let bp = mockBlueprint(losYard: 40)
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .presnap,
                                        quarter: 1, timeRemaining: 850, down: 1, yardsToGo: 10,
                                        yardLine: 40, blueprint: bp)
            let view = FPSFieldView(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "27_field_sprites_presnap.png")
            captured += 1
        } catch { print("[Harness] 27_field_sprites_presnap failed: \(error)") }

        // --- 28: Field with Authentic Sprites (Mid-play Running) ---
        do {
            report(28, "28_field_sprites_midplay.png")
            SpriteCache.shared.load()
            let bp = mockBlueprint(losYard: 50)
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playAnimation,
                                        quarter: 2, timeRemaining: 600, down: 2, yardsToGo: 7,
                                        yardLine: 50, blueprint: bp)
            let view = FPSFieldView(viewModel: vm)
            try ScreenshotService.captureView(view, filename: "28_field_sprites_midplay.png")
            captured += 1
        } catch { print("[Harness] 28_field_sprites_midplay failed: \(error)") }

        // --- 29: Play Result with Authentic Sprites ---
        do {
            report(29, "29_play_result_sprites.png")
            let bp = mockBlueprint(losYard: 55)
            let vm = configureViewModel(homeTeam: home, awayTeam: away, phase: .playResult,
                                        quarter: 2, timeRemaining: 590, down: 1, yardsToGo: 10,
                                        yardLine: 55,
                                        lastPlayDescription: "T. Thomas run off left tackle for 5 yards. First down!",
                                        lastPlayYards: 5, lastPlayIsFirstDown: true,
                                        blueprint: bp)
            let view = ZStack {
                FPSFieldView(viewModel: vm)
                FPSPlayResultOverlay(viewModel: vm)
            }
            try ScreenshotService.captureView(view, filename: "29_play_result_sprites.png")
            captured += 1
        } catch { print("[Harness] 29_play_result_sprites failed: \(error)") }

        // --- 30: Halftime Score Summary ---
        do {
            report(30, "30_halftime.png")
            let view = halftimeMockView(home: home, away: away)
            try ScreenshotService.captureView(view, filename: "30_halftime.png")
            captured += 1
        } catch { print("[Harness] 30_halftime failed: \(error)") }

        // --- 31: Game Over Final Score ---
        do {
            report(31, "31_game_over.png")
            var game = Game(homeTeamId: home.id, awayTeamId: away.id, week: 1, seasonYear: 1993)
            game.score = GameScore(homeScore: 24, awayScore: 17)
            game.gameStatus = .final
            let view = GameOverView(homeTeam: home, awayTeam: away, game: game, onContinue: {})
            try ScreenshotService.captureView(view, filename: "31_game_over.png")
            captured += 1
        } catch { print("[Harness] 31_game_over failed: \(error)") }

        // --- 32: Pause Menu Overlay ---
        do {
            report(32, "32_pause_menu.png")
            let view = pauseMenuMockView()
            try ScreenshotService.captureView(view, filename: "32_pause_menu.png")
            captured += 1
        } catch { print("[Harness] 32_pause_menu failed: \(error)") }

        return captured
    }

    // MARK: - Standalone View Builders

    // MARK: - New Screenshot Mock Views (21-32)

    /// Mock main menu (standalone, no EnvironmentObject needed)
    private static func mainMenuMockView() -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Text("FRONT PAGE SPORTS")
                    .font(RetroFont.huge())
                    .foregroundColor(VGA.digitalAmber)
                Text("FOOTBALL PRO")
                    .font(RetroFont.large())
                    .foregroundColor(VGA.white)
                Spacer().frame(height: 40)
                VStack(spacing: 12) {
                    FPSButton("NEW GAME", width: 200) {}
                    FPSButton("LOAD GAME", width: 200) {}
                    FPSButton("SETTINGS", width: 200) {}
                    FPSButton("QUIT", width: 200) {}
                }
                Spacer()
            }
        }
    }

    /// Mock team selection grid (standalone)
    private static func teamSelectionMockView() -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            FPSDialog("SELECT YOUR TEAM") {
                VStack(spacing: 12) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(80)), count: 7), spacing: 8) {
                        ForEach(0..<28, id: \.self) { i in
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(i == 4 ? Color(VGA.playSlotGreen) : Color(VGA.panelBg))
                                    .frame(width: 78, height: 40)
                                Text("TM\(i + 1)")
                                    .font(RetroFont.tiny())
                                    .foregroundColor(VGA.white)
                            }
                        }
                    }
                    .padding(8)
                    FPSButton("SELECT") {}
                }
                .padding()
            }
        }
    }

    /// Mock roster view (standalone)
    private static func rosterMockView() -> some View {
        let team = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        return ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(team.fullName.uppercased())
                        .font(RetroFont.header())
                        .foregroundColor(VGA.white)
                    Spacer()
                    Text("RECORD: 0-0")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.lightGray)
                }
                .padding(8)
                .background(Color(VGA.panelBg))

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(team.roster.prefix(15), id: \.id) { player in
                            HStack {
                                Text("#\(player.jerseyNumber)")
                                    .font(RetroFont.small())
                                    .foregroundColor(VGA.digitalAmber)
                                    .frame(width: 30, alignment: .trailing)
                                Text(player.fullName)
                                    .font(RetroFont.small())
                                    .foregroundColor(VGA.white)
                                Spacer()
                                Text(player.position.displayName)
                                    .font(RetroFont.tiny())
                                    .foregroundColor(VGA.lightGray)
                                Text("\(player.overall)")
                                    .font(RetroFont.small())
                                    .foregroundColor(VGA.green)
                                    .frame(width: 30)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    /// Mock pre-game narration (standalone)
    private static func pregameNarrationMockView(home: Team, away: Team) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("PRE-GAME")
                    .font(RetroFont.title())
                    .foregroundColor(VGA.digitalAmber)
                Text("\(home.fullName) vs \(away.fullName)")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.white)
                Text("The \(home.fullName) enter \(home.stadiumName) today to face the \(away.fullName) in what promises to be an exciting matchup. Coach \(home.coachName) leads his team onto the field...")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.lightGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
                FPSButton("START GAME") {}
                Spacer().frame(height: 40)
            }
        }
    }

    /// Mock extra point choice (standalone)
    private static func extraPointChoiceMockView(home: Team, away: Team) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            FPSDialog("TOUCHDOWN!") {
                VStack(spacing: 16) {
                    Text("\(home.fullName) 6 — \(away.fullName) 3")
                        .font(RetroFont.header())
                        .foregroundColor(VGA.white)
                    Spacer().frame(height: 8)
                    HStack(spacing: 20) {
                        FPSButton("KICK PAT", width: 120) {}
                        FPSButton("GO FOR 2", width: 120) {}
                    }
                }
                .padding()
            }
        }
    }

    /// Mock halftime score summary (standalone)
    private static func halftimeMockView(home: Team, away: Team) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            FPSDialog("HALFTIME") {
                VStack(spacing: 16) {
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text(away.abbreviation)
                                .font(RetroFont.header())
                                .foregroundColor(VGA.lightGray)
                            Text("10")
                                .font(RetroFont.score())
                                .foregroundColor(VGA.white)
                        }
                        Text("-")
                            .font(RetroFont.huge())
                            .foregroundColor(VGA.darkGray)
                        VStack(spacing: 4) {
                            Text(home.abbreviation)
                                .font(RetroFont.header())
                                .foregroundColor(VGA.lightGray)
                            Text("14")
                                .font(RetroFont.score())
                                .foregroundColor(VGA.green)
                        }
                    }
                    FPSButton("CONTINUE") {}
                }
                .padding(24)
            }
        }
    }

    /// Mock pause menu (standalone)
    private static func pauseMenuMockView() -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            FPSDialog("GAME PAUSED") {
                VStack(spacing: 12) {
                    Spacer().frame(height: 8)
                    FPSButton("RESUME", width: 200) {}
                    FPSButton("SAVE GAME", width: 200) {}
                    FPSButton("QUIT TO MENU", width: 200) {}
                    Spacer().frame(height: 8)
                }
                .padding()
            }
        }
    }

    // MARK: - Original Standalone View Builders

    /// "Game in progress" dialog matching reference frame 007
    private static func gameDialogView() -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FPSDialog("GAME IN PROGRESS") {
                VStack(spacing: 16) {
                    Text("Buffalo Bills vs Dallas Cowboys")
                        .font(RetroFont.body())
                        .foregroundColor(VGA.white)

                    Text("Week 1 — 1st Quarter  15:00")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.lightGray)

                    HStack(spacing: 12) {
                        FPSButton("Play", width: 80) {}
                        FPSButton("Watch", width: 80) {}
                        FPSButton("Save", width: 80) {}
                        FPSButton("Delete", width: 80) {}
                    }
                }
                .padding(16)
            }
            .frame(width: 500, height: 200)
        }
    }
}
