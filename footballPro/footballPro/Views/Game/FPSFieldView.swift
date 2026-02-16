//
//  FPSFieldView.swift
//  footballPro
//
//  Authentic Front Page Sports Football Pro '93 field view
//  Full-screen perspective field, solid green, ~25 yard window centered on LOS
//  Pre-rendered 3D-style player sprites with team colors
//  Green number overlay on ball carrier (matching original game)
//  Amber LED clocks at bottom corners
//  TimelineView-based 30fps animation loop for all 22 players
//

import SwiftUI
import CoreGraphics
import Foundation

// MARK: - Perspective Projection Engine

/// Projects flat field coordinates (640x360 "top-down" space) into
/// perspective screen coordinates for the full-screen field view.
///
/// Matches FPS Football Pro '93: shows ~25 yards of field centered on the LOS.
/// Camera "follows" the ball. Pronounced trapezoid perspective — wide at bottom,
/// narrower at top for isometric feel. Players near camera are noticeably larger.
/// Original game runs at 320x200 with chunky pre-rendered sprites.
struct PerspectiveProjection {
    let screenWidth: CGFloat
    let screenHeight: CGFloat

    let fieldCenterX: CGFloat
    let fieldTop: CGFloat       // Far edge of visible field on screen
    let fieldBottom: CGFloat    // Near edge of visible field on screen
    let nearWidth: CGFloat      // Width of field at bottom (near)
    let farWidth: CGFloat       // Width of field at top (far)

    // Source field dimensions (flat top-down space from PlayBlueprintGenerator)
    let flatFieldWidth: CGFloat = 640
    let flatFieldHeight: CGFloat = 360
    let flatEndZoneWidth: CGFloat = 32   // 640 * 0.05
    let flatPlayFieldWidth: CGFloat = 576 // 640 * 0.90

    // Visible yard window — ~25 yards visible matching original FPS '93
    let visibleYardsBehind: CGFloat = 8    // yards behind LOS shown
    let visibleYardsAhead: CGFloat = 17   // yards ahead of LOS shown
    var totalVisibleYards: CGFloat { visibleYardsBehind + visibleYardsAhead }

    let focusYardFlatX: CGFloat

    init(screenWidth: CGFloat, screenHeight: CGFloat, losYardLine: Int, isFieldFlipped: Bool) {
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.fieldCenterX = screenWidth / 2

        let endZone: CGFloat = 32
        let playField: CGFloat = 576
        if isFieldFlipped {
            self.focusYardFlatX = endZone + (CGFloat(100 - losYardLine) / 100.0) * playField
        } else {
            self.focusYardFlatX = endZone + (CGFloat(losYardLine) / 100.0) * playField
        }

        // Full-screen: field fills the entire view
        self.fieldTop = 0
        self.fieldBottom = screenHeight

        // Pronounced perspective like original FPS '93: wider at bottom, narrower at top
        self.nearWidth = screenWidth * 1.05
        self.farWidth = screenWidth * 0.82
    }

    /// Camera-tracking init: focus on an arbitrary flat X position (for following ball carrier).
    /// `focusFlatX` is in raw blueprint coordinate space (0–640).
    init(screenWidth: CGFloat, screenHeight: CGFloat, focusFlatX: CGFloat) {
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.fieldCenterX = screenWidth / 2
        self.focusYardFlatX = focusFlatX
        self.fieldTop = 0
        self.fieldBottom = screenHeight
        self.nearWidth = screenWidth * 1.05
        self.farWidth = screenWidth * 0.82
    }

    func depthToScreenY(_ depth: CGFloat) -> CGFloat {
        let clamped = min(max(depth, 0), 1)
        // Non-linear depth compression — more pronounced for isometric feel
        let t = pow(clamped, 0.80)
        return fieldBottom + (fieldTop - fieldBottom) * t
    }

    func widthAtDepth(_ depth: CGFloat) -> CGFloat {
        let clamped = min(max(depth, 0), 1)
        let t = pow(clamped, 0.80)
        return nearWidth + (farWidth - nearWidth) * t
    }

    func scaleAtDepth(_ depth: CGFloat) -> CGFloat {
        let w = widthAtDepth(depth)
        return max(w / nearWidth, 0.50)
    }

    func flatXToDepth(_ flatX: CGFloat, isFieldFlipped: Bool) -> CGFloat {
        let flatYardsPerPixel = flatPlayFieldWidth / 100.0

        let nearFlatX: CGFloat
        let farFlatX: CGFloat

        if isFieldFlipped {
            nearFlatX = focusYardFlatX + visibleYardsBehind * flatYardsPerPixel
            farFlatX = focusYardFlatX - visibleYardsAhead * flatYardsPerPixel
            let range = nearFlatX - farFlatX
            if range <= 0 { return 0.5 }
            return (nearFlatX - flatX) / range
        } else {
            nearFlatX = focusYardFlatX - visibleYardsBehind * flatYardsPerPixel
            farFlatX = focusYardFlatX + visibleYardsAhead * flatYardsPerPixel
            let range = farFlatX - nearFlatX
            if range <= 0 { return 0.5 }
            return (flatX - nearFlatX) / range
        }
    }

    func project(flatPos: CGPoint, isFieldFlipped: Bool) -> CGPoint {
        let depth = flatXToDepth(flatPos.x, isFieldFlipped: isFieldFlipped)
        let lateral = (flatPos.y / flatFieldHeight) - 0.5
        let screenY = depthToScreenY(depth)
        let w = widthAtDepth(depth)
        let screenX = fieldCenterX + lateral * w
        return CGPoint(x: screenX, y: screenY)
    }

    func yardToDepth(_ yard: Int, isFieldFlipped: Bool) -> CGFloat {
        let flatX: CGFloat
        if isFieldFlipped {
            flatX = flatEndZoneWidth + (CGFloat(100 - yard) / 100.0) * flatPlayFieldWidth
        } else {
            flatX = flatEndZoneWidth + (CGFloat(yard) / 100.0) * flatPlayFieldWidth
        }
        return flatXToDepth(flatX, isFieldFlipped: isFieldFlipped)
    }

    func visibleYardRange(isFieldFlipped: Bool) -> (Int, Int) {
        let flatYardsPerPixel = flatPlayFieldWidth / 100.0

        let nearFlatX: CGFloat
        let farFlatX: CGFloat

        if isFieldFlipped {
            nearFlatX = focusYardFlatX + visibleYardsBehind * flatYardsPerPixel
            farFlatX = focusYardFlatX - visibleYardsAhead * flatYardsPerPixel
        } else {
            nearFlatX = focusYardFlatX - visibleYardsBehind * flatYardsPerPixel
            farFlatX = focusYardFlatX + visibleYardsAhead * flatYardsPerPixel
        }

        let nearYardRaw: Int
        let farYardRaw: Int
        if isFieldFlipped {
            nearYardRaw = 100 - Int(((nearFlatX - flatEndZoneWidth) / flatPlayFieldWidth) * 100)
            farYardRaw = 100 - Int(((farFlatX - flatEndZoneWidth) / flatPlayFieldWidth) * 100)
        } else {
            nearYardRaw = Int(((nearFlatX - flatEndZoneWidth) / flatPlayFieldWidth) * 100)
            farYardRaw = Int(((farFlatX - flatEndZoneWidth) / flatPlayFieldWidth) * 100)
        }

        let minYard = max(-5, min(nearYardRaw, farYardRaw))
        let maxYard = min(105, max(nearYardRaw, farYardRaw))
        return (minYard, maxYard)
    }

    func trapezoid(depthNear: CGFloat, depthFar: CGFloat) -> (CGPoint, CGPoint, CGPoint, CGPoint) {
        let yNear = depthToScreenY(depthNear)
        let yFar = depthToScreenY(depthFar)
        let wNear = widthAtDepth(depthNear)
        let wFar = widthAtDepth(depthFar)

        let topLeft = CGPoint(x: fieldCenterX - wFar / 2, y: yFar)
        let topRight = CGPoint(x: fieldCenterX + wFar / 2, y: yFar)
        let botRight = CGPoint(x: fieldCenterX + wNear / 2, y: yNear)
        let botLeft = CGPoint(x: fieldCenterX - wNear / 2, y: yNear)
        return (topLeft, topRight, botRight, botLeft)
    }
}

// MARK: - FPSFieldView

struct FPSFieldView: View {
    @ObservedObject var viewModel: GameViewModel

    @State private var offensePlayers: [FPSPlayer] = []
    @State private var defensePlayers: [FPSPlayer] = []
    @State private var ballPosition: CGPoint = .zero
    @State private var isAnimatingPlay = false

    @State private var currentBlueprint: PlayAnimationBlueprint?
    @State private var animationStartTime: Date?

    /// Whether authentic sprites are loaded and ready for rendering
    @State private var spritesLoaded = false

    @State private var lastTickTime: Date?

    /// Optional frame logger (JSONL) for timing alignment against DOS captures.
    /// Enable by launching the app with `FPS_FRAME_LOG=/tmp/fps_frames.jsonl`.
    @State private var frameLogHandle: FileHandle?
    @State private var frameLogIndex: Int = 0
    private let frameLogEnvKey = "FPS_FRAME_LOG"

    // Internal flat field dimensions (blueprint coordinate space)
    private let flatFieldWidth: CGFloat = 640
    private let flatFieldHeight: CGFloat = 360
    private let flatPlayCenter: CGFloat = 180  // Y center of the 360-high field

    /// Camera smoothing factor — lower = smoother/slower follow (0.05 = very smooth, 0.2 = snappy)
    private let cameraSmoothing: CGFloat = 0.08

