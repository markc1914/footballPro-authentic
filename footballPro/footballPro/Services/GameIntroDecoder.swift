//
//  GameIntroDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 GAMINTRO.DAT.
//  Format: 12-byte header (offsets) + null-terminated template strings with %0-%8 placeholders.
//  Placeholders: %0=home city, %1=home mascot, %2=home coach, %3=home record,
//  %4=away city, %5=away mascot, %6=away coach, %7=away record, %8=stadium.
//

import Foundation

struct GameIntroTemplate: Equatable {
    let index: Int
    let template: String

    /// Fill template with game-specific values
    func render(homeCity: String, homeMascot: String, homeCoach: String, homeRecord: String,
                awayCity: String, awayMascot: String, awayCoach: String, awayRecord: String,
                stadium: String) -> String {
        var text = template
        text = text.replacingOccurrences(of: "%0", with: homeCity)
        text = text.replacingOccurrences(of: "%1", with: homeMascot)
        text = text.replacingOccurrences(of: "%2", with: homeCoach)
        text = text.replacingOccurrences(of: "%3", with: homeRecord)
        text = text.replacingOccurrences(of: "%4", with: awayCity)
        text = text.replacingOccurrences(of: "%5", with: awayMascot)
        text = text.replacingOccurrences(of: "%6", with: awayCoach)
        text = text.replacingOccurrences(of: "%7", with: awayRecord)
        text = text.replacingOccurrences(of: "%8", with: stadium)
        // Replace newlines encoded as 0x0A in template
        text = text.replacingOccurrences(of: "\n", with: " ")
        return text
    }
}

struct GameIntroDecoder {
    static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")

    /// Decode GAMINTRO.DAT
    /// Header: 2-byte total size + 2-byte count/flags + N x 2-byte LE offsets to template strings
    /// Each template is a null-terminated ASCII string with %0-%8 placeholders
    static func decode(at url: URL) throws -> [GameIntroTemplate] {
        let data = try Data(contentsOf: url)
        guard data.count >= 12 else { return [] }

        // Header: bytes 0-1 = file data size (0x01BC = 444)
        //         bytes 2-3 = flags (0x0001)
        //         bytes 4-5 = offset to template 1
        //         bytes 6-7 = offset to template 2, etc.
        // Read offsets until we hit the first string

        var offsets: [Int] = []
        var cursor = 4 // Skip first 4 bytes (size + flags)

        while cursor + 2 <= data.count {
            let offset = Int(data[cursor]) | (Int(data[cursor + 1]) << 8)
            if offset == 0 || offset >= data.count { break }
            // Verify it points to printable text
            if data[offset] >= 0x20 && data[offset] <= 0x7E {
                offsets.append(offset)
            } else {
                break
            }
            cursor += 2
        }

        var templates: [GameIntroTemplate] = []
        for (index, offset) in offsets.enumerated() {
            // Read null-terminated string
            var end = offset
            while end < data.count && data[end] != 0x00 {
                end += 1
            }
            if end > offset, let text = String(data: data[offset..<end], encoding: .ascii) {
                templates.append(GameIntroTemplate(index: index, template: text))
            }
        }

        return templates
    }

    /// Load templates from default game directory
    static func loadDefault() -> [GameIntroTemplate] {
        let url = defaultDirectory.appendingPathComponent("GAMINTRO.DAT")
        guard let templates = try? decode(at: url), !templates.isEmpty else {
            return []
        }
        print("[GameIntroDecoder] Loaded \(templates.count) intro templates")
        return templates
    }

    /// Get a random intro narration for a game
    static func randomIntro(homeCity: String, homeMascot: String, homeCoach: String, homeRecord: String,
                            awayCity: String, awayMascot: String, awayCoach: String, awayRecord: String,
                            stadium: String) -> String? {
        let templates = loadDefault()
        guard let template = templates.randomElement() else { return nil }
        return template.render(
            homeCity: homeCity, homeMascot: homeMascot, homeCoach: homeCoach, homeRecord: homeRecord,
            awayCity: awayCity, awayMascot: awayMascot, awayCoach: awayCoach, awayRecord: awayRecord,
            stadium: stadium
        )
    }
}
