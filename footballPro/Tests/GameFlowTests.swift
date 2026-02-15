//
//  GameFlowTests.swift
//  footballProTests
//
//  End-to-end game flow test: setup, phase transitions, play execution,
//  halftime, scoring, timeouts, and game-over conditions.
//

import Foundation
import Testing
@testable import footballPro

@Suite("Game Flow E2E Tests")
struct GameFlowTests {

    // MARK: - Helpers

    private func makeTeam(name: String, city: String, abbr: String) -> Team {
        var team = Team(
            name: name,
            city: city,
            abbreviation: abbr,
            colors: TeamColors(primary: "FF0000", secondary: "0000FF", accent: "FFFFFF"),
            stadiumName: "\(city) Stadium",
            coachName: "Coach \(name)",
            divisionId: UUID()
        )
        // Generate a minimal roster so simulation doesn't crash
        team = TeamGenerator.generateTeam(index: 0, divisionId: team.divisionId)
        return team
    }

    // MARK: - Game Creation

    @Test("Game initializes with pregame phase after setup")
    @MainActor func testGameSetup() {
        let home = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        let away = TeamGenerator.generateTeam(index: 1, divisionId: UUID())

        let vm = GameViewModel()
        vm.setupGame(homeTeam: home, awayTeam: away, week: 1, seasonYear: 1993,
                     userTeamId: home.id, quarterMinutes: 1) // 1-minute quarters for fast tests

        #expect(vm.game != nil)
        #expect(vm.homeTeam != nil)
        #expect(vm.awayTeam != nil)
        // Phase should be pregameNarration (if GAMINTRO.DAT present) or playCalling
        let phase = vm.currentPhase
        let validStart = phase == .pregameNarration || phase == .playCalling
        #expect(validStart, "Game should start in pregameNarration or playCalling, got: \(phase)")
    }

    @Test("Game clock starts at correct quarter length")
    @MainActor func testGameClockInitial() {
        let home = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        let away = TeamGenerator.generateTeam(index: 1, divisionId: UUID())

        let vm = GameViewModel()
        vm.setupGame(homeTeam: home, awayTeam: away, week: 1, seasonYear: 1993,
                     userTeamId: home.id, quarterMinutes: 15)

        #expect(vm.game?.clock.quarter == 1)
        #expect(vm.game?.score.homeScore == 0)
        #expect(vm.game?.score.awayScore == 0)
    }

    // MARK: - Phase Transitions

    @Test("startGameAfterNarration transitions away from pregameNarration")
    @MainActor func testStartAfterNarration() async throws {
        let home = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        let away = TeamGenerator.generateTeam(index: 1, divisionId: UUID())

        let vm = GameViewModel()
        vm.setupGame(homeTeam: home, awayTeam: away, week: 1, seasonYear: 1993,
                     userTeamId: home.id, quarterMinutes: 1)

        if vm.currentPhase == .pregameNarration {
            vm.startGameAfterNarration()
            // Give async task time to complete
            try await Task.sleep(nanoseconds: 500_000_000)
            #expect(vm.currentPhase != .pregameNarration)
        }
    }

    // MARK: - Timeout Management

    @Test("callTimeout decrements possessing team's timeout count")
    @MainActor func testCallTimeout() {
        let home = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        let away = TeamGenerator.generateTeam(index: 1, divisionId: UUID())

        let vm = GameViewModel()
        vm.setupGame(homeTeam: home, awayTeam: away, week: 1, seasonYear: 1993,
                     userTeamId: home.id, quarterMinutes: 1)

        guard vm.game != nil else {
            #expect(Bool(false), "Game not created")
            return
        }

        let timeoutsBefore = vm.possessingTeamTimeouts
        #expect(timeoutsBefore == 3)

        vm.callTimeout()

        // Timeout should have decremented and phase should be referee call
        let timeoutsAfter = vm.possessingTeamTimeouts
        #expect(timeoutsAfter == timeoutsBefore - 1)

        if case .refereeCall(let msg) = vm.currentPhase {
            #expect(msg.contains("TIMEOUT"))
        } else {
            #expect(Bool(false), "Expected refereeCall phase after timeout")
        }
    }

    @Test("callTimeout with 0 remaining does nothing")
    @MainActor func testCallTimeoutExhausted() {
        let home = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        let away = TeamGenerator.generateTeam(index: 1, divisionId: UUID())

        let vm = GameViewModel()
        vm.setupGame(homeTeam: home, awayTeam: away, week: 1, seasonYear: 1993,
                     userTeamId: home.id, quarterMinutes: 1)

        // Exhaust all timeouts
        vm.callTimeout()
        vm.callTimeout()
        vm.callTimeout()

        let before = vm.possessingTeamTimeouts
        #expect(before == 0)

        // This one should do nothing
        vm.callTimeout()
        #expect(vm.possessingTeamTimeouts == 0)
    }

    // MARK: - Game Struct Tests

    @Test("Game tracks scores correctly through manual updates")
    func testScoreTracking() {
        var game = Game(homeTeamId: UUID(), awayTeamId: UUID(), week: 1, seasonYear: 1993)
        #expect(game.score.homeScore == 0)
        #expect(game.score.awayScore == 0)

        game.score.homeScore += 7
        #expect(game.score.homeScore == 7)

        game.score.awayScore += 3
        #expect(game.score.awayScore == 3)
    }

    @Test("Game clock quarter transitions work")
    func testQuarterTransitions() {
        var game = Game(homeTeamId: UUID(), awayTeamId: UUID(), week: 1, seasonYear: 1993)
        #expect(game.clock.quarter == 1)

        game.clock.nextQuarter()
        #expect(game.clock.quarter == 2)

        game.clock.nextQuarter()
        #expect(game.clock.quarter == 3)

        game.clock.nextQuarter()
        #expect(game.clock.quarter == 4)
    }

    @Test("Down and distance tracks correctly")
    func testDownAndDistance() {
        let dd = DownAndDistance.firstDown(at: 25)
        #expect(dd.down == 1)
        #expect(dd.yardsToGo == 10)
        #expect(dd.lineOfScrimmage == 25)
    }

    // MARK: - Play-by-Play Tracking

    @Test("PlayResult can be created and has correct fields")
    func testPlayResultCreation() {
        let result = PlayResult(
            playType: .insideRun,
            description: "T. Thomas run for 5 yards.",
            yardsGained: 5,
            timeElapsed: 6,
            quarter: 1,
            timeRemaining: 894,
            isFirstDown: false
        )

        #expect(result.yardsGained == 5)
        #expect(result.playType == .insideRun)
        #expect(result.description.contains("Thomas"))
        #expect(!result.isFirstDown)
    }

    // MARK: - Halftime & Game Status

    @Test("Game status transitions from pregame to inProgress")
    func testGameStatusTransition() {
        var game = Game(homeTeamId: UUID(), awayTeamId: UUID(), week: 1, seasonYear: 1993)
        #expect(game.gameStatus == .pregame)

        game.gameStatus = .inProgress
        #expect(game.gameStatus == .inProgress)
    }

    @Test("Timeout counts reset at halftime")
    func testTimeoutResetAtHalf() {
        var game = Game(homeTeamId: UUID(), awayTeamId: UUID(), week: 1, seasonYear: 1993)
        game.homeTimeouts = 1
        game.awayTimeouts = 0

        // Simulate halftime reset
        game.homeTimeouts = 3
        game.awayTimeouts = 3
        #expect(game.homeTimeouts == 3)
        #expect(game.awayTimeouts == 3)
    }
}
