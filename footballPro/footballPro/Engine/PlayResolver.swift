//
//  PlayResolver.swift
//  footballPro
//
//  Resolves play outcomes based on matchups and ratings
//

import Foundation

class PlayResolver {

    // MARK: - Main Resolution

    func resolvePlay(
        offensiveCall: any PlayCall, // Changed to any PlayCall
        defensiveCall: any DefensiveCall, // Changed to any DefensiveCall
        offensiveTeam: Team,
        defensiveTeam: Team,
        fieldPosition: FieldPosition,
        downAndDistance: DownAndDistance,
        weather: Weather
    ) -> PlayOutcome {

        // Check for penalty first (5% chance)
        if Double.random(in: 0...1) < 0.05 {
            return resolvePenalty()
        }

        switch offensiveCall.playType {
        case .kneel:
            return resolveKneel(offensiveTeam: offensiveTeam)

        case .spike:
            return resolveSpike(offensiveTeam: offensiveTeam)

        case _ where offensiveCall.playType.isRun:
            return resolveRun(
                playType: offensiveCall.playType,
                offensiveTeam: offensiveTeam,
                defensiveTeam: defensiveTeam,
                defensiveFormation: defensiveCall.formation,
                fieldPosition: fieldPosition
            )

        case _ where offensiveCall.playType.isPass:
            return resolvePass(
                playType: offensiveCall.playType,
                offensiveTeam: offensiveTeam,
                defensiveTeam: defensiveTeam,
                defensiveCall: defensiveCall,
                fieldPosition: fieldPosition,
                weather: weather
            )

        default:
            return PlayOutcome.incomplete()
        }
    }

    // MARK: - Run Resolution

