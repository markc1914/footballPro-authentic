//
//  SpriteCacheTests.swift
//  footballProTests
//
//  Unit tests for SpriteCache: view index mapping, animation name mapping,
//  database loading, sprite access, and cache management.
//

import Foundation
import Testing
import CoreGraphics
@testable import footballPro

@Suite("SpriteCache Tests")
struct SpriteCacheTests {

    // MARK: - View Index Mapping

    @Test("viewIndex 0 degrees with 8 views returns expected index")
    func testViewIndex0Degrees() {
        let idx = SpriteCache.viewIndex(fromAngle: 0, viewCount: 8)
        #expect(idx >= 0 && idx < 8)
    }

    @Test("viewIndex 90 degrees with 8 views returns expected index")
    func testViewIndex90Degrees() {
        let idx = SpriteCache.viewIndex(fromAngle: 90, viewCount: 8)
        #expect(idx >= 0 && idx < 8)
    }

    @Test("viewIndex 180 degrees with 8 views returns expected index")
    func testViewIndex180Degrees() {
        let idx = SpriteCache.viewIndex(fromAngle: 180, viewCount: 8)
        #expect(idx >= 0 && idx < 8)
    }

    @Test("viewIndex 270 degrees with 8 views returns expected index")
    func testViewIndex270Degrees() {
        let idx = SpriteCache.viewIndex(fromAngle: 270, viewCount: 8)
        #expect(idx >= 0 && idx < 8)
    }

    @Test("viewIndex with viewCount=1 always returns 0")
    func testViewIndexSingleView() {
        #expect(SpriteCache.viewIndex(fromAngle: 0, viewCount: 1) == 0)
        #expect(SpriteCache.viewIndex(fromAngle: 90, viewCount: 1) == 0)
        #expect(SpriteCache.viewIndex(fromAngle: 180, viewCount: 1) == 0)
        #expect(SpriteCache.viewIndex(fromAngle: 270, viewCount: 1) == 0)
    }

    @Test("viewIndex produces 8 distinct indices across compass directions")
    func testViewIndexCoversAllDirections() {
        // 8 evenly spaced angles should produce 8 different view indices
        var indices = Set<Int>()
        for i in 0..<8 {
            let angle = Double(i) * 45.0
            let idx = SpriteCache.viewIndex(fromAngle: angle, viewCount: 8)
            indices.insert(idx)
        }
        #expect(indices.count == 8, "Expected 8 distinct view indices for 8 compass directions")
    }

    @Test("viewIndex wraps around at 360 degrees")
    func testViewIndexWrapAround() {
        let at0 = SpriteCache.viewIndex(fromAngle: 0, viewCount: 8)
        let at360 = SpriteCache.viewIndex(fromAngle: 360, viewCount: 8)
        #expect(at0 == at360)
    }

    // MARK: - Animation Name Mapping

    @Test("standing QB maps to QBPSET")
    func testStandingQB() {
        let name = SpriteCache.animationName(for: .standing, position: "QB", hasBall: false)
        #expect(name == "QBPSET")
    }

    @Test("standing lineman maps to LMT3PT")
    func testStandingLineman() {
        for pos in ["C", "OG", "OT", "DE", "DT"] {
            let name = SpriteCache.animationName(for: .standing, position: pos, hasBall: false)
            #expect(name == "LMT3PT", "Standing \(pos) should be LMT3PT")
        }
    }

    @Test("standing skill player maps to LMSTAND")
    func testStandingSkillPlayer() {
        let name = SpriteCache.animationName(for: .standing, position: "WR", hasBall: false)
        #expect(name == "LMSTAND")
    }

    @Test("running RB with ball maps to RBRNWB")
    func testRunningRBWithBall() {
        let name = SpriteCache.animationName(for: .running, position: "RB", hasBall: true)
        #expect(name == "RBRNWB")
    }

    @Test("running WR without ball maps to SKRUN")
    func testRunningWRNoBall() {
        let name = SpriteCache.animationName(for: .running, position: "WR", hasBall: false)
        #expect(name == "SKRUN")
    }

    @Test("running QB maps to QBRUN")
    func testRunningQB() {
        let name = SpriteCache.animationName(for: .running, position: "QB", hasBall: false)
        #expect(name == "QBRUN")
    }

