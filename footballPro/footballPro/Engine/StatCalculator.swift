//
//  StatCalculator.swift
//  footballPro
//
//  Calculates and tracks all player and team stats
//

import Foundation

class StatCalculator {

    // MARK: - QB Rating

    func calculateQBRating(stats: SeasonStats) -> Double {
        guard stats.passAttempts > 0 else { return 0 }

        // NFL Passer Rating Formula
        let att = Double(stats.passAttempts)
        let comp = Double(stats.passCompletions)
        let yards = Double(stats.passingYards)
        let td = Double(stats.passingTouchdowns)
        let int = Double(stats.interceptions)

        // Component A: Completion Percentage
        var a = ((comp / att) - 0.3) * 5
        a = min(max(a, 0), 2.375)

        // Component B: Yards per Attempt
        var b = ((yards / att) - 3) * 0.25
        b = min(max(b, 0), 2.375)

        // Component C: TD Percentage
        var c = (td / att) * 20
        c = min(max(c, 0), 2.375)

        // Component D: INT Percentage
        var d = 2.375 - ((int / att) * 25)
        d = min(max(d, 0), 2.375)

        return ((a + b + c + d) / 6) * 100
    }

    // MARK: - Fantasy Points

    func calculateFantasyPoints(for player: Player) -> Double {
        let stats = player.seasonStats
        var points: Double = 0

        // Passing
        points += Double(stats.passingYards) * 0.04 // 1 point per 25 yards
        points += Double(stats.passingTouchdowns) * 4
        points -= Double(stats.interceptions) * 2

        // Rushing
        points += Double(stats.rushingYards) * 0.1 // 1 point per 10 yards
        points += Double(stats.rushingTouchdowns) * 6

        // Receiving
        points += Double(stats.receptions) * 1 // PPR
        points += Double(stats.receivingYards) * 0.1
        points += Double(stats.receivingTouchdowns) * 6

        // Turnovers
        points -= Double(stats.fumblesLost) * 2

        return points
    }

    // MARK: - Player Value

    func calculatePlayerValue(player: Player) -> Int {
        let overall = player.overall
        let age = player.age
        let experience = player.experience

        // Base value from overall rating
        var value = overall * 100

        // Age adjustment (peak at 27)
        let agePeak = 27
        let ageDiff = abs(age - agePeak)
        value -= ageDiff * 50

        // Experience bonus
        value += min(experience, 5) * 20

        // Position value multiplier
        let positionMultiplier: Double
        switch player.position {
        case .quarterback: positionMultiplier = 2.0
        case .leftTackle, .cornerback: positionMultiplier = 1.3
        case .wideReceiver, .defensiveEnd: positionMultiplier = 1.2
        case .runningBack: positionMultiplier = 0.9 // RBs less valuable in modern NFL
        case .kicker, .punter: positionMultiplier = 0.3
        default: positionMultiplier = 1.0
        }

        return Int(Double(value) * positionMultiplier)
    }

    // MARK: - Team Statistics

    func calculateTeamOffensiveRating(_ team: Team) -> Int {
        let qb = team.starter(at: .quarterback)
        let rb = team.starter(at: .runningBack)
        let wr1 = team.starter(at: .wideReceiver)
        let te = team.starter(at: .tightEnd)
        let lt = team.starter(at: .leftTackle)

        let qbRating = qb?.overall ?? 50
        let rbRating = rb?.overall ?? 50
        let wr1Rating = wr1?.overall ?? 50
        let teRating = te?.overall ?? 50
        let ltRating = lt?.overall ?? 50

        // Weight positions differently
        let weighted = (qbRating * 30 + rbRating * 15 + wr1Rating * 20 + teRating * 10 + ltRating * 25) / 100
        return weighted
    }

    func calculateTeamDefensiveRating(_ team: Team) -> Int {
        let de = team.starter(at: .defensiveEnd)
        let dt = team.starter(at: .defensiveTackle)
        let mlb = team.starter(at: .middleLinebacker)
        let cb1 = team.starter(at: .cornerback)
        let fs = team.starter(at: .freeSafety)

        let deRating = de?.overall ?? 50
        let dtRating = dt?.overall ?? 50
        let mlbRating = mlb?.overall ?? 50
        let cb1Rating = cb1?.overall ?? 50
        let fsRating = fs?.overall ?? 50

        let weighted = (deRating * 20 + dtRating * 15 + mlbRating * 20 + cb1Rating * 25 + fsRating * 20) / 100
        return weighted
    }

    // MARK: - League Leaders

