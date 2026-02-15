//
//  SpriteCache.swift
//  footballPro
//
//  Sprite caching layer for FPS Football Pro '93 ANIM.DAT sprites.
//  Loads the AnimDatabase once and lazily renders sprites to CGImage on first access.
//  Thread-safe via NSLock on the image cache dictionary.
//

import Foundation
import CoreGraphics

// MARK: - Cache Key & Frame Types

struct SpriteCacheKey: Hashable {
    let animName: String
    let spriteID: Int
    let mirrored: Bool
    let colorTable: Int
}

struct SpriteFrame {
    let image: CGImage
    let xOffset: Int8
    let yOffset: Int8
    let width: Int
    let height: Int
    let isMirrored: Bool
}

// MARK: - Player Animation State

enum PlayerAnimState {
    case standing
    case running
    case blocking
    case tackling
    case passing
    case catching
    case diving
    case gettingUp
    case kicking
    case celebrating
}

// MARK: - SpriteCache

final class SpriteCache {
    static let shared = SpriteCache()

    private var database: AnimDatabase?
    private var imageCache: [SpriteCacheKey: CGImage] = [:]
    private let lock = NSLock()
    private var isLoaded = false

    private init() {}

    // MARK: - Loading

    /// Load the animation database from ANIM.DAT. Call once at app startup.
    /// Safe to call multiple times; subsequent calls are no-ops.
    func load() {
        guard !isLoaded else { return }
        database = AnimDecoder.loadDefault()
        isLoaded = true
        if database != nil {
            print("[SpriteCache] Database loaded successfully")
        } else {
            print("[SpriteCache] Warning: AnimDatabase is nil (ANIM.DAT not found?)")
        }
    }

    /// Whether the database has been loaded and is available.
    var isAvailable: Bool {
        database != nil
    }

    // MARK: - Sprite Access

    /// Get a sprite image for a specific animation, frame, and view direction.
    /// Returns nil if animation not found, not yet loaded, or frame/view out of range.
    func sprite(animation: String, frame: Int, view: Int, colorTable: Int = 0) -> SpriteFrame? {
        guard let db = database else { return nil }
        guard let anim = db.animations[animation] else { return nil }

        let viewCount = anim.viewCount
        let frameCount = anim.frameCount
        guard frame >= 0, frame < frameCount else { return nil }

        let clampedView = viewCount > 0 ? view % viewCount : 0
        let refIndex = frame * viewCount + clampedView
        guard refIndex >= 0, refIndex < anim.refs.count else { return nil }

        let ref = anim.refs[refIndex]
        let spriteID = ref.spriteID
        let mirrored = ref.isMirrored

        guard let decodedSprite = anim.sprites[spriteID] else { return nil }

        let key = SpriteCacheKey(
            animName: animation,
            spriteID: spriteID,
            mirrored: mirrored,
            colorTable: colorTable
        )

        // Check cache first (thread-safe)
        lock.lock()
        if let cached = imageCache[key] {
            lock.unlock()
            return SpriteFrame(
                image: cached,
                xOffset: ref.xOffset,
                yOffset: ref.yOffset,
                width: decodedSprite.width,
                height: decodedSprite.height,
                isMirrored: mirrored
            )
        }
        lock.unlock()

        // Render to CGImage
        guard let cgImage = AnimDecoder.spriteToImage(
            sprite: decodedSprite,
            palette: db.palette,
            mirrored: mirrored
        ) else {
            return nil
        }

        // Store in cache (thread-safe)
        lock.lock()
        imageCache[key] = cgImage
        lock.unlock()

        return SpriteFrame(
            image: cgImage,
            xOffset: ref.xOffset,
            yOffset: ref.yOffset,
            width: decodedSprite.width,
            height: decodedSprite.height,
            isMirrored: mirrored
        )
    }

    // MARK: - Animation Info

    /// Get animation metadata (frame count, view count).
    /// Returns nil if animation not found or database not loaded.
    func animationInfo(named name: String) -> (frames: Int, views: Int)? {
        guard let anim = database?.animations[name] else { return nil }
        return (frames: anim.frameCount, views: anim.viewCount)
    }

    /// List all available animation names.
    var animationNames: [String] {
        guard let db = database else { return [] }
        return Array(db.animations.keys).sorted()
    }

    // MARK: - Direction to View Mapping

    /// Convert a movement angle (0-360, 0=right, counterclockwise) to a view index.
    /// Uses the original game formula: (dir+16)>>5 & 7 for 8-view animations.
    /// For single-view animations returns 0.
    static func viewIndex(fromAngle angle: Double, viewCount: Int) -> Int {
        guard viewCount > 1 else { return 0 }

        if viewCount == 8 {
            // Original game formula: (dir+16)>>5 & 7
            // Angle is 0-255 in original; we need to map 0-360 to 0-255
            let dir = Int((angle / 360.0) * 256.0) & 0xFF
            return ((dir + 16) >> 5) & 7
        } else if viewCount == 16 {
            // 16-view variant: (dir+8)>>4 & 15
            let dir = Int((angle / 360.0) * 256.0) & 0xFF
            return ((dir + 8) >> 4) & 15
        } else {
            // Generic fallback: divide 360 degrees evenly
            let step = 360.0 / Double(viewCount)
            return Int((angle + step / 2.0).truncatingRemainder(dividingBy: 360.0) / step) % viewCount
        }
    }

    // MARK: - Animation Name Mapping

    /// Map a player's current state and position to the appropriate ANIM.DAT animation name.
    ///
    /// Position codes: "QB", "FB", "RB", "TE", "WR", "C", "OG", "OT", "DE", "DT", "LB", "CB", "S", "K", "P"
    /// Lineman group: C, OG, OT, DE, DT
    /// Skill group: WR, TE, CB, S, LB, FB, RB
    static func animationName(for state: PlayerAnimState, position: String, hasBall: Bool) -> String {
        let isLineman = ["C", "OG", "OT", "DE", "DT"].contains(position)
        let isQB = position == "QB"
        let isKicker = position == "K"
        let isPunter = position == "P"

        switch state {
        case .standing:
            if isQB { return "QBPSET" }
            if isLineman { return "LMT3PT" }
            return "LMSTAND"

        case .running:
            if isQB { return "QBRUN" }
            if hasBall { return "RBRNWB" }
            if isLineman { return "LMRUN" }
            return "SKRUN"

        case .blocking:
            if isLineman { return "LMPUSH" }
            return "L2LOCK"

        case .tackling:
            if isLineman { return "LMCHK" }
            return "SLTKSDL"

        case .passing:
            return "QBBULIT"

        case .catching:
            return "FCATCH"

        case .diving:
            if isLineman { return "LMDIVE" }
            return "SKDIVE"

        case .gettingUp:
            if isLineman { return "LMGETUPF" }
            return "SKSTUP"

        case .kicking:
            if isPunter { return "PUNT" }
            return "KICK"

        case .celebrating:
            return "EZSPIKE"
        }
    }

    // MARK: - Cache Management

    /// Clear the image cache to free memory. The database remains loaded.
    func clearImageCache() {
        lock.lock()
        imageCache.removeAll()
        lock.unlock()
        print("[SpriteCache] Image cache cleared")
    }

    /// Number of cached CGImage entries.
    var cachedImageCount: Int {
        lock.lock()
        let count = imageCache.count
        lock.unlock()
        return count
    }
}
