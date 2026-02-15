//
//  AnimDecoder.swift
//  footballPro
//
//  Decoder for FPS Football Pro '93 ANIM.DAT player sprite animations.
//  Format: Index table (71 animations) + per-animation sprite references + LZ77 compressed bitmaps.
//  Full rendering pipeline reverse-engineered from A.EXE disassembly.
//
//  Key discoveries:
//  - LZ77 backref copy length = (word & 0x0F) + 3 (not +2)
//  - Pixel data is COLUMN-MAJOR (Mode X VGA), must convert to row-major
//  - Gameplay palette from FILE.DAT PAL section #5
//  - Flag byte 0x02 = horizontal mirror
//

import Foundation
import CoreGraphics

// MARK: - Data Types

struct AnimationEntry {
    let name: String
    let frameCount: Int
    let viewCount: Int  // filled in during decoding (not in index)
    let dataOffset: Int
}

struct SpriteReference {
    let flag: UInt8       // 0x00 = normal, 0x02 = horizontal mirror
    let spriteID: Int
    let xOffset: Int8
    let yOffset: Int8

    var isMirrored: Bool { flag == 0x02 }
}

struct DecodedSprite {
    let width: Int
    let height: Int
    let pixels: [UInt8]  // row-major palette indices (width * height)
}

struct DecodedAnimation {
    let name: String
    let frameCount: Int
    let viewCount: Int
    let refs: [SpriteReference]
    let sprites: [Int: DecodedSprite]
}

struct AnimDatabase {
    let animations: [String: DecodedAnimation]
    let palette: [(UInt8, UInt8, UInt8)]
}

// MARK: - Decoder

struct AnimDecoder {

    static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/front-page-sports-football-pro/DYNAMIX/FBPRO")

    // Identity color table - passes through raw palette indices unchanged
    static let identityColorTable: [UInt8] = Array(0..<64)

    // 5 color tables from A.EXE at offset 0x4091D
    // Broken into separate lets to avoid Swift type-checker complexity limits.

    private static let skinBlock: [UInt8] = [0x10, 0x11, 0x12, 0x13]
    private static let zeros12: [UInt8] = [UInt8](repeating: 0, count: 12)
    private static let zeros16: [UInt8] = [UInt8](repeating: 0, count: 16)

