//
//  GameTests.swift
//  footballProTests
//
//  Tests for Game model and simulation
//

import Foundation
import Testing
@testable import footballPro

@Suite("Game Tests")
struct GameTests {

    // MARK: - Game Creation

    @Test("Game initializes with correct default state")
    func testGameCreation() {
        let homeTeamId = UUID()
        let awayTeamId = UUID()

        let game = Game(
            homeTeamId: homeTeamId,
            awayTeamId: awayTeamId,
            week: 1,
            seasonYear: 2024
        )

        #expect(game.homeTeamId == homeTeamId)
        #expect(game.awayTeamId == awayTeamId)
        #expect(game.week == 1)
        #expect(game.clock.quarter == 1)
        #expect(game.clock.timeRemaining == GameClock.defaultQuarterLength)
        #expect(game.score.homeScore == 0)
        #expect(game.score.awayScore == 0)
        #expect(game.gameStatus == .pregame)
    }

    // MARK: - Game Clock

    @Test("Game clock displays time correctly")
    func testGameClockDisplay() {
        var clock = GameClock.kickoff()

        #expect(clock.displayTime == "15:00")
        #expect(clock.quarterDisplay == "1st")

        clock.timeRemaining = 125 // 2:05
        #expect(clock.displayTime == "2:05")

        clock.quarter = 4
        #expect(clock.quarterDisplay == "4th")
    }

    @Test("Game clock ticks correctly")
    func testGameClockTick() {
        var clock = GameClock.kickoff()
        clock.isRunning = true

        clock.tick(seconds: 30)
        #expect(clock.timeRemaining == GameClock.defaultQuarterLength - 30)

        clock.tick(seconds: 900)
        #expect(clock.timeRemaining == 0) // Can't go below 0
    }

    @Test("Quarter transitions work correctly")
    func testQuarterTransition() {
        var clock = GameClock.kickoff()
        clock.nextQuarter()

        #expect(clock.quarter == 2)
        #expect(clock.timeRemaining == GameClock.defaultQuarterLength)
    }

    // MARK: - Field Position

    @Test("Field position calculates yards to end zone")
    func testFieldPositionYardsToEndZone() {
        var position = FieldPosition(yardLine: 25)
        #expect(position.yardsToEndZone == 75)

        position.yardLine = 80
        #expect(position.yardsToEndZone == 20)
        #expect(position.isRedZone)
    }

    @Test("Field position advance works correctly")
    func testFieldPositionAdvance() {
        var position = FieldPosition(yardLine: 25)

        position.advance(yards: 10)
        #expect(position.yardLine == 35)

        position.advance(yards: -5)
        #expect(position.yardLine == 30)
    }

    @Test("Field position flip for possession change")
    func testFieldPositionFlip() {
        var position = FieldPosition(yardLine: 75)
        position.flip()
        #expect(position.yardLine == 25)
    }

    @Test("Field position display is correct")
    func testFieldPositionDisplay() {
        var position = FieldPosition(yardLine: 25)
        #expect(position.displayYardLine == "OWN 25")

        position.yardLine = 75
        #expect(position.displayYardLine == "OPP 25")

        position.yardLine = 50
        #expect(position.displayYardLine == "50")
    }

    // MARK: - Down and Distance

    @Test("First down initializes correctly")
    func testFirstDownInitialization() {
        let downAndDistance = DownAndDistance.firstDown(at: 25)

        #expect(downAndDistance.down == 1)
        #expect(downAndDistance.yardsToGo == 10)
        #expect(downAndDistance.lineOfScrimmage == 25)
    }

    @Test("First down near goal line has correct yards to go")
    func testFirstDownNearGoalLine() {
        let downAndDistance = DownAndDistance.firstDown(at: 95)

        #expect(downAndDistance.yardsToGo == 5) // Only 5 yards to end zone
    }

    @Test("After play updates down and distance correctly")
    func testAfterPlay() {
        var downAndDistance = DownAndDistance.firstDown(at: 25)

        // 5 yard gain - not a first down
        let gotFirstDown = downAndDistance.afterPlay(yardsGained: 5)
        #expect(!gotFirstDown)
        #expect(downAndDistance.down == 2)
        #expect(downAndDistance.yardsToGo == 5)

        // 6 yard gain - first down!
        let gotFirstDown2 = downAndDistance.afterPlay(yardsGained: 6)
        #expect(gotFirstDown2)
        #expect(downAndDistance.down == 1)
        #expect(downAndDistance.yardsToGo == 10)
    }

