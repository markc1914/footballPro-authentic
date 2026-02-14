//
//  Game.swift
//  footballPro
//
//  Game state, score, and play history
//

import Foundation

// MARK: - Game Clock

public struct GameClock: Codable, Equatable {
    public var quarter: Int // 1-4, 5+ for overtime
    public var timeRemaining: Int // Seconds remaining in quarter
    public var isRunning: Bool
    public var quarterLengthSeconds: Int // Configurable quarter length

    public static let defaultQuarterLength = 900 // 15 minutes in seconds

    public var displayTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public var quarterDisplay: String {
        switch quarter {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        default: return "OT\(quarter - 4)"
        }
    }

    public var isHalftime: Bool {
        quarter == 2 && timeRemaining == 0
    }

    public var isEndOfRegulation: Bool {
        quarter == 4 && timeRemaining == 0
    }

    public var isGameOver: Bool {
        quarter > 4 && timeRemaining == 0
    }

    public static func kickoff(quarterMinutes: Int = 15) -> GameClock {
        let seconds = quarterMinutes * 60
        return GameClock(quarter: 1, timeRemaining: seconds, isRunning: false, quarterLengthSeconds: seconds)
    }

    public mutating func tick(seconds: Int) {
        guard isRunning else { return }
        timeRemaining = max(0, timeRemaining - seconds)
    }

    public mutating func nextQuarter() {
        quarter += 1
        timeRemaining = quarterLengthSeconds
        isRunning = false
    }
}

// MARK: - Field Position

public struct FieldPosition: Codable, Equatable {
    public var yardLine: Int // 0-100, where 0 is own goal line
    public var possessingTeamEndZone: Int { 100 } // Always scoring towards 100

    public var displayYardLine: String {
        if yardLine == 50 {
            return "50"
        } else if yardLine > 50 {
            return "OPP \(100 - yardLine)"
        } else {
            return "OWN \(yardLine)"
        }
    }

    public var yardsToEndZone: Int {
        100 - yardLine
    }

    public var isRedZone: Bool {
        yardsToEndZone <= 20
    }

    public var isGoalToGo: Bool {
        yardsToEndZone <= 10
    }

    public mutating func advance(yards: Int) {
        yardLine = min(100, max(0, yardLine + yards))
    }

    public mutating func flip() {
        yardLine = 100 - yardLine
    }
}

// MARK: - Down and Distance

public struct DownAndDistance: Codable, Equatable {
    public var down: Int // 1-4
    public var yardsToGo: Int
    public var lineOfScrimmage: Int

    public var displayDown: String {
        let suffix: String
        switch down {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
        return "\(down)\(suffix)"
    }

    public var displayDownAndDistance: String {
        let goalToGo = lineOfScrimmage + yardsToGo >= 100
        if goalToGo {
            return "\(displayDown) & Goal"
        }
        return "\(displayDown) & \(yardsToGo)"
    }

    public static func firstDown(at yardLine: Int) -> DownAndDistance {
        let yardsToEndZone = 100 - yardLine
        return DownAndDistance(
            down: 1,
            yardsToGo: min(10, yardsToEndZone),
            lineOfScrimmage: yardLine
        )
    }

    public mutating func afterPlay(yardsGained: Int) -> Bool {
        lineOfScrimmage += yardsGained

        if yardsGained >= yardsToGo {
            // First down
            let yardsToEndZone = 100 - lineOfScrimmage
            down = 1
            yardsToGo = min(10, yardsToEndZone)
            return true
        } else {
            // Next down
            down += 1
            yardsToGo -= yardsGained
            return false
        }
    }

    public var isFourthDown: Bool {
        down == 4
    }

    public var isTurnoverOnDowns: Bool {
        down > 4
    }
}

// MARK: - Score

public struct GameScore: Codable, Equatable {
    public var homeScore: Int = 0
    public var awayScore: Int = 0

    public var homeQuarterScores: [Int] = [0, 0, 0, 0]
    public var awayQuarterScores: [Int] = [0, 0, 0, 0]

    public mutating func addScore(points: Int, isHome: Bool, quarter: Int) {
        if isHome {
            homeScore += points
            if quarter <= 4 {
                homeQuarterScores[quarter - 1] += points
            }
        } else {
            awayScore += points
            if quarter <= 4 {
                awayQuarterScores[quarter - 1] += points
            }
        }
    }

    public var isTied: Bool {
        homeScore == awayScore
    }

    public func leader() -> Bool? { // true = home, false = away, nil = tied
        if homeScore > awayScore { return true }
        if awayScore > homeScore { return false }
        return nil
    }
}

// MARK: - Play Result

public struct PlayResult: Identifiable, Codable, Equatable {
    public let id: UUID
    public var playType: PlayType
    public var description: String
    public var yardsGained: Int
    public var timeElapsed: Int
    public var quarter: Int
    public var timeRemaining: Int
    public var isFirstDown: Bool
    public var isTouchdown: Bool
    public var isTurnover: Bool
    public var scoringPlay: ScoringPlay?