    /// Base scale multiplier for authentic sprites (original 320x200 VGA -> 640x360 blueprint space)
    private let spriteBaseScale: CGFloat = 2.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isAnimatingPlay, let blueprint = currentBlueprint, let startTime = animationStartTime {
                    // === ANIMATED RENDERING ===
                    // Projection is computed per-frame inside TimelineView so camera can track the ball.
                    // Use a periodic timeline to ensure ticks even without implicit SwiftUI animations.
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
                        renderAnimatedFrame(
                            timeline: timeline,
                            geo: geo,
                            blueprint: blueprint,
                            startTime: startTime
                        )
                    }
                } else {
                    // === STATIC RENDERING (pre-snap / between plays) ===
                    let staticProj = PerspectiveProjection(
                        screenWidth: geo.size.width,
                        screenHeight: geo.size.height,
                        losYardLine: viewModel.game?.fieldPosition.yardLine ?? 50,
                        isFieldFlipped: isFieldFlipped
                    )

                    // Field surface
                    Canvas { context, size in
                        drawField(context: context, size: size, proj: staticProj)
                    }

                    // Static players — z-ordered back-to-front
                    let allPlayers: [(player: FPSPlayer, isDefense: Bool, arrayIndex: Int)] =
                        defensePlayers.enumerated().map { (player: $0.element, isDefense: true, arrayIndex: $0.offset) } +
                        offensePlayers.enumerated().map { (player: $0.element, isDefense: false, arrayIndex: $0.offset) }

                    ForEach(0..<allPlayers.count, id: \.self) { idx in
                        let entry = allPlayers[idx]
                        let screenPos = staticProj.project(flatPos: entry.player.position, isFieldFlipped: isFieldFlipped)
                        let depth = staticProj.flatXToDepth(entry.player.position.x, isFieldFlipped: isFieldFlipped)
                        let scale = staticProj.scaleAtDepth(depth)

                        // Pre-snap poses: match authentic FPS '93 stances
                        let preSnapPose: PlayerPose = {
                            switch entry.player.role {
                            case .lineman, .defensiveLine: return .threePointStance
                            case .linebacker, .defensiveBack, .cornerback, .safety: return .dbReady
                            case .quarterback: return .standing
                            default: return .standing
                            }
                        }()

                        let staticPlayer = makeAnimatedPlayer(
                            entry.isDefense ? defensePlayers : offensePlayers,
                            entry.arrayIndex,
                            position: screenPos, isMoving: false, facing: entry.isDefense ? .pi : 0,
                            hasBall: false, pose: preSnapPose
                        )
                        let staticSprFrame = authenticSpriteFrame(
                            pose: preSnapPose,
                            role: entry.player.role,
                            isDefense: entry.isDefense,
                            hasBall: false,
                            facing: 0,
                            animProgress: 0
                        )
                        AuthenticPlayerSprite(
                            player: staticPlayer,
                            isDefense: entry.isDefense,
                            spriteFrame: staticSprFrame,
                            baseScale: spriteBaseScale * scale
                        )
                        .zIndex(Double(depth) * 1000)
                    }

                    // Static football at LOS
                    let ballScreen = staticProj.project(flatPos: ballPosition, isFieldFlipped: isFieldFlipped)
                    let ballDepth = staticProj.flatXToDepth(ballPosition.x, isFieldFlipped: isFieldFlipped)
                    let ballScale = staticProj.scaleAtDepth(ballDepth)

                    FootballSprite()
                        .position(ballScreen)
                        .scaleEffect(ballScale)
                        .zIndex(Double(ballDepth) * 1000 + 0.5)

                    // Amber LED clocks
                    animationClockOverlay
                }
            }
        }
        .onAppear {
            setupFieldPositions()
            if let blueprint = viewModel.currentAnimationBlueprint, !isAnimatingPlay {
                startAnimation(blueprint: blueprint)
            }
            // Load authentic sprites from ANIM.DAT
            if !spritesLoaded {
                if SpriteCache.shared.animationInfo(named: "SKRUN") == nil {
                    SpriteCache.shared.load()
                }
                spritesLoaded = SpriteCache.shared.isAvailable
            }
        }
        .onChange(of: viewModel.game) { _, _ in
            if !isAnimatingPlay { setupFieldPositions() }
        }
        .onChange(of: viewModel.game?.fieldPosition.yardLine) { _, _ in
            if !isAnimatingPlay { setupFieldPositions() }
        }
        .onChange(of: viewModel.isUserPossession) { _, _ in
            if !isAnimatingPlay { setupFieldPositions() }
        }
        .onChange(of: viewModel.currentAnimationBlueprint) { _, newBlueprint in
            if let blueprint = newBlueprint {
                startAnimation(blueprint: blueprint)
            }
        }
    }

    // MARK: - Clock Overlay

    private var animationClockOverlay: some View {
        VStack {
            Spacer()
            HStack {
                if let game = viewModel.game {
                    FPSDigitalClock(time: game.clock.displayTime, fontSize: 16)
                        .padding(8)
                }
                Spacer()
                FPSDigitalClock(time: "\(viewModel.playClockSeconds)", fontSize: 16)
                    .padding(8)
            }
        }
    }

    // MARK: - Pose Determination

    /// Determine the visual pose for a player based on role, phase, and movement state.
    private func determinePose(
        role: PlayerRole,
        isDefense: Bool,
        isMoving: Bool,
        hasBall: Bool,
        phase: AnimationPhase?,
        progress: Double
    ) -> PlayerPose {
        let phaseName = phase?.name ?? .preSnap

        switch phaseName {
        case .preSnap:
            // Authentic pre-snap stances matching FPS '93
            switch role {
            case .lineman:
                return .threePointStance       // OL in 3-point stance (LMT3PT)
            case .defensiveLine:
                return .threePointStance       // DL in 3-point stance (LMT3PT)
            case .quarterback:
                return .standing               // QB upright (QBPSET)
            case .linebacker:
                return .dbReady                // LB in ready crouch (DBREADY)
            case .defensiveBack, .cornerback, .safety:
                return .dbReady                // DBs in ready crouch (DBREADY)
            default:
                return .standing               // WR/TE/RB upright (LMSTAND)
            }

        case .snap:
            // Ball snapped — linemen engage, QB receives, receivers start
            switch role {
            case .lineman:
                return .blocking               // OL fires into blocks (LMPUSH)
            case .defensiveLine:
                return .running                // DL rushes off line (LMRUN)
            case .quarterback:
                return .qbUnderCenter          // QB receiving snap (QBSNP)
            case .linebacker:
                return isMoving ? .running : .dbReady
            case .defensiveBack, .cornerback, .safety:
                return .backpedaling           // DBs drop back (SKRUN)
            default:
                return isMoving ? .running : .standing
            }

        case .routesDevelop:
            // Routes developing — everyone in motion
            if hasBall {
                return .running                // Ball carrier runs (RBRNWB)
            }
            switch role {
            case .lineman:
                return .blocking               // OL sustains blocks (LMPUSH)
            case .defensiveLine:
                return .running                // DL pursuing (LMRUN)
            case .quarterback:
                return .throwing               // QB in pocket/throwing (QBBULIT)
            case .runningback, .runningBack, .fullback:
                return isMoving ? .running : .standing
            case .receiver, .tightend:
                return .running                // Running routes (SKRUN)
            case .linebacker:
                return isMoving ? .running : .dbReady
            case .defensiveBack, .cornerback, .safety:
                return isMoving ? .running : .backpedaling
            }

        case .resolution:
            // Ball thrown/caught/handed off — key action moment
            if hasBall {
                return .running                // Ball carrier running (RBRNWB)
            }
            switch role {
            case .lineman:
                return .blocking               // OL still blocking
            case .defensiveLine:
                return .running                // DL pursuing
            case .quarterback:
                return .throwing               // QB follow-through (QBBULIT)
            case .receiver, .tightend:
                return isMoving ? .running : .catching  // FCATCH if target
            case .linebacker, .defensiveBack, .cornerback, .safety:
                return isMoving ? .running : .standing
            default:
                return isMoving ? .running : .standing
            }

        case .yac:
            // Yards after catch/contact — ball carrier running, defenders converging
            if hasBall {
                return .running                // Ball carrier still going (RBRNWB)
            }
            if isDefense && isMoving {
                return .running                // Defenders pursuing (SKRUN/LMRUN)
            }
            switch role {
            case .lineman:
                return .standing               // OL done blocking
            default:
                return isMoving ? .running : .standing
            }

        case .tackle:
            // Play ending — ball carrier goes down, tacklers dive in
            if hasBall {
                // Ball carrier hit — play diving animation then go down
                let phaseProgress = phase.map { (progress - $0.startTime) / ($0.endTime - $0.startTime) } ?? 1.0
                if phaseProgress < 0.5 {
                    return .diving             // Going down (SKDIVE/LMDIVE)
                } else {
                    return .down               // On the ground
                }
            }
            if isDefense && isMoving {
                return .tackling               // Tackler making contact (SLTKSDL/LMCHK)
            }
            return .standing
        }
    }

    // MARK: - Animated Frame Rendering

    private func renderAnimatedFrame(
        timeline: TimelineViewDefaultContext,
        geo: GeometryProxy,
        blueprint: PlayAnimationBlueprint,
        startTime: Date
    ) -> some View {
        let elapsed = timeline.date.timeIntervalSince(startTime)
        let progress = min(elapsed / blueprint.totalDuration, 1.0)

        // Determine ball position in flat space for camera tracking
        let ballFlatPos = blueprint.ballPath.flatPosition(
            at: progress,
            offensivePaths: blueprint.offensivePaths,
            defensivePaths: blueprint.defensivePaths
        )

        // Smooth camera tracking: lerp toward ball's flat X
        let targetFocusX = ballFlatPos.x
        let smoothedFocusX = viewModel.cameraFocusX + (targetFocusX - viewModel.cameraFocusX) * cameraSmoothing

        // Per-frame projection centered on ball carrier
        let animProj = PerspectiveProjection(
            screenWidth: geo.size.width,
            screenHeight: geo.size.height,
            focusFlatX: smoothedFocusX
        )

        // Determine current phase and ball carrier
        let currentPhase = blueprint.currentPhase(at: progress)
        let carrier = blueprint.ballPath.ballCarrier(at: progress)

        logFrameIfNeeded(
            progress: progress,
            elapsed: elapsed,
            phase: currentPhase,
            projection: animProj,
            ballFlat: ballFlatPos,
            carrier: carrier,
            blueprint: blueprint
        )

        return ZStack {
            // Field surface (redraws per-frame with tracked camera)
            Canvas { context, size in
                drawField(context: context, size: size, proj: animProj)
            }

            // All 22 players with animated positions, poses, and ball carrier flag
            ForEach(0..<(defensePlayers.count + offensePlayers.count), id: \.self) { idx in
                let isDefense = idx < defensePlayers.count
                let i = isDefense ? idx : idx - defensePlayers.count
                let players = isDefense ? defensePlayers : offensePlayers
                let paths = isDefense ? blueprint.defensivePaths : blueprint.offensivePaths

                let path = i < paths.count ? paths[i] : nil
                let rawPos = path?.position(at: progress) ?? players[i].position
                let moving = path?.isMoving(at: progress) ?? false
                let facing: Double = {
                    let f = path?.facingDirection(at: progress) ?? 0
                    if moving || abs(f) > 0.0001 { return f }
                    return isDefense ? .pi : 0
                }()
                let screenPos = animProj.project(flatPos: rawPos, isFieldFlipped: isFieldFlipped)
                let depth = animProj.flatXToDepth(rawPos.x, isFieldFlipped: isFieldFlipped)
                let scale = animProj.scaleAtDepth(depth)

                // Determine if this player has the ball
                let playerHasBall: Bool = {
                    guard let c = carrier else { return false }
                    return c.playerIndex == i && c.isOffense == !isDefense
                }()

                // Determine pose
                let role = path?.role ?? players[i].role
                let pose = determinePose(
                    role: role,
                    isDefense: isDefense,
                    isMoving: moving,
                    hasBall: playerHasBall,
                    phase: currentPhase,
                    progress: progress
                )

                let animatedPlayer = makeAnimatedPlayer(
                    players, i,
                    position: screenPos,
                    isMoving: moving,
                    facing: facing,
                    hasBall: playerHasBall,
                    pose: pose
                )
                let sprFrame = animatedSpriteFrame(
                    pose: pose, role: role, isDefense: isDefense,
                    playerIndex: i, hasBall: playerHasBall,
                    facing: facing, phase: currentPhase, elapsed: elapsed
                )
                AuthenticPlayerSprite(
                    player: animatedPlayer,
                    isDefense: isDefense,
                    spriteFrame: sprFrame,
                    baseScale: spriteBaseScale * scale
                )
                .zIndex(Double(depth) * 1000)
            }

            // Football (only draw separately when not held by a player)
            if carrier == nil {
                let rawBallPos = ballFlatPos
                let ballScreen = animProj.project(flatPos: rawBallPos, isFieldFlipped: isFieldFlipped)
                let ballDepth = animProj.flatXToDepth(rawBallPos.x, isFieldFlipped: isFieldFlipped)
                let ballScale = animProj.scaleAtDepth(ballDepth)

                FootballSprite()
                    .position(ballScreen)
                    .scaleEffect(ballScale)
                    .zIndex(Double(ballDepth) * 1000 + 0.5)
            }

            // Amber LED clocks
            animationClockOverlay

            // Player control indicator — ball carrier silhouette + jersey number
            if let c = carrier {
                let carrierPlayers = c.isOffense ? offensePlayers : defensePlayers
                let jerseyNum = c.playerIndex < carrierPlayers.count ? carrierPlayers[c.playerIndex].number : 0
                PlayerControlIndicator(jerseyNumber: jerseyNum)
            }
        }
        .onChange(of: progress >= 1.0) { _, finished in
            if finished { endAnimation() }
        }
        .onChange(of: smoothedFocusX) { _, newX in
            viewModel.cameraFocusX = newX
        }
    }

    // MARK: - Animation Control

    private func startAnimation(blueprint: PlayAnimationBlueprint) {
        currentBlueprint = blueprint
        isAnimatingPlay = true
        animationStartTime = Date()
        lastTickTime = nil
        // Initialize optional frame logger
        if let logPath = ProcessInfo.processInfo.environment[frameLogEnvKey] {
            prepareFrameLog(at: logPath)
        } else {
            frameLogHandle = nil
        }

        // Initialize per-player animation states (11 offense + 11 defense)
        viewModel.offAnimStates = Array(repeating: PlayerAnimationState(), count: max(offensePlayers.count, 11))
        viewModel.defAnimStates = Array(repeating: PlayerAnimationState(), count: max(defensePlayers.count, 11))

        // Initialize camera focus on the LOS
        if let game = viewModel.game {
            viewModel.cameraFocusX = yardToFlatX(game.fieldPosition.yardLine)
        }
    }

    private func endAnimation() {
        isAnimatingPlay = false
        currentBlueprint = nil
        animationStartTime = nil
        lastTickTime = nil
        try? frameLogHandle?.close()
        frameLogHandle = nil
        viewModel.offAnimStates = []
        viewModel.defAnimStates = []
        viewModel.currentAnimationBlueprint = nil
        setupFieldPositions()
    }

    /// Prepare JSONL frame log for timing alignment when FPS_FRAME_LOG is set.
    private func prepareFrameLog(at path: String) {
        do {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(at: url)
            }
            FileManager.default.createFile(atPath: path, contents: nil)
            frameLogHandle = try FileHandle(forWritingTo: url)
            frameLogIndex = 0
        } catch {
            print("FPS_FRAME_LOG: unable to open \(path): \(error)")
            frameLogHandle = nil
        }
    }

    /// Log one animation frame (positions/poses) to JSONL for external comparison to DOS captures.
    private func logFrame(
        progress: Double,
        elapsed: Double,
        phase: AnimationPhase?,
        projection: PerspectiveProjection,
        ballFlat: CGPoint,
        carrier: (playerIndex: Int, isOffense: Bool)?,
        blueprint: PlayAnimationBlueprint
    ) {
        guard let handle = frameLogHandle else { return }

        struct FramePoint: Codable { let x: Double; let y: Double }
        struct FramePlayer: Codable {
            let isDefense: Bool
            let index: Int
            let role: String
            let hasBall: Bool
            let moving: Bool
            let pose: String
            let facing: Double
            let flat: FramePoint
            let screen: FramePoint
            let depth: Double
        }
        struct FrameEntry: Codable {
            let idx: Int
            let elapsed: Double
            let progress: Double
            let phase: String
            let ballFlat: FramePoint
            let ballScreen: FramePoint
            let players: [FramePlayer]
        }

        let ballScreen = projection.project(flatPos: ballFlat, isFieldFlipped: isFieldFlipped)

        func capturePlayers(paths: [AnimatedPlayerPath], isDefense: Bool) -> [FramePlayer] {
            paths.enumerated().map { (idx, path) in
                let rawPos = path.position(at: progress)
                let screenPos = projection.project(flatPos: rawPos, isFieldFlipped: isFieldFlipped)
                let depth = projection.flatXToDepth(rawPos.x, isFieldFlipped: isFieldFlipped)
                let moving = path.isMoving(at: progress)
                let facing = path.facingDirection(at: progress)
                let hasBall = carrier.map { $0.playerIndex == idx && $0.isOffense == !isDefense } ?? false
                let role = path.role
                let pose = determinePose(
                    role: role,
                    isDefense: isDefense,
                    isMoving: moving,
                    hasBall: hasBall,
                    phase: phase,
                    progress: progress
                )
                return FramePlayer(
                    isDefense: isDefense,
                    index: idx,
                    role: "\(role)",
                    hasBall: hasBall,
                    moving: moving,
                    pose: "\(pose)",
                    facing: facing,
                    flat: FramePoint(x: rawPos.x, y: rawPos.y),
                    screen: FramePoint(x: screenPos.x, y: screenPos.y),
                    depth: depth
                )
            }
        }

        let players = capturePlayers(paths: blueprint.offensivePaths, isDefense: false) +
            capturePlayers(paths: blueprint.defensivePaths, isDefense: true)

        let entry = FrameEntry(
            idx: frameLogIndex,
            elapsed: elapsed,
            progress: progress,
            phase: phase?.name.rawValue ?? "unknown",
            ballFlat: FramePoint(x: ballFlat.x, y: ballFlat.y),
            ballScreen: FramePoint(x: ballScreen.x, y: ballScreen.y),
            players: players
        )

        do {
            let data = try JSONEncoder().encode(entry)
            if let nl = "\n".data(using: .utf8) {
                handle.write(data)
                handle.write(nl)
            }
            frameLogIndex += 1
        } catch {
            print("FPS_FRAME_LOG encode failed: \(error)")
        }
    }

    /// Lightweight wrapper to guard the expensive logging call.
    private func logFrameIfNeeded(
        progress: Double,
        elapsed: Double,
        phase: AnimationPhase?,
        projection: PerspectiveProjection,
        ballFlat: CGPoint,
        carrier: (playerIndex: Int, isOffense: Bool)?,
        blueprint: PlayAnimationBlueprint
    ) {
        guard frameLogHandle != nil || ProcessInfo.processInfo.environment[frameLogEnvKey] != nil else { return }
        logFrame(
            progress: progress,
            elapsed: elapsed,
            phase: phase,
            projection: projection,
            ballFlat: ballFlat,
            carrier: carrier,
            blueprint: blueprint
        )
    }

    // MARK: - Field Drawing (Canvas)

    private func drawField(context: GraphicsContext, size: CGSize, proj: PerspectiveProjection) {
        let w = size.width
        let h = size.height

        // Background — dark area beyond sidelines
        let bgDark = Color(red: 0.08, green: 0.08, blue: 0.08)
        context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(bgDark))

        // Stadium backdrop — simplified stands visible when near end zones
        drawStadiumBackdrop(context: context, size: size, proj: proj)

        // Gray sideline border strips (track/concrete area beyond sidelines)
        // These follow the perspective projection — wider at bottom, narrower at top
        let sidelineGray = Color(red: 0.50, green: 0.50, blue: 0.50)
        let borderFraction: CGFloat = 0.06  // Width of gray strip as fraction of field width

        let nearLeft = CGPoint(x: proj.fieldCenterX - proj.nearWidth / 2, y: proj.fieldBottom)
        let nearRight = CGPoint(x: proj.fieldCenterX + proj.nearWidth / 2, y: proj.fieldBottom)
        let farLeft = CGPoint(x: proj.fieldCenterX - proj.farWidth / 2, y: proj.fieldTop)
        let farRight = CGPoint(x: proj.fieldCenterX + proj.farWidth / 2, y: proj.fieldTop)

        let nearBorderW = proj.nearWidth * borderFraction
        let farBorderW = proj.farWidth * borderFraction

        // Left gray strip
        var leftStrip = Path()
        leftStrip.move(to: CGPoint(x: nearLeft.x - nearBorderW, y: proj.fieldBottom))
        leftStrip.addLine(to: CGPoint(x: farLeft.x - farBorderW, y: proj.fieldTop))
        leftStrip.addLine(to: farLeft)
        leftStrip.addLine(to: nearLeft)
        leftStrip.closeSubpath()
        context.fill(leftStrip, with: .color(sidelineGray))

        // Right gray strip
        var rightStrip = Path()
        rightStrip.move(to: nearRight)
        rightStrip.addLine(to: farRight)
        rightStrip.addLine(to: CGPoint(x: farRight.x + farBorderW, y: proj.fieldTop))
        rightStrip.addLine(to: CGPoint(x: nearRight.x + nearBorderW, y: proj.fieldBottom))
        rightStrip.closeSubpath()
        context.fill(rightStrip, with: .color(sidelineGray))

        // Green field surface with alternating grass stripes every 5 yards (matching original FPS '93)
        let fieldGreenLight = Color(red: 0.18, green: 0.54, blue: 0.18)  // #2D8A2D lighter band
        let fieldGreenDark = Color(red: 0.14, green: 0.50, blue: 0.14)   // #248024 darker band

        // Base fill with darker green
        var fieldTrapezoid = Path()
        fieldTrapezoid.move(to: nearLeft)
        fieldTrapezoid.addLine(to: farLeft)
        fieldTrapezoid.addLine(to: farRight)
        fieldTrapezoid.addLine(to: nearRight)
        fieldTrapezoid.closeSubpath()
        context.fill(fieldTrapezoid, with: .color(fieldGreenDark))

        let (minYard, maxYard) = proj.visibleYardRange(isFieldFlipped: isFieldFlipped)

        // Draw alternating grass stripes every 5 yards (light bands on even 5-yard zones)
        // Zones: 0-5 = zone 0, 5-10 = zone 1, etc. Even zones get lighter stripe.
        let stripeMinYard = max(-10, minYard - 5)
        let stripeMaxYard = min(110, maxYard + 5)
        for zoneStart in stride(from: (stripeMinYard / 5) * 5, through: stripeMaxYard, by: 5) {
            let zoneIndex = zoneStart / 5
            guard zoneIndex % 2 == 0 else { continue }  // Only draw light stripes on even zones

            let yardNear = zoneStart
            let yardFar = zoneStart + 5

            let depthNear = proj.yardToDepth(yardNear, isFieldFlipped: isFieldFlipped)
            let depthFar = proj.yardToDepth(yardFar, isFieldFlipped: isFieldFlipped)

            // Clamp to visible range
            let dMin = min(depthNear, depthFar)
            let dMax = max(depthNear, depthFar)
            if dMax < -0.05 || dMin > 1.05 { continue }

            let clampedNear = max(0, min(dMin, 1.0))
            let clampedFar = max(0, min(dMax, 1.0))

            let (tl, tr, br, bl) = proj.trapezoid(depthNear: clampedNear, depthFar: clampedFar)
            var stripePath = Path()
            stripePath.move(to: bl)
            stripePath.addLine(to: tl)
            stripePath.addLine(to: tr)
            stripePath.addLine(to: br)
            stripePath.closeSubpath()
            context.fill(stripePath, with: .color(fieldGreenLight))
        }

        // End zones — same green as field in original FPS '93 (no colored fill)

        // Yard lines — thick and prominent like original FPS '93
        for yard in stride(from: max(0, minYard), through: min(100, maxYard), by: 5) {
            let depth = proj.yardToDepth(yard, isFieldFlipped: isFieldFlipped)
            if depth < -0.05 || depth > 1.05 { continue }

            let isGoalLine = yard == 0 || yard == 100
            let isTenYardLine = yard % 10 == 0
            let lineOpacity: Double = isGoalLine ? 1.0 : (isTenYardLine ? 0.95 : 0.7)

            let screenY = proj.depthToScreenY(depth)
            let halfW = proj.widthAtDepth(depth) / 2
            let scale = proj.scaleAtDepth(depth)

            let leftPt = CGPoint(x: proj.fieldCenterX - halfW, y: screenY)
            let rightPt = CGPoint(x: proj.fieldCenterX + halfW, y: screenY)

            // Thicker lines — original game has very prominent yard lines
            let lineWidth: CGFloat = isGoalLine ? 4.0 : (isTenYardLine ? 3.0 : 1.5)
            let linePath = Path { p in
                p.move(to: leftPt)
                p.addLine(to: rightPt)
            }
            context.stroke(linePath, with: .color(VGA.fieldLine.opacity(lineOpacity)),
                          lineWidth: lineWidth * scale)

            // Yard numbers — vertically stacked digits near sidelines (FPS '93 style)
            if isTenYardLine && yard > 0 && yard < 100 {
                let displayNum = yard <= 50 ? yard : (100 - yard)
                let digits = String(displayNum).map { String($0) }
                let leftNumX = proj.fieldCenterX - halfW * 0.92
                let rightNumX = proj.fieldCenterX + halfW * 0.92

                for (index, digit) in digits.enumerated() {
                    // Offset each digit vertically (~1.5 yards apart in field space)
                    let yardOffset = CGFloat(index) * 1.5 - CGFloat(digits.count - 1) * 0.75
                    let digitDepth = depth + yardOffset * 0.01  // approximate depth shift
                    let digitScreenY = screenY + yardOffset * 12 * scale
                    let digitFontSize = max(14, 22 * scale)
                    let verticalSquash = max(0.35, 0.55 * scale)

                    let resolvedDigit = context.resolve(
                        Text(digit)
                            .font(.system(size: digitFontSize, weight: .heavy, design: .monospaced))
                            .foregroundColor(VGA.fieldLine.opacity(0.95))
                    )

                    // Left sideline — draw with vertical perspective squash
                    context.drawLayer { layerCtx in
                        layerCtx.translateBy(x: leftNumX, y: digitScreenY)
                        layerCtx.scaleBy(x: 1.0, y: verticalSquash)
                        layerCtx.translateBy(x: -leftNumX, y: -digitScreenY)
                        layerCtx.draw(resolvedDigit, at: CGPoint(x: leftNumX, y: digitScreenY))
                    }

                    // Right sideline
                    context.drawLayer { layerCtx in
                        layerCtx.translateBy(x: rightNumX, y: digitScreenY)
                        layerCtx.scaleBy(x: 1.0, y: verticalSquash)
                        layerCtx.translateBy(x: -rightNumX, y: -digitScreenY)
                        layerCtx.draw(resolvedDigit, at: CGPoint(x: rightNumX, y: digitScreenY))
                    }
                }

                // Directional triangle pointing toward nearer end zone
                if displayNum != 50 {
                    let triSize = max(3, 6 * scale)
                    let pointsUp = (yard < 50) != isFieldFlipped  // toward lower yard numbers
                    for sideX in [leftNumX, rightNumX] {
                        let triX = sideX + (sideX < proj.fieldCenterX ? triSize * 2.5 : -triSize * 2.5)
                        var triPath = Path()
                        if pointsUp {
                            triPath.move(to: CGPoint(x: triX, y: screenY - triSize))
                            triPath.addLine(to: CGPoint(x: triX - triSize * 0.6, y: screenY + triSize * 0.3))
                            triPath.addLine(to: CGPoint(x: triX + triSize * 0.6, y: screenY + triSize * 0.3))
                        } else {
                            triPath.move(to: CGPoint(x: triX, y: screenY + triSize))
                            triPath.addLine(to: CGPoint(x: triX - triSize * 0.6, y: screenY - triSize * 0.3))
                            triPath.addLine(to: CGPoint(x: triX + triSize * 0.6, y: screenY - triSize * 0.3))
                        }
                        triPath.closeSubpath()
                        context.fill(triPath, with: .color(VGA.fieldLine.opacity(0.90)))
                    }
                }
            }
        }

        // Hash marks — every yard, short horizontal dashes parallel to yard lines (FPS '93 style)
        for yard in max(1, minYard)..<min(100, maxYard) {
            if yard % 5 == 0 { continue }
            let depth = proj.yardToDepth(yard, isFieldFlipped: isFieldFlipped)
            if depth < -0.05 || depth > 1.05 { continue }

            let screenY = proj.depthToScreenY(depth)
            let halfW = proj.widthAtDepth(depth) / 2
            let scale = proj.scaleAtDepth(depth)
            let hashLen = 4 * scale  // Short horizontal dash width

            // Left hash marks — horizontal dashes parallel to yard lines
            let leftHashX = proj.fieldCenterX - halfW * 0.30
            let leftHash = Path { p in
                p.move(to: CGPoint(x: leftHashX - hashLen / 2, y: screenY))
                p.addLine(to: CGPoint(x: leftHashX + hashLen / 2, y: screenY))
            }
            context.stroke(leftHash, with: .color(VGA.fieldLine.opacity(0.55)), lineWidth: max(1.0, 1.5 * scale))

            // Right hash marks
            let rightHashX = proj.fieldCenterX + halfW * 0.30
            let rightHash = Path { p in
                p.move(to: CGPoint(x: rightHashX - hashLen / 2, y: screenY))
                p.addLine(to: CGPoint(x: rightHashX + hashLen / 2, y: screenY))
            }
            context.stroke(rightHash, with: .color(VGA.fieldLine.opacity(0.55)), lineWidth: max(1.0, 1.5 * scale))
        }

        // Sideline borders — subtle in original FPS '93 (field extends to edge)
        let slNearLeft = CGPoint(x: proj.fieldCenterX - proj.nearWidth / 2, y: proj.fieldBottom)
        let slNearRight = CGPoint(x: proj.fieldCenterX + proj.nearWidth / 2, y: proj.fieldBottom)
        let slFarLeft = CGPoint(x: proj.fieldCenterX - proj.farWidth / 2, y: proj.fieldTop)
        let slFarRight = CGPoint(x: proj.fieldCenterX + proj.farWidth / 2, y: proj.fieldTop)

        let leftSideline = Path { p in p.move(to: slNearLeft); p.addLine(to: slFarLeft) }
        context.stroke(leftSideline, with: .color(VGA.fieldLine.opacity(0.35)), lineWidth: 2)

        let rightSideline = Path { p in p.move(to: slNearRight); p.addLine(to: slFarRight) }
        context.stroke(rightSideline, with: .color(VGA.fieldLine.opacity(0.35)), lineWidth: 2)

        // End zone text
        drawEndZoneText(context: context, proj: proj, minYard: minYard, maxYard: maxYard)

        // Goalpost — yellow uprights with blue padding at base (FPS '93 style)
        let goalpostYellow = Color(red: 0.9, green: 0.85, blue: 0.1)
        let goalpostBasePad = Color(red: 0.1, green: 0.1, blue: 0.6)
        for goalYard in [0, 100] {
            let depth = proj.yardToDepth(goalYard, isFieldFlipped: isFieldFlipped)
            if depth < 0.6 || depth > 1.05 { continue } // Only draw when far enough away

            let screenY = proj.depthToScreenY(depth)
            let scale = proj.scaleAtDepth(depth)
            let postHeight = 30 * scale
            let postWidth = max(2, 3 * scale)

            // Blue padding at base
            let padH = 5 * scale
            let padW = 6 * scale
            let padRect = CGRect(x: proj.fieldCenterX - padW / 2, y: screenY - padH, width: padW, height: padH)
            context.fill(Path(padRect), with: .color(goalpostBasePad))

            // Yellow vertical post
            let postPath = Path { p in
                p.move(to: CGPoint(x: proj.fieldCenterX, y: screenY - padH))
                p.addLine(to: CGPoint(x: proj.fieldCenterX, y: screenY - postHeight))
            }
            context.stroke(postPath, with: .color(goalpostYellow), lineWidth: postWidth)

            // Yellow crossbar
            let crossWidth = 14 * scale
            let crossPath = Path { p in
                p.move(to: CGPoint(x: proj.fieldCenterX - crossWidth, y: screenY - postHeight))
                p.addLine(to: CGPoint(x: proj.fieldCenterX + crossWidth, y: screenY - postHeight))
            }
            context.stroke(crossPath, with: .color(goalpostYellow), lineWidth: max(1.5, 2 * scale))
        }

        // Line of scrimmage (cyan) and first down marker (yellow) — prominent like original
        if let game = viewModel.game {
            let losDepth = proj.yardToDepth(game.fieldPosition.yardLine, isFieldFlipped: isFieldFlipped)
            if losDepth > -0.1 && losDepth < 1.1 {
                let losY = proj.depthToScreenY(losDepth)
                let losHalfW = proj.widthAtDepth(losDepth) / 2
                let losScale = proj.scaleAtDepth(losDepth)

                let losPath = Path { p in
                    p.move(to: CGPoint(x: proj.fieldCenterX - losHalfW, y: losY))
                    p.addLine(to: CGPoint(x: proj.fieldCenterX + losHalfW, y: losY))
                }
                context.stroke(losPath, with: .color(VGA.cyan.opacity(0.7)), lineWidth: 3.0 * losScale)

                // LOS "X" marker at center of field (FPS '93 pre-snap indicator)
                let xSize = 4 * losScale
                let xPath = Path { p in
                    p.move(to: CGPoint(x: proj.fieldCenterX - xSize, y: losY - xSize))
                    p.addLine(to: CGPoint(x: proj.fieldCenterX + xSize, y: losY + xSize))
                    p.move(to: CGPoint(x: proj.fieldCenterX + xSize, y: losY - xSize))
                    p.addLine(to: CGPoint(x: proj.fieldCenterX - xSize, y: losY + xSize))
                }
                context.stroke(xPath, with: .color(VGA.cyan), lineWidth: max(1.5, 2 * losScale))
            }

            let firstDownYard = game.fieldPosition.yardLine + game.downAndDistance.yardsToGo
            if firstDownYard > 0 && firstDownYard < 100 {
                let fdDepth = proj.yardToDepth(firstDownYard, isFieldFlipped: isFieldFlipped)
                if fdDepth > -0.1 && fdDepth < 1.1 {
                    let fdY = proj.depthToScreenY(fdDepth)
                    let fdHalfW = proj.widthAtDepth(fdDepth) / 2
                    let fdScale = proj.scaleAtDepth(fdDepth)

                    let fdPath = Path { p in
                        p.move(to: CGPoint(x: proj.fieldCenterX - fdHalfW, y: fdY))
                        p.addLine(to: CGPoint(x: proj.fieldCenterX + fdHalfW, y: fdY))
                    }
                    context.stroke(fdPath, with: .color(VGA.yellow.opacity(0.75)), lineWidth: 2.5 * fdScale)
                }
            }
        }
    }

    // MARK: - End Zone Text

    private func drawEndZoneText(context: GraphicsContext, proj: PerspectiveProjection, minYard: Int, maxYard: Int) {
        guard viewModel.game != nil else { return }

        let homeName = viewModel.homeTeam?.abbreviation ?? "HOME"
        let awayName = viewModel.awayTeam?.abbreviation ?? "AWAY"

        let endZoneYards: [(Int, String)] = [
            (-3, isFieldFlipped ? awayName : homeName),
            (102, isFieldFlipped ? homeName : awayName)
        ]

        for (ezYard, teamName) in endZoneYards {
            if ezYard < minYard - 5 || ezYard > maxYard + 5 { continue }
            let depth = proj.yardToDepth(ezYard, isFieldFlipped: isFieldFlipped)
            if depth < -0.2 || depth > 1.2 { continue }

            let screenY = proj.depthToScreenY(depth)
            let scale = proj.scaleAtDepth(depth)
            let fontSize = max(16, 30 * scale)

            let text = Text(teamName.uppercased())
                .font(.system(size: fontSize, weight: .heavy, design: .monospaced))
                .foregroundColor(VGA.fieldLine.opacity(0.75))
            context.draw(context.resolve(text), at: CGPoint(x: proj.fieldCenterX, y: screenY))
        }
    }

    // MARK: - Stadium Backdrop

    /// Draw simplified stadium stands behind the field when camera is near an end zone.
    /// Only visible when the LOS is within 20 yards of either end zone.
    private func drawStadiumBackdrop(context: GraphicsContext, size: CGSize, proj: PerspectiveProjection) {
        guard let game = viewModel.game else { return }
        let yardLine = game.fieldPosition.yardLine

        // Only show backdrop when near an end zone (within 20 yards)
        let nearEndZone = yardLine < 20 || yardLine > 80
        guard nearEndZone else { return }

        // The stadium appears at the far end (top of screen, depth ~1.0)
        // Draw a simplified bleacher/stands structure
        let standsDarkGray = Color(red: 0.25, green: 0.22, blue: 0.20)
        let standsMedGray = Color(red: 0.35, green: 0.32, blue: 0.30)
        let standsHighlight = Color(red: 0.45, green: 0.42, blue: 0.40)

        // Stands fill the top portion of the screen behind the far field edge
        let standsHeight = size.height * 0.18
        let topY = proj.fieldTop
        let standsTop = topY - standsHeight

        // Width matches the far field edge
        let farHalfW = proj.farWidth / 2
        let cx = proj.fieldCenterX

        // Main stands block (dark gray rectangle)
        var standsPath = Path()
        standsPath.move(to: CGPoint(x: cx - farHalfW * 1.1, y: standsTop))
        standsPath.addLine(to: CGPoint(x: cx + farHalfW * 1.1, y: standsTop))
        standsPath.addLine(to: CGPoint(x: cx + farHalfW, y: topY))
        standsPath.addLine(to: CGPoint(x: cx - farHalfW, y: topY))
        standsPath.closeSubpath()
        context.fill(standsPath, with: .color(standsDarkGray))

        // Horizontal tiers (3-4 bleacher rows)
        let tierCount = 4
        for i in 0..<tierCount {
            let t = CGFloat(i) / CGFloat(tierCount)
            let tierY = standsTop + t * standsHeight
            let tierColor = i % 2 == 0 ? standsMedGray : standsDarkGray

            // Each tier is a thin horizontal band
            let tierHeight = standsHeight / CGFloat(tierCount)
            let leftX = cx - farHalfW * (1.1 - 0.1 * t)
            let rightX = cx + farHalfW * (1.1 - 0.1 * t)
            let nextLeftX = cx - farHalfW * (1.1 - 0.1 * (t + 1.0 / CGFloat(tierCount)))
            let nextRightX = cx + farHalfW * (1.1 - 0.1 * (t + 1.0 / CGFloat(tierCount)))

            var tierPath = Path()
            tierPath.move(to: CGPoint(x: leftX, y: tierY))
            tierPath.addLine(to: CGPoint(x: rightX, y: tierY))
            tierPath.addLine(to: CGPoint(x: nextRightX, y: tierY + tierHeight))
            tierPath.addLine(to: CGPoint(x: nextLeftX, y: tierY + tierHeight))
            tierPath.closeSubpath()
            context.fill(tierPath, with: .color(tierColor))
        }

        // Crowd dots — small scattered highlights suggesting people in the stands
        let dotColor = standsHighlight
        let dotCount = 30
        // Use a deterministic pattern (not random, to avoid flicker on redraw)
        for i in 0..<dotCount {
            let seed = Double(i)
            let tx = (seed * 0.618).truncatingRemainder(dividingBy: 1.0)  // Golden ratio scatter
            let ty = (seed * 0.381).truncatingRemainder(dividingBy: 1.0)

            let dotX = cx - farHalfW * 0.9 + tx * farHalfW * 1.8
            let dotY = standsTop + ty * standsHeight * 0.9
            let dotSize: CGFloat = 1.5

            let dotRect = CGRect(x: dotX - dotSize / 2, y: dotY - dotSize / 2, width: dotSize, height: dotSize)
            context.fill(Path(dotRect), with: .color(dotColor))
        }
    }

    // MARK: - Player Helpers

    private func makePlayer(_ players: [FPSPlayer], _ index: Int, position: CGPoint, isMoving: Bool, facing: Double, hasBall: Bool) -> FPSPlayer {
        guard index < players.count else {
            return FPSPlayer(id: UUID(), position: position, number: 0, isHome: true)
        }
        var p = players[index]
        p.position = position
        p.isMoving = isMoving
        p.facingDirection = facing
        p.hasBall = hasBall
        return p
    }

    private func makeAnimatedPlayer(_ players: [FPSPlayer], _ index: Int, position: CGPoint, isMoving: Bool, facing: Double, hasBall: Bool, pose: PlayerPose) -> FPSPlayer {
        guard index < players.count else {
            return FPSPlayer(id: UUID(), position: position, number: 0, isHome: true, pose: pose)
        }
        var p = players[index]
        p.position = position
        p.isMoving = isMoving
        p.facingDirection = facing
        p.hasBall = hasBall
        p.pose = pose
        return p
    }

    private func animatedFlatPlayers(blueprint: PlayAnimationBlueprint, progress: Double) -> (offense: [FPSPlayer], defense: [FPSPlayer]) {
        var offense: [FPSPlayer] = []
        for i in 0..<offensePlayers.count {
            var p = offensePlayers[i]
            if i < blueprint.offensivePaths.count {
                p.position = blueprint.offensivePaths[i].position(at: progress)
            }
            offense.append(p)
        }

        var defense: [FPSPlayer] = []
        for i in 0..<defensePlayers.count {
            var p = defensePlayers[i]
            if i < blueprint.defensivePaths.count {
                p.position = blueprint.defensivePaths[i].position(at: progress)
            }
            defense.append(p)
        }

        return (offense, defense)
    }

    // MARK: - Sprite Rendering Helpers

    /// Map PlayerPose to PlayerAnimState for SpriteCache lookup
    private func poseToAnimState(_ pose: PlayerPose) -> PlayerAnimState {
        switch pose {
        case .threePointStance: return .standing
        case .standing: return .standing
        case .dbReady: return .dbReady
        case .snapping: return .snapping
        case .qbUnderCenter: return .qbSnap
        case .running: return .running
        case .blocking: return .blocking
        case .catching: return .catching
        case .throwing: return .passing
        case .handingOff: return .handingOff
        case .tackling: return .tackling
        case .diving: return .diving
        case .down: return .diving
        case .gettingUp: return .gettingUp
        case .backpedaling: return .running
        case .celebrating: return .celebrating
        }
    }

    /// Map PlayerRole to position code string for SpriteCache animation lookup
    private func roleToPositionCode(_ role: PlayerRole, isDefense: Bool) -> String {
        switch role {
        case .lineman: return "OG"
        case .quarterback: return "QB"
        case .runningback, .runningBack: return "RB"
        case .receiver: return "WR"
        case .tightend: return "TE"
        case .defensiveLine: return "DE"
        case .linebacker: return "LB"
        case .defensiveBack, .cornerback: return "CB"
        case .safety: return "S"
        default:
            return isDefense ? "LB" : "WR"
        }
    }

    /// Convert a facing direction (radians from blueprint) to degrees 0-360 for view mapping.
    /// Blueprint: 0 = right/east, positive = counterclockwise.
    /// When field is flipped, the visual direction is reversed horizontally.
    private func facingToAngle(_ facing: Double, isFlipped: Bool) -> Double {
        var deg = facing * (180.0 / .pi)
        if isFlipped {
            deg = 180.0 - deg
        }
        // Normalize to 0-360
        while deg < 0 { deg += 360 }
        while deg >= 360 { deg -= 360 }
        return deg
    }

    /// Try to get an authentic sprite frame for the given player state.
    /// Returns nil if sprites aren't loaded or animation not available.
    private func authenticSpriteFrame(
        pose: PlayerPose,
        role: PlayerRole,
        isDefense: Bool,
        hasBall: Bool,
        facing: Double,
        animProgress: Double = 0.0
    ) -> SpriteFrame? {
        guard spritesLoaded else { return nil }

        let animState = poseToAnimState(pose)
        let posCode = roleToPositionCode(role, isDefense: isDefense)
        let animName = SpriteCache.animationName(for: animState, position: posCode, hasBall: hasBall)

        guard let info = SpriteCache.shared.animationInfo(named: animName) else { return nil }

        // Determine frame based on animation progress (cycle through frames)
        let frame: Int
        if info.frames > 1 {
            frame = Int(animProgress * Double(info.frames)) % info.frames
        } else {
            frame = 0
        }

        // Map facing direction to view index
        let angle = facingToAngle(facing, isFlipped: isFieldFlipped)
        let viewIdx = SpriteCache.viewIndex(fromAngle: angle, viewCount: info.views)

        // Apply team color table (same logic as animatedSpriteFrame)
        let colorTable: Int = {
            guard let game = viewModel.game else { return 0 }
            let offenseIsHome = game.isHomeTeamPossession
            let isHomePlayer = isDefense ? !offenseIsHome : offenseIsHome
            return isHomePlayer ? SpriteCache.homeColorTable : SpriteCache.awayColorTable
        }()

        return SpriteCache.shared.sprite(animation: animName, frame: frame, view: viewIdx, colorTable: colorTable)
    }

    /// Per-player animated sprite frame using independent animation state machines.
    /// Updates the player's animation state in offAnimStates/defAnimStates arrays.
    private func animatedSpriteFrame(
        pose: PlayerPose,
        role: PlayerRole,
        isDefense: Bool,
        playerIndex: Int,
        hasBall: Bool,
        facing: Double,
        phase: AnimationPhase?,
        elapsed: Double
    ) -> SpriteFrame? {
        guard spritesLoaded else { return nil }

        let animState = poseToAnimState(pose)
        let posCode = roleToPositionCode(role, isDefense: isDefense)
        let animName = SpriteCache.animationName(for: animState, position: posCode, hasBall: hasBall)

        guard let info = SpriteCache.shared.animationInfo(named: animName) else { return nil }

        // Get or create animation state for this player
        let stateArray = isDefense ? viewModel.defAnimStates : viewModel.offAnimStates
        var playerAnim: PlayerAnimationState
        if playerIndex < stateArray.count {
            playerAnim = stateArray[playerIndex]
        } else {
            playerAnim = PlayerAnimationState()
        }

        // Transition if animation changed — reset elapsed to current play time
        if playerAnim.animationName != animName {
            playerAnim.transition(
                to: animName,
                frames: info.frames,
                views: info.views,
                loops: PlayerAnimationState.isLoopingAnimation(animName)
            )
            // Record when this animation started (as play elapsed time)
            playerAnim.elapsedTime = elapsed
        }

        // Compute frame from time since this animation started
        let phaseName = phase?.name ?? .preSnap
        let frame: Int
        if phaseName == .preSnap || info.frames <= 1 {
            frame = 0
        } else {
            let animTime = elapsed - playerAnim.elapsedTime
            let rawFrame = Int(animTime * PlayerAnimationState.fps)
            if playerAnim.isLooping {
                frame = rawFrame % info.frames
            } else {
                frame = min(rawFrame, info.frames - 1)
            }
        }

        // Write back updated state
        if playerIndex < stateArray.count {
            if isDefense {
                viewModel.defAnimStates[playerIndex] = playerAnim
            } else {
                viewModel.offAnimStates[playerIndex] = playerAnim
            }
        }

        let angle = facingToAngle(facing, isFlipped: isFieldFlipped)
        let viewIdx = SpriteCache.viewIndex(fromAngle: angle, viewCount: info.views)

        let colorTable: Int = {
            guard let game = viewModel.game else { return 0 }
            let offenseIsHome = game.isHomeTeamPossession
            let isHomePlayer = isDefense ? !offenseIsHome : offenseIsHome
            return isHomePlayer ? SpriteCache.homeColorTable : SpriteCache.awayColorTable
        }()

        return SpriteCache.shared.sprite(animation: animName, frame: frame, view: viewIdx, colorTable: colorTable)
    }

    // MARK: - Field Setup

    private var isFieldFlipped: Bool {
        !viewModel.isUserPossession
    }

    private func setupFieldPositions() {
        guard let game = viewModel.game else { return }

        let yardLine = game.fieldPosition.yardLine
        let lineOfScrimmage = yardToFlatX(yardLine)

        ballPosition = CGPoint(x: lineOfScrimmage, y: flatPlayCenter)

        let isHomeOnOffense = game.isHomeTeamPossession

        // ALWAYS use unflipped coordinates (matching PlayBlueprintGenerator).
        // Offense faces right (positive X), defense at higher X facing left.
        // PerspectiveProjection handles visual flipping via isFieldFlipped.
        offensePlayers = createOffensiveFormation(los: lineOfScrimmage, isHome: isHomeOnOffense, facingRight: true)
        defensePlayers = createDefensiveFormation(los: lineOfScrimmage, isHome: !isHomeOnOffense, facingRight: false)
    }

    /// Convert yard line to flat X coordinate (640-wide blueprint space)
    /// ALWAYS uses unflipped coordinates (same as PlayBlueprintGenerator).
    /// PerspectiveProjection handles visual flipping via isFieldFlipped.
    private func yardToFlatX(_ yard: Int) -> CGFloat {
        let endZone: CGFloat = 32
        let playField: CGFloat = 576
        return endZone + (CGFloat(yard) / 100.0) * playField
    }

    // MARK: - Formation Setup

    private func createOffensiveFormation(los: CGFloat, isHome: Bool, facingRight: Bool = true) -> [FPSPlayer] {
        let centerY = flatPlayCenter
        let formation = viewModel.currentOffensiveFormation ?? .shotgun
        let positions = FormationPositions.offensivePositions(for: formation, losX: los, centerY: centerY)
        let roles = FormationPositions.offensiveRoles(for: formation)

        let defaultNumbers = [50, 51, 52, 53, 54, 12, 24, 80, 88, 85, 81]

        var players: [FPSPlayer] = []
        for i in 0..<11 {
            players.append(FPSPlayer(
                id: UUID(),
                position: positions[i],
                number: defaultNumbers[i],
                isHome: isHome,
                role: roles[i]
            ))
        }
        return players
    }

    private func createDefensiveFormation(los: CGFloat, isHome: Bool, facingRight: Bool = false) -> [FPSPlayer] {
        let centerY = flatPlayCenter
        let formation = viewModel.currentDefensiveFormation ?? .base43
        let positions = FormationPositions.defensivePositions(for: formation, losX: los, centerY: centerY)
        let roles = FormationPositions.defensiveRoles(for: formation)

        let defaultNumbers = [90, 91, 92, 93, 50, 51, 52, 21, 29, 31, 39]

        var players: [FPSPlayer] = []
        for i in 0..<11 {
            players.append(FPSPlayer(
                id: UUID(),
                position: positions[i],
                number: defaultNumbers[i],
                isHome: isHome,
                role: roles[i]
            ))
        }
        return players
    }
}

