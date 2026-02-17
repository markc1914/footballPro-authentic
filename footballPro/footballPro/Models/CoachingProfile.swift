//
//  CoachingProfile.swift
//  footballPro
//
//  Situational AI play calling based on the original FPS '93 coaching profile system.
//  2,520 game situations per half = 6 time × 4 down × 5 distance × 7 field × 3 score buckets.
//

import Foundation

// MARK: - Situation Buckets

/// Minutes remaining in the half: 6 buckets
public enum TimeBucket: Int, CaseIterable, Codable, Hashable {
    case t0_2 = 0   // 0-2 minutes (hurry up / 2-minute drill)
    case t2_5        // 2-5 minutes (late half)
    case t5_8        // 5-8 minutes
    case t8_12       // 8-12 minutes
    case t12_15      // 12-15 minutes
    case t15plus     // 15+ minutes (start of half / OT)

    /// Map seconds remaining in the half to a bucket.
    /// Game stores total seconds in the quarter; caller should convert to half-remaining.
    public static func from(secondsRemainingInHalf: Int) -> TimeBucket {
        let minutes = secondsRemainingInHalf / 60
        switch minutes {
        case 0..<2:   return .t0_2
        case 2..<5:   return .t2_5
        case 5..<8:   return .t5_8
        case 8..<12:  return .t8_12
        case 12..<15: return .t12_15
        default:      return .t15plus
        }
    }
}

/// Yards to go: 5 buckets
public enum YardsBucket: Int, CaseIterable, Codable, Hashable {
    case y1_2 = 0    // 1-2 yards (short yardage / sneaks)
    case y3_5         // 3-5 yards
    case y6_10        // 6-10 yards (standard)
    case y11_15       // 11-15 yards (medium-long)
    case y16plus      // 16+ yards (very long)

    public static func from(yardsToGo: Int) -> YardsBucket {
        switch yardsToGo {
        case ...2:    return .y1_2
        case 3...5:   return .y3_5
        case 6...10:  return .y6_10
        case 11...15: return .y11_15
        default:      return .y16plus
        }
    }
}

/// Field position: 7 zones (from offense's perspective, 0 = own goal line, 100 = opponent's)
public enum FieldZone: Int, CaseIterable, Codable, Hashable {
    case own1_10 = 0   // Own 1-10 (backed up)
    case own11_25       // Own 11-25
    case own26_50       // Own 26-50
    case opp49_26       // Opponent 49-26 (midfield to their territory)
    case opp25_11       // Opponent 25-11 (red zone fringe)
    case opp10_1        // Opponent 10-1 (red zone / scoring position)
    case goalLine       // Goal line (inside 3)

    public static func from(fieldPosition: Int) -> FieldZone {
        switch fieldPosition {
        case ...10:   return .own1_10
        case 11...25: return .own11_25
        case 26...50: return .own26_50
        case 51...74: return .opp49_26
        case 75...89: return .opp25_11
        case 90...97: return .opp10_1
        default:      return .goalLine
        }
    }
}

/// Score differential: 3 states
public enum ScoreDiffBucket: Int, CaseIterable, Codable, Hashable {
    case losingBig = 0   // Losing by 8+ points
    case within7          // Within 7 points (either direction)
    case aheadBig         // Ahead by 8+ points

    public static func from(scoreDifferential: Int) -> ScoreDiffBucket {
        if scoreDifferential <= -8 { return .losingBig }
        if scoreDifferential >= 8 { return .aheadBig }
        return .within7
    }
}

// MARK: - Coaching Play Types (FPS '93 original)

/// Offensive play types from the original FPS '93 coaching profile system (15 types)
public enum CoachingPlayType: String, Codable, CaseIterable, Hashable {
    // Pass: 9 combinations of distance × direction
    case passShortLeft    = "Pass Short Left"
    case passShortMiddle  = "Pass Short Middle"
    case passShortRight   = "Pass Short Right"
    case passMediumLeft   = "Pass Medium Left"
    case passMediumMiddle = "Pass Medium Middle"
    case passMediumRight  = "Pass Medium Right"
    case passLongLeft     = "Pass Long Left"
    case passLongMiddle   = "Pass Long Middle"
    case passLongRight    = "Pass Long Right"
    // Run: 2 directions
    case runLeft          = "Run Left"
    case runRight         = "Run Right"
    // Goal line: 2
    case goalLineRun      = "Goal Line Run"
    case goalLinePass     = "Goal Line Pass"
    // Razzle dazzle: 2
    case razzleDazzleRun  = "Razzle Dazzle Run"
    case razzleDazzlePass = "Razzle Dazzle Pass"

