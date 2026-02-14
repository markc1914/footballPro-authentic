//
//  SimulationEngineTests.swift
//  footballProTests
//
//  Tests for game simulation engine
//

import Foundation
import Testing
@testable import footballPro

@Suite("Play Resolver Tests")
struct PlayResolverTests {
    let playResolver = PlayResolver()

    // MARK: - Run Play Tests

    @Test("Run plays generate valid outcomes")
    func testRunPlayOutcome() {
        let offTeam = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        let defTeam = TeamGenerator.generateTeam(index: 1, divisionId: UUID())

        let offCall = StandardPlayCall(formation: .singleback, playType: .insideRun) // Changed
        let defCall = StandardDefensiveCall(formation: .base43, coverage: .coverTwo, isBlitzing: false) // Changed

        let outcome = playResolver.resolvePlay(
            offensiveCall: offCall,
            defensiveCall: defCall,
            offensiveTeam: offTeam,
            defensiveTeam: defTeam,
            fieldPosition: FieldPosition(yardLine: 25),
            downAndDistance: .firstDown(at: 25),
            weather: Weather.dome
        )

        // Run plays typically gain between -5 and 15 yards
        #expect(outcome.yardsGained >= -10 && outcome.yardsGained <= 50)
        #expect(outcome.timeElapsed > 0)
        #expect(!outcome.description.isEmpty)
    }

    @Test("Goal line formation affects run defense")
    func testGoalLineDefense() {
        let offTeam = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        let defTeam = TeamGenerator.generateTeam(index: 1, divisionId: UUID())

        var goalLineYards: [Int] = []
        var normalYards: [Int] = []

        for _ in 0..<50 {
            let offCall = StandardPlayCall(formation: .singleback, playType: .insideRun) // Changed

            // Test against goal line defense
            let goalLineDef = StandardDefensiveCall(formation: .goalLine, coverage: .manCoverage, isBlitzing: false) // Changed
            let goalLineOutcome = playResolver.resolvePlay(
                offensiveCall: offCall,
                defensiveCall: goalLineDef,
                offensiveTeam: offTeam,
                defensiveTeam: defTeam,
                fieldPosition: FieldPosition(yardLine: 95),
                downAndDistance: DownAndDistance(down: 1, yardsToGo: 5, lineOfScrimmage: 95),
                weather: Weather.dome
            )
            goalLineYards.append(goalLineOutcome.yardsGained)

            // Test against normal defense
            let normalDef = StandardDefensiveCall(formation: .nickel, coverage: .coverTwo, isBlitzing: false) // Changed
            let normalOutcome = playResolver.resolvePlay(
                offensiveCall: offCall,
                defensiveCall: normalDef,
                offensiveTeam: offTeam,
                defensiveTeam: defTeam,
                fieldPosition: FieldPosition(yardLine: 50),
                downAndDistance: .firstDown(at: 50),
                weather: Weather.dome
            )
            normalYards.append(normalOutcome.yardsGained)
        }

        let goalLineAvg = Double(goalLineYards.reduce(0, +)) / Double(goalLineYards.count)
        let normalAvg = Double(normalYards.reduce(0, +)) / Double(normalYards.count)

        // Goal line defense should yield fewer yards on average
        #expect(goalLineAvg < normalAvg, "Goal line avg (\(goalLineAvg)) should be less than normal (\(normalAvg))")
    }

    // MARK: - Pass Play Tests

    @Test("Pass plays generate valid outcomes")
    func testPassPlayOutcome() {
        let offTeam = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        let defTeam = TeamGenerator.generateTeam(index: 1, divisionId: UUID())

        let offCall = StandardPlayCall(formation: .shotgun, playType: .shortPass) // Changed
        let defCall = StandardDefensiveCall(formation: .nickel, coverage: .coverTwo, isBlitzing: false) // Changed

        let outcome = playResolver.resolvePlay(
            offensiveCall: offCall,
            defensiveCall: defCall,
            offensiveTeam: offTeam,
            defensiveTeam: defTeam,
            fieldPosition: FieldPosition(yardLine: 25),
            downAndDistance: .firstDown(at: 25),
            weather: Weather.dome
        )

        #expect(outcome.timeElapsed > 0)
        #expect(!outcome.description.isEmpty)
    }

