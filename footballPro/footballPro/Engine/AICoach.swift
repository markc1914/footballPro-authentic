//
//  AICoach.swift
//  footballPro
//
//  CPU play calling AI with situational awareness
//

import Foundation

class AICoach {

    // Track recent play types to avoid repetition (last 5 calls)
    private var recentPlayTypes: [String] = []

    /// Record a play type and trim to last 5
    private func recordPlayType(_ playType: String) {
        recentPlayTypes.append(playType)
        if recentPlayTypes.count > 5 {
            recentPlayTypes.removeFirst()
        }
    }

    // MARK: - Offensive Play Selection

    func selectOffensivePlay(for team: Team, situation: GameSituation, playbook: [AuthenticPlayDefinition] = []) -> any PlayCall {

        let nonSTPlays = playbook.filter { !$0.isSpecialTeams }

        // If no authentic playbook available, fall back to old StandardPlayCall logic
        guard !nonSTPlays.isEmpty else {
            return fallbackOffensivePlay(for: team, situation: situation)
        }

        // Evaluate team strengths
        let passingStrength = evaluatePassingGame(team)
        let rushingStrength = evaluateRushingGame(team)

        // Pick categories based on situation
        let preferredCategories: [AuthenticPlayCategory]

        if situation.fieldPosition >= 95 {
            // Goal line — run-heavy
            preferredCategories = [.run]
        } else if situation.isTwoMinuteWarning && situation.scoreDifferential < 0 {
            // Two-minute drill — pass-heavy
            preferredCategories = [.pass, .screen]
        } else if situation.shouldRunClock {
            // Run clock
            preferredCategories = [.run, .draw]
        } else if situation.needsTouchdown {
            // Need big play
            preferredCategories = [.pass, .playAction]
        } else if situation.isRedZone {
            preferredCategories = [.pass, .run, .playAction]
        } else if situation.yardsToGo <= 2 && situation.down >= 3 {
            // Short yardage
            preferredCategories = [.run, .draw]
        } else if situation.yardsToGo >= 7 && situation.down == 3 {
            // Third and long
            preferredCategories = [.pass, .screen]
        } else if situation.down == 1 {
            // First down — balanced
            if Double.random(in: 0...1) < (0.45 + Double(passingStrength - rushingStrength) / 500.0) {
                preferredCategories = [.pass, .playAction]
            } else {
                preferredCategories = [.run, .draw]
            }
        } else {
            // Default — balanced
            preferredCategories = rushingStrength > passingStrength ?
                [.run, .draw, .playAction] : [.pass, .screen, .playAction]
        }

        // Filter by preferred categories
        let filtered = nonSTPlays.filter { preferredCategories.contains($0.category) }
        let chosen = filtered.isEmpty ? nonSTPlays : filtered

        // Weight selection: reduce weight of recently called play types by 50%
        let weights: [Double] = chosen.map { play in
            recentPlayTypes.contains(play.name) ? 0.5 : 1.0
        }
        let totalWeight = weights.reduce(0, +)
        var roll = Double.random(in: 0..<totalWeight)
        var pick = chosen.last!
        for (i, w) in weights.enumerated() {
            roll -= w
            if roll <= 0 { pick = chosen[i]; break }
        }
        recordPlayType(pick.name)
        return AuthenticPlayCall(play: pick)
    }

    /// Legacy fallback for when no authentic playbook is loaded
    private func fallbackOffensivePlay(for team: Team, situation: GameSituation) -> any PlayCall {
        let formation: OffensiveFormation
        let playType: PlayType

        // Kill clock: lean fully into the run game
        if situation.shouldRunClock {
            formation = [.singleback, .iFormation, .goalLine, .jumbo].randomElement()!
            playType = [.insideRun, .outsideRun, .draw, .sweep, .qbSneak].randomElement()!
            return StandardPlayCall(formation: formation, playType: playType)
        }

        if situation.fieldPosition >= 95 {
            formation = .goalLine
            playType = Bool.random() ? .qbSneak : .insideRun
        } else if situation.yardsToGo <= 2 && situation.down >= 3 {
            formation = [.goalLine, .iFormation, .singleback].randomElement()!
            playType = [.qbSneak, .insideRun, .draw, .shortPass, .screen].randomElement()!
        } else if situation.isTwoMinuteWarning && situation.scoreDifferential < 0 {
            formation = .shotgun
            playType = [.shortPass, .mediumPass, .screen].randomElement()!
        } else {
            formation = [.singleback, .shotgun].randomElement()!
            playType = [.insideRun, .shortPass, .mediumPass].randomElement()!
        }
        recordPlayType(String(describing: playType))
        return StandardPlayCall(formation: formation, playType: playType)
    }

    // MARK: - Defensive Play Selection