    /// Map to the game's PlayType enum for actual play selection
    public var matchingPlayTypes: [PlayType] {
        switch self {
        case .passShortLeft, .passShortMiddle, .passShortRight:
            return [.shortPass, .screen]
        case .passMediumLeft, .passMediumMiddle, .passMediumRight:
            return [.mediumPass, .rollout]
        case .passLongLeft, .passLongMiddle, .passLongRight:
            return [.deepPass, .playAction]
        case .runLeft:
            return [.outsideRun, .sweep]
        case .runRight:
            return [.insideRun, .draw, .counter]
        case .goalLineRun:
            return [.qbSneak, .insideRun]
        case .goalLinePass:
            return [.shortPass, .playAction]
        case .razzleDazzleRun:
            return [.counter, .sweep, .qbScramble]
        case .razzleDazzlePass:
            return [.playAction, .screen, .rollout]
        }
    }

    /// Map to AuthenticPlayCategory for filtering authentic playbook entries
    public var matchingCategories: [AuthenticPlayCategory] {
        switch self {
        case .passShortLeft, .passShortMiddle, .passShortRight:
            return [.pass, .screen]
        case .passMediumLeft, .passMediumMiddle, .passMediumRight:
            return [.pass]
        case .passLongLeft, .passLongMiddle, .passLongRight:
            return [.pass, .playAction]
        case .runLeft, .runRight:
            return [.run, .draw]
        case .goalLineRun:
            return [.run]
        case .goalLinePass:
            return [.pass, .screen]
        case .razzleDazzleRun:
            return [.run, .draw]
        case .razzleDazzlePass:
            return [.playAction, .screen]
        }
    }

    /// Whether this is a run-type play
    public var isRun: Bool {
        switch self {
        case .runLeft, .runRight, .goalLineRun, .razzleDazzleRun: return true
        default: return false
        }
    }
}

/// Defensive play types from the original FPS '93 coaching profile system (10 types)
public enum CoachingDefensivePlayType: String, Codable, CaseIterable, Hashable {
    case runLeft          = "Defend Run Left"
    case runMiddle        = "Defend Run Middle"
    case runRight         = "Defend Run Right"
    case passShort        = "Defend Pass Short"
    case passMedium       = "Defend Pass Medium"
    case passLong         = "Defend Pass Long"
    case goalLineRun      = "Goal Line Run D"
    case goalLinePass     = "Goal Line Pass D"
    case razzleDazzleRun  = "Razzle Dazzle Run D"
    case razzleDazzlePass = "Razzle Dazzle Pass D"

    /// Map to the game's defensive PlayType + formation for actual play selection
    public var matchingCoverages: [PlayType] {
        switch self {
        case .runLeft, .runMiddle, .runRight:
            return [.coverTwo, .manCoverage]
        case .passShort:
            return [.coverTwo, .coverThree, .zoneBlitz]
        case .passMedium:
            return [.coverThree, .manCoverage]
        case .passLong:
            return [.coverFour, .coverThree]
        case .goalLineRun:
            return [.manCoverage, .blitz]
        case .goalLinePass:
            return [.manCoverage, .coverTwo]
        case .razzleDazzleRun:
            return [.blitz, .manCoverage]
        case .razzleDazzlePass:
            return [.zoneBlitz, .coverThree]
        }
    }

    /// Preferred defensive formations for this play type
    public var preferredFormations: [DefensiveFormation] {
        switch self {
        case .runLeft, .runMiddle, .runRight:
            return [.base43, .base34, .base44]
        case .passShort:
            return [.nickel, .base43]
        case .passMedium:
            return [.nickel, .dime]
        case .passLong:
            return [.dime, .prevent]
        case .goalLineRun, .goalLinePass:
            return [.goalLine, .goalLineDef]
        case .razzleDazzleRun, .razzleDazzlePass:
            return [.base43, .nickel]
        }
    }
}

