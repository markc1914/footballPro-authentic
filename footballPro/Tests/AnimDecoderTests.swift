//
//  AnimDecoderTests.swift
//  footballProTests
//
//  Unit tests for AnimDecoder: index parsing, LZ77 decompression,
//  animation decoding, palette loading, and sprite image rendering.
//

import Foundation
import Testing
import CoreGraphics
@testable import footballPro

@Suite("AnimDecoder Tests")
struct AnimDecoderTests {

    // MARK: - Helpers

    private func animDatURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FBPRO_ORIGINAL", isDirectory: true)
            .appendingPathComponent("ANIM.DAT")
    }

    private func loadAnimData() throws -> Data {
        let url = animDatURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AnimTestError.fileNotFound(url.path)
        }
        return try Data(contentsOf: url)
    }

    enum AnimTestError: Error {
        case fileNotFound(String)
    }

    // MARK: - Index Parsing

    @Test("parseIndex returns 71 animations from ANIM.DAT")
    func testParseIndexCount() throws {
        let data = try loadAnimData()
        let entries = AnimDecoder.parseIndex(from: data)
        #expect(entries.count == 71)
    }

    @Test("parseIndex includes known animation names")
    func testParseIndexNames() throws {
        let data = try loadAnimData()
        let entries = AnimDecoder.parseIndex(from: data)
        let names = Set(entries.map { $0.name })

        #expect(names.contains("QBBULIT"))
        #expect(names.contains("SKRUN"))
        #expect(names.contains("LMSTAND"))
        #expect(names.contains("RCSTAND"))
        #expect(names.contains("RBRNWB"))
        #expect(names.contains("FCATCH"))
        #expect(names.contains("KICK"))
        #expect(names.contains("EZSPIKE"))
    }

    @Test("parseIndex has correct frame counts (big-endian)")
    func testParseIndexFrameCounts() throws {
        let data = try loadAnimData()
        let entries = AnimDecoder.parseIndex(from: data)
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })

        #expect(byName["SKRUN"]?.frameCount == 8)
        #expect(byName["RCSTAND"]?.frameCount == 1)
        #expect(byName["QBBULIT"]?.frameCount == 5)
        #expect(byName["LMSTAND"]?.frameCount == 1)
        #expect(byName["RBRNWB"]?.frameCount == 8)
    }

    @Test("parseIndex returns empty for insufficient data")
    func testParseIndexEmptyData() {
        let entries = AnimDecoder.parseIndex(from: Data())
        #expect(entries.isEmpty)

        let oneByteEntries = AnimDecoder.parseIndex(from: Data([0x01]))
        #expect(oneByteEntries.isEmpty)
    }

    // MARK: - LZ77 Decompression

    @Test("decompressLZ77 with identity color table passes through literals")
    func testDecompressLZ77Literals() {
        // Build minimal LZ77 data: 0 full groups, 3 tail bits, all literals
        // groups_minus_1 = 0x0000 (but we want 0 full groups really, so groupsM1 = -1 doesn't work)
        // Actually: with 0 full groups we set groups_minus_1 = 0xFFFF? No.
        // The format: groups_minus_1 (uint16 LE) + tail_bits (uint8)
        // With groupsM1 = 0, we get 1 full group (8 decisions)
        // Let's make 0 full groups by using groupsM1=0 and having all in tail
        // Actually looking at the code: for _ in 0..<(groupsM1 + 1) means groupsM1=0 → 1 group
        // So minimum is 1 group. Let's make a simple test with 1 group, 8 literal bytes.

        // 1 group (groupsM1=0), 0 tail bits
        // Flag byte = 0x00 (all 8 bits are 0 = all literals)
        // 8 literal bytes
        var testData = Data()
        testData.append(contentsOf: [0x00, 0x00]) // groups_minus_1 = 0 (1 group)
        testData.append(0x00)                       // tail_bits = 0
        testData.append(0x00)                       // flag byte: all zeros = 8 literals
        testData.append(contentsOf: [10, 20, 30, 40, 50, 60, 61, 62]) // 8 literal bytes

        let result = AnimDecoder.decompressLZ77(data: testData, offset: 0, colorTable: AnimDecoder.identityColorTable)
        #expect(result.count == 8)
        #expect(result[0] == 10)
        #expect(result[1] == 20)
        #expect(result[7] == 62)
    }

    @Test("decompressLZ77 handles back-references with +3 length")
    func testDecompressLZ77BackRef() {
        // 1 group (8 decisions), 0 tail bits
        // Flag: 0b0001_0000 = MSB-first: 0,0,0,1,0,0,0,0
        // Decisions: 3 literals, 1 backref, 4 literals
        // 3 literals: A(0x41), B(0x42), C(0x43)
        // Backref: copy 3 bytes from distance 2
        //   ref word: low 4 bits = length-3 = 0, high 12 bits = distance = 2
        //   word = (2 << 4) | 0 = 0x0020
        //   copyPos = output.count(3) - 2 - 1 = 0 → copies A, B, C
        // 4 literals: D(0x44), E(0x45), F(0x46), G(0x47)

        var testData = Data()
        testData.append(contentsOf: [0x00, 0x00]) // groups_minus_1 = 0 (1 group)
        testData.append(0x00)                       // tail_bits = 0
        testData.append(0b0001_0000)                // flag byte
        testData.append(contentsOf: [0x41, 0x42, 0x43])   // 3 literals: A, B, C
        testData.append(contentsOf: [0x20, 0x00])          // backref: distance=2, length=3
        testData.append(contentsOf: [0x44, 0x45, 0x46, 0x47]) // 4 literals: D, E, F, G

        let ct = AnimDecoder.identityColorTable
        let result = AnimDecoder.decompressLZ77(data: testData, offset: 0, colorTable: ct)

        // Expected output: A, B, C, A, B, C, D, E, F, G
        #expect(result.count == 10)
        #expect(result[0] == 0x41) // A
        #expect(result[1] == 0x42) // B
        #expect(result[2] == 0x43) // C
        #expect(result[3] == 0x41) // copied A
        #expect(result[4] == 0x42) // copied B
        #expect(result[5] == 0x43) // copied C
        #expect(result[6] == 0x44) // D
        #expect(result[9] == 0x47) // G
    }

    // MARK: - Animation Decoding

    @Test("decodeAnimation RCSTAND has 1 frame, 8 views, sprite width=16 height=31")
    func testDecodeRCSTAND() throws {
        var data = try loadAnimData()
        data.append(Data(repeating: 0, count: 256)) // safety padding

        let entries = AnimDecoder.parseIndex(from: data)
        guard let rcstand = entries.first(where: { $0.name == "RCSTAND" }) else {
            #expect(Bool(false), "RCSTAND not found in index")
            return
        }

        guard let anim = AnimDecoder.decodeAnimation(from: data, entry: rcstand) else {
            #expect(Bool(false), "Failed to decode RCSTAND")
            return
        }

        #expect(anim.frameCount == 1)
        #expect(anim.viewCount == 8)
        #expect(anim.refs.count == 8) // 1 frame * 8 views

        // Check sprite 0 dimensions
        guard let sprite0 = anim.sprites[0] else {
            #expect(Bool(false), "RCSTAND sprite 0 missing")
            return
        }
        #expect(sprite0.width == 16)
        #expect(sprite0.height == 31)
        #expect(sprite0.pixels.count == 16 * 31)
    }

    @Test("decodeAnimation SKRUN has 8 frames, 8 views, at least 8 unique sprites")
    func testDecodeSKRUN() throws {
        var data = try loadAnimData()
        data.append(Data(repeating: 0, count: 256))

        let entries = AnimDecoder.parseIndex(from: data)
        guard let skrun = entries.first(where: { $0.name == "SKRUN" }) else {
            #expect(Bool(false), "SKRUN not found in index")
            return
        }

        guard let anim = AnimDecoder.decodeAnimation(from: data, entry: skrun) else {
            #expect(Bool(false), "Failed to decode SKRUN")
            return
        }

        #expect(anim.frameCount == 8)
        #expect(anim.viewCount == 8)
        #expect(anim.refs.count == 64) // 8 * 8
        #expect(anim.sprites.count >= 8)
    }

    // MARK: - Palette Loading

    @Test("loadGameplayPalette returns 256 entries with skin tones at 0x10-0x13")
    func testLoadGameplayPalette() {
        let palette = AnimDecoder.loadGameplayPalette()

        #expect(palette.count == 256)

        // Index 0 should be black (or near-black)
        #expect(palette[0].0 == 0)
        #expect(palette[0].1 == 0)
        #expect(palette[0].2 == 0)

        // Skin tone indices (0x10-0x13) should be non-zero
        for i in 0x10...0x13 {
            let (r, g, b) = palette[i]
            let sum = Int(r) + Int(g) + Int(b)
            #expect(sum > 0, "Palette index \(i) should be non-zero (skin tones)")
        }
    }

    // MARK: - Sprite to Image

    @Test("spriteToImage returns valid CGImage with correct dimensions")
    func testSpriteToImage() {
        let palette = AnimDecoder.loadGameplayPalette()
        let sprite = DecodedSprite(
            width: 16, height: 16,
            pixels: [UInt8](repeating: 0x20, count: 256) // all same color
        )

        let img = AnimDecoder.spriteToImage(sprite: sprite, palette: palette)
        #expect(img != nil)
        #expect(img?.width == 16)
        #expect(img?.height == 16)
    }

    @Test("spriteToImage mirrored returns valid image with same dimensions")
    func testSpriteToImageMirrored() {
        let palette = AnimDecoder.loadGameplayPalette()
        // Create a sprite with left-right asymmetry
        var pixels = [UInt8](repeating: 0, count: 4 * 4)
        pixels[0] = 0x20 // top-left colored
        pixels[1] = 0x00 // top-right transparent

        let sprite = DecodedSprite(width: 4, height: 4, pixels: pixels)

        let normal = AnimDecoder.spriteToImage(sprite: sprite, palette: palette, mirrored: false)
        let mirrored = AnimDecoder.spriteToImage(sprite: sprite, palette: palette, mirrored: true)

        #expect(normal != nil)
        #expect(mirrored != nil)
        #expect(normal?.width == mirrored?.width)
        #expect(normal?.height == mirrored?.height)
    }

    @Test("spriteToImage makes palette index 0 transparent")
    func testSpriteToImageTransparency() {
        let palette: [(UInt8, UInt8, UInt8)] = Array(repeating: (128, 128, 128), count: 256)
        // All palette 0 pixels
        let sprite = DecodedSprite(width: 2, height: 2, pixels: [0, 0, 0, 0])

        guard let img = AnimDecoder.spriteToImage(sprite: sprite, palette: palette) else {
            #expect(Bool(false), "spriteToImage returned nil")
            return
        }

        // Extract pixel data from CGImage
        guard let dataProvider = img.dataProvider,
              let pixelData = dataProvider.data else {
            #expect(Bool(false), "Could not extract pixel data")
            return
        }

        let data = pixelData as Data
        // RGBA format: check alpha channel (every 4th byte starting at index 3)
        for i in stride(from: 3, to: data.count, by: 4) {
            #expect(data[i] == 0, "Pixel with palette index 0 should have alpha=0")
        }
    }

    // MARK: - Full Database Loading

    @Test("loadDefault returns 71 animations with approximately 2752 total sprites")
    func testLoadDefault() {
        guard let db = AnimDecoder.loadDefault() else {
            // Skip if game files not available
            print("[Test] ANIM.DAT not available, skipping loadDefault test")
            return
        }

        #expect(db.animations.count == 71)
        #expect(db.palette.count == 256)

        let totalSprites = db.animations.values.reduce(0) { $0 + $1.sprites.count }
        // Should be approximately 2752 but allow some tolerance
        #expect(totalSprites > 2700)
        #expect(totalSprites < 2850)
    }

    // MARK: - Color Tables

    @Test("colorTables has 5 tables of 64 entries each")
    func testColorTablesShape() {
        #expect(AnimDecoder.colorTables.count == 5)
        for (i, table) in AnimDecoder.colorTables.enumerated() {
            #expect(table.count == 64, "Color table \(i) should have 64 entries")
        }
    }

    @Test("identityColorTable maps i to i for 0..<64")
    func testIdentityColorTable() {
        #expect(AnimDecoder.identityColorTable.count == 64)
        for i in 0..<64 {
            #expect(AnimDecoder.identityColorTable[i] == UInt8(i))
        }
    }

    @Test("colorTable0 is outline-only: mostly zeros with 46->0x2E, 47->0x2F")
    func testColorTable0() {
        let ct = AnimDecoder.colorTable0
        #expect(ct[46] == 0x2E)
        #expect(ct[47] == 0x2F)

        // Indices 0-45 should be 0
        for i in 0..<46 {
            #expect(ct[i] == 0, "CT0 index \(i) should be 0")
        }
    }

    @Test("colorTable1 has skin tones at indices 16-19")
    func testColorTable1SkinTones() {
        let ct = AnimDecoder.colorTable1
        #expect(ct[16] == 0x10)
        #expect(ct[17] == 0x11)
        #expect(ct[18] == 0x12)
        #expect(ct[19] == 0x13)
    }
}
