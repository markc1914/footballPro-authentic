//
//  PlayBlueprintGenerator.swift
//  footballPro
//
//  Converts PlayArt + DefensivePlayArt + PlayResult into a complete
//  PlayAnimationBlueprint with waypoint paths for all 22 players + ball.
//

import SwiftUI

// MARK: - Play Blueprint Generator

struct PlayBlueprintGenerator {

    // Field dimensions (must match FPSFieldView)
    static let fieldWidth: CGFloat = 640
    static let fieldHeight: CGFloat = 360

    /// Yards-per-pixel scale on the field canvas (play area is 90% of field width)
    private static let playFieldWidth: CGFloat = fieldWidth * 0.90
    private static let endZoneWidth: CGFloat = fieldWidth * 0.05
    private static let yardsPerPixel: CGFloat = playFieldWidth / 100.0 // ~5.76 px per yard

    // MARK: - Public API

    /// Generate a complete animation blueprint for one play.
    static func generateBlueprint(
        playArt: PlayArt?,
        defensiveArt: DefensivePlayArt?,
        result: PlayResult,
        los: Int,               // Line of scrimmage yard line (0-100)
        fieldWidth: CGFloat = 640,
        fieldHeight: CGFloat = 360
    ) -> PlayAnimationBlueprint {

        let losX = yardToX(los)
        let centerY = fieldHeight / 2

        // Total duration scales with play type
        let totalDuration = playDuration(for: result)

        // Phase timing (normalized 0–1)
        let phases = buildPhases(for: result, duration: totalDuration)

        // Build offensive player paths (11 players)
        let offPaths = buildOffensivePaths(
            playArt: playArt,
            result: result,
            losX: losX,
            centerY: centerY,
            totalDuration: totalDuration,
            phases: phases
        )

        // Build defensive player paths (11 players)
        let defPaths = buildDefensivePaths(
            defensiveArt: defensiveArt,
            result: result,
            losX: losX,
            centerY: centerY,
            totalDuration: totalDuration,
            phases: phases,
            offensivePaths: offPaths
        )

        // Build ball path
        let ballPath = buildBallPath(
            playArt: playArt,
            result: result,
            losX: losX,
            centerY: centerY,
            offPaths: offPaths,
            totalDuration: totalDuration,
            phases: phases
        )

        return PlayAnimationBlueprint(
            offensivePaths: offPaths,
            defensivePaths: defPaths,
            ballPath: ballPath,
            totalDuration: totalDuration,
            phases: phases
        )
    }

    // MARK: - Phase Building

    private static func buildPhases(for result: PlayResult, duration: Double) -> [AnimationPhase] {
        // Timing varies by play type
        let isPass = result.playType.isPass
        let isKick = result.playType == .kickoff || result.playType == .punt

        if isKick {
            return [
                AnimationPhase(name: .preSnap, startTime: 0.0, endTime: 0.05),
                AnimationPhase(name: .snap, startTime: 0.05, endTime: 0.15),
                AnimationPhase(name: .resolution, startTime: 0.15, endTime: 0.7),
                AnimationPhase(name: .yac, startTime: 0.7, endTime: 0.9),
                AnimationPhase(name: .tackle, startTime: 0.9, endTime: 1.0)
            ]
        }

        if isPass {
            return [
                AnimationPhase(name: .preSnap, startTime: 0.0, endTime: 0.05),
                AnimationPhase(name: .snap, startTime: 0.05, endTime: 0.12),
                AnimationPhase(name: .routesDevelop, startTime: 0.12, endTime: 0.55),
                AnimationPhase(name: .resolution, startTime: 0.55, endTime: 0.72),
                AnimationPhase(name: .yac, startTime: 0.72, endTime: 0.88),
                AnimationPhase(name: .tackle, startTime: 0.88, endTime: 1.0)
            ]
        }

        // Run play
        return [
            AnimationPhase(name: .preSnap, startTime: 0.0, endTime: 0.05),
            AnimationPhase(name: .snap, startTime: 0.05, endTime: 0.15),
            AnimationPhase(name: .routesDevelop, startTime: 0.15, endTime: 0.45),
            AnimationPhase(name: .resolution, startTime: 0.45, endTime: 0.75),
            AnimationPhase(name: .yac, startTime: 0.75, endTime: 0.9),
            AnimationPhase(name: .tackle, startTime: 0.9, endTime: 1.0)
        ]
    }

    private static func playDuration(for result: PlayResult) -> Double {
        switch result.playType {
        case .deepPass:
            return 6.0
        case .mediumPass, .playAction:
            return 5.0
        case .shortPass, .screen:
            return 4.5
        case .insideRun, .draw:
            return 4.5
        case .outsideRun, .sweep, .counter:
            return 5.0
        case .kickoff, .punt:
            return 5.5
        default:
            return 4.5
        }
    }

    // MARK: - Offensive Paths

