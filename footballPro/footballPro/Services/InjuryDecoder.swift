//
//  InjuryDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 INJURY.DAT.
//  Format: 2-byte header + offset table (23 x 2-byte LE pointers) + null-terminated injury strings.
//  Total: 560 bytes, 33 injury types.
//

import Foundation

struct GameInjury: Equatable {
    let index: Int
    let name: String
    let severity: InjurySeverity

    enum InjurySeverity: String {
        case minor       // 1-2 weeks (sprains, soreness)
        case moderate    // 3-6 weeks (strains, fractures)
        case major       // 7-12 weeks (torn ligaments, broken bones)
        case severe      // 12+ weeks (ruptured disks, dislocated hips)
    }

    var minWeeks: Int {
        switch severity {
        case .minor: return 1
        case .moderate: return 3
        case .major: return 7
        case .severe: return 12
        }
    }

    var maxWeeks: Int {
        switch severity {
        case .minor: return 2
        case .moderate: return 6
        case .major: return 12
        case .severe: return 20
        }
    }

    var recoveryWeeks: ClosedRange<Int> {
        minWeeks...maxWeeks
    }
}

struct InjuryDecoder {
    static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")

    /// Severity classification based on injury name keywords
    private static func classifySeverity(_ name: String) -> GameInjury.InjurySeverity {
        let lower = name.lowercased()
        if lower.contains("sore") || lower.contains("mild") || lower.contains("turf toe") {
            return .minor
        }
        if lower.contains("ruptured") || lower.contains("dislocated") || lower.contains("torn") {
            return .severe
        }
        if lower.contains("broken") || lower.contains("fractured") || lower.contains("hyper") ||
           lower.contains("cartilage") {
            return .major
        }
        // sprains, strains
        return .moderate
    }

    /// Decode INJURY.DAT
    /// Structure: First 2 bytes = count/flags, then 23 x 2-byte LE offset pointers,
    /// followed by null-terminated injury name strings
    static func decode(at url: URL) throws -> [GameInjury] {
        let data = try Data(contentsOf: url)
        guard data.count >= 48 else { return [] }

        // The offset table starts at byte 2, with 23 entries of 2 bytes each = 46 bytes
        // But examining the hex, the first 4 bytes are: 2e 02 01 00
        // Then offsets start: 46 00 56 00 65 00 ...
        // These offsets (0x46=70, 0x56=86, etc.) point to where strings begin

        // Actually, looking more carefully at the hex dump:
        // Bytes 0-1: 0x022e = 558 (near file size)
        // Bytes 2-3: 0x0001
        // Bytes 4-5: 0x0046 = offset to first string "Mild concussion"
        // The string at offset 0x46 is indeed "Mild concussion"

        let headerSize = 4
        var offsets: [Int] = []

        // Read 2-byte LE offsets until we reach the first string
        var cursor = headerSize
        while cursor + 2 <= data.count {
            let offset = Int(data[cursor]) | (Int(data[cursor + 1]) << 8)
            if offset == 0 || offset >= data.count { break }
            // Check if this offset points to a printable ASCII char
            if data[offset] >= 0x20 && data[offset] <= 0x7E {
                offsets.append(offset)
            } else {
                break
            }
            cursor += 2
        }

        // Now extract null-terminated strings at each offset
        var injuries: [GameInjury] = []
        for (index, offset) in offsets.enumerated() {
            var end = offset
            while end < data.count && data[end] != 0x00 {
                end += 1
            }
            if end > offset, let name = String(data: data[offset..<end], encoding: .ascii) {
                injuries.append(GameInjury(
                    index: index,
                    name: name,
                    severity: classifySeverity(name)
                ))
            }
        }

        return injuries
    }

    /// Load injuries from default game directory
    static func loadDefault() -> [GameInjury] {
        let url = defaultDirectory.appendingPathComponent("INJURY.DAT")
        guard let injuries = try? decode(at: url), !injuries.isEmpty else {
            return []
        }
        print("[InjuryDecoder] Loaded \(injuries.count) injury types")
        return injuries
    }
}
