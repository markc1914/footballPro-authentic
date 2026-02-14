//
//  Player.swift
//  footballPro
//
//  Player model with attributes, ratings, stats, and contracts
//

import Foundation

// MARK: - Position

public enum Position: String, Codable, CaseIterable { // Public
    // Offense
    case quarterback = "QB"
    case runningBack = "RB"
    case fullback = "FB"
    case wideReceiver = "WR"
    case tightEnd = "TE"
    case leftTackle = "LT"
    case leftGuard = "LG"
    case center = "C"
    case rightGuard = "RG"
    case rightTackle = "RT"

    // Defense
    case defensiveEnd = "DE"
    case defensiveTackle = "DT"
    case outsideLinebacker = "OLB"
    case middleLinebacker = "MLB"
    case cornerback = "CB"
    case freeSafety = "FS"
    case strongSafety = "SS"

    // Special Teams
    case kicker = "K"
    case punter = "P"

    public var isOffense: Bool {
        switch self {
        case .quarterback, .runningBack, .fullback, .wideReceiver, .tightEnd,
             .leftTackle, .leftGuard, .center, .rightGuard, .rightTackle:
            return true
        default:
            return false
        }
    }

    public var isDefense: Bool {
        switch self {
        case .defensiveEnd, .defensiveTackle, .outsideLinebacker, .middleLinebacker,
             .cornerback, .freeSafety, .strongSafety:
            return true
        default:
            return false
        }
    }

    public var isSpecialTeams: Bool {
        switch self {
        case .kicker, .punter:
            return true
        default:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .quarterback: return "Quarterback"
        case .runningBack: return "Running Back"
        case .fullback: return "Fullback"
        case .wideReceiver: return "Wide Receiver"
        case .tightEnd: return "Tight End"
        case .leftTackle: return "Left Tackle"
        case .leftGuard: return "Left Guard"
        case .center: return "Center"
        case .rightGuard: return "Right Guard"
        case .rightTackle: return "Right Tackle"
        case .defensiveEnd: return "Defensive End"
        case .defensiveTackle: return "Defensive Tackle"
        case .outsideLinebacker: return "Outside Linebacker"
        case .middleLinebacker: return "Middle Linebacker"
        case .cornerback: return "Cornerback"
        case .freeSafety: return "Free Safety"
        case .strongSafety: return "Strong Safety"
        case .kicker: return "Kicker"
        case .punter: return "Punter"
        }
    }
}

// MARK: - Player Ratings

public struct PlayerRatings: Codable, Equatable { // Public
    // Core physical attributes (1-99)
    public var speed: Int
    public var strength: Int
    public var agility: Int
    public var stamina: Int
    public var awareness: Int
    public var toughness: Int

    // Passing (QB focused)
    public var throwPower: Int
    public var throwAccuracyShort: Int
    public var throwAccuracyMid: Int
    public var throwAccuracyDeep: Int
    public var playAction: Int

    // Rushing
    public var carrying: Int
    public var breakTackle: Int
    public var trucking: Int
    public var elusiveness: Int
    public var ballCarrierVision: Int

    // Receiving
    public var catching: Int
    public var catchInTraffic: Int
    public var spectacularCatch: Int
    public var routeRunning: Int
    public var release: Int

    // Blocking
    public var runBlock: Int
    public var passBlock: Int
    public var impactBlock: Int

    // Defense
    public var tackle: Int
    public var hitPower: Int
    public var pursuit: Int
    public var playRecognition: Int
    public var manCoverage: Int
    public var zoneCoverage: Int
    public var press: Int
    public var blockShedding: Int
    public var passRush: Int

    // Special Teams
    public var kickPower: Int
    public var kickAccuracy: Int

    public var overall: Int {
        // Calculate weighted overall based on position relevance
        let attrs = [speed, strength, agility, stamina, awareness, toughness,
                     throwPower, carrying, catching, runBlock, passBlock,
                     tackle, hitPower, pursuit, playRecognition]
        return attrs.reduce(0, +) / attrs.count
    }