    private static func buildOffensivePaths(
        playArt: PlayArt?,
        result: PlayResult,
        losX: CGFloat,
        centerY: CGFloat,
        totalDuration: Double,
        phases: [AnimationPhase]
    ) -> [AnimatedPlayerPath] {

        var paths: [AnimatedPlayerPath] = []

        // Starting positions for 11 offensive players (must match FPSFieldView.createOffensiveFormation)
        let formation = playArt?.formation ?? .shotgun
        let startPositions = offensiveStartPositions(formation: formation, losX: losX, centerY: centerY)
        let roles: [PlayerRole] = [
            .lineman, .lineman, .lineman, .lineman, .lineman,  // OL (indices 0-4)
            .quarterback,                                        // QB (index 5)
            .runningback,                                        // RB (index 6)
            .receiver, .receiver,                                // WR1, WR2 (indices 7, 8)
            .tightend,                                           // TE (index 9)
            .receiver                                            // Slot (index 10)
        ]

        let routeStart = phaseTime(phases, .routesDevelop)?.startTime ?? 0.12
        let routeEnd = phaseTime(phases, .routesDevelop)?.endTime ?? 0.55
        let resolutionStart = phaseTime(phases, .resolution)?.startTime ?? 0.55
        let resolutionEnd = phaseTime(phases, .resolution)?.endTime ?? 0.72
        let yacEnd = phaseTime(phases, .yac)?.endTime ?? 0.88
        let tackleEnd: Double = 1.0

        let isPass = result.playType.isPass
        let isRun = result.playType.isRun

        // Build route lookup from PlayArt
        var routeLookup: [PlayerPosition: PlayRoute] = [:]
        if let art = playArt {
            for route in art.routes {
                routeLookup[route.position] = route
            }
        }

        let positionMap: [Int: PlayerPosition] = [
            0: .leftTackle, 1: .leftGuard, 2: .center, 3: .rightGuard, 4: .rightTackle,
            5: .quarterback, 6: .runningBack, 7: .wideReceiverLeft, 8: .wideReceiverRight,
            9: .tightEnd, 10: .slotReceiver
        ]

        let gainPixels = CGFloat(result.yardsGained) * yardsPerPixel
        let targetX = losX + gainPixels

        for i in 0..<11 {
            let start = startPositions[i]
            let role = roles[i]
            var waypoints: [AnimationWaypoint] = []

            // Start position (pre-snap)
            waypoints.append(AnimationWaypoint(position: start, time: 0.0, speed: .slow))
            waypoints.append(AnimationWaypoint(position: start, time: routeStart, speed: .slow))

            // Get the route for this position
            let position = positionMap[i]
            let route = position.flatMap { routeLookup[$0] }

            switch role {
            case .lineman:
                // Offensive line blocking
                if isPass {
                    // Pass block: step back, hold
                    let blockPos = CGPoint(x: start.x - 6, y: start.y + CGFloat.random(in: -3...3))
                    waypoints.append(AnimationWaypoint(position: blockPos, time: routeStart + 0.05, speed: .normal))
                    // Hold with minor jostling
                    let jostle1 = CGPoint(x: blockPos.x + CGFloat.random(in: -3...3), y: blockPos.y + CGFloat.random(in: -4...4))
                    waypoints.append(AnimationWaypoint(position: jostle1, time: routeEnd, speed: .slow))
                    let jostle2 = CGPoint(x: blockPos.x + CGFloat.random(in: -2...2), y: blockPos.y + CGFloat.random(in: -3...3))
                    waypoints.append(AnimationWaypoint(position: jostle2, time: tackleEnd, speed: .slow))
                } else {
                    // Run block: push forward
                    let isPlayside = (i <= 2 && result.yardsGained > 0) || (i >= 3)
                    let pushDist: CGFloat = isPlayside ? 18 : 10
                    let blockTarget = CGPoint(x: start.x + pushDist, y: start.y + CGFloat.random(in: -8...8))
                    waypoints.append(AnimationWaypoint(position: blockTarget, time: routeEnd, speed: .fast))
                    // Continue downfield
                    let finalBlock = CGPoint(x: min(start.x + pushDist + 15, targetX), y: blockTarget.y)
                    waypoints.append(AnimationWaypoint(position: finalBlock, time: tackleEnd, speed: .normal))
                }

            case .quarterback:
                if isPass {
                    // Drop back
                    let dropDepth: CGFloat = result.playType == .deepPass ? -35 : (result.playType == .mediumPass ? -25 : -18)
                    let dropPos = CGPoint(x: start.x + dropDepth, y: centerY + CGFloat.random(in: -5...5))
                    waypoints.append(AnimationWaypoint(position: dropPos, time: routeStart + 0.08, speed: .fast))
                    // Hold in pocket
                    let pocketPos = CGPoint(x: dropPos.x + CGFloat.random(in: -3...3), y: dropPos.y + CGFloat.random(in: -5...5))
                    waypoints.append(AnimationWaypoint(position: pocketPos, time: resolutionStart, speed: .slow))

                    if result.description.lowercased().contains("sack") {
                        // Sacked: pushed back
                        let sackPos = CGPoint(x: dropPos.x - 10, y: dropPos.y)
                        waypoints.append(AnimationWaypoint(position: sackPos, time: resolutionEnd, speed: .slow))
                        waypoints.append(AnimationWaypoint(position: sackPos, time: tackleEnd, speed: .slow))
                    } else {
                        // Throw and stand
                        waypoints.append(AnimationWaypoint(position: pocketPos, time: tackleEnd, speed: .slow))
                    }
                } else if isRun {
                    // Handoff: step back slightly then hold
                    let handoffPos = CGPoint(x: start.x - 8, y: centerY)
                    waypoints.append(AnimationWaypoint(position: handoffPos, time: routeStart + 0.05, speed: .normal))
                    // Fake and hold position
                    waypoints.append(AnimationWaypoint(position: handoffPos, time: tackleEnd, speed: .slow))
                } else {
                    waypoints.append(AnimationWaypoint(position: start, time: tackleEnd, speed: .slow))
                }

            case .runningback, .runningBack:
                if let route = route, isRun {
                    // Run play: follow route path
                    let routeWaypoints = generateRouteWaypoints(
                        route: route,
                        start: start,
                        losX: losX,
                        centerY: centerY,
                        routeStart: routeStart + 0.03,
                        routeEnd: routeEnd
                    )
                    waypoints.append(contentsOf: routeWaypoints)
                    // Continue to gain/loss point
                    let finalPos = CGPoint(x: targetX, y: routeWaypoints.last?.position.y ?? centerY + CGFloat.random(in: -20...20))
                    waypoints.append(AnimationWaypoint(position: finalPos, time: yacEnd, speed: .sprint))
                    waypoints.append(AnimationWaypoint(position: finalPos, time: tackleEnd, speed: .slow))
                } else if isPass, let route = route {
                    // Pass route for RB
                    let routeWaypoints = generateRouteWaypoints(
                        route: route,
                        start: start,
                        losX: losX,
                        centerY: centerY,
                        routeStart: routeStart,
                        routeEnd: routeEnd
                    )
                    waypoints.append(contentsOf: routeWaypoints)
                    waypoints.append(AnimationWaypoint(position: routeWaypoints.last?.position ?? start, time: tackleEnd, speed: .normal))
                } else {
                    // Default: step up as blocker
                    let blockPos = CGPoint(x: start.x + 5, y: start.y)
                    waypoints.append(AnimationWaypoint(position: blockPos, time: routeEnd, speed: .normal))
                    waypoints.append(AnimationWaypoint(position: blockPos, time: tackleEnd, speed: .slow))
                }

            case .receiver:
                if let route = route {
                    let routeWaypoints = generateRouteWaypoints(
                        route: route,
                        start: start,
                        losX: losX,
                        centerY: centerY,
                        routeStart: routeStart,
                        routeEnd: routeEnd
                    )
                    waypoints.append(contentsOf: routeWaypoints)

                    // After route: if this is the target receiver, YAC
                    let isTarget = isTargetReceiver(playerIndex: i, result: result, playArt: playArt)
                    if isTarget && isPass && result.yardsGained > 0 && !result.isTurnover {
                        let catchPos = routeWaypoints.last?.position ?? start
                        let yacPos = CGPoint(x: targetX, y: catchPos.y + CGFloat.random(in: -10...10))
                        waypoints.append(AnimationWaypoint(position: yacPos, time: yacEnd, speed: .sprint))
                        waypoints.append(AnimationWaypoint(position: yacPos, time: tackleEnd, speed: .slow))
                    } else {
                        // Non-target: slow down at route endpoint
                        let endPos = routeWaypoints.last?.position ?? start
                        waypoints.append(AnimationWaypoint(position: endPos, time: tackleEnd, speed: .slow))
                    }
                } else {
                    // No route assigned: run a default fly/block
                    let defaultEnd = CGPoint(x: start.x + 40, y: start.y + CGFloat.random(in: -10...10))
                    waypoints.append(AnimationWaypoint(position: defaultEnd, time: routeEnd, speed: .fast))
                    waypoints.append(AnimationWaypoint(position: defaultEnd, time: tackleEnd, speed: .slow))
                }

            case .tightend:
                if let route = route {
                    let routeWaypoints = generateRouteWaypoints(
                        route: route,
                        start: start,
                        losX: losX,
                        centerY: centerY,
                        routeStart: routeStart,
                        routeEnd: routeEnd
                    )
                    waypoints.append(contentsOf: routeWaypoints)
                    waypoints.append(AnimationWaypoint(position: routeWaypoints.last?.position ?? start, time: tackleEnd, speed: .normal))
                } else if isRun {
                    // Block
                    let blockTarget = CGPoint(x: start.x + 15, y: start.y + (result.yardsGained > 0 ? 5 : -5))
                    waypoints.append(AnimationWaypoint(position: blockTarget, time: routeEnd, speed: .fast))
                    waypoints.append(AnimationWaypoint(position: blockTarget, time: tackleEnd, speed: .slow))
                } else {
                    let defaultEnd = CGPoint(x: start.x + 25, y: start.y + 8)
                    waypoints.append(AnimationWaypoint(position: defaultEnd, time: routeEnd, speed: .fast))
                    waypoints.append(AnimationWaypoint(position: defaultEnd, time: tackleEnd, speed: .slow))
                }

            default:
                waypoints.append(AnimationWaypoint(position: start, time: tackleEnd, speed: .slow))
            }

            paths.append(AnimatedPlayerPath(playerIndex: i, role: role, waypoints: waypoints))
        }

        return paths
    }

