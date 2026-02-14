//
//  DraftEngine.swift
//  footballPro
//
//  Draft class generation and draft logic
//

import Foundation

class DraftEngine {

    // MARK: - Draft Prospect

    struct DraftProspect: Identifiable, Equatable {
        let id: UUID
        var player: Player
        var projectedRound: Int
        var scoutingGrade: ScoutingGrade
        var combine: CombineResults
        var collegeStats: CollegeStats
        var strengths: [String]
        var weaknesses: [String]

        var projectedOverall: ClosedRange<Int> {
            let base = player.overall
            let variance = 10 - scoutingGrade.accuracy
            return (base - variance)...(base + variance)
        }
    }

    struct ScoutingGrade: Equatable {
        var overall: Int // 1-100
        var accuracy: Int // How accurate is the scouting (1-10)
        var ceiling: Int // Potential ceiling rating
        var floor: Int // Potential floor rating
        var development: DevelopmentTrait
    }

    enum DevelopmentTrait: String, Codable, CaseIterable {
        case superstar = "Superstar"
        case star = "Star"
        case normal = "Normal"
        case slow = "Slow"

        var progressionMultiplier: Double {
            switch self {
            case .superstar: return 1.5
            case .star: return 1.25
            case .normal: return 1.0
            case .slow: return 0.75
            }
        }
    }

    struct CombineResults: Equatable {
        var fortyYardDash: Double // Seconds
        var benchPress: Int // Reps of 225 lbs
        var verticalJump: Double // Inches
        var broadJump: Int // Inches
        var threeConeDrill: Double // Seconds
        var shuttleRun: Double // Seconds

        static func generate(for position: Position, speed: Int, strength: Int, agility: Int) -> CombineResults {
            // Base times/reps modified by ratings
            let speedMod = Double(speed - 70) / 100.0
            let strengthMod = Double(strength - 70) / 50.0
            let agilityMod = Double(agility - 70) / 100.0

            var fortyBase: Double
            switch position {
            case .cornerback, .wideReceiver, .runningBack, .freeSafety:
                fortyBase = 4.45
            case .quarterback, .strongSafety, .outsideLinebacker:
                fortyBase = 4.65
            case .tightEnd, .middleLinebacker:
                fortyBase = 4.75
            case .defensiveEnd:
                fortyBase = 4.80
            case .leftTackle, .rightTackle, .leftGuard, .rightGuard, .center, .defensiveTackle:
                fortyBase = 5.10
            default:
                fortyBase = 4.80
            }

            return CombineResults(
                fortyYardDash: fortyBase - (speedMod * 0.2) + Double.random(in: -0.05...0.05),
                benchPress: Int(Double(20) * (1 + strengthMod)) + Int.random(in: -3...3),
                verticalJump: 32.0 + (speedMod * 5) + Double.random(in: -2...2),
                broadJump: 110 + Int(agilityMod * 10) + Int.random(in: -5...5),
                threeConeDrill: 7.0 - (agilityMod * 0.3) + Double.random(in: -0.1...0.1),
                shuttleRun: 4.2 - (agilityMod * 0.2) + Double.random(in: -0.1...0.1)
            )
        }
    }

    struct CollegeStats: Equatable {
        var gamesPlayed: Int
        var passingYards: Int
        var passingTDs: Int
        var rushingYards: Int
        var rushingTDs: Int
        var receivingYards: Int
        var receivingTDs: Int
        var tackles: Int
        var sacks: Double
        var interceptions: Int

        static func generate(for position: Position) -> CollegeStats {
            var stats = CollegeStats(
                gamesPlayed: Int.random(in: 36...52),
                passingYards: 0, passingTDs: 0,
                rushingYards: 0, rushingTDs: 0,
                receivingYards: 0, receivingTDs: 0,
                tackles: 0, sacks: 0, interceptions: 0
            )

            switch position {
            case .quarterback:
                stats.passingYards = Int.random(in: 6000...12000)
                stats.passingTDs = Int.random(in: 50...100)
                stats.rushingYards = Int.random(in: 0...1500)
                stats.rushingTDs = Int.random(in: 0...20)
            case .runningBack:
                stats.rushingYards = Int.random(in: 2500...5000)
                stats.rushingTDs = Int.random(in: 25...50)
                stats.receivingYards = Int.random(in: 200...1000)
            case .wideReceiver:
                stats.receivingYards = Int.random(in: 2000...4000)
                stats.receivingTDs = Int.random(in: 20...40)
            case .tightEnd:
                stats.receivingYards = Int.random(in: 800...2000)
                stats.receivingTDs = Int.random(in: 10...25)
            case .defensiveEnd, .defensiveTackle:
                stats.tackles = Int.random(in: 80...180)
                stats.sacks = Double.random(in: 15...35)
            case .outsideLinebacker, .middleLinebacker:
                stats.tackles = Int.random(in: 200...400)
                stats.sacks = Double.random(in: 5...20)
            case .cornerback, .freeSafety, .strongSafety:
                stats.tackles = Int.random(in: 100...200)
                stats.interceptions = Int.random(in: 5...15)
            default:
                break
            }

            return stats
        }
    }