// MARK: - Field Player Model

// MARK: - Player Pose

/// Visual pose state for sprite rendering — determines which body shape to draw.
public enum PlayerPose {
    case threePointStance   // Pre-snap linemen: crouched, one hand down (LMT3PT)
    case standing           // Pre-snap WR/TE/RB standing upright (LMSTAND)
    case dbReady            // Pre-snap DB/LB ready crouch (DBREADY)
    case snapping           // Center snapping the ball (CTSNP)
    case qbUnderCenter      // QB receiving snap (QBSNP)
    case running            // Upright with legs in stride (SKRUN/LMRUN/QBRUN)
    case blocking           // Leaned forward, arms out, engaging defender (LMPUSH/L2LOCK)
    case catching           // Arms extended upward to catch ball (FCATCH)
    case throwing           // QB with arm back/releasing (QBBULIT)
    case handingOff         // QB handing off to RB (QBHAND)
    case tackling           // Reaching/diving toward ball carrier (SLTKSDL/LMCHK)
    case diving             // Diving for ball/tackle (SKDIVE/LMDIVE)
    case down               // On the ground after tackle
    case gettingUp          // Getting up after being down (LMGETUPF/SKSTUP)
    case backpedaling       // Defensive backs dropping into coverage (SKRUN)
    case celebrating        // End zone celebration (EZSPIKE etc.)
}

