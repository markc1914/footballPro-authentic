//
//  Play.swift
//  footballPro
//
//  Play types, formations, and outcomes
//

import Foundation

// MARK: - Play Type

public enum PlayType: String, Codable, CaseIterable { // Public for external use
    // Run plays
    case insideRun = "Inside Run"
    case outsideRun = "Outside Run"
    case draw = "Draw"
    case counter = "Counter"
    case sweep = "Sweep"
    case qbSneak = "QB Sneak"
    case qbScramble = "QB Scramble"

    // Pass plays
    case shortPass = "Short Pass"
    case mediumPass = "Medium Pass"
    case deepPass = "Deep Pass"
    case screen = "Screen"
    case playAction = "Play Action"
    case rollout = "Rollout"

    // Special teams
    case kickoff = "Kickoff"
    case punt = "Punt"
    case fieldGoal = "Field Goal"
    case extraPoint = "Extra Point"
    case twoPointConversion = "Two Point Conversion"
    case onsideKick = "Onside Kick"

    // Defense (for play calling)
    case coverTwo = "Cover 2"
    case coverThree = "Cover 3"
    case coverFour = "Cover 4"
    case manCoverage = "Man Coverage"
    case blitz = "Blitz"
    case zoneBlitz = "Zone Blitz"

    public var isRun: Bool {
        switch self {
        case .insideRun, .outsideRun, .draw, .counter, .sweep, .qbSneak, .qbScramble:
            return true
        default:
            return false
        }
    }

    public var isPass: Bool {
        switch self {
        case .shortPass, .mediumPass, .deepPass, .screen, .playAction, .rollout:
            return true
        default:
            return false
        }
    }

    public var isSpecialTeams: Bool {
        switch self {
        case .kickoff, .punt, .fieldGoal, .extraPoint, .twoPointConversion, .onsideKick:
            return true
        default:
            return false
        }
    }

    public var isDefense: Bool {
        switch self {
        case .coverTwo, .coverThree, .coverFour, .manCoverage, .blitz, .zoneBlitz:
            return true
        default:
            return false
        }
    }

    public var averageYards: Double {
        switch self {
        case .insideRun: return 3.5
        case .outsideRun: return 4.0
        case .draw: return 4.5
        case .counter: return 4.2
        case .sweep: return 5.0
        case .qbSneak: return 1.5
        case .qbScramble: return 6.0
        case .shortPass: return 5.0
        case .mediumPass: return 12.0
        case .deepPass: return 25.0
        case .screen: return 6.0
        case .playAction: return 15.0
        case .rollout: return 8.0
        default: return 0
        }
    }

    public var riskLevel: Int { // 1-10, higher = riskier
        switch self {
        case .qbSneak: return 1
        case .insideRun: return 2
        case .outsideRun: return 3
        case .shortPass: return 3
        case .draw: return 4
        case .screen: return 4
        case .mediumPass: return 5
        case .counter: return 5
        case .sweep: return 5
        case .rollout: return 6
        case .playAction: return 6
        case .qbScramble: return 7
        case .deepPass: return 8
        default: return 5
        }
    }
}

// MARK: - Formation

public enum OffensiveFormation: String, Codable, CaseIterable { // Public
    case singleback = "Singleback"
    case iFormation = "I-Formation"
    case shotgun = "Shotgun"
    case pistol = "Pistol"
    case emptySet = "Empty Set"
    case goalLine = "Goal Line"
    case jumbo = "Jumbo"
    case proSet = "Pro Set"
    case spread = "Spread"
    case trips = "Trips"
    case nearFormation = "Near"
    case doubleWing = "Double Wing"
    case iSlot = "I-Slot"
    case loneBack = "Lone Back"

