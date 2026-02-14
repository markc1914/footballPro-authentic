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

    var result: GameResult?

    var isCompleted: Bool {
        result != nil
    }

    init(homeTeamId: UUID, awayTeamId: UUID, week: Int, isPlayoff: Bool = false, playoffRound: PlayoffRound? = nil) {
        self.id = UUID()
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.week = week
        self.isPlayoff = isPlayoff
        self.playoffRound = playoffRound
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
    static func generateSeason(for league: League) -> Season {
        var season = Season(year: 2024, divisions: league.divisions)

        // Initialize standings for all teams
        for team in league.teams {
            season.standings[team.id] = StandingsEntry(teamId: team.id)
        }

        var schedule: [ScheduledGame] = []
        let allTeamIds = league.teams.map { $0.id }
        let numTeams = allTeamIds.count

        // Ensure an even number of teams for standard round-robin. Add a "bye" team if odd.
        let hasBye = numTeams % 2 != 0
        let effectiveNumTeams = hasBye ? numTeams + 1 : numTeams
        var teams = allTeamIds

        if hasBye {
            // Add a placeholder for scheduling if an odd number of teams
            teams.append(UUID()) // Use a dummy UUID for the bye
        }

        // Generate one full round-robin (each team plays every other team once)
        // This will result in (numTeams - 1) weeks, with numTeams/2 games per week.
        var currentRotation = teams
        for weekNum in 1..<effectiveNumTeams {
            var weekGames: [ScheduledGame] = []
            var teamsScheduledThisWeek: Set<UUID> = []

            for i in 0..<effectiveNumTeams / 2 {
                let teamA = currentRotation[i]
                let teamB = currentRotation[effectiveNumTeams - 1 - i]

                // Skip games involving the "bye" team
                if teamA == teams.last && hasBye || teamB == teams.last && hasBye {
                    continue
                }

                // Ensure unique games (no duplicates within the same week)
                guard !teamsScheduledThisWeek.contains(teamA) && !teamsScheduledThisWeek.contains(teamB) else { continue }

                // Alternate home/away based on a consistent pattern (e.g., higher index team is home first)
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

            // Rotate teams (keep first team fixed, rotate others)
            let fixedTeam = currentRotation[0]
            var rotatedPart = Array(currentRotation.dropFirst())
            rotatedPart.append(rotatedPart.removeFirst()) // Rotate the rest
            currentRotation = [fixedTeam] + rotatedPart
        }

        // We want 14 games per team, so we need two full cycles of the (numTeams-1) week schedule
        // The above loop generates (numTeams-1) weeks.
        // For 8 teams, that's 7 weeks.
        // We need 14 weeks for 14 games per team. So we repeat the schedule with home/away flipped and incremented week numbers.
        let firstHalfSchedule = schedule
        let weeksPerHalf = effectiveNumTeams - 1

        for game in firstHalfSchedule {
            // Duplicate the game for the second half of the season, flipping home/away and incrementing week
            let secondHalfGame = ScheduledGame(
                homeTeamId: game.awayTeamId, // Flipped home/away
                awayTeamId: game.homeTeamId,
                week: game.week + weeksPerHalf // Increment week number
            )
            schedule.append(secondHalfGame)
        }

        season.schedule = schedule
        season.totalWeeks = weeksPerHalf * 2 // Should be 14 for 8 teams
        return season
    }
}