public struct FPSPlayer: Identifiable {
    public let id: UUID
    var position: CGPoint
    let number: Int
    let isHome: Bool
    var role: PlayerRole = .lineman
    var facingDirection: Double = 0
    var isMoving: Bool = false
    var hasBall: Bool = false
    var pose: PlayerPose = .standing
}

// MARK: - Authentic Player Sprite (FPS '93 Original ANIM.DAT sprites)
//
// Renders authentic sprites decoded from ANIM.DAT when available.
// Falls back to RetroPlayerSprite geometric shapes if sprites aren't loaded.

struct AuthenticPlayerSprite: View {
    let player: FPSPlayer
    let isDefense: Bool
    let spriteFrame: SpriteFrame?
    let baseScale: CGFloat

    var body: some View {
        if let frame = spriteFrame {
            // Authentic sprite rendering
            ZStack {
                Image(decorative: frame.image, scale: 1.0)
                    .interpolation(.none)  // Crisp pixel art, no blurring
                    .scaleEffect(baseScale)

                // Ball carrier green number box overlay (FPS '93 signature feature!)
                if player.hasBall {
                    let boxYOffset: CGFloat = player.pose == .down ? -4 : -CGFloat(frame.height) * baseScale / 2 - 10
                    BallCarrierNumberBox(number: player.number)
                        .offset(y: boxYOffset)
                }
            }
            .frame(
                width: CGFloat(frame.width) * baseScale,
                height: CGFloat(frame.height) * baseScale
            )
            .offset(
                x: CGFloat(frame.xOffset) * baseScale,
                y: CGFloat(frame.yOffset) * baseScale
            )
            .position(player.position)
        } else {
            // Fallback to geometric shapes
            RetroPlayerSprite(player: player, isDefense: isDefense)
        }
    }
}

