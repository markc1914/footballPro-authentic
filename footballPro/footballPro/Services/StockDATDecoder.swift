//
//  StockDATDecoder.swift
//  footballPro
//
//  Decodes STOCK.DAT play/formation records from FPS Football Pro '93.
//  Uses STOCK.MAP as an index to locate records within STOCK.DAT.
//  Returns structured play data: pre-snap positions, post-snap routes,
//  blocking assignments, and zone/coverage instructions for all 11 players.
//

import Foundation
import CoreGraphics

// MARK: - Stock Play Data Model

/// A fully decoded play or formation from STOCK.DAT
struct StockPlay {
    let name: String
    let index: Int
    let category: StockPlayCategory
    let recordTypeID: UInt8
    let players: [StockPlayerEntry]  // Up to 11 player entries
}

enum StockPlayCategory: String {
    case offensiveFormation = "Offensive Formation"
    case defensiveFormation = "Defensive Formation"
    case specialTeams = "Special Teams"
    case offensivePlay = "Offensive Play"
    case defensivePlay = "Defensive Play"
}

/// A single player entry within a StockPlay record
struct StockPlayerEntry {
    let side: UInt8           // 1=left, 2=right, 3=far/split
    let role: UInt8           // 0=default, 1=center, 2=QB/primary
    let positionCode: UInt16  // Position type code (e.g. 0x0020=QB)
    let preSnapPosition: CGPoint?   // PH1 coordinates (STOCK.DAT native)
    let postSnapPosition: CGPoint?  // PH2 coordinates
    let routePhasePosition: CGPoint? // PH3 coordinates
    let routeWaypoints: [CGPoint]   // 0x0202 intermediate waypoints
    let motionTarget: CGPoint?      // 0x020A pre-snap motion destination
    let assignments: [StockAssignment] // 0x01xx assignment nodes
    let hasQBThrow: Bool            // 0x021B node present
    let zoneTarget: CGPoint?        // 0x0219 zone coverage target
    let delayTicks: Int             // Sum of 0x00xx delay values
}

/// An assignment from the node stream (blocking, coverage, etc.)
struct StockAssignment {
    let type: StockAssignmentType
    let targetPlayerIndex: UInt8  // Which player this assignment references
}

enum StockAssignmentType: UInt16 {
    case passTarget = 0x0101
    case block = 0x0103
    case leadBlock = 0x0104
    case coverage = 0x010E
    case rush = 0x010F
    case unknown = 0xFFFF

    init(rawMarker: UInt16) {
        switch rawMarker {
        case 0x0101: self = .passTarget
        case 0x0103: self = .block
        case 0x0104: self = .leadBlock
        case 0x010E: self = .coverage
        case 0x010F: self = .rush
        default: self = .unknown
        }
    }
}

/// Position type code to football position mapping
enum StockPositionType: UInt16 {
    case OT = 0x0010
    case OG = 0x0011
    case C  = 0x0012
    case QB = 0x0020
    case HB = 0x0041
    case FB = 0x0042
    case WR = 0x0080
    case TE = 0x0081
    case DE = 0x0101
    case DT = 0x0102
    case LB = 0x0200
    case CB = 0x0400
    case S  = 0x0401
    case K  = 0x0800
    case P  = 0x1000
}

// MARK: - MAP Entry (index into DAT)

struct StockMapEntry {
    let index: Int
    let name: String
    let dim1: UInt8
    let dim2: UInt8
    let datOffset: UInt32
}

// MARK: - Stock Database (loaded result)

struct StockDatabase {
    let plays: [StockPlay]
    let mapEntries: [StockMapEntry]

    /// All offensive formations (indices 0-21)
    var offensiveFormations: [StockPlay] {
        plays.filter { $0.category == .offensiveFormation }
    }

    /// All defensive formations (indices 22-32)
    var defensiveFormations: [StockPlay] {
        plays.filter { $0.category == .defensiveFormation }
    }

    /// All offensive plays (indices 33+, category = offensivePlay)
    var offensivePlays: [StockPlay] {
        plays.filter { $0.category == .offensivePlay }
    }

    /// All defensive plays
    var defensivePlays: [StockPlay] {
        plays.filter { $0.category == .defensivePlay }
    }