    private func resolveRun(
        playType: PlayType,
        offensiveTeam: Team,
        defensiveTeam: Team,
        defensiveFormation: DefensiveFormation,
        fieldPosition: FieldPosition
    ) -> PlayOutcome {

        // Get key players
        let rb = offensiveTeam.starter(at: .runningBack)
        let lt = offensiveTeam.starter(at: .leftTackle)
        let lg = offensiveTeam.starter(at: .leftGuard)
        let c = offensiveTeam.starter(at: .center)
        let rg = offensiveTeam.starter(at: .rightGuard)
        let rt = offensiveTeam.starter(at: .rightTackle)

        let dt1 = defensiveTeam.starter(at: .defensiveTackle)
        let dt2 = defensiveTeam.players(at: .defensiveTackle).dropFirst().first
        let mlb = defensiveTeam.starter(at: .middleLinebacker)
        let olb1 = defensiveTeam.starter(at: .outsideLinebacker)

        // Pick a random tackler from defensive front
        let allDefenders = [dt1, dt2, mlb, olb1].compactMap { $0 }
        let tackler = allDefenders.randomElement()

        // Calculate offensive line rating
        let oLineRating = [lt, lg, c, rg, rt]
            .compactMap { $0?.ratings.runBlock }
            .reduce(0, +) / 5

        // Calculate defensive front rating (weighted more heavily)
        let defenders = allDefenders
        var dLineRating = defenders.isEmpty ? 70 : defenders
            .map { ($0.ratings.tackle + $0.ratings.blockShedding + $0.ratings.pursuit) / 3 }
            .reduce(0, +) / defenders.count

        // Linebacker play recognition improves run defense reads
        let linebackers = [mlb, olb1].compactMap { $0 }
        if !linebackers.isEmpty {
            let lbRecognition = Double(linebackers.map { $0.ratings.playRecognition }.reduce(0, +)) / Double(linebackers.count)
            dLineRating += Int(lbRecognition * 0.3)
        }

        // Running back contribution
        let rbRating = rb.map { ($0.ratings.speed + $0.ratings.elusiveness + $0.ratings.ballCarrierVision) / 3 } ?? 60

        // Formation matchup - defense gets more credit for run-stopping formations
        let formationModifier: Double
        switch defensiveFormation {
        case .goalLine, .goalLineDef: formationModifier = 0.4  // Very hard to run against goal line
        case .base43, .base34, .base46, .base44, .flex: formationModifier = 0.85
        case .nickel, .base33: formationModifier = 1.0
        case .dime, .prevent: formationModifier = 1.3
        }

        // Calculate base yards - defense is now more impactful
        let matchupDiff = Double(oLineRating + rbRating/2 - dLineRating) / 150.0
        let baseYards = playType.averageYards * (0.8 + matchupDiff) * formationModifier

        // NFL-realistic right-skewed rushing distribution
        let roll = Double.random(in: 0...1)
        let variance: Double
        if roll < 0.40 {
            variance = Double.random(in: -2...1)       // 40%: stuffed/short (0-3 yds)
        } else if roll < 0.75 {
            variance = Double.random(in: 1...4)        // 35%: moderate (3-6 yds)
        } else if roll < 0.90 {
            variance = Double.random(in: 4...8)        // 15%: good gain (6-10 yds)
        } else if roll < 0.97 {
            variance = Double.random(in: 8...18)       // 7%: big play (10-20 yds)
        } else {
            variance = Double.random(in: 18...45)      // 3%: breakaway (20+ yds)
        }
        var yards = Int(baseYards + variance)

        // Break tackle check: RB's breakTackle + trucking can add extra yards
        if let runner = rb {
            let breakChance = Double(runner.ratings.breakTackle + runner.ratings.trucking) / 400.0 * 0.20
            if Double.random(in: 0...1) < breakChance {
                yards += Int.random(in: 3...8)
            }
        }

        // 20% chance of tackle for loss if defense wins the matchup
        if dLineRating > oLineRating && Double.random(in: 0...1) < 0.20 {
            yards = Int.random(in: -3...0)
        }

        // Play type specific adjustments
        switch playType {
        case .qbSneak:
            yards = max(-1, min(yards, 2))
        case .draw:
            // Draws are risky - can break big or get stuffed
            if Double.random(in: 0...1) < 0.3 {
                yards = Int.random(in: -2...1)
            } else if Double.random(in: 0...1) < 0.1 {
                yards += Int.random(in: 8...20)
            }
        case .sweep, .outsideRun:
            // Outside runs can lose yards or break big
            if Double.random(in: 0...1) < 0.25 {
                yards = Int.random(in: -4...1)
            } else if Double.random(in: 0...1) < 0.10 {
                yards += Int.random(in: 10...25)
            }
        default:
            break
        }

        // Check for fumble (2% base chance, more realistic)
        let carryingSkill = Double(rb?.ratings.carrying ?? 70)
        var fumbleChance = 0.02 * (1.0 - carryingSkill / 200.0)

        // Tackler's hitPower increases fumble chance
        if let hitPwr = tackler?.ratings.hitPower {
            fumbleChance *= (1.0 + Double(hitPwr - 70) / 200.0)
        }

        if Double.random(in: 0...1) < fumbleChance {
            let recovered = Double.random(in: 0...1) < 0.45 // Defense recovers 55% of fumbles
            return PlayOutcome(
                yardsGained: min(yards, 3), // Fumble usually happens after short gain
                timeElapsed: Int.random(in: 5...10),
                isComplete: true,
                isTouchdown: false,
                isTurnover: !recovered,
                turnoverType: recovered ? nil : .fumble,
                isPenalty: false,
                penalty: nil,
                isInjury: false,
                injuredPlayerId: nil,
                wentOutOfBounds: false,
                passerId: nil,
                rusherId: rb?.id,
                receiverId: nil,
                primaryTacklerId: tackler?.id,
                description: generateRunDescription(rb: rb, yards: yards, fumble: true, recovered: recovered)
            )
        }

        // Cap yards at distance to end zone
        yards = min(yards, fieldPosition.yardsToEndZone)
        let isTouchdown = fieldPosition.yardLine + yards >= 100

        // Time elapsed
        let timeElapsed = yards > 0 ? Int.random(in: 25...40) : Int.random(in: 5...15)

        // Check for injury (~2% chance on runs, higher on big hits)
        let injuryResult = checkForInjury(ballCarrierId: rb?.id, tacklerId: tackler?.id, isBigHit: yards <= 0)

        // Out-of-bounds check: outside runs ~25%, inside runs ~5%
        let oobChance: Double
        switch playType {
        case .sweep, .outsideRun, .qbScramble:
            oobChance = 0.25
        default:
            oobChance = 0.05
        }
        let wentOOB = Double.random(in: 0...1) < oobChance

        return PlayOutcome(
            yardsGained: yards,
            timeElapsed: timeElapsed,
            isComplete: true,
            isTouchdown: isTouchdown,
            isTurnover: false,
            turnoverType: nil,
            isPenalty: false,
            penalty: nil,
            isInjury: injuryResult.isInjury,
            injuredPlayerId: injuryResult.injuredPlayerId,
            wentOutOfBounds: wentOOB,
            passerId: nil,
            rusherId: rb?.id,
            receiverId: nil,
            primaryTacklerId: tackler?.id,
            description: generateRunDescription(rb: rb, yards: yards)
        )
    }

