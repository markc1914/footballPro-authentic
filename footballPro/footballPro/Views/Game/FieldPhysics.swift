//
//  FieldPhysics.swift
//  footballPro
//
//  Physics calculations for realistic field animations
//

import SwiftUI

// MARK: - Field Physics Helpers

struct FieldPhysics {

    // MARK: - Pass Trajectory

    /// Calculate parabolic arc for a football pass
    /// Returns array of points along the arc for animation
    static func calculatePassArc(
        from start: CGPoint,
        to end: CGPoint,
        power: Double,      // 0-100 (QB throw power)
        accuracy: Double,   // 0-100 (QB accuracy)
        isDeep: Bool = false
    ) -> [CGPoint] {
        let distance = end.x - start.x

        // Calculate peak height based on pass distance and power
        let baseHeight: Double
        if isDeep {
            baseHeight = -80.0  // Deep passes arc higher
        } else if abs(distance) < 50 {
            baseHeight = -30.0  // Short passes have lower arc
        } else {
            baseHeight = -50.0  // Medium passes
        }

        // Adjust height for power (stronger throw = higher arc)
        let peakHeight = baseHeight * (power / 100.0)

        // Calculate control point for quadratic bezier curve
        let controlX = (start.x + end.x) / 2
        let controlY = min(start.y, end.y) + peakHeight

        // Add wobble for inaccurate passes
        let wobbleX = accuracy < 70 ? Double.random(in: -10...10) : 0
        let wobbleY = accuracy < 70 ? Double.random(in: -15...15) : 0

        let controlPoint = CGPoint(
            x: controlX + wobbleX,
            y: controlY + wobbleY
        )

        // Generate points along the arc
        var points: [CGPoint] = []
        let steps = 20

        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let point = quadraticBezierPoint(
                t: t,
                p0: start,
                p1: controlPoint,
                p2: end
            )
            points.append(point)
        }