    // MARK: - Generate Draft Class

    func generateDraftClass(year: Int, numberOfRounds: Int = 5, teamsCount: Int = 8) -> [DraftProspect] {
        var prospects: [DraftProspect] = []

        let totalPicks = numberOfRounds * teamsCount

        // Position quotas per round
        let positionQuotas: [Position] = [
            .quarterback, .quarterback,
            .runningBack, .runningBack, .runningBack,
            .wideReceiver, .wideReceiver, .wideReceiver, .wideReceiver,
            .tightEnd, .tightEnd,
            .leftTackle, .leftTackle, .leftGuard, .rightGuard, .center,
            .defensiveEnd, .defensiveEnd, .defensiveTackle, .defensiveTackle,
            .outsideLinebacker, .outsideLinebacker, .middleLinebacker,
            .cornerback, .cornerback, .cornerback,
            .freeSafety, .strongSafety
        ]

        // Generate prospects with varied talent levels
        for i in 0..<totalPicks {
            let round = (i / teamsCount) + 1
            let position = positionQuotas[i % positionQuotas.count]

            let tier: PlayerTier
            switch round {
            case 1:
                tier = Double.random(in: 0...1) < 0.6 ? .elite : .starter
            case 2:
                tier = Double.random(in: 0...1) < 0.4 ? .starter : .backup
            case 3:
                tier = Double.random(in: 0...1) < 0.3 ? .starter : .backup
            default:
                tier = Double.random(in: 0...1) < 0.2 ? .backup : .reserve
            }

            let prospect = generateProspect(position: position, projectedRound: round, tier: tier)
            prospects.append(prospect)
        }

        // Sort by projected overall (with some randomness for realistic draft)
        prospects.sort { a, b in
            let aValue = a.player.overall + Int.random(in: -5...5)
            let bValue = b.player.overall + Int.random(in: -5...5)
            return aValue > bValue
        }

        return prospects
    }

    private func generateProspect(position: Position, projectedRound: Int, tier: PlayerTier) -> DraftProspect {
        var player = PlayerGenerator.generate(position: position, tier: tier)
        player.age = Int.random(in: 21...23)
        player.experience = 0
        player.contract = Contract.rookie(round: projectedRound, pick: Int.random(in: 1...8))

        let development: DevelopmentTrait
        switch tier {
        case .elite:
            development = [.superstar, .star, .star].randomElement()!
        case .starter:
            development = [.star, .normal, .normal].randomElement()!
        case .backup:
            development = [.normal, .normal, .slow].randomElement()!
        case .reserve:
            development = [.normal, .slow, .slow].randomElement()!
        }

        let scoutingAccuracy = projectedRound <= 2 ? Int.random(in: 6...9) : Int.random(in: 3...7)

        let scoutingGrade = ScoutingGrade(
            overall: player.overall + Int.random(in: -5...5),
            accuracy: scoutingAccuracy,
            ceiling: player.overall + Int.random(in: 5...15),
            floor: player.overall - Int.random(in: 5...15),
            development: development
        )

        let combine = CombineResults.generate(
            for: position,
            speed: player.ratings.speed,
            strength: player.ratings.strength,
            agility: player.ratings.agility
        )

        let collegeStats = CollegeStats.generate(for: position)

        let strengths = generateStrengths(for: player)
        let weaknesses = generateWeaknesses(for: player)

        return DraftProspect(
            id: player.id,
            player: player,
            projectedRound: projectedRound,
            scoutingGrade: scoutingGrade,
            combine: combine,
            collegeStats: collegeStats,
            strengths: strengths,
            weaknesses: weaknesses
        )
    }