    // MARK: - Pass Resolution

    private func resolvePass(
        playType: PlayType,
        offensiveTeam: Team,
        defensiveTeam: Team,
        defensiveCall: any DefensiveCall, // Changed to any DefensiveCall
        fieldPosition: FieldPosition,
        weather: Weather
    ) -> PlayOutcome {

        let qb = offensiveTeam.starter(at: .quarterback)
        let receivers = offensiveTeam.players(at: .wideReceiver) + offensiveTeam.players(at: .tightEnd)
        // Weight target selection by receiver overall rating so WR1 gets more targets
        let targetReceiver: Player? = {
            guard !receivers.isEmpty else { return nil }
            let weights = receivers.map { Double($0.overall) }
            let totalWeight = weights.reduce(0, +)
            guard totalWeight > 0 else { return receivers.randomElement() }
            var pick = Double.random(in: 0..<totalWeight)
            for (i, w) in weights.enumerated() {
                pick -= w
                if pick <= 0 { return receivers[i] }
            }
            return receivers.last
        }()

        let cb1 = defensiveTeam.starter(at: .cornerback)
        let cb2 = defensiveTeam.players(at: .cornerback).dropFirst().first
        let fs = defensiveTeam.starter(at: .freeSafety)
        let ss = defensiveTeam.starter(at: .strongSafety)
        let de1 = defensiveTeam.starter(at: .defensiveEnd)

        // QB accuracy based on pass depth
        let qbAccuracy: Int
        switch playType {
        case .shortPass, .screen:
            qbAccuracy = qb?.ratings.throwAccuracyShort ?? 70
        case .mediumPass, .playAction, .rollout:
            qbAccuracy = qb?.ratings.throwAccuracyMid ?? 70
        case .deepPass:
            qbAccuracy = qb?.ratings.throwAccuracyDeep ?? 70
        default:
            qbAccuracy = qb?.ratings.throwAccuracyMid ?? 70
        }

        // Receiver rating
        let receiverRating = targetReceiver.map {
            ($0.ratings.catching + $0.ratings.routeRunning) / 2
        } ?? 60

        // Coverage rating - more comprehensive calculation
        let coverageRating: Int
        switch defensiveCall.coverage {
        case .manCoverage:
            // Man coverage uses individual CB skills
            let cbRating = ((cb1?.ratings.manCoverage ?? 70) + (cb2?.ratings.manCoverage ?? 70)) / 2
            coverageRating = cbRating + 5 // Slight bonus for man coverage
        case .coverTwo:
            let safetyRating = ((fs?.ratings.zoneCoverage ?? 70) + (ss?.ratings.zoneCoverage ?? 70)) / 2
            coverageRating = safetyRating
        case .coverThree, .coverFour:
            let dbRating = [cb1, cb2, fs, ss].compactMap { $0?.ratings.zoneCoverage }.reduce(0, +) / 4
            coverageRating = dbRating + 8 // Zone coverage bonus
        default:
            coverageRating = 70
        }

        // Pass rush pressure affects everything
        let passRushRating = de1?.ratings.passRush ?? 70
        let oLinePassBlock = [
            offensiveTeam.starter(at: .leftTackle)?.ratings.passBlock ?? 70,
            offensiveTeam.starter(at: .leftGuard)?.ratings.passBlock ?? 70,
            offensiveTeam.starter(at: .center)?.ratings.passBlock ?? 70,
            offensiveTeam.starter(at: .rightGuard)?.ratings.passBlock ?? 70,
            offensiveTeam.starter(at: .rightTackle)?.ratings.passBlock ?? 70
        ].reduce(0, +) / 5

        // Sack chance - more realistic (NFL average ~6-7%)
        var sackChance = 0.07
        if defensiveCall.isBlitzing {
            sackChance = 0.18  // Blitzes are high risk/reward
        }
        // Pass rush vs pass block matchup
        let passRushDiff = Double(passRushRating - oLinePassBlock) / 100.0
        sackChance += passRushDiff * 0.08
        sackChance = max(0.03, min(0.25, sackChance))

        if Double.random(in: 0...1) < sackChance {
            let sackYards = Int.random(in: -12...(-4))

            // Strip sack fumble chance (~10% of sacks result in fumbles, defense recovers ~65%)
            let stripSackChance = 0.10
            if Double.random(in: 0...1) < stripSackChance {
                let defenseRecovers = Double.random(in: 0...1) < 0.65
                let desc = defenseRecovers
                    ? "\(qb?.fullName ?? "QB") STRIP SACKED! Fumble recovered by defense!"
                    : "\(qb?.fullName ?? "QB") stripped on the sack, but recovers the fumble"
                return PlayOutcome(
                    yardsGained: sackYards,
                    timeElapsed: Int.random(in: 5...10),
                    isComplete: false,
                    isTouchdown: false,
                    isTurnover: defenseRecovers,
                    turnoverType: defenseRecovers ? .fumble : nil,
                    isPenalty: false,
                    penalty: nil,
                    isInjury: false,
                    injuredPlayerId: nil,
                    wentOutOfBounds: false,
                    passerId: qb?.id,
                    rusherId: nil,
                    receiverId: nil,
                    primaryTacklerId: de1?.id,
                    description: desc
                )
            }

            // Check for injury on sack (~3% chance)
            let sackInjury = checkForInjury(ballCarrierId: qb?.id, tacklerId: de1?.id, isBigHit: true)

            return PlayOutcome(
                yardsGained: sackYards,
                timeElapsed: Int.random(in: 5...10),
                isComplete: false,
                isTouchdown: false,
                isTurnover: false,
                turnoverType: nil,
                isPenalty: false,
                penalty: nil,
                isInjury: sackInjury.isInjury,
                injuredPlayerId: sackInjury.injuredPlayerId,
                wentOutOfBounds: false,
                passerId: qb?.id,
                rusherId: nil,
                receiverId: nil,
                primaryTacklerId: de1?.id,
                description: "\(qb?.fullName ?? "QB") sacked for a loss of \(abs(sackYards)) yards"
            )
        }

        // Pressure affects accuracy even without sack (hurried throws)
        let isPressured = Double.random(in: 0...1) < (sackChance * 2.5)
        let pressurePenalty = isPressured ? 15 : 0

        // Calculate completion chance - more realistic (NFL average ~65%)
        let effectiveQBAccuracy = qbAccuracy - pressurePenalty
        var completionChance = Double(effectiveQBAccuracy + receiverRating - coverageRating - 20) / 120.0
        completionChance = min(0.80, max(0.30, completionChance))  // Tighter bounds

        // Weather affects passing
        if weather.affectsPassing {
            completionChance *= 0.80
        }

        // Catch in traffic: when coverage is tight, receiver's catchInTraffic helps
        if coverageRating > receiverRating, let receiver = targetReceiver {
            completionChance += Double(receiver.ratings.catchInTraffic - 60) / 500.0
        }

        // Press vs release: CB press technique vs WR release off the line
        if let receiver = targetReceiver {
            let cornerForPress = cb1 ?? cb2
            if let corner = cornerForPress {
                let pressRelease = Double(receiver.ratings.release - corner.ratings.press) / 300.0
                completionChance += pressRelease
            }
        }

        // Play type modifiers - more conservative
        switch playType {
        case .screen:
            completionChance += 0.12
        case .deepPass:
            completionChance -= 0.20  // Deep balls are hard
            // Spectacular catch chance on deep passes
            if let receiver = targetReceiver {
                completionChance += Double(receiver.ratings.spectacularCatch - 60) / 600.0
            }
        case .playAction:
            // Rating-based play action bonus (replaces flat +5%)
            let paRating = qb?.ratings.playAction ?? 50
            let paBonus = 0.02 + Double(paRating - 50) / 1000.0
            completionChance += paBonus
        case .shortPass:
            completionChance += 0.08
        default:
            break
        }

        // Coverage matchup - defense gets more credit
        switch defensiveCall.coverage {
        case .blitz, .zoneBlitz:
            completionChance += 0.08  // Less bonus for blitz (receivers less open)
        case .manCoverage:
            completionChance -= 0.08
        case .coverThree, .coverFour:
            completionChance -= 0.05
        case .coverTwo:
            completionChance -= 0.03
        default:
            break
        }

        // Prevent formation gives up short passes
        if defensiveCall.formation == .prevent {
            completionChance += 0.10
        }

        let isComplete = Double.random(in: 0...1) < completionChance

        if !isComplete {
            // Check for interception - more realistic (NFL ~2.5% of passes)
            var intChance = 0.025
            if playType == .deepPass { intChance = 0.06 }
            if isPressured { intChance += 0.03 }  // Hurried throws get picked
            if defensiveCall.coverage == .coverFour { intChance += 0.02 }
            if defensiveCall.coverage == .manCoverage { intChance += 0.015 }

            // Bad QB decisions
            let qbAwareness = qb?.ratings.awareness ?? 70
            if qbAwareness < 70 { intChance += 0.02 }

            if Double.random(in: 0...1) < intChance {
                return PlayOutcome(
                    yardsGained: 0,
                    timeElapsed: Int.random(in: 4...8),
                    isComplete: false,
                    isTouchdown: false,
                    isTurnover: true,
                    turnoverType: .interception,
                    isPenalty: false,
                    penalty: nil,
                    isInjury: false,
                    injuredPlayerId: nil,
                    wentOutOfBounds: false,
                    passerId: qb?.id,
                    rusherId: nil,
                    receiverId: targetReceiver?.id,
                    primaryTacklerId: cb1?.id,
                    description: "\(qb?.fullName ?? "QB") pass INTERCEPTED by \(cb1?.fullName ?? "defender")!"
                )
            }

            // Pass breakup description
            let breakupDesc = isPressured ?
                "\(qb?.fullName ?? "QB") throws it away under pressure" :
                "Pass incomplete to \(targetReceiver?.fullName ?? "receiver")"

            return PlayOutcome(
                yardsGained: 0,
                timeElapsed: Int.random(in: 4...8),
                isComplete: false,
                isTouchdown: false,
                isTurnover: false,
                turnoverType: nil,
                isPenalty: false,
                penalty: nil,
                isInjury: false,
                injuredPlayerId: nil,
                wentOutOfBounds: false,
                passerId: qb?.id,
                rusherId: nil,
                receiverId: targetReceiver?.id,
                primaryTacklerId: nil,
                description: breakupDesc
            )
        }

        // Calculate yards - reduce YAC, make coverage matter more
        let baseYards = playType.averageYards
        let tackleSkill = Double((cb1?.ratings.tackle ?? 70) + (ss?.ratings.tackle ?? 70)) / 200.0
        let yacAbility = Double.random(in: 0...5) * Double(targetReceiver?.ratings.speed ?? 70) / 150.0 * (1.0 - tackleSkill * 0.5)
        var totalYards = Int(Double(baseYards) * 0.85 + yacAbility + Double.random(in: -4...3))
        totalYards = max(1, totalYards)  // Minimum 1 yard on completion

        // Cap at end zone
        totalYards = min(totalYards, fieldPosition.yardsToEndZone)
        let isTouchdown = fieldPosition.yardLine + totalYards >= 100

        let timeElapsed = Int.random(in: 5...15)

        // Pick a tackler from defensive backs
        let dbTackler = [cb1, cb2, fs, ss].compactMap { $0 }.randomElement()

        // Check for injury on completed pass (~1.5% chance)
        let passInjury = checkForInjury(ballCarrierId: targetReceiver?.id, tacklerId: dbTackler?.id, isBigHit: false)

        return PlayOutcome(
            yardsGained: totalYards,
            timeElapsed: timeElapsed,
            isComplete: true,
            isTouchdown: isTouchdown,
            isTurnover: false,
            turnoverType: nil,
            isPenalty: false,
            penalty: nil,
            isInjury: passInjury.isInjury,
            injuredPlayerId: passInjury.injuredPlayerId,
            wentOutOfBounds: false,
            passerId: qb?.id,
            rusherId: nil,
            receiverId: targetReceiver?.id,
            primaryTacklerId: dbTackler?.id,
            description: generatePassDescription(qb: qb, receiver: targetReceiver, yards: totalYards, touchdown: isTouchdown)
        )
    }

