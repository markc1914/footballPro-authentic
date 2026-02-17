//
//  FastSimEngine.swift
//  footballPro
//
//  Fast simulation engine for CPU-vs-CPU games.
//  Resolves games using team rating averages rather than play-by-play simulation.
//

import Foundation

struct FastSimEngine {

    // MARK: - Public API

    /// Quickly simulate a game between two teams using rating-based resolution.
    /// Returns a full GameResult with realistic scores and box-score stats.
    static func fastSimGame(home: Team, away: Team) -> GameResult {
        // Calculate composite ratings
        let homeOff = offensiveRating(for: home)
        let homeDef = defensiveRating(for: home)
        let homeST = specialTeamsRating(for: home)

        let awayOff = offensiveRating(for: away)
        let awayDef = defensiveRating(for: away)
        let awayST = specialTeamsRating(for: away)

        // Home field advantage: +3 points equivalent
        let homeAdvantage = 3.0

        // Expected points: offense vs opposing defense, scaled to NFL range
        // NFL average is ~21-24 points per team
        let basePoints = 21.0
        let offDefScale = 0.25  // How much ratings affect scoring

        let homeExpected = basePoints
            + (homeOff - awayDef) * offDefScale
            + (Double(homeST) - 70.0) * 0.05
            + homeAdvantage

        let awayExpected = basePoints
            + (awayOff - homeDef) * offDefScale
            + (Double(awayST) - 70.0) * 0.05

        // Add randomness (NFL games have high variance)
        let homeVariance = Double.random(in: -10...10)
        let awayVariance = Double.random(in: -10...10)

        // Clamp to NFL-realistic range (3-45)
        let homeScore = max(3, min(45, Int(homeExpected + homeVariance)))
        let awayScore = max(3, min(45, Int(awayExpected + awayVariance)))

        // Handle ties: in regular season allow them, but scores of exactly equal
        // are fine (NFL had ties in '93)

        // Generate quarter-by-quarter scoring
        let homeQScores = distributeScoreByQuarter(totalScore: homeScore)
        let awayQScores = distributeScoreByQuarter(totalScore: awayScore)

        // Generate box score stats
        let homeStats = generateBoxScore(score: homeScore, offRating: homeOff, defRating: homeDef)
        let awayStats = generateBoxScore(score: awayScore, offRating: awayOff, defRating: awayDef)

        return GameResult(
            homeScore: homeScore,
            awayScore: awayScore,
            homeTeamStats: homeStats,
            awayTeamStats: awayStats,
            winnerId: homeScore > awayScore ? home.id : (awayScore > homeScore ? away.id : nil),
            loserId: homeScore > awayScore ? away.id : (awayScore > homeScore ? home.id : nil)
        )
    }

    // MARK: - Rating Calculations

    /// Offensive rating: weighted average of QB + skill position starters
    private static func offensiveRating(for team: Team) -> Double {
        var totalRating = 0.0
        var totalWeight = 0.0

        // QB is most important
        if let qb = team.starter(at: .quarterback) {
            totalRating += Double(qb.overall) * 3.0
            totalWeight += 3.0
        }

        // Skill positions
        let skillPositions: [(Position, Double)] = [
            (.runningBack, 2.0),
            (.wideReceiver, 2.0),
            (.tightEnd, 1.5),
            (.fullback, 0.5)
        ]

        for (pos, weight) in skillPositions {
            if let player = team.starter(at: pos) {
                totalRating += Double(player.overall) * weight
                totalWeight += weight
            }
        }

        // O-line average
        let oLinePositions: [Position] = [.leftTackle, .leftGuard, .center, .rightGuard, .rightTackle]
        var oLineTotal = 0.0
        var oLineCount = 0.0
        for pos in oLinePositions {
            if let player = team.starter(at: pos) {
                oLineTotal += Double(player.overall)
                oLineCount += 1.0
            }
        }
        if oLineCount > 0 {
            totalRating += (oLineTotal / oLineCount) * 1.5
            totalWeight += 1.5
        }

        return totalWeight > 0 ? totalRating / totalWeight : 70.0
    }