    public static func random(tier: PlayerTier) -> PlayerRatings {
        let range: ClosedRange<Int>
        switch tier {
        case .elite: range = 85...99
        case .starter: range = 72...88
        case .backup: range = 60...75
        case .reserve: range = 50...65
        }

        return PlayerRatings(
            speed: Int.random(in: range),
            strength: Int.random(in: range),
            agility: Int.random(in: range),
            stamina: Int.random(in: range),
            awareness: Int.random(in: range),
            toughness: Int.random(in: range),
            throwPower: Int.random(in: range),
            throwAccuracyShort: Int.random(in: range),
            throwAccuracyMid: Int.random(in: range),
            throwAccuracyDeep: Int.random(in: range),
            playAction: Int.random(in: range),
            carrying: Int.random(in: range),
            breakTackle: Int.random(in: range),
            trucking: Int.random(in: range),
            elusiveness: Int.random(in: range),
            ballCarrierVision: Int.random(in: range),
            catching: Int.random(in: range),
            catchInTraffic: Int.random(in: range),
            spectacularCatch: Int.random(in: range),
            routeRunning: Int.random(in: range),
            release: Int.random(in: range),
            runBlock: Int.random(in: range),
            passBlock: Int.random(in: range),
            impactBlock: Int.random(in: range),
            tackle: Int.random(in: range),
            hitPower: Int.random(in: range),
            pursuit: Int.random(in: range),
            playRecognition: Int.random(in: range),
            manCoverage: Int.random(in: range),
            zoneCoverage: Int.random(in: range),
            press: Int.random(in: range),
            blockShedding: Int.random(in: range),
            passRush: Int.random(in: range),
            kickPower: Int.random(in: range),
            kickAccuracy: Int.random(in: range)
        )
    }
}

public enum PlayerTier: String, Codable { // Public
    case elite
    case starter
    case backup
    case reserve
}

// MARK: - Player Stats

public struct SeasonStats: Codable, Equatable { // Public
    public var gamesPlayed: Int = 0

    // Passing
    public var passAttempts: Int = 0
    public var passCompletions: Int = 0
    public var passingYards: Int = 0
    public var passingTouchdowns: Int = 0
    public var interceptions: Int = 0
    public var sacks: Int = 0
    public var qbRating: Double = 0.0

    // Rushing
    public var rushAttempts: Int = 0
    public var rushingYards: Int = 0
    public var rushingTouchdowns: Int = 0
    public var fumbles: Int = 0
    public var fumblesLost: Int = 0

    // Receiving
    public var targets: Int = 0
    public var receptions: Int = 0
    public var receivingYards: Int = 0
    public var receivingTouchdowns: Int = 0
    public var drops: Int = 0

    // Defense
    public var totalTackles: Int = 0
    public var soloTackles: Int = 0
    public var assistedTackles: Int = 0
    public var tacklesForLoss: Int = 0
    public var defSacks: Double = 0.0
    public var interceptionsDef: Int = 0
    public var passesDefended: Int = 0
    public var forcedFumbles: Int = 0
    public var fumblesRecovered: Int = 0
    public var defensiveTouchdowns: Int = 0

    // Special Teams
    public var fieldGoalsMade: Int = 0
    public var fieldGoalsAttempted: Int = 0
    public var extraPointsMade: Int = 0
    public var extraPointsAttempted: Int = 0
    public var punts: Int = 0
    public var puntYards: Int = 0

    public var completionPercentage: Double {
        guard passAttempts > 0 else { return 0 }
        return Double(passCompletions) / Double(passAttempts) * 100
    }

    public var yardsPerCarry: Double {
        guard rushAttempts > 0 else { return 0 }
        return Double(rushingYards) / Double(rushAttempts)
    }

    public var yardsPerReception: Double {
        guard receptions > 0 else { return 0 }
        return Double(receivingYards) / Double(receptions)
    }

    public var fieldGoalPercentage: Double {
        guard fieldGoalsAttempted > 0 else { return 0 }
        return Double(fieldGoalsMade) / Double(fieldGoalsAttempted) * 100
    }
}

public struct GameStats: Codable, Equatable { // Public
    public var passAttempts: Int = 0
    public var passCompletions: Int = 0
    public var passingYards: Int = 0
    public var passingTouchdowns: Int = 0
    public var interceptions: Int = 0

    public var rushAttempts: Int = 0
    public var rushingYards: Int = 0
    public var rushingTouchdowns: Int = 0

    public var targets: Int = 0
    public var receptions: Int = 0
    public var receivingYards: Int = 0
    public var receivingTouchdowns: Int = 0

