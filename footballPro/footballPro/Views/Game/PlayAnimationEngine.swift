//
//  PlayAnimationEngine.swift
//  footballPro
//
//  Animates football plays in real-time
//  Players run routes, ball carrier moves, tackles happen
//

import SwiftUI

// MARK: - Play Animation Engine

class PlayAnimationEngine: ObservableObject {
    @Published var offensePlayers: [AnimatedPlayer] = []
    @Published var defensePlayers: [AnimatedPlayer] = []
    @Published var ballPosition: CGPoint = .zero
    @Published var ballCarrierId: UUID?
    @Published var isAnimating = false

    private let fieldWidth: CGFloat = 600
    private let fieldHeight: CGFloat = 400

    // MARK: - Animate Play

    func animatePlay(
        playType: PlayType,
        formation: OffensiveFormation,
        yardsGained: Int,
        lineOfScrimmage: Int,
        completion: @escaping () -> Void
    ) async {
        isAnimating = true

        let losX = yardToX(lineOfScrimmage)
        let targetYardLine = lineOfScrimmage + yardsGained
        let targetX = yardToX(targetYardLine)

        switch playType {
        case .shortPass, .mediumPass, .deepPass:
            await animatePassPlay(losX: losX, targetX: targetX, formation: formation, isDeep: playType == .deepPass)
        case .insideRun, .outsideRun, .draw:
            await animateRunPlay(losX: losX, targetX: targetX, formation: formation)
        case .screen:
            await animateScreenPlay(losX: losX, targetX: targetX)
        case .kickoff, .punt, .fieldGoal:
            await animateKickingPlay(losX: losX, targetX: targetX)
        default:
            await animateGenericPlay(losX: losX, targetX: targetX)
        }

        isAnimating = false
        completion()
    }

    // MARK: - Pass Play Animation

    private func animatePassPlay(losX: CGFloat, targetX: CGFloat, formation: OffensiveFormation, isDeep: Bool) async {
        let centerY = fieldHeight / 2

        // Find QB and receiver
        guard let qbIndex = offensePlayers.firstIndex(where: { $0.role == .quarterback }),
              let receiverIndex = offensePlayers.firstIndex(where: { $0.role == .receiver }) else { return }

        // 1. QB drops back (0.5 seconds)
        let dropBackDistance: CGFloat = 15
        await animatePlayerMovement(
            playerIndex: qbIndex,
            isOffense: true,
            targetPosition: CGPoint(x: losX - dropBackDistance, y: centerY),
            duration: 0.5
        )

        // 2. Receiver runs route (1.0 seconds)
        let routeDepth = targetX - losX
        let routeY = isDeep ? centerY - 80 : centerY - 40
        await animatePlayerMovement(
            playerIndex: receiverIndex,
            isOffense: true,
            targetPosition: CGPoint(x: losX + routeDepth, y: routeY),
            duration: 1.0
        )

        // 3. QB throws ball (0.8 seconds - ball travels)
        let ballStart = offensePlayers[qbIndex].position
        let ballEnd = offensePlayers[receiverIndex].position
        await animateBallThrow(from: ballStart, to: ballEnd, duration: 0.8)

        // 4. Receiver catches and runs (0.5 seconds)
        ballCarrierId = offensePlayers[receiverIndex].id
        await animatePlayerMovement(
            playerIndex: receiverIndex,
            isOffense: true,
            targetPosition: CGPoint(x: targetX, y: routeY),
            duration: 0.5
        )

        // 5. Defender tackles
        await showTackle(at: offensePlayers[receiverIndex].position)
    }

    // MARK: - Run Play Animation

    private func animateRunPlay(losX: CGFloat, targetX: CGFloat, formation: OffensiveFormation) async {
        let centerY = fieldHeight / 2

        // Find RB
        guard let rbIndex = offensePlayers.firstIndex(where: { $0.role == .runningback }) else { return }

        // 1. Handoff delay (0.3 seconds)
        try? await Task.sleep(nanoseconds: 300_000_000)
        ballCarrierId = offensePlayers[rbIndex].id

        // 2. RB hits the hole (0.4 seconds to line)
        await animatePlayerMovement(
            playerIndex: rbIndex,
            isOffense: true,
            targetPosition: CGPoint(x: losX + 5, y: centerY),
            duration: 0.4
        )

        // 3. RB breaks through and runs (variable speed based on yards)
        let runDistance = abs(targetX - losX)
        let runDuration = min(1.5, max(0.6, Double(runDistance) / 100.0))

        await animatePlayerMovement(
            playerIndex: rbIndex,
            isOffense: true,
            targetPosition: CGPoint(x: targetX, y: centerY + CGFloat.random(in: -20...20)),
            duration: runDuration
        )

        // 4. Tackle
        await showTackle(at: offensePlayers[rbIndex].position)
    }

    // MARK: - Screen Play Animation

