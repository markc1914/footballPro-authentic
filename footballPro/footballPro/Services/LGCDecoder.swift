//
//  LGCDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 league city pair files (.LGC).
//  Format: Repeating LGC: sections, each 44 bytes:
//    LGC: marker (4B) + uint32 LE size (4B, always 0x24=36)
//    + city1 (17B null-padded) + byte1 (1B) + city2 (17B null-padded) + byte2 (1B)
//  NFLPA93.LGC: 27 city pair records, 1,188 bytes.
//  Historical matchup data for Super Bowl / championship game pairings.
//

import Foundation

struct LGCCityPair: Equatable {
    let city1: String
    let city2: String
    let value1: UInt8  // Possibly team index or year reference
    let value2: UInt8
}

struct LGCData: Equatable {
    let cityPairs: [LGCCityPair]
}

struct LGCDecoder {
    static let defaultDirectory = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")

    private static let sectionMarker = Data("LGC:".utf8)
    private static let recordSize = 44  // 8B header + 36B content
    private static let cityFieldLength = 17

    static func decode(at url: URL) throws -> LGCData {
        let data = try Data(contentsOf: url)
        var pairs: [LGCCityPair] = []
        var searchPos = 0

        while let range = data.range(of: sectionMarker, in: searchPos..<data.count) {
            let pos = range.lowerBound
            guard pos + recordSize <= data.count else { break }

            // Skip marker (4B) + size (4B) = 8 bytes to content
            let contentStart = pos + 8
            let city1 = extractNullTerminated(from: data, at: contentStart, maxLength: cityFieldLength)
            let value1 = data[contentStart + cityFieldLength]
            let city2 = extractNullTerminated(from: data, at: contentStart + cityFieldLength + 1, maxLength: cityFieldLength)
            let value2 = data[contentStart + cityFieldLength + 1 + cityFieldLength]

            pairs.append(LGCCityPair(city1: city1, city2: city2, value1: value1, value2: value2))
            searchPos = pos + recordSize
        }

        return LGCData(cityPairs: pairs)
    }

    static func loadDefault() -> LGCData? {
        let url = defaultDirectory.appendingPathComponent("NFLPA93.LGC")
        guard let lgc = try? decode(at: url), !lgc.cityPairs.isEmpty else { return nil }
        print("[LGCDecoder] Loaded \(lgc.cityPairs.count) city pairs")
        for (i, pair) in lgc.cityPairs.enumerated() {
            print("  [\(i)] \(pair.city1) vs \(pair.city2)")
        }
        return lgc
    }

    private static func extractNullTerminated(from data: Data, at offset: Int, maxLength: Int) -> String {
        guard offset >= 0, offset < data.count else { return "" }
        let end = min(offset + maxLength, data.count)
        let slice = data[offset..<end]
        let trimmed = slice.prefix { $0 != 0x00 }
        return String(bytes: trimmed, encoding: .ascii) ?? ""
    }
}