    public var totalTackles: Int = 0
    public var defSacks: Double = 0.0
    public var interceptionsDef: Int = 0
    public var passesDefended: Int = 0
}

// MARK: - Contract

public struct Contract: Codable, Equatable { // Public
    public var yearsRemaining: Int
    public var totalValue: Int // Total contract value in thousands
    public var yearlyValues: [Int] // Salary per year in thousands
    public var signingBonus: Int
    public var guaranteedMoney: Int

    public var currentYearSalary: Int {
        yearlyValues.first ?? 0
    }

    public var capHit: Int {
        currentYearSalary + (signingBonus / max(yearsRemaining, 1))
    }

    public static func rookie(round: Int, pick: Int) -> Contract {
        let baseValue: Int
        switch round {
        case 1: baseValue = 8000 + (32 - pick) * 500
        case 2: baseValue = 3000 + (32 - pick) * 100
        case 3: baseValue = 1500 + (32 - pick) * 50
        default: baseValue = 800
        }

        return Contract(
            yearsRemaining: 4,
            totalValue: baseValue * 4,
            yearlyValues: [baseValue, baseValue, baseValue + 500, baseValue + 1000],
            signingBonus: baseValue / 2,
            guaranteedMoney: baseValue * 2
        )
    }

    public static func veteran(rating: Int, position: Position) -> Contract {
        let positionMultiplier: Double
        switch position {
        case .quarterback: positionMultiplier = 2.5
        case .leftTackle, .cornerback: positionMultiplier = 1.5
        case .wideReceiver, .defensiveEnd: positionMultiplier = 1.3
        default: positionMultiplier = 1.0
        }

        let baseValue = Int(Double(rating * 100) * positionMultiplier)
        let years = Int.random(in: 2...5)

        var yearlyValues: [Int] = []
        for i in 0..<years {
            yearlyValues.append(baseValue + (i * 200))
        }

        return Contract(
            yearsRemaining: years,
            totalValue: yearlyValues.reduce(0, +),
            yearlyValues: yearlyValues,
            signingBonus: baseValue / 4,
            guaranteedMoney: baseValue * 2
        )
    }
}

// MARK: - Player Status

public struct PlayerStatus: Codable, Equatable { // Public
    public var health: Int // 0-100, below 80 is injured
    public var fatigue: Int // 0-100, higher is more tired
    public var morale: Int // 0-100
    public var injuryType: InjuryType?
    public var weeksInjured: Int

    public var isInjured: Bool { health < 80 }
    public var canPlay: Bool { health >= 60 && injuryType != .seasonEnding }

    public static var healthy: PlayerStatus {
        PlayerStatus(health: 100, fatigue: 0, morale: 75, injuryType: nil, weeksInjured: 0)
    }
}

public enum InjuryType: String, Codable { // Public
    case minor // 1-2 weeks
    case moderate // 3-6 weeks
    case major // 7-12 weeks
    case seasonEnding

    public var recoveryWeeks: ClosedRange<Int> {
        switch self {
        case .minor: return 1...2
        case .moderate: return 3...6
        case .major: return 7...12
        case .seasonEnding: return 14...20
        }
    }
}

// MARK: - Player

public struct Player: Identifiable, Codable, Equatable { // Public
    public let id: UUID
    public var firstName: String
    public var lastName: String
    public var position: Position
    public var age: Int
    public var height: Int // in inches
    public var weight: Int // in pounds
    public var college: String
    public var experience: Int // years in league

    public var ratings: PlayerRatings
    public var seasonStats: SeasonStats
    public var careerStats: SeasonStats
    public var contract: Contract
    public var status: PlayerStatus

    public var fullName: String {
        "\(firstName) \(lastName)"
    }

    public var displayHeight: String {
        let feet = height / 12
        let inches = height % 12
        return "\(feet)'\(inches)\""  
    }

    public var overall: Int {
        calculateOverall(for: position)
    }

