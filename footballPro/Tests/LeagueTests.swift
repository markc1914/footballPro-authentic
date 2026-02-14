//
//  LeagueTests.swift
//  footballProTests
//
//  Tests for League model and season management
//

import Foundation
import Testing
@testable import footballPro

@Suite("League Tests")
struct LeagueTests {

    // MARK: - League Generation

    @Test("League generator creates valid league")
    func testLeagueGeneration() {
        let league = LeagueGenerator.generateLeague()

        #expect(league.teams.count == 8)
        #expect(league.divisions.count == 2)
        #expect(league.freeAgents.count > 0)
        #expect(league.draftClass != nil)
    }

    @Test("Each division has correct number of teams")
    func testDivisionTeamCount() {
        let league = LeagueGenerator.generateLeague()

        for division in league.divisions {
            #expect(division.teamIds.count == 4)
        }
    }

    @Test("League can find team by ID")
    func testFindTeamById() {
        let league = LeagueGenerator.generateLeague()
        let team = league.teams.first!

        let foundTeam = league.team(withId: team.id)
        #expect(foundTeam != nil)
        #expect(foundTeam?.id == team.id)
    }

    @Test("League can find team by abbreviation")
    func testFindTeamByAbbreviation() {
        let league = LeagueGenerator.generateLeague()
        let team = league.teams.first!

        let foundTeam = league.team(withAbbreviation: team.abbreviation)
        #expect(foundTeam != nil)
        #expect(foundTeam?.abbreviation == team.abbreviation)
    }

    // MARK: - Free Agency

    @Test("Free agents have valid asking prices")
    func testFreeAgentAskingPrices() {
        let league = LeagueGenerator.generateLeague()

        for freeAgent in league.freeAgents {
            #expect(freeAgent.askingPrice > 0)
            // Higher rated players should ask for more
            if freeAgent.player.overall >= 80 {
                #expect(freeAgent.askingPrice > 3000)
            }
        }
    }

    @Test("Signing free agent moves player to team")
    func testSignFreeAgent() {
        var league = LeagueGenerator.generateLeague()
        let team = league.teams.first!
        let freeAgent = league.freeAgents.first!
        let initialRosterCount = team.roster.count

        let contract = Contract.veteran(rating: freeAgent.player.overall, position: freeAgent.player.position)
        league.signFreeAgent(playerId: freeAgent.id, to: team.id, contract: contract)

        let updatedTeam = league.team(withId: team.id)!
        #expect(updatedTeam.roster.count == initialRosterCount + 1)
        #expect(!league.freeAgents.contains { $0.id == freeAgent.id })
    }

    // MARK: - Trading

    @Test("Trade offer can be created")
    func testTradeOfferCreation() {
        let league = LeagueGenerator.generateLeague()
        let team1 = league.teams[0]
        let team2 = league.teams[1]

        var trade = TradeOffer(proposingTeamId: team1.id, receivingTeamId: team2.id)
        trade.playersOffered = [team1.roster[0].id]
        trade.playersRequested = [team2.roster[0].id]

        #expect(trade.status == .pending)
        #expect(trade.playersOffered.count == 1)
        #expect(trade.playersRequested.count == 1)
    }
}

// MARK: - Season Tests

@Suite("Season Tests")
struct SeasonTests {

    @Test("Season generator creates valid schedule")
    func testSeasonGeneration() {
        let league = LeagueGenerator.generateLeague()
        let season = SeasonGenerator.generateSeason(for: league)

        #expect(season.currentWeek == 1)
        #expect(season.totalWeeks == 14)
        #expect(season.schedule.count > 0)
        #expect(season.standings.count == 8)
    }

    @Test("Each team has correct number of games")
    func testTeamGameCount() {
        let league = LeagueGenerator.generateLeague()
        let season = SeasonGenerator.generateSeason(for: league)

        for team in league.teams {
            let teamGames = season.games(for: team.id)
            #expect(teamGames.count == 14, "Team \(team.name) has \(teamGames.count) games, expected 14")
        }
    }

    @Test("Standings entries exist for all teams")
    func testStandingsEntries() {
        let league = LeagueGenerator.generateLeague()
        let season = SeasonGenerator.generateSeason(for: league)

        for team in league.teams {
            #expect(season.standings[team.id] != nil)
        }
    }