    func calculateLeagueLeaders(teams: [Team]) -> [RecordCategory: (player: Player, value: Int)] {
        var leaders: [RecordCategory: (player: Player, value: Int)] = [:]

        for team in teams {
            for player in team.roster {
                let stats = player.seasonStats

                // Passing yards
                if stats.passingYards > (leaders[.passingYards]?.value ?? 0) {
                    leaders[.passingYards] = (player, stats.passingYards)
                }

                // Passing TDs
                if stats.passingTouchdowns > (leaders[.passingTouchdowns]?.value ?? 0) {
                    leaders[.passingTouchdowns] = (player, stats.passingTouchdowns)
                }

                // Rushing yards
                if stats.rushingYards > (leaders[.rushingYards]?.value ?? 0) {
                    leaders[.rushingYards] = (player, stats.rushingYards)
                }

                // Rushing TDs
                if stats.rushingTouchdowns > (leaders[.rushingTouchdowns]?.value ?? 0) {
                    leaders[.rushingTouchdowns] = (player, stats.rushingTouchdowns)
                }

                // Receiving yards
                if stats.receivingYards > (leaders[.receivingYards]?.value ?? 0) {
                    leaders[.receivingYards] = (player, stats.receivingYards)
                }

                // Receiving TDs
                if stats.receivingTouchdowns > (leaders[.receivingTouchdowns]?.value ?? 0) {
                    leaders[.receivingTouchdowns] = (player, stats.receivingTouchdowns)
                }

                // Receptions
                if stats.receptions > (leaders[.receptions]?.value ?? 0) {
                    leaders[.receptions] = (player, stats.receptions)
                }

                // Sacks
                if stats.defSacks > Double(leaders[.sacks]?.value ?? 0) {
                    leaders[.sacks] = (player, Int(stats.defSacks))
                }

                // Interceptions
                if stats.interceptionsDef > (leaders[.interceptions]?.value ?? 0) {
                    leaders[.interceptions] = (player, stats.interceptionsDef)
                }

                // Tackles
                if stats.totalTackles > (leaders[.tackles]?.value ?? 0) {
                    leaders[.tackles] = (player, stats.totalTackles)
                }
            }
        }

        return leaders
    }

    // MARK: - Advanced Stats

    func calculateYardsPerGame(player: Player) -> Double {
        let games = max(player.seasonStats.gamesPlayed, 1)
        let totalYards = player.seasonStats.rushingYards + player.seasonStats.receivingYards
        return Double(totalYards) / Double(games)
    }

    func calculateTouchdownsPerGame(player: Player) -> Double {
        let games = max(player.seasonStats.gamesPlayed, 1)
        let totalTDs = player.seasonStats.rushingTouchdowns + player.seasonStats.receivingTouchdowns
        return Double(totalTDs) / Double(games)
    }

    func calculateCatchRate(player: Player) -> Double {
        guard player.seasonStats.targets > 0 else { return 0 }
        return Double(player.seasonStats.receptions) / Double(player.seasonStats.targets) * 100
    }

    func calculateYardsAfterContact(rushingYards: Int, brokenTackles: Int) -> Double {
        // Estimate YAC based on broken tackles
        return Double(brokenTackles) * 2.5
    }

    // MARK: - Game Score (Bill James style)

    func calculateGameScore(stats: GameStats, position: Position) -> Double {
        var score: Double = 0

        switch position {
        case .quarterback:
            score += Double(stats.passCompletions) * 0.5
            score += Double(stats.passingYards) * 0.04
            score += Double(stats.passingTouchdowns) * 6
            score -= Double(stats.interceptions) * 4

        case .runningBack:
            score += Double(stats.rushAttempts) * 0.2
            score += Double(stats.rushingYards) * 0.1
            score += Double(stats.rushingTouchdowns) * 6
            score += Double(stats.receptions) * 0.5
            score += Double(stats.receivingYards) * 0.08

        case .wideReceiver, .tightEnd:
            score += Double(stats.receptions) * 1
            score += Double(stats.receivingYards) * 0.1
            score += Double(stats.receivingTouchdowns) * 6

        default:
            score += Double(stats.totalTackles) * 1
            score += stats.defSacks * 3
            score += Double(stats.interceptionsDef) * 6
            score += Double(stats.passesDefended) * 1.5
        }

        return score
    }

    // MARK: - Pro Bowl Calculation

    func calculateProBowlScore(player: Player) -> Int {
        var score = player.overall * 2

        // Add stats-based component
        let stats = player.seasonStats
        score += stats.passingTouchdowns * 5
        score += stats.rushingTouchdowns * 5
        score += stats.receivingTouchdowns * 5
        score += stats.passingYards / 100
        score += stats.rushingYards / 50
        score += stats.receivingYards / 50
        score += Int(stats.defSacks) * 3
        score += stats.interceptionsDef * 5

        return score
    }

    // MARK: - Season Summary

    struct SeasonSummaryStats {
        var totalPassingYards: Int
        var totalRushingYards: Int
        var totalPointsScored: Int
        var totalPointsAllowed: Int
        var yardsPerGame: Double
        var pointsPerGame: Double
    }

    func calculateSeasonSummary(for team: Team, games: [GameResult]) -> SeasonSummaryStats {
        var totalPassingYards = 0
        var totalRushingYards = 0
        var totalPointsScored = 0
        var totalPointsAllowed = 0

        for game in games {
            // This would need to track which team is home/away
            totalPassingYards += game.homeTeamStats.passingYards
            totalRushingYards += game.homeTeamStats.rushingYards
            totalPointsScored += game.homeScore
            totalPointsAllowed += game.awayScore
        }

        let gamesCount = max(games.count, 1)

        return SeasonSummaryStats(
            totalPassingYards: totalPassingYards,
            totalRushingYards: totalRushingYards,
            totalPointsScored: totalPointsScored,
            totalPointsAllowed: totalPointsAllowed,
            yardsPerGame: Double(totalPassingYards + totalRushingYards) / Double(gamesCount),
            pointsPerGame: Double(totalPointsScored) / Double(gamesCount)
        )
    }
}
