//
//  NameDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 NAMEF.DAT and NAMEL.DAT name databases.
//  Format: Sequential null-terminated ASCII strings.
//

import Foundation

struct NameDatabase {
    let firstNames: [String]
    let lastNames: [String]

    func randomFirstName() -> String {
        firstNames.randomElement() ?? "John"
    }

    func randomLastName() -> String {
        lastNames.randomElement() ?? "Smith"
    }

    func randomFullName() -> (first: String, last: String) {
        (randomFirstName(), randomLastName())
    }
}

struct NameDecoder {
    /// Default game data directory
    static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")

    /// Decode a name database file (NAMEF.DAT or NAMEL.DAT)
    /// Format: null-terminated ASCII strings packed sequentially
    static func decodeNames(at url: URL) throws -> [String] {
        let data = try Data(contentsOf: url)
        var names: [String] = []
        var start = 0

        for i in 0..<data.count {
            if data[i] == 0x00 {
                if i > start {
                    if let name = String(data: data[start..<i], encoding: .ascii) {
                        names.append(name)
                    }
                }
                start = i + 1
            }
        }

        // Handle case where file doesn't end with null
        if start < data.count {
            if let name = String(data: data[start..<data.count], encoding: .ascii) {
                names.append(name)
            }
        }

        return names
    }

    /// Decode unique names (original files have duplicates for frequency weighting)
    static func decodeUniqueNames(at url: URL) throws -> [String] {
        let all = try decodeNames(at: url)
        var seen = Set<String>()
        return all.filter { seen.insert($0).inserted }
    }

    /// Load the full name database from default game directory
    static func loadDefaultDatabase() -> NameDatabase? {
        let firstURL = defaultDirectory.appendingPathComponent("NAMEF.DAT")
        let lastURL = defaultDirectory.appendingPathComponent("NAMEL.DAT")

        guard let firstNames = try? decodeNames(at: firstURL),
              let lastNames = try? decodeNames(at: lastURL),
              !firstNames.isEmpty, !lastNames.isEmpty else {
            return nil
        }

        print("[NameDecoder] Loaded \(firstNames.count) first names, \(lastNames.count) last names")
        return NameDatabase(firstNames: firstNames, lastNames: lastNames)
    }
}