    /// Special teams plays
    var specialTeamsPlays: [StockPlay] {
        plays.filter { $0.category == .specialTeams }
    }

    /// Look up a play by name (case-insensitive)
    func play(named name: String) -> StockPlay? {
        plays.first { $0.name.uppercased() == name.uppercased() }
    }

    /// Look up a play by MAP index
    func play(at index: Int) -> StockPlay? {
        plays.first { $0.index == index }
    }

    /// Get offensive plays that use a given formation name
    func offensivePlays(forFormation formationName: String) -> [StockPlay] {
        // Convention: play names often start with or contain the formation abbreviation
        let upper = formationName.uppercased()
        return offensivePlays.filter { play in
            play.name.uppercased().contains(upper)
        }
    }

    /// Get a random offensive play
    func randomOffensivePlay() -> StockPlay? {
        offensivePlays.randomElement()
    }

    /// Get a random defensive play
    func randomDefensivePlay() -> StockPlay? {
        defensivePlays.randomElement()
    }
}

// MARK: - StockDATDecoder

struct StockDATDecoder {

    /// Default file paths
    static let defaultMAPPath = "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL/STOCK.MAP"
    static let defaultDATPath = "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL/STOCK.DAT"

    /// Alternate paths (game directory)
    static let gameMAPPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO/STOCK.MAP"
    }()
    static let gameDATPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO/STOCK.DAT"
    }()

    // MARK: - MAP header
    private static let mapHeader = "ZTA:tF"
    private static let mapHeaderSize = 6
    private static let mapEntrySize = 18
    private static let recordHeaderSize = 25

    // MARK: - Public API

    /// Load the full stock database from default paths
    static func loadDefault() -> StockDatabase? {
        // Try project copy first, then game directory
        if let db = load(mapPath: defaultMAPPath, datPath: defaultDATPath) {
            return db
        }
        return load(mapPath: gameMAPPath, datPath: gameDATPath)
    }

    /// Load from specific file paths
    static func load(mapPath: String, datPath: String) -> StockDatabase? {
        guard let mapData = try? Data(contentsOf: URL(fileURLWithPath: mapPath)),
              let datData = try? Data(contentsOf: URL(fileURLWithPath: datPath)) else {
            print("[StockDATDecoder] Could not read STOCK.MAP or STOCK.DAT")
            return nil
        }

        guard let entries = parseMAP(mapData) else {
            return nil
        }

        var plays: [StockPlay] = []
        var decoded = 0
        var failed = 0

        for entry in entries {
            if let play = parseRecord(entry: entry, datData: datData) {
                plays.append(play)
                decoded += 1
            } else {
                failed += 1
            }
        }

        print("[StockDATDecoder] Decoded \(decoded) plays (\(failed) failed) from \(entries.count) MAP entries")

        return StockDatabase(plays: plays, mapEntries: entries)
    }

    // MARK: - MAP Parser

    private static func parseMAP(_ data: Data) -> [StockMapEntry]? {
        guard data.count >= mapHeaderSize else {
            print("[StockDATDecoder] MAP file too small: \(data.count) bytes")
            return nil
        }

        let headerStr = String(bytes: data.prefix(6), encoding: .ascii) ?? ""
        guard headerStr == mapHeader else {
            print("[StockDATDecoder] Invalid MAP header: \(headerStr)")
            return nil
        }

        let entryCount = (data.count - mapHeaderSize) / mapEntrySize
        var entries: [StockMapEntry] = []

        for i in 0..<entryCount {
            let offset = mapHeaderSize + i * mapEntrySize
            guard offset + mapEntrySize <= data.count else { break }

            let dim1 = data[offset + 3]
            let dim2 = data[offset + 5]

            // Name: bytes 6-13 (8 bytes, null-padded ASCII)
            let nameStart = offset + 6
            let nameEnd = offset + 14
            let nameData = data[nameStart..<nameEnd]
            let name = String(bytes: nameData, encoding: .ascii)?
                .trimmingCharacters(in: .controlCharacters)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                .trimmingCharacters(in: .whitespaces) ?? ""

            // DAT offset: bytes 14-17 (uint32 LE)
            let datOffset = data.subdata(in: (offset + 14)..<(offset + 18))
                .withUnsafeBytes { $0.load(as: UInt32.self) }

            entries.append(StockMapEntry(
                index: i,
                name: name,
                dim1: dim1,
                dim2: dim2,
                datOffset: datOffset
            ))
        }

        return entries
    }

    // MARK: - Record Parser

    private static func parseRecord(entry: StockMapEntry, datData: Data) -> StockPlay? {
        let offset = Int(entry.datOffset)
        guard offset >= 0, offset + recordHeaderSize <= datData.count else {
            return nil
        }

        // Read header: 11 x uint16 LE offset table + 3 bytes (type, 0x00, type)
        var playerOffsets: [UInt16] = []
        for i in 0..<11 {
            let pos = offset + i * 2
            guard pos + 2 <= datData.count else { return nil }
            let value = UInt16(datData[pos]) | (UInt16(datData[pos + 1]) << 8)
            playerOffsets.append(value)
        }

        let recordTypeID = datData[offset + 22]

        // Determine category by index
        let category = categorize(index: entry.index)

        // Determine record end: find next entry's offset or use data bounds
        // For simplicity, use a generous max record size (585 bytes per spec max)
        let maxRecordEnd = min(offset + 600, datData.count)

        // Parse player entries
        var players: [StockPlayerEntry] = []
        for i in 0..<11 {
            let playerOffset = offset + Int(playerOffsets[i])
            guard playerOffset + 4 <= maxRecordEnd else { continue }

            // Determine end of this player's data
            let nextPlayerEnd: Int
            if i < 10 {
                // Find next non-equal offset
                var nextOff = maxRecordEnd
                for j in (i + 1)..<11 {
                    if playerOffsets[j] != playerOffsets[i] {
                        nextOff = offset + Int(playerOffsets[j])
                        break
                    }
                }
                nextPlayerEnd = nextOff
            } else {
                nextPlayerEnd = maxRecordEnd
            }

            if let player = parsePlayerEntry(
                data: datData,
                offset: playerOffset,
                endOffset: nextPlayerEnd
            ) {
                players.append(player)
            }
        }

        return StockPlay(
            name: entry.name,
            index: entry.index,
            category: category,
            recordTypeID: recordTypeID,
            players: players
        )
    }

    private static func categorize(index: Int) -> StockPlayCategory {
        switch index {
        case 0...21: return .offensiveFormation
        case 22...32: return .defensiveFormation
        case 33...44: return .specialTeams    // FG/PAT/kickoff offensive formations
        case 45...771: return .offensivePlay  // Offensive plays (run, pass)
        case 772...781: return .specialTeams  // Kick return / special teams defense
        case 782...1001: return .defensivePlay // Defensive plays
        default: return .offensivePlay
        }
    }

    // MARK: - Player Entry Parser

    private static func parsePlayerEntry(
        data: Data,
        offset: Int,
        endOffset: Int
    ) -> StockPlayerEntry? {
        guard offset + 4 <= endOffset else { return nil }

        let side = data[offset]
        let role = data[offset + 1]
        let positionCode = UInt16(data[offset + 2]) | (UInt16(data[offset + 3]) << 8)

        var pos = offset + 4
        var preSnap: CGPoint?
        var postSnap: CGPoint?
        var routePhase: CGPoint?
        var waypoints: [CGPoint] = []
        var motionTarget: CGPoint?
        var assignments: [StockAssignment] = []
        var hasThrow = false
        var zoneTarget: CGPoint?
        var delayTicks = 0

        // Parse node stream
        while pos + 2 <= endOffset {
            let marker = UInt16(data[pos]) | (UInt16(data[pos + 1]) << 8)

            if marker == 0x0001 || marker == 0x0002 || marker == 0x0003 {
                // Phase position node: MARKER(2) + X(2) + Y(2) + CONTINUATION(2) = 8 bytes
                guard pos + 8 <= endOffset else { break }
                let x = readInt16LE(data, at: pos + 2)
                let y = readInt16LE(data, at: pos + 4)
                let continuation = UInt16(data[pos + 6]) | (UInt16(data[pos + 7]) << 8)
                let point = CGPoint(x: CGFloat(x), y: CGFloat(y))

                switch marker {
                case 0x0001: preSnap = point
                case 0x0002: postSnap = point
                case 0x0003: routePhase = point
                default: break
                }

                pos += 8

                if continuation == 0x0000 {
                    break // End of this player's nodes
                }

                // Parse continuation chain
                while pos + 2 <= endOffset {
                    let contMarker = UInt16(data[pos]) | (UInt16(data[pos + 1]) << 8)

                    if contMarker == 0x0202 {
                        // Route waypoint: 6B or 10B
                        guard pos + 6 <= endOffset else { break }
                        let wx = readInt16LE(data, at: pos + 2)
                        let wy = readInt16LE(data, at: pos + 4)
                        waypoints.append(CGPoint(x: CGFloat(wx), y: CGFloat(wy)))

                        // Check if this is 10B (duplicated coords at end)
                        if pos + 10 <= endOffset {
                            let wx2 = readInt16LE(data, at: pos + 6)
                            let wy2 = readInt16LE(data, at: pos + 8)
                            if wx2 == wx && wy2 == wy {
                                pos += 10  // Last waypoint (10B)
                                break      // End of route
                            }
                        }
                        pos += 6  // Intermediate waypoint (6B)

                    } else if contMarker == 0x020A {
                        // Motion: 10B (always has dup coords)
                        guard pos + 10 <= endOffset else { break }
                        let mx = readInt16LE(data, at: pos + 2)
                        let my = readInt16LE(data, at: pos + 4)
                        motionTarget = CGPoint(x: CGFloat(mx), y: CGFloat(my))
                        pos += 10
                        break  // Motion ends the chain

                    } else if contMarker == 0x021B {
                        // QB Throw: 6B
                        guard pos + 6 <= endOffset else { break }
                        hasThrow = true
                        pos += 6

                    } else if contMarker == 0x0219 {
                        // Zone move: 6B
                        guard pos + 6 <= endOffset else { break }
                        let zx = readInt16LE(data, at: pos + 2)
                        let zy = readInt16LE(data, at: pos + 4)
                        zoneTarget = CGPoint(x: CGFloat(zx), y: CGFloat(zy))
                        pos += 6

                    } else if (contMarker & 0xFF00) == 0x0100 {
                        // Assignment: 4B (marker + param)
                        guard pos + 4 <= endOffset else { break }
                        let assignType = StockAssignmentType(rawMarker: contMarker)
                        let param = UInt16(data[pos + 2]) | (UInt16(data[pos + 3]) << 8)
                        assignments.append(StockAssignment(
                            type: assignType,
                            targetPlayerIndex: UInt8(param & 0xFF)
                        ))
                        pos += 4

                    } else if contMarker < 0x0040 {
                        // Delay: 2B timing
                        guard pos + 2 <= endOffset else { break }
                        delayTicks += Int(contMarker)
                        pos += 2

                    } else {
                        // Unknown continuation marker, stop parsing
                        break
                    }
                }

                break // After continuation chain, we're done with this player

            } else {
                // Not a phase marker - skip or stop
                break
            }
        }

        return StockPlayerEntry(
            side: side,
            role: role,
            positionCode: positionCode,
            preSnapPosition: preSnap,
            postSnapPosition: postSnap,
            routePhasePosition: routePhase,
            routeWaypoints: waypoints,
            motionTarget: motionTarget,
            assignments: assignments,
            hasQBThrow: hasThrow,
            zoneTarget: zoneTarget,
            delayTicks: delayTicks
        )
    }

    // MARK: - Byte Reading Helpers

    private static func readInt16LE(_ data: Data, at offset: Int) -> Int16 {
        let lo = UInt16(data[offset])
        let hi = UInt16(data[offset + 1])
        return Int16(bitPattern: lo | (hi << 8))
    }
}

