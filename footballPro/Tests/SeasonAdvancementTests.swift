//
//  SeasonAdvancementTests.swift
//  footballProTests
//
//  Comprehensive tests for season-to-season advancement (Issue #1)
//

import Foundation
import Testing
@testable import footballPro

// MARK: - Player Season Advancement Tests

@Suite("Player Season Advancement Tests")
struct PlayerSeasonAdvancementTests {

    @Test("Player archives season stats to career stats")
    func testArchiveSeasonStats() {
        var player = PlayerGenerator.generate(position: .quarterback, tier: .starter)

        // Add some season stats
        player.seasonStats.gamesPlayed = 16
        player.seasonStats.passingYards = 4000
        player.seasonStats.passingTouchdowns = 30
        player.seasonStats.interceptions = 10
        player.seasonStats.rushingYards = 200
        player.seasonStats.rushingTouchdowns = 2

        // Archive stats
        player.archiveSeasonStats()

        // Career stats should have the values
        #expect(player.careerStats.gamesPlayed == 16)
        #expect(player.careerStats.passingYards == 4000)
        #expect(player.careerStats.passingTouchdowns == 30)
        #expect(player.careerStats.interceptions == 10)
        #expect(player.careerStats.rushingYards == 200)
        #expect(player.careerStats.rushingTouchdowns == 2)

        // Season stats should be reset
        #expect(player.seasonStats.gamesPlayed == 0)
        #expect(player.seasonStats.passingYards == 0)
        #expect(player.seasonStats.passingTouchdowns == 0)
    }

    @Test("Player career stats accumulate across multiple seasons")
    func testCareerStatsAccumulate() {
        var player = PlayerGenerator.generate(position: .runningBack, tier: .starter)

        // Season 1
        player.seasonStats.rushingYards = 1200
        player.seasonStats.rushingTouchdowns = 10
        player.seasonStats.gamesPlayed = 16
        player.archiveSeasonStats()

        // Season 2
        player.seasonStats.rushingYards = 1400
        player.seasonStats.rushingTouchdowns = 12
        player.seasonStats.gamesPlayed = 16
        player.archiveSeasonStats()

        // Season 3
        player.seasonStats.rushingYards = 1100
        player.seasonStats.rushingTouchdowns = 8
        player.seasonStats.gamesPlayed = 14
        player.archiveSeasonStats()

        // Career totals
        #expect(player.careerStats.rushingYards == 3700)
        #expect(player.careerStats.rushingTouchdowns == 30)
        #expect(player.careerStats.gamesPlayed == 46)
    }

    @Test("Player age increments on season advancement")
    func testPlayerAgeIncrement() {
        var player = PlayerGenerator.generate(position: .wideReceiver, tier: .starter)
        let initialAge = player.age

        player.advanceToNextSeason()

        #expect(player.age == initialAge + 1)
    }

    @Test("Player experience increments on season advancement")
    func testPlayerExperienceIncrement() {
        var player = PlayerGenerator.generate(position: .cornerback, tier: .starter)
        let initialExperience = player.experience

        player.advanceToNextSeason()

        #expect(player.experience == initialExperience + 1)
    }

    @Test("Player contract years decrement on season advancement")
    func testContractYearsDecrement() {
        var player = PlayerGenerator.generate(position: .quarterback, tier: .starter)
        player.contract = Contract(
            yearsRemaining: 4,
            totalValue: 100000,
            yearlyValues: [20000, 25000, 25000, 30000],
            signingBonus: 10000,
            guaranteedMoney: 50000
        )

        player.advanceToNextSeason()

        #expect(player.contract.yearsRemaining == 3)
        #expect(player.contract.yearlyValues.count == 3)
        #expect(player.contract.yearlyValues[0] == 25000) // First year removed
    }

    @Test("Player contract expired detection works")
    func testContractExpiredDetection() {
        var player = PlayerGenerator.generate(position: .middleLinebacker, tier: .backup)

        // Multi-year contract - not expired
        player.contract = Contract(
            yearsRemaining: 2,
            totalValue: 10000,
            yearlyValues: [5000, 5000],
            signingBonus: 1000,
            guaranteedMoney: 5000
        )
        #expect(player.isContractExpired == false)

        // One year left - not expired yet
        player.advanceToNextSeason()
        #expect(player.isContractExpired == false)

        // Now expired
        player.advanceToNextSeason()
        #expect(player.isContractExpired == true)
    }