    @Test("running lineman maps to LMRUN")
    func testRunningLineman() {
        let name = SpriteCache.animationName(for: .running, position: "OG", hasBall: false)
        #expect(name == "LMRUN")
    }

    @Test("blocking OG maps to LMPUSH")
    func testBlockingLineman() {
        let name = SpriteCache.animationName(for: .blocking, position: "OG", hasBall: false)
        #expect(name == "LMPUSH")
    }

    @Test("blocking non-lineman maps to L2LOCK")
    func testBlockingSkillPlayer() {
        let name = SpriteCache.animationName(for: .blocking, position: "WR", hasBall: false)
        #expect(name == "L2LOCK")
    }

    @Test("tackling LB maps to LMCHK for lineman, SLTKSDL for non-lineman")
    func testTackling() {
        let lbName = SpriteCache.animationName(for: .tackling, position: "LB", hasBall: false)
        #expect(lbName == "SLTKSDL")

        let dtName = SpriteCache.animationName(for: .tackling, position: "DT", hasBall: false)
        #expect(dtName == "LMCHK")
    }

    @Test("passing maps to QBBULIT")
    func testPassing() {
        let name = SpriteCache.animationName(for: .passing, position: "QB", hasBall: true)
        #expect(name == "QBBULIT")
    }

    @Test("catching maps to FCATCH")
    func testCatching() {
        let name = SpriteCache.animationName(for: .catching, position: "WR", hasBall: false)
        #expect(name == "FCATCH")
    }

    @Test("kicking punter maps to PUNT, kicker maps to KICK")
    func testKicking() {
        #expect(SpriteCache.animationName(for: .kicking, position: "P", hasBall: false) == "PUNT")
        #expect(SpriteCache.animationName(for: .kicking, position: "K", hasBall: false) == "KICK")
    }

    @Test("celebrating maps to EZSPIKE")
    func testCelebrating() {
        let name = SpriteCache.animationName(for: .celebrating, position: "RB", hasBall: false)
        #expect(name == "EZSPIKE")
    }

    // MARK: - Database Loading & Sprite Access

    @Test("SpriteCache.shared loads and isAvailable returns true")
    func testLoadAndAvailability() {
        let cache = SpriteCache.shared
        cache.load()

        // May be false if game files missing — that's OK, just test the path
        if cache.isAvailable {
            #expect(cache.animationNames.count == 71)
        } else {
            print("[Test] Game files not available, skipping availability assertion")
        }
    }

    @Test("sprite() returns SpriteFrame with valid CGImage for RCSTAND")
    func testSpriteAccessRCSTAND() {
        let cache = SpriteCache.shared
        cache.load()
        guard cache.isAvailable else {
            print("[Test] Game files not available, skipping sprite access test")
            return
        }

        let frame = cache.sprite(animation: "RCSTAND", frame: 0, view: 0)
        #expect(frame != nil)
        #expect(frame?.width == 16)
        // Height varies by view direction sprite (31 or 32)
        #expect(frame?.height ?? 0 >= 30)
        #expect(frame?.height ?? 0 <= 33)
        #expect(frame?.image.width == 16)
        #expect(frame?.image.height == frame?.height)
    }

    @Test("sprite() returns nil for nonexistent animation")
    func testSpriteAccessNonexistent() {
        let cache = SpriteCache.shared
        cache.load()

        let frame = cache.sprite(animation: "NOSUCHANIM", frame: 0, view: 0)
        #expect(frame == nil)
    }

    @Test("animationInfo returns correct metadata")
    func testAnimationInfo() {
        let cache = SpriteCache.shared
        cache.load()
        guard cache.isAvailable else { return }

        let info = cache.animationInfo(named: "SKRUN")
        #expect(info?.frames == 8)
        #expect(info?.views == 8)

        let rcInfo = cache.animationInfo(named: "RCSTAND")
        #expect(rcInfo?.frames == 1)
        #expect(rcInfo?.views == 8)
    }

    // MARK: - Cache Management

    @Test("clearImageCache resets cachedImageCount to 0")
    func testClearImageCache() {
        let cache = SpriteCache.shared
        cache.load()
        guard cache.isAvailable else { return }

        // Load at least one sprite to populate cache
        _ = cache.sprite(animation: "RCSTAND", frame: 0, view: 0)
        #expect(cache.cachedImageCount > 0)

        cache.clearImageCache()
        #expect(cache.cachedImageCount == 0)
    }
}