    @Test("Deep passes have higher variance than short passes")
    func testPassDepthVariance() {
        let offTeam = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        let defTeam = TeamGenerator.generateTeam(index: 1, divisionId: UUID())

        var shortPassYards: [Int] = []
        var deepPassYards: [Int] = []

        for _ in 0..<100 {
            let shortCall = StandardPlayCall(formation: .shotgun, playType: .shortPass) // Changed
            let deepCall = StandardPlayCall(formation: .shotgun, playType: .deepPass) // Changed
            let defCall = StandardDefensiveCall(formation: .nickel, coverage: .coverTwo, isBlitzing: false) // Changed

            let shortOutcome = playResolver.resolvePlay(
                offensiveCall: shortCall,
                defensiveCall: defCall,
                offensiveTeam: offTeam,
                defensiveTeam: defTeam,
                fieldPosition: FieldPosition(yardLine: 25),
                downAndDistance: .firstDown(at: 25),
                weather: Weather.dome
            )
            shortPassYards.append(shortOutcome.yardsGained)

            let deepOutcome = playResolver.resolvePlay(
                offensiveCall: deepCall,
                defensiveCall: defCall,
                offensiveTeam: offTeam,
                defensiveTeam: defTeam,
                fieldPosition: FieldPosition(yardLine: 25),
                downAndDistance: .firstDown(at: 25),
                weather: Weather.dome
            )
            deepPassYards.append(deepOutcome.yardsGained)
        }

        // Deep passes should have higher variance
        let shortVariance = variance(shortPassYards)
        let deepVariance = variance(deepPassYards)

        #expect(deepVariance > shortVariance, "Deep pass variance should be higher")
    }

    // MARK: - Special Situations

    @Test("Blitz increases sack chance but opens coverage")
    func testBlitzEffect() {
        let offTeam = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        let defTeam = TeamGenerator.generateTeam(index: 1, divisionId: UUID())

        var blitzSacks = 0
        var normalSacks = 0
        let trials = 200

        for _ in 0..<trials {
            let offCall = StandardPlayCall(formation: .shotgun, playType: .mediumPass) // Changed

            let blitzDef = StandardDefensiveCall(formation: .nickel, coverage: .blitz, isBlitzing: true) // Changed
            let blitzOutcome = playResolver.resolvePlay(
                offensiveCall: offCall,
                defensiveCall: blitzDef,
                offensiveTeam: offTeam,
                defensiveTeam: defTeam,
                fieldPosition: FieldPosition(yardLine: 25),
                downAndDistance: .firstDown(at: 25),
                weather: Weather.dome
            )

            if blitzOutcome.yardsGained < 0 && !blitzOutcome.isComplete {
                blitzSacks += 1
            }

            let normalDef = StandardDefensiveCall(formation: .nickel, coverage: .coverTwo, isBlitzing: false) // Changed
            let normalOutcome = playResolver.resolvePlay(
                offensiveCall: offCall,
                defensiveCall: normalDef,
                offensiveTeam: offTeam,
                defensiveTeam: defTeam,
                fieldPosition: FieldPosition(yardLine: 25),
                downAndDistance: .firstDown(at: 25),
                weather: Weather.dome
            )

            if normalOutcome.yardsGained < 0 && !normalOutcome.isComplete {
                normalSacks += 1
            }
        }

        // Blitz should generate more sacks
        #expect(blitzSacks > normalSacks, "Blitz (\(blitzSacks)) should generate more sacks than normal (\(normalSacks))")
    }

    // MARK: - Helpers

    private func variance(_ values: [Int]) -> Double {
        let mean = Double(values.reduce(0, +)) / Double(values.count)
        let squaredDiffs = values.map { pow(Double($0) - mean, 2) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }
}

// MARK: - AI Coach Tests

@Suite("AI Coach Tests")
struct AICoachTests {
    let aiCoach = AICoach()

    @Test("AI calls appropriate plays in short yardage")
    func testShortYardagePlayCalling() {
        let team = TeamGenerator.generateTeam(index: 0, divisionId: UUID())

        let situation = GameSituation(
            down: 3,
            yardsToGo: 1,
            fieldPosition: 50,
            quarter: 2,
            timeRemaining: 600,
            scoreDifferential: 0,
            isRedZone: false
        )

        let play = aiCoach.selectOffensivePlay(for: team, situation: situation)

        // Should favor run plays in short yardage
        let runPlays: [PlayType] = [.insideRun, .outsideRun, .qbSneak, .draw]
        let passPlays: [PlayType] = [.shortPass, .screen]

        let isRunOrShortPass = runPlays.contains(play.playType) || passPlays.contains(play.playType)
        #expect(isRunOrShortPass, "Expected run or short pass, got \(play.playType)")
    }