    @Test("Player status resets to healthy on season advancement")
    func testPlayerStatusResets() {
        var player = PlayerGenerator.generate(position: .runningBack, tier: .starter)
        player.status = PlayerStatus(
            health: 60,
            fatigue: 80,
            morale: 50,
            injuryType: .moderate,
            weeksInjured: 3
        )

        player.advanceToNextSeason()

        #expect(player.status.health == 100)
        #expect(player.status.fatigue == 0)
        #expect(player.status.injuryType == nil)
    }

    @Test("Defensive stats archive correctly")
    func testDefensiveStatsArchive() {
        var player = PlayerGenerator.generate(position: .middleLinebacker, tier: .starter)

        player.seasonStats.totalTackles = 120
        player.seasonStats.soloTackles = 80
        player.seasonStats.assistedTackles = 40
        player.seasonStats.defSacks = 5.5
        player.seasonStats.interceptionsDef = 2
        player.seasonStats.forcedFumbles = 3

        player.archiveSeasonStats()

        #expect(player.careerStats.totalTackles == 120)
        #expect(player.careerStats.soloTackles == 80)
        #expect(player.careerStats.assistedTackles == 40)
        #expect(player.careerStats.defSacks == 5.5)
        #expect(player.careerStats.interceptionsDef == 2)
        #expect(player.careerStats.forcedFumbles == 3)
    }

    @Test("Special teams stats archive correctly")
    func testSpecialTeamsStatsArchive() {
        var player = PlayerGenerator.generate(position: .kicker, tier: .starter)

        player.seasonStats.fieldGoalsMade = 28
        player.seasonStats.fieldGoalsAttempted = 32
        player.seasonStats.extraPointsMade = 40
        player.seasonStats.extraPointsAttempted = 41

        player.archiveSeasonStats()

        #expect(player.careerStats.fieldGoalsMade == 28)
        #expect(player.careerStats.fieldGoalsAttempted == 32)
        #expect(player.careerStats.extraPointsMade == 40)
        #expect(player.careerStats.extraPointsAttempted == 41)
    }
}

// MARK: - Team Season Advancement Tests

@Suite("Team Season Advancement Tests")
struct TeamSeasonAdvancementTests {

    @Test("Team archives all player stats")
    func testTeamArchivesAllPlayerStats() {
        var team = TeamGenerator.generateTeam(index: 0, divisionId: UUID())

        // Add stats to some players
        for i in 0..<min(5, team.roster.count) {
            team.roster[i].seasonStats.gamesPlayed = 16
            team.roster[i].seasonStats.totalTackles = 50
        }

        team.archiveAllPlayerStats()

        // All players should have archived stats and reset season stats
        for i in 0..<min(5, team.roster.count) {
            #expect(team.roster[i].careerStats.gamesPlayed == 16)
            #expect(team.roster[i].seasonStats.gamesPlayed == 0)
        }
    }

    @Test("Team advances all players to next season")
    func testTeamAdvancesAllPlayers() {
        var team = TeamGenerator.generateTeam(index: 0, divisionId: UUID())

        let initialAges = team.roster.map { $0.age }

        team.advanceAllPlayersToNextSeason()

        for (index, player) in team.roster.enumerated() {
            #expect(player.age == initialAges[index] + 1)
        }
    }

    @Test("Team identifies expired contracts")
    func testTeamIdentifiesExpiredContracts() {
        var team = TeamGenerator.generateTeam(index: 0, divisionId: UUID())

        // Manually set some contracts to expire
        if team.roster.count >= 2 {
            team.roster[0].contract.yearsRemaining = 0
            team.roster[1].contract.yearsRemaining = 0
        }

        let expired = team.playersWithExpiredContracts()

        #expect(expired.count >= 2)
    }

    @Test("Team releases expired contracts")
    func testTeamReleasesExpiredContracts() {
        var team = TeamGenerator.generateTeam(index: 0, divisionId: UUID())
        let initialRosterSize = team.roster.count

        // Set two contracts to expire
        if team.roster.count >= 2 {
            team.roster[0].contract.yearsRemaining = 0
            team.roster[1].contract.yearsRemaining = 0
        }

        let released = team.releaseExpiredContracts()

        #expect(released.count >= 2)
        #expect(team.roster.count == initialRosterSize - released.count)
    }

