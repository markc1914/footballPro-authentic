//
//  PlayerTests.swift
//  footballProTests
//
//  Tests for Player model and generation
//

import Foundation
import Testing
@testable import footballPro

@Suite("Player Tests")
struct PlayerTests {

    // MARK: - Player Creation

    @Test("Player can be created with valid attributes")
    func testPlayerCreation() {
        let ratings = PlayerRatings.random(tier: .starter)
        let contract = Contract.veteran(rating: 80, position: .quarterback)

        let player = Player(
            firstName: "John",
            lastName: "Doe",
            position: .quarterback,
            age: 25,
            height: 75,
            weight: 220,
            college: "Alabama",
            experience: 3,
            ratings: ratings,
            contract: contract
        )

        #expect(player.fullName == "John Doe")
        #expect(player.position == .quarterback)
        #expect(player.age == 25)
        #expect(player.experience == 3)
    }

    @Test("Player display height formats correctly")
    func testDisplayHeight() {
        let ratings = PlayerRatings.random(tier: .starter)
        let contract = Contract.rookie(round: 1, pick: 1)

        let player = Player(
            firstName: "Test",
            lastName: "Player",
            position: .quarterback,
            age: 22,
            height: 75, // 6'3"
            weight: 220,
            college: "Test U",
            experience: 0,
            ratings: ratings,
            contract: contract
        )

        #expect(player.displayHeight == "6'3\"")
    }

    // MARK: - Player Generator

    @Test("Player generator creates valid players for all positions")
    func testPlayerGeneratorAllPositions() {
        for position in Position.allCases {
            let player = PlayerGenerator.generate(position: position, tier: .starter)

            #expect(player.position == position)
            #expect(player.age >= 22 && player.age <= 32)
            #expect(player.overall >= 50 && player.overall <= 99)
            #expect(!player.firstName.isEmpty)
            #expect(!player.lastName.isEmpty)
        }
    }

    @Test("Elite tier players have higher ratings than backup tier")
    func testPlayerTierRatings() {
        var eliteRatings: [Int] = []
        var backupRatings: [Int] = []

        for _ in 0..<50 {
            let elite = PlayerGenerator.generate(position: .quarterback, tier: .elite)
            let backup = PlayerGenerator.generate(position: .quarterback, tier: .backup)

            eliteRatings.append(elite.overall)
            backupRatings.append(backup.overall)
        }

        let eliteAvg = eliteRatings.reduce(0, +) / eliteRatings.count
        let backupAvg = backupRatings.reduce(0, +) / backupRatings.count

        #expect(eliteAvg > backupAvg, "Elite average (\(eliteAvg)) should be higher than backup average (\(backupAvg))")
    }

    // MARK: - Player Ratings

    @Test("Position-specific overall calculations work correctly")
    func testPositionOverallCalculation() {
        // QB should weight throwing stats heavily
        let qbPlayer = PlayerGenerator.generate(position: .quarterback, tier: .starter)
        #expect(qbPlayer.overall >= 50)

        // RB should weight running stats heavily
        let rbPlayer = PlayerGenerator.generate(position: .runningBack, tier: .starter)
        #expect(rbPlayer.overall >= 50)

        // CB should weight coverage stats heavily
        let cbPlayer = PlayerGenerator.generate(position: .cornerback, tier: .starter)
        #expect(cbPlayer.overall >= 50)
    }

    // MARK: - Player Stats

    @Test("Adding game stats updates season stats correctly")
    func testGameStatsAccumulation() {
        var player = PlayerGenerator.generate(position: .quarterback, tier: .starter)

        let gameStats = GameStats(
            passAttempts: 30,
            passCompletions: 20,
            passingYards: 250,
            passingTouchdowns: 2,
            interceptions: 1
        )

        player.addGameStats(gameStats)

        #expect(player.seasonStats.gamesPlayed == 1)
        #expect(player.seasonStats.passAttempts == 30)
        #expect(player.seasonStats.passCompletions == 20)
        #expect(player.seasonStats.passingYards == 250)
        #expect(player.seasonStats.passingTouchdowns == 2)
        #expect(player.seasonStats.interceptions == 1)

        // Add another game
        player.addGameStats(gameStats)

        #expect(player.seasonStats.gamesPlayed == 2)
        #expect(player.seasonStats.passingYards == 500)
    }

    @Test("Completion percentage calculates correctly")
    func testCompletionPercentage() {
        var stats = SeasonStats()
        stats.passAttempts = 100
        stats.passCompletions = 65

        #expect(stats.completionPercentage == 65.0)
    }

    @Test("Yards per carry calculates correctly")
    func testYardsPerCarry() {
        var stats = SeasonStats()
        stats.rushAttempts = 100
        stats.rushingYards = 450

        #expect(stats.yardsPerCarry == 4.5)
    }

    // MARK: - Contract

    @Test("Rookie contract values are reasonable")
    func testRookieContract() {
        let firstRound = Contract.rookie(round: 1, pick: 1)
        let thirdRound = Contract.rookie(round: 3, pick: 10)
        let seventhRound = Contract.rookie(round: 7, pick: 20)

        #expect(firstRound.yearsRemaining == 4)
        #expect(firstRound.totalValue > thirdRound.totalValue)
        #expect(thirdRound.totalValue > seventhRound.totalValue)
    }

    @Test("Veteran contract reflects player value")
    func testVeteranContract() {
        let highRatedContract = Contract.veteran(rating: 95, position: .quarterback)
        let lowRatedContract = Contract.veteran(rating: 70, position: .quarterback)

        #expect(highRatedContract.totalValue > lowRatedContract.totalValue)
    }

    @Test("QB contracts are higher than other positions")
    func testPositionContractValues() {
        let qbContract = Contract.veteran(rating: 85, position: .quarterback)
        let rbContract = Contract.veteran(rating: 85, position: .runningBack)

        #expect(qbContract.totalValue > rbContract.totalValue)
    }

    // MARK: - Player Status

    @Test("Healthy status is correct by default")
    func testHealthyStatus() {
        let status = PlayerStatus.healthy

        #expect(status.health == 100)
        #expect(status.fatigue == 0)
        #expect(!status.isInjured)
        #expect(status.canPlay)
    }

    @Test("Injured status reflects correctly")
    func testInjuredStatus() {
        var status = PlayerStatus.healthy
        status.health = 70
        status.injuryType = .minor

        #expect(status.isInjured)
        #expect(status.canPlay) // Minor injury still playable

        status.health = 50
        status.injuryType = .seasonEnding

        #expect(!status.canPlay)
    }
}

// MARK: - Position Tests

@Suite("Position Tests")
struct PositionTests {

    @Test("Position correctly identifies offense/defense/special teams")
    func testPositionCategories() {
        #expect(Position.quarterback.isOffense)
        #expect(Position.runningBack.isOffense)
        #expect(Position.wideReceiver.isOffense)

        #expect(Position.cornerback.isDefense)
        #expect(Position.middleLinebacker.isDefense)
        #expect(Position.defensiveEnd.isDefense)

        #expect(Position.kicker.isSpecialTeams)
        #expect(Position.punter.isSpecialTeams)
    }

    @Test("All positions have display names")
    func testPositionDisplayNames() {
        for position in Position.allCases {
            #expect(!position.displayName.isEmpty)
            #expect(position.displayName != position.rawValue || position == .center)
        }
    }
}