// MARK: - Situation Key

/// A unique game situation combining all 5 dimensions. Hashable for dictionary lookup.
public struct CoachingSituationKey: Hashable, Codable {
    public let time: TimeBucket
    public let down: Int          // 1-4
    public let distance: YardsBucket
    public let field: FieldZone
    public let scoreDiff: ScoreDiffBucket

    public init(time: TimeBucket, down: Int, distance: YardsBucket, field: FieldZone, scoreDiff: ScoreDiffBucket) {
        self.time = time
        self.down = down
        self.distance = distance
        self.field = field
        self.scoreDiff = scoreDiff
    }

    /// Create from raw game state values
    public static func from(secondsInHalf: Int, down: Int, yardsToGo: Int, fieldPosition: Int, scoreDifferential: Int) -> CoachingSituationKey {
        CoachingSituationKey(
            time: TimeBucket.from(secondsRemainingInHalf: secondsInHalf),
            down: min(max(down, 1), 4),
            distance: YardsBucket.from(yardsToGo: yardsToGo),
            field: FieldZone.from(fieldPosition: fieldPosition),
            scoreDiff: ScoreDiffBucket.from(scoreDifferential: scoreDifferential)
        )
    }

    /// Create from the existing GameSituation struct used by AICoach
    public static func from(situation: GameSituation) -> CoachingSituationKey {
        // Convert quarter-based time remaining to half-remaining seconds
        let secondsInHalf: Int
        if situation.quarter == 1 || situation.quarter == 3 {
            // First quarter of the half: add a full second quarter
            secondsInHalf = situation.timeRemaining + 900
        } else {
            // Second quarter of the half (Q2 or Q4)
            secondsInHalf = situation.timeRemaining
        }

        return from(
            secondsInHalf: secondsInHalf,
            down: situation.down,
            yardsToGo: situation.yardsToGo,
            fieldPosition: situation.fieldPosition,
            scoreDifferential: situation.scoreDifferential
        )
    }
}

// MARK: - Situation Response

/// For each situation, 3 weighted play type choices (weights sum to 100) + stop clock flag
public struct OffensiveSituationResponse: Codable {
    public let choices: [(type: CoachingPlayType, weight: Int)]
    public let stopClock: Bool

    public init(choices: [(CoachingPlayType, Int)], stopClock: Bool = false) {
        self.choices = choices.map { (type: $0.0, weight: $0.1) }
        self.stopClock = stopClock
    }

    // Custom Codable since tuples aren't Codable by default
    enum CodingKeys: String, CodingKey { case choices, stopClock }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawChoices = try container.decode([[String]].self, forKey: .choices)
        choices = rawChoices.compactMap { arr in
            guard arr.count == 2,
                  let type = CoachingPlayType(rawValue: arr[0]),
                  let weight = Int(arr[1]) else { return nil }
            return (type: type, weight: weight)
        }
        stopClock = try container.decode(Bool.self, forKey: .stopClock)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let rawChoices = choices.map { ["\($0.type.rawValue)", "\($0.weight)"] }
        try container.encode(rawChoices, forKey: .choices)
        try container.encode(stopClock, forKey: .stopClock)
    }
}

public struct DefensiveSituationResponse: Codable {
    public let choices: [(type: CoachingDefensivePlayType, weight: Int)]
    public let stopClock: Bool

    public init(choices: [(CoachingDefensivePlayType, Int)], stopClock: Bool = false) {
        self.choices = choices.map { (type: $0.0, weight: $0.1) }
        self.stopClock = stopClock
    }

    enum CodingKeys: String, CodingKey { case choices, stopClock }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawChoices = try container.decode([[String]].self, forKey: .choices)
        choices = rawChoices.compactMap { arr in
            guard arr.count == 2,
                  let type = CoachingDefensivePlayType(rawValue: arr[0]),
                  let weight = Int(arr[1]) else { return nil }
            return (type: type, weight: weight)
        }
        stopClock = try container.decode(Bool.self, forKey: .stopClock)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let rawChoices = choices.map { ["\($0.type.rawValue)", "\($0.weight)"] }
        try container.encode(rawChoices, forKey: .choices)
        try container.encode(stopClock, forKey: .stopClock)
    }
}