    public init(id: UUID = UUID(),
         firstName: String,
         lastName: String,
         position: Position,
         age: Int,
         height: Int,
         weight: Int,
         college: String,
         experience: Int,
         ratings: PlayerRatings,
         contract: Contract) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.position = position
        self.age = age
        self.height = height
        self.weight = weight
        self.college = college
        self.experience = experience
        self.ratings = ratings
        self.seasonStats = SeasonStats()
        self.careerStats = SeasonStats()
        self.contract = contract
        self.status = .healthy
    }

    private func calculateOverall(for position: Position) -> Int {
        let r = ratings
        let weights: [(Int, Double)]

        switch position {
        case .quarterback:
            weights = [
                (r.throwPower, 0.15),
                (r.throwAccuracyShort, 0.15),
                (r.throwAccuracyMid, 0.15),
                (r.throwAccuracyDeep, 0.10),
                (r.awareness, 0.15),
                (r.playAction, 0.10),
                (r.agility, 0.10),
                (r.speed, 0.10)
            ]
        case .runningBack:
            weights = [
                (r.speed, 0.20),
                (r.agility, 0.15),
                (r.carrying, 0.15),
                (r.breakTackle, 0.15),
                (r.elusiveness, 0.15),
                (r.ballCarrierVision, 0.10),
                (r.catching, 0.10)
            ]
        case .wideReceiver:
            weights = [
                (r.speed, 0.20),
                (r.catching, 0.20),
                (r.routeRunning, 0.20),
                (r.release, 0.10),
                (r.catchInTraffic, 0.15),
                (r.agility, 0.15)
            ]
        case .tightEnd:
            weights = [
                (r.catching, 0.20),
                (r.runBlock, 0.20),
                (r.strength, 0.15),
                (r.routeRunning, 0.15),
                (r.speed, 0.15),
                (r.catchInTraffic, 0.15)
            ]
        case .leftTackle, .rightTackle:
            weights = [
                (r.passBlock, 0.30),
                (r.runBlock, 0.25),
                (r.strength, 0.20),
                (r.awareness, 0.15),
                (r.agility, 0.10)
            ]
        case .leftGuard, .rightGuard, .center:
            weights = [
                (r.runBlock, 0.30),
                (r.passBlock, 0.25),
                (r.strength, 0.25),
                (r.awareness, 0.10),
                (r.impactBlock, 0.10)
            ]
        case .defensiveEnd:
            weights = [
                (r.passRush, 0.25),
                (r.blockShedding, 0.20),
                (r.speed, 0.15),
                (r.strength, 0.15),
                (r.tackle, 0.15),
                (r.pursuit, 0.10)
            ]
        case .defensiveTackle:
            weights = [
                (r.blockShedding, 0.25),
                (r.strength, 0.25),
                (r.tackle, 0.20),
                (r.passRush, 0.15),
                (r.pursuit, 0.15)
            ]
        case .outsideLinebacker:
            weights = [
                (r.tackle, 0.20),
                (r.pursuit, 0.15),
                (r.passRush, 0.15),
                (r.zoneCoverage, 0.15),
                (r.speed, 0.15),
                (r.playRecognition, 0.20)
            ]
        case .middleLinebacker:
            weights = [
                (r.tackle, 0.25),
                (r.playRecognition, 0.20),
                (r.pursuit, 0.15),
                (r.zoneCoverage, 0.15),
                (r.strength, 0.15),
                (r.awareness, 0.10)
            ]
        case .cornerback:
            weights = [
                (r.manCoverage, 0.25),
                (r.speed, 0.20),
                (r.zoneCoverage, 0.15),
                (r.press, 0.15),
                (r.agility, 0.15),
                (r.playRecognition, 0.10)
            ]
        case .freeSafety:
            weights = [
                (r.zoneCoverage, 0.25),
                (r.speed, 0.20),
                (r.playRecognition, 0.20),
                (r.tackle, 0.15),
                (r.pursuit, 0.10),
                (r.catching, 0.10)
            ]
        case .strongSafety:
            weights = [
                (r.tackle, 0.20),
                (r.hitPower, 0.15),
                (r.zoneCoverage, 0.20),
                (r.speed, 0.15),
                (r.strength, 0.15),
                (r.playRecognition, 0.15)
            ]
        case .kicker:
            weights = [
                (r.kickPower, 0.50),
                (r.kickAccuracy, 0.50)
            ]
        case .punter:
            weights = [
                (r.kickPower, 0.50),
                (r.kickAccuracy, 0.50)
            ]
        case .fullback:
            weights = [
                (r.runBlock, 0.30),
                (r.strength, 0.20),
                (r.carrying, 0.15),
                (r.catching, 0.15),
                (r.impactBlock, 0.20)
            ]
        }

        let weighted = weights.reduce(0.0) { $0 + Double($1.0) * $1.1 }
        return Int(weighted)
    }

    public mutating func addGameStats(_ gameStats: GameStats) {
        seasonStats.gamesPlayed += 1
        seasonStats.passAttempts += gameStats.passAttempts
        seasonStats.passCompletions += gameStats.passCompletions
        seasonStats.passingYards += gameStats.passingYards
        seasonStats.passingTouchdowns += gameStats.passingTouchdowns
        seasonStats.interceptions += gameStats.interceptions

        seasonStats.rushAttempts += gameStats.rushAttempts
        seasonStats.rushingYards += gameStats.rushingYards
        seasonStats.rushingTouchdowns += gameStats.rushingTouchdowns

        seasonStats.targets += gameStats.targets
        seasonStats.receptions += gameStats.receptions
        seasonStats.receivingYards += gameStats.receivingYards
        seasonStats.receivingTouchdowns += gameStats.receivingTouchdowns

        seasonStats.totalTackles += gameStats.totalTackles
        seasonStats.defSacks += gameStats.defSacks
        seasonStats.interceptionsDef += gameStats.interceptionsDef
        seasonStats.passesDefended += gameStats.passesDefended
    }

    /// Archives current season stats to career stats and resets season stats
    public mutating func archiveSeasonStats() {
        // Add season stats to career totals
        careerStats.gamesPlayed += seasonStats.gamesPlayed
        careerStats.passAttempts += seasonStats.passAttempts
        careerStats.passCompletions += seasonStats.passCompletions
        careerStats.passingYards += seasonStats.passingYards
        careerStats.passingTouchdowns += seasonStats.passingTouchdowns
        careerStats.interceptions += seasonStats.interceptions
        careerStats.sacks += seasonStats.sacks

        careerStats.rushAttempts += seasonStats.rushAttempts
        careerStats.rushingYards += seasonStats.rushingYards
        careerStats.rushingTouchdowns += seasonStats.rushingTouchdowns
        careerStats.fumbles += seasonStats.fumbles
        careerStats.fumblesLost += seasonStats.fumblesLost

        careerStats.targets += seasonStats.targets
        careerStats.receptions += seasonStats.receptions
        careerStats.receivingYards += seasonStats.receivingYards
        careerStats.receivingTouchdowns += seasonStats.receivingTouchdowns
        careerStats.drops += seasonStats.drops

        careerStats.totalTackles += seasonStats.totalTackles
        careerStats.soloTackles += seasonStats.soloTackles
        careerStats.assistedTackles += seasonStats.assistedTackles
        careerStats.tacklesForLoss += seasonStats.tacklesForLoss
        careerStats.defSacks += seasonStats.defSacks
        careerStats.interceptionsDef += seasonStats.interceptionsDef
        careerStats.passesDefended += seasonStats.passesDefended
        careerStats.forcedFumbles += seasonStats.forcedFumbles
        careerStats.fumblesRecovered += seasonStats.fumblesRecovered
        careerStats.defensiveTouchdowns += seasonStats.defensiveTouchdowns

        careerStats.fieldGoalsMade += seasonStats.fieldGoalsMade
        careerStats.fieldGoalsAttempted += seasonStats.fieldGoalsAttempted
        careerStats.extraPointsMade += seasonStats.extraPointsMade
        careerStats.extraPointsAttempted += seasonStats.extraPointsAttempted
        careerStats.punts += seasonStats.punts
        careerStats.puntYards += seasonStats.puntYards

        // Reset season stats for new season
        seasonStats = SeasonStats()
    }

    /// Advances player to next season (age, experience, contract)
    public mutating func advanceToNextSeason() {
        age += 1
        experience += 1

        // Decrement contract years
        if contract.yearsRemaining > 0 {
            contract.yearsRemaining -= 1
            if !contract.yearlyValues.isEmpty {
                contract.yearlyValues.removeFirst()
            }
        }

        // Reset status for new season
        status = .healthy
    }

    /// Whether player's contract has expired
    public var isContractExpired: Bool {
        contract.yearsRemaining <= 0
    }
}