    public init(playType: PlayType,
         description: String,
         yardsGained: Int,
         timeElapsed: Int,
         quarter: Int,
         timeRemaining: Int,
         isFirstDown: Bool = false,
         isTouchdown: Bool = false,
         isTurnover: Bool = false,
         scoringPlay: ScoringPlay? = nil) {
        self.id = UUID()
        self.playType = playType
        self.description = description
        self.yardsGained = yardsGained
        self.timeElapsed = timeElapsed
        self.quarter = quarter
        self.timeRemaining = timeRemaining
        self.isFirstDown = isFirstDown
        self.isTouchdown = isTouchdown
        self.isTurnover = isTurnover
        self.scoringPlay = scoringPlay
    }
}

public enum ScoringPlay: String, Codable {
    case touchdown = "TD"
    case fieldGoal = "FG"
    case extraPoint = "XP"
    case twoPointConversion = "2PT"
    case safety = "SAF"
}

// MARK: - Drive

public struct Drive: Identifiable, Codable, Equatable {
    public let id: UUID
    public var teamId: UUID
    public var startingFieldPosition: Int
    public var startingQuarter: Int
    public var startingTime: Int

    public var plays: [PlayResult]
    public var result: DriveResult?

    public var totalYards: Int {
        plays.reduce(0) { $0 + $1.yardsGained }
    }

    public var numberOfPlays: Int {
        plays.count
    }

    public var timeOfPossession: Int {
        plays.reduce(0) { $0 + $1.timeElapsed }
    }

    public var timeOfPossessionDisplay: String {
        let minutes = timeOfPossession / 60
        let seconds = timeOfPossession % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public init(teamId: UUID, startingFieldPosition: Int, quarter: Int, time: Int) {
        self.id = UUID()
        self.teamId = teamId
        self.startingFieldPosition = startingFieldPosition
        self.startingQuarter = quarter
        self.startingTime = time
        self.plays = []
        self.result = nil
    }
}

public enum DriveResult: String, Codable {
    case touchdown
    case fieldGoal
    case punt
    case turnoverOnDowns
    case interception
    case fumble
    case safety
    case endOfHalf
    case endOfGame
}

// MARK: - Game

public struct Game: Identifiable, Codable, Equatable {
    public let id: UUID
    public var homeTeamId: UUID
    public var awayTeamId: UUID
    public var week: Int
    public var seasonYear: Int

    public var clock: GameClock
    public var score: GameScore
    public var fieldPosition: FieldPosition
    public var downAndDistance: DownAndDistance

    public var possessingTeamId: UUID
    public var isKickoff: Bool
    public var isExtraPoint: Bool
    public var awaitingUserInput: Bool

    // Timeout tracking (3 per half per team)
    public var homeTimeouts: Int
    public var awayTimeouts: Int

    // Overtime tracking
    public var overtimePossessions: Int

    public var drives: [Drive]
    public var currentDrive: Drive?

    public var gameStatus: GameStatus
    public var weather: Weather

    // Stats tracking
    public var homeTeamStats: TeamGameStats
    public var awayTeamStats: TeamGameStats

    public init(homeTeamId: UUID, awayTeamId: UUID, week: Int, seasonYear: Int, quarterMinutes: Int = 15, weather: Weather? = nil) {
        self.id = UUID()
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.week = week
        self.seasonYear = seasonYear

        self.clock = .kickoff(quarterMinutes: quarterMinutes)
        self.score = GameScore()
        self.fieldPosition = FieldPosition(yardLine: 35) // Kickoff from 35
        self.downAndDistance = .firstDown(at: 25)

        // Away team receives first (coin toss)
        self.possessingTeamId = awayTeamId
        self.isKickoff = true
        self.isExtraPoint = false
        self.awaitingUserInput = false

        self.homeTimeouts = 3
        self.awayTimeouts = 3
        self.overtimePossessions = 0

        self.drives = []
        self.currentDrive = nil

        self.gameStatus = .pregame
        self.weather = weather ?? Weather.random()

        self.homeTeamStats = TeamGameStats()
        self.awayTeamStats = TeamGameStats()
    }

    public var isHomeTeamPossession: Bool {
        possessingTeamId == homeTeamId
    }

    public var isOver: Bool {
        gameStatus == .final
    }

    public mutating func switchPossession() {
        possessingTeamId = possessingTeamId == homeTeamId ? awayTeamId : homeTeamId
        fieldPosition.flip()
    }