    @Test("Team record resets for new season")
    func testTeamRecordResets() {
        var team = TeamGenerator.generateTeam(index: 0, divisionId: UUID())

        // Add some wins/losses
        team.record.wins = 10
        team.record.losses = 6
        team.record.ties = 0

        team.resetRecord()

        #expect(team.record.wins == 0)
        #expect(team.record.losses == 0)
        #expect(team.record.ties == 0)
    }
}

// MARK: - League Season Advancement Tests

@Suite("League Season Advancement Tests")
struct LeagueSeasonAdvancementTests {

    /// Helper to create a completed season with a champion
    private func createCompletedSeason(for league: League, year: Int) -> Season {
        var season = Season(year: year, divisions: league.divisions)

        // Initialize standings
        for team in league.teams {
            season.standings[team.id] = StandingsEntry(teamId: team.id)
        }

        // Create schedule
        var schedule: [ScheduledGame] = []
        let allTeamIds = league.teams.map { $0.id }

        for week in 1...14 {
            var scheduled: Set<UUID> = []
            for i in 0..<allTeamIds.count {
                let teamA = allTeamIds[i]
                if scheduled.contains(teamA) { continue }

                let opponentIndex = (i + week) % allTeamIds.count
                let teamB = allTeamIds[opponentIndex]
                if teamA == teamB || scheduled.contains(teamB) { continue }

                var game = ScheduledGame(
                    homeTeamId: teamA,
                    awayTeamId: teamB,
                    week: week
                )
                // Mark as completed
                game.result = GameResult(
                    homeScore: 21,
                    awayScore: 14,
                    homeTeamStats: TeamGameStats(),
                    awayTeamStats: TeamGameStats(),
                    winnerId: teamA,
                    loserId: teamB
                )
                schedule.append(game)
                scheduled.insert(teamA)
                scheduled.insert(teamB)
            }
        }
        season.schedule = schedule

        // Set up playoffs with champion
        let qualifiedTeams = Array(league.teams.prefix(4).map { $0.id })
        season.initializePlayoffs(qualifiedTeams: qualifiedTeams)

        // Complete semifinal games
        var bracket = season.playoffBracket!
        var semis = bracket.games(for: .conference)
        for i in 0..<semis.count {
            semis[i].result = GameResult(
                homeScore: 28,
                awayScore: 21,
                homeTeamStats: TeamGameStats(),
                awayTeamStats: TeamGameStats(),
                winnerId: semis[i].homeTeamId,
                loserId: semis[i].awayTeamId
            )
        }
        bracket.games[.conference] = semis
        season.playoffBracket = bracket

        // Advance to create championship
        season.advancePlayoffs()

        // Complete championship
        var finals = season.playoffBracket!.games(for: .championship)
        if !finals.isEmpty {
            finals[0].result = GameResult(
                homeScore: 35,
                awayScore: 28,
                homeTeamStats: TeamGameStats(),
                awayTeamStats: TeamGameStats(),
                winnerId: finals[0].homeTeamId,
                loserId: finals[0].awayTeamId
            )
            season.playoffBracket?.games[.championship] = finals
            season.playoffBracket?.championId = finals[0].homeTeamId
        }

        return season
    }

    @Test("League advances to next season year")
    func testLeagueAdvancesYear() {
        var league = LeagueGenerator.generateLeague()
        let completedSeason = createCompletedSeason(for: league, year: 2024)

        let newSeason = league.advanceToNextSeason(completedSeason: completedSeason)

        #expect(newSeason.year == 2025)
    }

    @Test("League records season history")
    func testLeagueRecordsHistory() {
        var league = LeagueGenerator.generateLeague()
        let completedSeason = createCompletedSeason(for: league, year: 2024)

        #expect(league.history.isEmpty)

        _ = league.advanceToNextSeason(completedSeason: completedSeason)

        #expect(league.history.count == 1)
        #expect(league.history[0].year == 2024)
        #expect(league.history[0].championTeamId == completedSeason.playoffBracket?.championId)
    }