// MARK: - Player Generation

public struct PlayerGenerator { // Public
    public static let firstNames = [
        "James", "Marcus", "DeShawn", "Tyler", "Brandon", "Chris", "Mike", "David",
        "Antonio", "Derek", "Justin", "Kevin", "Ryan", "Josh", "Matt", "Drew",
        "Dak", "Lamar", "Patrick", "Jalen", "Tua", "Joe", "Trevor", "Mac",
        "Aaron", "Tom", "Russell", "Kyler", "Daniel", "Baker", "Sam", "Zach",
        "Derrick", "Dalvin", "Alvin", "Nick", "Ezekiel", "Saquon", "Jonathan", "Austin",
        "Davante", "Tyreek", "Stefon", "Cooper", "CeeDee", "Ja'Marr", "Justin", "Amon-Ra",
        "Travis", "Mark", "George", "Darren", "Kyle", "Zach", "Dallas", "David"
    ]

    public static let lastNames = [
        "Johnson", "Williams", "Brown", "Jones", "Davis", "Wilson", "Anderson", "Thomas",
        "Jackson", "White", "Harris", "Martin", "Thompson", "Garcia", "Robinson", "Clark",
        "Rodriguez", "Lewis", "Lee", "Walker", "Hall", "Allen", "Young", "King",
        "Wright", "Scott", "Green", "Baker", "Adams", "Nelson", "Hill", "Campbell",
        "Mitchell", "Roberts", "Carter", "Phillips", "Evans", "Turner", "Torres", "Parker",
        "Collins", "Edwards", "Stewart", "Morris", "Murphy", "Rivera", "Cook", "Rogers",
        "Morgan", "Peterson", "Cooper", "Reed", "Bailey", "Bell", "Gomez", "Kelly"
    ]

