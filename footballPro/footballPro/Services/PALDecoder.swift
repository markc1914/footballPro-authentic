//
//  PALDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 VGA palette files (.PAL).
//  Format: Magic "PAL:" (8B) + "VGA:" (8B) + 256 RGB triplets (6-bit values 0-63).
//  Each value multiplied by 4 gives 8-bit RGB. Total: 784 bytes.
//

import Foundation
import SwiftUI

struct PaletteColor: Equatable {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

struct VGAPalette: Equatable {
    let colors: [PaletteColor]

    var count: Int { colors.count }

    func color(at index: Int) -> Color {
        guard index >= 0 && index < colors.count else { return .black }
        let c = colors[index]
        return Color(
            .sRGB,
            red: Double(c.r) / 255.0,
            green: Double(c.g) / 255.0,
            blue: Double(c.b) / 255.0
        )
    }

    func nsColor(at index: Int) -> NSColor {
        guard index >= 0 && index < colors.count else { return .black }
        let c = colors[index]
        return NSColor(
            srgbRed: CGFloat(c.r) / 255.0,
            green: CGFloat(c.g) / 255.0,
            blue: CGFloat(c.b) / 255.0,
            alpha: 1.0
        )
    }
}

struct PALDecoder {
    static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")

    static let headerSize = 16 // "PAL:" (8B) + "VGA:" (8B)
    static let paletteEntries = 256
    static let expectedFileSize = headerSize + (paletteEntries * 3) // 784

    /// Decode a .PAL file
    /// Header: PAL: (4B magic + 4B flags) + VGA: (4B magic + 4B flags)
    /// Data: 256 x 3 bytes (R, G, B in 6-bit VGA values 0-63)
    static func decode(at url: URL) throws -> VGAPalette {
        let data = try Data(contentsOf: url)
        guard data.count >= expectedFileSize else {
            print("[PALDecoder] File too small: \(data.count) bytes, expected \(expectedFileSize)")
            return VGAPalette(colors: [])
        }

        var colors: [PaletteColor] = []
        colors.reserveCapacity(paletteEntries)

        for i in 0..<paletteEntries {
            let offset = headerSize + (i * 3)
            // VGA 6-bit values (0-63), multiply by 4 to get 8-bit (0-252)
            let r = min(data[offset] * 4, 255)
            let g = min(data[offset + 1] * 4, 255)
            let b = min(data[offset + 2] * 4, 255)
            colors.append(PaletteColor(r: r, g: g, b: b))
        }

        return VGAPalette(colors: colors)
    }

    /// Load a named palette from default directory
    static func loadPalette(named filename: String) -> VGAPalette? {
        let url = defaultDirectory.appendingPathComponent(filename)
        guard let palette = try? decode(at: url) else { return nil }
        print("[PALDecoder] Loaded \(filename): \(palette.count) colors")
        return palette
    }

    /// Load all available palettes
    static func loadAllPalettes() -> [String: VGAPalette] {
        let palFiles = ["DYNAMIX.PAL", "GAMINTRO.PAL", "CHAMP.PAL", "INTRO.PAL",
                        "MU1.PAL", "MU2.PAL", "PICKER.PAL", "INTROPT1.PAL", "INTROPT2.PAL"]
        var palettes: [String: VGAPalette] = [:]

        for file in palFiles {
            if let palette = loadPalette(named: file) {
                palettes[file] = palette
            }
        }

        print("[PALDecoder] Loaded \(palettes.count) palettes")
        return palettes
    }
}
