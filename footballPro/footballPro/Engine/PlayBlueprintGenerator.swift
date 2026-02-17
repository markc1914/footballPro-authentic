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
    /// When authentic STOCK.DAT data is available, uses real play routes from the original game.
    /// Falls back to synthetic generation when game files are missing.
    static func generateBlueprint(
        playArt: PlayArt?,
        defensiveArt: DefensivePlayArt?,
        result: PlayResult,
        los: Int,               // Line of scrimmage yard line (0-100)
        fieldWidth: CGFloat = 640,
        fieldHeight: CGFloat = 360,
        stockPlayName: String? = nil  // Optional: specific STOCK.DAT play name to use
    ) -> PlayAnimationBlueprint {

        let losX = yardToX(los)
        let centerY = fieldHeight / 2

        // Total duration scales with play type
        let totalDuration = playDuration(for: result)

        // Phase timing (normalized 0–1)
        let phases = buildPhases(for: result, duration: totalDuration)

        // Try authentic STOCK.DAT routes first
        if let stockDB = StockDATDecoder.shared {
            let stockOffPlay = resolveStockOffensivePlay(
                stockDB: stockDB, playArt: playArt, result: result, name: stockPlayName
            )
            let stockDefPlay = resolveStockDefensivePlay(
                stockDB: stockDB, defensiveArt: defensiveArt, result: result
            )

            if let stockOff = stockOffPlay {
                let sorted = sortPlayersToStandardOrder(stockOff.players)
                let offPaths = buildAuthenticOffensivePaths(
                    stockPlay: stockOff,
                    result: result,
                    losX: losX,
                    centerY: centerY,
                    totalDuration: totalDuration,
                    phases: phases
                )

                // Determine the STOCK.DAT target receiver for accurate ball path
                let stockTargetIdx = findStockTargetReceiver(
                    players: sorted, result: result, isPass: result.playType.isPass
                )

                let defPaths: [AnimatedPlayerPath]
                if let stockDef = stockDefPlay {
                    defPaths = buildAuthenticDefensivePaths(
                        stockPlay: stockDef,
                        result: result,
                        losX: losX,
                        centerY: centerY,
                        totalDuration: totalDuration,
                        phases: phases,
                        offensivePaths: offPaths
                    )
                } else {
                    defPaths = buildDefensivePaths(
                        defensiveArt: defensiveArt,
                        result: result,
                        losX: losX,
                        centerY: centerY,
                        totalDuration: totalDuration,
                        phases: phases,
                        offensivePaths: offPaths
                    )
                }

                let ballPath = buildBallPath(
                    playArt: playArt,
                    result: result,
                    losX: losX,
                    centerY: centerY,
                    offPaths: offPaths,
                    totalDuration: totalDuration,
                    phases: phases,
                    stockTargetReceiverIndex: stockTargetIdx
                )

                return PlayAnimationBlueprint(
                    offensivePaths: offPaths,
                    defensivePaths: defPaths,
                    ballPath: ballPath,
                    totalDuration: totalDuration,
                    phases: phases
                )
            }
        }

        // Fallback: synthetic generation
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
        phases: [AnimationPhase],
        stockTargetReceiverIndex: Int? = nil
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

            // Use STOCK.DAT target receiver if available, otherwise fallback to heuristic
            let targetIdx = stockTargetReceiverIndex ?? findTargetReceiverIndex(result: result)
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
    /// Route depths are measured from the LOS (losX), not from the player's start position,
    /// so receivers run PAST the LOS to their route depth downfield.
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

        // Route target X: measured from the LOS, not the player's start position.
        // This ensures routes always go downfield past the LOS.
        let routeBaseX = losX
        let routeEndX = routeBaseX + depthPixels

        // Direction multiplier: if player is above center, "outside" = upward (negative Y)
        let outsideMult: CGFloat = isAboveCenter ? -1 : 1
        let insideMult: CGFloat = -outsideMult

        switch route.route {
        case .fly:
            // Straight downfield
            let endPos = CGPoint(x: routeEndX, y: start.y)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .post:
            // Straight, then 45° inside
            let breakPoint = CGPoint(x: routeBaseX + depthPixels * 0.6, y: start.y)
            waypoints.append(AnimationWaypoint(position: breakPoint, time: routeStart + routeDuration * 0.5, speed: .fast))
            let endPos = CGPoint(x: routeEndX, y: start.y + insideMult * depthPixels * 0.4)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .corner:
            // Straight, then 45° outside
            let breakPoint = CGPoint(x: routeBaseX + depthPixels * 0.6, y: start.y)
            waypoints.append(AnimationWaypoint(position: breakPoint, time: routeStart + routeDuration * 0.5, speed: .fast))
            let endPos = CGPoint(x: routeEndX, y: start.y + outsideMult * depthPixels * 0.4)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .out:
            // Straight to depth, then 90° to sideline
            let breakPoint = CGPoint(x: routeEndX, y: start.y)
            waypoints.append(AnimationWaypoint(position: breakPoint, time: routeStart + routeDuration * 0.6, speed: .fast))
            let endPos = CGPoint(x: routeEndX, y: start.y + outsideMult * 25)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .slant:
            // Short forward then 45° inside
            let breakPoint = CGPoint(x: routeBaseX + 15, y: start.y)
            waypoints.append(AnimationWaypoint(position: breakPoint, time: routeStart + routeDuration * 0.25, speed: .fast))
            let endPos = CGPoint(x: routeEndX, y: start.y + insideMult * depthPixels * 0.7)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .curl:
            // Straight to depth, then turn back
            let deepPoint = CGPoint(x: routeEndX, y: start.y)
            waypoints.append(AnimationWaypoint(position: deepPoint, time: routeStart + routeDuration * 0.7, speed: .fast))
            let curlBack = CGPoint(x: routeEndX - 10, y: start.y + insideMult * 5)
            waypoints.append(AnimationWaypoint(position: curlBack, time: routeEnd, speed: .normal))

        case .comeBack:
            // Deep, then back toward sideline
            let deepPoint = CGPoint(x: routeEndX, y: start.y)
            waypoints.append(AnimationWaypoint(position: deepPoint, time: routeStart + routeDuration * 0.65, speed: .fast))
            let comebackPos = CGPoint(x: routeEndX - 12, y: start.y + outsideMult * 10)
            waypoints.append(AnimationWaypoint(position: comebackPos, time: routeEnd, speed: .normal))

        case .drag:
            // Slight forward then horizontal across
            let midPoint = CGPoint(x: routeBaseX + 10, y: start.y)
            waypoints.append(AnimationWaypoint(position: midPoint, time: routeStart + routeDuration * 0.2, speed: .fast))
            let endPos = CGPoint(x: routeBaseX + 15, y: start.y + insideMult * 60)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .flat:
            // Short route angling to sideline
            let endPos = CGPoint(x: routeBaseX + depthPixels * 0.5, y: start.y + outsideMult * 30)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .hitch:
            // Straight to depth, stop
            let endPos = CGPoint(x: routeEndX, y: start.y)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeStart + routeDuration * 0.6, speed: .fast))
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .slow))

        case .fade:
            // Diagonal toward sideline corner
            let endPos = CGPoint(x: routeEndX, y: start.y + outsideMult * depthPixels * 0.3)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .wheel:
            // Start inside (fake block), then break outside deep
            let fakeBlock = CGPoint(x: start.x + 5, y: start.y + insideMult * 5)
            waypoints.append(AnimationWaypoint(position: fakeBlock, time: routeStart + routeDuration * 0.3, speed: .slow))
            let breakOut = CGPoint(x: routeBaseX + depthPixels * 0.5, y: start.y + outsideMult * 15)
            waypoints.append(AnimationWaypoint(position: breakOut, time: routeStart + routeDuration * 0.6, speed: .fast))
            let endPos = CGPoint(x: routeEndX, y: start.y + outsideMult * 30)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .sprint))

        case .cut: // New case for the generic cut route
            // For now, treat generic cuts as a short straight route
            let endPos = CGPoint(x: routeBaseX + depthPixels * 0.5, y: start.y)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .swing:
            // Arc out to flat — starts behind LOS, arcs forward
            let midPoint = CGPoint(x: start.x - 5, y: start.y + outsideMult * 15)
            waypoints.append(AnimationWaypoint(position: midPoint, time: routeStart + routeDuration * 0.35, speed: .normal))
            let endPos = CGPoint(x: routeBaseX + 10, y: start.y + outsideMult * 35)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .angle:
            // Diagonal cut at 45°
            let direction = route.direction
            let lateralMult: CGFloat = direction == .left ? -1 : (direction == .right ? 1 : insideMult)
            let endPos = CGPoint(x: routeEndX, y: start.y + lateralMult * depthPixels * 0.6)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .delay:
            // Hold (fake block), then release
            waypoints.append(AnimationWaypoint(position: start, time: routeStart + routeDuration * 0.35, speed: .slow))
            let endPos = CGPoint(x: routeEndX, y: start.y + insideMult * 15)
            waypoints.append(AnimationWaypoint(position: endPos, time: routeEnd, speed: .fast))

        case .block, .passBlock:
            // Step back, hold — blocking stays relative to player position
            let blockPos = CGPoint(x: start.x - 5, y: start.y + CGFloat.random(in: -3...3))
            waypoints.append(AnimationWaypoint(position: blockPos, time: routeStart + routeDuration * 0.2, speed: .slow))
            waypoints.append(AnimationWaypoint(position: blockPos, time: routeEnd, speed: .slow))

        case .runBlock:
            // Step forward into defender — blocking stays relative to player position
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

    // MARK: - Kickoff Blueprint

    /// Generate a kickoff-specific animation blueprint with kicking and return team formations.
    static func generateKickoffBlueprint(
        result: PlayResult,
        los: Int  // Kickoff from yard line (typically 35)
    ) -> PlayAnimationBlueprint {
        let losX = yardToX(los)
        let centerY = fieldHeight / 2
        let totalDuration: Double = 5.5
        let gainPixels = CGFloat(result.yardsGained) * yardsPerPixel

        let phases: [AnimationPhase] = [
            AnimationPhase(name: .preSnap, startTime: 0.0, endTime: 0.05),
            AnimationPhase(name: .snap, startTime: 0.05, endTime: 0.15),
            AnimationPhase(name: .resolution, startTime: 0.15, endTime: 0.7),
            AnimationPhase(name: .yac, startTime: 0.7, endTime: 0.9),
            AnimationPhase(name: .tackle, startTime: 0.9, endTime: 1.0)
        ]

        // Kicking team lineup: spread across the 35 yard line
        let kickTeamSpacing: CGFloat = 28
        let kickTeamBaseY = centerY - 5 * kickTeamSpacing / 2
        var kickerPaths: [AnimatedPlayerPath] = []

        for i in 0..<11 {
            let startY = kickTeamBaseY + CGFloat(i) * kickTeamSpacing
            let startPos = CGPoint(x: losX, y: startY)

            // All kicking team players sprint downfield toward the returner
            let targetX = losX + gainPixels
            let targetY = centerY + CGFloat.random(in: -40...40)
            let endPos = CGPoint(x: targetX, y: targetY)

            var wps: [AnimationWaypoint] = []
            wps.append(AnimationWaypoint(position: startPos, time: 0.0, speed: .slow))
            wps.append(AnimationWaypoint(position: startPos, time: 0.15, speed: .slow))

            // Sprint downfield
            let midPos = CGPoint(x: startPos.x + (endPos.x - startPos.x) * 0.6, y: startY + (targetY - startY) * 0.3)
            wps.append(AnimationWaypoint(position: midPos, time: 0.5, speed: .sprint))
            wps.append(AnimationWaypoint(position: endPos, time: 0.9, speed: .fast))
            wps.append(AnimationWaypoint(position: endPos, time: 1.0, speed: .slow))

            let role: PlayerRole = i == 5 ? .lineman : .lineman // Middle player is kicker
            kickerPaths.append(AnimatedPlayerPath(playerIndex: i, role: role, waypoints: wps))
        }

        // Receiving team: spread across the deep return zone (~10-15 yard line)
        let returnZoneX = yardToX(10)
        let returnSpacing: CGFloat = 28
        let returnBaseY = centerY - 5 * returnSpacing / 2
        var returnPaths: [AnimatedPlayerPath] = []

        for i in 0..<11 {
            let startY = returnBaseY + CGFloat(i) * returnSpacing
            let depth: CGFloat = i == 5 ? 0 : CGFloat.random(in: 30...80) // Returner is deep, blockers up front
            let startPos = CGPoint(x: returnZoneX + depth, y: startY)

            var wps: [AnimationWaypoint] = []
            wps.append(AnimationWaypoint(position: startPos, time: 0.0, speed: .slow))
            wps.append(AnimationWaypoint(position: startPos, time: 0.15, speed: .slow))

            if i == 5 {
                // Returner: catches and runs to the result yard line
                let catchPos = CGPoint(x: yardToX(5), y: centerY)
                let returnEndX = yardToX(result.yardsGained)
                let returnEnd = CGPoint(x: returnEndX, y: centerY + CGFloat.random(in: -20...20))
                wps.append(AnimationWaypoint(position: catchPos, time: 0.35, speed: .normal))
                wps.append(AnimationWaypoint(position: returnEnd, time: 0.85, speed: .sprint))
                wps.append(AnimationWaypoint(position: returnEnd, time: 1.0, speed: .slow))
            } else {
                // Blockers: run upfield to set up blocks
                let blockX = startPos.x + 60
                let blockEnd = CGPoint(x: blockX, y: startY + CGFloat.random(in: -10...10))
                wps.append(AnimationWaypoint(position: blockEnd, time: 0.6, speed: .fast))
                wps.append(AnimationWaypoint(position: blockEnd, time: 1.0, speed: .slow))
            }

            let role: PlayerRole = i == 5 ? .receiver : .lineman
            returnPaths.append(AnimatedPlayerPath(playerIndex: i, role: role, waypoints: wps))
        }

        // Ball path: kicked from kicker, caught by returner, carried to final position
        let kickStart = CGPoint(x: losX, y: centerY)
        let catchPoint = CGPoint(x: yardToX(5), y: centerY)
        let returnEndX = yardToX(result.yardsGained)
        let returnEnd = CGPoint(x: returnEndX, y: centerY)

        let arcPoints = FieldPhysics.calculatePassArc(from: kickStart, to: catchPoint, power: 95, accuracy: 80, isDeep: true)
        let ballPath = BallAnimationPath(segments: [
            .held(byPlayerIndex: 5, isOffense: true, startTime: 0.0, endTime: 0.15),
            .kicked(arcPoints: arcPoints, startTime: 0.15, endTime: 0.35),
            .held(byPlayerIndex: 5, isOffense: false, startTime: 0.35, endTime: 1.0)
        ])

        return PlayAnimationBlueprint(
            offensivePaths: kickerPaths,
            defensivePaths: returnPaths,
            ballPath: ballPath,
            totalDuration: totalDuration,
            phases: phases
        )
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

    // MARK: - Authentic STOCK.DAT Play Resolution

    /// Find a matching offensive play from STOCK.DAT.
    /// Priority: exact name > play art name substring > FPS '93 naming conventions > random from category.
    private static func resolveStockOffensivePlay(
        stockDB: StockDatabase,
        playArt: PlayArt?,
        result: PlayResult,
        name: String?
    ) -> StockPlay? {
        // 1. Exact name match (e.g. from stockPlayName parameter)
        if let name = name, let play = stockDB.play(named: name) {
            return play
        }

        // 2. Match by PlayArt name — try exact first, then substring
        if let artName = playArt?.playName {
            let upper = artName.uppercased().replacingOccurrences(of: " ", with: "")
            // Exact match
            if let play = stockDB.offensivePlays.first(where: {
                $0.name.uppercased().replacingOccurrences(of: " ", with: "") == upper
            }) {
                return play
            }
            // Substring match (authentic 8-char PLN codes)
            if let play = stockDB.offensivePlays.first(where: {
                $0.name.uppercased().replacingOccurrences(of: " ", with: "").contains(upper) ||
                upper.contains($0.name.uppercased().replacingOccurrences(of: " ", with: ""))
            }) {
                return play
            }
        }

        // 3. Match by play type using FPS '93 naming conventions
        //    Run plays: RM/RR/RL (run middle/right/left), FBD (fullback dive), SWP (sweep), DR (draw)
        //    Short pass: PS (pass short), SA (screen)
        //    Medium pass: PM (pass medium)
        //    Deep pass: PL (pass long), PA/FA (play action/fake action)
        let candidates: [StockPlay]
        switch result.playType {
        case .insideRun, .qbSneak:
            candidates = stockDB.offensivePlays.filter { play in
                let n = play.name.uppercased()
                return n.contains("RM") || n.contains("FBD") || n.contains("DIVE") ||
                       n.hasPrefix("QK")
            }
        case .outsideRun, .sweep, .counter:
            candidates = stockDB.offensivePlays.filter { play in
                let n = play.name.uppercased()
                return n.contains("RR") || n.contains("RL") || n.contains("SWP") ||
                       n.contains("SWEEP") || n.contains("PI") || n.contains("SL")
            }
        case .draw:
            candidates = stockDB.offensivePlays.filter { play in
                play.name.uppercased().hasPrefix("DR")
            }
        case .screen:
            candidates = stockDB.offensivePlays.filter { play in
                play.name.uppercased().hasPrefix("SA")
            }
        case .shortPass:
            candidates = stockDB.offensivePlays.filter { play in
                let n = play.name.uppercased()
                return n.contains("PS") && !n.contains("PL") && !n.contains("PM")
            }
        case .mediumPass:
            candidates = stockDB.offensivePlays.filter { play in
                play.name.uppercased().contains("PM")
            }
        case .deepPass:
            candidates = stockDB.offensivePlays.filter { play in
                play.name.uppercased().contains("PL")
            }
        case .playAction:
            candidates = stockDB.offensivePlays.filter { play in
                let n = play.name.uppercased()
                return n.contains("PA") || n.hasPrefix("FA")
            }
        case .qbScramble:
            // Any run play works for scramble animation
            candidates = stockDB.offensivePlays.filter { play in
                let n = play.name.uppercased()
                return n.contains("RM") || n.contains("RR") || n.contains("RL")
            }
        default:
            candidates = stockDB.offensivePlays
        }

        // Pick from matching candidates, falling back to any offensive play
        if let match = candidates.randomElement() {
            return match
        }

        // 4. Broad fallback: run vs pass
        if result.playType.isRun {
            let runPlays = stockDB.offensivePlays.filter { play in
                let n = play.name.uppercased()
                return n.contains("R") && (n.contains("RM") || n.contains("RR") || n.contains("RL"))
            }
            if let match = runPlays.randomElement() { return match }
        } else if result.playType.isPass {
            let passPlays = stockDB.offensivePlays.filter { play in
                let n = play.name.uppercased()
                return n.contains("P") && (n.contains("PS") || n.contains("PM") || n.contains("PL"))
            }
            if let match = passPlays.randomElement() { return match }
        }

        return stockDB.randomOffensivePlay()
    }

    /// Find a matching defensive play from STOCK.DAT.
    /// Matches by defensive formation characteristics, then falls back to random.
    private static func resolveStockDefensivePlay(
        stockDB: StockDatabase,
        defensiveArt: DefensivePlayArt?,
        result: PlayResult
    ) -> StockPlay? {
        // Try to match by defensive formation name
        if let defArt = defensiveArt {
            let formName = defArt.formation.rawValue.uppercased()
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: " ", with: "")
            // Exact formation name match
            let exact = stockDB.defensivePlays.filter { play in
                play.name.uppercased().replacingOccurrences(of: " ", with: "") == formName
            }
            if let match = exact.randomElement() { return match }

            // Substring match
            let candidates = stockDB.defensivePlays.filter { play in
                play.name.uppercased().contains(formName) ||
                formName.contains(play.name.uppercased().trimmingCharacters(in: .whitespaces))
            }
            if let match = candidates.randomElement() { return match }

            // Match by DL/LB count from formation type
            let dlCount = defArt.formation.dLineCount
            let lbCount = defArt.formation.lbCount
            let formCandidates = stockDB.defensivePlays.filter { play in
                let dlPlayers = play.players.filter {
                    $0.positionCode == 0x0101 || $0.positionCode == 0x0102
                }
                let lbPlayers = play.players.filter { $0.positionCode == 0x0200 }
                return dlPlayers.count == dlCount && lbPlayers.count == lbCount
            }
            if let match = formCandidates.randomElement() { return match }
        }

        return stockDB.randomDefensivePlay()
    }

    // MARK: - Authentic Offensive Path Builder

    /// Build offensive player paths from authentic STOCK.DAT play data.
    /// Uses each player's actual STOCK.DAT route waypoints, assignments (block/passTarget),
    /// and phase positions (PH1=pre-snap, PH2=post-snap, PH3=route endpoint).
    private static func buildAuthenticOffensivePaths(
        stockPlay: StockPlay,
        result: PlayResult,
        losX: CGFloat,
        centerY: CGFloat,
        totalDuration: Double,
        phases: [AnimationPhase]
    ) -> [AnimatedPlayerPath] {

        let routeStart = phaseTime(phases, .routesDevelop)?.startTime ?? 0.12
        let routeEnd = phaseTime(phases, .routesDevelop)?.endTime ?? 0.55
        let resolutionStart = phaseTime(phases, .resolution)?.startTime ?? 0.55
        let yacEnd = phaseTime(phases, .yac)?.endTime ?? 0.88
        let tackleEnd: Double = 1.0
        let isPass = result.playType.isPass
        let isRun = result.playType.isRun
        let gainPixels = CGFloat(result.yardsGained) * yardsPerPixel
        let targetX = losX + gainPixels

        // Sort players into standard order: OL(5), QB, RB, WR1, WR2, TE, Slot/FB
        let sorted = sortPlayersToStandardOrder(stockPlay.players)

        let roles: [PlayerRole] = [
            .lineman, .lineman, .lineman, .lineman, .lineman,
            .quarterback, .runningback,
            .receiver, .receiver,
            .tightend, .receiver
        ]

        // Identify the target receiver from STOCK.DAT passTarget assignments.
        // This replaces the hardcoded index-7 assumption.
        let stockTargetReceiverIndex = findStockTargetReceiver(
            players: sorted, result: result, isPass: isPass
        )

        var paths: [AnimatedPlayerPath] = []

        for i in 0..<11 {
            guard i < sorted.count else {
                // Pad with a stationary player at LOS if stock play has fewer than 11
                let fallbackPos = CGPoint(x: losX, y: centerY + CGFloat(i - 5) * 22)
                let wps = [
                    AnimationWaypoint(position: fallbackPos, time: 0.0, speed: .slow),
                    AnimationWaypoint(position: fallbackPos, time: tackleEnd, speed: .slow)
                ]
                paths.append(AnimatedPlayerPath(playerIndex: i, role: roles[i], waypoints: wps))
                continue
            }

            let player = sorted[i]
            let role = roles[i]
            var waypoints: [AnimationWaypoint] = []

            // Pre-snap position from STOCK.DAT PH1
            let startPos: CGPoint
            if let preSnap = player.preSnapPosition {
                startPos = StockDATDecoder.convertToBlueprint(
                    stockPoint: preSnap, losX: losX, centerY: centerY
                )
            } else {
                // Fallback to formation positions
                let formation = FormationPositions.offensivePositions(
                    for: .shotgun, losX: losX, centerY: centerY
                )
                startPos = i < formation.count ? formation[i] : CGPoint(x: losX, y: centerY)
            }

            // Pre-snap hold
            waypoints.append(AnimationWaypoint(position: startPos, time: 0.0, speed: .slow))

            // Pre-snap motion (some receivers/backs motion before the snap)
            if let motionTarget = player.motionTarget {
                let motionPos = StockDATDecoder.convertToBlueprint(
                    stockPoint: motionTarget, losX: losX, centerY: centerY
                )
                // Motion happens during pre-snap phase, ending just before snap
                waypoints.append(AnimationWaypoint(position: motionPos, time: routeStart, speed: .normal))
            } else {
                waypoints.append(AnimationWaypoint(position: startPos, time: routeStart, speed: .slow))
            }

            // Determine player's behavior from STOCK.DAT assignments
            let isBlocker = player.hasBlockingAssignment
            let isPassRoute = player.hasPassRoute
            let isThisTarget = (i == stockTargetReceiverIndex)
            let hasStockRoute = !player.routeWaypoints.isEmpty || player.routePhasePosition != nil
            let hasPostSnap = player.postSnapPosition != nil

            // === Post-snap movement ===
            // Use actual STOCK.DAT phase positions and route waypoints

            if hasPostSnap {
                let postPos = StockDATDecoder.convertToBlueprint(
                    stockPoint: player.postSnapPosition!, losX: losX, centerY: centerY
                )
                // Speed depends on role: blockers engage quickly, route runners accelerate
                let speed: WaypointSpeed = isBlocker ? .fast : (isPassRoute ? .fast : .normal)
                let postSnapTime = routeStart + (routeEnd - routeStart) * 0.15
                waypoints.append(AnimationWaypoint(position: postPos, time: postSnapTime, speed: speed))
            }

            // Route waypoints from STOCK.DAT (0x0202 nodes)
            if !player.routeWaypoints.isEmpty {
                let bpWaypoints = StockDATDecoder.convertWaypointsToBlueprint(
                    waypoints: player.routeWaypoints, losX: losX, centerY: centerY
                )
                let waypointCount = bpWaypoints.count
                for (wi, wp) in bpWaypoints.enumerated() {
                    // Distribute waypoints evenly through the route development phase
                    let progress = Double(wi + 1) / Double(waypointCount + 1)
                    let t = routeStart + (routeEnd - routeStart) * progress
                    // Route runners sprint, blockers are slower
                    let speed: WaypointSpeed = isBlocker ? .normal : .sprint
                    waypoints.append(AnimationWaypoint(position: wp, time: t, speed: speed))
                }
            }

            // Route endpoint (PH3) from STOCK.DAT
            if let routePhase = player.routePhasePosition {
                let routePos = StockDATDecoder.convertToBlueprint(
                    stockPoint: routePhase, losX: losX, centerY: centerY
                )
                let speed: WaypointSpeed = isBlocker ? .normal : .fast
                waypoints.append(AnimationWaypoint(position: routePos, time: routeEnd, speed: speed))
            }

            // === Post-route behavior (after routes develop) ===
            // This is where the play result affects the animation

            let lastPos = waypoints.last?.position ?? startPos

            switch role {
            case .lineman:
                // Linemen: use assignment to differentiate behavior
                if isRun && !isBlocker {
                    // Run-block: push forward toward the play direction
                    let pushTarget = CGPoint(x: lastPos.x + 15, y: lastPos.y + CGFloat.random(in: -5...5))
                    waypoints.append(AnimationWaypoint(position: pushTarget, time: resolutionStart, speed: .fast))
                    waypoints.append(AnimationWaypoint(position: pushTarget, time: tackleEnd, speed: .slow))
                } else if isPass && !hasStockRoute {
                    // Pass-block: hold position with minor jostling
                    let jostle = CGPoint(x: lastPos.x + CGFloat.random(in: -3...3), y: lastPos.y + CGFloat.random(in: -4...4))
                    waypoints.append(AnimationWaypoint(position: jostle, time: resolutionStart, speed: .slow))
                    waypoints.append(AnimationWaypoint(position: jostle, time: tackleEnd, speed: .slow))
                } else {
                    // Hold at blocking position from STOCK.DAT route
                    waypoints.append(AnimationWaypoint(position: lastPos, time: tackleEnd, speed: .slow))
                }

            case .quarterback:
                if player.hasQBThrow && isPass {
                    if result.description.lowercased().contains("sack") {
                        // Sacked: pushed backward from pocket position
                        let sackPos = CGPoint(x: lastPos.x - 12, y: lastPos.y + CGFloat.random(in: -5...5))
                        waypoints.append(AnimationWaypoint(position: sackPos, time: resolutionStart + 0.05, speed: .slow))
                        waypoints.append(AnimationWaypoint(position: sackPos, time: tackleEnd, speed: .slow))
                    } else {
                        // Throw and hold — QB stays in pocket
                        waypoints.append(AnimationWaypoint(position: lastPos, time: tackleEnd, speed: .slow))
                    }
                } else if isRun {
                    // Handoff: QB steps back, fakes, holds
                    if !hasStockRoute {
                        let handoffPos = CGPoint(x: startPos.x - 8, y: centerY)
                        waypoints.append(AnimationWaypoint(position: handoffPos, time: resolutionStart, speed: .normal))
                    }
                    waypoints.append(AnimationWaypoint(position: lastPos, time: tackleEnd, speed: .slow))
                } else {
                    waypoints.append(AnimationWaypoint(position: lastPos, time: tackleEnd, speed: .slow))
                }

            case .runningback, .runningBack:
                if isRun {
                    // Ball carrier: follow STOCK.DAT route to the gap, then run to gain point
                    let finalY = lastPos.y + CGFloat.random(in: -10...10)
                    let finalPos = CGPoint(x: targetX, y: finalY)
                    waypoints.append(AnimationWaypoint(position: finalPos, time: yacEnd, speed: .sprint))
                    waypoints.append(AnimationWaypoint(position: finalPos, time: tackleEnd, speed: .slow))
                } else if isBlocker {
                    // RB assigned to block (pass protection)
                    let blockPos = CGPoint(x: lastPos.x - 3, y: lastPos.y + CGFloat.random(in: -3...3))
                    waypoints.append(AnimationWaypoint(position: blockPos, time: resolutionStart, speed: .slow))
                    waypoints.append(AnimationWaypoint(position: blockPos, time: tackleEnd, speed: .slow))
                } else if isPassRoute {
                    // RB running a pass route (swing, angle, screen)
                    if isThisTarget && result.yardsGained > 0 && !result.isTurnover {
                        let yacPos = CGPoint(x: targetX, y: lastPos.y + CGFloat.random(in: -10...10))
                        waypoints.append(AnimationWaypoint(position: yacPos, time: yacEnd, speed: .sprint))
                        waypoints.append(AnimationWaypoint(position: yacPos, time: tackleEnd, speed: .slow))
                    } else {
                        waypoints.append(AnimationWaypoint(position: lastPos, time: tackleEnd, speed: .normal))
                    }
                } else {
                    waypoints.append(AnimationWaypoint(position: lastPos, time: tackleEnd, speed: .normal))
                }

            case .receiver, .tightend:
                if isBlocker && !isPassRoute {
                    // Receiver/TE assigned to block (run plays, screen plays)
                    if isRun {
                        let blockTarget = CGPoint(x: lastPos.x + 12, y: lastPos.y + CGFloat.random(in: -5...5))
                        waypoints.append(AnimationWaypoint(position: blockTarget, time: resolutionStart, speed: .fast))
                        waypoints.append(AnimationWaypoint(position: blockTarget, time: tackleEnd, speed: .slow))
                    } else {
                        waypoints.append(AnimationWaypoint(position: lastPos, time: tackleEnd, speed: .slow))
                    }
                } else if isThisTarget && isPass && result.yardsGained > 0 && !result.isTurnover {
                    // This is the targeted receiver — catch and YAC
                    let yacPos = CGPoint(x: targetX, y: lastPos.y + CGFloat.random(in: -10...10))
                    waypoints.append(AnimationWaypoint(position: yacPos, time: yacEnd, speed: .sprint))
                    waypoints.append(AnimationWaypoint(position: yacPos, time: tackleEnd, speed: .slow))
                } else {
                    // Non-target: slow down at route endpoint
                    let driftPos = CGPoint(x: lastPos.x + 3, y: lastPos.y + CGFloat.random(in: -3...3))
                    waypoints.append(AnimationWaypoint(position: driftPos, time: tackleEnd, speed: .slow))
                }

            default:
                waypoints.append(AnimationWaypoint(position: lastPos, time: tackleEnd, speed: .slow))
            }

            paths.append(AnimatedPlayerPath(playerIndex: i, role: role, waypoints: waypoints))
        }

        return paths
    }

    /// Find the target receiver index from STOCK.DAT passTarget assignments.
    /// Falls back to heuristic based on route data and play type.
    private static func findStockTargetReceiver(
        players: [StockPlayerEntry],
        result: PlayResult,
        isPass: Bool
    ) -> Int {
        guard isPass else { return 6 } // RB for run plays

        // Look for players with passTarget assignment (0x0101)
        let targetsWithIndices = players.enumerated().filter { _, player in
            player.assignments.contains { $0.type == .passTarget }
        }

        if !targetsWithIndices.isEmpty {
            // Pick the first pass target as the primary receiver
            // In multi-target plays, this is typically the #1 read
            return targetsWithIndices[0].offset
        }

        // Fallback: find the receiver/TE with the deepest route
        let receiversWithIndices = players.enumerated().filter { _, player in
            player.isSkillPosition && !player.isLineman && player.positionCode != 0x0020 // Not QB
        }

        if let deepest = receiversWithIndices.max(by: { a, b in
            let aDepth = a.element.routePhasePosition?.y ?? a.element.preSnapPosition?.y ?? 0
            let bDepth = b.element.routePhasePosition?.y ?? b.element.preSnapPosition?.y ?? 0
            return aDepth < bDepth  // Higher Y = deeper downfield in STOCK.DAT coords
        }) {
            return deepest.offset
        }

        // Last resort: default receiver indices by play type
        switch result.playType {
        case .screen: return 6  // RB
        case .shortPass: return 7  // WR1
        case .deepPass: return 7  // WR1
        default: return 7
        }
    }

    // MARK: - Authentic Defensive Path Builder

    /// Build defensive player paths from authentic STOCK.DAT play data.
    /// Uses STOCK.DAT assignments (rush/coverage/zone) and route waypoints
    /// to drive realistic defensive player movements.
    private static func buildAuthenticDefensivePaths(
        stockPlay: StockPlay,
        result: PlayResult,
        losX: CGFloat,
        centerY: CGFloat,
        totalDuration: Double,
        phases: [AnimationPhase],
        offensivePaths: [AnimatedPlayerPath]
    ) -> [AnimatedPlayerPath] {

        let routeStart = phaseTime(phases, .routesDevelop)?.startTime ?? 0.12
        let routeEnd = phaseTime(phases, .routesDevelop)?.endTime ?? 0.55
        let resolutionEnd = phaseTime(phases, .resolution)?.endTime ?? 0.72
        let yacEnd = phaseTime(phases, .yac)?.endTime ?? 0.88
        let tackleEnd: Double = 1.0
        let isPass = result.playType.isPass
        let gainPixels = CGFloat(result.yardsGained) * yardsPerPixel
        let ballCarrierFinalX = losX + gainPixels

        // Find ball carrier final position for pursuit convergence
        let ballCarrierFinalY: CGFloat
        if isPass {
            // For authentic paths, use the stock target receiver logic
            let targetIdx = findStockTargetReceiverFromOffPaths(offensivePaths: offensivePaths, result: result)
            if targetIdx < offensivePaths.count {
                ballCarrierFinalY = offensivePaths[targetIdx].waypoints.last?.position.y ?? centerY
            } else {
                ballCarrierFinalY = centerY
            }
        } else {
            // RB is at index 6
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

        let roles: [PlayerRole] = [
            .defensiveLine, .defensiveLine, .defensiveLine, .defensiveLine,
            .linebacker, .linebacker, .linebacker,
            .defensiveBack, .defensiveBack, .defensiveBack, .defensiveBack
        ]

        // Sort defensive players into standard order: DL(4), LB(3), DB(4)
        let sorted = sortDefensivePlayersToStandardOrder(stockPlay.players)

        var paths: [AnimatedPlayerPath] = []

        for i in 0..<11 {
            guard i < sorted.count else {
                let fallbackPos = CGPoint(x: losX + 20, y: centerY + CGFloat(i - 5) * 22)
                let wps = [
                    AnimationWaypoint(position: fallbackPos, time: 0.0, speed: .slow),
                    AnimationWaypoint(position: fallbackPos, time: tackleEnd, speed: .slow)
                ]
                paths.append(AnimatedPlayerPath(playerIndex: i, role: roles[i], waypoints: wps))
                continue
            }

            let player = sorted[i]
            let role = roles[i]
            var waypoints: [AnimationWaypoint] = []

            // Pre-snap position from STOCK.DAT PH1
            let startPos: CGPoint
            if let preSnap = player.preSnapPosition {
                startPos = StockDATDecoder.convertToBlueprint(
                    stockPoint: preSnap, losX: losX, centerY: centerY
                )
            } else {
                let formation = FormationPositions.defensivePositions(
                    for: .base43, losX: losX, centerY: centerY
                )
                startPos = i < formation.count ? formation[i] : CGPoint(x: losX + 20, y: centerY)
            }

            waypoints.append(AnimationWaypoint(position: startPos, time: 0.0, speed: .slow))
            waypoints.append(AnimationWaypoint(position: startPos, time: routeStart, speed: .slow))

            // Determine this player's primary assignment from STOCK.DAT
            let isRusher = player.hasRushAssignment
            let isCoverage = player.hasCoverageAssignment
            let hasZone = player.zoneTarget != nil
            let hasStockRoute = !player.routeWaypoints.isEmpty || player.routePhasePosition != nil

            // === Phase 1: Post-snap initial movement (from PH2) ===
            if let postSnap = player.postSnapPosition {
                let postPos = StockDATDecoder.convertToBlueprint(
                    stockPoint: postSnap, losX: losX, centerY: centerY
                )
                let speed: WaypointSpeed = isRusher ? .sprint : .fast
                let postTime = routeStart + (routeEnd - routeStart) * 0.15
                waypoints.append(AnimationWaypoint(position: postPos, time: postTime, speed: speed))
            }

            // === Phase 2: Route development (STOCK.DAT waypoints) ===
            if !player.routeWaypoints.isEmpty {
                let bpWaypoints = StockDATDecoder.convertWaypointsToBlueprint(
                    waypoints: player.routeWaypoints, losX: losX, centerY: centerY
                )
                let wpCount = bpWaypoints.count
                for (wi, wp) in bpWaypoints.enumerated() {
                    let t = routeStart + (routeEnd - routeStart) * Double(wi + 1) / Double(wpCount + 1)
                    let speed: WaypointSpeed = isRusher ? .sprint : .fast
                    waypoints.append(AnimationWaypoint(position: wp, time: t, speed: speed))
                }
            }

            // === Phase 3: Assignment-driven endpoint ===
            if isRusher && !hasStockRoute {
                // Pass rush: charge toward QB if no STOCK.DAT route was given
                let rushTarget = CGPoint(x: qbDropPos.x + 5, y: qbDropPos.y + CGFloat.random(in: -10...10))
                waypoints.append(AnimationWaypoint(position: rushTarget, time: routeEnd, speed: .sprint))
            } else if hasZone {
                // Zone coverage: drop to zone target from STOCK.DAT
                let zonePos = StockDATDecoder.convertToBlueprint(
                    stockPoint: player.zoneTarget!, losX: losX, centerY: centerY
                )
                waypoints.append(AnimationWaypoint(position: zonePos, time: routeEnd, speed: .normal))
            } else if isCoverage && !hasStockRoute {
                // Man coverage without specific route: shadow assigned offensive player
                let coverTarget = findCoverageTargetFromAssignment(
                    player: player, defIndex: i, offensivePaths: offensivePaths, centerY: centerY
                )
                if let receiverPath = offensivePaths[safe: coverTarget] {
                    // Follow receiver with slight trailing offset
                    for wp in receiverPath.waypoints where wp.time >= routeStart && wp.time <= routeEnd {
                        let offset = CGPoint(x: wp.position.x + 5, y: wp.position.y + CGFloat.random(in: -3...3))
                        waypoints.append(AnimationWaypoint(position: offset, time: min(wp.time + 0.02, 1.0), speed: .fast))
                    }
                }
            }

            // Route endpoint (PH3) from STOCK.DAT
            if let routePhase = player.routePhasePosition {
                let routePos = StockDATDecoder.convertToBlueprint(
                    stockPoint: routePhase, losX: losX, centerY: centerY
                )
                waypoints.append(AnimationWaypoint(position: routePos, time: routeEnd, speed: .fast))
            }

            // === Phase 4: Pursuit toward ball carrier ===
            let lastPos = waypoints.last?.position ?? startPos

            // All defenders converge toward the ball carrier after the play develops
            let pursuitSpeed: WaypointSpeed
            let pursuitDist: CGFloat

            if isRusher {
                // Rushers are close to the action — aggressive pursuit
                pursuitSpeed = .sprint
                pursuitDist = 60
            } else if isCoverage || hasZone {
                // Coverage players react and close in
                pursuitSpeed = .fast
                pursuitDist = 50
            } else {
                // Default pursuit angle
                pursuitSpeed = .fast
                pursuitDist = 45
            }

            // Intermediate pursuit point at resolution time
            let midPursuitPos = pursueTarget(from: lastPos, target: ballCarrierFinal, maxDist: pursuitDist * 0.6)
            waypoints.append(AnimationWaypoint(position: midPursuitPos, time: resolutionEnd, speed: pursuitSpeed))

            // Final convergence
            let finalPursuitPos = pursueTarget(from: midPursuitPos, target: ballCarrierFinal, maxDist: pursuitDist)
            waypoints.append(AnimationWaypoint(position: finalPursuitPos, time: tackleEnd, speed: pursuitSpeed))

            paths.append(AnimatedPlayerPath(playerIndex: i, role: role, waypoints: waypoints))
        }

        return paths
    }

    /// Find which offensive player a defensive player should cover based on STOCK.DAT assignment.
    /// Uses the targetPlayerIndex from the coverage assignment, falling back to positional matching.
    private static func findCoverageTargetFromAssignment(
        player: StockPlayerEntry,
        defIndex: Int,
        offensivePaths: [AnimatedPlayerPath],
        centerY: CGFloat
    ) -> Int {
        // Check if STOCK.DAT has an explicit coverage target index
        if let coverageAssignment = player.assignments.first(where: { $0.type == .coverage }) {
            let target = Int(coverageAssignment.targetPlayerIndex)
            if target < offensivePaths.count {
                return target
            }
        }

        // Fallback to positional matching
        return findCoverageTarget(defIndex: defIndex, offensivePaths: offensivePaths, centerY: centerY)
    }

    /// Find the target receiver index from offensive paths for ball carrier pursuit.
    /// Uses the offense's route depth to identify the likely target.
    private static func findStockTargetReceiverFromOffPaths(
        offensivePaths: [AnimatedPlayerPath],
        result: PlayResult
    ) -> Int {
        // For runs, ball carrier is RB (index 6)
        if result.playType.isRun { return 6 }

        // For screen, typically RB or nearby receiver
        if result.playType == .screen { return 6 }

        // For passes: find the receiver whose final position is closest to the gain point
        let gainYards = CGFloat(result.yardsGained) * yardsPerPixel
        let receiverIndices = [7, 8, 9, 10] // WR1, WR2, TE, Slot
        var bestIdx = 7
        var bestMatch: CGFloat = .greatestFiniteMagnitude

        for idx in receiverIndices {
            guard idx < offensivePaths.count else { continue }
            let path = offensivePaths[idx]
            if let lastWP = path.waypoints.last {
                // How far is this receiver's endpoint from the expected catch point?
                let dist = abs(lastWP.position.x - gainYards)
                if dist < bestMatch {
                    bestMatch = dist
                    bestIdx = idx
                }
            }
        }

        return bestIdx
    }

    // MARK: - Player Sorting (STOCK.DAT → Standard 11-player Order)

    /// Sort offensive STOCK.DAT player entries into standard order:
    /// [LT, LG, C, RG, RT, QB, RB, WR1, WR2, TE, Slot/FB]
    private static func sortPlayersToStandardOrder(_ players: [StockPlayerEntry]) -> [StockPlayerEntry] {
        // Separate by position type
        var linemen: [StockPlayerEntry] = []
        var qb: StockPlayerEntry?
        var rbs: [StockPlayerEntry] = []
        var wrs: [StockPlayerEntry] = []
        var tes: [StockPlayerEntry] = []
        var others: [StockPlayerEntry] = []

        for p in players {
            switch p.positionCode {
            case 0x0010, 0x0011, 0x0012: linemen.append(p)
            case 0x0020: qb = p
            case 0x0041, 0x0042: rbs.append(p)
            case 0x0080: wrs.append(p)
            case 0x0081: tes.append(p)
            default: others.append(p)
            }
        }

        // Sort linemen by Y position (left to right: most negative Y = left)
        linemen.sort { ($0.preSnapPosition?.y ?? 0) < ($1.preSnapPosition?.y ?? 0) }

        // Sort WRs by Y position
        wrs.sort { ($0.preSnapPosition?.y ?? 0) < ($1.preSnapPosition?.y ?? 0) }

        // Build ordered array: pad to 11
        var result: [StockPlayerEntry] = []

        // OL (5 spots)
        for i in 0..<5 {
            if i < linemen.count {
                result.append(linemen[i])
            } else {
                // Pad with a dummy entry
                result.append(StockPlayerEntry(
                    side: 0, role: 0, positionCode: 0x0012,
                    preSnapPosition: nil, postSnapPosition: nil,
                    routePhasePosition: nil, routeWaypoints: [],
                    motionTarget: nil, assignments: [],
                    hasQBThrow: false, zoneTarget: nil, delayTicks: 0
                ))
            }
        }

        // QB
        result.append(qb ?? StockPlayerEntry(
            side: 0, role: 2, positionCode: 0x0020,
            preSnapPosition: nil, postSnapPosition: nil,
            routePhasePosition: nil, routeWaypoints: [],
            motionTarget: nil, assignments: [],
            hasQBThrow: false, zoneTarget: nil, delayTicks: 0
        ))

        // RB (first one)
        result.append(rbs.first ?? StockPlayerEntry(
            side: 0, role: 0, positionCode: 0x0041,
            preSnapPosition: nil, postSnapPosition: nil,
            routePhasePosition: nil, routeWaypoints: [],
            motionTarget: nil, assignments: [],
            hasQBThrow: false, zoneTarget: nil, delayTicks: 0
        ))

        // WR1 (leftmost)
        result.append(wrs.first ?? StockPlayerEntry(
            side: 1, role: 0, positionCode: 0x0080,
            preSnapPosition: nil, postSnapPosition: nil,
            routePhasePosition: nil, routeWaypoints: [],
            motionTarget: nil, assignments: [],
            hasQBThrow: false, zoneTarget: nil, delayTicks: 0
        ))

        // WR2 (rightmost or second)
        if wrs.count >= 2 {
            result.append(wrs[wrs.count - 1])
        } else {
            result.append(StockPlayerEntry(
                side: 2, role: 0, positionCode: 0x0080,
                preSnapPosition: nil, postSnapPosition: nil,
                routePhasePosition: nil, routeWaypoints: [],
                motionTarget: nil, assignments: [],
                hasQBThrow: false, zoneTarget: nil, delayTicks: 0
            ))
        }

        // TE
        result.append(tes.first ?? StockPlayerEntry(
            side: 2, role: 0, positionCode: 0x0081,
            preSnapPosition: nil, postSnapPosition: nil,
            routePhasePosition: nil, routeWaypoints: [],
            motionTarget: nil, assignments: [],
            hasQBThrow: false, zoneTarget: nil, delayTicks: 0
        ))

        // Slot/FB (remaining player: second RB, middle WR, or TE)
        let remaining: StockPlayerEntry
        if rbs.count >= 2 {
            remaining = rbs[1]
        } else if wrs.count >= 3 {
            remaining = wrs[1]  // Middle WR
        } else if tes.count >= 2 {
            remaining = tes[1]
        } else if !others.isEmpty {
            remaining = others[0]
        } else {
            remaining = StockPlayerEntry(
                side: 0, role: 0, positionCode: 0x0080,
                preSnapPosition: nil, postSnapPosition: nil,
                routePhasePosition: nil, routeWaypoints: [],
                motionTarget: nil, assignments: [],
                hasQBThrow: false, zoneTarget: nil, delayTicks: 0
            )
        }
        result.append(remaining)

        return result
    }

    /// Sort defensive STOCK.DAT player entries into standard order:
    /// [DL0, DL1, DL2, DL3, LB0, LB1, LB2, DB0, DB1, DB2, DB3]
    private static func sortDefensivePlayersToStandardOrder(_ players: [StockPlayerEntry]) -> [StockPlayerEntry] {
        var dline: [StockPlayerEntry] = []
        var linebackers: [StockPlayerEntry] = []
        var dbacks: [StockPlayerEntry] = []
        var others: [StockPlayerEntry] = []

        for p in players {
            switch p.positionCode {
            case 0x0101, 0x0102: dline.append(p)
            case 0x0200: linebackers.append(p)
            case 0x0400, 0x0401: dbacks.append(p)
            default: others.append(p)
            }
        }

        // Sort each group by Y position
        dline.sort { ($0.preSnapPosition?.y ?? 0) < ($1.preSnapPosition?.y ?? 0) }
        linebackers.sort { ($0.preSnapPosition?.y ?? 0) < ($1.preSnapPosition?.y ?? 0) }
        dbacks.sort { ($0.preSnapPosition?.y ?? 0) < ($1.preSnapPosition?.y ?? 0) }

        var result: [StockPlayerEntry] = []
        let dummy = StockPlayerEntry(
            side: 0, role: 0, positionCode: 0x0102,
            preSnapPosition: nil, postSnapPosition: nil,
            routePhasePosition: nil, routeWaypoints: [],
            motionTarget: nil, assignments: [],
            hasQBThrow: false, zoneTarget: nil, delayTicks: 0
        )

        // DL (4 spots)
        for i in 0..<4 {
            result.append(i < dline.count ? dline[i] : (others.isEmpty ? dummy : others.removeFirst()))
        }

        // LB (3 spots)
        for i in 0..<3 {
            result.append(i < linebackers.count ? linebackers[i] : (others.isEmpty ? dummy : others.removeFirst()))
        }

        // DB (4 spots)
        for i in 0..<4 {
            result.append(i < dbacks.count ? dbacks[i] : (others.isEmpty ? dummy : others.removeFirst()))
        }

        // If extra DL/LB (e.g., 5-2 defense), they get sorted into remaining slots
        // But we always return exactly 11
        return Array(result.prefix(11))
    }
}

// Note: PlayType.isPass, PlayType.isRun are defined in Play.swift
// Note: Array.subscript(safe:) is defined in NavigationBar.swift