// MARK: - Coordinate Conversion

extension StockDATDecoder {

    /// Convert a STOCK.DAT native coordinate to the 640x360 blueprint space.
    ///
    /// STOCK.DAT coordinate system (verified from actual data):
    ///   X = lateral position: 0 = center, positive/negative = sidelines
    ///   Y = depth: negative = behind LOS (own endzone), positive = ahead (opponent endzone)
    ///   Example: QB at (7, -244) = near center, 244 units behind LOS
    ///   Example: OL at Y=-141, X from -484 to +342 = at LOS, spread laterally
    ///
    /// Blueprint space:
    ///   X = downfield: losX = line of scrimmage, positive = toward opponent endzone
    ///   Y = lateral: centerY = center of field
    /// The stock Y depth at which the offensive line sits (acts as the LOS reference)
    private static let stockLOSDepth: CGFloat = -141

    static func convertToBlueprint(
        stockPoint: CGPoint,
        losX: CGFloat,
        centerY: CGFloat
    ) -> CGPoint {
        // Lateral: stock X -> blueprint Y. WR at stock X~1340 maps to ~110px from center.
        let lateralScale: CGFloat = 0.082
        // Depth: stock Y -> blueprint X. QB at stock Y=-244 is ~28px behind LOS.
        // Use stock Y=-141 as the LOS depth reference (where OL lines up).
        let depthScale: CGFloat = 0.27
        let relativeDepth = stockPoint.y - stockLOSDepth

        return CGPoint(
            x: losX + relativeDepth * depthScale,
            y: centerY + stockPoint.x * lateralScale
        )
    }

