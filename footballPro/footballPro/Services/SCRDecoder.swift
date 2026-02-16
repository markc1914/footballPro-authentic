//
//  SCRDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 screen graphics (.SCR).
//  Format decoded from DGDS engine: container "SCR:" -> child sections.
//  BIN section stores low nibbles, VGA section stores high nibbles. Pixels are 4-bit palette indices.
//

import Foundation
import AppKit
import CoreGraphics

struct SCRImage: Equatable {
    let width: Int
    let height: Int
    let pixels: [UInt8] // palette indices length = width * height

    /// Convert to CGImage using the provided VGA palette. Alpha is always 1.0.
    func cgImage(palette: VGAPalette) -> CGImage? {
        guard palette.colors.count >= 256 else { return nil }
        var rgba: [UInt8] = Array(repeating: 0, count: width * height * 4)

        for i in 0..<pixels.count {
            let idx = Int(pixels[i])
            let color = idx < palette.colors.count ? palette.colors[idx] : PaletteColor(r: 0, g: 0, b: 0)
            let base = i * 4
            rgba[base] = color.r
            rgba[base + 1] = color.g
            rgba[base + 2] = color.b
            rgba[base + 3] = 255
        }

        let rgbaData = Data(rgba)
        guard let provider = CGDataProvider(data: rgbaData as CFData) else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    func nsImage(palette: VGAPalette) -> NSImage? {
        guard let cg = cgImage(palette: palette) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }
}

struct SCRDecoder {
    enum DecodeError: Error {
        case invalidHeader
        case missingSections
    }

    static let defaultDirectory = URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL")

    /// Decode a .SCR file at the given URL.
    static func decode(at url: URL) throws -> SCRImage {
        let data = try Data(contentsOf: url)
        let bytes = [UInt8](data)
        guard bytes.count >= 12 else { throw DecodeError.invalidHeader }

        var cursor = 0
        var width = 320
        var height = 200
        var lowNibbles: [UInt8]? = nil
        var highNibbles: [UInt8]? = nil
        var containerEnd: Int? = nil

        while cursor + 8 <= data.count {
            guard let tag = String(data: data[cursor..<(cursor + 4)], encoding: .ascii) else { break }
            cursor += 4
            let rawSize = readUInt32LE(bytes, offset: cursor)
            let size = Int(rawSize & 0x7FFF_FFFF) // bit 31 = container flag
            cursor += 4

            // Respect container boundary if present
            if let end = containerEnd, cursor > end { break }

            if tag == "SCR:" {
                containerEnd = cursor + size
                continue
            }

            guard cursor + size <= data.count else { break }
            let sectionData = data[cursor..<(cursor + size)]
            cursor += size

            switch tag {
            case "DIM:":
                if size >= 4 {
                    let bytes = Array(sectionData)
                    width = Int(readUInt16LE(bytes, offset: 0))
                    height = Int(readUInt16LE(bytes, offset: 2))
                }
            case "BIN:":
                lowNibbles = decompressSection(Data(sectionData))
            case "VGA:":
                highNibbles = decompressSection(Data(sectionData))
            default:
                continue
            }
        }

        guard let lows = lowNibbles, let highs = highNibbles, lows.count == highs.count else {
            throw DecodeError.missingSections
        }

        let pixelCount = width * height
        let nibbleCount = pixelCount / 2
        guard lows.count >= nibbleCount, highs.count >= nibbleCount else {
            throw DecodeError.missingSections
        }

        var pixels: [UInt8] = Array(repeating: 0, count: pixelCount)
        for i in 0..<pixelCount {
            let byteIndex = i / 2
            if i % 2 == 0 {
                let low = lows[byteIndex] & 0x0F
                let high = highs[byteIndex] & 0x0F
                pixels[i] = low | (high << 4)
            } else {
                let low = (lows[byteIndex] >> 4) & 0x0F
                let high = (highs[byteIndex] >> 4) & 0x0F
                pixels[i] = low | (high << 4)
            }
        }

        return SCRImage(width: width, height: height, pixels: pixels)
    }

    /// Convenience: load from default game directory.
    static func load(named filename: String) -> SCRImage? {
        let url = defaultDirectory.appendingPathComponent(filename)
        return try? decode(at: url)
    }

    /// Decode a section body that starts with compression type + size.
    private static func decompressSection(_ data: Data) -> [UInt8] {
        let bytes = [UInt8](data)
        guard bytes.count >= 5 else { return [] }
        let type = bytes[0]
        let expectedSize = Int(readUInt32LE(bytes, offset: 1))
        let payload = Array(bytes[5..<bytes.count])

        switch type {
        case 0x01:
            return decompressRLE(payload, expectedSize: expectedSize)
        case 0x02:
            return decompressLZW(payload, expectedSize: expectedSize)
        default:
            return []
        }
    }

