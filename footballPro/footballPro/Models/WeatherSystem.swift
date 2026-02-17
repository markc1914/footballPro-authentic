//
//  WeatherSystem.swift
//  footballPro
//
//  Weather system with gameplay effects based on FPS Football Pro '93 original manual.
//  Temperature, wind, humidity, rain/snow affect passing, rushing, kicking, and injuries.
//  Field conditions (grass, turf, mud, snow) affect player speed and injury rates.
//

import Foundation

// MARK: - Game Weather

/// Full weather state for a game, generated from city weather zones and month
public struct GameWeather: Codable, Equatable {
    public var temperature: Int          // Fahrenheit (-10 to 110)
    public var windSpeed: Int            // MPH (0-40)
    public var windDirection: Int        // Degrees (0-359, 0=North)
    public var humidity: Int             // Percentage (0-100)
    public var condition: WeatherConditionFull
    public var fieldCondition: FieldCondition

    /// Human-readable description for pre-game narration
    public var narrativeDescription: String {
        let tempDesc: String
        if temperature >= 90 { tempDesc = "a scorching \(temperature)" }
        else if temperature >= 75 { tempDesc = "a warm \(temperature)" }
        else if temperature >= 55 { tempDesc = "a pleasant \(temperature)" }
        else if temperature >= 40 { tempDesc = "a chilly \(temperature)" }
        else if temperature >= 25 { tempDesc = "a frigid \(temperature)" }
        else { tempDesc = "a bone-chilling \(temperature)" }

        var parts: [String] = ["\(tempDesc) degrees"]

        if condition != .clear {
            parts.append(condition.rawValue.lowercased())
        }

        if windSpeed > 10 {
            parts.append("winds \(windSpeed) mph from the \(windDirectionName)")
        }

        if fieldCondition != .grass && fieldCondition != .artificialTurf {
            parts.append("\(fieldCondition.rawValue.lowercased()) field")
        } else if fieldCondition == .artificialTurf {
            parts.append("artificial turf")
        }

        return parts.joined(separator: ", ")
    }

    /// Short scoreboard-style description: "28F Snow W15 NW"
    public var shortDescription: String {
        "\(temperature)F \(condition.shortName) W\(windSpeed) \(windDirectionName)"
    }