// MARK: - Ball Carrier Number Box (FPS '93 — bright green with alternating border)

struct BallCarrierNumberBox: View {
    let number: Int
    @State private var borderPhase = false

    // Bright green matching original (#00CC00)
    private let boxGreen = Color(red: 0.0, green: 0.80, blue: 0.0)
    private let boxBorderDark = Color(red: 0.0, green: 0.55, blue: 0.0)

    var body: some View {
        Text("\(number)")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(boxGreen)
            .overlay(
                Rectangle()
                    .stroke(borderPhase ? Color.blue : Color.orange, lineWidth: 1.5)
            )
            .onAppear {
                // Alternate border color every 0.3s
                Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                    borderPhase.toggle()
                }
            }
    }
}

// MARK: - Retro Player Sprite (FPS '93 chunky pre-rendered 3D style)
//
// Original game at 320x200 has chunky colored-block sprites.
// Base frame is 40x52. Sprites are simple: helmet oval + jersey block + pants block.
// No facemask detail, no separate fingers, no cleats — just solid colored shapes.

struct RetroPlayerSprite: View {
    let player: FPSPlayer
    let isDefense: Bool

    // Team colors matching original FPS '93:
    // Home = blue jerseys + red pants, Away = white jerseys + gray pants
    private var jerseyColor: Color {
        player.isHome
            ? Color(red: 0.15, green: 0.15, blue: 0.65)
            : Color.white
    }