    /// Convert an array of STOCK.DAT waypoints to blueprint space
    static func convertWaypointsToBlueprint(
        waypoints: [CGPoint],
        losX: CGFloat,
        centerY: CGFloat
    ) -> [CGPoint] {
        waypoints.map { convertToBlueprint(stockPoint: $0, losX: losX, centerY: centerY) }
    }
}

// MARK: - Position Mapping Helpers

extension StockPlayerEntry {

    /// Map the STOCK.DAT position code to a game PlayerPosition
    var playerPosition: PlayerPosition? {
        switch positionCode {
        case 0x0012: return .center
        case 0x0011: return side == 1 ? .leftGuard : .rightGuard
        case 0x0010: return side == 1 ? .leftTackle : .rightTackle
        case 0x0020: return .quarterback
        case 0x0041: return .runningBack
        case 0x0042: return .fullback
        case 0x0080: return side == 1 ? .wideReceiverLeft : .wideReceiverRight
        case 0x0081: return .tightEnd
        default: return nil
        }
    }

    /// Map to a defensive position category
    var defensiveRole: PlayerRole {
        switch positionCode {
        case 0x0101, 0x0102: return .defensiveLine
        case 0x0200: return .linebacker
        case 0x0400: return .defensiveBack  // CB
        case 0x0401: return .defensiveBack  // S
        default: return .defensiveLine
        }
    }

