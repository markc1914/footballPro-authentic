//
//  Season.swift
//  footballPro
//
//  Schedule, standings, and playoffs
//

import Foundation

// MARK: - Scheduled Game

struct ScheduledGame: Identifiable, Codable, Equatable {
    let id: UUID
    var homeTeamId: UUID
    var awayTeamId: UUID
    var week: Int
    var isPlayoff: Bool
    var playoffRound: PlayoffRound?
    var gameDate: Date?

    var result: GameResult?

    var isCompleted: Bool {
        result != nil
    }

    init(homeTeamId: UUID, awayTeamId: UUID, week: Int, isPlayoff: Bool = false, playoffRound: PlayoffRound? = nil, gameDate: Date? = nil) {
        self.id = UUID()
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.week = week
        self.isPlayoff = isPlayoff
        self.playoffRound = playoffRound
        self.gameDate = gameDate
        self.result = nil
    }
}

struct GameResult: Codable, Equatable {
    var homeScore: Int
    var awayScore: Int
    var homeTeamStats: TeamGameStats
    var awayTeamStats: TeamGameStats

    var winnerId: UUID?
    var loserId: UUID?
    var isTie: Bool {
        homeScore == awayScore
    }
}

enum PlayoffRound: String, Codable {
    case wildCard = "Wild Card"
    case divisional = "Divisional"
    case conference = "Conference Championship"
    case championship = "Championship"

    var nextRound: PlayoffRound? {
        switch self {
        case .wildCard: return .divisional
        case .divisional: return .conference
        case .conference: return .championship
        case .championship: return nil
        }
    }
}

// MARK: - Division

struct Division: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var teamIds: [UUID]

    init(name: String, teamIds: [UUID] = []) {
        self.id = UUID()
        self.name = name
        self.teamIds = teamIds
    }
}

// MARK: - Standings Entry

struct StandingsEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var teamId: UUID
    var wins: Int
    var losses: Int
    var ties: Int
    var pointsFor: Int
    var pointsAgainst: Int
    var divisionWins: Int
    var divisionLosses: Int
    var streak: Int // Positive = wins, negative = losses

    var gamesPlayed: Int { wins + losses + ties }

    var winPercentage: Double {
        guard gamesPlayed > 0 else { return 0 }
        return (Double(wins) + Double(ties) * 0.5) / Double(gamesPlayed)
    }

    var pointDifferential: Int {
        pointsFor - pointsAgainst
    }

    var record: String {
        ties > 0 ? "\(wins)-\(losses)-\(ties)" : "\(wins)-\(losses)"
    }

    var streakDisplay: String {
        if streak > 0 {
            return "W\(streak)"
        } else if streak < 0 {
            return "L\(abs(streak))"
        }
        return "-"
    }

    init(teamId: UUID) {
        self.id = UUID()
        self.teamId = teamId
        self.wins = 0
        self.losses = 0
        self.ties = 0
        self.pointsFor = 0
        self.pointsAgainst = 0
        self.divisionWins = 0
        self.divisionLosses = 0
        self.streak = 0
    }

    mutating func recordWin(points: Int, opponentPoints: Int, isDivision: Bool) {
        wins += 1
        pointsFor += points
        pointsAgainst += opponentPoints
        if isDivision { divisionWins += 1 }
        streak = streak > 0 ? streak + 1 : 1
    }

    mutating func recordLoss(points: Int, opponentPoints: Int, isDivision: Bool) {
        losses += 1
        pointsFor += points
        pointsAgainst += opponentPoints
        if isDivision { divisionLosses += 1 }
        streak = streak < 0 ? streak - 1 : -1
    }

    mutating func recordTie(points: Int, opponentPoints: Int, isDivision: Bool) {
        ties += 1
        pointsFor += points
        pointsAgainst += opponentPoints
        streak = 0
    }
}

// MARK: - Playoff Bracket

struct PlayoffBracket: Codable, Equatable {
    var games: [PlayoffRound: [ScheduledGame]]
    var championId: UUID?

    init() {
        games = [:]
        for round in [PlayoffRound.wildCard, .divisional, .conference, .championship] {
            games[round] = []
        }
    }

    mutating func addGame(_ game: ScheduledGame, round: PlayoffRound) {
        games[round]?.append(game)
    }

    func games(for round: PlayoffRound) -> [ScheduledGame] {
        games[round] ?? []
    }

    var isComplete: Bool {
        championId != nil
    }
}

// MARK: - Season

struct Season: Identifiable, Codable, Equatable {
    let id: UUID
    var year: Int
    var currentWeek: Int
    var totalWeeks: Int // Regular season weeks

    var divisions: [Division]
    var schedule: [ScheduledGame]
    var standings: [UUID: StandingsEntry] // TeamId -> Standings
    var playoffBracket: PlayoffBracket?

    var isRegularSeason: Bool {
        currentWeek <= totalWeeks
    }

    var isPlayoffs: Bool {
        currentWeek > totalWeeks && playoffBracket != nil
    }