// MARK: - Coaching Profile

/// A complete coaching profile with situational play weights for all 2,520 game situations.
public struct CoachingProfile: Codable {
    public let name: String
    public let description: String
    public var fgRange: Int  // 5-50 yards, auto-kick FG on 4th down when in range

    // Offensive profiles store offensive responses; defensive profiles store defensive responses.
    // A team has one offensive + one defensive profile active.
    public var offensiveResponses: [CoachingSituationKey: OffensiveSituationResponse]
    public var defensiveResponses: [CoachingSituationKey: DefensiveSituationResponse]

    public init(name: String, description: String, fgRange: Int,
                offensiveResponses: [CoachingSituationKey: OffensiveSituationResponse] = [:],
                defensiveResponses: [CoachingSituationKey: DefensiveSituationResponse] = [:]) {
        self.name = name
        self.description = description
        self.fgRange = min(max(fgRange, 5), 50)
        self.offensiveResponses = offensiveResponses
        self.defensiveResponses = defensiveResponses
    }

    /// Total number of situations covered
    public var offensiveSituationCount: Int { offensiveResponses.count }
    public var defensiveSituationCount: Int { defensiveResponses.count }

    /// Look up the offensive response for a given situation
    public func offensiveResponse(for key: CoachingSituationKey) -> OffensiveSituationResponse? {
        offensiveResponses[key]
    }

    /// Look up the defensive response for a given situation
    public func defensiveResponse(for key: CoachingSituationKey) -> DefensiveSituationResponse? {
        defensiveResponses[key]
    }

    /// Roll a weighted random offensive play type from the situation response
    public func rollOffensivePlayType(for key: CoachingSituationKey) -> CoachingPlayType? {
        guard let response = offensiveResponses[key], !response.choices.isEmpty else { return nil }
        let totalWeight = response.choices.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }
        var roll = Int.random(in: 1...totalWeight)
        for choice in response.choices {
            roll -= choice.weight
            if roll <= 0 { return choice.type }
        }
        return response.choices.last?.type
    }

    /// Roll a weighted random defensive play type from the situation response
    public func rollDefensivePlayType(for key: CoachingSituationKey) -> CoachingDefensivePlayType? {
        guard let response = defensiveResponses[key], !response.choices.isEmpty else { return nil }
        let totalWeight = response.choices.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }
        var roll = Int.random(in: 1...totalWeight)
        for choice in response.choices {
            roll -= choice.weight
            if roll <= 0 { return choice.type }
        }
        return response.choices.last?.type
    }
}

// MARK: - Default Profile Generation

/// Factory for the 4 default coaching profiles matching the original FPS '93 game:
/// OFF1 (conservative), OFF2 (aggressive), DEF1 (conservative), DEF2 (aggressive)
public struct CoachingProfileDefaults {

    /// All 4 default profiles
    public static var allProfiles: [CoachingProfile] {
        [off1, off2, def1, def2]
    }

    // MARK: OFF1 — Conservative Offense

    public static var off1: CoachingProfile {
        var profile = CoachingProfile(
            name: "OFF1",
            description: "Conservative offense: run-heavy on early downs, short passes on 3rd-and-long, goal line runs near end zone",
            fgRange: 45
        )
        profile.offensiveResponses = generateOffensiveResponses(style: .conservative)
        return profile
    }

    // MARK: OFF2 — Aggressive Offense

    public static var off2: CoachingProfile {
        var profile = CoachingProfile(
            name: "OFF2",
            description: "Aggressive offense: more deep passes, play action, spread formation",
            fgRange: 50
        )
        profile.offensiveResponses = generateOffensiveResponses(style: .aggressive)
        return profile
    }

    // MARK: DEF1 — Conservative Defense

    public static var def1: CoachingProfile {
        var profile = CoachingProfile(
            name: "DEF1",
            description: "Conservative defense: zone coverage, prevent big plays, standard rush",
            fgRange: 45
        )
        profile.defensiveResponses = generateDefensiveResponses(style: .conservative)
        return profile
    }

    // MARK: DEF2 — Aggressive Defense