    public var description: String {
        switch self {
        case .singleback: return "One RB behind QB, balanced formation"
        case .iFormation: return "FB and RB stacked behind QB, power running"
        case .shotgun: return "QB in shotgun, pass-heavy formation"
        case .pistol: return "RB directly behind shotgun QB"
        case .emptySet: return "No backs, 5 receivers"
        case .goalLine: return "Heavy formation for short yardage"
        case .jumbo: return "Extra linemen, power running"
        case .proSet: return "QB under center, FB and RB offset, balanced"
        case .spread: return "4 WR spread wide, 1 RB, shotgun"
        case .trips: return "3 WR on one side, stretches defense"
        case .nearFormation: return "Strong-side overload, power running"
        case .doubleWing: return "Two wingbacks flanking TE, misdirection"
        case .iSlot: return "I-Formation with slot receiver"
        case .loneBack: return "Single back 7 yards deep, 3 WR"
        }
    }

    public var suggestedPlays: [PlayType] {
        switch self {
        case .singleback:
            return [.insideRun, .outsideRun, .shortPass, .playAction]
        case .iFormation:
            return [.insideRun, .counter, .playAction, .sweep]
        case .shotgun:
            return [.shortPass, .mediumPass, .deepPass, .screen, .draw]
        case .pistol:
            return [.draw, .insideRun, .playAction, .mediumPass]
        case .emptySet:
            return [.shortPass, .mediumPass, .deepPass, .screen]
        case .goalLine:
            return [.qbSneak, .insideRun, .playAction]
        case .jumbo:
            return [.insideRun, .qbSneak]
        case .proSet:
            return [.insideRun, .outsideRun, .playAction, .shortPass]
        case .spread:
            return [.shortPass, .mediumPass, .deepPass, .screen, .draw]
        case .trips:
            return [.shortPass, .mediumPass, .deepPass, .screen]
        case .nearFormation:
            return [.insideRun, .counter, .sweep, .playAction]
        case .doubleWing:
            return [.insideRun, .counter, .sweep, .playAction]
        case .iSlot:
            return [.insideRun, .counter, .playAction, .mediumPass]
        case .loneBack:
            return [.insideRun, .outsideRun, .playAction, .mediumPass]
        }
    }
}

// NEW HELPER: Map UInt16 formation code to OffensiveFormation enum
public extension OffensiveFormation {
    static func fromPrfFormationCode(_ prfFormationCode: UInt16) -> OffensiveFormation {
        switch prfFormationCode {
        case 0x8501: return .iFormation
        case 0x8502: return .iFormation // I-Form Var
        case 0x8505: return .shotgun
        case 0x8506: return .singleback
        case 0x850A: return .goalLine // Goal Line Off
        // Add more mappings as discovered/needed
        default: return .singleback // Default to a common offensive formation
        }
    }
}


public enum DefensiveFormation: String, Codable, CaseIterable { // Public
    case base43 = "4-3"
    case base34 = "3-4"
    case nickel = "Nickel"
    case dime = "Dime"
    case goalLine = "Goal Line"
    case prevent = "Prevent"
    case base46 = "4-6"
    case base33 = "3-3"
    case base44 = "4-4"
    case flex = "Flex"
    case goalLineDef = "Goal Line D"

    public var description: String {
        switch self {
        case .base43: return "4 linemen, 3 linebackers - balanced"
        case .base34: return "3 linemen, 4 linebackers - versatile"
        case .nickel: return "5 DBs - pass defense focus"
        case .dime: return "6 DBs - heavy pass defense"
        case .goalLine: return "Heavy personnel to stop short runs"
        case .prevent: return "Deep coverage to prevent big plays"
        case .base46: return "Aggressive 46 defense, 8 in the box"
        case .base33: return "3-3 stack, balanced pass/run"
        case .base44: return "4-4 stack, strong run defense"
        case .flex: return "Staggered DL depths, disguised coverage"
        case .goalLineDef: return "Heavy goal line defense, everyone up close"
        }
    }

