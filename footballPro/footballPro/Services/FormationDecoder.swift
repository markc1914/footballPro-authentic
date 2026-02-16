//
//  FormationDecoder.swift
//  footballPro
//
//  Decodes STOCK.MAP formation index from FPS Football Pro '93.
//  Provides formation position lookup tables for all 22 offensive
//  and 11 defensive formations in 640×360 blueprint coordinate space.
//

import Foundation
import CoreGraphics

// MARK: - STOCK.MAP Entry

struct FormationEntry {
    let name: String
    let type: FormationType
    let dimension1: UInt8   // 9 = offense, 8 = defense, 1 = special
    let dimension2: UInt8
    let datOffset: UInt32

    enum FormationType {
        case offensive
        case defensive
        case special
        case playRoute
    }
}

// MARK: - Formation Catalog

struct FormationCatalog {
    let offensiveFormations: [FormationEntry]
    let defensiveFormations: [FormationEntry]
    let specialFormations: [FormationEntry]
    let playRouteEntries: [FormationEntry]
    let totalEntries: Int
}

// MARK: - STOCK.MAP Decoder

struct FormationDecoder {

    static let mapHeader = "ZTA:tF"
    static let entrySize = 18
    static let headerSize = 6

    /// Known base offensive formation names from STOCK.MAP
    static let baseOffensiveNames: Set<String> = [
        "3WRIFOR", "DUBLWIN", "I-FORM", "I-SLOT",
        "LONEBAC", "NEAR", "OPPOSIT", "PRO-SET",
        "SHOTGUN", "SPREAD", "TRIPWIN"
    ]

    /// Known flipped offensive formation names (F-prefix)
    static let flippedOffensiveNames: Set<String> = [
        "F3WRIFR", "FDBLWIN", "FI-FORM", "FI-SLOT",
        "FLONEBA", "FNEAR", "FOPPOSI", "FPRO-SE",
        "FSHOTGU", "FSPREAD", "FTRIPWI"
    ]

    /// Known defensive formation names
    static let defensiveNames: Set<String> = [
        "33", "34", "353", "43", "44", "46",
        "DIME", "FLEXL", "FLEXR", "GLD", "NICKEL"
    ]

    /// Decode STOCK.MAP at the given path
    static func decode(at path: String) -> FormationCatalog? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            print("[FormationDecoder] Could not read file at \(path)")
            return nil
        }

        guard data.count >= headerSize else {
            print("[FormationDecoder] File too small: \(data.count) bytes")
            return nil
        }

        // Verify header
        let headerBytes = data.prefix(6)
        let headerStr = String(bytes: headerBytes, encoding: .ascii) ?? ""
        if headerStr != mapHeader {
            print("[FormationDecoder] Invalid header: \(headerStr)")
            return nil
        }

        let entryCount = (data.count - headerSize) / entrySize

        var offensive: [FormationEntry] = []
        var defensive: [FormationEntry] = []
        var special: [FormationEntry] = []
        var playRoutes: [FormationEntry] = []

        for i in 0..<entryCount {
            let offset = headerSize + i * entrySize
            guard offset + entrySize <= data.count else { break }

            let dim1 = data[offset + 3]
            let dim2 = data[offset + 5]

            // Extract name (bytes 6-13, 8 bytes, null-padded ASCII)
            let nameStart = offset + 6
            let nameEnd = offset + 14
            let nameData = data[nameStart..<nameEnd]
            let name = String(bytes: nameData, encoding: .ascii)?
                .trimmingCharacters(in: .controlCharacters)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? ""

            // Extract DAT offset (bytes 14-17, uint32 LE)
            let datOffset = data.subdata(in: (offset + 14)..<(offset + 18))
                .withUnsafeBytes { $0.load(as: UInt32.self) }

            let type: FormationEntry.FormationType
            let trimmedName = name.trimmingCharacters(in: .whitespaces)

            if dim1 == 9 && (baseOffensiveNames.contains(trimmedName) || flippedOffensiveNames.contains(trimmedName)) {
                type = .offensive
            } else if dim1 == 8 && defensiveNames.contains(trimmedName) {
                type = .defensive
            } else if dim1 == 1 {
                type = .special
            } else {
                type = .playRoute
            }

            let entry = FormationEntry(
                name: trimmedName,
                type: type,
                dimension1: dim1,
                dimension2: dim2,
                datOffset: datOffset
            )

            switch type {
            case .offensive: offensive.append(entry)
            case .defensive: defensive.append(entry)
            case .special: special.append(entry)
            case .playRoute: playRoutes.append(entry)
            }
        }

        let catalog = FormationCatalog(
            offensiveFormations: offensive,
            defensiveFormations: defensive,
            specialFormations: special,
            playRouteEntries: playRoutes,
            totalEntries: entryCount
        )

        print("[FormationDecoder] Loaded \(entryCount) entries (\(offensive.count) offensive, \(defensive.count) defensive, \(special.count) special, \(playRoutes.count) play routes)")

        return catalog
    }

    /// Load from default game directory
    static func loadDefault() -> FormationCatalog? {
        let path = "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL/STOCK.MAP"
        return decode(at: path)
    }
}