    private func generateStrengths(for player: Player) -> [String] {
        var strengths: [String] = []
        let r = player.ratings

        if r.speed >= 85 { strengths.append("Elite speed") }
        if r.strength >= 85 { strengths.append("Physical presence") }
        if r.agility >= 85 { strengths.append("Exceptional agility") }
        if r.awareness >= 85 { strengths.append("High football IQ") }

        switch player.position {
        case .quarterback:
            if r.throwPower >= 85 { strengths.append("Cannon arm") }
            if r.throwAccuracyDeep >= 85 { strengths.append("Deep ball accuracy") }
        case .runningBack:
            if r.elusiveness >= 85 { strengths.append("Elusive runner") }
            if r.breakTackle >= 85 { strengths.append("Tackles won't bring him down") }
        case .wideReceiver:
            if r.catching >= 85 { strengths.append("Sure hands") }
            if r.routeRunning >= 85 { strengths.append("Crisp route runner") }
        case .cornerback:
            if r.manCoverage >= 85 { strengths.append("Lockdown man coverage") }
            if r.press >= 85 { strengths.append("Physical at the line") }
        default:
            break
        }

        return Array(strengths.prefix(3))
    }

    private func generateWeaknesses(for player: Player) -> [String] {
        var weaknesses: [String] = []
        let r = player.ratings

        if r.speed < 70 { weaknesses.append("Lacks top-end speed") }
        if r.strength < 70 { weaknesses.append("Needs to add strength") }
        if r.awareness < 70 { weaknesses.append("Slow to read plays") }

        switch player.position {
        case .quarterback:
            if r.throwAccuracyDeep < 70 { weaknesses.append("Struggles with deep ball") }
            if r.playAction < 70 { weaknesses.append("Predictable in play action") }
        case .runningBack:
            if r.catching < 70 { weaknesses.append("Receiving skills need work") }
            if r.carrying < 70 { weaknesses.append("Ball security concerns") }
        case .wideReceiver:
            if r.catchInTraffic < 70 { weaknesses.append("Struggles in traffic") }
            if r.release < 70 { weaknesses.append("Gets jammed at the line") }
        default:
            break
        }

        return Array(weaknesses.prefix(2))
    }

    // MARK: - AI Draft Selection

    func selectBestAvailable(from prospects: [DraftProspect], for team: Team, needs: [Position]) -> DraftProspect? {
        // Score each available prospect
        var scoredProspects: [(prospect: DraftProspect, score: Double)] = []

        for prospect in prospects {
            var score = Double(prospect.scoutingGrade.overall)

            // Boost for team needs
            if needs.contains(prospect.player.position) {
                score *= 1.2
            }

            // Boost for development potential
            score *= prospect.scoutingGrade.development.progressionMultiplier * 0.1 + 0.9

            // Penalty for positions team is strong at
            if let starter = team.starter(at: prospect.player.position) {
                if starter.overall > prospect.player.overall {
                    score *= 0.85
                }
            }

            scoredProspects.append((prospect, score))
        }

        // Sort by score and return best
        scoredProspects.sort { $0.score > $1.score }
        return scoredProspects.first?.prospect
    }

    func evaluateTeamNeeds(for team: Team) -> [Position] {
        var needs: [Position] = []

        // Check each position group
        let positionGroups: [(Position, Int)] = [
            (.quarterback, 75),
            (.runningBack, 70),
            (.wideReceiver, 72),
            (.leftTackle, 75),
            (.cornerback, 73),
            (.defensiveEnd, 72)
        ]

        for (position, threshold) in positionGroups {
            if let starter = team.starter(at: position) {
                if starter.overall < threshold {
                    needs.append(position)
                }
                // Also need if starter is aging
                if starter.age >= 30 {
                    needs.append(position)
                }
            } else {
                needs.append(position)
            }
        }

        return needs
    }

    // MARK: - Trade Value

    func calculatePickValue(round: Int, pick: Int, totalTeams: Int) -> Int {
        // NFL-style pick value chart (simplified)
        let overallPick = (round - 1) * totalTeams + pick

        if overallPick <= 5 {
            return 3000 - (overallPick * 200)
        } else if overallPick <= 10 {
            return 2000 - (overallPick * 100)
        } else if overallPick <= 20 {
            return 1000 - (overallPick * 30)
        } else {
            return max(50, 500 - (overallPick * 10))
        }
    }
}
