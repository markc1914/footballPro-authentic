//
//  PYRDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 player roster files (.PYR).
//  Format: Sequential 51-byte player records with no file header.
//  Record layout:
//    Bytes 0-1:   Player index (uint16 LE)
//    Bytes 2-5:   Reserved (zeros)
//    Bytes 6-21:  Ratings (16 raw bytes, values ~30-99)
//    Byte  22:    Experience/years indicator
//    Byte  23:    Position group code
//    Byte  24:    Position code (maps to football position)
//    Bytes 25-37: First name (13 bytes, null-padded ASCII)
//    Bytes 38-50: Last name (13 bytes, null-padded ASCII)
//

import Foundation

// MARK: - FPS Ratings (8 paired attributes from original game)

/// The 8 core ratings from FPS Football Pro '93.
/// Each player has potential (ceiling) and current (actual) versions.
struct FPSRatings: Equatable {
    var speed: Int          // SP — raw foot speed
    var acceleration: Int   // AC — burst/quickness
    var endurance: Int      // EN — stamina/conditioning
    var strength: Int       // ST — physical power
    var hands: Int          // HA — ball handling/catching
    var intelligence: Int   // IN — football IQ/awareness
    var agility: Int        // AG — change of direction
    var discipline: Int     // DI — consistency/technique

    init(bytes: [UInt8]) {
        speed        = Int(bytes.count > 0 ? bytes[0] : 50)
        acceleration = Int(bytes.count > 1 ? bytes[1] : 50)
        endurance    = Int(bytes.count > 2 ? bytes[2] : 50)
        strength     = Int(bytes.count > 3 ? bytes[3] : 50)
        hands        = Int(bytes.count > 4 ? bytes[4] : 50)
        intelligence = Int(bytes.count > 5 ? bytes[5] : 50)
        agility      = Int(bytes.count > 6 ? bytes[6] : 50)
        discipline   = Int(bytes.count > 7 ? bytes[7] : 50)
    }
}

// MARK: - PYR Data Types

struct PYRPlayer: Equatable {
    let fileIndex: Int       // Sequential index in PYR file (0-based)
    let playerIndex: Int     // Index stored in record (used by LGE roster references)
    let firstName: String
    let lastName: String
    let positionCode: UInt8  // Raw position byte
    let positionGroup: UInt8 // Raw position group byte
    let experienceCode: UInt8
    let potentialRatings: FPSRatings  // Bytes 6-13: ceiling ratings
    let currentRatings: FPSRatings    // Bytes 14-21: actual ratings

    var fullName: String { "\(firstName) \(lastName)" }

    var position: Position {
        PYRDecoder.mapPosition(code: positionCode)
    }

    /// Convert current FPS ratings to the 31-field PlayerRatings struct
    func toPlayerRatings() -> PlayerRatings {
        let c = currentRatings

        return PlayerRatings(
            speed: c.speed,
            strength: c.strength,
            agility: c.agility,
            stamina: c.endurance,
            awareness: c.intelligence,
            toughness: c.discipline,
            throwPower: c.strength,
            throwAccuracyShort: (c.hands + c.intelligence) / 2,
            throwAccuracyMid: (c.hands + c.intelligence) / 2,
            throwAccuracyDeep: (c.hands + c.intelligence * 2) / 3,
            playAction: (c.intelligence + c.discipline) / 2,
            carrying: c.hands,
            breakTackle: (c.strength + c.agility) / 2,
            trucking: c.strength,
            elusiveness: c.agility,
            ballCarrierVision: c.intelligence,
            catching: c.hands,
            catchInTraffic: (c.hands + c.discipline) / 2,
            spectacularCatch: (c.hands + c.agility) / 2,
            routeRunning: (c.agility + c.intelligence) / 2,
            release: (c.speed + c.agility) / 2,
            runBlock: (c.strength + c.intelligence) / 2,
            passBlock: (c.strength + c.intelligence) / 2,
            impactBlock: c.strength,
            tackle: (c.strength + c.agility) / 2,
            hitPower: c.strength,
            pursuit: (c.speed + c.intelligence) / 2,
            playRecognition: c.intelligence,
            manCoverage: (c.speed + c.intelligence) / 2,
            zoneCoverage: (c.intelligence + c.discipline) / 2,
            press: (c.strength + c.agility) / 2,
            blockShedding: (c.strength + c.agility) / 2,
            passRush: (c.speed + c.strength) / 2,
            kickPower: c.strength,
            kickAccuracy: c.discipline
        )
    }

