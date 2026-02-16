//
//  MagazineDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 MAGAZINE.DAT.
//  Format: MAG: marker (4B) + uint32 LE size + space-separated month names (null-terminated)
//  + "Page" (null-terminated) + "Front Page Sports: Football Pro" (null-terminated) + layout bytes.
//  Total: 146 bytes.
//

import Foundation

struct MagazineData: Equatable {
    let monthNames: [String]  // 12 month names
    let pageLabel: String     // "Page"
    let titleText: String     // "Front Page Sports: Football Pro"
}

struct MagazineDecoder {
    static let defaultDirectory = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")

    static func decode(at url: URL) throws -> MagazineData {
        let data = try Data(contentsOf: url)
        guard data.count >= 8 else {
            throw DecoderError.fileTooSmall
        }

        // Verify MAG: marker
        let marker = String(data: data[0..<4], encoding: .ascii) ?? ""
        guard marker == "MAG:" else {
            throw DecoderError.invalidMarker
        }

        let contentStart = 8
        var strings: [String] = []
        var pos = contentStart

        // Read null-terminated strings
        while pos < data.count {
            var end = pos
            while end < data.count && data[end] != 0x00 {
                end += 1
            }
            if end > pos, let str = String(data: data[pos..<end], encoding: .ascii) {
                strings.append(str)
            }
            pos = end + 1
            // Stop after 3 strings (months, page label, title)
            if strings.count >= 3 { break }
        }

        // First string is space-separated month names
        let monthNames = strings.count > 0 ? strings[0].components(separatedBy: " ") : []
        let pageLabel = strings.count > 1 ? strings[1] : "Page"
        let titleText = strings.count > 2 ? strings[2] : "Front Page Sports: Football Pro"

        return MagazineData(
            monthNames: monthNames,
            pageLabel: pageLabel,
            titleText: titleText
        )
    }

    static func loadDefault() -> MagazineData? {
        let url = defaultDirectory.appendingPathComponent("MAGAZINE.DAT")
        guard let magazine = try? decode(at: url) else { return nil }
        print("[MagazineDecoder] Loaded: \(magazine.titleText) (\(magazine.monthNames.count) months)")
        return magazine
    }

    enum DecoderError: Error {
        case fileTooSmall
        case invalidMarker
    }
}
