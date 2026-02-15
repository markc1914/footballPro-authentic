//
//  MsgDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 MSG.DAT.
//  Format: 4-byte header + 47 sequential null-terminated ASCII strings
//  containing error messages, UI prompts, and diagnostic text.
//  Total: 2,124 bytes.
//

import Foundation

struct MsgDatabase: Equatable {
    let messages: [String]

    func message(at index: Int) -> String? {
        guard index >= 0, index < messages.count else { return nil }
        return messages[index]
    }
}

struct MsgDecoder {
    static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")

    static func decode(at url: URL) throws -> MsgDatabase {
        let data = try Data(contentsOf: url)
        guard data.count >= 8 else {
            return MsgDatabase(messages: [])
        }

        // Header: 4 bytes, then a block of 2-byte LE values.
        // The first 2-byte value at offset 4 gives the start of the string data area.
        let headerSize = 4
        let stringAreaStart = Int(data[headerSize]) | (Int(data[headerSize + 1]) << 8)
        guard stringAreaStart > headerSize, stringAreaStart < data.count else {
            return MsgDatabase(messages: [])
        }

        // Read null-terminated strings sequentially from the string data area
        var messages: [String] = []
        var pos = stringAreaStart

        while pos < data.count {
            // Find end of current string (null terminator)
            var end = pos
            while end < data.count && data[end] != 0x00 {
                end += 1
            }

            if end > pos {
                // Strip leading control characters (CR, BS, etc.)
                var cleanStart = pos
                while cleanStart < end && data[cleanStart] < 0x20 {
                    cleanStart += 1
                }
                if cleanStart < end,
                   let text = String(data: data[cleanStart..<end], encoding: .ascii) {
                    // Replace embedded newlines with spaces for clean display
                    let cleaned = text.replacingOccurrences(of: "\n", with: " ")
                    messages.append(cleaned)
                }
            }

            pos = end + 1
            // Skip extra null padding between strings
            while pos < data.count && data[pos] == 0x00 {
                pos += 1
            }
        }

        return MsgDatabase(messages: messages)
    }

    static func loadDefault() -> MsgDatabase? {
        let url = defaultDirectory.appendingPathComponent("MSG.DAT")
        guard let db = try? decode(at: url), !db.messages.isEmpty else { return nil }
        print("[MsgDecoder] Loaded \(db.messages.count) messages")
        return db
    }
}