    // MARK: - Defensive Paths

    private static func buildDefensivePaths(
        defensiveArt: DefensivePlayArt?,
        result: PlayResult,
        losX: CGFloat,
        centerY: CGFloat,
        totalDuration: Double,
        phases: [AnimationPhase],
        offensivePaths: [AnimatedPlayerPath]
    ) -> [AnimatedPlayerPath] {

        var paths: [AnimatedPlayerPath] = []

        let startPositions = defensiveStartPositions(formation: defensiveArt?.formation ?? .base43, losX: losX, centerY: centerY)
        let roles: [PlayerRole] = [
            .defensiveLine, .defensiveLine, .defensiveLine, .defensiveLine,  // DL (0-3)
            .linebacker, .linebacker, .linebacker,                            // LB (4-6)
            .defensiveBack, .defensiveBack,                                   // CB (7-8)
            .defensiveBack, .defensiveBack                                    // S (9-10)
        ]

        let routeStart = phaseTime(phases, .routesDevelop)?.startTime ?? 0.12
        let routeEnd = phaseTime(phases, .routesDevelop)?.endTime ?? 0.55
        let resolutionEnd = phaseTime(phases, .resolution)?.endTime ?? 0.72
        let yacEnd = phaseTime(phases, .yac)?.endTime ?? 0.88
        let tackleEnd: Double = 1.0

        let isPass = result.playType.isPass
        let gainPixels = CGFloat(result.yardsGained) * yardsPerPixel
        let ballCarrierFinalX = losX + gainPixels

        // Build assignment lookup
        var assignmentLookup: [Int: DefensiveAssignment] = [:]
        var depthLookup: [Int: Int] = [:]
        var sideLookup: [Int: DefensiveSide] = [:]
        if let art = defensiveArt {
            let defPositionToIndex = mapDefensivePositionsToIndices(formation: art.formation)
            for assignment in art.assignments {
                if let idx = defPositionToIndex[assignment.position] {
                    assignmentLookup[idx] = assignment.assignment
                    depthLookup[idx] = assignment.depth
                    sideLookup[idx] = assignment.side
                }
            }
        }

        // Find ball carrier endpoint for tackle convergence
        let ballCarrierFinalY: CGFloat
        if result.playType.isPass {
            // Find target receiver's final position
            let targetIdx = findTargetReceiverIndex(result: result)
            if targetIdx < offensivePaths.count {
                ballCarrierFinalY = offensivePaths[targetIdx].waypoints.last?.position.y ?? centerY
            } else {
                ballCarrierFinalY = centerY + CGFloat.random(in: -30...30)
            }
        } else {
            // RB final position
            if 6 < offensivePaths.count {
                ballCarrierFinalY = offensivePaths[6].waypoints.last?.position.y ?? centerY
            } else {
                ballCarrierFinalY = centerY
            }
        }

        let ballCarrierFinal = CGPoint(x: ballCarrierFinalX, y: ballCarrierFinalY)

        // QB position for rush targets
        let qbDropPos: CGPoint
        if 5 < offensivePaths.count, let qbWP = offensivePaths[5].waypoints.first(where: { $0.time >= routeEnd - 0.1 }) {
            qbDropPos = qbWP.position
        } else {
            qbDropPos = CGPoint(x: losX - 25, y: centerY)
        }

        for i in 0..<11 {
            let start = startPositions[i]
            let role = roles[i]
            var waypoints: [AnimationWaypoint] = []

            let assignment = assignmentLookup[i]

            // Pre-snap hold
            waypoints.append(AnimationWaypoint(position: start, time: 0.0, speed: .slow))
            waypoints.append(AnimationWaypoint(position: start, time: routeStart, speed: .slow))

            switch assignment {
            case .passRush:
                // Rush toward QB
                let rushTarget = CGPoint(x: qbDropPos.x + 5, y: qbDropPos.y + CGFloat.random(in: -10...10))
                let rushMid = CGPoint(x: start.x - 15, y: lerp(start.y, rushTarget.y, 0.5))
                waypoints.append(AnimationWaypoint(position: rushMid, time: routeEnd * 0.6, speed: .sprint))
                waypoints.append(AnimationWaypoint(position: rushTarget, time: routeEnd, speed: .sprint))
                // After resolution, pursue ball carrier
                let pursuitPos = pursueTarget(from: rushTarget, target: ballCarrierFinal, maxDist: 60)
                waypoints.append(AnimationWaypoint(position: pursuitPos, time: tackleEnd, speed: .fast))

            case .containRush:
                // Rush upfield but stay wide
                let containTarget = CGPoint(x: qbDropPos.x + 10, y: start.y > centerY ? start.y + 10 : start.y - 10)
                waypoints.append(AnimationWaypoint(position: containTarget, time: routeEnd, speed: .fast))
                let pursuitPos = pursueTarget(from: containTarget, target: ballCarrierFinal, maxDist: 50)
                waypoints.append(AnimationWaypoint(position: pursuitPos, time: tackleEnd, speed: .fast))

            case .blitz:
                // Sprint to QB
                let blitzTarget = CGPoint(x: qbDropPos.x + 3, y: qbDropPos.y + CGFloat.random(in: -8...8))
                waypoints.append(AnimationWaypoint(position: blitzTarget, time: routeEnd * 0.7, speed: .sprint))
                waypoints.append(AnimationWaypoint(position: blitzTarget, time: resolutionEnd, speed: .sprint))
                let pursuitPos = pursueTarget(from: blitzTarget, target: ballCarrierFinal, maxDist: 50)
                waypoints.append(AnimationWaypoint(position: pursuitPos, time: tackleEnd, speed: .sprint))

            case .delayed:
                // Hold, then rush
                waypoints.append(AnimationWaypoint(position: start, time: routeEnd * 0.5, speed: .slow))
                let delayTarget = CGPoint(x: qbDropPos.x + 8, y: qbDropPos.y + CGFloat.random(in: -12...12))
                waypoints.append(AnimationWaypoint(position: delayTarget, time: routeEnd, speed: .sprint))
                let pursuitPos = pursueTarget(from: delayTarget, target: ballCarrierFinal, maxDist: 50)
                waypoints.append(AnimationWaypoint(position: pursuitPos, time: tackleEnd, speed: .fast))

            case .manCoverage:
                // Mirror a receiver's route (offset by a few pixels)
                let coverTarget = findCoverageTarget(defIndex: i, offensivePaths: offensivePaths, centerY: centerY)
                if let receiverPath = offensivePaths[safe: coverTarget] {
                    // Follow receiver with slight delay
                    for wp in receiverPath.waypoints where wp.time >= routeStart {
                        let offset = CGPoint(x: wp.position.x + 5, y: wp.position.y + CGFloat.random(in: -3...3))
                        waypoints.append(AnimationWaypoint(position: offset, time: min(wp.time + 0.02, 1.0), speed: .fast))
                    }
                } else {
                    // Default zone drop
                    let dropTarget = CGPoint(x: losX + CGFloat(depthLookup[i] ?? 10) * yardsPerPixel, y: sideY(sideLookup[i] ?? .middle, centerY: centerY))
                    waypoints.append(AnimationWaypoint(position: dropTarget, time: routeEnd, speed: .fast))
                }
                let pursuitPos = pursueTarget(from: waypoints.last?.position ?? start, target: ballCarrierFinal, maxDist: 40)
                waypoints.append(AnimationWaypoint(position: pursuitPos, time: tackleEnd, speed: .fast))

            case .zoneCoverage, .hookZone:
                // Drop to zone
                let depth = CGFloat(depthLookup[i] ?? 10) * yardsPerPixel
                let zoneCenter = CGPoint(x: losX + depth, y: sideY(sideLookup[i] ?? .middle, centerY: centerY))
                waypoints.append(AnimationWaypoint(position: zoneCenter, time: routeEnd, speed: .normal))
                // Read and react toward ball
                let reactPos = pursueTarget(from: zoneCenter, target: ballCarrierFinal, maxDist: 35)
                waypoints.append(AnimationWaypoint(position: reactPos, time: yacEnd, speed: .fast))
                waypoints.append(AnimationWaypoint(position: pursueTarget(from: reactPos, target: ballCarrierFinal, maxDist: 25), time: tackleEnd, speed: .fast))

            case .deepThird:
                let depth = CGFloat(depthLookup[i] ?? 20) * yardsPerPixel
                let side = sideLookup[i] ?? .middle
                let targetY: CGFloat
                switch side {
                case .left: targetY = centerY - 80
                case .right: targetY = centerY + 80
                case .middle: targetY = centerY
                }
                let dropTarget = CGPoint(x: losX + depth, y: targetY)
                waypoints.append(AnimationWaypoint(position: dropTarget, time: routeEnd, speed: .normal))
                let reactPos = pursueTarget(from: dropTarget, target: ballCarrierFinal, maxDist: 45)
                waypoints.append(AnimationWaypoint(position: reactPos, time: tackleEnd, speed: .fast))

            case .deepHalf:
                let depth = CGFloat(depthLookup[i] ?? 20) * yardsPerPixel
                let side = sideLookup[i] ?? .middle
                let targetY: CGFloat = side == .left ? centerY - 60 : centerY + 60
                let dropTarget = CGPoint(x: losX + depth, y: targetY)
                waypoints.append(AnimationWaypoint(position: dropTarget, time: routeEnd, speed: .normal))
                let reactPos = pursueTarget(from: dropTarget, target: ballCarrierFinal, maxDist: 50)
                waypoints.append(AnimationWaypoint(position: reactPos, time: tackleEnd, speed: .fast))

            case .flatZone:
                let depth = CGFloat(depthLookup[i] ?? 5) * yardsPerPixel
                let side = sideLookup[i] ?? .middle
                let targetY: CGFloat = side == .left ? centerY - 90 : (side == .right ? centerY + 90 : centerY)
                let dropTarget = CGPoint(x: losX + depth, y: targetY)
                waypoints.append(AnimationWaypoint(position: dropTarget, time: routeEnd, speed: .normal))
                let reactPos = pursueTarget(from: dropTarget, target: ballCarrierFinal, maxDist: 35)
                waypoints.append(AnimationWaypoint(position: reactPos, time: tackleEnd, speed: .fast))

            case .spyQB:
                // Mirror QB lateral movement
                let spyPos = CGPoint(x: start.x, y: qbDropPos.y)
                waypoints.append(AnimationWaypoint(position: spyPos, time: routeEnd, speed: .normal))
                let reactPos = pursueTarget(from: spyPos, target: ballCarrierFinal, maxDist: 50)
                waypoints.append(AnimationWaypoint(position: reactPos, time: tackleEnd, speed: .sprint))

            case .runGap:
                // Fill gap then pursue
                let gapTarget = CGPoint(x: losX + 5, y: start.y + CGFloat.random(in: -10...10))
                waypoints.append(AnimationWaypoint(position: gapTarget, time: routeEnd * 0.5, speed: .fast))
                let pursuitPos = pursueTarget(from: gapTarget, target: ballCarrierFinal, maxDist: 60)
                waypoints.append(AnimationWaypoint(position: pursuitPos, time: tackleEnd, speed: .sprint))

            case .edgeContain:
                // Set edge
                let edgePos = CGPoint(x: losX + 3, y: start.y > centerY ? start.y + 8 : start.y - 8)
                waypoints.append(AnimationWaypoint(position: edgePos, time: routeEnd * 0.5, speed: .fast))
                let pursuitPos = pursueTarget(from: edgePos, target: ballCarrierFinal, maxDist: 55)
                waypoints.append(AnimationWaypoint(position: pursuitPos, time: tackleEnd, speed: .fast))

            case .pursuitAngle:
                // Angle toward ball carrier
                waypoints.append(AnimationWaypoint(position: start, time: routeEnd * 0.3, speed: .normal))
                let pursuitPos = pursueTarget(from: start, target: ballCarrierFinal, maxDist: 70)
                waypoints.append(AnimationWaypoint(position: pursuitPos, time: tackleEnd, speed: .sprint))

            case nil:
                // Default: DL rush, LB zone, DB deep zone based on role
                switch role {
                case .defensiveLine:
                    let rushTarget = CGPoint(x: qbDropPos.x + 8, y: start.y + CGFloat.random(in: -15...15))
                    waypoints.append(AnimationWaypoint(position: rushTarget, time: routeEnd, speed: .sprint))
                    let pursuitPos = pursueTarget(from: rushTarget, target: ballCarrierFinal, maxDist: 50)
                    waypoints.append(AnimationWaypoint(position: pursuitPos, time: tackleEnd, speed: .fast))

                case .linebacker:
                    let dropTarget = CGPoint(x: losX + (isPass ? 30 : 8), y: start.y + CGFloat.random(in: -15...15))
                    waypoints.append(AnimationWaypoint(position: dropTarget, time: routeEnd, speed: .normal))
                    let pursuitPos = pursueTarget(from: dropTarget, target: ballCarrierFinal, maxDist: 45)
                    waypoints.append(AnimationWaypoint(position: pursuitPos, time: tackleEnd, speed: .fast))

                case .defensiveBack, .cornerback, .safety:
                    let dropTarget = CGPoint(x: losX + (isPass ? 60 : 20), y: start.y)
                    waypoints.append(AnimationWaypoint(position: dropTarget, time: routeEnd, speed: .normal))
                    let reactPos = pursueTarget(from: dropTarget, target: ballCarrierFinal, maxDist: 50)
                    waypoints.append(AnimationWaypoint(position: reactPos, time: tackleEnd, speed: .fast))

                default:
                    waypoints.append(AnimationWaypoint(position: start, time: tackleEnd, speed: .slow))
                }
            }

            paths.append(AnimatedPlayerPath(playerIndex: i, role: role, waypoints: waypoints))
        }

        return paths
    }