    /// Defensive rating: weighted average of all defensive starters
    private static func defensiveRating(for team: Team) -> Double {
        var totalRating = 0.0
        var totalWeight = 0.0

        let defPositions: [(Position, Double)] = [
            (.defensiveEnd, 2.0),
            (.defensiveTackle, 1.5),
            (.outsideLinebacker, 1.5),
            (.middleLinebacker, 2.0),
            (.cornerback, 2.0),
            (.freeSafety, 1.5),
            (.strongSafety, 1.0)
        ]

        for (pos, weight) in defPositions {
            if let player = team.starter(at: pos) {
                totalRating += Double(player.overall) * weight
                totalWeight += weight
            }
        }

        return totalWeight > 0 ? totalRating / totalWeight : 70.0
    }

    /// Special teams rating from K + P
    private static func specialTeamsRating(for team: Team) -> Int {
        let kicker = team.starter(at: .kicker)?.overall ?? 70
        let punter = team.starter(at: .punter)?.overall ?? 70
        return (kicker + punter) / 2
    }

    // MARK: - Score Distribution

    /// Distribute total score across 4 quarters in NFL-realistic fashion.
    /// Q2 and Q4 tend to have slightly more scoring.
    private static func distributeScoreByQuarter(totalScore: Int) -> [Int] {
        guard totalScore > 0 else { return [0, 0, 0, 0] }

        // Weight distribution: Q1=20%, Q2=30%, Q3=20%, Q4=30%
        let weights = [0.20, 0.30, 0.20, 0.30]
        var quarters = [0, 0, 0, 0]
        var remaining = totalScore

        // First pass: assign proportional amounts rounded down
        for i in 0..<3 {
            let share = Int(Double(totalScore) * weights[i])
            quarters[i] = share
            remaining -= share
        }
        quarters[3] = remaining

        // Ensure scores are realistic (multiples of 1-7 per scoring event)
        // Shuffle a few points between quarters for variety
        let shuffleAmount = Int.random(in: 0...3)
        if shuffleAmount > 0 && quarters.max()! >= shuffleAmount {
            let fromQ = (0..<4).filter { quarters[$0] >= shuffleAmount }.randomElement() ?? 0
            let toQ = (0..<4).filter { $0 != fromQ }.randomElement() ?? 0
            quarters[fromQ] -= shuffleAmount
            quarters[toQ] += shuffleAmount
        }

        return quarters
    }

    // MARK: - Box Score Generation

    /// Generate realistic box-score stats based on final score and ratings.
    private static func generateBoxScore(score: Int, offRating: Double, defRating: Double) -> TeamGameStats {
        var stats = TeamGameStats()

        // Higher scoring teams tend to have more yards
        let yardMultiplier = 1.0 + (Double(score) - 21.0) * 0.02

        // Pass/rush split influenced by offensive rating
        let passRatio = 0.55 + (offRating - 70.0) * 0.003  // Higher rated offenses pass slightly more
        let clampedPassRatio = max(0.45, min(0.65, passRatio))

        // Total yards: NFL average ~330, scale with score
        let totalYards = Int(Double.random(in: 280...400) * yardMultiplier)
        let passingYards = Int(Double(totalYards) * clampedPassRatio)
        let rushingYards = totalYards - passingYards

        stats.totalYards = totalYards
        stats.passingYards = passingYards
        stats.rushingYards = rushingYards
        stats.firstDowns = totalYards / Int.random(in: 14...18)

        // Turnovers: inversely related to offensive rating
        let turnoverChance = max(0.0, (80.0 - offRating) * 0.02)
        stats.turnovers = Int(turnoverChance * Double.random(in: 0.5...2.0))

        // 3rd down: NFL average ~38-42%
        stats.thirdDownAttempts = Int.random(in: 10...16)
        let convRate = 0.35 + (offRating - 70.0) * 0.005
        stats.thirdDownConversions = Int(Double(stats.thirdDownAttempts) * max(0.25, min(0.55, convRate)))

        // Time of possession: ~28-32 minutes per team, slightly more for higher rushing
        let rushPct = Double(rushingYards) / Double(max(1, totalYards))
        let topMinutes = 28.0 + rushPct * 8.0 + Double.random(in: -2...2)
        stats.timeOfPossession = Int(topMinutes * 60.0)

        // Penalties
        stats.penalties = Int.random(in: 3...9)
        stats.penaltyYards = stats.penalties * Int.random(in: 7...12)

        return stats
    }
}