    /// Whether this is an offensive lineman
    var isLineman: Bool {
        positionCode >= 0x0010 && positionCode <= 0x0012
    }

    /// Whether this is a skill position (WR, TE, RB, QB)
    var isSkillPosition: Bool {
        switch positionCode {
        case 0x0020, 0x0041, 0x0042, 0x0080, 0x0081: return true
        default: return false
        }
    }

    /// Whether this player has a blocking assignment
    var hasBlockingAssignment: Bool {
        assignments.contains { $0.type == .block || $0.type == .leadBlock }
    }

    /// Whether this player has a pass route (has route waypoints and is a pass target)
    var hasPassRoute: Bool {
        !routeWaypoints.isEmpty || assignments.contains { $0.type == .passTarget }
    }

    /// Whether this player has a rush assignment (defensive)
    var hasRushAssignment: Bool {
        assignments.contains { $0.type == .rush }
    }

    /// Whether this player has a coverage assignment (defensive)
    var hasCoverageAssignment: Bool {
        assignments.contains { $0.type == .coverage }
    }
}

// MARK: - Singleton Cache

extension StockDATDecoder {

    /// Shared singleton database (loaded lazily)
    private static var _cachedDatabase: StockDatabase?
    private static var _loadAttempted = false

    /// Get or load the shared database
    static var shared: StockDatabase? {
        if !_loadAttempted {
            _loadAttempted = true
            _cachedDatabase = loadDefault()
        }
        return _cachedDatabase
    }

    /// Force reload the database
    @discardableResult
    static func reload() -> StockDatabase? {
        _loadAttempted = true
        _cachedDatabase = loadDefault()
        return _cachedDatabase
    }
}