    public static let colleges = [
        "Alabama", "Ohio State", "Georgia", "Clemson", "LSU", "Michigan", "Oklahoma",
        "Notre Dame", "Texas", "Penn State", "Florida", "Oregon", "USC", "Auburn",
        "Texas A&M", "Wisconsin", "Miami", "Florida State", "Tennessee", "Iowa"
    ]

    public static func generate(position: Position, tier: PlayerTier) -> Player {
        let firstName = firstNames.randomElement()!
        let lastName = lastNames.randomElement()!
        let college = colleges.randomElement()!
        let age = tier == .elite ? Int.random(in: 25...32) : Int.random(in: 22...30)
        let experience = max(0, age - 22)

        let (height, weight) = physicals(for: position)

        return Player(
            firstName: firstName,
            lastName: lastName,
            position: position,
            age: age,
            height: height,
            weight: weight,
            college: college,
            experience: experience,
            ratings: PlayerRatings.random(tier: tier),
            contract: Contract.veteran(rating: tier == .elite ? 90 : (tier == .starter ? 80 : 70), position: position)
        )
    }

    private static func physicals(for position: Position) -> (height: Int, weight: Int) {
        switch position {
        case .quarterback: return (Int.random(in: 73...77), Int.random(in: 210...240))
        case .runningBack: return (Int.random(in: 68...72), Int.random(in: 195...225))
        case .fullback: return (Int.random(in: 70...74), Int.random(in: 240...260))
        case .wideReceiver: return (Int.random(in: 69...76), Int.random(in: 175...215))
        case .tightEnd: return (Int.random(in: 75...79), Int.random(in: 245...265))
        case .leftTackle, .rightTackle: return (Int.random(in: 76...80), Int.random(in: 305...335))
        case .leftGuard, .rightGuard: return (Int.random(in: 74...78), Int.random(in: 305...330))
        case .center: return (Int.random(in: 73...77), Int.random(in: 295...320))
        case .defensiveEnd: return (Int.random(in: 74...78), Int.random(in: 255...285))
        case .defensiveTackle: return (Int.random(in: 73...77), Int.random(in: 295...330))
        case .outsideLinebacker: return (Int.random(in: 73...77), Int.random(in: 235...260))
        case .middleLinebacker: return (Int.random(in: 72...76), Int.random(in: 240...255))
        case .cornerback: return (Int.random(in: 69...74), Int.random(in: 185...205))
        case .freeSafety: return (Int.random(in: 70...74), Int.random(in: 195...215))
        case .strongSafety: return (Int.random(in: 71...75), Int.random(in: 205...220))
        case .kicker: return (Int.random(in: 70...74), Int.random(in: 185...210))
        case .punter: return (Int.random(in: 72...76), Int.random(in: 200...225))
        }
    }
}