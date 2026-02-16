//
//  LGEDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 league files (.LGE).
//  Format: Section-based with markers T00: (teams), R00: (rosters),
//  C00: (conferences), D00: (divisions).
//  Team record: city(16B) + mascot(17B) + abbreviation(4B) + stadium(17B) + coach(20B)
//

import Foundation

// MARK: - Data Types

struct LGEConference: Equatable {
    let index: Int
    let name: String
}

struct LGEDivision: Equatable {
    let index: Int
    let name: String
    let conferenceIndex: Int
}

struct LGETeam: Equatable {
    let index: Int
    let city: String
    let mascot: String
    let abbreviation: String
    let stadiumName: String
    let coachName: String
    let divisionIndex: Int
    let conferenceIndex: Int
    let colorData: Data
    let rosterPlayerIndices: [Int]
    let jerseyNumbers: [Int]

    var fullName: String { "\(city) \(mascot)" }
}

struct LGELeague: Equatable {
    let sourceURL: URL
    let leagueName: String
    let trophyName: String
    let conferences: [LGEConference]
    let divisions: [LGEDivision]
    let teams: [LGETeam]
}

// MARK: - Decoder

struct LGEDecoder {
    static let defaultDirectory = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")

    private static let teamMarker = Data("T00:".utf8)
    private static let rosterMarker = Data("R00:".utf8)
    private static let confMarker = Data("C00:".utf8)
    private static let divMarker = Data("D00:".utf8)

    // Offsets within T00: record
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
    private static let colorOffset = 0x0C
    private static let colorLength = 21

    static func decode(at url: URL) throws -> LGELeague {
        let data = try Data(contentsOf: url)

        // Parse league name from header (at offset ~0x17)
        let leagueName = extractNullTerminated(from: data, at: 0x0F, maxLength: 32)
        let trophyName = extractNullTerminated(from: data, at: 0x2F, maxLength: 32)

        // Parse conferences
        var conferences: [LGEConference] = []
        var confIndex = 0
        var searchPos = 0
        while let range = data.range(of: confMarker, in: searchPos..<data.count) {
            let pos = range.lowerBound
            let name = extractNullTerminated(from: data, at: pos + 11, maxLength: 32)
            conferences.append(LGEConference(index: confIndex, name: name))
            confIndex += 1
            searchPos = pos + 4
        }

        // Parse divisions
        var divisions: [LGEDivision] = []
        searchPos = 0
        while let range = data.range(of: divMarker, in: searchPos..<data.count) {
            let pos = range.lowerBound
            let name = extractNullTerminated(from: data, at: pos + 11, maxLength: 32)
            let divIdx = data.count > pos + 8 ? Int(data[pos + 8]) : divisions.count
            let confRef = data.count > pos + 9 ? Int(data[pos + 9]) : 0
            divisions.append(LGEDivision(index: divIdx, name: name, conferenceIndex: confRef))
            searchPos = pos + 4
        }

        // Parse teams
        var teams: [LGETeam] = []
        searchPos = 0
        var currentDivIndex = 0
        var currentConfIndex = 0

        // Track which division each team belongs to based on section ordering
        var divisionTeamMap: [Int: [Int]] = [:]

        while let range = data.range(of: teamMarker, in: searchPos..<data.count) {
            let pos = range.lowerBound
            let teamIndex = teams.count

            // Check if a division marker appears between last team and this one
            for div in divisions {
                // Find the D00: marker for this division
                if let divRange = data.range(of: divMarker, in: max(0, searchPos - 200)..<pos) {
                    let divPos = divRange.lowerBound
                    if divPos >= searchPos - 200 && divPos < pos {
                        let idx = Int(data[divPos + 8])
                        let cRef = Int(data[divPos + 9])
                        currentDivIndex = idx
                        currentConfIndex = cRef
                    }
                }
                _ = div // suppress unused warning
            }

            guard pos + coachOffset + coachLength <= data.count else { break }

            let city = extractNullTerminated(from: data, at: pos + cityOffset, maxLength: cityLength)
            let mascot = extractNullTerminated(from: data, at: pos + mascotOffset, maxLength: mascotLength)
            let abbr = extractNullTerminated(from: data, at: pos + abbrOffset, maxLength: abbrLength)
            let stadium = extractNullTerminated(from: data, at: pos + stadiumOffset, maxLength: stadiumLength)
            let coach = extractNullTerminated(from: data, at: pos + coachOffset, maxLength: coachLength)
            let colors = Data(data[(pos + colorOffset)..<min(pos + colorOffset + colorLength, data.count)])

            // Parse R00: roster for this team
            var rosterIndices: [Int] = []
            var jerseyNumbers: [Int] = []
            if let rRange = data.range(of: rosterMarker, in: pos + 4..<min(pos + 500, data.count)) {
                let rPos = rRange.lowerBound
                var cursor = rPos + 10 // Skip R00: header (4 marker + 4 size + 2 team#)
                while cursor + 2 <= data.count {
                    let lo = Int(data[cursor])
                    let hi = Int(data[cursor + 1])
                    let playerIdx = lo | (hi << 8)
                    if playerIdx == 0 { break }
                    rosterIndices.append(playerIdx)
                    cursor += 2
                }

                // Jersey numbers: 45 × uint8 starting at offset +104 from rPos
                let jerseyBase = rPos + 104
                for j in 0..<min(45, rosterIndices.count) {
                    if jerseyBase + j < data.count {
                        jerseyNumbers.append(Int(data[jerseyBase + j]))
                    } else {
                        jerseyNumbers.append(0)
                    }
                }
            }

            teams.append(LGETeam(
                index: teamIndex,
                city: city,
                mascot: mascot,
                abbreviation: abbr,
                stadiumName: stadium,
                coachName: coach,
                divisionIndex: currentDivIndex,
                conferenceIndex: currentConfIndex,
                colorData: colors,
                rosterPlayerIndices: rosterIndices,
                jerseyNumbers: jerseyNumbers
            ))

            divisionTeamMap[currentDivIndex, default: []].append(teamIndex)
            searchPos = pos + 4
        }

        return LGELeague(
            sourceURL: url,
            leagueName: leagueName,
            trophyName: trophyName,
            conferences: conferences,
            divisions: divisions,
            teams: teams
        )
    }

    /// Load the default NFLPA93 league
    static func loadDefault() -> LGELeague? {
        let url = defaultDirectory.appendingPathComponent("NFLPA93.LGE")
        guard let league = try? decode(at: url) else { return nil }
        print("[LGEDecoder] Loaded '\(league.leagueName)': \(league.conferences.count) conferences, \(league.divisions.count) divisions, \(league.teams.count) teams")
        for team in league.teams {
            print("  [\(team.index)] \(team.fullName) (\(team.abbreviation)) @ \(team.stadiumName) - Coach: \(team.coachName) [\(team.rosterPlayerIndices.count) players, \(team.jerseyNumbers.count) jerseys]")
        }
        return league
    }

    private static func extractNullTerminated(from data: Data, at offset: Int, maxLength: Int) -> String {
        guard offset >= 0 && offset < data.count else { return "" }
        let end = min(offset + maxLength, data.count)
        let slice = data[offset..<end]
        let trimmed = slice.prefix { $0 != 0x00 }
        return String(bytes: trimmed, encoding: .ascii) ?? ""
    }
}
