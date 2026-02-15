//
//  PYFDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 player index files (.PYF).
//  Format: PPD: marker (4B) + uint32 LE size + uint16 LE count + sequential uint16 LE player indices.
//  Indices map into PYR file records.
//  NFLPA93.PYF: 143 indices, 8_TEAMS.PYF: 47 indices.
//

import Foundation

struct PYFIndex: Equatable {
    let playerIndices: [UInt16]
}

struct PYFDecoder {
    static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")

    static func decode(at url: URL) throws -> PYFIndex {
        let data = try Data(contentsOf: url)
        guard data.count >= 10 else {
            return PYFIndex(playerIndices: [])
        }

        // Verify PPD: marker
        let marker = String(data: data[0..<4], encoding: .ascii) ?? ""
        guard marker == "PPD:" else {
            return PYFIndex(playerIndices: [])
        }

        // Bytes 4-7: uint32 LE size (content size after header)
        // Bytes 8-9: uint16 LE count of player indices
        let count = Int(data[8]) | (Int(data[9]) << 8)
        guard count > 0 else {
            return PYFIndex(playerIndices: [])
        }

        // Read sequential uint16 LE player indices starting at byte 10
        var indices: [UInt16] = []
        var cursor = 10
        for _ in 0..<count {
            guard cursor + 2 <= data.count else { break }
            let idx = UInt16(data[cursor]) | (UInt16(data[cursor + 1]) << 8)
            indices.append(idx)
            cursor += 2
        }

        return PYFIndex(playerIndices: indices)
    }

    static func loadDefault() -> PYFIndex? {
        let url = defaultDirectory.appendingPathComponent("NFLPA93.PYF")
        guard let index = try? decode(at: url), !index.playerIndices.isEmpty else { return nil }
        print("[PYFDecoder] Loaded \(index.playerIndices.count) player indices (range: \(index.playerIndices.min() ?? 0)-\(index.playerIndices.max() ?? 0))")
        return index
    }
}