    public static var def2: CoachingProfile {
        var profile = CoachingProfile(
            name: "DEF2",
            description: "Aggressive defense: more blitzes, man coverage, press",
            fgRange: 45
        )
        profile.defensiveResponses = generateDefensiveResponses(style: .aggressive)
        return profile
    }

    // MARK: - Profile Generation Engine

    private enum Style {
        case conservative
        case aggressive
    }

    /// Generate all 2,520 offensive situation responses for a given style
    private static func generateOffensiveResponses(style: Style) -> [CoachingSituationKey: OffensiveSituationResponse] {
        var responses: [CoachingSituationKey: OffensiveSituationResponse] = [:]

        for time in TimeBucket.allCases {
            for down in 1...4 {
                for distance in YardsBucket.allCases {
                    for field in FieldZone.allCases {
                        for scoreDiff in ScoreDiffBucket.allCases {
                            let key = CoachingSituationKey(time: time, down: down, distance: distance, field: field, scoreDiff: scoreDiff)
                            responses[key] = offensiveResponse(style: style, time: time, down: down, distance: distance, field: field, scoreDiff: scoreDiff)
                        }
                    }
                }
            }
        }

        return responses
    }

    /// Generate all 2,520 defensive situation responses for a given style
    private static func generateDefensiveResponses(style: Style) -> [CoachingSituationKey: DefensiveSituationResponse] {
        var responses: [CoachingSituationKey: DefensiveSituationResponse] = [:]

        for time in TimeBucket.allCases {
            for down in 1...4 {
                for distance in YardsBucket.allCases {
                    for field in FieldZone.allCases {
                        for scoreDiff in ScoreDiffBucket.allCases {
                            let key = CoachingSituationKey(time: time, down: down, distance: distance, field: field, scoreDiff: scoreDiff)
                            responses[key] = defensiveResponse(style: style, time: time, down: down, distance: distance, field: field, scoreDiff: scoreDiff)
                        }
                    }
                }
            }
        }

        return responses
    }

    // MARK: - Offensive Situation Rules