    /// Generate a full Player model from PYR data
    func toPlayer(jerseyNumber: Int = 0) -> Player {
        let pos = position
        let ratings = toPlayerRatings()
        let experience = Int(experienceCode)
        let age = 22 + experience

        let (height, weight) = PYRDecoder.physicals(for: pos)

        return Player(
            firstName: firstName,
            lastName: lastName,
            position: pos,
            age: age,
            height: height,
            weight: weight,
            college: "Unknown",
            experience: experience,
            jerseyNumber: jerseyNumber,
            ratings: ratings,
            contract: Contract.veteran(rating: ratings.overall, position: pos)
        )
    }
}

struct PYRFile: Equatable {
    let sourceURL: URL
    let players: [PYRPlayer]

    /// Look up a player by their stored index
    func player(byIndex index: Int) -> PYRPlayer? {
        players.first { $0.playerIndex == index }
    }

    /// Get players by a list of indices (from LGE roster references)
    func players(byIndices indices: [Int]) -> [PYRPlayer] {
        indices.compactMap { player(byIndex: $0) }
    }
}

// MARK: - Decoder

struct PYRDecoder {
    static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")

    static let recordSize = 51
    static let indexOffset = 0
    static let ratingsOffset = 6
    static let ratingsLength = 16
    static let experienceOffset = 22
    static let posGroupOffset = 23
    static let posCodeOffset = 24
    static let firstNameOffset = 25
    static let lastNameOffset = 38
    static let nameLength = 13

    /// Position code mapping (byte 24 of each record)
    /// Decoded from known NFL players in NFLPA93.PYR
    static let positionMap: [UInt8: Position] = [
        0x00: .quarterback,       // QB
        0x01: .fullback,           // FB
        0x02: .runningBack,        // RB
        0x03: .tightEnd,           // TE
        0x04: .wideReceiver,       // WR
        0x05: .center,             // C
        0x06: .leftGuard,          // OG (mapped to LG)
        0x07: .leftTackle,         // OT (mapped to LT)
        0x08: .defensiveEnd,       // DE
        0x09: .defensiveTackle,    // DT
        0x0A: .outsideLinebacker,  // LB (mapped to OLB)
        0x0B: .cornerback,         // CB
        0x0C: .freeSafety,         // S (mapped to FS)
        0x0D: .kicker,             // K
        0x0E: .punter,             // P
    ]

    static func mapPosition(code: UInt8) -> Position {
        positionMap[code] ?? .runningBack
    }

    static func decode(at url: URL) throws -> PYRFile {
        let data = try Data(contentsOf: url)
        let totalRecords = data.count / recordSize
        var players: [PYRPlayer] = []
        players.reserveCapacity(totalRecords)

        for i in 0..<totalRecords {
            let base = i * recordSize
            guard base + recordSize <= data.count else { break }

            let playerIndex = Int(data[base]) | (Int(data[base + 1]) << 8)

            // Extract 8 paired ratings: potential (bytes 6-13), current (bytes 14-21)
            var potentialBytes: [UInt8] = []
            var currentBytes: [UInt8] = []
            for j in 0..<8 {
                potentialBytes.append(data[base + ratingsOffset + j])
            }
            for j in 0..<8 {
                currentBytes.append(data[base + ratingsOffset + 8 + j])
            }

            let experience = data[base + experienceOffset]
            let posGroup = data[base + posGroupOffset]
            let posCode = data[base + posCodeOffset]

            let firstName = extractName(from: data, at: base + firstNameOffset)
            let lastName = extractName(from: data, at: base + lastNameOffset)

            // Skip records with empty names (padding at end of file)
            guard !firstName.isEmpty || !lastName.isEmpty else { continue }

            players.append(PYRPlayer(
                fileIndex: i,
                playerIndex: playerIndex,
                firstName: firstName,
                lastName: lastName,
                positionCode: posCode,
                positionGroup: posGroup,
                experienceCode: experience,
                potentialRatings: FPSRatings(bytes: potentialBytes),
                currentRatings: FPSRatings(bytes: currentBytes)
            ))
        }

        return PYRFile(sourceURL: url, players: players)
    }