    public var suggestedCoverages: [PlayType] {
        switch self {
        case .base43:
            return [.coverTwo, .coverThree, .manCoverage]
        case .base34:
            return [.coverTwo, .coverThree, .zoneBlitz]
        case .nickel:
            return [.coverTwo, .coverThree, .manCoverage, .blitz]
        case .dime:
            return [.coverFour, .coverThree, .manCoverage]
        case .goalLine:
            return [.manCoverage, .blitz]
        case .prevent:
            return [.coverFour, .coverThree]
        case .base46:
            return [.manCoverage, .blitz, .coverTwo]
        case .base33:
            return [.coverThree, .coverTwo, .manCoverage]
        case .base44:
            return [.coverTwo, .manCoverage, .blitz]
        case .flex:
            return [.coverTwo, .coverThree, .zoneBlitz]
        case .goalLineDef:
            return [.manCoverage, .blitz]
        }
    }

    public var runStopRating: Int {
        switch self {
        case .base43: return 75
        case .base34: return 80
        case .nickel: return 60
        case .dime: return 45
        case .goalLine: return 95
        case .prevent: return 40
        case .base46: return 90
        case .base33: return 65
        case .base44: return 85
        case .flex: return 75
        case .goalLineDef: return 95
        }
    }

    public var passDefenseRating: Int {
        switch self {
        case .base43: return 70
        case .base34: return 70
        case .nickel: return 80
        case .dime: return 90
        case .goalLine: return 50
        case .prevent: return 95
        case .base46: return 55
        case .base33: return 75
        case .base44: return 55
        case .flex: return 72
        case .goalLineDef: return 45
        }
    }
}

// NEW HELPER: Map UInt16 defensive formation code to DefensiveFormation enum
public extension DefensiveFormation {
    static func fromPrfFormationCode(_ prfFormationCode: UInt16) -> DefensiveFormation {
        switch prfFormationCode {
        case 0x8401: return .base43
        case 0x8402: return .base34
        case 0x8403: return .base43   // 4-3 variant
        case 0x8404: return .nickel
        case 0x8405: return .dime
        case 0x8406: return .goalLine  // Goal Line Def
        case 0x8407: return .prevent
        default: return .base43       // Default to common defensive formation
        }
    }
}

// MARK: - Play Call Protocol

public protocol PlayCall: Codable, Equatable {
    var name: String { get }
    var playType: PlayType { get }
    var formation: OffensiveFormation { get } // Assuming OffensiveFormation for all PlayCalls
    var isAudible: Bool { get }
    var displayName: String { get }
}

public protocol DefensiveCall: Codable, Equatable { // Renaming to DefensiveCall, was a struct
    var formation: DefensiveFormation { get }
    var coverage: PlayType { get }
    var isBlitzing: Bool { get }
    var blitzTarget: Position? { get }
    var displayName: String { get }
}


// MARK: - Standard Play Call Implementations

public struct StandardPlayCall: PlayCall {
    public var formation: OffensiveFormation
    public var playType: PlayType
    public var targetReceiver: Int? // Specific to standard play calls
    public var audibleOption: PlayType? // Specific to standard play calls

    public var name: String { return "\(formation.rawValue) - \(playType.rawValue)" }
    public var isAudible: Bool { return audibleOption != nil }
    public var displayName: String { return name }
}

public struct StandardDefensiveCall: DefensiveCall { // Renamed original struct
    public var formation: DefensiveFormation
    public var coverage: PlayType
    public var isBlitzing: Bool
    public var blitzTarget: Position?

    public var displayName: String {
        "\(formation.rawValue) - \(coverage.rawValue)"
    }
}


// MARK: - Play Outcome

public struct PlayOutcome: Codable, Equatable {
    public var yardsGained: Int
    public var timeElapsed: Int // Seconds
    public var isComplete: Bool // For passes
    public var isTouchdown: Bool
    public var isTurnover: Bool
    public var turnoverType: TurnoverType?
    public var isPenalty: Bool
    public var penalty: Penalty?
    public var isInjury: Bool
    public var injuredPlayerId: UUID?

