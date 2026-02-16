//
//  SeasonStatsDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 season statistics files (1992.DAT).
//  Format: 0x8C-byte header + 20-byte stat records until 0xFF padding.
//  Each record: type(1B) + 0x00(1B) + entity_id(2B LE) + data(16B)
//  Player IDs are PYR indices (100-1256). Team IDs are 1-28.
//

import Foundation

// MARK: - Stat Record Types

/// Individual player stat categories decoded from 1992.DAT
struct HistoricalRushingStats {
    let attempts: Int
    let yards: Int       // signed
    let longest: Int
    let touchdowns: Int
}

struct HistoricalPassingStats {
    let attempts: Int
    let yards: Int
    let longest: Int
    let touchdowns: Int
    let completions: Int
    let interceptions: Int
    let sacked: Int
    let sackYards: Int
}

struct HistoricalReceivingStats {
    let receptions: Int
    let yards: Int
    let longest: Int
    let touchdowns: Int
}

struct HistoricalInterceptionStats {
    let interceptions: Int
    let returnYards: Int
    let longest: Int
    let touchdowns: Int
}

struct HistoricalPuntingStats {
    let punts: Int
    let yards: Int
    let longest: Int
    let inside20: Int
    let touchbacks: Int
}

struct HistoricalPuntReturnStats {
    let returns: Int
    let yards: Int
    let longest: Int
    let touchdowns: Int
    let fairCatches: Int
}

struct HistoricalKOReturnStats {
    let returns: Int
    let yards: Int
    let longest: Int
    let touchdowns: Int
}

struct HistoricalKickerXPStats {
    let attempted: Int
    let made: Int
}

struct HistoricalKickerFGStats {
    let kickoffs: Int
    let madeByRange: [(made: Int, attempted: Int)]  // 5 ranges
    let longFG: Int

    var totalMade: Int { madeByRange.reduce(0) { $0 + $1.made } }
    var totalAttempted: Int { madeByRange.reduce(0) { $0 + $1.attempted } }
}

struct HistoricalSackStats {
    let sacks: Int
}

struct HistoricalTackleStats {
    let tackles: Int
}

struct HistoricalFumbleStats {
    let fumbles: Int
}

struct HistoricalFumRecoveryStats {
    let recoveries: Int
    let returnYards: Int
    let longest: Int
    let touchdowns: Int
}

// MARK: - Aggregated Player Stats

/// All stats for a single player, aggregated from multiple record types
struct HistoricalPlayerStats {
    let entityId: Int
    var playerName: String = ""
    var teamAbbr: String = ""
    var position: String = ""

    var rushing: HistoricalRushingStats?
    var passing: HistoricalPassingStats?
    var receiving: HistoricalReceivingStats?
    var interceptions: HistoricalInterceptionStats?
    var punting: HistoricalPuntingStats?
    var puntReturns: HistoricalPuntReturnStats?
    var koReturns: HistoricalKOReturnStats?
    var kickerXP: HistoricalKickerXPStats?
    var kickerFG: HistoricalKickerFGStats?
    var sacks: HistoricalSackStats?
    var tackles: HistoricalTackleStats?
    var fumbles: HistoricalFumbleStats?
    var fumRecovery: HistoricalFumRecoveryStats?
}

/// All stats for a single team, aggregated from multiple record types
struct HistoricalTeamStats {
    let teamId: Int
    var teamName: String = ""

    var rushing: HistoricalRushingStats?
    var passing: HistoricalPassingStats?
    var oppRushing: HistoricalRushingStats?
    var oppPassing: HistoricalPassingStats?
}

// MARK: - Decoded Season

struct HistoricalSeason {
    let sourceURL: URL
    let playerStats: [Int: HistoricalPlayerStats]   // entityId -> stats
    let teamStats: [Int: HistoricalTeamStats]        // teamId -> stats
    let recordCount: Int

    /// Get rushing leaders sorted by yards
    func rushingLeaders(limit: Int = 30) -> [HistoricalPlayerStats] {
        playerStats.values
            .filter { $0.rushing != nil && $0.rushing!.attempts > 0 }
            .sorted { ($0.rushing?.yards ?? 0) > ($1.rushing?.yards ?? 0) }
            .prefix(limit)
            .map { $0 }
    }

    /// Get passing leaders sorted by yards
    func passingLeaders(limit: Int = 30) -> [HistoricalPlayerStats] {
        playerStats.values
            .filter { $0.passing != nil && $0.passing!.attempts > 0 }
            .sorted { ($0.passing?.yards ?? 0) > ($1.passing?.yards ?? 0) }
            .prefix(limit)
            .map { $0 }
    }