    @Test("Recording game result updates standings")
    func testRecordGameResult() {
        let league = LeagueGenerator.generateLeague()
        var season = SeasonGenerator.generateSeason(for: league)

        let game = season.schedule.first!
        let result = GameResult(
            homeScore: 28,
            awayScore: 21,
            homeTeamStats: TeamGameStats(),
            awayTeamStats: TeamGameStats(),
            winnerId: game.homeTeamId,
            loserId: game.awayTeamId
        )

        season.recordGameResult(gameId: game.id, result: result)

        let homeStandings = season.standings[game.homeTeamId]!
        let awayStandings = season.standings[game.awayTeamId]!

        #expect(homeStandings.wins == 1)
        #expect(homeStandings.losses == 0)
        #expect(awayStandings.wins == 0)
        #expect(awayStandings.losses == 1)
    }

    @Test("Division standings sort correctly")
    func testDivisionStandingsSorting() {
        let league = LeagueGenerator.generateLeague()
        var season = SeasonGenerator.generateSeason(for: league)

        let division = league.divisions.first!
        let teamsInDivision = division.teamIds

        // Give first team some wins
        if var entry = season.standings[teamsInDivision[0]] {
            entry.wins = 5
            entry.losses = 1
            entry.pointsFor = 150
            entry.pointsAgainst = 100
            season.standings[teamsInDivision[0]] = entry
        }

        // Give second team fewer wins
        if var entry = season.standings[teamsInDivision[1]] {
            entry.wins = 3
            entry.losses = 3
            season.standings[teamsInDivision[1]] = entry
        }

        let standings = season.divisionStandings(for: division.id)

        #expect(standings[0].teamId == teamsInDivision[0], "Team with best record should be first")
    }

    // MARK: - Playoffs

    @Test("Playoff initialization creates bracket")
    func testPlayoffInitialization() {
        let league = LeagueGenerator.generateLeague()
        var season = SeasonGenerator.generateSeason(for: league)

        let qualifiedTeams = Array(league.teams.prefix(4).map { $0.id })
        season.initializePlayoffs(qualifiedTeams: qualifiedTeams)

        #expect(season.playoffBracket != nil)

        let semis = season.playoffBracket!.games(for: .conference)
        #expect(semis.count == 2)
    }

    @Test("Advancing playoffs creates championship game")
    func testPlayoffAdvancement() {
        let league = LeagueGenerator.generateLeague()
        var season = SeasonGenerator.generateSeason(for: league)

        let qualifiedTeams = Array(league.teams.prefix(4).map { $0.id })
        season.initializePlayoffs(qualifiedTeams: qualifiedTeams)

        // Simulate semifinal results
        var bracket = season.playoffBracket!
        var semis = bracket.games(for: .conference)

        for i in 0..<semis.count {
            let result = GameResult(
                homeScore: 28,
                awayScore: 21,
                homeTeamStats: TeamGameStats(),
                awayTeamStats: TeamGameStats(),
                winnerId: semis[i].homeTeamId,
                loserId: semis[i].awayTeamId
            )
            semis[i].result = result
        }

        bracket.games[.conference] = semis
        season.playoffBracket = bracket

        season.advancePlayoffs()

        let finals = season.playoffBracket!.games(for: .championship)
        #expect(finals.count == 1)
    }
}

// MARK: - Standings Entry Tests

@Suite("Standings Entry Tests")
struct StandingsEntryTests {

    @Test("Win percentage calculates correctly")
    func testWinPercentage() {
        var entry = StandingsEntry(teamId: UUID())
        entry.wins = 10
        entry.losses = 4
        entry.ties = 0

        #expect(entry.winPercentage > 0.71 && entry.winPercentage < 0.72)
    }

    @Test("Streak tracking works correctly")
    func testStreakTracking() {
        var entry = StandingsEntry(teamId: UUID())

        entry.recordWin(points: 21, opponentPoints: 14, isDivision: false)
        #expect(entry.streak == 1)
        #expect(entry.streakDisplay == "W1")

        entry.recordWin(points: 28, opponentPoints: 21, isDivision: false)
        #expect(entry.streak == 2)
        #expect(entry.streakDisplay == "W2")

        entry.recordLoss(points: 14, opponentPoints: 35, isDivision: false)
        #expect(entry.streak == -1)
        #expect(entry.streakDisplay == "L1")
    }

    @Test("Point differential calculates correctly")
    func testPointDifferential() {
        var entry = StandingsEntry(teamId: UUID())

        entry.recordWin(points: 28, opponentPoints: 14, isDivision: false)
        entry.recordWin(points: 21, opponentPoints: 17, isDivision: false)
        entry.recordLoss(points: 10, opponentPoints: 24, isDivision: false)

        // 28+21+10 = 59 for, 14+17+24 = 55 against
        #expect(entry.pointDifferential == 4)
    }
}
