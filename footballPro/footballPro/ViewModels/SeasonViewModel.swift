//
//  SeasonViewModel.swift
//  footballPro
//
//  Season progression view model
//

import Foundation
import SwiftUI

@MainActor
class SeasonViewModel: ObservableObject {
    @Published var season: Season?
    @Published var league: League?
    @Published var userTeam: Team?

    @Published var selectedWeek: Int = 1
    @Published var showGamePreview = false
    @Published var selectedGame: ScheduledGame?

    // MARK: - Initialization

    func loadSeason(_ season: Season, league: League, userTeam: Team) {
        self.season = season
        self.league = league
        self.userTeam = userTeam
        self.selectedWeek = season.currentWeek
    }

    // MARK: - Schedule

    var currentWeekGames: [ScheduledGame] {
        season?.gamesForWeek(selectedWeek) ?? []
    }

    var userTeamNextGame: ScheduledGame? {
        guard let team = userTeam else { return nil }
        return season?.nextGame(for: team.id)
    }

    var userTeamSchedule: [ScheduledGame] {
        guard let team = userTeam else { return [] }
        return season?.games(for: team.id) ?? []
    }

    var weeksInSeason: [Int] {
        guard let season = season else { return [] }
        return Array(1...season.totalWeeks)
    }

    func isCurrentWeek(_ week: Int) -> Bool {
        week == season?.currentWeek
    }

    func gameResult(for game: ScheduledGame) -> String {
        guard let result = game.result else { return "vs" }

        let isHome = game.homeTeamId == userTeam?.id
        let userScore = isHome ? result.homeScore : result.awayScore
        let oppScore = isHome ? result.awayScore : result.homeScore

        if userScore > oppScore {
            return "W \(userScore)-\(oppScore)"
        } else if userScore < oppScore {
            return "L \(userScore)-\(oppScore)"
        } else {
            return "T \(userScore)-\(oppScore)"
        }
    }

    // MARK: - Standings

    var divisionStandings: [[StandingsEntry]] {
        guard let season = season else { return [] }
        return season.divisions.map { division in
            season.divisionStandings(for: division.id)
        }
    }

    var overallStandings: [StandingsEntry] {
        season?.overallStandings() ?? []
    }

    func teamName(for teamId: UUID) -> String {
        league?.team(withId: teamId)?.fullName ?? "Unknown"
    }

    func teamAbbreviation(for teamId: UUID) -> String {
        league?.team(withId: teamId)?.abbreviation ?? "???"
    }

    func teamRecord(for teamId: UUID) -> String {
        season?.standings[teamId]?.record ?? "0-0"
    }

    func divisionName(for index: Int) -> String {
        guard let season = season, index < season.divisions.count else { return "" }
        return season.divisions[index].name
    }

    // MARK: - Week Progression

    @Published var isSimulating = false

    func canAdvanceWeek() -> Bool {
        guard let season = season else { return false }

        // Check if all games in current week are complete
        let currentWeekGames = season.gamesForWeek(season.currentWeek)
        return currentWeekGames.allSatisfy { $0.isCompleted }
    }