    func selectDefensivePlay(for team: Team, situation: GameSituation, playbook: [AuthenticPlayDefinition] = []) -> any DefensiveCall {

        let nonSTPlays = playbook.filter { !$0.isSpecialTeams }

        // If no authentic playbook available, fall back to StandardDefensiveCall
        guard !nonSTPlays.isEmpty else {
            return fallbackDefensivePlay(situation: situation)
        }

        // Situational formation preferences
        let preferredFormations: [DefensiveFormation]

        if situation.fieldPosition >= 95 {
            preferredFormations = [.goalLine]
        } else if situation.isLateGame && situation.scoreDifferential > 7 {
            preferredFormations = [.prevent]
        } else if situation.isTwoMinuteWarning {
            preferredFormations = [.dime, .nickel]
        } else if situation.yardsToGo <= 2 {
            preferredFormations = [.base43, .base34]
        } else if situation.down == 3 && situation.yardsToGo >= 7 {
            preferredFormations = [.nickel, .dime]
        } else {
            preferredFormations = [.base43, .base34, .nickel]
        }

        // Filter by preferred formation
        let filtered = nonSTPlays.filter { play in
            let formation = DefensiveFormation.fromPrfFormationCode(play.formationCode)
            return preferredFormations.contains(formation)
        }
        let chosen = filtered.isEmpty ? nonSTPlays : filtered

        let pick = chosen.randomElement()!
        return AuthenticDefensiveCall(play: pick)
    }

    /// Legacy fallback for when no authentic defensive playbook is loaded
    private func fallbackDefensivePlay(situation: GameSituation) -> any DefensiveCall {
        let formation: DefensiveFormation
        let coverage: PlayType

        if situation.fieldPosition >= 95 {
            formation = .goalLine
            coverage = .manCoverage
        } else if situation.isLateGame && situation.scoreDifferential > 7 {
            formation = .prevent
            coverage = .coverFour
        } else {
            formation = [.base43, .nickel].randomElement()!
            coverage = [.coverTwo, .coverThree].randomElement()!
        }
        return StandardDefensiveCall(formation: formation, coverage: coverage, isBlitzing: false)
    }

    // MARK: - Fourth Down Decision

    enum FourthDownDecision {
        case goForIt
        case punt
        case fieldGoal
    }

    func fourthDownDecision(situation: GameSituation, kicker: Player?) -> FourthDownDecision {

        let yardsToGo = situation.yardsToGo
        let fieldPosition = situation.fieldPosition
        let scoreDiff = situation.scoreDifferential

        // Must go for it situations
        if situation.isLateGame && scoreDiff < 0 {
            if fieldPosition >= 60 { // Past midfield
                return .goForIt
            }
            if scoreDiff <= -8 { // Need more than a TD
                return .goForIt
            }
        }

        // Field goal range (roughly inside 35-yard line = 52 yard FG)
        let fieldGoalDistance = 100 - fieldPosition + 17
        let kickerAccuracy = kicker?.ratings.kickAccuracy ?? 70
        let kickerPower = kicker?.ratings.kickPower ?? 70

        var fgMakeChance: Double
        if fieldGoalDistance <= 35 {
            fgMakeChance = 0.90
        } else if fieldGoalDistance <= 45 {
            fgMakeChance = 0.75
        } else if fieldGoalDistance <= 55 {
            fgMakeChance = 0.50
        } else {
            fgMakeChance = 0.20
        }

        // Adjust for kicker rating
        fgMakeChance *= Double(kickerAccuracy + kickerPower) / 140.0

        // If in good FG range
        if fgMakeChance > 0.6 && fieldPosition >= 60 {
            // But short yardage might go for it
            if yardsToGo <= 1 && fieldPosition >= 70 {
                return Bool.random() ? .goForIt : .fieldGoal
            }
            return .fieldGoal
        }

        // Go for it calculations
        let goForItThreshold: Int
        if fieldPosition >= 70 {
            goForItThreshold = 3
        } else if fieldPosition >= 50 {
            goForItThreshold = 2
        } else {
            goForItThreshold = 1
        }

        if yardsToGo <= goForItThreshold {
            return .goForIt
        }

        // Default to punt
        return .punt
    }

    // MARK: - Helper Methods

    private func evaluatePassingGame(_ team: Team) -> Int {
        let qb = team.starter(at: .quarterback)
        let wr1 = team.starter(at: .wideReceiver)
        let te = team.starter(at: .tightEnd)

        let qbRating = qb?.overall ?? 50
        let wr1Rating = wr1?.overall ?? 50
        let teRating = te?.overall ?? 50

        return (qbRating * 2 + wr1Rating + teRating) / 4
    }

    private func evaluateRushingGame(_ team: Team) -> Int {
        let rb = team.starter(at: .runningBack)
        let lt = team.starter(at: .leftTackle)
        let lg = team.starter(at: .leftGuard)
        let c = team.starter(at: .center)

        let rbRating = rb?.overall ?? 50
        let oLineRating = [lt, lg, c].compactMap { $0?.overall }.reduce(0, +) / 3

        return (rbRating * 2 + oLineRating) / 3
    }

    // MARK: - Timeout Usage

    func shouldCallTimeout(situation: GameSituation, timeoutsRemaining: Int) -> Bool {
        guard timeoutsRemaining > 0 else { return false }

        // End of half - save time
        if situation.isTwoMinuteWarning && situation.scoreDifferential < 0 {
            return true
        }

        // Prevent opponent from running clock
        if situation.isLateGame && situation.scoreDifferential < 0 {
            return true
        }

        return false
    }

    // MARK: - Challenge Decision

    func shouldChallenge(playWasGood: Bool, challengesRemaining: Int, situation: GameSituation) -> Bool {
        guard challengesRemaining > 0 else { return false }

        // Only challenge plays that went against us
        guard !playWasGood else { return false }

        // More likely to challenge in important situations
        if situation.isRedZone || situation.isLateGame {
            return Double.random(in: 0...1) < 0.6
        }

        return Double.random(in: 0...1) < 0.3
    }
}