    // MARK: - Penalty Resolution

    private func resolvePenalty() -> PlayOutcome {
        let penaltyType = PenaltyType.allCases.randomElement()!

        // Assign penalty to the CORRECT side based on penalty type
        let isOnOffense: Bool
        if penaltyType.isAlwaysOffense {
            isOnOffense = true
        } else if penaltyType.isAlwaysDefense {
            isOnOffense = false
        } else {
            // Ambiguous penalties (holding, facemask, etc.): random side
            isOnOffense = Bool.random()
        }

        let penalty = Penalty(
            type: penaltyType,
            yards: penaltyType.yards,
            isOnOffense: isOnOffense,
            isDeclined: false
        )

        let yardEffect = isOnOffense ? -penalty.yards : penalty.yards

        return PlayOutcome(
            yardsGained: yardEffect,
            timeElapsed: Int.random(in: 5...10),
            isComplete: false,
            isTouchdown: false,
            isTurnover: false,
            turnoverType: nil,
            isPenalty: true,
            penalty: penalty,
            isInjury: false,
            injuredPlayerId: nil,
            wentOutOfBounds: false,
            passerId: nil,
            rusherId: nil,
            receiverId: nil,
            primaryTacklerId: nil,
            description: "FLAG: \(penalty.description)"
        )
    }