    private static let teamBlockA: [UInt8] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
                                               0x38, 0x39, 0x3A, 0x3B, 0x2C, 0x2D, 0, 0]
    private static let teamBlockB: [UInt8] = [0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
                                               0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0, 0]

    private static let secBlockA: [UInt8] = [0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
                                              0x28, 0x29, 0x2A, 0x2B, 0x3C, 0x3D, 0x3E, 0x3F]
    private static let secBlockB: [UInt8] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
                                              0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F]

    // Table 0: outline only (mostly zeros, indices 46-47 mapped)
    static let colorTable0: [UInt8] = [UInt8](repeating: 0, count: 46) + [0x2E, 0x2F] + zeros16
    // Table 1: team A primary
    static let colorTable1: [UInt8] = zeros16 + skinBlock + zeros12 + teamBlockA + secBlockA
    // Table 2: team B variant
    static let colorTable2: [UInt8] = zeros16 + skinBlock + zeros12 + teamBlockB + secBlockA
    // Table 3: team C variant
    static let colorTable3: [UInt8] = zeros16 + skinBlock + zeros12 + teamBlockA + secBlockB
    // Table 4: team D variant
    static let colorTable4: [UInt8] = zeros16 + skinBlock + zeros12 + teamBlockB + secBlockB

    static let colorTables: [[UInt8]] = [colorTable0, colorTable1, colorTable2, colorTable3, colorTable4]

    // MARK: - Index Parsing

    /// Parse the ANIM.DAT index table.
    /// Header: uint16 LE count at offset 0
    /// 72 entries x 14 bytes: name(8B null-padded) + frameCount(2B BIG-endian) + dataOffset(4B LE)
    /// Entry #71 is sentinel (skip it).
    static func parseIndex(from data: Data) -> [AnimationEntry] {
        guard data.count >= 2 else { return [] }
        let count = Int(data[0]) | (Int(data[1]) << 8)
        var animations: [AnimationEntry] = []
        animations.reserveCapacity(count)

        for i in 0..<count {
            let off = 2 + i * 14
            guard off + 14 <= data.count else { break }

            // Name: 8 bytes null-padded ASCII
            var nameBytes = [UInt8]()
            for j in 0..<8 {
                let b = data[off + j]
                if b == 0 { break }
                nameBytes.append(b)
            }
            let name = String(bytes: nameBytes, encoding: .ascii) ?? ""

            // Frame count: 2 bytes BIG-endian
            let frameCount = (Int(data[off + 8]) << 8) | Int(data[off + 9])

            // Data offset: 4 bytes little-endian
            let dataOffset = Int(data[off + 10]) |
                (Int(data[off + 11]) << 8) |
                (Int(data[off + 12]) << 16) |
                (Int(data[off + 13]) << 24)

            animations.append(AnimationEntry(
                name: name,
                frameCount: frameCount,
                viewCount: 0,  // filled in during decode
                dataOffset: dataOffset
            ))
        }

        return animations
    }

    // MARK: - LZ77 Decompression

    /// Decompress LZ77/LZSS compressed sprite data.
    ///
    /// Header: uint16 LE (groups_minus_1) + uint8 (tail_bits)
    /// Per group: 1 flag byte, 8 decisions MSB-first
    /// After all groups: 1 flag byte for tail_bits remaining decisions
    /// bit=0: LITERAL byte, remap through colorTable if value < 64
    /// bit=1: BACKREF uint16 LE, length = (word & 0x0F) + 3, distance = word >> 4
    /// CRITICAL: copy length is +3, NOT +2
    static func decompressLZ77(data: Data, offset: Int, colorTable: [UInt8]) -> [UInt8] {
        guard offset + 3 <= data.count else { return [] }

        var si = offset
        let groupsM1 = Int(data[si]) | (Int(data[si + 1]) << 8)
        si += 2
        let tailBits = Int(data[si])
        si += 1

        var output = [UInt8]()
        output.reserveCapacity(1024) // typical sprite size

        @inline(__always)
        func processBit(_ flagBit: Bool) {
            if !flagBit {
                // LITERAL
                guard si < data.count else { return }
                let bv = Int(data[si])
                si += 1
                let mapped: UInt8 = bv < 64 ? colorTable[bv] : UInt8(bv)
                output.append(mapped)
            } else {
                // BACKREF
                guard si + 1 < data.count else { return }
                let ref = Int(data[si]) | (Int(data[si + 1]) << 8)
                si += 2
                let copyLen = (ref & 0x0F) + 3
                let distance = ref >> 4
                let copyPos = output.count - distance - 1
                for j in 0..<copyLen {
                    let srcIdx = copyPos + j
                    if srcIdx >= 0 && srcIdx < output.count {
                        output.append(output[srcIdx])
                    } else {
                        output.append(0)
                    }
                }
            }
        }

        // Process full groups
        for _ in 0..<(groupsM1 + 1) {
            guard si < data.count else { break }
            var flag = Int(data[si])
            si += 1
            for _ in 0..<8 {
                processBit((flag >> 7) & 1 == 1)
                flag <<= 1
            }
        }

        // Process tail bits
        if tailBits > 0 {
            guard si < data.count else { return output }
            var flag = Int(data[si])
            si += 1
            for _ in 0..<tailBits {
                processBit((flag >> 7) & 1 == 1)
                flag <<= 1
            }
        }

        return output
    }

    // MARK: - Animation Decoding

    /// Decode a single animation from ANIM.DAT data.
    ///
    /// At dataOffset: frameCount(1B) + viewCount(1B) + unknown(2B)
    /// Sprite ref table: (frames x views) x 4B each: flag(1B) + spriteID(1B) + xOffset(int8) + yOffset(int8)
    /// Bitmap section starts after ref table
    /// Sprite offset table: spriteCount x uint16 LE offsets (relative to bitmap section start)
    /// Each sprite: width(1B) + height(1B) + LZ77 compressed data
    /// CRITICAL: Decompressed pixels are COLUMN-MAJOR, must convert to row-major.
    static func decodeAnimation(from data: Data, entry: AnimationEntry, colorTable: [UInt8]? = nil) -> DecodedAnimation? {
        let ct = colorTable ?? identityColorTable

        let dataOffset = entry.dataOffset
        guard dataOffset + 4 <= data.count else {
            print("[AnimDecoder] Warning: animation '\(entry.name)' offset \(dataOffset) out of bounds")
            return nil
        }

        let nFrames = Int(data[dataOffset])
        let nViews = Int(data[dataOffset + 1])
        // bytes 2-3 are unknown, skip

        let refStart = dataOffset + 4
        let nRefs = nFrames * nViews

        guard refStart + nRefs * 4 <= data.count else {
            print("[AnimDecoder] Warning: animation '\(entry.name)' ref table exceeds data")
            return nil
        }

        var refs: [SpriteReference] = []
        refs.reserveCapacity(nRefs)
        var spriteIDs = Set<Int>()

        for i in 0..<nRefs {
            let r = refStart + i * 4
            let flag = data[r]
            let sid = Int(data[r + 1])
            let xOff = Int8(bitPattern: data[r + 2])
            let yOff = Int8(bitPattern: data[r + 3])
            refs.append(SpriteReference(flag: flag, spriteID: sid, xOffset: xOff, yOffset: yOff))
            spriteIDs.insert(sid)
        }

        guard let maxSpriteID = spriteIDs.max() else {
            return DecodedAnimation(name: entry.name, frameCount: nFrames, viewCount: nViews, refs: refs, sprites: [:])
        }
        let nSprites = maxSpriteID + 1
        let bitmapStart = refStart + nRefs * 4

        guard bitmapStart + nSprites * 2 <= data.count else {
            print("[AnimDecoder] Warning: animation '\(entry.name)' sprite offset table exceeds data")
            return nil
        }

        // Read sprite offset table
        var spriteOffsets = [Int]()
        spriteOffsets.reserveCapacity(nSprites)
        for i in 0..<nSprites {
            let off = bitmapStart + i * 2
            let val = Int(data[off]) | (Int(data[off + 1]) << 8)
            spriteOffsets.append(val)
        }

        // Decode each unique sprite
        var sprites = [Int: DecodedSprite]()
        for sid in spriteIDs {
            guard sid < spriteOffsets.count else { continue }
            let absOff = bitmapStart + spriteOffsets[sid]
            guard absOff + 2 <= data.count else { continue }

            let w = Int(data[absOff])
            let h = Int(data[absOff + 1])
            guard w > 0, h > 0 else { continue }

            let colMajor = decompressLZ77(data: data, offset: absOff + 2, colorTable: ct)

            // Convert column-major to row-major
            var rowMajor = [UInt8](repeating: 0, count: w * h)
            for x in 0..<w {
                for y in 0..<h {
                    let src = x * h + y
                    let dst = y * w + x
                    if src < colMajor.count {
                        rowMajor[dst] = colMajor[src]
                    }
                }
            }

            sprites[sid] = DecodedSprite(width: w, height: h, pixels: rowMajor)
        }

        return DecodedAnimation(
            name: entry.name,
            frameCount: nFrames,
            viewCount: nViews,
            refs: refs,
            sprites: sprites
        )
    }

    // MARK: - Palette Loading

    /// Load the gameplay palette from FILE.DAT (PAL section #5).
    /// Falls back to synthetic palette if FILE.DAT is unavailable.
    static func loadGameplayPalette() -> [(UInt8, UInt8, UInt8)] {
        let fileDatURL = defaultDirectory.appendingPathComponent("FILE.DAT")
        guard let data = try? Data(contentsOf: fileDatURL) else {
            print("[AnimDecoder] FILE.DAT not found, using synthetic palette")
            return syntheticGameplayPalette()
        }

        // Find PAL: markers
        let palMarker = Data("PAL:".utf8)
        var palOffsets = [Int]()
        var pos = 0
        while pos < data.count - 4 {
            if let range = data.range(of: palMarker, in: pos..<data.count) {
                palOffsets.append(range.lowerBound)
                pos = range.lowerBound + 1
            } else {
                break
            }
        }

        guard palOffsets.count >= 6 else {
            print("[AnimDecoder] FILE.DAT has \(palOffsets.count) PAL: sections (need 6), using synthetic palette")
            return syntheticGameplayPalette()
        }

        // Use PAL #5 (index 5) which has the fullest sprite color data
        let palOffset = palOffsets[5]
        let rgbStart = palOffset + 16  // skip PAL:(8B) + VGA:(8B)
        guard rgbStart + 256 * 3 <= data.count else {
            print("[AnimDecoder] PAL section #5 too short, using synthetic palette")
            return syntheticGameplayPalette()
        }

        var palette = [(UInt8, UInt8, UInt8)]()
        palette.reserveCapacity(256)
        for i in 0..<256 {
            let off = rgbStart + i * 3
            let r = min(UInt16(data[off]) * 4, 255)
            let g = min(UInt16(data[off + 1]) * 4, 255)
            let b = min(UInt16(data[off + 2]) * 4, 255)
            palette.append((UInt8(r), UInt8(g), UInt8(b)))
        }

        // Apply team colors from NFLPA93.LGE
        applyTeamColors(&palette)

        return palette
    }

    /// Apply team colors from NFLPA93.LGE to palette indices 0x20-0x27 (home) and 0x30-0x37 (away).
    private static func applyTeamColors(_ palette: inout [(UInt8, UInt8, UInt8)]) {
        let lgeURL = defaultDirectory.appendingPathComponent("NFLPA93.LGE")
        guard let data = try? Data(contentsOf: lgeURL) else { return }

        let teamMarker = Data("T00:".utf8)
        var teams: [[(UInt8, UInt8, UInt8)]] = []
        var pos = 0
        while pos < data.count - 4 {
            guard let range = data.range(of: teamMarker, in: pos..<data.count) else { break }
            let idx = range.lowerBound
            let sizeOff = idx + 4
            guard sizeOff + 4 <= data.count else { break }
            let size = Int(data[sizeOff]) | (Int(data[sizeOff + 1]) << 8) |
                (Int(data[sizeOff + 2]) << 16) | (Int(data[sizeOff + 3]) << 24)
            let tdStart = idx + 8
            guard tdStart + 0x0A + 15 <= data.count, size > 0 else {
                pos = idx + 1
                continue
            }

            var colors = [(UInt8, UInt8, UInt8)]()
            for c in 0..<5 {
                let off = tdStart + 0x0A + c * 3
                guard off + 2 < data.count else { break }
                colors.append((data[off], data[off + 1], data[off + 2]))
            }
            teams.append(colors)
            pos = idx + 1
        }

        guard teams.count >= 2 else { return }

        // Home team primary -> 0x20-0x23, secondary -> 0x24-0x27
        let homeC1 = generate4ShadeGradient(teams[0][0].0, teams[0][0].1, teams[0][0].2)
        let homeC2 = generate4ShadeGradient(teams[0][1].0, teams[0][1].1, teams[0][1].2)
        for i in 0..<4 { palette[0x20 + i] = homeC1[i] }
        for i in 0..<4 { palette[0x24 + i] = homeC2[i] }

        // Away team primary -> 0x30-0x33, secondary -> 0x34-0x37
        let awayC1 = generate4ShadeGradient(teams[1][0].0, teams[1][0].1, teams[1][0].2)
        let awayC2 = generate4ShadeGradient(teams[1][1].0, teams[1][1].1, teams[1][1].2)
        for i in 0..<4 { palette[0x30 + i] = awayC1[i] }
        for i in 0..<4 { palette[0x34 + i] = awayC2[i] }
    }

    /// Generate 4 shades from a VGA base color (brightest to darkest).
    private static func generate4ShadeGradient(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> [(UInt8, UInt8, UInt8)] {
        let factors: [Double] = [1.0, 0.79, 0.59, 0.49]
        return factors.map { f in
            let r8 = min(255, Int(Double(r) * 4.0 * f))
            let g8 = min(255, Int(Double(g) * 4.0 * f))
            let b8 = min(255, Int(Double(b) * 4.0 * f))
            return (UInt8(r8), UInt8(g8), UInt8(b8))
        }
    }

    /// Fallback synthetic palette when FILE.DAT is unavailable.
    private static func syntheticGameplayPalette() -> [(UInt8, UInt8, UInt8)] {
        // Try loading MU1.PAL first
        let mu1URL = defaultDirectory.appendingPathComponent("MU1.PAL")
        var palette: [(UInt8, UInt8, UInt8)]
        if let palData = try? Data(contentsOf: mu1URL), palData.count >= 784 {
            palette = [(UInt8, UInt8, UInt8)]()
            palette.reserveCapacity(256)
            for i in 0..<256 {
                let off = 16 + i * 3
                let r = min(UInt16(palData[off]) * 4, 255)
                let g = min(UInt16(palData[off + 1]) * 4, 255)
                let b = min(UInt16(palData[off + 2]) * 4, 255)
                palette.append((UInt8(r), UInt8(g), UInt8(b)))
            }
        } else {
            palette = [(UInt8, UInt8, UInt8)](repeating: (0, 0, 0), count: 256)
        }

        // Fill sprite color range with synthetic values
        // Skin tones (0x10-0x13)
        palette[0x10] = (227, 227, 227)  // helmet white
        palette[0x11] = (186, 186, 186)  // helmet gray
        palette[0x12] = (150, 150, 150)  // helmet mid
        palette[0x13] = (113, 113, 113)  // helmet dark
        // Skin tones (0x14-0x1B)
        palette[0x14] = (184, 120, 92)
        palette[0x15] = (172, 108, 80)
        palette[0x16] = (160, 96, 68)
        palette[0x17] = (148, 84, 56)
        palette[0x18] = (140, 72, 48)
        palette[0x19] = (128, 60, 40)
        palette[0x1A] = (116, 52, 32)
        palette[0x1B] = (108, 44, 24)
        // Home team A (red)
        for i in 0..<4 {
            let v = UInt8(220 - i * 40)
            palette[0x20 + i] = (v, 20, 20)
        }
        // Home team B (blue)
        for i in 0..<4 {
            let v = UInt8(220 - i * 40)
            palette[0x24 + i] = (20, 20, v)
        }
        // Equipment (brown)
        palette[0x28] = (144, 112, 64)
        palette[0x29] = (116, 88, 48)
        palette[0x2A] = (88, 64, 32)
        palette[0x2B] = (72, 52, 28)
        palette[0x2C] = (20, 20, 20)
        palette[0x2D] = (52, 52, 52)
        palette[0x2E] = (8, 64, 20)
        palette[0x2F] = (12, 80, 28)
        // Away team A (white)
        for i in 0..<4 {
            let v = UInt8(255 - i * 30)
            palette[0x30 + i] = (v, v, v)
        }
        // Away team B (gray)
        for i in 0..<4 {
            let v = UInt8(180 - i * 30)
            palette[0x34 + i] = (v, v, v)
        }
        // Away equipment
        palette[0x38] = (144, 112, 64)
        palette[0x39] = (116, 88, 48)
        palette[0x3A] = (88, 64, 32)
        palette[0x3B] = (72, 52, 28)
        palette[0x3C] = (200, 200, 200)
        palette[0x3D] = (220, 220, 220)
        palette[0x3E] = (240, 240, 240)
        palette[0x3F] = (255, 255, 255)

        return palette
    }

    // MARK: - Image Rendering

    /// Convert a decoded sprite to a CGImage using the given palette.
    /// Palette index 0 = transparent. If mirrored, flips pixels horizontally.
    static func spriteToImage(sprite: DecodedSprite, palette: [(UInt8, UInt8, UInt8)], mirrored: Bool = false) -> CGImage? {
        let w = sprite.width
        let h = sprite.height
        guard w > 0, h > 0 else { return nil }

        var rgba = [UInt8](repeating: 0, count: w * h * 4)

        for y in 0..<h {
            for x in 0..<w {
                let srcX = mirrored ? (w - 1 - x) : x
                let pi = y * w + srcX
                guard pi < sprite.pixels.count else { continue }
                let palIdx = Int(sprite.pixels[pi])
                let dstOff = (y * w + x) * 4
                if palIdx == 0 {
                    // Transparent
                    rgba[dstOff] = 0
                    rgba[dstOff + 1] = 0
                    rgba[dstOff + 2] = 0
                    rgba[dstOff + 3] = 0
                } else {
                    let color = palIdx < palette.count ? palette[palIdx] : (255, 0, 255)
                    rgba[dstOff] = color.0
                    rgba[dstOff + 1] = color.1
                    rgba[dstOff + 2] = color.2
                    rgba[dstOff + 3] = 255
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }

        return CGImage(
            width: w,
            height: h,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    // MARK: - Full Database Loading

    /// Load all animations from ANIM.DAT and the gameplay palette.
    /// Returns nil if ANIM.DAT cannot be found or read.
    static func loadDefault() -> AnimDatabase? {
        let animURL = defaultDirectory.appendingPathComponent("ANIM.DAT")
        guard var data = try? Data(contentsOf: animURL) else {
            print("[AnimDecoder] ANIM.DAT not found at \(animURL.path)")
            return nil
        }

        // Add safety padding (256 zero bytes) to prevent out-of-bounds during decompression
        data.append(Data(repeating: 0, count: 256))

        let entries = parseIndex(from: data)
        guard !entries.isEmpty else {
            print("[AnimDecoder] No animations found in index")
            return nil
        }

        var animations = [String: DecodedAnimation]()
        var totalSprites = 0

        for entry in entries {
            if let decoded = decodeAnimation(from: data, entry: entry) {
                animations[entry.name] = decoded
                totalSprites += decoded.sprites.count
            }
        }

        let palette = loadGameplayPalette()

        print("[AnimDecoder] Loaded \(animations.count) animations, \(totalSprites) sprites from ANIM.DAT")
        return AnimDatabase(animations: animations, palette: palette)
    }
}