    // MARK: - Ball Path

    private static func buildBallPath(
        playArt: PlayArt?,
        result: PlayResult,
        losX: CGFloat,
        centerY: CGFloat,
        offPaths: [AnimatedPlayerPath],
        totalDuration: Double,
        phases: [AnimationPhase]
    ) -> BallAnimationPath {

        var segments: [BallSegment] = []
        let routeStart = phaseTime(phases, .routesDevelop)?.startTime ?? 0.12
        let resolutionStart = phaseTime(phases, .resolution)?.startTime ?? 0.55
        let resolutionEnd = phaseTime(phases, .resolution)?.endTime ?? 0.72

        let isPass = result.playType.isPass
        let isRun = result.playType.isRun

        if isPass {
            // Ball held by QB (index 5) from snap to throw
            segments.append(.held(byPlayerIndex: 5, isOffense: true, startTime: 0.0, endTime: resolutionStart))

            // Ball in air from throw to catch/incomplete
            let qbPos: CGPoint
            if 5 < offPaths.count, let wp = offPaths[5].waypoints.first(where: { $0.time >= resolutionStart - 0.05 }) {
                qbPos = wp.position
            } else {
                qbPos = CGPoint(x: losX - 25, y: centerY)
            }

            let targetIdx = findTargetReceiverIndex(result: result)
            let catchPos: CGPoint
            if targetIdx < offPaths.count, let wp = offPaths[targetIdx].waypoints.first(where: { $0.time >= resolutionStart }) {
                catchPos = wp.position
            } else {
                catchPos = CGPoint(x: losX + CGFloat(abs(result.yardsGained)) * yardsPerPixel, y: centerY + CGFloat.random(in: -30...30))
            }

            let arcPoints = FieldPhysics.calculatePassArc(
                from: qbPos,
                to: catchPos,
                power: 80,
                accuracy: 85,
                isDeep: result.playType == .deepPass
            )

            segments.append(.thrown(arcPoints: arcPoints, startTime: resolutionStart, endTime: resolutionEnd))

            if result.isTurnover {
                // Interception or incomplete — ball is loose
                segments.append(.loose(position: catchPos, time: resolutionEnd))
            } else if result.yardsGained > 0 {
                // Caught — held by receiver
                segments.append(.held(byPlayerIndex: targetIdx, isOffense: true, startTime: resolutionEnd, endTime: 1.0))
            } else {
                // Incomplete
                segments.append(.loose(position: catchPos, time: resolutionEnd))
            }

        } else if isRun {
            // Ball held by QB until handoff
            segments.append(.held(byPlayerIndex: 5, isOffense: true, startTime: 0.0, endTime: routeStart + 0.03))
            // Ball held by RB (index 6) after handoff
            segments.append(.held(byPlayerIndex: 6, isOffense: true, startTime: routeStart + 0.03, endTime: 1.0))

        } else if result.playType == .kickoff || result.playType == .punt {
            // Kicking play
            let kickStart = CGPoint(x: losX, y: centerY)
            let gainPixels = CGFloat(result.yardsGained) * yardsPerPixel
            let kickEnd = CGPoint(x: losX + gainPixels, y: centerY)
            let arcPoints = FieldPhysics.calculatePassArc(from: kickStart, to: kickEnd, power: 95, accuracy: 80, isDeep: true)
            segments.append(.kicked(arcPoints: arcPoints, startTime: 0.1, endTime: 0.6))
            // After catch, held by returner
            segments.append(.held(byPlayerIndex: 7, isOffense: false, startTime: 0.6, endTime: 1.0))

        } else {
            // Default: held by QB
            segments.append(.held(byPlayerIndex: 5, isOffense: true, startTime: 0.0, endTime: 1.0))
        }

        return BallAnimationPath(segments: segments)
    }

