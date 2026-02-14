//
//  TeamTests.swift
//  footballProTests
//
//  Tests for Team model and generation
//

import Foundation
import Testing
@testable import footballPro

@Suite("Team Tests")
struct TeamTests {

    // MARK: - Team Creation

    @Test("Team can be created with valid attributes")
    func testTeamCreation() {
        let divisionId = UUID()
        let team = Team(
            name: "Eagles",
            city: "Philadelphia",
            abbreviation: "PHI",
            colors: TeamColors(primary: "004C54", secondary: "A5ACAF", accent: "FFFFFF"),
            stadiumName: "Lincoln Financial Field",
            divisionId: divisionId
        )

        #expect(team.fullName == "Philadelphia Eagles")
        #expect(team.abbreviation == "PHI")
        #expect(team.roster.isEmpty)
        #expect(team.record.wins == 0)
    }

    // MARK: - Roster Management

    @Test("Adding players updates roster and depth chart")
    func testAddPlayer() {
        var team = createTestTeam()
        let player = PlayerGenerator.generate(position: .quarterback, tier: .starter)

        team.addPlayer(player)

        #expect(team.roster.count == 1)
        #expect(team.player(withId: player.id) != nil)
        #expect(team.players(at: .quarterback).count == 1)
    }

    @Test("Removing players updates roster and finances")
    func testRemovePlayer() {
        var team = createTestTeam()
        let player = PlayerGenerator.generate(position: .quarterback, tier: .starter)

        team.addPlayer(player)
        let initialPayroll = team.finances.currentPayroll

        team.removePlayer(player.id)

        #expect(team.roster.isEmpty)
        #expect(team.finances.currentPayroll < initialPayroll)
    }

    @Test("Setting starter updates depth chart")
    func testSetStarter() {
        var team = createTestTeam()
        let qb1 = PlayerGenerator.generate(position: .quarterback, tier: .starter)
        let qb2 = PlayerGenerator.generate(position: .quarterback, tier: .backup)

        team.addPlayer(qb1)
        team.addPlayer(qb2)

        team.setStarter(qb2.id, at: .quarterback)

        #expect(team.starter(at: .quarterback)?.id == qb2.id)
    }

    // MARK: - Team Ratings

    @Test("Team ratings calculate from roster")
    func testTeamRatings() {
        var team = createTestTeam()

        // Empty team should have default ratings
        #expect(team.offensiveRating == 50)
        #expect(team.defensiveRating == 50)

        // Add some offensive players
        for _ in 0..<5 {
            team.addPlayer(PlayerGenerator.generate(position: .wideReceiver, tier: .elite))
        }

        // Offensive rating should be higher now
        #expect(team.offensiveRating > 50)
    }

    // MARK: - Team Generator

    @Test("Team generator creates valid teams")
    func testTeamGenerator() {
        let divisionId = UUID()
        let team = TeamGenerator.generateTeam(index: 0, divisionId: divisionId)

        #expect(!team.name.isEmpty)
        #expect(!team.city.isEmpty)
        #expect(team.abbreviation.count == 3)
        #expect(team.roster.count > 40) // Should have full roster
        #expect(team.divisionId == divisionId)
    }

    @Test("Generated team has players at all key positions")
    func testGeneratedTeamPositions() {
        let divisionId = UUID()
        let team = TeamGenerator.generateTeam(index: 0, divisionId: divisionId)

        // Check key positions have starters
        #expect(team.starter(at: .quarterback) != nil)
        #expect(team.starter(at: .runningBack) != nil)
        #expect(team.starter(at: .wideReceiver) != nil)
        #expect(team.starter(at: .leftTackle) != nil)
        #expect(team.starter(at: .cornerback) != nil)
        #expect(team.starter(at: .middleLinebacker) != nil)
        #expect(team.starter(at: .kicker) != nil)
    }

    @Test("Generated team has at least one elite player")
    func testGeneratedTeamHasElite() {
        let divisionId = UUID()
        let team = TeamGenerator.generateTeam(index: 0, divisionId: divisionId)

        let hasElite = team.roster.contains { $0.overall >= 85 }
        #expect(hasElite)
    }

    // MARK: - Team Record