    @Test("AI calls aggressive plays when trailing late")
    func testTrailingLatePlayCalling() {
        let team = TeamGenerator.generateTeam(index: 0, divisionId: UUID())

        let situation = GameSituation(
            down: 1,
            yardsToGo: 10,
            fieldPosition: 25,
            quarter: 4,
            timeRemaining: 120, // 2 minutes left
            scoreDifferential: -10, // Trailing by 10
            isRedZone: false
        )

        let play = aiCoach.selectOffensivePlay(for: team, situation: situation)

        // Should favor passing plays when needing to score quickly
        #expect(play.formation == .shotgun || play.formation == .emptySet, "Should use passing formation")
    }

    @Test("AI runs clock when winning late")
    func testWinningLatePlayCalling() {
        let team = TeamGenerator.generateTeam(index: 0, divisionId: UUID())

        let situation = GameSituation(
            down: 1,
            yardsToGo: 10,
            fieldPosition: 50,
            quarter: 4,
            timeRemaining: 180, // 3 minutes left
            scoreDifferential: 7, // Winning by 7
            isRedZone: false
        )

        var runCount = 0
        let trials = 20

        for _ in 0..<trials {
            let play = aiCoach.selectOffensivePlay(for: team, situation: situation)
            if play.playType.isRun {
                runCount += 1
            }
        }

        // Should favor running plays to run clock
        #expect(runCount > trials / 2, "Should run more often when winning late (ran \(runCount)/\(trials))")
    }

    @Test("Fourth down decisions are reasonable")
    func testFourthDownDecisions() {
        let situation1 = GameSituation(
            down: 4, yardsToGo: 1, fieldPosition: 75,
            quarter: 2, timeRemaining: 300, scoreDifferential: 0, isRedZone: true
        )

        let decision1 = aiCoach.fourthDownDecision(situation: situation1, kicker: nil)
        // 4th and 1 on the 25 - should go for it or kick FG
        #expect(decision1 == .goForIt || decision1 == .fieldGoal)

        let situation2 = GameSituation(
            down: 4, yardsToGo: 10, fieldPosition: 30,
            quarter: 1, timeRemaining: 600, scoreDifferential: 0, isRedZone: false
        )

        let decision2 = aiCoach.fourthDownDecision(situation: situation2, kicker: nil)
        // 4th and 10 on own 30 - should punt
        #expect(decision2 == .punt)

        let situation3 = GameSituation(
            down: 4, yardsToGo: 5, fieldPosition: 85,
            quarter: 4, timeRemaining: 60, scoreDifferential: -4, isRedZone: true
        )

        let decision3 = aiCoach.fourthDownDecision(situation: situation3, kicker: nil)
        // Late game, trailing, red zone - must go for it
        #expect(decision3 == .goForIt)
    }
}

// MARK: - Stat Calculator Tests

@Suite("Stat Calculator Tests")
struct StatCalculatorTests {
    let statCalculator = StatCalculator()

    @Test("QB rating calculates correctly")
    func testQBRating() {
        var stats = SeasonStats()
        stats.passAttempts = 500
        stats.passCompletions = 350
        stats.passingYards = 4500
        stats.passingTouchdowns = 35
        stats.interceptions = 10

        let rating = statCalculator.calculateQBRating(stats: stats)

        // Should be a good rating for these stats
        #expect(rating > 100 && rating < 160, "Rating \(rating) should be between 100-160")
    }

    @Test("Player value considers age and position")
    func testPlayerValue() {
        let youngQB = PlayerGenerator.generate(position: .quarterback, tier: .elite)
        let youngRB = PlayerGenerator.generate(position: .runningBack, tier: .elite)
        let youngKicker = PlayerGenerator.generate(position: .kicker, tier: .elite)

        let qbValue = statCalculator.calculatePlayerValue(player: youngQB)
        let rbValue = statCalculator.calculatePlayerValue(player: youngRB)
        let kickerValue = statCalculator.calculatePlayerValue(player: youngKicker)

        // QB should be most valuable, kicker least
        #expect(qbValue > rbValue, "QB should be more valuable than RB")
        #expect(rbValue > kickerValue, "RB should be more valuable than kicker")
    }
}