//
//  PlayerAnimationState.swift
//  footballPro
//
//  Per-player animation state machine for independent ~15fps sprite animation.
//  Each player tracks their current animation, frame index, and timing.
//

import Foundation

struct PlayerAnimationState {
    /// Current ANIM.DAT animation name (e.g. "SKRUN", "LMPUSH")
    var animationName: String = "LMSTAND"

    /// Total frames in current animation
    var frameCount: Int = 1

    /// Number of view directions in current animation
    var viewCount: Int = 8

    /// Accumulated time since animation started (seconds)
    var elapsedTime: Double = 0

    /// Whether this animation loops or plays once and holds on last frame
    var isLooping: Bool = true

    /// Target sprite frame rate (~15fps matches original FPS '93 feel)
    static let fps: Double = 15.0

    /// Switch to a new animation, resetting frame and timing.
    mutating func transition(to animName: String, frames: Int, views: Int, loops: Bool) {
        guard animName != animationName else { return }
        animationName = animName
        frameCount = max(1, frames)
        viewCount = max(1, views)
        isLooping = loops
        elapsedTime = 0
    }

    /// Determine if a given animation name should loop or play once.
    static func isLoopingAnimation(_ name: String) -> Bool {
        switch name {
        // Looping: run cycles, stances, pushing/blocking
        case "SKRUN", "LMRUN", "QBRUN", "RBRNWB",
             "LMPUSH", "L2LOCK",
             "LMT3PT", "LMT4PT", "LMSTAND", "QBPSET",
             "DBREADY", "DBPREBZ", "BNDOVER",
             "LMSPINCC", "LMSPINCW",
             "RCSTAND", "LMBBUT":
            return true
        // Everything else is one-shot (snaps, catches, tackles, throws, celebrations, getting up, etc.)
        default:
            return false
        }
    }
}