    var isComplete: Bool {
        playoffBracket?.isComplete ?? false
    }

    init(year: Int, divisions: [Division], totalWeeks: Int = 14) {
        self.id = UUID()
        self.year = year
        self.currentWeek = 1
        self.totalWeeks = totalWeeks
        self.divisions = divisions
        self.schedule = []
        self.standings = [:]
        self.playoffBracket = nil
    }

    func gamesForWeek(_ week: Int) -> [ScheduledGame] {
        schedule.filter { $0.week == week }
    }

    func games(for teamId: UUID) -> [ScheduledGame] {
        schedule.filter { $0.homeTeamId == teamId || $0.awayTeamId == teamId }
    }

    func nextGame(for teamId: UUID) -> ScheduledGame? {
        games(for: teamId)
            .filter { !$0.isCompleted }
            .sorted { $0.week < $1.week }
            .first
    }

    func divisionStandings(for divisionId: UUID) -> [StandingsEntry] {
        guard let division = divisions.first(where: { $0.id == divisionId }) else { return [] }
        return division.teamIds
            .compactMap { standings[$0] }
            .sorted { compareStandings($0, $1) }
    }

    func overallStandings() -> [StandingsEntry] {
        Array(standings.values).sorted { compareStandings($0, $1) }
    }

    private func compareStandings(_ a: StandingsEntry, _ b: StandingsEntry) -> Bool {
        // 1. Win percentage
        if a.winPercentage != b.winPercentage {
            return a.winPercentage > b.winPercentage
        }
        // 2. Division record
        let aDivPct = a.divisionWins + a.divisionLosses > 0 ?
            Double(a.divisionWins) / Double(a.divisionWins + a.divisionLosses) : 0
        let bDivPct = b.divisionWins + b.divisionLosses > 0 ?
            Double(b.divisionWins) / Double(b.divisionWins + b.divisionLosses) : 0
        if aDivPct != bDivPct {
            return aDivPct > bDivPct
        }
        // 3. Point differential
        return a.pointDifferential > b.pointDifferential
    }

    mutating func recordGameResult(gameId: UUID, result: GameResult) {
        guard let index = schedule.firstIndex(where: { $0.id == gameId }) else { return }
        schedule[index].result = result

        let game = schedule[index]
        let homeTeamId = game.homeTeamId
        let awayTeamId = game.awayTeamId

        // Check if division game
        let isDivision = divisions.contains { div in
            div.teamIds.contains(homeTeamId) && div.teamIds.contains(awayTeamId)
        }

        if result.homeScore > result.awayScore {
            standings[homeTeamId]?.recordWin(points: result.homeScore, opponentPoints: result.awayScore, isDivision: isDivision)
            standings[awayTeamId]?.recordLoss(points: result.awayScore, opponentPoints: result.homeScore, isDivision: isDivision)
        } else if result.awayScore > result.homeScore {
            standings[awayTeamId]?.recordWin(points: result.awayScore, opponentPoints: result.homeScore, isDivision: isDivision)
            standings[homeTeamId]?.recordLoss(points: result.homeScore, opponentPoints: result.awayScore, isDivision: isDivision)
        } else {
            standings[homeTeamId]?.recordTie(points: result.homeScore, opponentPoints: result.awayScore, isDivision: isDivision)
            standings[awayTeamId]?.recordTie(points: result.awayScore, opponentPoints: result.homeScore, isDivision: isDivision)
        }
    }

    mutating func advanceWeek() {
        currentWeek += 1
    }

    mutating func initializePlayoffs(qualifiedTeams: [UUID]) {
        var bracket = PlayoffBracket()

        // 4-team playoff: 2 semifinals + championship
        // Seeds: 1 vs 4, 2 vs 3
        if qualifiedTeams.count >= 4 {
            let semi1 = ScheduledGame(
                homeTeamId: qualifiedTeams[0],
                awayTeamId: qualifiedTeams[3],
                week: totalWeeks + 1,
                isPlayoff: true,
                playoffRound: .conference
            )
            let semi2 = ScheduledGame(
                homeTeamId: qualifiedTeams[1],
                awayTeamId: qualifiedTeams[2],
                week: totalWeeks + 1,
                isPlayoff: true,
                playoffRound: .conference
            )
            bracket.addGame(semi1, round: .conference)
            bracket.addGame(semi2, round: .conference)
            schedule.append(contentsOf: [semi1, semi2])
        }

        playoffBracket = bracket
    }

    mutating func advancePlayoffs() {
        guard var bracket = playoffBracket else { return }

        // Check if conference championship games are complete
        let semis = bracket.games(for: .conference)
        let completedSemis = semis.filter { $0.isCompleted }

        if completedSemis.count == 2 && bracket.games(for: .championship).isEmpty {
            // Create championship game
            let winners = completedSemis.compactMap { game -> UUID? in
                guard let result = game.result else { return nil }
                return result.homeScore > result.awayScore ? game.homeTeamId : game.awayTeamId
            }

            if winners.count == 2 {
                let championship = ScheduledGame(
                    homeTeamId: winners[0],
                    awayTeamId: winners[1],
                    week: totalWeeks + 2,
                    isPlayoff: true,
                    playoffRound: .championship
                )
                bracket.addGame(championship, round: .championship)
                schedule.append(championship)
            }
        }

        // Check if championship is complete
        let finals = bracket.games(for: .championship)
        if let championship = finals.first, let result = championship.result {
            bracket.championId = result.homeScore > result.awayScore ?
                championship.homeTeamId : championship.awayTeamId
        }

        playoffBracket = bracket
    }
}