    private var helmetColor: Color {
        player.isHome
            ? Color(red: 0.12, green: 0.12, blue: 0.55)
            : Color(red: 0.85, green: 0.85, blue: 0.85)
    }

    private var pantsColor: Color {
        player.isHome
            ? Color(red: 0.55, green: 0.10, blue: 0.10)
            : Color(red: 0.80, green: 0.80, blue: 0.80)
    }

    private var numberColor: Color {
        player.isHome ? .white : Color(red: 0.15, green: 0.15, blue: 0.65)
    }

    // Linemen are wider/stockier than skill players
    private var bodyWidth: CGFloat {
        switch player.role {
        case .lineman, .defensiveLine: return 22
        case .linebacker, .tightend: return 19
        default: return 16
        }
    }

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2

            switch player.pose {
            case .threePointStance:
                drawThreePointStance(context: context, cx: cx, cy: cy)
            case .standing, .qbUnderCenter:
                drawStanding(context: context, cx: cx, cy: cy)
            case .dbReady:
                drawThreePointStance(context: context, cx: cx, cy: cy)
            case .snapping:
                drawBlocking(context: context, cx: cx, cy: cy)
            case .running, .backpedaling:
                drawRunning(context: context, cx: cx, cy: cy)
            case .blocking:
                drawBlocking(context: context, cx: cx, cy: cy)
            case .catching:
                drawCatching(context: context, cx: cx, cy: cy)
            case .throwing, .handingOff:
                drawThrowing(context: context, cx: cx, cy: cy)
            case .tackling:
                drawTackling(context: context, cx: cx, cy: cy)
            case .diving:
                drawTackling(context: context, cx: cx, cy: cy)
            case .down:
                drawDown(context: context, cx: cx, cy: cy)
            case .gettingUp:
                drawStanding(context: context, cx: cx, cy: cy)
            case .celebrating:
                drawStanding(context: context, cx: cx, cy: cy)
            }