    // MARK: - Kneel Resolution

    private func resolveKneel(offensiveTeam: Team) -> PlayOutcome {
        let qb = offensiveTeam.starter(at: .quarterback)
        let qbName = qb?.fullName ?? "Quarterback"

        return PlayOutcome(
            yardsGained: -1,
            timeElapsed: Int.random(in: 38...42), // ~40 seconds off clock
            isComplete: true,
            isTouchdown: false,
            isTurnover: false,
            turnoverType: nil,
            isPenalty: false,
            penalty: nil,
            isInjury: false,
            injuredPlayerId: nil,
            wentOutOfBounds: false,
            passerId: nil,
            rusherId: qb?.id,
            receiverId: nil,
            primaryTacklerId: nil,
            description: "\(qbName) takes a knee"
        )
    }

    // MARK: - Spike Resolution

    private func resolveSpike(offensiveTeam: Team) -> PlayOutcome {
        let qb = offensiveTeam.starter(at: .quarterback)
        let qbName = qb?.fullName ?? "Quarterback"

        return PlayOutcome(
            yardsGained: 0,
            timeElapsed: Int.random(in: 2...4), // ~3 seconds off clock
            isComplete: false, // Spike is an incomplete pass — clock stops
            isTouchdown: false,
            isTurnover: false,
            turnoverType: nil,
            isPenalty: false,
            penalty: nil,
            isInjury: false,
            injuredPlayerId: nil,
            wentOutOfBounds: false,
            passerId: qb?.id,
            rusherId: nil,
            receiverId: nil,
            primaryTacklerId: nil,
            description: "\(qbName) spikes the ball to stop the clock"
        )
    }

