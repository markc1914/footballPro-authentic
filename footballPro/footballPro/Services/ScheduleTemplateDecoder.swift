//
//  ScheduleTemplateDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 STPL.DAT.
//  Format: Multiple SCT: sections (schedule templates) + SPT: sections (playoff brackets).
//  Each SCT: section has a 3-byte header (weekCount, leagueType, extra) followed by
//  matchup pairs (home, away) for each game in each week.
//  League sizes: 8, 10, 12, 18, 28 teams across different SCT sections.
//

import Foundation

struct ScheduleMatchup: Equatable {
    let homeTeamIndex: Int  // 1-based team index matching LGE file order
    let awayTeamIndex: Int  // 1-based team index
}

struct ScheduleTemplate: Equatable {
    let leagueSize: Int
    let weekCount: Int
    let leagueType: Int
    let weeks: [[ScheduleMatchup]]  // weeks[weekIndex] = array of matchups
}

struct PlayoffTemplate: Equatable {
    let rawBytes: [UInt8]  // Raw SPT payload for future interpretation
}

struct LeagueScheduleData: Equatable {
    let scheduleTemplates: [ScheduleTemplate]
    let playoffTemplates: [PlayoffTemplate]
}

struct ScheduleTemplateDecoder {
    static let defaultDirectory = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")

    static func decode(at url: URL) throws -> LeagueScheduleData {
        let data = try Data(contentsOf: url)
        guard data.count >= 8 else {
            throw DecoderError.fileTooSmall
        }

        var schedules: [ScheduleTemplate] = []
        var playoffs: [PlayoffTemplate] = []
        var pos = 0

        while pos < data.count - 4 {
            let marker = String(data: data[pos..<min(pos+4, data.count)], encoding: .ascii) ?? ""

            if marker == "SCT:" {
                let sectionSize = readUInt32LE(data, at: pos + 4)
                let contentStart = pos + 8
                guard contentStart + 3 <= data.count else { break }

                let weekCount = Int(data[contentStart])
                let leagueType = Int(data[contentStart + 1])
                // Byte 2 is an extra field (unused)

                // Calculate league size from section data
                let matchupBytes = sectionSize - 3
                guard weekCount > 0 else {
                    pos += 8 + sectionSize
                    continue
                }
                let leagueSize = matchupBytes / weekCount
                let gamesPerWeek = leagueSize / 2

                // Parse matchup pairs
                let dataStart = contentStart + 3
                var weeks: [[ScheduleMatchup]] = []

                for week in 0..<weekCount {
                    var weekMatchups: [ScheduleMatchup] = []
                    for game in 0..<gamesPerWeek {
                        let offset = dataStart + (week * gamesPerWeek * 2) + (game * 2)
                        guard offset + 1 < data.count else { break }
                        let home = Int(data[offset])
                        let away = Int(data[offset + 1])
                        if home >= 1 && home <= leagueSize && away >= 1 && away <= leagueSize && home != away {
                            weekMatchups.append(ScheduleMatchup(homeTeamIndex: home, awayTeamIndex: away))
                        }
                    }
                    weeks.append(weekMatchups)
                }

                schedules.append(ScheduleTemplate(
                    leagueSize: leagueSize,
                    weekCount: weekCount,
                    leagueType: leagueType,
                    weeks: weeks
                ))

                pos += 8 + sectionSize

            } else if marker == "SPT:" {
                let sectionSize = readUInt32LE(data, at: pos + 4)
                let contentStart = pos + 8
                var rawBytes: [UInt8] = []
                for i in 0..<sectionSize {
                    guard contentStart + i < data.count else { break }
                    rawBytes.append(data[contentStart + i])
                }
                playoffs.append(PlayoffTemplate(rawBytes: rawBytes))
                pos += 8 + sectionSize
            } else {
                pos += 1
            }
        }

        return LeagueScheduleData(scheduleTemplates: schedules, playoffTemplates: playoffs)
    }

    /// Find the best matching schedule template for the given team count
    static func template(for teamCount: Int, from data: LeagueScheduleData) -> ScheduleTemplate? {
        // Exact match first
        if let exact = data.scheduleTemplates.first(where: { $0.leagueSize == teamCount }) {
            return exact
        }
        // Find the closest template with league size >= teamCount
        let larger = data.scheduleTemplates
            .filter { $0.leagueSize >= teamCount }
            .sorted { $0.leagueSize < $1.leagueSize }
        return larger.first
    }

    static func loadDefault() -> LeagueScheduleData? {
        let url = defaultDirectory.appendingPathComponent("STPL.DAT")
        guard let data = try? decode(at: url) else { return nil }
        let sizes = data.scheduleTemplates.map { $0.leagueSize }
        print("[ScheduleTemplateDecoder] Loaded \(data.scheduleTemplates.count) schedule templates (sizes: \(sizes))")
        return data
    }

    private static func readUInt32LE(_ data: Data, at offset: Int) -> Int {
        guard offset + 3 < data.count else { return 0 }
        return Int(data[offset]) | (Int(data[offset+1]) << 8) |
               (Int(data[offset+2]) << 16) | (Int(data[offset+3]) << 24)
    }

    enum DecoderError: Error {
        case fileTooSmall
    }
}