// MARK: - Formation Positions (640×360 Blueprint Space)

/// Provides 11 CGPoints for each formation in the flat 640×360 coordinate space
/// used by PlayBlueprintGenerator and FPSFieldView.
/// All positions are relative to a given LOS X coordinate and center Y.
struct FormationPositions {

    // MARK: - Offensive Positions

    /// Returns 11 CGPoints for the given offensive formation.
    /// Order: [LT, LG, C, RG, RT, QB, RB, WR1, WR2, TE, Slot/FB]
    static func offensivePositions(for formation: OffensiveFormation, losX: CGFloat, centerY: CGFloat) -> [CGPoint] {
        // Offensive line is consistent across most formations
        let ol: [CGPoint] = [
            CGPoint(x: losX, y: centerY - 44),   // LT
            CGPoint(x: losX, y: centerY - 22),   // LG
            CGPoint(x: losX, y: centerY),         // C
            CGPoint(x: losX, y: centerY + 22),    // RG
            CGPoint(x: losX, y: centerY + 44),    // RT
        ]

        switch formation {
        case .proSet:
            // QB under center, FB offset left, RB offset right behind QB
            return ol + [
                CGPoint(x: losX - 8, y: centerY),          // QB under center
                CGPoint(x: losX - 30, y: centerY + 18),    // RB offset right
                CGPoint(x: losX + 2, y: centerY - 105),    // WR1 wide left
                CGPoint(x: losX + 2, y: centerY + 105),    // WR2 wide right
                CGPoint(x: losX, y: centerY + 52),          // TE right
                CGPoint(x: losX - 30, y: centerY - 18),    // FB offset left
            ]

        case .iFormation:
            // QB under center, FB directly behind, RB behind FB (stacked)
            return ol + [
                CGPoint(x: losX - 8, y: centerY),          // QB under center
                CGPoint(x: losX - 40, y: centerY),          // RB deep behind FB
                CGPoint(x: losX + 2, y: centerY - 105),    // WR1 wide left
                CGPoint(x: losX + 2, y: centerY + 105),    // WR2 wide right
                CGPoint(x: losX, y: centerY + 52),          // TE right
                CGPoint(x: losX - 25, y: centerY),          // FB behind QB
            ]

        case .shotgun:
            // QB 5yds back, RB beside (current default)
            return ol + [
                CGPoint(x: losX - 28, y: centerY),          // QB in shotgun
                CGPoint(x: losX - 35, y: centerY + 15),     // RB beside QB
                CGPoint(x: losX + 2, y: centerY - 105),     // WR1 wide left
                CGPoint(x: losX + 2, y: centerY + 105),     // WR2 wide right
                CGPoint(x: losX, y: centerY + 52),           // TE right
                CGPoint(x: losX + 5, y: centerY - 65),      // Slot left
            ]

        case .singleback:
            // QB under center, single RB behind
            return ol + [
                CGPoint(x: losX - 8, y: centerY),          // QB under center
                CGPoint(x: losX - 32, y: centerY),          // RB behind QB
                CGPoint(x: losX + 2, y: centerY - 105),    // WR1 wide left
                CGPoint(x: losX + 2, y: centerY + 105),    // WR2 wide right
                CGPoint(x: losX, y: centerY + 52),          // TE right
                CGPoint(x: losX + 5, y: centerY - 65),     // Slot left
            ]

        case .pistol:
            // QB in short shotgun, RB directly behind
            return ol + [
                CGPoint(x: losX - 20, y: centerY),          // QB short shotgun
                CGPoint(x: losX - 35, y: centerY),          // RB directly behind
                CGPoint(x: losX + 2, y: centerY - 105),    // WR1 wide left
                CGPoint(x: losX + 2, y: centerY + 105),    // WR2 wide right
                CGPoint(x: losX, y: centerY + 52),          // TE right
                CGPoint(x: losX + 5, y: centerY - 65),     // Slot left
            ]

        case .spread:
            // 4 WR spread wide, 1 RB, shotgun QB
            return ol + [
                CGPoint(x: losX - 28, y: centerY),          // QB in shotgun
                CGPoint(x: losX - 35, y: centerY + 12),     // RB beside QB
                CGPoint(x: losX + 2, y: centerY - 115),    // WR1 wide left
                CGPoint(x: losX + 2, y: centerY + 115),    // WR2 wide right
                CGPoint(x: losX + 5, y: centerY + 65),     // Slot right (no TE)
                CGPoint(x: losX + 5, y: centerY - 65),     // Slot left
            ]

        case .emptySet:
            // No backs, 5 receivers
            return ol + [
                CGPoint(x: losX - 28, y: centerY),          // QB in shotgun
                CGPoint(x: losX + 5, y: centerY + 75),     // Slot right (was RB)
                CGPoint(x: losX + 2, y: centerY - 115),    // WR1 wide left
                CGPoint(x: losX + 2, y: centerY + 115),    // WR2 wide right
                CGPoint(x: losX, y: centerY + 52),          // TE right
                CGPoint(x: losX + 5, y: centerY - 65),     // Slot left
            ]

        case .goalLine:
            // Heavy formation, QB under center, FB+RB tight, extra TE
            return ol + [
                CGPoint(x: losX - 8, y: centerY),          // QB under center
                CGPoint(x: losX - 25, y: centerY + 10),    // RB close
                CGPoint(x: losX + 2, y: centerY - 80),     // WR1 (tighter)
                CGPoint(x: losX + 2, y: centerY + 80),     // WR2 (tighter)
                CGPoint(x: losX, y: centerY + 52),          // TE right
                CGPoint(x: losX - 18, y: centerY - 10),    // FB close
            ]

        case .jumbo:
            // Extra linemen, very tight formation
            return ol + [
                CGPoint(x: losX - 8, y: centerY),          // QB under center
                CGPoint(x: losX - 25, y: centerY),          // RB behind
                CGPoint(x: losX + 2, y: centerY - 80),     // WR1
                CGPoint(x: losX + 2, y: centerY + 80),     // WR2
                CGPoint(x: losX, y: centerY + 52),          // TE right
                CGPoint(x: losX, y: centerY - 52),          // TE left (extra)
            ]

        case .trips:
            // 3 WR on one side (right), TE on left
            return ol + [
                CGPoint(x: losX - 28, y: centerY),          // QB shotgun
                CGPoint(x: losX - 35, y: centerY + 12),     // RB beside
                CGPoint(x: losX + 2, y: centerY - 105),    // WR1 wide left (iso)
                CGPoint(x: losX + 2, y: centerY + 105),    // WR2 wide right
                CGPoint(x: losX, y: centerY - 52),          // TE left
                CGPoint(x: losX + 5, y: centerY + 70),     // Slot right (trips)
            ]

        case .nearFormation:
            // Strong-side overload: TE, FB, and flanker to one side
            return ol + [
                CGPoint(x: losX - 8, y: centerY),          // QB under center
                CGPoint(x: losX - 30, y: centerY + 15),    // RB offset strong
                CGPoint(x: losX + 2, y: centerY - 105),    // WR1 wide left (weak)
                CGPoint(x: losX + 2, y: centerY + 90),     // WR2 flanker strong
                CGPoint(x: losX, y: centerY + 52),          // TE strong side
                CGPoint(x: losX - 22, y: centerY + 25),    // FB strong side
            ]

        case .doubleWing:
            // Two wingbacks flanking TE, QB under center
            return ol + [
                CGPoint(x: losX - 8, y: centerY),          // QB under center
                CGPoint(x: losX - 30, y: centerY),          // RB deep
                CGPoint(x: losX + 2, y: centerY - 105),    // WR1 wide left
                CGPoint(x: losX + 2, y: centerY + 105),    // WR2 wide right
                CGPoint(x: losX, y: centerY + 52),          // TE right
                CGPoint(x: losX - 5, y: centerY - 55),     // Wingback left
            ]

        case .iSlot:
            // I-Formation with a slot receiver instead of flanker
            return ol + [
                CGPoint(x: losX - 8, y: centerY),          // QB under center
                CGPoint(x: losX - 40, y: centerY),          // RB deep (I-form)
                CGPoint(x: losX + 2, y: centerY - 105),    // WR1 wide left
                CGPoint(x: losX + 2, y: centerY + 105),    // WR2 wide right
                CGPoint(x: losX, y: centerY + 52),          // TE right
                CGPoint(x: losX - 25, y: centerY),          // FB (I-form)
            ]

        case .loneBack:
            // Single back 7yds deep, 3WR
            return ol + [
                CGPoint(x: losX - 8, y: centerY),          // QB under center
                CGPoint(x: losX - 42, y: centerY),          // RB very deep
                CGPoint(x: losX + 2, y: centerY - 105),    // WR1 wide left
                CGPoint(x: losX + 2, y: centerY + 105),    // WR2 wide right
                CGPoint(x: losX, y: centerY + 52),          // TE right
                CGPoint(x: losX + 5, y: centerY - 65),     // Slot left
            ]
        }
    }