    /// Load the default NFLPA93 roster file
    static func loadDefault() -> PYRFile? {
        let url = defaultDirectory.appendingPathComponent("NFLPA93.PYR")
        guard let file = try? decode(at: url) else { return nil }
        print("[PYRDecoder] Loaded \(file.players.count) players from NFLPA93.PYR")

        // Print position distribution
        var posCounts: [Position: Int] = [:]
        for p in file.players {
            posCounts[p.position, default: 0] += 1
        }
        for (pos, count) in posCounts.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            print("  \(pos.rawValue): \(count)")
        }

        return file
    }

    /// Build a complete team roster from LGE team data + PYR player data
    static func buildTeamRoster(lgeTeam: LGETeam, pyrFile: PYRFile) -> [Player] {
        let pyrPlayers = pyrFile.players(byIndices: lgeTeam.rosterPlayerIndices)
        return pyrPlayers.enumerated().map { index, pyrPlayer in
            let jersey = index < lgeTeam.jerseyNumbers.count ? lgeTeam.jerseyNumbers[index] : 0
            return pyrPlayer.toPlayer(jerseyNumber: jersey)
        }
    }

    // MARK: - Private Helpers

    private static func extractName(from data: Data, at offset: Int) -> String {
        guard offset >= 0 && offset + nameLength <= data.count else { return "" }
        let slice = data[offset..<(offset + nameLength)]
        let trimmed = slice.prefix { $0 != 0x00 }
        return String(bytes: trimmed, encoding: .ascii) ?? ""
    }

    /// Generate reasonable physical attributes for a position
    static func physicals(for position: Position) -> (height: Int, weight: Int) {
        switch position {
        case .quarterback: return (Int.random(in: 73...77), Int.random(in: 210...240))
        case .runningBack: return (Int.random(in: 68...72), Int.random(in: 195...225))
        case .fullback: return (Int.random(in: 70...74), Int.random(in: 240...260))
        case .wideReceiver: return (Int.random(in: 69...76), Int.random(in: 175...215))
        case .tightEnd: return (Int.random(in: 75...79), Int.random(in: 245...265))
        case .leftTackle, .rightTackle: return (Int.random(in: 76...80), Int.random(in: 305...335))
        case .leftGuard, .rightGuard: return (Int.random(in: 74...78), Int.random(in: 305...330))
        case .center: return (Int.random(in: 73...77), Int.random(in: 295...320))
        case .defensiveEnd: return (Int.random(in: 74...78), Int.random(in: 255...285))
        case .defensiveTackle: return (Int.random(in: 73...77), Int.random(in: 295...330))
        case .outsideLinebacker: return (Int.random(in: 73...77), Int.random(in: 235...260))
        case .middleLinebacker: return (Int.random(in: 72...76), Int.random(in: 240...255))
        case .cornerback: return (Int.random(in: 69...74), Int.random(in: 185...205))
        case .freeSafety: return (Int.random(in: 70...74), Int.random(in: 195...215))
        case .strongSafety: return (Int.random(in: 71...75), Int.random(in: 205...220))
        case .kicker: return (Int.random(in: 70...74), Int.random(in: 185...210))
        case .punter: return (Int.random(in: 72...76), Int.random(in: 200...225))
        }
    }
}

// Uses Array subscript(safe:) extension from NavigationBar.swift