    @Test("League archives all player stats")
    func testLeagueArchivesPlayerStats() {
        var league = LeagueGenerator.generateLeague()

        // Add stats to a player
        let teamIndex = 0
        let playerIndex = 0
        league.teams[teamIndex].roster[playerIndex].seasonStats.gamesPlayed = 16
        league.teams[teamIndex].roster[playerIndex].seasonStats.passingYards = 4000

        let completedSeason = createCompletedSeason(for: league, year: 2024)
        _ = league.advanceToNextSeason(completedSeason: completedSeason)

        // Stats should be archived
        #expect(league.teams[teamIndex].roster[playerIndex].careerStats.gamesPlayed == 16)
        #expect(league.teams[teamIndex].roster[playerIndex].careerStats.passingYards == 4000)

        // Season stats should be reset
        #expect(league.teams[teamIndex].roster[playerIndex].seasonStats.gamesPlayed == 0)
    }

    @Test("Expired contracts become free agents")
    func testExpiredContractsBecomeFreeAgents() {
        var league = LeagueGenerator.generateLeague()
        let initialFreeAgentCount = league.freeAgents.count

        // Set some contracts to expire
        league.teams[0].roster[0].contract.yearsRemaining = 0
        league.teams[0].roster[1].contract.yearsRemaining = 0

        let completedSeason = createCompletedSeason(for: league, year: 2024)
        _ = league.advanceToNextSeason(completedSeason: completedSeason)

        // Should have at least 2 more free agents (could be more from other teams)
        #expect(league.freeAgents.count >= initialFreeAgentCount + 2)
    }

    @Test("League generates new draft class")
    func testLeagueGeneratesNewDraftClass() {
        var league = LeagueGenerator.generateLeague()
        let completedSeason = createCompletedSeason(for: league, year: 2024)

        _ = league.advanceToNextSeason(completedSeason: completedSeason)

        #expect(league.draftClass != nil)
        #expect(league.draftClass?.year == 2025)
        #expect(league.draftClass?.prospects.count ?? 0 > 0)
    }

    @Test("League clears pending trades")
    func testLeagueClearsPendingTrades() {
        var league = LeagueGenerator.generateLeague()

        // Add a pending trade
        let trade = TradeOffer(
            proposingTeamId: league.teams[0].id,
            receivingTeamId: league.teams[1].id
        )
        league.pendingTrades.append(trade)

        let completedSeason = createCompletedSeason(for: league, year: 2024)
        _ = league.advanceToNextSeason(completedSeason: completedSeason)

        #expect(league.pendingTrades.isEmpty)
    }

    @Test("New season has fresh schedule")
    func testNewSeasonHasFreshSchedule() {
        var league = LeagueGenerator.generateLeague()
        let completedSeason = createCompletedSeason(for: league, year: 2024)

        let newSeason = league.advanceToNextSeason(completedSeason: completedSeason)

        #expect(newSeason.schedule.count > 0)
        #expect(newSeason.currentWeek == 1)

        // All games should be incomplete
        for game in newSeason.schedule {
            #expect(game.result == nil)
        }
    }

    @Test("New season has fresh standings")
    func testNewSeasonHasFreshStandings() {
        var league = LeagueGenerator.generateLeague()
        let completedSeason = createCompletedSeason(for: league, year: 2024)

        let newSeason = league.advanceToNextSeason(completedSeason: completedSeason)

        // All teams should have zero record
        for teamId in league.teams.map({ $0.id }) {
            let standings = newSeason.standings[teamId]
            #expect(standings != nil)
            #expect(standings?.wins == 0)
            #expect(standings?.losses == 0)
        }
    }

    @Test("Team records reset after advancement")
    func testTeamRecordsReset() {
        var league = LeagueGenerator.generateLeague()

        // Give teams some wins
        for i in 0..<league.teams.count {
            league.teams[i].record.wins = 10
            league.teams[i].record.losses = 6
        }

        let completedSeason = createCompletedSeason(for: league, year: 2024)
        _ = league.advanceToNextSeason(completedSeason: completedSeason)

        // All teams should have reset records
        for team in league.teams {
            #expect(team.record.wins == 0)
            #expect(team.record.losses == 0)
        }
    }