    // MARK: - Injury Check

    private struct InjuryCheckResult {
        let isInjury: Bool
        let injuredPlayerId: UUID?
    }

    /// Roll for injury. Base ~1.5% per play; big hits (sacks, TFLs) bump to ~3%.
    private func checkForInjury(ballCarrierId: UUID?, tacklerId: UUID?, isBigHit: Bool) -> InjuryCheckResult {
        let baseChance = isBigHit ? 0.03 : 0.015
        guard Double.random(in: 0...1) < baseChance else {
            return InjuryCheckResult(isInjury: false, injuredPlayerId: nil)
        }
        // Injured player is the ball carrier (more common) or tackler
        let injuredId = Double.random(in: 0...1) < 0.80 ? ballCarrierId : tacklerId
        return InjuryCheckResult(isInjury: injuredId != nil, injuredPlayerId: injuredId)
    }

    // MARK: - Description Generation

    private func generateRunDescription(rb: Player?, yards: Int, fumble: Bool = false, recovered: Bool = true) -> String {
        let name = rb?.fullName ?? "Running back"

        if fumble {
            if recovered {
                return "\(name) runs for \(yards) yards, FUMBLES but recovers"
            } else {
                return "\(name) runs for \(yards) yards, FUMBLES! Recovered by defense"
            }
        }

        if yards <= 0 {
            return "\(name) stuffed for no gain"
        } else if yards <= 3 {
            return "\(name) runs up the middle for \(yards) yards"
        } else if yards <= 10 {
            return "\(name) finds a hole for \(yards) yards"
        } else {
            return "\(name) breaks free for a \(yards) yard gain!"
        }
    }

    private func generatePassDescription(qb: Player?, receiver: Player?, yards: Int, touchdown: Bool) -> String {
        let qbName = qb?.fullName ?? "Quarterback"
        let recName = receiver?.fullName ?? "receiver"

        if touchdown {
            return "\(qbName) finds \(recName) for a \(yards) yard TOUCHDOWN!"
        } else if yards <= 5 {
            return "\(qbName) completes a short pass to \(recName) for \(yards) yards"
        } else if yards <= 15 {
            return "\(qbName) hits \(recName) over the middle for \(yards) yards"
        } else {
            return "\(qbName) connects deep with \(recName) for \(yards) yards!"
        }
    }
}