    public mutating func startDrive() {
        currentDrive = Drive(
            teamId: possessingTeamId,
            startingFieldPosition: fieldPosition.yardLine,
            quarter: clock.quarter,
            time: clock.timeRemaining
        )
    }

    public mutating func endDrive(result: DriveResult) {
        currentDrive?.result = result
        if let drive = currentDrive {
            drives.append(drive)
        }
        currentDrive = nil
    }

    public func teamStats(for teamId: UUID) -> TeamGameStats {
        teamId == homeTeamId ? homeTeamStats : awayTeamStats
    }
}

public enum GameStatus: String, Codable {
    case pregame
    case inProgress
    case halftime
    case final
}

// MARK: - Weather

public struct Weather: Codable, Equatable {
    public var condition: WeatherCondition
    public var temperature: Int // Fahrenheit
    public var windSpeed: Int // MPH

    public var description: String {
        "\(temperature)°F, \(condition.rawValue), Wind: \(windSpeed) mph"
    }

    public var affectsKicking: Bool {
        windSpeed > 15 || condition == .snow || condition == .rain
    }

    public var affectsPassing: Bool {
        windSpeed > 20 || condition == .snow || condition == .heavyRain
    }

    public static func random() -> Weather {
        Weather(
            condition: WeatherCondition.allCases.randomElement()!,
            temperature: Int.random(in: 30...90),
            windSpeed: Int.random(in: 0...25)
        )
    }

    public static var dome: Weather {
        Weather(condition: .dome, temperature: 72, windSpeed: 0)
    }

    /// Generate weather based on CITIES.DAT weather zone.
    /// Zones from the original game map to climate regions:
    ///   0 = dome/indoor, 1 = warm/southern, 2 = temperate, 3 = cold/northern,
    ///   4 = extreme cold, 5+ = variable/coastal
    public static func forZone(_ zone: Int) -> Weather {
        switch zone {
        case 0:
            // Dome — always perfect
            return .dome
        case 1:
            // Warm climate (Miami, Tampa, Phoenix, New Orleans)
            let conditions: [WeatherCondition] = [.clear, .clear, .clear, .cloudy, .rain]
            return Weather(
                condition: conditions.randomElement()!,
                temperature: Int.random(in: 70...95),
                windSpeed: Int.random(in: 0...12)
            )
        case 2:
            // Temperate (Dallas, San Francisco, Washington)
            let conditions: [WeatherCondition] = [.clear, .clear, .cloudy, .cloudy, .rain]
            return Weather(
                condition: conditions.randomElement()!,
                temperature: Int.random(in: 45...80),
                windSpeed: Int.random(in: 0...18)
            )
        case 3:
            // Cold (Chicago, Pittsburgh, New York, Denver)
            let conditions: [WeatherCondition] = [.clear, .cloudy, .cloudy, .rain, .snow]
            return Weather(
                condition: conditions.randomElement()!,
                temperature: Int.random(in: 25...55),
                windSpeed: Int.random(in: 5...25)
            )
        case 4:
            // Extreme cold (Green Bay, Buffalo, Minnesota outdoor)
            let conditions: [WeatherCondition] = [.clear, .cloudy, .snow, .snow, .heavyRain]
            return Weather(
                condition: conditions.randomElement()!,
                temperature: Int.random(in: 10...40),
                windSpeed: Int.random(in: 8...30)
            )
        default:
            // Coastal/variable (Seattle, San Diego)
            let conditions: [WeatherCondition] = [.cloudy, .cloudy, .clear, .rain, .rain]
            return Weather(
                condition: conditions.randomElement()!,
                temperature: Int.random(in: 40...70),
                windSpeed: Int.random(in: 3...20)
            )
        }
    }
}

public enum WeatherCondition: String, Codable, CaseIterable {
    case clear = "Clear"
    case cloudy = "Cloudy"
    case rain = "Rain"
    case heavyRain = "Heavy Rain"
    case snow = "Snow"
    case dome = "Dome"
}

// MARK: - Team Game Stats

public struct TeamGameStats: Codable, Equatable {
    public var totalYards: Int = 0
    public var passingYards: Int = 0
    public var rushingYards: Int = 0
    public var firstDowns: Int = 0
    public var thirdDownAttempts: Int = 0
    public var thirdDownConversions: Int = 0
    public var fourthDownAttempts: Int = 0
    public var fourthDownConversions: Int = 0
    public var turnovers: Int = 0
    public var penalties: Int = 0
    public var penaltyYards: Int = 0
    public var timeOfPossession: Int = 0 // Seconds

    public var thirdDownPercentage: Double {
        guard thirdDownAttempts > 0 else { return 0 }
        return Double(thirdDownConversions) / Double(thirdDownAttempts) * 100
    }

    public var timeOfPossessionDisplay: String {
        let minutes = timeOfPossession / 60
        let seconds = timeOfPossession % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}