    // MARK: - Defensive Positions

    /// Returns 11 CGPoints for the given defensive formation.
    /// Order: [DL0, DL1, DL2, DL3, LB0, LB1, LB2, CB0, CB1, S0, S1]
    static func defensivePositions(for formation: DefensiveFormation, losX: CGFloat, centerY: CGFloat) -> [CGPoint] {
        switch formation {
        case .base43:
            // 4 DL, 3 LB
            return [
                CGPoint(x: losX + 12, y: centerY - 39),    // LE
                CGPoint(x: losX + 12, y: centerY - 13),    // DT
                CGPoint(x: losX + 12, y: centerY + 13),    // DT
                CGPoint(x: losX + 12, y: centerY + 39),    // RE
                CGPoint(x: losX + 38, y: centerY - 42),    // SAM
                CGPoint(x: losX + 38, y: centerY),          // MIKE
                CGPoint(x: losX + 38, y: centerY + 42),    // WILL
                CGPoint(x: losX + 55, y: centerY - 95),    // LCB
                CGPoint(x: losX + 55, y: centerY + 95),    // RCB
                CGPoint(x: losX + 80, y: centerY - 40),    // FS
                CGPoint(x: losX + 80, y: centerY + 40),    // SS
            ]

        case .base34:
            // 3 DL, 4 LB
            return [
                CGPoint(x: losX + 12, y: centerY - 30),    // LE
                CGPoint(x: losX + 12, y: centerY),          // NT
                CGPoint(x: losX + 12, y: centerY + 30),    // RE
                CGPoint(x: losX + 12, y: centerY + 50),    // OLB (rush end, on line)
                CGPoint(x: losX + 32, y: centerY - 50),    // LOLB
                CGPoint(x: losX + 32, y: centerY - 15),    // ILB
                CGPoint(x: losX + 32, y: centerY + 15),    // ILB
                CGPoint(x: losX + 55, y: centerY - 95),    // LCB
                CGPoint(x: losX + 55, y: centerY + 95),    // RCB
                CGPoint(x: losX + 80, y: centerY - 40),    // FS
                CGPoint(x: losX + 80, y: centerY + 40),    // SS
            ]

        case .nickel:
            // 4 DL, 2 LB, 5 DB (extra slot corner)
            return [
                CGPoint(x: losX + 12, y: centerY - 39),    // LE
                CGPoint(x: losX + 12, y: centerY - 13),    // DT
                CGPoint(x: losX + 12, y: centerY + 13),    // DT
                CGPoint(x: losX + 12, y: centerY + 39),    // RE
                CGPoint(x: losX + 35, y: centerY - 20),    // LB
                CGPoint(x: losX + 35, y: centerY + 20),    // LB
                CGPoint(x: losX + 50, y: centerY - 65),    // Nickel CB (slot)
                CGPoint(x: losX + 55, y: centerY - 100),   // LCB
                CGPoint(x: losX + 55, y: centerY + 100),   // RCB
                CGPoint(x: losX + 80, y: centerY - 40),    // FS
                CGPoint(x: losX + 80, y: centerY + 40),    // SS
            ]

        case .dime:
            // 4 DL, 1 LB, 6 DB
            return [
                CGPoint(x: losX + 12, y: centerY - 39),    // LE
                CGPoint(x: losX + 12, y: centerY - 13),    // DT
                CGPoint(x: losX + 12, y: centerY + 13),    // DT
                CGPoint(x: losX + 12, y: centerY + 39),    // RE
                CGPoint(x: losX + 35, y: centerY),          // LB (solo)
                CGPoint(x: losX + 50, y: centerY - 65),    // Nickel CB
                CGPoint(x: losX + 50, y: centerY + 65),    // Dime CB
                CGPoint(x: losX + 55, y: centerY - 100),   // LCB
                CGPoint(x: losX + 55, y: centerY + 100),   // RCB
                CGPoint(x: losX + 80, y: centerY - 40),    // FS
                CGPoint(x: losX + 80, y: centerY + 40),    // SS
            ]

        case .goalLine:
            // Heavy run defense: 5 DL, 3 LB, 3 DB
            return [
                CGPoint(x: losX + 10, y: centerY - 44),    // LE
                CGPoint(x: losX + 10, y: centerY - 22),    // DT
                CGPoint(x: losX + 10, y: centerY),          // NT
                CGPoint(x: losX + 10, y: centerY + 22),    // DT
                CGPoint(x: losX + 25, y: centerY - 35),    // LB
                CGPoint(x: losX + 25, y: centerY),          // LB
                CGPoint(x: losX + 25, y: centerY + 35),    // LB
                CGPoint(x: losX + 40, y: centerY - 70),    // CB
                CGPoint(x: losX + 40, y: centerY + 70),    // CB
                CGPoint(x: losX + 55, y: centerY - 25),    // S
                CGPoint(x: losX + 55, y: centerY + 25),    // S
            ]

        case .prevent:
            // Deep coverage: 3 DL, 1 LB, 7 DB-depth positioning
            return [
                CGPoint(x: losX + 12, y: centerY - 26),    // LE
                CGPoint(x: losX + 12, y: centerY),          // NT
                CGPoint(x: losX + 12, y: centerY + 26),    // RE
                CGPoint(x: losX + 30, y: centerY),          // LB (solo contain)
                CGPoint(x: losX + 55, y: centerY - 70),    // DB
                CGPoint(x: losX + 55, y: centerY + 70),    // DB
                CGPoint(x: losX + 75, y: centerY),          // DB (deep middle)
                CGPoint(x: losX + 60, y: centerY - 110),   // LCB (press off)
                CGPoint(x: losX + 60, y: centerY + 110),   // RCB (press off)
                CGPoint(x: losX + 95, y: centerY - 50),    // FS (deep)
                CGPoint(x: losX + 95, y: centerY + 50),    // SS (deep)
            ]

        case .base46:
            // 46 defense: 4 DL crowding gaps, 3 LB stacked, aggressive
            return [
                CGPoint(x: losX + 10, y: centerY - 35),    // LE
                CGPoint(x: losX + 10, y: centerY - 11),    // DT
                CGPoint(x: losX + 10, y: centerY + 11),    // DT
                CGPoint(x: losX + 10, y: centerY + 35),    // RE
                CGPoint(x: losX + 25, y: centerY - 30),    // LB (up close)
                CGPoint(x: losX + 25, y: centerY),          // LB (up close)
                CGPoint(x: losX + 25, y: centerY + 30),    // LB (up close)
                CGPoint(x: losX + 50, y: centerY - 95),    // LCB
                CGPoint(x: losX + 50, y: centerY + 95),    // RCB
                CGPoint(x: losX + 70, y: centerY - 35),    // FS
                CGPoint(x: losX + 70, y: centerY + 35),    // SS (in the box)
            ]

        case .base33:
            // 3-3 stack: 3 DL, 3 LB stacked behind, 5 DB
            return [
                CGPoint(x: losX + 12, y: centerY - 26),    // LE
                CGPoint(x: losX + 12, y: centerY),          // NT
                CGPoint(x: losX + 12, y: centerY + 26),    // RE
                CGPoint(x: losX + 30, y: centerY - 26),    // LB
                CGPoint(x: losX + 30, y: centerY),          // LB
                CGPoint(x: losX + 30, y: centerY + 26),    // LB
                CGPoint(x: losX + 50, y: centerY - 65),    // Nickel CB
                CGPoint(x: losX + 55, y: centerY - 100),   // LCB
                CGPoint(x: losX + 55, y: centerY + 100),   // RCB
                CGPoint(x: losX + 80, y: centerY - 40),    // FS
                CGPoint(x: losX + 80, y: centerY + 40),    // SS
            ]

        case .base44:
            // 4-4 stack: 4 DL, 4 LB, 3 DB
            return [
                CGPoint(x: losX + 10, y: centerY - 35),    // LE
                CGPoint(x: losX + 10, y: centerY - 11),    // DT
                CGPoint(x: losX + 10, y: centerY + 11),    // DT
                CGPoint(x: losX + 10, y: centerY + 35),    // RE
                CGPoint(x: losX + 28, y: centerY - 42),    // OLB
                CGPoint(x: losX + 28, y: centerY - 14),    // ILB
                CGPoint(x: losX + 28, y: centerY + 14),    // ILB
                CGPoint(x: losX + 50, y: centerY - 90),    // LCB
                CGPoint(x: losX + 50, y: centerY + 90),    // RCB
                CGPoint(x: losX + 70, y: centerY - 30),    // FS
                CGPoint(x: losX + 70, y: centerY + 30),    // SS
            ]

        case .flex:
            // Flex defense: DL staggered depths, one end dropped back
            return [
                CGPoint(x: losX + 12, y: centerY - 35),    // LE (on line)
                CGPoint(x: losX + 12, y: centerY - 11),    // DT (on line)
                CGPoint(x: losX + 18, y: centerY + 11),    // DT (flexed back)
                CGPoint(x: losX + 18, y: centerY + 35),    // RE (flexed back)
                CGPoint(x: losX + 36, y: centerY - 42),    // SAM
                CGPoint(x: losX + 36, y: centerY),          // MIKE
                CGPoint(x: losX + 36, y: centerY + 42),    // WILL
                CGPoint(x: losX + 55, y: centerY - 95),    // LCB
                CGPoint(x: losX + 55, y: centerY + 95),    // RCB
                CGPoint(x: losX + 80, y: centerY - 40),    // FS
                CGPoint(x: losX + 80, y: centerY + 40),    // SS
            ]

        case .goalLineDef:
            // Heavy goal line defense: everyone up close
            return [
                CGPoint(x: losX + 8, y: centerY - 40),     // LE
                CGPoint(x: losX + 8, y: centerY - 18),     // DT
                CGPoint(x: losX + 8, y: centerY),           // NT
                CGPoint(x: losX + 8, y: centerY + 18),     // DT
                CGPoint(x: losX + 20, y: centerY - 30),    // LB
                CGPoint(x: losX + 20, y: centerY),          // LB
                CGPoint(x: losX + 20, y: centerY + 30),    // LB
                CGPoint(x: losX + 35, y: centerY - 60),    // CB
                CGPoint(x: losX + 35, y: centerY + 60),    // CB
                CGPoint(x: losX + 45, y: centerY - 20),    // S
                CGPoint(x: losX + 45, y: centerY + 20),    // S
            ]
        }
    }