    /// Get receiving leaders sorted by yards
    func receivingLeaders(limit: Int = 30) -> [HistoricalPlayerStats] {
        playerStats.values
            .filter { $0.receiving != nil && $0.receiving!.receptions > 0 }
            .sorted { ($0.receiving?.yards ?? 0) > ($1.receiving?.yards ?? 0) }
            .prefix(limit)
            .map { $0 }
    }

    /// Get defensive leaders sorted by tackles
    func defenseLeaders(limit: Int = 30) -> [HistoricalPlayerStats] {
        playerStats.values
            .filter {
                ($0.tackles?.tackles ?? 0) > 0 ||
                ($0.sacks?.sacks ?? 0) > 0 ||
                ($0.interceptions?.interceptions ?? 0) > 0
            }
            .sorted { ($0.tackles?.tackles ?? 0) > ($1.tackles?.tackles ?? 0) }
            .prefix(limit)
            .map { $0 }
    }

    /// Get kicking leaders sorted by FG made
    func kickingLeaders(limit: Int = 30) -> [HistoricalPlayerStats] {
        playerStats.values
            .filter { $0.kickerFG != nil || $0.kickerXP != nil }
            .sorted { ($0.kickerFG?.totalMade ?? 0) > ($1.kickerFG?.totalMade ?? 0) }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Decoder

struct SeasonStatsDecoder {
    static let defaultDirectory = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")
    static let gameDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")

    private static let headerSize = 0x8C
    private static let recordSize = 20

    // Player stat type codes
    private static let typeKickerXP: UInt8    = 0x20
    private static let typeKickerFG: UInt8    = 0x21
    private static let typeRushing: UInt8     = 0x22
    private static let typePassing: UInt8     = 0x23
    private static let typeReceiving: UInt8   = 0x24
    private static let typeInterceptions: UInt8 = 0x25
    private static let typePunting: UInt8     = 0x26
    private static let typePuntReturns: UInt8 = 0x27
    private static let typeKOReturns: UInt8   = 0x28
    private static let typeFumbles: UInt8     = 0x29
    private static let typeFumRecovery: UInt8 = 0x2A
    private static let typeSacks: UInt8       = 0x2B
    private static let typeSafeties: UInt8    = 0x2C
    private static let typeTackles: UInt8     = 0x2D

    // Team stat type codes (same layout, entity_id = team 1-28)
    private static let teamTypeBase: UInt8    = 0x82  // 0x82-0x8F mirror 0x20-0x2D
    private static let typeOppRushing: UInt8  = 0xC8
    private static let typeOppPassing: UInt8  = 0xC9

    /// Decode 1992.DAT and cross-reference with 1992.PYR and 1992.XGE for names
    static func decode1992Season() -> HistoricalSeason? {
        // Try multiple directories
        let directories = [defaultDirectory, gameDirectory]

        for dir in directories {
            let datURL = dir.appendingPathComponent("1992.DAT")
            guard FileManager.default.fileExists(atPath: datURL.path) else { continue }

            guard let season = try? decodeDAT(at: datURL) else { continue }

            // Cross-reference with PYR for player names
            var enriched = season
            enrichPYRNames(season: &enriched, directory: dir)
            enrichTeamNames(season: &enriched, directory: dir)

            print("[SeasonStatsDecoder] Loaded 1992 season: \(enriched.recordCount) records, \(enriched.playerStats.count) players, \(enriched.teamStats.count) teams")
            return enriched
        }

        return nil
    }

    /// Decode a .DAT file
    static func decodeDAT(at url: URL) throws -> HistoricalSeason {
        let data = try Data(contentsOf: url)
        guard data.count > headerSize else {
            throw DecoderError.fileTooSmall
        }

        var playerStats: [Int: HistoricalPlayerStats] = [:]
        var teamStats: [Int: HistoricalTeamStats] = [:]
        var recordCount = 0
        var pos = headerSize

        while pos + recordSize <= data.count {
            let recordType = data[pos]

            // Stop at 0xFF padding
            if recordType == 0xFF { break }

            let entityId = Int(data[pos + 2]) | (Int(data[pos + 3]) << 8)
            let statData = Data(data[(pos + 4)..<(pos + 20)])

            // Determine if player or team record
            if recordType >= 0x82 {
                // Team stat record
                if teamStats[entityId] == nil {
                    teamStats[entityId] = HistoricalTeamStats(teamId: entityId)
                }
                decodeTeamRecord(type: recordType, data: statData, into: &teamStats[entityId]!)
            } else if recordType >= 0x20 && recordType <= 0x2D {
                // Player stat record
                if playerStats[entityId] == nil {
                    playerStats[entityId] = HistoricalPlayerStats(entityId: entityId)
                }
                decodePlayerRecord(type: recordType, data: statData, into: &playerStats[entityId]!)
            }

            recordCount += 1
            pos += recordSize
        }

        return HistoricalSeason(
            sourceURL: url,
            playerStats: playerStats,
            teamStats: teamStats,
            recordCount: recordCount
        )
    }

    // MARK: - Player Record Decoding

    private static func decodePlayerRecord(type: UInt8, data: Data, into stats: inout HistoricalPlayerStats) {
        switch type {
        case typeRushing:
            stats.rushing = HistoricalRushingStats(
                attempts: readUInt16(data, 0),
                yards: readInt16(data, 2),
                longest: readUInt16(data, 4),
                touchdowns: readUInt16(data, 6)
            )

        case typePassing:
            stats.passing = HistoricalPassingStats(
                attempts: readUInt16(data, 0),
                yards: readUInt16(data, 2),
                longest: readUInt16(data, 4),
                touchdowns: readUInt16(data, 6),
                completions: readUInt16(data, 8),
                interceptions: readUInt16(data, 10),
                sacked: readUInt16(data, 12),
                sackYards: readUInt16(data, 14)
            )

        case typeReceiving:
            stats.receiving = HistoricalReceivingStats(
                receptions: readUInt16(data, 0),
                yards: readUInt16(data, 2),
                longest: readUInt16(data, 4),
                touchdowns: readUInt16(data, 6)
            )

        case typeInterceptions:
            stats.interceptions = HistoricalInterceptionStats(
                interceptions: readUInt16(data, 0),
                returnYards: readUInt16(data, 2),
                longest: readUInt16(data, 4),
                touchdowns: readUInt16(data, 6)
            )

        case typePunting:
            stats.punting = HistoricalPuntingStats(
                punts: readUInt16(data, 0),
                yards: readUInt16(data, 2),
                longest: readUInt16(data, 4),
                inside20: readUInt16(data, 10),
                touchbacks: readUInt16(data, 14)
            )

        case typePuntReturns:
            stats.puntReturns = HistoricalPuntReturnStats(
                returns: readUInt16(data, 0),
                yards: readUInt16(data, 2),
                longest: readUInt16(data, 4),
                touchdowns: readUInt16(data, 6),
                fairCatches: readUInt16(data, 8)
            )

        case typeKOReturns:
            stats.koReturns = HistoricalKOReturnStats(
                returns: readUInt16(data, 0),
                yards: readUInt16(data, 2),
                longest: readUInt16(data, 4),
                touchdowns: readUInt16(data, 6)
            )

        case typeKickerXP:
            stats.kickerXP = HistoricalKickerXPStats(
                attempted: readUInt16(data, 0),
                made: readUInt16(data, 2)
            )

        case typeKickerFG:
            // 1B kickoffs + 5x(u8 made, u8 att) by range + 1B long_fg
            let kickoffs = Int(data[data.startIndex])
            var ranges: [(Int, Int)] = []
            for i in 0..<5 {
                let base = data.startIndex + 1 + (i * 2)
                if base + 1 < data.endIndex {
                    ranges.append((Int(data[base]), Int(data[base + 1])))
                }
            }
            let longIdx = data.startIndex + 11
            let longFG = longIdx < data.endIndex ? Int(data[longIdx]) : 0
            stats.kickerFG = HistoricalKickerFGStats(
                kickoffs: kickoffs,
                madeByRange: ranges,
                longFG: longFG
            )

        case typeSacks:
            stats.sacks = HistoricalSackStats(sacks: readUInt16(data, 0))

        case typeTackles:
            stats.tackles = HistoricalTackleStats(tackles: readUInt16(data, 0))

        case typeFumbles:
            stats.fumbles = HistoricalFumbleStats(fumbles: readUInt16(data, 0))

        case typeFumRecovery:
            stats.fumRecovery = HistoricalFumRecoveryStats(
                recoveries: readUInt16(data, 0),
                returnYards: readUInt16(data, 2),
                longest: readUInt16(data, 4),
                touchdowns: readUInt16(data, 6)
            )

        default:
            break
        }
    }

    // MARK: - Team Record Decoding

    private static func decodeTeamRecord(type: UInt8, data: Data, into stats: inout HistoricalTeamStats) {
        switch type {
        case 0x84: // Team rushing (same layout as player rushing)
            stats.rushing = HistoricalRushingStats(
                attempts: readUInt16(data, 0),
                yards: readInt16(data, 2),
                longest: readUInt16(data, 4),
                touchdowns: readUInt16(data, 6)
            )

        case 0x85: // Team passing
            stats.passing = HistoricalPassingStats(
                attempts: readUInt16(data, 0),
                yards: readUInt16(data, 2),
                longest: readUInt16(data, 4),
                touchdowns: readUInt16(data, 6),
                completions: readUInt16(data, 8),
                interceptions: readUInt16(data, 10),
                sacked: readUInt16(data, 12),
                sackYards: readUInt16(data, 14)
            )

        case typeOppRushing:
            stats.oppRushing = HistoricalRushingStats(
                attempts: readUInt16(data, 0),
                yards: readInt16(data, 2),
                longest: readUInt16(data, 4),
                touchdowns: readUInt16(data, 6)
            )

        case typeOppPassing:
            stats.oppPassing = HistoricalPassingStats(
                attempts: readUInt16(data, 0),
                yards: readUInt16(data, 2),
                longest: readUInt16(data, 4),
                touchdowns: readUInt16(data, 6),
                completions: readUInt16(data, 8),
                interceptions: readUInt16(data, 10),
                sacked: readUInt16(data, 12),
                sackYards: readUInt16(data, 14)
            )

        default:
            break
        }
    }

    // MARK: - Name Enrichment

    /// Cross-reference entity IDs with 1992.PYR to get player names and positions
    private static func enrichPYRNames(season: inout HistoricalSeason, directory: URL) {
        let pyrURL = directory.appendingPathComponent("1992.PYR")
        guard let pyrFile = try? PYRDecoder.decode(at: pyrURL) else { return }

        // Also load XGE (same format as LGE) for team assignments
        let xgeURL = directory.appendingPathComponent("1992.XGE")
        let league = try? LGEDecoder.decode(at: xgeURL)

        // Build player-to-team lookup from league rosters
        var playerTeamMap: [Int: String] = [:]
        if let league = league {
            for team in league.teams {
                for playerIdx in team.rosterPlayerIndices {
                    playerTeamMap[playerIdx] = team.abbreviation
                }
            }
        }

        var enrichedStats = season.playerStats
        for (entityId, var stats) in enrichedStats {
            if let pyrPlayer = pyrFile.player(byIndex: entityId) {
                stats.playerName = pyrPlayer.fullName
                stats.position = PYRDecoder.mapPosition(code: pyrPlayer.positionCode).rawValue
                stats.teamAbbr = playerTeamMap[entityId] ?? ""
                enrichedStats[entityId] = stats
            }
        }

        season = HistoricalSeason(
            sourceURL: season.sourceURL,
            playerStats: enrichedStats,
            teamStats: season.teamStats,
            recordCount: season.recordCount
        )
    }

    /// Cross-reference team IDs with 1992.XGE for team names
    private static func enrichTeamNames(season: inout HistoricalSeason, directory: URL) {
        let xgeURL = directory.appendingPathComponent("1992.XGE")
        guard let league = try? LGEDecoder.decode(at: xgeURL) else { return }

        var enrichedTeams = season.teamStats
        for (teamId, var stats) in enrichedTeams {
            // Team IDs in DAT are 1-based, league teams are 0-indexed
            let teamIdx = teamId - 1
            if teamIdx >= 0 && teamIdx < league.teams.count {
                stats.teamName = league.teams[teamIdx].fullName
                enrichedTeams[teamId] = stats
            }
        }

        season = HistoricalSeason(
            sourceURL: season.sourceURL,
            playerStats: season.playerStats,
            teamStats: enrichedTeams,
            recordCount: season.recordCount
        )
    }

    // MARK: - Binary Helpers

    private static func readUInt16(_ data: Data, _ offset: Int) -> Int {
        let idx = data.startIndex + offset
        guard idx + 1 < data.endIndex else { return 0 }
        return Int(data[idx]) | (Int(data[idx + 1]) << 8)
    }

    private static func readInt16(_ data: Data, _ offset: Int) -> Int {
        let raw = readUInt16(data, offset)
        return raw > 32767 ? raw - 65536 : raw
    }

    enum DecoderError: Error {
        case fileTooSmall
        case fileNotFound
    }
}