            // Ball carrier green number box is rendered as SwiftUI overlay (BallCarrierNumberBox)
            // Canvas can't host SwiftUI Timer-driven views, so the green box for RetroPlayerSprite
            // is drawn statically here as a fallback
            if player.hasBall {
                let boxY: CGFloat = player.pose == .down ? cy - 14 : cy - 30
                let numBoxW: CGFloat = 22
                let numBoxH: CGFloat = 13
                let numBoxRect = CGRect(x: cx - numBoxW / 2, y: boxY, width: numBoxW, height: numBoxH)
                context.fill(Path(numBoxRect), with: .color(Color(red: 0.0, green: 0.80, blue: 0.0)))
                context.stroke(Path(numBoxRect), with: .color(Color.orange), lineWidth: 1.5)

                let ballNumText = Text("\(player.number)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                context.draw(context.resolve(ballNumText), at: CGPoint(x: cx, y: boxY + numBoxH / 2))
            }
        }
        .frame(width: 40, height: 52)
        .position(player.position)
    }

    // MARK: - Pose: Three-Point Stance (pre-snap linemen)
    // Compact crouched blob — low and wide

    private func drawThreePointStance(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let bw = bodyWidth

        // Shadow (prominent)
        drawShadow(context: context, cx: cx, cy: cy + 10, width: bw + 10)

        // Helmet (low)
        let helmetRect = CGRect(x: cx - 7, y: cy - 6, width: 14, height: 10)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1)

        // Jersey block (short, wide — crouched)
        let jerseyRect = CGRect(x: cx - bw / 2, y: cy + 3, width: bw, height: 10)
        context.fill(Path(jerseyRect), with: .color(jerseyColor))
        context.stroke(Path(jerseyRect), with: .color(.black), lineWidth: 1)

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: cy + 8))

        // Pants block (wide base)
        let pantsRect = CGRect(x: cx - bw / 2 - 2, y: cy + 13, width: bw + 4, height: 7)
        context.fill(Path(pantsRect), with: .color(pantsColor))
    }

    // MARK: - Pose: Standing (pre-snap QB, receivers, DBs)

    private func drawStanding(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let bw = bodyWidth

        drawShadow(context: context, cx: cx, cy: cy + 16, width: bw + 6)

        // Helmet
        let helmetRect = CGRect(x: cx - 7, y: cy - 18, width: 14, height: 11)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1)

        // Jersey block
        let jerseyRect = CGRect(x: cx - bw / 2, y: cy - 6, width: bw, height: 12)
        context.fill(Path(jerseyRect), with: .color(jerseyColor))
        context.stroke(Path(jerseyRect), with: .color(.black), lineWidth: 1)

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: cy))

        // Pants block
        let pantsRect = CGRect(x: cx - bw / 2 + 1, y: cy + 6, width: bw - 2, height: 10)
        context.fill(Path(pantsRect), with: .color(pantsColor))
    }

    // MARK: - Pose: Running (ball carrier, routes, pursuit)

    private func drawRunning(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let bw = bodyWidth

        drawShadow(context: context, cx: cx, cy: cy + 16, width: bw + 6)

        // Helmet (slight forward lean)
        let helmetRect = CGRect(x: cx - 7, y: cy - 17, width: 14, height: 11)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1)

        // Jersey block
        let jerseyRect = CGRect(x: cx - bw / 2, y: cy - 5, width: bw, height: 11)
        context.fill(Path(jerseyRect), with: .color(jerseyColor))
        context.stroke(Path(jerseyRect), with: .color(.black), lineWidth: 1)

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: cy + 1))

        // Legs in stride — two blocks with gap
        let legW: CGFloat = 6
        let legH: CGFloat = 9
        let leftLeg = CGRect(x: cx - legW - 2, y: cy + 6, width: legW, height: legH)
        let rightLeg = CGRect(x: cx + 2, y: cy + 9, width: legW, height: legH)
        context.fill(Path(leftLeg), with: .color(pantsColor))
        context.fill(Path(rightLeg), with: .color(pantsColor))
    }

    // MARK: - Pose: Blocking (OL engaging, leaned forward)

    private func drawBlocking(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let bw = bodyWidth + 2

        drawShadow(context: context, cx: cx, cy: cy + 12, width: bw + 8)

        // Helmet (down, forward)
        let helmetRect = CGRect(x: cx - 7, y: cy - 9, width: 14, height: 10)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1)

        // Jersey block (wide, low — engaging)
        let jerseyRect = CGRect(x: cx - bw / 2, y: cy + 1, width: bw, height: 10)
        context.fill(Path(jerseyRect), with: .color(jerseyColor))
        context.stroke(Path(jerseyRect), with: .color(.black), lineWidth: 1)

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: cy + 6))

        // Pants block (wide base)
        let pantsRect = CGRect(x: cx - bw / 2 - 1, y: cy + 11, width: bw + 2, height: 7)
        context.fill(Path(pantsRect), with: .color(pantsColor))
    }

    // MARK: - Pose: Catching (arms up, reaching for ball)

    private func drawCatching(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let bw = bodyWidth

        drawShadow(context: context, cx: cx, cy: cy + 16, width: bw + 6)

        // Helmet (looking up)
        let helmetRect = CGRect(x: cx - 7, y: cy - 19, width: 14, height: 11)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1)

        // Arms up — two small blocks above shoulders
        let armW: CGFloat = 4
        let armH: CGFloat = 10
        let leftArm = CGRect(x: cx - 8, y: cy - 24, width: armW, height: armH)
        let rightArm = CGRect(x: cx + 4, y: cy - 24, width: armW, height: armH)
        context.fill(Path(leftArm), with: .color(jerseyColor))
        context.fill(Path(rightArm), with: .color(jerseyColor))

        // Jersey block
        let jerseyRect = CGRect(x: cx - bw / 2, y: cy - 7, width: bw, height: 12)
        context.fill(Path(jerseyRect), with: .color(jerseyColor))
        context.stroke(Path(jerseyRect), with: .color(.black), lineWidth: 1)

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: cy - 1))

        // Pants block
        let pantsRect = CGRect(x: cx - bw / 2 + 1, y: cy + 5, width: bw - 2, height: 10)
        context.fill(Path(pantsRect), with: .color(pantsColor))
    }

    // MARK: - Pose: Throwing (QB arm cocked back)

    private func drawThrowing(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let bw: CGFloat = 16

        drawShadow(context: context, cx: cx, cy: cy + 16, width: bw + 6)

        // Helmet
        let helmetRect = CGRect(x: cx - 7, y: cy - 18, width: 14, height: 11)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1)

        // Throwing arm (raised block behind)
        let throwArm = CGRect(x: cx + bw / 2, y: cy - 14, width: 4, height: 10)
        context.fill(Path(throwArm), with: .color(jerseyColor))

        // Jersey block
        let jerseyRect = CGRect(x: cx - bw / 2, y: cy - 6, width: bw, height: 12)
        context.fill(Path(jerseyRect), with: .color(jerseyColor))
        context.stroke(Path(jerseyRect), with: .color(.black), lineWidth: 1)

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: cy))

        // Pants block
        let pantsRect = CGRect(x: cx - bw / 2 + 1, y: cy + 6, width: bw - 2, height: 10)
        context.fill(Path(pantsRect), with: .color(pantsColor))
    }

    // MARK: - Pose: Tackling (diving/reaching toward ball carrier)

    private func drawTackling(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let bw = bodyWidth

        drawShadow(context: context, cx: cx, cy: cy + 12, width: bw + 8)

        // Helmet (low, forward)
        let helmetRect = CGRect(x: cx - 7, y: cy - 10, width: 14, height: 10)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1)

        // Jersey block (leaning forward)
        let jerseyRect = CGRect(x: cx - bw / 2, y: cy, width: bw, height: 10)
        context.fill(Path(jerseyRect), with: .color(jerseyColor))
        context.stroke(Path(jerseyRect), with: .color(.black), lineWidth: 1)

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: cy + 5))

        // Legs trailing
        let pantsRect = CGRect(x: cx - bw / 2 + 2, y: cy + 10, width: bw - 4, height: 8)
        context.fill(Path(pantsRect), with: .color(pantsColor))
    }

    // MARK: - Pose: Down (on the ground after tackle)

    private func drawDown(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let bw = bodyWidth

        // Horizontal shadow
        drawShadow(context: context, cx: cx, cy: cy + 5, width: bw + 12)

        // Helmet (side)
        let helmetRect = CGRect(x: cx - 16, y: cy - 5, width: 11, height: 9)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1)

        // Body (horizontal jersey block)
        let bodyRect = CGRect(x: cx - 7, y: cy - 4, width: 14, height: 8)
        context.fill(Path(bodyRect), with: .color(jerseyColor))

        // Legs (horizontal pants block)
        let legsRect = CGRect(x: cx + 7, y: cy - 3, width: 12, height: 6)
        context.fill(Path(legsRect), with: .color(pantsColor))
    }

    // MARK: - Pose: Backpedaling (DBs dropping into coverage)

    private func drawBackpedaling(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let bw = bodyWidth

        drawShadow(context: context, cx: cx, cy: cy + 16, width: bw + 6)

        // Helmet
        let helmetRect = CGRect(x: cx - 7, y: cy - 17, width: 14, height: 11)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1)

        // Jersey block
        let jerseyRect = CGRect(x: cx - bw / 2, y: cy - 5, width: bw, height: 11)
        context.fill(Path(jerseyRect), with: .color(jerseyColor))
        context.stroke(Path(jerseyRect), with: .color(.black), lineWidth: 1)

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: cy + 1))

        // Legs crossing (backpedal)
        let legW: CGFloat = 6
        let legH: CGFloat = 9
        let leftLeg = CGRect(x: cx - legW, y: cy + 8, width: legW, height: legH)
        let rightLeg = CGRect(x: cx, y: cy + 6, width: legW, height: legH)
        context.fill(Path(leftLeg), with: .color(pantsColor))
        context.fill(Path(rightLeg), with: .color(pantsColor))
    }

    // MARK: - Shadow Helper (disabled — original FPS '93 has no sprite shadows)

    private func drawShadow(context: GraphicsContext, cx: CGFloat, cy: CGFloat, width: CGFloat) {
        // No-op: original FPS '93 does not render player shadows
    }
}