    @Test("Turnover on downs triggers after 4th down failure")
    func testTurnoverOnDowns() {
        var downAndDistance = DownAndDistance(down: 4, yardsToGo: 5, lineOfScrimmage: 50)

        _ = downAndDistance.afterPlay(yardsGained: 3)

        #expect(downAndDistance.isTurnoverOnDowns)
    }

    // MARK: - Score

    @Test("Score tracks correctly")
    func testScoreTracking() {
        var score = GameScore()

        score.addScore(points: 7, isHome: true, quarter: 1)
        #expect(score.homeScore == 7)
        #expect(score.awayScore == 0)
        #expect(score.homeQuarterScores[0] == 7)

        score.addScore(points: 3, isHome: false, quarter: 2)
        #expect(score.awayScore == 3)
        #expect(score.awayQuarterScores[1] == 3)
    }

    @Test("Score leader calculation")
    func testScoreLeader() {
        var score = GameScore()

        score.homeScore = 21
        score.awayScore = 14

        #expect(score.leader() == true) // Home is leading

        score.awayScore = 21
        #expect(score.isTied)
        #expect(score.leader() == nil)
    }

    // MARK: - Possession

    @Test("Switching possession flips field position")
    func testSwitchPossession() {
        var game = Game(
            homeTeamId: UUID(),
            awayTeamId: UUID(),
            week: 1,
            seasonYear: 2024
        )

        game.fieldPosition = FieldPosition(yardLine: 75)
        let initialPossession = game.possessingTeamId

        game.switchPossession()

        #expect(game.possessingTeamId != initialPossession)
        #expect(game.fieldPosition.yardLine == 25)
    }

    // MARK: - Weather

    @Test("Weather affects gameplay correctly")
    func testWeatherEffects() {
        let clearWeather = Weather(condition: .clear, temperature: 70, windSpeed: 5)
        #expect(!clearWeather.affectsKicking)
        #expect(!clearWeather.affectsPassing)

        let windyWeather = Weather(condition: .clear, temperature: 70, windSpeed: 25)
        #expect(windyWeather.affectsKicking)
        #expect(windyWeather.affectsPassing)

        let snowWeather = Weather(condition: .snow, temperature: 30, windSpeed: 10)
        #expect(snowWeather.affectsKicking)
    }

    @Test("Dome weather has no effects")
    func testDomeWeather() {
        let dome = Weather.dome

        #expect(dome.condition == .dome)
        #expect(dome.windSpeed == 0)
        #expect(!dome.affectsKicking)
        #expect(!dome.affectsPassing)
    }

    // MARK: - Team Game Stats

    @Test("Third down percentage calculates correctly")
    func testThirdDownPercentage() {
        var stats = TeamGameStats()
        stats.thirdDownAttempts = 10
        stats.thirdDownConversions = 4

        #expect(stats.thirdDownPercentage == 40.0)
    }

    @Test("Time of possession displays correctly")
    func testTimeOfPossessionDisplay() {
        var stats = TeamGameStats()
        stats.timeOfPossession = 1800 // 30 minutes

        #expect(stats.timeOfPossessionDisplay == "30:00")
    }
}

// MARK: - Drive Tests

@Suite("Drive Tests")
struct DriveTests {

    @Test("Drive initializes correctly")
    func testDriveCreation() {
        let teamId = UUID()
        let drive = Drive(teamId: teamId, startingFieldPosition: 25, quarter: 1, time: 900)

        #expect(drive.teamId == teamId)
        #expect(drive.startingFieldPosition == 25)
        #expect(drive.plays.isEmpty)
        #expect(drive.result == nil)
    }

    @Test("Drive totals calculate correctly")
    func testDriveTotals() {
        let teamId = UUID()
        var drive = Drive(teamId: teamId, startingFieldPosition: 25, quarter: 1, time: 900)

        let play1 = PlayResult(
            playType: .insideRun,
            description: "Run for 5 yards",
            yardsGained: 5,
            timeElapsed: 30,
            quarter: 1,
            timeRemaining: 870
        )

        let play2 = PlayResult(
            playType: .shortPass,
            description: "Pass for 10 yards",
            yardsGained: 10,
            timeElapsed: 25,
            quarter: 1,
            timeRemaining: 845
        )

        drive.plays = [play1, play2]

        #expect(drive.totalYards == 15)
        #expect(drive.numberOfPlays == 2)
        #expect(drive.timeOfPossession == 55)
    }
}