    /// Simulates all unplayed games for a specific week (excluding user's game)
    func simulateWeek(_ week: Int? = nil) async {
        guard var season = season, let league = league else { return }

        let targetWeek = week ?? season.currentWeek
        isSimulating = true
        defer { isSimulating = false }

        let weekGames = season.gamesForWeek(targetWeek)

        for game in weekGames {
            // Skip already completed games
            guard !game.isCompleted else { continue }

            // Skip user's game - they should play it manually
            if let userTeam = userTeam,
               (game.homeTeamId == userTeam.id || game.awayTeamId == userTeam.id) {
                continue
            }

            // Get teams for simulation
            guard let homeTeam = league.team(withId: game.homeTeamId),
                  let awayTeam = league.team(withId: game.awayTeamId) else { continue }

            // Simulate the game
            let result = simulateGame(homeTeam: homeTeam, awayTeam: awayTeam)

            // Record the result
            season.recordGameResult(gameId: game.id, result: result)

            // Small delay to allow UI updates
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        self.season = season

        // Auto-advance week if all games complete
        if canAdvanceWeek() && season.currentWeek <= season.totalWeeks {
            advanceWeek()
        }
    }

    /// Simulates a single game between two teams and returns the result
    private func simulateGame(homeTeam: Team, awayTeam: Team) -> GameResult {
        // Calculate team strengths
        let homeOVR = Double(homeTeam.overallRating)
        let awayOVR = Double(awayTeam.overallRating)

        // Home field advantage (~3 points)
        let homeAdvantage = 3.0

        // Calculate expected point differential
        let expectedDiff = (homeOVR - awayOVR) * 0.3 + homeAdvantage

        // Generate scores with variance
        let baseScore = Double.random(in: 17...28)
        let variance = Double.random(in: -10...10)

        let homeScore = max(0, Int(baseScore + expectedDiff / 2 + variance))
        let awayScore = max(0, Int(baseScore - expectedDiff / 2 + Double.random(in: -8...8)))

        // Generate simplified stats
        let homeStats = generateSimulatedStats(score: homeScore)
        let awayStats = generateSimulatedStats(score: awayScore)

        return GameResult(
            homeScore: homeScore,
            awayScore: awayScore,
            homeTeamStats: homeStats,
            awayTeamStats: awayStats,
            winnerId: homeScore > awayScore ? homeTeam.id : (awayScore > homeScore ? awayTeam.id : nil),
            loserId: homeScore > awayScore ? awayTeam.id : (awayScore > homeScore ? homeTeam.id : nil)
        )
    }

    private func generateSimulatedStats(score: Int) -> TeamGameStats {
        // Estimate stats based on score


        let passingYards = Int.random(in: 150...350)
        let rushingYards = Int.random(in: 80...180)
        let totalYards = passingYards + rushingYards
        let firstDowns = totalYards / 15

        var stats = TeamGameStats()
        stats.totalYards = totalYards
        stats.passingYards = passingYards
        stats.rushingYards = rushingYards
        stats.firstDowns = firstDowns
        stats.turnovers = Int.random(in: 0...2)
        stats.timeOfPossession = Int.random(in: 25...35) * 60 // In seconds

        return stats
    }

    func advanceWeek() {
        season?.advanceWeek()
        selectedWeek = season?.currentWeek ?? 1

        // Check if regular season is over
        if let season = season, season.currentWeek > season.totalWeeks && season.playoffBracket == nil {
            initializePlayoffs()
        }
    }

    // MARK: - Playoffs

    var isPlayoffs: Bool {
        season?.isPlayoffs ?? false
    }

    var playoffBracket: PlayoffBracket? {
        season?.playoffBracket
    }

    func initializePlayoffs() {
        guard var season = season else { return }

        // Get top 4 teams
        let standings = season.overallStandings()
        let qualifiedTeams = standings.prefix(4).map { $0.teamId }

        season.initializePlayoffs(qualifiedTeams: Array(qualifiedTeams))
        self.season = season
    }

    func advancePlayoffs() {
        season?.advancePlayoffs()
    }

    var playoffTeams: [Team] {
        guard let season = season, let bracket = season.playoffBracket else { return [] }

        var teamIds: Set<UUID> = []
        for (_, games) in bracket.games {
            for game in games {
                teamIds.insert(game.homeTeamId)
                teamIds.insert(game.awayTeamId)
            }
        }

        return teamIds.compactMap { league?.team(withId: $0) }
    }

    var champion: Team? {
        guard let championId = season?.playoffBracket?.championId else { return nil }
        return league?.team(withId: championId)
    }

    // MARK: - Game Selection

    func selectGame(_ game: ScheduledGame) {
        selectedGame = game
        showGamePreview = true
    }

    func opponent(for game: ScheduledGame) -> Team? {
        guard let userTeam = userTeam else { return nil }
        let opponentId = game.homeTeamId == userTeam.id ? game.awayTeamId : game.homeTeamId
        return league?.team(withId: opponentId)
    }

    func isHomeGame(_ game: ScheduledGame) -> Bool {
        game.homeTeamId == userTeam?.id
    }

    // MARK: - Season Summary

    var userTeamRecord: String {
        guard let team = userTeam else { return "0-0" }
        return season?.standings[team.id]?.record ?? "0-0"
    }

    var userTeamStandingsPosition: Int {
        guard let team = userTeam else { return 0 }
        let standings = overallStandings
        return (standings.firstIndex { $0.teamId == team.id } ?? -1) + 1
    }

    var userTeamDivisionPosition: Int {
        guard let team = userTeam,
              let division = league?.division(for: team.id),
              let season = season else { return 0 }

        let divisionStandings = season.divisionStandings(for: division.id)
        return (divisionStandings.firstIndex { $0.teamId == team.id } ?? -1) + 1
    }

    var gamesPlayed: Int {
        guard let team = userTeam else { return 0 }
        return season?.standings[team.id]?.gamesPlayed ?? 0
    }

    var gamesRemaining: Int {
        guard let season = season else { return 0 }
        return season.totalWeeks - gamesPlayed
    }
}