    private func animateScreenPlay(losX: CGFloat, targetX: CGFloat) async {
        let centerY = fieldHeight / 2

        guard let qbIndex = offensePlayers.firstIndex(where: { $0.role == .quarterback }),
              let rbIndex = offensePlayers.firstIndex(where: { $0.role == .runningback }) else { return }

        // 1. QB drops back
        await animatePlayerMovement(
            playerIndex: qbIndex,
            isOffense: true,
            targetPosition: CGPoint(x: losX - 20, y: centerY),
            duration: 0.6
        )

        // 2. RB drifts to flat
        await animatePlayerMovement(
            playerIndex: rbIndex,
            isOffense: true,
            targetPosition: CGPoint(x: losX - 5, y: centerY + 60),
            duration: 0.5
        )

        // 3. QB throws to RB
        await animateBallThrow(
            from: offensePlayers[qbIndex].position,
            to: offensePlayers[rbIndex].position,
            duration: 0.4
        )

        // 4. RB catches and runs
        ballCarrierId = offensePlayers[rbIndex].id
        await animatePlayerMovement(
            playerIndex: rbIndex,
            isOffense: true,
            targetPosition: CGPoint(x: targetX, y: centerY + 60),
            duration: 1.0
        )

        // 5. Tackle
        await showTackle(at: offensePlayers[rbIndex].position)
    }

    // MARK: - Kicking Play Animation

    private func animateKickingPlay(losX: CGFloat, targetX: CGFloat) async {
        let centerY = fieldHeight / 2

        // Ball flies through air
        await animateBallKick(from: CGPoint(x: losX, y: centerY), to: CGPoint(x: targetX, y: centerY), duration: 1.5)

        // Return (if not touchback)
        if targetX < yardToX(100) {
            let returnDistance = CGFloat.random(in: 10...30)
            await animateBallCarrier(from: CGPoint(x: targetX, y: centerY), to: CGPoint(x: targetX - returnDistance, y: centerY), duration: 0.8)
        }
    }

    // MARK: - Generic Play Animation

    private func animateGenericPlay(losX: CGFloat, targetX: CGFloat) async {
        // Simple forward movement
        let centerY = fieldHeight / 2
        await animateBallCarrier(
            from: CGPoint(x: losX, y: centerY),
            to: CGPoint(x: targetX, y: centerY),
            duration: 1.0
        )
    }

    // MARK: - Helper Animations

    private func animatePlayerMovement(playerIndex: Int, isOffense: Bool, targetPosition: CGPoint, duration: Double) async {
        await withCheckedContinuation { continuation in
            withAnimation(.easeInOut(duration: duration)) {
                if isOffense {
                    offensePlayers[playerIndex].position = targetPosition
                } else {
                    defensePlayers[playerIndex].position = targetPosition
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                continuation.resume()
            }
        }
    }

    private func animateBallThrow(from start: CGPoint, to end: CGPoint, duration: Double) async {
        // Arc trajectory
        let controlPoint = CGPoint(
            x: (start.x + end.x) / 2,
            y: min(start.y, end.y) - 50 // Arc height
        )

        await withCheckedContinuation { continuation in
            let steps = 20
            Task {
                for i in 0...steps {
                    let t = CGFloat(i) / CGFloat(steps)

                    // Quadratic bezier curve
                    let x = (1-t)*(1-t)*start.x + 2*(1-t)*t*controlPoint.x + t*t*end.x
                    let y = (1-t)*(1-t)*start.y + 2*(1-t)*t*controlPoint.y + t*t*end.y

                    await MainActor.run {
                        ballPosition = CGPoint(x: x, y: y)
                    }

                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000 / Double(steps)))
                }
                continuation.resume()
            }
        }
    }

    private func animateBallKick(from start: CGPoint, to end: CGPoint, duration: Double) async {
        // High arc for kicks
        let controlPoint = CGPoint(
            x: (start.x + end.x) / 2,
            y: start.y - 100 // High arc
        )

        await animateBallThrow(from: start, to: end, duration: duration)
    }

    private func animateBallCarrier(from start: CGPoint, to end: CGPoint, duration: Double) async {
        await withCheckedContinuation { continuation in
            withAnimation(.easeInOut(duration: duration)) {
                ballPosition = end
            }

            Task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                continuation.resume()
            }
        }
    }

    private func showTackle(at position: CGPoint) async {
        // Flash or impact effect
        try? await Task.sleep(nanoseconds: 200_000_000)
        ballCarrierId = nil
    }

    // MARK: - Utilities

    private func yardToX(_ yard: Int) -> CGFloat {
        let fieldPlayWidth = fieldWidth * 0.9
        let endZoneWidth = fieldWidth * 0.05
        return endZoneWidth + (CGFloat(yard) / 100.0) * fieldPlayWidth
    }
}

// MARK: - Animated Player Model

struct AnimatedPlayer: Identifiable {
    let id: UUID
    var position: CGPoint
    let number: Int
    let isHome: Bool
    let role: PlayerRole
}