// MARK: - Football Sprite

struct FootballSprite: View {
    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2

            let ballRect = CGRect(x: cx - 6, y: cy - 3.5, width: 12, height: 7)
            context.fill(Ellipse().path(in: ballRect), with: .color(Color(red: 0.55, green: 0.27, blue: 0.07)))
            context.stroke(Ellipse().path(in: ballRect), with: .color(.black), lineWidth: 1)

            let lacePath = Path { p in
                p.move(to: CGPoint(x: cx - 2.5, y: cy - 1))
                p.addLine(to: CGPoint(x: cx + 2.5, y: cy - 1))
            }
            context.stroke(lacePath, with: .color(.white), lineWidth: 1)
        }
        .frame(width: 16, height: 12)
    }
}

// MARK: - Player Control Indicator (ball carrier silhouette during play animation)

struct PlayerControlIndicator: View {
    let jerseyNumber: Int

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    // Simple human silhouette in amber
                    Canvas { context, size in
                        let cx = size.width / 2
                        // Head
                        let headRect = CGRect(x: cx - 4, y: 1, width: 8, height: 8)
                        context.fill(Ellipse().path(in: headRect), with: .color(VGA.digitalAmber))
                        // Body
                        let bodyRect = CGRect(x: cx - 5, y: 10, width: 10, height: 12)
                        context.fill(Path(bodyRect), with: .color(VGA.digitalAmber))
                        // Left leg
                        let leftLeg = CGRect(x: cx - 5, y: 22, width: 4, height: 8)
                        context.fill(Path(leftLeg), with: .color(VGA.digitalAmber))
                        // Right leg
                        let rightLeg = CGRect(x: cx + 1, y: 22, width: 4, height: 8)
                        context.fill(Path(rightLeg), with: .color(VGA.digitalAmber))
                    }
                    .frame(width: 20, height: 30)

                    Text("\(jerseyNumber)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(VGA.digitalAmber)
                }
                .padding(6)
                .background(Color.black.opacity(0.5))
                .padding(.trailing, 8)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FPSFieldView(viewModel: GameViewModel())
        .frame(width: 700, height: 500)
        .background(Color.black)
}