    /// Wind direction as compass name (N, NE, E, SE, S, SW, W, NW)
    public var windDirectionName: String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = ((windDirection + 22) % 360) / 45
        return directions[min(index, 7)]
    }

    // MARK: - Gameplay Modifiers

    /// Completion percentage modifier (multiplied against base completion chance)
    /// Rain: -10%, Snow: -15%
    public var completionModifier: Double {
        switch condition {
        case .rain: return 0.90
        case .snow: return 0.85
        default: return 1.0
        }
    }

    /// Fumble chance multiplier. Rain: +25%, Snow: +35%
    public var fumbleModifier: Double {
        switch condition {
        case .rain: return 1.25
        case .snow: return 1.35
        default: return 1.0
        }
    }

    /// Kick distance multiplier from weather conditions (rain, snow, cold)
    public var kickDistanceModifier: Double {
        var modifier = 1.0

        // Temperature effects
        if temperature > 85 {
            modifier += 0.05  // Hot: ball flies farther
        } else if temperature < 32 {
            modifier -= 0.10  // Cold: ball doesn't travel as far
        }

        // Precipitation effects
        switch condition {
        case .rain: modifier -= 0.05
        case .snow: modifier -= 0.10
        default: break
        }

        return modifier
    }

    /// Wind modifier on kick distance based on kick direction relative to wind.
    /// `kickDirection` in degrees (0=North, same convention as windDirection).
    /// Headwind reduces distance, tailwind increases.
    public func kickWindModifier(kickDirection: Int) -> Double {
        guard windSpeed > 0 else { return 1.0 }
        // Angle between wind direction and kick direction
        let angleDiff = Double(abs(windDirection - kickDirection)) * .pi / 180.0
        let cosAngle = cos(angleDiff)
        // Tailwind (cos > 0) adds distance, headwind (cos < 0) reduces
        return 1.0 + Double(windSpeed) * cosAngle / 100.0
    }

    /// Speed modifier for runners. Snow: -5%, Mud field: -10%, Artificial turf: +5%
    public var speedModifier: Double {
        var modifier = 1.0

        // Weather condition
        if condition == .snow { modifier -= 0.05 }

        // Field condition
        switch fieldCondition {
        case .mud: modifier -= 0.10
        case .snow: modifier -= 0.05
        case .artificialTurf: modifier += 0.05
        case .grass: break
        }

        return modifier
    }

    /// Injury chance multiplier. Cold: +25%, Mud: +20%, Artificial turf: +15% (on tackles)
    public var injuryModifier: Double {
        var modifier = 1.0

        if temperature < 32 { modifier += 0.25 }

        switch fieldCondition {
        case .mud: modifier += 0.20
        case .artificialTurf: modifier += 0.15
        default: break
        }

        // High humidity in heat compounds fatigue/injury risk
        if temperature > 85 && humidity > 80 {
            modifier += 0.15
        }

        return modifier
    }

    /// Whether kicking is affected (legacy compatibility with existing Weather.affectsKicking)
    public var affectsKicking: Bool {
        windSpeed > 15 || condition == .snow || condition == .rain
    }

    /// Whether passing is affected (legacy compatibility with existing Weather.affectsPassing)
    public var affectsPassing: Bool {
        windSpeed > 20 || condition == .snow || condition == .rain
    }

    // MARK: - Generation

    /// Generate weather for a city + month using weather zone from CITIES.DAT
    public static func generate(for city: String, weatherZone: Int, month: Int) -> GameWeather {
        let isDome = weatherZone == 0

        if isDome {
            return GameWeather(
                temperature: 72,
                windSpeed: 0,
                windDirection: 0,
                humidity: 40,
                condition: .clear,
                fieldCondition: .artificialTurf
            )
        }

        // Season-based temperature ranges by zone
        let baseTemp: ClosedRange<Int>
        let isCold = (month >= 11 || month <= 2)  // Nov-Feb
        let isMild = (month >= 9 && month <= 10) || (month >= 3 && month <= 4) // Sep-Oct, Mar-Apr

        switch weatherZone {
        case 1: // Warm (Miami, Tampa, Phoenix)
            baseTemp = isCold ? 55...75 : (isMild ? 70...90 : 80...105)
        case 2: // Temperate (Dallas, SF, Washington)
            baseTemp = isCold ? 30...50 : (isMild ? 50...75 : 70...95)
        case 3: // Cold (Chicago, Pittsburgh, NY, Denver)
            baseTemp = isCold ? 10...35 : (isMild ? 40...60 : 65...85)
        case 4: // Extreme cold (Green Bay, Buffalo)
            baseTemp = isCold ? -10...25 : (isMild ? 30...50 : 55...80)
        default: // Coastal/variable (Seattle, San Diego)
            baseTemp = isCold ? 35...55 : (isMild ? 50...65 : 60...80)
        }

        let temperature = Int.random(in: baseTemp)
        let windSpeed = Int.random(in: 0...windMax(for: weatherZone, month: month))
        let windDirection = Int.random(in: 0...359)
        let humidity = Int.random(in: humidityRange(for: weatherZone))

        // Condition based on temperature + zone
        let condition = randomCondition(zone: weatherZone, temperature: temperature, month: month)

        // Field condition derived from weather
        let fieldCondition: FieldCondition
        if condition == .snow && temperature < 32 {
            fieldCondition = .snow
        } else if condition == .rain && temperature < 45 {
            fieldCondition = .mud
        } else if condition == .rain && Double.random(in: 0...1) < 0.3 {
            fieldCondition = .mud
        } else if weatherZone == 0 {
            fieldCondition = .artificialTurf
        } else {
            // Some stadiums had turf in '93
            fieldCondition = Double.random(in: 0...1) < 0.25 ? .artificialTurf : .grass
        }

        return GameWeather(
            temperature: temperature,
            windSpeed: windSpeed,
            windDirection: windDirection,
            humidity: humidity,
            condition: condition,
            fieldCondition: fieldCondition
        )
    }

    /// Generate fully random weather (for exhibition/test games)
    public static func randomWeather() -> GameWeather {
        let zone = Int.random(in: 1...5)
        let month = Int.random(in: 9...12) // Football season months
        return generate(for: "", weatherZone: zone, month: month)
    }

    // MARK: - Conversion from legacy Weather

    /// Create a GameWeather from the existing simple Weather struct
    public static func fromLegacy(_ weather: Weather) -> GameWeather {
        let condition: WeatherConditionFull
        switch weather.condition {
        case .clear: condition = .clear
        case .cloudy: condition = .cloudy
        case .rain: condition = .rain
        case .heavyRain: condition = .rain
        case .snow: condition = .snow
        case .dome: condition = .clear
        }

        let fieldCondition: FieldCondition
        if weather.condition == .dome {
            fieldCondition = .artificialTurf
        } else if weather.condition == .snow {
            fieldCondition = .snow
        } else if weather.condition == .rain || weather.condition == .heavyRain {
            fieldCondition = Double.random(in: 0...1) < 0.4 ? .mud : .grass
        } else {
            fieldCondition = .grass
        }

        return GameWeather(
            temperature: weather.temperature,
            windSpeed: weather.windSpeed,
            windDirection: Int.random(in: 0...359),
            humidity: Int.random(in: 30...80),
            condition: condition,
            fieldCondition: fieldCondition
        )
    }

    // MARK: - Private Helpers

    private static func windMax(for zone: Int, month: Int) -> Int {
        let isCold = (month >= 11 || month <= 2)
        switch zone {
        case 1: return isCold ? 15 : 10
        case 2: return isCold ? 20 : 15
        case 3: return isCold ? 30 : 20
        case 4: return isCold ? 40 : 25
        default: return isCold ? 25 : 18
        }
    }

    private static func humidityRange(for zone: Int) -> ClosedRange<Int> {
        switch zone {
        case 1: return 60...95  // Warm/humid
        case 2: return 30...70  // Temperate
        case 3: return 20...60  // Cold/dry
        case 4: return 15...55  // Extreme cold/dry
        default: return 50...85 // Coastal/humid
        }
    }

    private static func randomCondition(zone: Int, temperature: Int, month: Int) -> WeatherConditionFull {
        let isCold = (month >= 11 || month <= 2)
        let roll = Double.random(in: 0...1)

        switch zone {
        case 1: // Warm
            if roll < 0.50 { return .clear }
            if roll < 0.70 { return .partlyCloudy }
            if roll < 0.85 { return .cloudy }
            return .rain
        case 2: // Temperate
            if roll < 0.35 { return .clear }
            if roll < 0.55 { return .partlyCloudy }
            if roll < 0.75 { return .cloudy }
            if isCold && temperature < 35 && roll < 0.90 { return .snow }
            return .rain
        case 3: // Cold
            if roll < 0.25 { return .clear }
            if roll < 0.45 { return .partlyCloudy }
            if roll < 0.65 { return .cloudy }
            if isCold && temperature < 35 { return .snow }
            return .rain
        case 4: // Extreme cold
            if roll < 0.20 { return .clear }
            if roll < 0.35 { return .partlyCloudy }
            if roll < 0.55 { return .cloudy }
            if isCold && temperature < 35 {
                return roll < 0.80 ? .snow : .rain
            }
            return .rain
        default: // Coastal
            if roll < 0.25 { return .clear }
            if roll < 0.45 { return .partlyCloudy }
            if roll < 0.65 { return .cloudy }
            return .rain
        }
    }
}

// MARK: - Weather Condition (Full)

/// Extended weather condition enum with partly cloudy (matches original game manual)
public enum WeatherConditionFull: String, Codable, CaseIterable {
    case clear = "Clear"
    case partlyCloudy = "Partly Cloudy"
    case cloudy = "Cloudy"
    case rain = "Rain"
    case snow = "Snow"

    /// Short display name for scoreboard
    public var shortName: String {
        switch self {
        case .clear: return "CLR"
        case .partlyCloudy: return "PCL"
        case .cloudy: return "CLD"
        case .rain: return "RN"
        case .snow: return "SNW"
        }
    }
}

// MARK: - Field Condition

/// Playing surface type affecting speed and injury rates
public enum FieldCondition: String, Codable, CaseIterable {
    case grass = "Grass"
    case artificialTurf = "Artificial Turf"
    case mud = "Mud"
    case snow = "Snow"

    /// Short display name for scoreboard
    public var shortName: String {
        switch self {
        case .grass: return "GRS"
        case .artificialTurf: return "TRF"
        case .mud: return "MUD"
        case .snow: return "SNW"
        }
    }
}