    @Test("Season complete detection works")
    func testSeasonCompleteDetection() {
        let league = LeagueGenerator.generateLeague()

        // Incomplete season
        let incompleteSeason = SeasonGenerator.generateSeason(for: league)
        #expect(league.isSeasonComplete(incompleteSeason) == false)

        // Complete season
        let completeSeason = createCompletedSeason(for: league, year: 2024)
        #expect(league.isSeasonComplete(completeSeason) == true)
    }

    @Test("Multiple season advancements work correctly")
    func testMultipleSeasonAdvancements() {
        var league = LeagueGenerator.generateLeague()

        // Advance through 3 seasons
        var currentSeason = createCompletedSeason(for: league, year: 2024)

        for expectedYear in [2025, 2026, 2027] {
            let newSeason = league.advanceToNextSeason(completedSeason: currentSeason)
            #expect(newSeason.year == expectedYear)
            #expect(league.history.count == expectedYear - 2024)
            currentSeason = createCompletedSeason(for: league, year: expectedYear)
        }

        #expect(league.history.count == 3)
    }

    @Test("Player ages accumulate over multiple seasons")
    func testPlayerAgesAccumulateOverSeasons() {
        var league = LeagueGenerator.generateLeague()
        let initialAge = league.teams[0].roster[0].age

        var currentSeason = createCompletedSeason(for: league, year: 2024)
        _ = league.advanceToNextSeason(completedSeason: currentSeason)

        currentSeason = createCompletedSeason(for: league, year: 2025)
        _ = league.advanceToNextSeason(completedSeason: currentSeason)

        currentSeason = createCompletedSeason(for: league, year: 2026)
        _ = league.advanceToNextSeason(completedSeason: currentSeason)

        // Player should be 3 years older
        #expect(league.teams[0].roster[0].age == initialAge + 3)
    }
}

// MARK: - Season Advancement Integration Tests

@Suite("Season Advancement Integration Tests")
struct SeasonAdvancementIntegrationTests {

    @Test("Full season cycle works end-to-end")
    func testFullSeasonCycle() {
        var league = LeagueGenerator.generateLeague()

        // Simulate a full season
        var season = SeasonGenerator.generateSeason(for: league)

        // Play all regular season games
        for gameIndex in 0..<season.schedule.count {
            let game = season.schedule[gameIndex]
            if game.isPlayoff { continue }

            let result = GameResult(
                homeScore: Int.random(in: 14...42),
                awayScore: Int.random(in: 14...42),
                homeTeamStats: TeamGameStats(),
                awayTeamStats: TeamGameStats(),
                winnerId: Bool.random() ? game.homeTeamId : game.awayTeamId,
                loserId: Bool.random() ? game.awayTeamId : game.homeTeamId
            )
            season.recordGameResult(gameId: game.id, result: result)
        }

        // Initialize playoffs
        let standings = season.overallStandings()
        let qualifiedTeams = standings.prefix(4).map { $0.teamId }
        season.initializePlayoffs(qualifiedTeams: Array(qualifiedTeams))

        // Complete playoffs
        var bracket = season.playoffBracket!
        var semis = bracket.games(for: .conference)
        for i in 0..<semis.count {
            semis[i].result = GameResult(
                homeScore: 28, awayScore: 21,
                homeTeamStats: TeamGameStats(), awayTeamStats: TeamGameStats(),
                winnerId: semis[i].homeTeamId, loserId: semis[i].awayTeamId
            )
        }
        bracket.games[.conference] = semis
        season.playoffBracket = bracket
        season.advancePlayoffs()

        var finals = season.playoffBracket!.games(for: .championship)
        finals[0].result = GameResult(
            homeScore: 35, awayScore: 28,
            homeTeamStats: TeamGameStats(), awayTeamStats: TeamGameStats(),
            winnerId: finals[0].homeTeamId, loserId: finals[0].awayTeamId
        )
        season.playoffBracket?.games[.championship] = finals
        season.playoffBracket?.championId = finals[0].homeTeamId

        // Now advance to next season
        #expect(league.isSeasonComplete(season) == true)

        let newSeason = league.advanceToNextSeason(completedSeason: season)

        // Verify new season is properly set up
        #expect(newSeason.year == season.year + 1)
        #expect(newSeason.currentWeek == 1)
        #expect(newSeason.schedule.count > 0)
        #expect(league.history.count == 1)
        #expect(league.draftClass?.year == newSeason.year)
    }
}