// MARK: - Season Generator

struct SeasonGenerator {
    static func generateSeason(for league: League, year: Int = 2024) -> Season {
        var season = Season(year: year, divisions: league.divisions)

        // Initialize standings for all teams
        for team in league.teams {
            season.standings[team.id] = StandingsEntry(teamId: team.id)
        }

        // Try authentic schedule template matching league size
        if let data = ScheduleTemplateDecoder.loadDefault(),
           let template = ScheduleTemplateDecoder.template(for: league.teams.count, from: data) {
            season.schedule = buildAuthenticSchedule(template: template, league: league)
            season.totalWeeks = template.weekCount
        } else {
            // Fallback: round-robin
            let (schedule, totalWeeks) = buildRoundRobinSchedule(teams: league.teams.map { $0.id })
            season.schedule = schedule
            season.totalWeeks = totalWeeks
        }

        // Apply authentic calendar dates if available
        if let calendar = CalendarDecoder.loadDefault() {
            let weekDates = calendar.weekDates(for: year)
            for i in season.schedule.indices {
                let weekIdx = season.schedule[i].week - 1
                if weekIdx >= 0 && weekIdx < weekDates.count {
                    season.schedule[i].gameDate = weekDates[weekIdx].resolve(seasonStartYear: year)
                }
            }
        }

        return season
    }

    /// Build schedule from authentic STPL.DAT template
    private static func buildAuthenticSchedule(template: ScheduleTemplate, league: League) -> [ScheduledGame] {
        var schedule: [ScheduledGame] = []
        let teams = league.teams

        for (weekIndex, weekMatchups) in template.weeks.enumerated() {
            for matchup in weekMatchups {
                // Template indices are 1-based, league.teams is 0-based
                let homeIdx = matchup.homeTeamIndex - 1
                let awayIdx = matchup.awayTeamIndex - 1
                guard homeIdx >= 0 && homeIdx < teams.count &&
                      awayIdx >= 0 && awayIdx < teams.count else { continue }

                let game = ScheduledGame(
                    homeTeamId: teams[homeIdx].id,
                    awayTeamId: teams[awayIdx].id,
                    week: weekIndex + 1
                )
                schedule.append(game)
            }
        }

        return schedule
    }

    /// Fallback round-robin schedule generator
    static func buildRoundRobinSchedule(teams allTeamIds: [UUID]) -> ([ScheduledGame], Int) {
        var schedule: [ScheduledGame] = []
        let numTeams = allTeamIds.count

        let hasBye = numTeams % 2 != 0
        let effectiveNumTeams = hasBye ? numTeams + 1 : numTeams
        var teams = allTeamIds

        if hasBye {
            teams.append(UUID())
        }

        var currentRotation = teams
        for weekNum in 1..<effectiveNumTeams {
            var weekGames: [ScheduledGame] = []
            var teamsScheduledThisWeek: Set<UUID> = []

            for i in 0..<effectiveNumTeams / 2 {
                let teamA = currentRotation[i]
                let teamB = currentRotation[effectiveNumTeams - 1 - i]

                if teamA == teams.last && hasBye || teamB == teams.last && hasBye {
                    continue
                }

                guard !teamsScheduledThisWeek.contains(teamA) && !teamsScheduledThisWeek.contains(teamB) else { continue }

                let isTeamAHome = weekNum % 2 == 1

                let game = ScheduledGame(
                    homeTeamId: isTeamAHome ? teamA : teamB,
                    awayTeamId: isTeamAHome ? teamB : teamA,
                    week: weekNum
                )
                weekGames.append(game)
                teamsScheduledThisWeek.insert(teamA)
                teamsScheduledThisWeek.insert(teamB)
            }
            schedule.append(contentsOf: weekGames)

            let fixedTeam = currentRotation[0]
            var rotatedPart = Array(currentRotation.dropFirst())
            rotatedPart.append(rotatedPart.removeFirst())
            currentRotation = [fixedTeam] + rotatedPart
        }

        let firstHalfSchedule = schedule
        let weeksPerHalf = effectiveNumTeams - 1

        for game in firstHalfSchedule {
            let secondHalfGame = ScheduledGame(
                homeTeamId: game.awayTeamId,
                awayTeamId: game.homeTeamId,
                week: game.week + weeksPerHalf
            )
            schedule.append(secondHalfGame)
        }

        let totalWeeks = weeksPerHalf * 2
        return (schedule, totalWeeks)
    }
}