    // MARK: - Player Roles for Formations

    /// Returns the PlayerRole array for an offensive formation (11 roles).
    /// Order matches the position array.
    static func offensiveRoles(for formation: OffensiveFormation) -> [PlayerRole] {
        switch formation {
        case .proSet, .nearFormation:
            return [.lineman, .lineman, .lineman, .lineman, .lineman,
                    .quarterback, .runningback, .receiver, .receiver, .tightend, .runningback]
        case .iFormation, .iSlot:
            return [.lineman, .lineman, .lineman, .lineman, .lineman,
                    .quarterback, .runningback, .receiver, .receiver, .tightend, .runningback]
        case .spread, .emptySet:
            return [.lineman, .lineman, .lineman, .lineman, .lineman,
                    .quarterback, .runningback, .receiver, .receiver, .receiver, .receiver]
        default:
            return [.lineman, .lineman, .lineman, .lineman, .lineman,
                    .quarterback, .runningback, .receiver, .receiver, .tightend, .receiver]
        }
    }

    /// Returns the PlayerRole array for a defensive formation (11 roles).
    static func defensiveRoles(for formation: DefensiveFormation) -> [PlayerRole] {
        switch formation {
        case .base43, .base46, .flex:
            return [.defensiveLine, .defensiveLine, .defensiveLine, .defensiveLine,
                    .linebacker, .linebacker, .linebacker,
                    .defensiveBack, .defensiveBack, .defensiveBack, .defensiveBack]
        case .base34:
            return [.defensiveLine, .defensiveLine, .defensiveLine, .defensiveLine,
                    .linebacker, .linebacker, .linebacker,
                    .defensiveBack, .defensiveBack, .defensiveBack, .defensiveBack]
        case .nickel, .base33:
            return [.defensiveLine, .defensiveLine, .defensiveLine, .defensiveLine,
                    .linebacker, .linebacker, .defensiveBack,
                    .defensiveBack, .defensiveBack, .defensiveBack, .defensiveBack]
        case .dime:
            return [.defensiveLine, .defensiveLine, .defensiveLine, .defensiveLine,
                    .linebacker, .defensiveBack, .defensiveBack,
                    .defensiveBack, .defensiveBack, .defensiveBack, .defensiveBack]
        case .goalLine, .base44, .goalLineDef:
            return [.defensiveLine, .defensiveLine, .defensiveLine, .defensiveLine,
                    .linebacker, .linebacker, .linebacker,
                    .defensiveBack, .defensiveBack, .defensiveBack, .defensiveBack]
        case .prevent:
            return [.defensiveLine, .defensiveLine, .defensiveLine, .linebacker,
                    .defensiveBack, .defensiveBack, .defensiveBack,
                    .defensiveBack, .defensiveBack, .defensiveBack, .defensiveBack]
        }
    }
}