    private static func offensiveResponse(style: Style, time: TimeBucket, down: Int, distance: YardsBucket, field: FieldZone, scoreDiff: ScoreDiffBucket) -> OffensiveSituationResponse {

        // Stop clock: trailing with little time left
        let stopClock = (time == .t0_2 && scoreDiff == .losingBig)

        let choices: [(CoachingPlayType, Int)]

        // --- Goal Line (inside 3) ---
        if field == .goalLine {
            if style == .conservative {
                choices = [(.goalLineRun, 55), (.goalLinePass, 30), (.runRight, 15)]
            } else {
                choices = [(.goalLinePass, 45), (.goalLineRun, 35), (.passShortMiddle, 20)]
            }
            return OffensiveSituationResponse(choices: choices, stopClock: stopClock)
        }

        // --- Red Zone (opp 10-1) ---
        if field == .opp10_1 {
            if down <= 2 {
                if style == .conservative {
                    choices = [(.runRight, 40), (.passShortMiddle, 35), (.runLeft, 25)]
                } else {
                    choices = [(.passShortMiddle, 40), (.passShortLeft, 30), (.runRight, 30)]
                }
            } else {
                // 3rd/4th down in red zone
                choices = [(.passShortMiddle, 45), (.passShortRight, 30), (.runRight, 25)]
            }
            return OffensiveSituationResponse(choices: choices, stopClock: stopClock)
        }

        // --- Hurry-up / 2-minute drill (losing, under 2 minutes) ---
        if time == .t0_2 && scoreDiff == .losingBig {
            choices = [(.passLongMiddle, 40), (.passMediumRight, 35), (.passMediumLeft, 25)]
            return OffensiveSituationResponse(choices: choices, stopClock: true)
        }
        if time == .t0_2 && scoreDiff == .within7 {
            if style == .conservative {
                choices = [(.passMediumMiddle, 40), (.passShortRight, 35), (.runRight, 25)]
            } else {
                choices = [(.passMediumMiddle, 45), (.passLongRight, 30), (.passShortLeft, 25)]
            }
            return OffensiveSituationResponse(choices: choices, stopClock: true)
        }

        // --- Ahead big, run the clock ---
        if scoreDiff == .aheadBig && (time == .t0_2 || time == .t2_5) {
            choices = [(.runRight, 45), (.runLeft, 35), (.passShortMiddle, 20)]
            return OffensiveSituationResponse(choices: choices, stopClock: false)
        }

        // --- Backed up (own 1-10) ---
        if field == .own1_10 {
            if style == .conservative {
                choices = [(.runRight, 45), (.runLeft, 30), (.passShortMiddle, 25)]
            } else {
                choices = [(.runRight, 35), (.passShortMiddle, 35), (.passMediumRight, 30)]
            }
            return OffensiveSituationResponse(choices: choices, stopClock: stopClock)
        }

        // --- Down-and-distance logic ---
        switch (down, distance) {

        // 1st down: balanced or run-heavy
        case (1, _):
            if style == .conservative {
                choices = [(.runRight, 40), (.runLeft, 25), (.passShortMiddle, 35)]
            } else {
                let paType = playActionPassType(field: field)
                choices = [(.passMediumMiddle, 35), (.runRight, 30), (paType, 35)]
            }

        // 2nd and short (1-2)
        case (2, .y1_2):
            if style == .conservative {
                choices = [(.runRight, 50), (.runLeft, 30), (.passShortMiddle, 20)]
            } else {
                choices = [(.runRight, 35), (.passMediumRight, 35), (.razzleDazzlePass, 30)]
            }

        // 2nd and medium (3-5)
        case (2, .y3_5):
            if style == .conservative {
                choices = [(.runRight, 40), (.passShortMiddle, 35), (.passShortRight, 25)]
            } else {
                choices = [(.passMediumMiddle, 40), (.runLeft, 30), (.passShortLeft, 30)]
            }

        // 2nd and standard (6-10)
        case (2, .y6_10):
            if style == .conservative {
                choices = [(.passShortMiddle, 40), (.runRight, 35), (.passMediumRight, 25)]
            } else {
                choices = [(.passMediumMiddle, 40), (.passMediumRight, 30), (.runRight, 30)]
            }

        // 2nd and long (11+)
        case (2, .y11_15), (2, .y16plus):
            if style == .conservative {
                choices = [(.passShortMiddle, 40), (.passMediumMiddle, 35), (.runRight, 25)]
            } else {
                choices = [(.passMediumLeft, 40), (.passLongMiddle, 35), (.passShortRight, 25)]
            }

        // 3rd and short (1-2): power running
        case (3, .y1_2):
            if style == .conservative {
                choices = [(.runRight, 50), (.passShortMiddle, 30), (.runLeft, 20)]
            } else {
                choices = [(.runRight, 35), (.passShortMiddle, 35), (.razzleDazzleRun, 30)]
            }

        // 3rd and medium (3-5)
        case (3, .y3_5):
            if style == .conservative {
                choices = [(.passShortMiddle, 45), (.passShortRight, 30), (.runRight, 25)]
            } else {
                choices = [(.passMediumMiddle, 40), (.passShortLeft, 35), (.razzleDazzlePass, 25)]
            }

        // 3rd and standard (6-10)
        case (3, .y6_10):
            choices = [(.passMediumMiddle, 45), (.passMediumRight, 30), (.passShortLeft, 25)]

        // 3rd and long (11+)
        case (3, .y11_15), (3, .y16plus):
            if style == .conservative {
                choices = [(.passMediumMiddle, 40), (.passLongMiddle, 35), (.passShortRight, 25)]
            } else {
                choices = [(.passLongMiddle, 40), (.passLongRight, 35), (.passMediumLeft, 25)]
            }

        // 4th down — almost always punt/FG, but if going for it:
        case (4, .y1_2):
            choices = [(.runRight, 50), (.passShortMiddle, 30), (.goalLineRun, 20)]
        case (4, _):
            // Longer 4th downs: pass-heavy desperation
            choices = [(.passMediumMiddle, 40), (.passLongMiddle, 35), (.passShortRight, 25)]

        default:
            choices = [(.runRight, 35), (.passShortMiddle, 35), (.passMediumMiddle, 30)]
        }

        return OffensiveSituationResponse(choices: choices, stopClock: stopClock)
    }

