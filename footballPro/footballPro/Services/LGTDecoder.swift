//
//  LGTDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 league template files (.LGT).
//  Format: LGT: marker (4B) + uint32 LE size + header bytes,
//  then C00: conference sections, D00: division sections, TMT: team template sections.
//  LTPL08 through LTPL28 (5 league size variants: 8, 10, 12, 18, 28 teams).
//

import Foundation

// MARK: - Data Types

struct LGTConference: Equatable {
    let index: Int
    let name: String
}

struct LGTDivision: Equatable {
    let index: Int
    let name: String
    let conferenceIndex: Int
    let teamIndices: [Int]  // Template team indices assigned to this division
}

struct LGTTeamTemplate: Equatable {
    let index: Int
    let city: String
    let mascot: String
    let abbreviation: String
    let stadiumName: String
    let coachName: String
}

struct LGTTemplate: Equatable {
    let sourceURL: URL
    let conferences: [LGTConference]
    let divisions: [LGTDivision]
    let teamTemplates: [LGTTeamTemplate]
}

// MARK: - Decoder

struct LGTDecoder {
    static let defaultDirectory = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")

    private static let confMarker = Data("C00:".utf8)
    private static let divMarker = Data("D00:".utf8)
    private static let teamMarker = Data("TMT:".utf8)

    // TMT: record field offsets (same layout as LGE T00: records)
    private static let cityOffset = 0x21
    private static let cityLength = 16
    private static let mascotOffset = 0x32
    private static let mascotLength = 16
    private static let abbrOffset = 0x43
    private static let abbrLength = 4
    private static let stadiumOffset = 0x48
    private static let stadiumLength = 17
    private static let coachOffset = 0x59
    private static let coachLength = 20

    static func decode(at url: URL) throws -> LGTTemplate {
        let data = try Data(contentsOf: url)
        guard data.count >= 8 else {
            return LGTTemplate(sourceURL: url, conferences: [], divisions: [], teamTemplates: [])
        }

        // Verify LGT: marker
        let marker = String(data: data[0..<4], encoding: .ascii) ?? ""
        guard marker == "LGT:" else {
            return LGTTemplate(sourceURL: url, conferences: [], divisions: [], teamTemplates: [])
        }

        // Parse conferences (C00: sections)
        var conferences: [LGTConference] = []
        var searchPos = 0
        while let range = data.range(of: confMarker, in: searchPos..<data.count) {
            let pos = range.lowerBound
            // C00: header: marker(4B) + size(4B) + index(2B) + confRef(2B) + flags(3B) + name
            let name = extractNullTerminated(from: data, at: pos + 15, maxLength: 20)
            conferences.append(LGTConference(index: conferences.count, name: name))
            searchPos = pos + 4
        }

        // Parse divisions (D00: sections)
        var divisions: [LGTDivision] = []
        searchPos = 0
        while let range = data.range(of: divMarker, in: searchPos..<data.count) {
            let pos = range.lowerBound
            guard pos + 8 < data.count else { break }

            // D00: header: marker(4B) + size(4B) + index(1B) + confRef(1B) + flags(1B) + teamCount(1B)
            let divIdx = Int(data[pos + 8])
            let confRef = Int(data[pos + 9])

            // Size field tells us the content length
            let sectionSize = Int(data[pos + 4]) | (Int(data[pos + 5]) << 8)
                | (Int(data[pos + 6]) << 16) | (Int(data[pos + 7]) << 24)

            let name = extractNullTerminated(from: data, at: pos + 12, maxLength: 20)

            // Team indices follow the name (null-padded to 20 chars), at offset ~32 from section start
            var teamIndices: [Int] = []
            let teamListStart = pos + 8 + sectionSize - 8  // Last bytes are team indices
            // Scan for team index bytes at the end of the section
            let sectionEnd = pos + 8 + sectionSize
            var tPos = sectionEnd - 1
            // Walk backwards to find where team indices start (they're single bytes < 0x40)
            var tempIndices: [Int] = []
            while tPos >= pos + 32 && data[tPos] < 0x40 {
                tempIndices.insert(Int(data[tPos]), at: 0)
                tPos -= 1
            }
            teamIndices = tempIndices
            _ = teamListStart // suppress warning

            divisions.append(LGTDivision(
                index: divIdx,
                name: name,
                conferenceIndex: confRef,
                teamIndices: teamIndices
            ))
            searchPos = pos + 4
        }

        // Parse team templates (TMT: sections)
        var teamTemplates: [LGTTeamTemplate] = []
        searchPos = 0
        while let range = data.range(of: teamMarker, in: searchPos..<data.count) {
            let pos = range.lowerBound
            guard pos + coachOffset + coachLength <= data.count else { break }

            let city = extractNullTerminated(from: data, at: pos + cityOffset, maxLength: cityLength)
            let mascot = extractNullTerminated(from: data, at: pos + mascotOffset, maxLength: mascotLength)
            let abbr = extractNullTerminated(from: data, at: pos + abbrOffset, maxLength: abbrLength)
            let stadium = extractNullTerminated(from: data, at: pos + stadiumOffset, maxLength: stadiumLength)
            let coach = extractNullTerminated(from: data, at: pos + coachOffset, maxLength: coachLength)

            teamTemplates.append(LGTTeamTemplate(
                index: teamTemplates.count,
                city: city,
                mascot: mascot,
                abbreviation: abbr,
                stadiumName: stadium,
                coachName: coach
            ))
            searchPos = pos + 4
        }

        return LGTTemplate(
            sourceURL: url,
            conferences: conferences,
            divisions: divisions,
            teamTemplates: teamTemplates
        )
    }

    /// Load a specific league template by team count
    static func load(teamCount: Int) -> LGTTemplate? {
        let filename: String
        switch teamCount {
        case 2: filename = "LTPL02.LGT"
        case 8: filename = "LTPL08.LGT"
        case 10: filename = "LTPL10.LGT"
        case 12: filename = "LTPL12.LGT"
        case 18: filename = "LTPL18.LGT"
        case 28: filename = "LTPL28.LGT"
        default: return nil
        }
        let url = defaultDirectory.appendingPathComponent(filename)
        guard let template = try? decode(at: url) else { return nil }
        print("[LGTDecoder] Loaded \(filename): \(template.conferences.count) conferences, \(template.divisions.count) divisions, \(template.teamTemplates.count) team templates")
        return template
    }

    /// Load the default 28-team template
    static func loadDefault() -> LGTTemplate? {
        return load(teamCount: 28)
    }

    private static func extractNullTerminated(from data: Data, at offset: Int, maxLength: Int) -> String {
        guard offset >= 0, offset < data.count else { return "" }
        let end = min(offset + maxLength, data.count)
        let slice = data[offset..<end]
        let trimmed = slice.prefix { $0 != 0x00 }
        return String(bytes: trimmed, encoding: .ascii) ?? ""
    }
}