    /// Dynamix RLE: value <=127 => copy N literal bytes; value>128 => repeat next byte (value-128) times.
    private static func decompressRLE(_ data: [UInt8], expectedSize: Int) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(expectedSize)
        var cursor = 0

        while output.count < expectedSize && cursor < data.count {
            let value = data[cursor]
            cursor += 1
            if value <= 0x7F {
                let literalCount = Int(value)
                guard cursor + literalCount <= data.count else { break }
                output.append(contentsOf: data[cursor..<(cursor + literalCount)])
                cursor += literalCount
            } else {
                let repeatCount = Int(value) - 0x80
                guard cursor < data.count else { break }
                let byte = data[cursor]
                cursor += 1
                output.append(contentsOf: Array(repeating: byte, count: repeatCount))
            }
        }

        if output.count > expectedSize {
            output = Array(output.prefix(expectedSize))
        } else if output.count < expectedSize {
            output.append(contentsOf: Array(repeating: 0, count: expectedSize - output.count))
        }

        return output
    }

    /// Dynamix LZW (DGDS): 9-bit init, max 12, clear=0x100, LSB-first, block-aligned.
    private static func decompressLZW(_ data: [UInt8], expectedSize: Int) -> [UInt8] {
        let clearCode = 0x100
        var table: [Int: [UInt8]] = [:]
        for i in 0..<256 { table[i] = [UInt8(i)] }
        var tableSize = 0x101 // 256 literals + clear code slot
        var tableMax = 0x200   // 512
        var codeSize = 9
        var tableFull = false
        var cacheBits = 0

        var output: [UInt8] = []
        output.reserveCapacity(expectedSize)

        var bitData: UInt32 = 0
        var bitCount: Int = 0
        var bytePos = 0
        var previous: [UInt8]? = nil

        func getCode(_ bits: Int) -> Int? {
            var result = 0
            var bitsNeeded = bits
            var shift = 0

            while bitsNeeded > 0 {
                if bitCount == 0 {
                    guard bytePos < data.count else { return nil }
                    bitData = UInt32(data[bytePos])
                    bytePos += 1
                    bitCount = 8
                }

                let take = min(bitsNeeded, bitCount)
                let mask = UInt32((1 << take) - 1)
                result |= Int(bitData & mask) << shift
                bitData >>= take
                bitCount -= take
                bitsNeeded -= take
                shift += take
            }

            return result
        }

        while output.count < expectedSize {
            guard let code = getCode(codeSize) else { break }

            cacheBits += codeSize
            if cacheBits >= codeSize * 8 {
                cacheBits -= codeSize * 8
            }

            if code == clearCode {
                if cacheBits > 0 {
                    let skip = codeSize * 8 - cacheBits
                    _ = getCode(skip)
                }
                table.removeAll(keepingCapacity: true)
                for i in 0..<256 { table[i] = [UInt8(i)] }
                tableSize = 0x101
                tableMax = 0x200
                codeSize = 9
                tableFull = false
                cacheBits = 0
                previous = nil
                continue
            }

            let current: [UInt8]
            if let entry = table[code] {
                current = entry
            } else if code == tableSize, let prev = previous {
                current = prev + [prev[0]]
            } else {
                break
            }

            output.append(contentsOf: current)

            if let prev = previous, !tableFull {
                table[tableSize] = prev + [current[0]]
                tableSize += 1

                if tableSize == tableMax && codeSize < 12 {
                    codeSize += 1
                    tableMax = 1 << codeSize
                } else if tableSize >= tableMax {
                    tableFull = true
                }
            }

            previous = current
        }

        if output.count > expectedSize {
            output = Array(output.prefix(expectedSize))
        } else if output.count < expectedSize {
            output.append(contentsOf: Array(repeating: 0, count: expectedSize - output.count))
        }

        return output
    }

    private static func readUInt32LE(_ data: [UInt8], offset: Int) -> UInt32 {
        guard offset + 3 < data.count else { return 0 }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1]) << 8
        let b2 = UInt32(data[offset + 2]) << 16
        let b3 = UInt32(data[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    private static func readUInt16LE(_ data: [UInt8], offset: Int) -> UInt16 {
        guard offset + 1 < data.count else { return 0 }
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1]) << 8
        return b0 | b1
    }
}
