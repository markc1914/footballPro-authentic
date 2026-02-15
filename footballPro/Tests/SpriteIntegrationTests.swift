//
//  SpriteIntegrationTests.swift
//  footballProTests
//
//  Integration tests verifying sprites wire correctly end-to-end:
//  all animation states resolve, all views return valid frames, and transparency works.
//

import Foundation
import Testing
import CoreGraphics
@testable import footballPro

@Suite("Sprite Integration Tests")
struct SpriteIntegrationTests {

    // MARK: - Helpers

    private func ensureCacheLoaded() -> Bool {
        let cache = SpriteCache.shared
        cache.load()
        return cache.isAvailable
    }

    // MARK: - Animation State Resolution

    @Test("Every PlayerAnimState case resolves to a valid animation name for common positions")
    func testAllAnimStatesResolve() {
        let states: [PlayerAnimState] = [
            .standing, .running, .blocking, .tackling, .passing,
            .catching, .diving, .gettingUp, .kicking, .celebrating
        ]
        let positions = ["QB", "RB", "FB", "WR", "TE", "C", "OG", "OT", "DE", "DT", "LB", "CB", "S", "K", "P"]

        for state in states {
            for pos in positions {
                let animName = SpriteCache.animationName(for: state, position: pos, hasBall: false)
                #expect(!animName.isEmpty, "No animation for state=\(state), position=\(pos)")
            }
        }
    }

    @Test("Every resolved animation name exists in the loaded AnimDatabase")
    func testResolvedNamesExistInDatabase() {
        guard ensureCacheLoaded() else {
            print("[Test] Game files not available, skipping database lookup test")
            return
        }

        let states: [PlayerAnimState] = [
            .standing, .running, .blocking, .tackling, .passing,
            .catching, .diving, .gettingUp, .kicking, .celebrating
        ]
        let positions = ["QB", "RB", "WR", "OG", "DE", "LB", "CB", "K", "P"]

        let cache = SpriteCache.shared
        var missing: [String] = []

        for state in states {
            for pos in positions {
                let animName = SpriteCache.animationName(for: state, position: pos, hasBall: false)
                if cache.animationInfo(named: animName) == nil {
                    missing.append("\(state)/\(pos) -> \(animName)")
                }
            }
        }

        #expect(missing.isEmpty, "Missing animations in database: \(missing.joined(separator: ", "))")
    }

    // MARK: - View Direction Coverage

    @Test("All 8 view directions return valid SpriteFrame for SKRUN")
    func testAllViewsSKRUN() {
        guard ensureCacheLoaded() else {
            print("[Test] Game files not available, skipping view direction test")
            return
        }

        let cache = SpriteCache.shared
        for view in 0..<8 {
            let frame = cache.sprite(animation: "SKRUN", frame: 0, view: view)
            #expect(frame != nil, "SKRUN view \(view) returned nil")
            if let f = frame {
                #expect(f.width > 0)
                #expect(f.height > 0)
            }
        }
    }

    @Test("All 8 view directions return valid SpriteFrame for LMRUN")
    func testAllViewsLMRUN() {
        guard ensureCacheLoaded() else { return }

        let cache = SpriteCache.shared
        for view in 0..<8 {
            let frame = cache.sprite(animation: "LMRUN", frame: 0, view: view)
            #expect(frame != nil, "LMRUN view \(view) returned nil")
        }
    }

    // MARK: - Ball Carrier Animation

    @Test("RBRNWB has 8 frames (ball carrier run cycle)")
    func testRBRNWBFrameCount() {
        guard ensureCacheLoaded() else { return }

        let cache = SpriteCache.shared
        let info = cache.animationInfo(named: "RBRNWB")
        #expect(info?.frames == 8, "RBRNWB should have 8 frames")
        #expect(info?.views == 8, "RBRNWB should have 8 views")
    }

    @Test("RBRNWB all 8 frames return valid sprites for view 0")
    func testRBRNWBAllFrames() {
        guard ensureCacheLoaded() else { return }

        let cache = SpriteCache.shared
        for frame in 0..<8 {
            let sprite = cache.sprite(animation: "RBRNWB", frame: frame, view: 0)
            #expect(sprite != nil, "RBRNWB frame \(frame) returned nil")
        }
    }

    // MARK: - Mirror Flag

    @Test("Mirror flag (0x02) sprites return valid images")
    func testMirrorFlagSprites() {
        guard ensureCacheLoaded() else { return }

        // DBREADY is known to have mirrored views (views 1-3 have flag=0x02)
        let cache = SpriteCache.shared
        for view in 0..<8 {
            let frame = cache.sprite(animation: "DBREADY", frame: 0, view: view)
            #expect(frame != nil, "DBREADY view \(view) returned nil")
        }
    }

    // MARK: - Transparency

    @Test("spriteToImage transparency: palette index 0 pixels have alpha=0")
    func testTransparencyInRenderedSprite() {
        let palette: [(UInt8, UInt8, UInt8)] = Array(repeating: (200, 100, 50), count: 256)
        // Create sprite with alternating transparent and colored pixels
        let pixels: [UInt8] = [0, 1, 0, 1, 0, 1, 0, 1, 0] // 3x3
        let sprite = DecodedSprite(width: 3, height: 3, pixels: pixels)

        guard let img = AnimDecoder.spriteToImage(sprite: sprite, palette: palette) else {
            #expect(Bool(false), "spriteToImage returned nil")
            return
        }

        #expect(img.width == 3)
        #expect(img.height == 3)

        // Extract RGBA data
        guard let provider = img.dataProvider, let pixelData = provider.data else {
            #expect(Bool(false), "Could not extract pixel data")
            return
        }

        let data = pixelData as Data
        // Check pixel (0,0) = palette 0 → alpha should be 0
        #expect(data[3] == 0, "Transparent pixel alpha should be 0")
        // Check pixel (1,0) = palette 1 → alpha should be 255
        #expect(data[7] == 255, "Colored pixel alpha should be 255")
    }

    // MARK: - Single-View Animations

    @Test("Single-view animations (EZ*) work correctly")
    func testSingleViewAnimation() {
        guard ensureCacheLoaded() else { return }

        let cache = SpriteCache.shared
        // EZ animations are single-view (end zone celebrations)
        let info = cache.animationInfo(named: "EZSPIKE")
        if let info = info {
            #expect(info.views == 1, "EZSPIKE should be single-view")
            #expect(info.frames == 12)
        }

        // View index should always return 0 for single-view
        #expect(SpriteCache.viewIndex(fromAngle: 90, viewCount: 1) == 0)
    }

    // MARK: - Comprehensive Coverage

    @Test("All 71 animations have at least one valid sprite")
    func testAllAnimationsHaveSprites() {
        guard ensureCacheLoaded() else { return }

        let cache = SpriteCache.shared
        let names = cache.animationNames
        #expect(names.count == 71)

        var failures: [String] = []
        for name in names {
            let frame = cache.sprite(animation: name, frame: 0, view: 0)
            if frame == nil {
                failures.append(name)
            }
        }

        #expect(failures.isEmpty, "Animations with no valid sprite: \(failures.joined(separator: ", "))")
    }
}
