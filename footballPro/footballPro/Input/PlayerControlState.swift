//
//  PlayerControlState.swift
//  footballPro
//
//  On-field player control state for keyboard-driven gameplay during play animation.
//  Tracks which player the user controls, movement direction, and action inputs.
//

import Foundation
import SwiftUI

// MARK: - Control Mode

/// What the user is currently controlling on the field.
public enum ControlMode: Equatable {
    case none           // AI controls everything (pre-snap, or no user input)
    case quarterback    // User controls QB (move in pocket, enter passing mode)
    case ballCarrier    // User controls the ball carrier (run direction, stiff arm, dive)
    case defender       // User controls a defensive player
    case passingMode    // QB in passing mode, cycling/selecting receivers
}

// MARK: - Movement Direction (8-way from WASD/arrows)

public struct MovementInput: Equatable {
    public var up: Bool = false
    public var down: Bool = false
    public var left: Bool = false
    public var right: Bool = false

    /// Normalized direction vector in blueprint flat space.
    /// X = field-length axis (positive = toward opponent end zone when on offense).
    /// Y = lateral axis (positive = toward bottom sideline).
    /// Returns nil when no direction is held.
    public var directionVector: CGVector? {
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        if right { dx += 1 }
        if left  { dx -= 1 }
        if down  { dy += 1 }
        if up    { dy -= 1 }
        guard dx != 0 || dy != 0 else { return nil }
        let len = sqrt(dx * dx + dy * dy)
        return CGVector(dx: dx / len, dy: dy / len)
    }

    /// Reset all directions to false.
    public mutating func reset() {
        up = false; down = false; left = false; right = false
    }
}

// MARK: - Player Control State

/// Complete state of on-field player control during a play.
@MainActor
public class PlayerControlState: ObservableObject {
    @Published public var mode: ControlMode = .none
    @Published public var controlledPlayerIndex: Int = 0  // Index into offense or defense array
    @Published public var movement: MovementInput = MovementInput()

    // Passing mode state
    @Published public var highlightedReceiverIndex: Int = 0     // Which receiver is highlighted (0-4)
    @Published public var eligibleReceiverIndices: [Int] = []   // Player indices of eligible receivers

    // Action flags (set on press, consumed by update loop)
    @Published public var actionPressed: Bool = false    // Space — dive/tackle/enter passing mode
    @Published public var secondaryPressed: Bool = false // X — stiff arm / switch player
    @Published public var throwTarget: Int? = nil        // 1-5 number key → receiver index

    // User-controlled position override in blueprint flat space (640x360)
    @Published public var userPosition: CGPoint? = nil

    // Timing
    @Published public var lastUpdateTime: Date = Date()

    /// Speed in blueprint pixels per second. Scaled by player Speed rating (0-100).
    /// Average player (~70 speed) moves ~100 px/s in 640-wide field = ~17 yards/sec (realistic sprint).
    public static let baseSpeed: CGFloat = 80.0
    public static let maxSpeed: CGFloat = 140.0

    /// Calculate movement speed for a given player speed rating (0-100).
    public static func movementSpeed(forRating rating: Int) -> CGFloat {
        let normalized = CGFloat(max(40, min(rating, 99))) / 100.0
        return baseSpeed + (maxSpeed - baseSpeed) * normalized
    }

    /// Reset all control state for a new play.
    public func reset() {
        mode = .none
        controlledPlayerIndex = 0
        movement.reset()
        highlightedReceiverIndex = 0
        eligibleReceiverIndices = []
        actionPressed = false
        secondaryPressed = false
        throwTarget = nil
        userPosition = nil
        lastUpdateTime = Date()
    }

    /// Begin control for offense after snap.
    public func beginOffensiveControl(qbIndex: Int, receiverIndices: [Int]) {
        mode = .quarterback
        controlledPlayerIndex = qbIndex
        eligibleReceiverIndices = receiverIndices
        highlightedReceiverIndex = 0
        userPosition = nil
    }

    /// Switch to ball carrier control (after handoff or scramble).
    public func switchToBallCarrier(index: Int, currentPosition: CGPoint) {
        mode = .ballCarrier
        controlledPlayerIndex = index
        userPosition = currentPosition
        movement.reset()
    }

    /// Begin defensive control.
    public func beginDefensiveControl(nearestDefenderIndex: Int, currentPosition: CGPoint) {
        mode = .defender
        controlledPlayerIndex = nearestDefenderIndex
        userPosition = currentPosition
        movement.reset()
    }

    /// Enter passing mode from QB control.
    public func enterPassingMode() {
        guard mode == .quarterback else { return }
        mode = .passingMode
        highlightedReceiverIndex = 0
    }

    /// Cycle to next receiver in passing mode.
    public func cycleReceiver() {
        guard mode == .passingMode, !eligibleReceiverIndices.isEmpty else { return }
        highlightedReceiverIndex = (highlightedReceiverIndex + 1) % eligibleReceiverIndices.count
    }

    /// Switch to nearest defender to ball carrier.
    public func switchDefender(toIndex index: Int, currentPosition: CGPoint) {
        guard mode == .defender else { return }
        controlledPlayerIndex = index
        userPosition = currentPosition
        movement.reset()
    }

    /// Update the user-controlled player's position based on current movement input.
    /// Called each frame (~30fps). Returns the new position, or nil if no movement.
    public func updatePosition(dt: CGFloat, speedRating: Int, fieldBounds: CGRect) -> CGPoint? {
        guard let dir = movement.directionVector, var pos = userPosition else { return nil }

        let speed = Self.movementSpeed(forRating: speedRating)
        pos.x += dir.dx * speed * dt
        pos.y += dir.dy * speed * dt

        // Clamp to field bounds
        pos.x = max(fieldBounds.minX, min(pos.x, fieldBounds.maxX))
        pos.y = max(fieldBounds.minY, min(pos.y, fieldBounds.maxY))

        userPosition = pos
        return pos
    }
}