        return points
    }

    /// Calculate point on quadratic bezier curve
    private static func quadraticBezierPoint(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let x = pow(1 - t, 2) * p0.x + 2 * (1 - t) * t * p1.x + pow(t, 2) * p2.x
        let y = pow(1 - t, 2) * p0.y + 2 * (1 - t) * t * p1.y + pow(t, 2) * p2.y
        return CGPoint(x: x, y: y)
    }

    // MARK: - Player Movement

    /// Calculate smooth acceleration path for player movement
    static func calculateRunPath(
        from start: CGPoint,
        to end: CGPoint,
        speed: Double,          // 0-100 (player speed rating)
        acceleration: Double    // 0-100 (player acceleration)
    ) -> AnimationCurve {
        // Calculate duration based on speed
        let baseTime = 1.0
        let speedFactor = speed / 100.0
        let duration = baseTime / max(0.5, speedFactor)

        // Calculate easing based on acceleration
        let accelFactor = acceleration / 100.0

        return AnimationCurve(
            duration: duration,
            easing: .easeInOut,
            accelerationFactor: accelFactor
        )
    }

    /// Calculate cut/juke movement (lateral acceleration)
    static func calculateCutPath(
        from start: CGPoint,
        direction: CGVector,
        cutSharpness: Double  // 0-100 (agility rating)
    ) -> [CGPoint] {
        var points: [CGPoint] = []
        let steps = 10

        // Sharp cuts for high agility, gradual for low agility
        let curveFactor = cutSharpness / 100.0

        for i in 0...steps {
            let t = Double(i) / Double(steps)
            // Use sine curve for smooth cut
            let easedT = sin(t * .pi / 2) * curveFactor + t * (1 - curveFactor)

            let x = start.x + direction.dx * easedT
            let y = start.y + direction.dy * easedT
            points.append(CGPoint(x: x, y: y))
        }

        return points
    }

    // MARK: - Collision Detection

    /// Check if two players are colliding (for tackles)
    static func checkCollision(
        player1: CGPoint,
        player2: CGPoint,
        radius: Double = 15.0  // Tackle radius in points
    ) -> Bool {
        let distance = sqrt(pow(player2.x - player1.x, 2) + pow(player2.y - player1.y, 2))
        return distance < radius
    }

    /// Calculate tackle impact direction
    static func calculateTackleImpact(
        tackler: CGPoint,
        ballCarrier: CGPoint,
        velocity: CGVector
    ) -> CGVector {
        // Direction from tackler to ball carrier
        let dx = ballCarrier.x - tackler.x
        let dy = ballCarrier.y - tackler.y
        let magnitude = sqrt(dx * dx + dy * dy)

        if magnitude == 0 { return .zero }

        // Normalize and apply velocity
        let impactX = (dx / magnitude) * velocity.dx * 0.5
        let impactY = (dy / magnitude) * velocity.dy * 0.5

        return CGVector(dx: impactX, dy: impactY)
    }

    // MARK: - Formation Positioning

    /// Get realistic player positions for formations
    static func getFormationPositions(
        formation: OffensiveFormation,
        lineOfScrimmage: Double,
        fieldWidth: Double,
        fieldHeight: Double
    ) -> [FormationPosition] {
        let los = lineOfScrimmage
        let yToX: (Int) -> Double = { yard in Double(yard) / 100.0 * fieldWidth }

        switch formation {
        case .shotgun:
            return [
                // QB in shotgun (5 yards back)
                FormationPosition(label: "QB", position: CGPoint(x: yToX(Int(los) - 5), y: fieldHeight / 2)),
                // RB beside QB
                FormationPosition(label: "RB", position: CGPoint(x: yToX(Int(los) - 4), y: fieldHeight / 2 - 25)),
                // 5 offensive linemen
                FormationPosition(label: "LT", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 - 40)),
                FormationPosition(label: "LG", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 - 20)),
                FormationPosition(label: "C", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2)),
                FormationPosition(label: "RG", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 + 20)),
                FormationPosition(label: "RT", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 + 40)),
                // Spread receivers
                FormationPosition(label: "WR", position: CGPoint(x: yToX(Int(los) + 1), y: 15)),
                FormationPosition(label: "WR", position: CGPoint(x: yToX(Int(los)), y: fieldHeight - 15)),
                FormationPosition(label: "WR", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 - 60)),
                FormationPosition(label: "TE", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 + 55))
            ]

        case .iFormation:
            return [
                // QB under center
                FormationPosition(label: "QB", position: CGPoint(x: yToX(Int(los) - 1), y: fieldHeight / 2)),
                // FB 3 yards back
                FormationPosition(label: "FB", position: CGPoint(x: yToX(Int(los) - 4), y: fieldHeight / 2)),
                // HB 5 yards back
                FormationPosition(label: "HB", position: CGPoint(x: yToX(Int(los) - 6), y: fieldHeight / 2)),
                // 5 offensive linemen
                FormationPosition(label: "LT", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 - 35)),
                FormationPosition(label: "LG", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 - 18)),
                FormationPosition(label: "C", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2)),
                FormationPosition(label: "RG", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 + 18)),
                FormationPosition(label: "RT", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 + 35)),
                // TEs and WRs
                FormationPosition(label: "TE", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 - 50)),
                FormationPosition(label: "WR", position: CGPoint(x: yToX(Int(los)), y: 12)),
                FormationPosition(label: "WR", position: CGPoint(x: yToX(Int(los)), y: fieldHeight - 12))
            ]

        case .singleback:
            return [
                // QB under center
                FormationPosition(label: "QB", position: CGPoint(x: yToX(Int(los) - 1), y: fieldHeight / 2)),
                // Single RB
                FormationPosition(label: "RB", position: CGPoint(x: yToX(Int(los) - 5), y: fieldHeight / 2)),
                // 5 offensive linemen
                FormationPosition(label: "LT", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 - 35)),
                FormationPosition(label: "LG", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 - 18)),
                FormationPosition(label: "C", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2)),
                FormationPosition(label: "RG", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 + 18)),
                FormationPosition(label: "RT", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 + 35)),
                // 2 TEs, 2 WRs
                FormationPosition(label: "TE", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 - 50)),
                FormationPosition(label: "TE", position: CGPoint(x: yToX(Int(los)), y: fieldHeight / 2 + 50)),
                FormationPosition(label: "WR", position: CGPoint(x: yToX(Int(los)), y: 12)),
                FormationPosition(label: "WR", position: CGPoint(x: yToX(Int(los)), y: fieldHeight - 12))
            ]

        default:
            // Default to I-Formation
            return getFormationPositions(
                formation: .iFormation,
                lineOfScrimmage: lineOfScrimmage,
                fieldWidth: fieldWidth,
                fieldHeight: fieldHeight
            )
        }
    }

    /// Get defensive formation positions
    static func getDefensiveFormationPositions(
        formation: DefensiveFormation,
        lineOfScrimmage: Double,
        fieldWidth: Double,
        fieldHeight: Double
    ) -> [FormationPosition] {
        let los = lineOfScrimmage
        let yToX: (Int) -> Double = { yard in Double(yard) / 100.0 * fieldWidth }

        switch formation {
        case .base43:
            return [
                // 4 down linemen
                FormationPosition(label: "DE", position: CGPoint(x: yToX(Int(los) + 1), y: fieldHeight / 2 - 45)),
                FormationPosition(label: "DT", position: CGPoint(x: yToX(Int(los) + 1), y: fieldHeight / 2 - 15)),
                FormationPosition(label: "DT", position: CGPoint(x: yToX(Int(los) + 1), y: fieldHeight / 2 + 15)),
                FormationPosition(label: "DE", position: CGPoint(x: yToX(Int(los) + 1), y: fieldHeight / 2 + 45)),
                // 3 linebackers
                FormationPosition(label: "LB", position: CGPoint(x: yToX(Int(los) + 4), y: fieldHeight / 2 - 30)),
                FormationPosition(label: "LB", position: CGPoint(x: yToX(Int(los) + 3), y: fieldHeight / 2)),
                FormationPosition(label: "LB", position: CGPoint(x: yToX(Int(los) + 4), y: fieldHeight / 2 + 30)),
                // 2 corners, 2 safeties
                FormationPosition(label: "CB", position: CGPoint(x: yToX(Int(los) + 8), y: 18)),
                FormationPosition(label: "CB", position: CGPoint(x: yToX(Int(los) + 8), y: fieldHeight - 18)),
                FormationPosition(label: "S", position: CGPoint(x: yToX(Int(los) + 15), y: fieldHeight / 2 - 40)),
                FormationPosition(label: "S", position: CGPoint(x: yToX(Int(los) + 15), y: fieldHeight / 2 + 40))
            ]

        case .nickel:
            return [
                // 4 down linemen
                FormationPosition(label: "DE", position: CGPoint(x: yToX(Int(los) + 1), y: fieldHeight / 2 - 40)),
                FormationPosition(label: "DT", position: CGPoint(x: yToX(Int(los) + 1), y: fieldHeight / 2 - 12)),
                FormationPosition(label: "DT", position: CGPoint(x: yToX(Int(los) + 1), y: fieldHeight / 2 + 12)),
                FormationPosition(label: "DE", position: CGPoint(x: yToX(Int(los) + 1), y: fieldHeight / 2 + 40)),
                // 2 linebackers (nickel = extra DB)
                FormationPosition(label: "LB", position: CGPoint(x: yToX(Int(los) + 3), y: fieldHeight / 2 - 25)),
                FormationPosition(label: "LB", position: CGPoint(x: yToX(Int(los) + 3), y: fieldHeight / 2 + 25)),
                // 5 DBs
                FormationPosition(label: "CB", position: CGPoint(x: yToX(Int(los) + 8), y: 15)),
                FormationPosition(label: "CB", position: CGPoint(x: yToX(Int(los) + 8), y: fieldHeight - 15)),
                FormationPosition(label: "CB", position: CGPoint(x: yToX(Int(los) + 6), y: fieldHeight / 2)),  // Nickel back
                FormationPosition(label: "S", position: CGPoint(x: yToX(Int(los) + 14), y: fieldHeight / 2 - 35)),
                FormationPosition(label: "S", position: CGPoint(x: yToX(Int(los) + 14), y: fieldHeight / 2 + 35))
            ]

        default:
            // Default to 4-3
            return getDefensiveFormationPositions(
                formation: .base43,
                lineOfScrimmage: lineOfScrimmage,
                fieldWidth: fieldWidth,
                fieldHeight: fieldHeight
            )
        }
    }
}

// MARK: - Supporting Types

struct AnimationCurve {
    var duration: Double
    var easing: Animation
    var accelerationFactor: Double
}

struct FormationPosition {
    var label: String
    var position: CGPoint
}

// MARK: - CGPoint Extensions

extension CGPoint {
    func distance(to other: CGPoint) -> Double {
        return sqrt(pow(other.x - x, 2) + pow(other.y - y, 2))
    }

    func angle(to other: CGPoint) -> Double {
        return atan2(other.y - y, other.x - x)
    }
}