    @Test("Recording wins updates record correctly")
    func testRecordWin() {
        var record = TeamRecord()

        record.recordWin(points: 28, opponentPoints: 21, isDivision: true, isConference: true)

        #expect(record.wins == 1)
        #expect(record.losses == 0)
        #expect(record.divisionWins == 1)
        #expect(record.conferenceWins == 1)
        #expect(record.pointsFor == 28)
        #expect(record.pointsAgainst == 21)
        #expect(record.displayRecord == "1-0")
    }

    @Test("Recording losses updates record correctly")
    func testRecordLoss() {
        var record = TeamRecord()

        record.recordLoss(points: 14, opponentPoints: 35, isDivision: false, isConference: true)

        #expect(record.wins == 0)
        #expect(record.losses == 1)
        #expect(record.divisionLosses == 0)
        #expect(record.conferenceLosses == 1)
        #expect(record.pointDifferential == -21)
    }

    @Test("Win percentage calculates correctly")
    func testWinPercentage() {
        var record = TeamRecord()

        record.wins = 10
        record.losses = 4
        record.ties = 0

        #expect(record.gamesPlayed == 14)
        // Win percentage = 10 / 14 = ~0.714
        #expect(record.winPercentage > 0.71 && record.winPercentage < 0.72)
    }

    // MARK: - Team Finances

    @Test("Salary cap calculations are correct")
    func testSalaryCapCalculations() {
        var finances = TeamFinances.standard

        #expect(finances.salaryCap == 225000)
        #expect(finances.availableCap == 225000)

        finances.currentPayroll = 200000

        #expect(finances.availableCap == 25000)
        #expect(finances.capPercentageUsed > 88 && finances.capPercentageUsed < 90)
    }

    @Test("Adding contracts updates payroll")
    func testAddContract() {
        var finances = TeamFinances.standard
        let contract = Contract.veteran(rating: 90, position: .quarterback)

        finances.addContract(contract)

        #expect(finances.currentPayroll == contract.capHit)
    }

    // MARK: - Helper Methods

    private func createTestTeam() -> Team {
        Team(
            name: "Test",
            city: "Test City",
            abbreviation: "TST",
            colors: TeamColors(primary: "000000", secondary: "FFFFFF", accent: "FF0000"),
            stadiumName: "Test Stadium",
            divisionId: UUID()
        )
    }
}

// MARK: - Depth Chart Tests

@Suite("Depth Chart Tests")
struct DepthChartTests {

    @Test("Depth chart initializes with all positions")
    func testDepthChartInitialization() {
        let depthChart = DepthChart()

        for position in Position.allCases {
            #expect(depthChart.positions[position] != nil)
        }
    }

    @Test("Setting starter moves player to front")
    func testSetStarter() {
        var depthChart = DepthChart()
        let player1Id = UUID()
        let player2Id = UUID()

        depthChart.addPlayer(player1Id, at: .quarterback)
        depthChart.addPlayer(player2Id, at: .quarterback)

        // player1 should be starter initially
        #expect(depthChart.starter(at: .quarterback) == player1Id)

        // Set player2 as starter
        depthChart.setStarter(player2Id, at: .quarterback)

        #expect(depthChart.starter(at: .quarterback) == player2Id)
        #expect(depthChart.backups(at: .quarterback).contains(player1Id))
    }

    @Test("Removing player clears from all positions")
    func testRemovePlayer() {
        var depthChart = DepthChart()
        let playerId = UUID()

        depthChart.addPlayer(playerId, at: .quarterback)

        #expect(depthChart.starter(at: .quarterback) == playerId)

        depthChart.removePlayer(playerId)

        #expect(depthChart.starter(at: .quarterback) == nil)
    }

    @Test("Depth position returns correct value")
    func testDepthPosition() {
        var depthChart = DepthChart()
        let player1Id = UUID()
        let player2Id = UUID()
        let player3Id = UUID()

        depthChart.addPlayer(player1Id, at: .quarterback)
        depthChart.addPlayer(player2Id, at: .quarterback)
        depthChart.addPlayer(player3Id, at: .quarterback)

        #expect(depthChart.depthPosition(for: player1Id, at: .quarterback) == 1)
        #expect(depthChart.depthPosition(for: player2Id, at: .quarterback) == 2)
        #expect(depthChart.depthPosition(for: player3Id, at: .quarterback) == 3)
    }
}