    /// Helper: pick appropriate play-action pass type based on field position
    private static func playActionPassType(field: FieldZone) -> CoachingPlayType {
        switch field {
        case .opp25_11, .opp10_1, .goalLine:
            return .passMediumMiddle
        case .opp49_26:
            return .passLongMiddle
        default:
            return .passMediumRight
        }
    }

    // MARK: - Defensive Situation Rules

    private static func defensiveResponse(style: Style, time: TimeBucket, down: Int, distance: YardsBucket, field: FieldZone, scoreDiff: ScoreDiffBucket) -> DefensiveSituationResponse {

        let stopClock = false // Defense doesn't normally control clock stops

        let choices: [(CoachingDefensivePlayType, Int)]

        // --- Goal Line ---
        if field == .goalLine || field == .opp10_1 {
            if style == .conservative {
                choices = [(.goalLineRun, 50), (.goalLinePass, 35), (.runMiddle, 15)]
            } else {
                choices = [(.goalLinePass, 40), (.goalLineRun, 35), (.razzleDazzleRun, 25)]
            }
            return DefensiveSituationResponse(choices: choices, stopClock: stopClock)
        }

        // --- Prevent defense: ahead big, late game ---
        if scoreDiff == .aheadBig && (time == .t0_2 || time == .t2_5) {
            choices = [(.passLong, 50), (.passMedium, 35), (.passShort, 15)]
            return DefensiveSituationResponse(choices: choices, stopClock: stopClock)
        }

        // --- Opponent in hurry-up (losing, under 2 min) ---
        if time == .t0_2 && scoreDiff == .aheadBig {
            choices = [(.passLong, 45), (.passMedium, 35), (.passShort, 20)]
            return DefensiveSituationResponse(choices: choices, stopClock: stopClock)
        }

        // --- Down-and-distance logic ---
        switch (down, distance) {

        // 1st down: expect balanced / run
        case (1, _):
            if style == .conservative {
                choices = [(.runMiddle, 40), (.runRight, 30), (.passShort, 30)]
            } else {
                choices = [(.runMiddle, 35), (.passShort, 35), (.razzleDazzleRun, 30)]
            }

        // 2nd and short: expect run
        case (2, .y1_2):
            if style == .conservative {
                choices = [(.runMiddle, 50), (.runLeft, 30), (.passShort, 20)]
            } else {
                choices = [(.runMiddle, 40), (.razzleDazzleRun, 35), (.passShort, 25)]
            }

        // 2nd and medium
        case (2, .y3_5):
            choices = [(.runMiddle, 35), (.passShort, 35), (.passMedium, 30)]

        // 2nd and standard/long
        case (2, .y6_10), (2, .y11_15), (2, .y16plus):
            if style == .conservative {
                choices = [(.passShort, 40), (.passMedium, 35), (.runMiddle, 25)]
            } else {
                choices = [(.passMedium, 40), (.passShort, 30), (.razzleDazzlePass, 30)]
            }

        // 3rd and short: expect run
        case (3, .y1_2):
            if style == .conservative {
                choices = [(.runMiddle, 50), (.runRight, 30), (.passShort, 20)]
            } else {
                choices = [(.runMiddle, 40), (.razzleDazzleRun, 35), (.passShort, 25)]
            }

        // 3rd and medium
        case (3, .y3_5):
            if style == .conservative {
                choices = [(.passShort, 45), (.runMiddle, 30), (.passMedium, 25)]
            } else {
                choices = [(.passShort, 35), (.passMedium, 35), (.razzleDazzlePass, 30)]
            }

        // 3rd and long
        case (3, .y6_10), (3, .y11_15), (3, .y16plus):
            if style == .conservative {
                choices = [(.passMedium, 45), (.passLong, 30), (.passShort, 25)]
            } else {
                choices = [(.passLong, 40), (.passMedium, 35), (.razzleDazzlePass, 25)]
            }

        // 4th down: expect pass or trick play
        case (4, .y1_2):
            choices = [(.runMiddle, 45), (.passShort, 35), (.goalLineRun, 20)]
        case (4, _):
            choices = [(.passMedium, 40), (.passLong, 35), (.passShort, 25)]

        default:
            choices = [(.runMiddle, 35), (.passShort, 35), (.passMedium, 30)]
        }

        return DefensiveSituationResponse(choices: choices, stopClock: stopClock)
    }
}
