//
//  DDAAnimationDecoder.swift
//  footballPro
//
//  Lightweight decoder for FPS '93 .DDA cutscene streams.
//  Uses heuristic RLE grammars derived from brute-force exploration.
//

import Foundation
import CoreGraphics

struct DDAFrame {
    let image: CGImage
}

final class DDAAnimationDecoder {
    /// Attempt to decode the first frame of a DDA file using known heuristics.
    /// - Parameters:
    ///   - url: File URL to the .DDA asset.
    ///   - width: Expected width (default 320).
    ///   - height: Expected height (default 200).
    ///   - paletteOffset: Byte offset where the 768-byte VGA palette begins (default 0).
    ///   - payloadOffset: Optional override for payload start. If nil, will use header offset for DDA: magic, else 0x1F10 fallback.
    static func decodeFirstFrame(
        from url: URL,
        width: Int = 320,
        height: Int = 200,
        paletteOffset: Int = 0,
        payloadOffset: Int? = nil
    ) -> DDAFrame? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decodeFirstFrame(data: data, width: width, height: height, paletteOffset: paletteOffset, payloadOffset: payloadOffset)
    }

    /// Decode all frames using a mix of offset-table and length-prefixed heuristics.
    /// Falls back to the first-frame decoder if no frame segmentation can be inferred.
    static func decodeFrames(
        from url: URL,
        width: Int = 320,
        height: Int = 200,
        paletteOffset: Int = 0,
        payloadOffset: Int? = nil
    ) -> [DDAFrame] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let palette = loadPalette(from: data, offset: paletteOffset)
        let payloadStart = resolvePayloadStart(in: data, override: payloadOffset)
        guard payloadStart < data.count else { return [] }
        let expected = width * height

        if let offsets = findOffsetTable(in: data, payloadStart: payloadStart, expectedCount: headerFrameCount(from: data)) {
            let frames = decodeFrames(from: offsets, data: data, expected: expected, palette: palette, width: width, height: height)
            if !frames.isEmpty {
                return frames
            }
        }

        let payload = data[payloadStart...]
        let lengthFrames = decodeLengthPrefixedFrames(payload: payload, expected: expected, palette: palette, width: width, height: height)
        if !lengthFrames.isEmpty {
            return lengthFrames
        }

        if let first = decodeFirstFrame(data: data, width: width, height: height, paletteOffset: paletteOffset, payloadOffset: payloadOffset) {
            return [first]
        }
        return []
    }

    private static func decodeFirstFrame(
        data: Data,
        width: Int,
        height: Int,
        paletteOffset: Int,
        payloadOffset: Int?
    ) -> DDAFrame? {
        let palette = loadPalette(from: data, offset: paletteOffset)
        let payloadStart = resolvePayloadStart(in: data, override: payloadOffset)

        guard payloadStart < data.count else { return nil }
        let payload = data[payloadStart...]
        let expected = width * height

        if let image = decodeSlice(payload, expected: expected, palette: palette, width: width, height: height) {
            return DDAFrame(image: image)
        }
        return nil
    }

    // MARK: - Decoders

    private static let decoders: [(Data.SubSequence, Int) -> Data?] = [
        nibbleDecoder(litBias: 1, repBias: 1, ctrlMask: 0x80), // best hit for LOGOSPIN
        nibbleDecoder(litBias: 1, repBias: 1, ctrlMask: 0xC0),
        nibbleDecoder(litBias: 0, repBias: 1, ctrlMask: 0x80),
        nibbleDecoder(litBias: 0, repBias: 1, ctrlMask: 0xC0),
        markerDecoder(marker: 0xFE, lenOffset: 1), // hits INTROPT1/2
        markerDecoder(marker: 0xC9, lenOffset: 1)
    ]

    private static func nibbleDecoder(litBias: Int, repBias: Int, ctrlMask: UInt8) -> (Data.SubSequence, Int) -> Data? {
        return { data, expected in
            var out = [UInt8]()
            out.reserveCapacity(expected)
            var i = data.startIndex
            while i < data.endIndex && out.count < expected {
                let b = data[i]
                data.formIndex(after: &i)
                if (b & ctrlMask) != 0 {
                    guard i < data.endIndex else { break }
                    let run = Int(b & 0x3F) + repBias
                    let val = data[i]
                    data.formIndex(after: &i)
                    out.append(contentsOf: repeatElement(val, count: run))
                } else {
                    let run = Int(b & 0x3F) + litBias
                    guard data.distance(from: i, to: data.endIndex) >= run else { break }
                    out.append(contentsOf: data[i ..< data.index(i, offsetBy: run)])
                    i = data.index(i, offsetBy: run)
                }
            }
            return out.count == expected ? Data(out) : nil
        }
    }

    private static func markerDecoder(marker: UInt8, lenOffset: Int) -> (Data.SubSequence, Int) -> Data? {
        return { data, expected in
            var out = [UInt8]()
            out.reserveCapacity(expected)
            var i = data.startIndex
            while i < data.endIndex && out.count < expected {
                let b = data[i]
                data.formIndex(after: &i)
                if b == marker {
                    guard data.distance(from: i, to: data.endIndex) >= 2 else { break }
                    let run = Int(data[i]) + lenOffset
                    let val = data[data.index(after: i)]
                    i = data.index(i, offsetBy: 2)
                    out.append(contentsOf: repeatElement(val, count: run))
                } else {
                    out.append(b)
                }
            }
            return out.count == expected ? Data(out) : nil
        }
    }

    // MARK: - Frame heuristics

    private static func resolvePayloadStart(in data: Data, override: Int?) -> Int {
        if let override {
            return override
        }
        if data.starts(with: Data([0x44, 0x44, 0x41, 0x3A])) { // "DDA:"
            if data.count >= 0x14 {
                return Int(data.withUnsafeBytes { $0.load(fromByteOffset: 0x10, as: UInt32.self) })
            }
        }
        return 0x1F10
    }

    private static func headerFrameCount(from data: Data) -> Int? {
        guard data.count >= 8 else { return nil }
        if data.starts(with: Data([0x44, 0x44, 0x41, 0x3A])) { // "DDA:"
            let count = Int(data.withUnsafeBytes { $0.load(fromByteOffset: 0x4, as: UInt32.self) })
            if (1...512).contains(count) {
                return count
            }
        }
        return nil
    }

    private static func findOffsetTable(in data: Data, payloadStart: Int, expectedCount: Int?) -> [Int]? {
        guard payloadStart > 0 else { return nil }
        let maxCount = expectedCount ?? 0
        var best: [Int]?
        var bestScore = 0
        var start = 0
        while start + 8 <= payloadStart {
            var offsets: [Int] = []
            var pos = start
            while pos + 4 <= payloadStart {
                let value = Int(data.withUnsafeBytes { $0.load(fromByteOffset: pos, as: UInt32.self) })
                if value <= payloadStart || value >= data.count {
                    break
                }
                if let last = offsets.last, value <= last {
                    break
                }
                offsets.append(value)
                if let hint = expectedCount, offsets.count == hint {
                    break
                }
                pos += 4
            }
            if offsets.count >= 2 && offsets.count > bestScore {
                bestScore = offsets.count
                best = offsets
                if let hint = expectedCount, offsets.count == hint {
                    break
                }
            }
            start += 2
        }
        return best
    }

    private static func decodeFrames(
        from offsets: [Int],
        data: Data,
        expected: Int,
        palette: [UInt8],
        width: Int,
        height: Int
    ) -> [DDAFrame] {
        guard offsets.count >= 2 else { return [] }
        var frames: [DDAFrame] = []
        var boundaries = offsets
        if boundaries.last != data.count {
            boundaries.append(data.count)
        }

        for i in 0..<(boundaries.count - 1) {
            let start = boundaries[i]
            let end = boundaries[i + 1]
            guard start < end, end <= data.count else { continue }
            let slice = data[start..<end]
            if let image = decodeSlice(slice, expected: expected, palette: palette, width: width, height: height) {
                frames.append(DDAFrame(image: image))
            }
        }
        return frames
    }

    private static func decodeLengthPrefixedFrames(
        payload: Data.SubSequence,
        expected: Int,
        palette: [UInt8],
        width: Int,
        height: Int,
        maxFrames: Int = 128
    ) -> [DDAFrame] {
        var frames: [DDAFrame] = []
        let bytes = Data(payload)
        var cursor = 0

        while cursor + 2 <= bytes.count && frames.count < maxFrames {
            let length = Int(UInt16(bytes[cursor]) | (UInt16(bytes[cursor + 1]) << 8))
            cursor += 2
            if length == 0 || cursor + length > bytes.count {
                break
            }
            let end = cursor + length
            let slice = bytes[cursor..<end]
            cursor = end

            if let image = decodeSlice(slice[...], expected: expected, palette: palette, width: width, height: height) {
                frames.append(DDAFrame(image: image))
            }
        }

        return frames
    }

    private static func decodeSlice(
        _ slice: Data.SubSequence,
        expected: Int,
        palette: [UInt8],
        width: Int,
        height: Int
    ) -> CGImage? {
        for decoder in decoders {
            if let buf = decoder(slice, expected) {
                if let image = makeImage(buffer: buf, palette: palette, width: width, height: height) {
                    return image
                }
            }
        }
        return nil
    }

    // MARK: - Palette / Image helpers

    private static func loadPalette(from data: Data, offset: Int) -> [UInt8] {
        var pal = [UInt8](repeating: 0, count: 256 * 4)
        guard offset + 768 <= data.count else { return pal }
        for i in 0..<256 {
            let base = offset + i * 3
            let r = min(Int(data[base]) * 4, 255)
            let g = min(Int(data[base + 1]) * 4, 255)
            let b = min(Int(data[base + 2]) * 4, 255)
            pal[i * 4 + 0] = UInt8(r)
            pal[i * 4 + 1] = UInt8(g)
            pal[i * 4 + 2] = UInt8(b)
            pal[i * 4 + 3] = i == 0 ? 0 : 255
        }
        return pal
    }

    private static func makeImage(buffer: Data, palette: [UInt8], width: Int, height: Int) -> CGImage? {
        guard buffer.count == width * height else { return nil }

        // Expand indexed buffer to RGBA
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for (i, idx) in buffer.enumerated() {
            let palIndex = Int(idx) * 4
            let out = i * 4
            rgba[out + 0] = palette[palIndex + 0]
            rgba[out + 1] = palette[palIndex + 1]
            rgba[out + 2] = palette[palIndex + 2]
            rgba[out + 3] = palette[palIndex + 3]
        }

        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