    // MARK: - Route Waypoint Generation

    /// Convert a PlayRoute into waypoints in field coordinate space.
    private static func generateRouteWaypoints(
        route: PlayRoute,
        start: CGPoint,
        losX: CGFloat,
        centerY: CGFloat,
        routeStart: Double,
        routeEnd: Double
    ) -> [AnimationWaypoint] {

        var waypoints: [AnimationWaypoint] = []
        let depthPixels = CGFloat(route.depth) * yardsPerPixel
        let routeDuration = routeEnd - routeStart
        let isAboveCenter = start.y < centerY

        // Direction multiplier: if player is above center, "outside" = upward (negative Y)
        let outsideMult: CGFloat = isAboveCenter ? -1 : 1
        let insideMult: CGFloat = -outsideMult

        switch route.route {
        case .fly:
            // Straight downfield
            let endPos = CGPoint(x: start.x + depthPixels, y: start.y)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .post:
            // Straight, then 45° inside
            let breakPoint = CGPoint(x: start.x + depthPixels * 0.6, y: start.y)
            waypoints.append(AnimationWaypoint(position: breakPoint, time: routeStart + routeDuration * 0.5, speed: .fast))
            let endPos = CGPoint(x: start.x + depthPixels, y: start.y + insideMult * depthPixels * 0.4)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .corner:
            // Straight, then 45° outside
            let breakPoint = CGPoint(x: start.x + depthPixels * 0.6, y: start.y)
            waypoints.append(AnimationWaypoint(position: breakPoint, time: routeStart + routeDuration * 0.5, speed: .fast))
            let endPos = CGPoint(x: start.x + depthPixels, y: start.y + outsideMult * depthPixels * 0.4)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .out:
            // Straight to depth, then 90° to sideline
            let breakPoint = CGPoint(x: start.x + depthPixels, y: start.y)
            waypoints.append(AnimationWaypoint(position: breakPoint, time: routeStart + routeDuration * 0.6, speed: .fast))
            let endPos = CGPoint(x: start.x + depthPixels, y: start.y + outsideMult * 25)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .slant:
            // Short forward then 45° inside
            let breakPoint = CGPoint(x: start.x + 15, y: start.y)
            waypoints.append(AnimationWaypoint(position: breakPoint, time: routeStart + routeDuration * 0.25, speed: .fast))
            let endPos = CGPoint(x: start.x + depthPixels, y: start.y + insideMult * depthPixels * 0.7)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .curl:
            // Straight to depth, then turn back
            let deepPoint = CGPoint(x: start.x + depthPixels, y: start.y)
            waypoints.append(AnimationWaypoint(position: deepPoint, time: routeStart + routeDuration * 0.7, speed: .fast))
            let curlBack = CGPoint(x: start.x + depthPixels - 10, y: start.y + insideMult * 5)
            waypoints.append(AnimationWaypoint(position: curlBack, time: routeEnd, speed: .normal))

        case .comeBack:
            // Deep, then back toward sideline
            let deepPoint = CGPoint(x: start.x + depthPixels, y: start.y)
            waypoints.append(AnimationWaypoint(position: deepPoint, time: routeStart + routeDuration * 0.65, speed: .fast))
            let comebackPos = CGPoint(x: start.x + depthPixels - 12, y: start.y + outsideMult * 10)
            waypoints.append(AnimationWaypoint(position: comebackPos, time: routeEnd, speed: .normal))

        case .drag:
            // Slight forward then horizontal across
            let midPoint = CGPoint(x: start.x + 10, y: start.y)
            waypoints.append(AnimationWaypoint(position: midPoint, time: routeStart + routeDuration * 0.2, speed: .fast))
            let endPos = CGPoint(x: start.x + 15, y: start.y + insideMult * 60)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .flat:
            // Short route angling to sideline
            let endPos = CGPoint(x: start.x + depthPixels * 0.5, y: start.y + outsideMult * 30)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .hitch:
            // Straight to depth, stop
            let endPos = CGPoint(x: start.x + depthPixels, y: start.y)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeStart + routeDuration * 0.6, speed: .fast))
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .slow))

        case .fade:
            // Diagonal toward sideline corner
            let endPos = CGPoint(x: start.x + depthPixels, y: start.y + outsideMult * depthPixels * 0.3)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .wheel:
            // Start inside (fake block), then break outside deep
            let fakeBlock = CGPoint(x: start.x + 5, y: start.y + insideMult * 5)
            waypoints.append(AnimationWaypoint(position: fakeBlock, time: routeStart + routeDuration * 0.3, speed: .slow))
            let breakOut = CGPoint(x: start.x + depthPixels * 0.5, y: start.y + outsideMult * 15)
            waypoints.append(AnimationWaypoint(position: breakOut, time: routeStart + routeDuration * 0.6, speed: .fast))
            let endPos = CGPoint(x: start.x + depthPixels, y: start.y + outsideMult * 30)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .cut: // New case for the generic cut route
            // For now, treat generic cuts as a short straight route
            let endPos = CGPoint(x: start.x + depthPixels * 0.5, y: start.y)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .swing:
            // Arc out to flat
            let midPoint = CGPoint(x: start.x - 5, y: start.y + outsideMult * 15)
            waypoints.append(AnimationWaypoint(position: midPoint, time: routeStart + routeDuration * 0.35, speed: .normal))
            let endPos = CGPoint(x: start.x + 10, y: start.y + outsideMult * 35)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .angle:
            // Diagonal cut at 45°
            let direction = route.direction
            let lateralMult: CGFloat = direction == .left ? -1 : (direction == .right ? 1 : insideMult)
            let endPos = CGPoint(x: start.x + depthPixels, y: start.y + lateralMult * depthPixels * 0.6)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .delay:
            // Hold (fake block), then release
            waypoints.append(AnimationWaypoint(position: start, time: routeStart + routeDuration * 0.35, speed: .slow))
            let endPos = CGPoint(x: start.x + depthPixels, y: start.y + insideMult * 15)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .block, .passBlock:
            // Step back, hold
            let blockPos = CGPoint(x: start.x - 5, y: start.y + CGFloat.random(in: -3...3))
            waypoints.append(AnimationWaypoint(position: blockPos, time: routeStart + routeDuration * 0.2, speed: .slow))
            waypoints.append(AnimationWaypoint(position: blockPos, time: routeEnd, speed: .slow))

        case .runBlock:
            // Step forward into defender
            let blockPos = CGPoint(x: start.x + 12, y: start.y + CGFloat.random(in: -5...5))
            waypoints.append(AnimationWaypoint(position: blockPos, time: routeEnd, speed: .fast))

        case .motionLeft:
            let endPos = CGPoint(x: start.x, y: start.y - 40)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .normal))

        case .motionRight:
            let endPos = CGPoint(x: start.x, y: start.y + 40)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .normal))
        }

        return waypoints
    }

    // MARK: - Starting Positions

    /// Formation-aware offensive start positions using FormationPositions lookup.
    /// Must match FPSFieldView.createOffensiveFormation exactly.
    private static func offensiveStartPositions(formation: OffensiveFormation, losX: CGFloat, centerY: CGFloat) -> [CGPoint] {
        return FormationPositions.offensivePositions(for: formation, losX: losX, centerY: centerY)
    }

    /// Formation-aware defensive start positions using FormationPositions lookup.
    /// Must match FPSFieldView.createDefensiveFormation exactly.
    private static func defensiveStartPositions(formation: DefensiveFormation, losX: CGFloat, centerY: CGFloat) -> [CGPoint] {
        return FormationPositions.defensivePositions(for: formation, losX: losX, centerY: centerY)
    }

    // MARK: - Helpers

    private static func yardToX(_ yard: Int) -> CGFloat {
        return endZoneWidth + (CGFloat(yard) / 100.0) * playFieldWidth
    }

    private static func phaseTime(_ phases: [AnimationPhase], _ name: AnimationPhaseName) -> AnimationPhase? {
        phases.first { $0.name == name }
    }

    /// Move from `from` toward `target`, capped at `maxDist` pixels.
    private static func pursueTarget(from: CGPoint, target: CGPoint, maxDist: CGFloat) -> CGPoint {
        let dx = target.x - from.x
        let dy = target.y - from.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist <= maxDist {
            return target
        }

        let scale = maxDist / dist
        return CGPoint(x: from.x + dx * scale, y: from.y + dy * scale)
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }

    private static func sideY(_ side: DefensiveSide, centerY: CGFloat) -> CGFloat {
        switch side {
        case .left: return centerY - 50
        case .right: return centerY + 50
        case .middle: return centerY
        }
    }

    /// Map DefensivePlayerPosition to indices in our 11-player array
    private static func mapDefensivePositionsToIndices(formation: DefensiveFormation) -> [DefensivePlayerPosition: Int] {
        // Standard 4-3 mapping
        return [
            .leftEnd: 0, .leftTackle: 1, .noseTackle: 1,
            .rightTackle: 2, .rightEnd: 3,
            .samLB: 4, .outsideLB: 4,
            .mikeLB: 5,
            .willLB: 6,
            .leftCorner: 7,
            .rightCorner: 8,
            .slotCorner: 7,   // Share with LCB in base
            .freeSafety: 9,
            .strongSafety: 10
        ]
    }

    /// Determine which offensive player is the "target receiver" for the play result.
    private static func findTargetReceiverIndex(result: PlayResult) -> Int {
        // Use play type to guess
        switch result.playType {
        case .screen:
            return 6  // RB
        case .shortPass, .mediumPass:
            return 7  // WR1 (default target)
        case .deepPass:
            return 7  // WR1
        default:
            return 7
        }
    }

    /// Check if a given player index is the target receiver for YAC purposes
    private static func isTargetReceiver(playerIndex: Int, result: PlayResult, playArt: PlayArt?) -> Bool {
        let targetIdx = findTargetReceiverIndex(result: result)
        return playerIndex == targetIdx
    }

    /// Find which offensive player index a defensive player should cover in man coverage
    private static func findCoverageTarget(defIndex: Int, offensivePaths: [AnimatedPlayerPath], centerY: CGFloat) -> Int {
        // Simple assignment: CBs cover WRs, safeties cover TE/slot
        switch defIndex {
        case 7: return 7  // LCB → WR1
        case 8: return 8  // RCB → WR2
        case 9: return 10 // FS → Slot
        case 10: return 9 // SS → TE
        case 4: return 6  // SAM → RB
        case 5: return 9  // MIKE → TE (backup)
        case 6: return 6  // WILL → RB
        default: return 7
        }
    }
}

// Note: PlayType.isPass, PlayType.isRun are defined in Play.swift
// Note: Array.subscript(safe:) is defined in NavigationBar.swift
