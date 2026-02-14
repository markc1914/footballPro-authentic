//
//  CitiesDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 CITIES.DAT.
//  Format: Magic "CTL:F" header, sections CTR:, CHI:, CWC:, then CTY: records.
//  Each CTY: record has a city name (null-padded to 16B) + weather/coordinate data.
//

import Foundation

struct GameCity: Equatable {
    let index: Int
    let name: String
    let weatherZone: Int
    let weatherData: Data  // Raw weather bytes for future decoding
}

struct CitiesDecoder {
    static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")

    private static let cityMarker = Data("CTY:".utf8)
    private static let headerMarker = Data("CTL:".utf8)

    /// Decode CITIES.DAT
    /// Each CTY: block: 4B marker "CTY:" + 1B type + 3B padding + 1B index + city name (null-padded) + weather data
    static func decode(at url: URL) throws -> [GameCity] {
        let data = try Data(contentsOf: url)
        guard data.count >= 16 else { return [] }

        var cities: [GameCity] = []
        var searchStart = 0

        while searchStart < data.count - 4 {
            guard let markerRange = data.range(of: cityMarker, in: searchStart..<data.count) else {
                break
            }

            let recordStart = markerRange.lowerBound
            // CTY: marker is 4 bytes, then 1 byte type ('D'), 3 bytes padding, 1 byte index
            let nameStart = recordStart + 4 + 1 + 3 + 1 // = recordStart + 9

            guard nameStart + 16 <= data.count else { break }

            // Extract city name (null-padded, up to ~16 chars)
            var nameEnd = nameStart
            while nameEnd < data.count && nameEnd < nameStart + 16 && data[nameEnd] != 0x00 {
                nameEnd += 1
            }

            let cityIndex = Int(data[recordStart + 8])

            if nameEnd > nameStart,
               let name = String(data: data[nameStart..<nameEnd], encoding: .ascii) {

                // Weather zone byte follows the name area
                let weatherOffset = nameStart + 16
                let weatherZone: Int
                let weatherData: Data

                if weatherOffset + 1 <= data.count {
                    weatherZone = Int(data[weatherOffset])
                    let weatherEnd = min(weatherOffset + 40, data.count)
                    weatherData = Data(data[weatherOffset..<weatherEnd])
                } else {
                    weatherZone = 0
                    weatherData = Data()
                }

                cities.append(GameCity(
                    index: cityIndex,
                    name: name,
                    weatherZone: weatherZone,
                    weatherData: weatherData
                ))
            }

            searchStart = recordStart + 4
        }

        return cities
    }

    /// Load cities from default game directory
    static func loadDefault() -> [GameCity] {
        let url = defaultDirectory.appendingPathComponent("CITIES.DAT")
        guard let cities = try? decode(at: url), !cities.isEmpty else {
            return []
        }
        print("[CitiesDecoder] Loaded \(cities.count) cities")
        for city in cities {
            print("  [\(city.index)] \(city.name) (weather zone: \(city.weatherZone))")
        }
        return cities
    }
}
