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
        var vqtData: [UInt8]? = nil
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
            case "VQT:":
                vqtData = Array(sectionData)
            default:
                continue
            }
        }

        // Prefer VQT if present (BALL.SCR/KICK.SCR).
        if let vqt = vqtData, let image = decodeVQT(vqt, width: width, height: height) {
            return image
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

    // MARK: - VQT Decoder (Recursive Quadtree + Adaptive Color Tables)
    // Algorithm from ScummVM DGDS engine (engines/dgds/image.cpp).
    // VQT: sections use recursive quadtree decomposition. Each node splits
    // a region into 4 quadrants; leaf regions use local color tables with
    // variable-width bit-packed indices. Data is a bitstream, LSB-first.

    /// Mutable state for VQT bitstream reading.
    private final class VQTBitReader {
        let data: [UInt8]
        var offset: Int = 0 // bit offset

        init(_ data: [UInt8]) {
            self.data = data
        }

        /// Read nbits (up to 16) from the bitstream, LSB-first.
        func getBits(_ nbits: Int) -> UInt8 {
            let index = offset >> 3
            let shift = offset & 7
            offset += nbits

            // Read up to 3 bytes to cover the bit span
            var val: UInt32 = 0
            for i in 0..<3 {
                if index + i < data.count {
                    val |= UInt32(data[index + i]) << (i * 8)
                }
            }

            return UInt8((val >> shift) & UInt32((1 << nbits) - 1))
        }
    }

    /// Decode a VQT leaf region (uniform fill or indexed color table).
    private static func vqtDecodeLeaf(_ reader: VQTBitReader, _ pixels: inout [UInt8],
                                       _ imgWidth: Int, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        guard h > 0 && w > 0 else { return }

        // Single pixel: read 8 bits directly
        if w == 1 && h == 1 {
            pixels[y * imgWidth + x] = reader.getBits(8)
            return
        }

        let losize = Int(UInt8(truncatingIfNeeded: w)) * Int(UInt8(truncatingIfNeeded: h))

        // Compute bits needed to represent (losize - 1)
        var bitcount1: Int = 8
        if losize < 256 {
            bitcount1 = 0
            var b = UInt8(truncatingIfNeeded: losize - 1)
            while b != 0 {
                bitcount1 += 1
                b >>= 1
            }
        }

        // Read firstval: encodes (color_count - 1)
        let firstval = Int(reader.getBits(bitcount1))

        // Compute bitcount2: bits to index into color table
        var bitcount2: Int = 0
        let bval: UInt8
        var temp = firstval
        while temp != 0 {
            bitcount2 += 1
            temp >>= 1
        }
        bval = UInt8(truncatingIfNeeded: firstval) &+ 1 // number of colors in local table

        // Efficiency check: cheaper to store raw 8-bit pixels?
        if losize * 8 <= losize * bitcount2 + Int(bval) * 8 {
            for xx in x..<(x + w) {
                for yy in y..<(y + h) {
                    pixels[yy * imgWidth + xx] = reader.getBits(8)
                }
            }
            return
        }

        // Uniform fill: single color for the whole region
        if bval == 1 {
            let val = reader.getBits(8)
            for yy in y..<(y + h) {
                for xx in x..<(x + w) {
                    pixels[yy * imgWidth + xx] = val
                }
            }
            return
        }

        // Read local color table
        var tmpbuf: [UInt8] = []
        tmpbuf.reserveCapacity(Int(bval))
        for _ in 0..<Int(bval) {
            tmpbuf.append(reader.getBits(8))
        }

        // Fill pixels using indexed lookups (column-major order)
        for xx in x..<(x + w) {
            for yy in y..<(y + h) {
                let idx = Int(reader.getBits(bitcount2))
                pixels[yy * imgWidth + xx] = idx < tmpbuf.count ? tmpbuf[idx] : 0
            }
        }
    }

    /// Recursive quadtree decoder. Reads 4-bit mask, splits into quadrants.
    /// Bit 3=top-left, 2=top-right, 1=bottom-left, 0=bottom-right.
    /// If bit=1: recurse. If bit=0: decode as leaf.
    private static func vqtDecodeQuad(_ reader: VQTBitReader, _ pixels: inout [UInt8],
                                       _ imgWidth: Int, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        guard w > 0 || h > 0 else { return }

        let mask = reader.getBits(4)
        let halfW = w / 2
        let halfH = h / 2
        let rightW = (w + 1) / 2
        let bottomH = (h + 1) / 2

        // Top-left
        if mask & 8 != 0 {
            vqtDecodeQuad(reader, &pixels, imgWidth, x, y, halfW, halfH)
        } else {
            vqtDecodeLeaf(reader, &pixels, imgWidth, x, y, halfW, halfH)
        }

        // Top-right
        if mask & 4 != 0 {
            vqtDecodeQuad(reader, &pixels, imgWidth, x + halfW, y, rightW, halfH)
        } else {
            vqtDecodeLeaf(reader, &pixels, imgWidth, x + halfW, y, rightW, halfH)
        }

        // Bottom-left
        if mask & 2 != 0 {
            vqtDecodeQuad(reader, &pixels, imgWidth, x, y + halfH, halfW, bottomH)
        } else {
            vqtDecodeLeaf(reader, &pixels, imgWidth, x, y + halfH, halfW, bottomH)
        }

        // Bottom-right
        if mask & 1 != 0 {
            vqtDecodeQuad(reader, &pixels, imgWidth, x + halfW, y + halfH, rightW, bottomH)
        } else {
            vqtDecodeLeaf(reader, &pixels, imgWidth, x + halfW, y + halfH, rightW, bottomH)
        }
    }

    /// Decode VQT section data into an SCRImage.
    /// Uses recursive quadtree decomposition with adaptive color tables.
    private static func decodeVQT(_ data: [UInt8], width: Int, height: Int) -> SCRImage? {
        guard !data.isEmpty, width > 0, height > 0 else { return nil }

        let reader = VQTBitReader(data)
        var pixels: [UInt8] = Array(repeating: 0, count: width * height)

        vqtDecodeQuad(reader, &pixels, width, 0, 0, width, height)

        return SCRImage(width: width, height: height, pixels: pixels)
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