    public var description: String // Play-by-play text

    public static func incomplete() -> PlayOutcome {
        PlayOutcome(
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
            description: "Pass incomplete"
        )
    }
}

public enum TurnoverType: String, Codable {
    case interception = "INT"
    case fumble = "FUM"
    case fumbleRecovery = "FUM REC"
    case turnoverOnDowns = "TOD"
}

// MARK: - Penalty

public struct Penalty: Codable, Equatable {
    public var type: PenaltyType
    public var yards: Int
    public var isOnOffense: Bool
    public var isDeclined: Bool
    public var playerNumber: Int?

    public var description: String {
        let team = isOnOffense ? "Offense" : "Defense"
        return "\(type.rawValue) on \(team), \(yards) yards"
    }
}

public enum PenaltyType: String, Codable, CaseIterable {
    case offside = "Offside"
    case falseStart = "False Start"
    case holding = "Holding"
    case passInterference = "Pass Interference"
    case roughingThePasser = "Roughing the Passer"
    case unsportsmanlike = "Unsportsmanlike Conduct"
    case delay = "Delay of Game"
    case illegalMotion = "Illegal Motion"
    case facemask = "Facemask"
    case horseCollar = "Horse Collar"
    case intentionalGrounding = "Intentional Grounding"
    case illegalBlock = "Illegal Block"

    public var yards: Int {
        switch self {
        case .offside, .falseStart, .delay, .illegalMotion:
            return 5
        case .holding, .illegalBlock:
            return 10
        case .passInterference, .roughingThePasser, .horseCollar, .facemask:
            return 15
        case .unsportsmanlike, .intentionalGrounding:
            return 15
        }
    }

    public var isAutoFirstDown: Bool {
        switch self {
        case .roughingThePasser, .passInterference, .facemask, .horseCollar:
            return true
        default:
            return false
        }
    }

    /// Penalties that can ONLY be called on the offense
    public var isAlwaysOffense: Bool {
        switch self {
        case .falseStart, .delay, .illegalMotion, .intentionalGrounding, .illegalBlock:
            return true
        default:
            return false
        }
    }

    /// Penalties that can ONLY be called on the defense
    public var isAlwaysDefense: Bool {
        switch self {
        case .offside, .roughingThePasser:
            return true
        default:
            return false
        }
    }
}

// MARK: - Playbook

public struct Playbook: Codable, Equatable {
    public var teamId: UUID
    public var offensivePlays: [StandardPlayCall] // Reverted to concrete type
    public var defensivePlays: [StandardDefensiveCall] // Reverted to concrete type
    public var favoriteRunPlays: [PlayType]
    public var favoritePassPlays: [PlayType]

    public static func standard(for teamId: UUID) -> Playbook {
        var plays: [StandardPlayCall] = [] // Reverted to concrete type

        // Generate standard offensive plays
        for formation in OffensiveFormation.allCases {
            for playType in formation.suggestedPlays {
                plays.append(StandardPlayCall(formation: formation, playType: playType)) // Use StandardPlayCall
            }
        }

        var defensivePlays: [StandardDefensiveCall] = [] // Reverted to concrete type
        for formation in DefensiveFormation.allCases {
            for coverage in formation.suggestedCoverages {
                defensivePlays.append(StandardDefensiveCall( // Use StandardDefensiveCall
                    formation: formation,
                    coverage: coverage,
                    isBlitzing: coverage == .blitz || coverage == .zoneBlitz
                ))
            }
        }

        return Playbook(
            teamId: teamId,
            offensivePlays: plays,
            defensivePlays: defensivePlays,
            favoriteRunPlays: [.insideRun, .outsideRun, .draw],
            favoritePassPlays: [.shortPass, .mediumPass, .playAction]
        )
    }
}