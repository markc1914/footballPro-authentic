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

// MARK: - Perspective Projection Engine

/// Projects flat field coordinates (640x360 "top-down" space) into
/// perspective screen coordinates for the full-screen field view.
///
/// Matches FPS Football Pro '93: shows ~15 yards of field centered on the LOS.
/// Camera "follows" the ball. Very mild trapezoid perspective — wide at bottom,
/// slightly narrower at top. Players near camera are larger.
/// Original game runs at 320x200 with players ~35-40px tall (20% of screen height).
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

    // Visible yard window — zoomed in to match original (only ~15 yards visible)
    let visibleYardsBehind: CGFloat = 5    // yards behind LOS shown
    let visibleYardsAhead: CGFloat = 10    // yards ahead of LOS shown
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

        // Very subtle perspective like original: near barely wider, far ~93% (almost flat)
        self.nearWidth = screenWidth * 1.01
        self.farWidth = screenWidth * 0.93
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
        self.nearWidth = screenWidth * 1.01
        self.farWidth = screenWidth * 0.93
    }

    func depthToScreenY(_ depth: CGFloat) -> CGFloat {
        let clamped = min(max(depth, 0), 1)
        // Mild non-linear compression for depth perception
        let t = pow(clamped, 0.88)
        return fieldBottom + (fieldTop - fieldBottom) * t
    }

    func widthAtDepth(_ depth: CGFloat) -> CGFloat {
        let clamped = min(max(depth, 0), 1)
        let t = pow(clamped, 0.88)
        return nearWidth + (farWidth - nearWidth) * t
    }

    func scaleAtDepth(_ depth: CGFloat) -> CGFloat {
        let w = widthAtDepth(depth)
        return max(w / nearWidth, 0.60)
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
    @State private var cameraFocusX: CGFloat = 320  // Smoothed camera focus in flat space

    // Internal flat field dimensions (blueprint coordinate space)
    private let flatFieldWidth: CGFloat = 640
    private let flatFieldHeight: CGFloat = 360
    private let flatPlayCenter: CGFloat = 180  // Y center of the 360-high field

    /// Camera smoothing factor — lower = smoother/slower follow (0.05 = very smooth, 0.2 = snappy)
    private let cameraSmoothing: CGFloat = 0.08

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isAnimatingPlay, let blueprint = currentBlueprint, let startTime = animationStartTime {
                    // === ANIMATED RENDERING ===
                    // Projection is computed per-frame inside TimelineView so camera can track the ball.
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
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
                        let smoothedFocusX = cameraFocusX + (targetFocusX - cameraFocusX) * cameraSmoothing

                        // Per-frame projection centered on ball carrier
                        let animProj = PerspectiveProjection(
                            screenWidth: geo.size.width,
                            screenHeight: geo.size.height,
                            focusFlatX: smoothedFocusX
                        )

                        // Determine current phase and ball carrier
                        let currentPhase = blueprint.currentPhase(at: progress)
                        let carrier = blueprint.ballPath.ballCarrier(at: progress)

                        ZStack {
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
                                let facing = path?.facingDirection(at: progress) ?? 0
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

                                RetroPlayerSprite(
                                    player: makeAnimatedPlayer(
                                        players, i,
                                        position: screenPos,
                                        isMoving: moving,
                                        facing: facing,
                                        hasBall: playerHasBall,
                                        pose: pose
                                    ),
                                    isDefense: isDefense
                                )
                                .scaleEffect(scale)
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
                        }
                        .onChange(of: progress >= 1.0) { _, finished in
                            if finished { endAnimation() }
                        }
                        .onChange(of: smoothedFocusX) { _, newX in
                            cameraFocusX = newX
                        }
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

                        // Pre-snap poses: linemen in 3-point stance, others standing
                        let preSnapPose: PlayerPose = {
                            switch entry.player.role {
                            case .lineman, .defensiveLine: return .threePointStance
                            default: return .standing
                            }
                        }()

                        RetroPlayerSprite(
                            player: makeAnimatedPlayer(
                                entry.isDefense ? defensePlayers : offensePlayers,
                                entry.arrayIndex,
                                position: screenPos, isMoving: false, facing: 0,
                                hasBall: false, pose: preSnapPose
                            ),
                            isDefense: entry.isDefense
                        )
                        .scaleEffect(scale)
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
                FPSDigitalClock(time: "25", fontSize: 16)
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
            // Everyone in pre-snap stance
            switch role {
            case .lineman, .defensiveLine:
                return .threePointStance
            default:
                return .standing
            }

        case .snap:
            // Linemen engage, QB receives snap
            switch role {
            case .lineman:
                return .blocking
            case .defensiveLine:
                return isMoving ? .running : .threePointStance
            case .quarterback:
                return .standing
            default:
                return .standing
            }

        case .routesDevelop:
            // Routes developing — everyone in motion
            if hasBall {
                return .running
            }
            switch role {
            case .lineman:
                return .blocking
            case .defensiveLine:
                return .running
            case .quarterback:
                return .throwing
            case .runningback, .runningBack:
                return isMoving ? .running : .standing
            case .receiver, .tightend:
                return isMoving ? .running : .standing
            case .linebacker:
                return isMoving ? .running : .backpedaling
            case .defensiveBack, .cornerback, .safety:
                return isMoving ? .backpedaling : .standing
            default:
                return isMoving ? .running : .standing
            }

        case .resolution:
            // Ball thrown/caught/handed off
            if hasBall {
                return .running
            }
            switch role {
            case .lineman:
                return .blocking
            case .defensiveLine:
                return .running
            case .quarterback:
                return .throwing
            case .receiver, .tightend:
                return isMoving ? .running : .catching
            case .linebacker, .defensiveBack, .cornerback, .safety:
                return isMoving ? .running : .standing
            default:
                return isMoving ? .running : .standing
            }

        case .yac:
            // Yards after catch — ball carrier running, defenders pursuing
            if hasBall {
                return .running
            }
            if isDefense && isMoving {
                return .tackling
            }
            switch role {
            case .lineman:
                return .standing
            default:
                return isMoving ? .running : .standing
            }

        case .tackle:
            // Play ending — ball carrier goes down, nearby defenders tackle
            if hasBall {
                return .down
            }
            if isDefense && isMoving {
                return .tackling
            }
            return .standing
        }
    }

    // MARK: - Animation Control

    private func startAnimation(blueprint: PlayAnimationBlueprint) {
        currentBlueprint = blueprint
        isAnimatingPlay = true
        animationStartTime = Date()

        // Initialize camera focus on the LOS
        if let game = viewModel.game {
            cameraFocusX = yardToFlatX(game.fieldPosition.yardLine)
        }
    }

    private func endAnimation() {
        isAnimatingPlay = false
        currentBlueprint = nil
        animationStartTime = nil
        viewModel.currentAnimationBlueprint = nil
        setupFieldPositions()
    }

    // MARK: - Field Drawing (Canvas)

    private func drawField(context: GraphicsContext, size: CGSize, proj: PerspectiveProjection) {
        let w = size.width
        let h = size.height

        // Solid green background — fills entire screen (matches original FPS '93)
        let fieldGreen = Color(red: 0.14, green: 0.50, blue: 0.14)  // Medium-dark green like original
        context.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(fieldGreen))

        let (minYard, maxYard) = proj.visibleYardRange(isFieldFlipped: isFieldFlipped)

        // End zone fill (if visible)
        for yard in minYard..<maxYard {
            if yard >= 0 && yard < 100 { continue }

            let color: Color
            if yard < 0 {
                color = isFieldFlipped ? VGA.endZoneBlue : VGA.endZoneRed
            } else {
                color = isFieldFlipped ? VGA.endZoneRed : VGA.endZoneBlue
            }

            let depthNear = proj.yardToDepth(yard, isFieldFlipped: isFieldFlipped)
            let depthFar = proj.yardToDepth(yard + 1, isFieldFlipped: isFieldFlipped)
            let dNear = min(depthNear, depthFar)
            let dFar = max(depthNear, depthFar)
            if dFar < -0.1 || dNear > 1.1 { continue }

            let (tl, tr, br, bl) = proj.trapezoid(depthNear: dNear, depthFar: dFar)
            var path = Path()
            path.move(to: tl)
            path.addLine(to: tr)
            path.addLine(to: br)
            path.addLine(to: bl)
            path.closeSubpath()
            context.fill(path, with: .color(color))
        }

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

            // Yard numbers — large and prominent like original
            if isTenYardLine && yard > 0 && yard < 100 {
                let displayNum = yard <= 50 ? yard : (100 - yard)
                let fontSize = max(18, 32 * scale)
                let numText = Text("\(displayNum)")
                    .font(.system(size: fontSize, weight: .heavy, design: .monospaced))
                    .foregroundColor(VGA.fieldLine.opacity(0.75))

                let leftNumX = proj.fieldCenterX - halfW * 0.80
                context.draw(context.resolve(numText), at: CGPoint(x: leftNumX, y: screenY))

                let rightNumX = proj.fieldCenterX + halfW * 0.80
                context.draw(context.resolve(numText), at: CGPoint(x: rightNumX, y: screenY))
            }
        }

        // Hash marks — every yard, prominent like original
        for yard in max(1, minYard)..<min(100, maxYard) {
            if yard % 5 == 0 { continue }
            let depth = proj.yardToDepth(yard, isFieldFlipped: isFieldFlipped)
            if depth < -0.05 || depth > 1.05 { continue }

            let screenY = proj.depthToScreenY(depth)
            let halfW = proj.widthAtDepth(depth) / 2
            let scale = proj.scaleAtDepth(depth)
            let hashLen = 10 * scale

            // Left hash marks (wider tick marks like original)
            let leftHashX = proj.fieldCenterX - halfW * 0.30
            let leftHash = Path { p in
                p.move(to: CGPoint(x: leftHashX, y: screenY - hashLen / 2))
                p.addLine(to: CGPoint(x: leftHashX, y: screenY + hashLen / 2))
            }
            context.stroke(leftHash, with: .color(VGA.fieldLine.opacity(0.55)), lineWidth: max(1.0, 1.5 * scale))

            // Right hash marks
            let rightHashX = proj.fieldCenterX + halfW * 0.30
            let rightHash = Path { p in
                p.move(to: CGPoint(x: rightHashX, y: screenY - hashLen / 2))
                p.addLine(to: CGPoint(x: rightHashX, y: screenY + hashLen / 2))
            }
            context.stroke(rightHash, with: .color(VGA.fieldLine.opacity(0.55)), lineWidth: max(1.0, 1.5 * scale))
        }

        // Sideline border — subtle since original barely shows them
        let nearLeft = CGPoint(x: proj.fieldCenterX - proj.nearWidth / 2, y: proj.fieldBottom)
        let nearRight = CGPoint(x: proj.fieldCenterX + proj.nearWidth / 2, y: proj.fieldBottom)
        let farLeft = CGPoint(x: proj.fieldCenterX - proj.farWidth / 2, y: proj.fieldTop)
        let farRight = CGPoint(x: proj.fieldCenterX + proj.farWidth / 2, y: proj.fieldTop)

        let leftSideline = Path { p in p.move(to: nearLeft); p.addLine(to: farLeft) }
        context.stroke(leftSideline, with: .color(VGA.fieldLine.opacity(0.45)), lineWidth: 2)

        let rightSideline = Path { p in p.move(to: nearRight); p.addLine(to: farRight) }
        context.stroke(rightSideline, with: .color(VGA.fieldLine.opacity(0.45)), lineWidth: 2)

        // End zone text
        drawEndZoneText(context: context, proj: proj, minYard: minYard, maxYard: maxYard)

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
        var players: [FPSPlayer] = []
        let centerY = flatPlayCenter
        let dir: CGFloat = facingRight ? 1.0 : -1.0

        // Offensive line (5)
        for i in 0..<5 {
            let yOffset = CGFloat(i - 2) * 22
            players.append(FPSPlayer(
                id: UUID(),
                position: CGPoint(x: los, y: centerY + yOffset),
                number: 50 + i, isHome: isHome, role: .lineman
            ))
        }

        // QB
        players.append(FPSPlayer(
            id: UUID(),
            position: CGPoint(x: los - 28 * dir, y: centerY),
            number: 12, isHome: isHome, role: .quarterback
        ))

        // RB
        players.append(FPSPlayer(
            id: UUID(),
            position: CGPoint(x: los - 35 * dir, y: centerY + 15),
            number: 24, isHome: isHome, role: .runningback
        ))

        // WR (wide left)
        players.append(FPSPlayer(
            id: UUID(),
            position: CGPoint(x: los + 2 * dir, y: centerY - 105),
            number: 80, isHome: isHome, role: .receiver
        ))

        // WR (wide right)
        players.append(FPSPlayer(
            id: UUID(),
            position: CGPoint(x: los + 2 * dir, y: centerY + 105),
            number: 88, isHome: isHome, role: .receiver
        ))

        // TE
        players.append(FPSPlayer(
            id: UUID(),
            position: CGPoint(x: los, y: centerY + 52),
            number: 85, isHome: isHome, role: .tightend
        ))

        // Slot
        players.append(FPSPlayer(
            id: UUID(),
            position: CGPoint(x: los + 5 * dir, y: centerY - 65),
            number: 81, isHome: isHome, role: .receiver
        ))

        return players
    }

    private func createDefensiveFormation(los: CGFloat, isHome: Bool, facingRight: Bool = false) -> [FPSPlayer] {
        var players: [FPSPlayer] = []
        let centerY = flatPlayCenter
        let dir: CGFloat = facingRight ? -1.0 : 1.0

        // DL (4)
        for i in 0..<4 {
            let yOffset = (CGFloat(i) - 1.5) * 26
            players.append(FPSPlayer(
                id: UUID(),
                position: CGPoint(x: los + 12 * dir, y: centerY + yOffset),
                number: 90 + i, isHome: isHome, role: .defensiveLine
            ))
        }

        // LB (3)
        for i in 0..<3 {
            let yOffset = CGFloat(i - 1) * 42
            players.append(FPSPlayer(
                id: UUID(),
                position: CGPoint(x: los + 38 * dir, y: centerY + yOffset),
                number: 50 + i, isHome: isHome, role: .linebacker
            ))
        }

        // CB (2)
        players.append(FPSPlayer(
            id: UUID(),
            position: CGPoint(x: los + 55 * dir, y: centerY - 95),
            number: 21, isHome: isHome, role: .defensiveBack
        ))
        players.append(FPSPlayer(
            id: UUID(),
            position: CGPoint(x: los + 55 * dir, y: centerY + 95),
            number: 29, isHome: isHome, role: .defensiveBack
        ))

        // S (2)
        players.append(FPSPlayer(
            id: UUID(),
            position: CGPoint(x: los + 80 * dir, y: centerY - 40),
            number: 31, isHome: isHome, role: .defensiveBack
        ))
        players.append(FPSPlayer(
            id: UUID(),
            position: CGPoint(x: los + 80 * dir, y: centerY + 40),
            number: 39, isHome: isHome, role: .defensiveBack
        ))

        return players
    }
}

// MARK: - Field Player Model

// MARK: - Player Pose

/// Visual pose state for sprite rendering — determines which body shape to draw.
public enum PlayerPose {
    case threePointStance   // Pre-snap linemen: crouched, one hand down
    case standing           // Pre-snap QB, receivers, defensive backs
    case running            // Upright with legs in stride
    case blocking           // Leaned forward, arms out, engaging defender
    case catching           // Arms extended upward to catch ball
    case throwing           // QB with arm back/releasing
    case tackling           // Reaching/diving toward ball carrier
    case down               // On the ground after tackle
    case backpedaling       // Defensive backs dropping into coverage
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

// MARK: - Retro Player Sprite (FPS '93 pre-rendered 3D style)
//
// Original game at 320x200 has players ~35-40px tall (20% of screen height).
// Our sprite base frame is 56x76 with scaleEffect applied by depth.
// At near camera (scale 1.0) = 76px on ~500px screen = ~15%
// At far camera (scale 0.60) = 46px = ~9%

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

    private var skinColor: Color {
        Color(red: 0.85, green: 0.70, blue: 0.55)
    }

    // Linemen are wider/stockier than skill players
    private var shoulderWidth: CGFloat {
        switch player.role {
        case .lineman, .defensiveLine: return 28
        case .linebacker, .tightend: return 24
        default: return 20
        }
    }

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2

            switch player.pose {
            case .threePointStance:
                drawThreePointStance(context: context, cx: cx, cy: cy)
            case .standing:
                drawStanding(context: context, cx: cx, cy: cy)
            case .running:
                drawRunning(context: context, cx: cx, cy: cy)
            case .blocking:
                drawBlocking(context: context, cx: cx, cy: cy)
            case .catching:
                drawCatching(context: context, cx: cx, cy: cy)
            case .throwing:
                drawThrowing(context: context, cx: cx, cy: cy)
            case .tackling:
                drawTackling(context: context, cx: cx, cy: cy)
            case .down:
                drawDown(context: context, cx: cx, cy: cy)
            case .backpedaling:
                drawBackpedaling(context: context, cx: cx, cy: cy)
            }

            // === BALL CARRIER: GREEN NUMBER BOX (FPS '93 signature feature!) ===
            if player.hasBall {
                let boxY: CGFloat = player.pose == .down ? cy - 20 : cy - 44
                let numBoxW: CGFloat = 28
                let numBoxH: CGFloat = 16
                let numBoxRect = CGRect(x: cx - numBoxW / 2, y: boxY, width: numBoxW, height: numBoxH)
                context.fill(Path(numBoxRect), with: .color(Color(red: 0.0, green: 0.7, blue: 0.0)))
                context.stroke(Path(numBoxRect), with: .color(.black), lineWidth: 1)

                let ballNumText = Text("\(player.number)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                context.draw(context.resolve(ballNumText), at: CGPoint(x: cx, y: boxY + numBoxH / 2))
            }
        }
        .frame(width: 56, height: 76)
        .position(player.position)
    }

    // MARK: - Pose: Three-Point Stance (pre-snap linemen)
    // Crouched low, one hand on ground, wide base

    private func drawThreePointStance(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let sw = shoulderWidth

        // Ground shadow
        drawShadow(context: context, cx: cx, cy: cy + 12, width: sw + 8)

        // Helmet (lower, tilted forward)
        let helmetRect = CGRect(x: cx - 9, y: cy - 10, width: 18, height: 14)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1.5)
        drawFacemask(context: context, cx: cx, maskY: cy + 2)

        // Shoulder pads (wider, lower)
        let shoulderY = cy + 4
        let shoulderRect = CGRect(x: cx - sw / 2, y: shoulderY, width: sw, height: 7)
        context.fill(Path(shoulderRect), with: .color(jerseyColor))
        context.stroke(Path(shoulderRect), with: .color(.black), lineWidth: 1)

        // Jersey body (short, crouched)
        let bodyW = sw - 4
        let bodyRect = CGRect(x: cx - bodyW / 2, y: shoulderY + 7, width: bodyW, height: 8)
        context.fill(Path(bodyRect), with: .color(jerseyColor))

        // Number on back
        let numText = Text("\(player.number)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: shoulderY + 11))

        // Down hand (one arm reaching to ground)
        let handRect = CGRect(x: cx + 6, y: cy + 15, width: 5, height: 6)
        context.fill(Path(handRect), with: .color(skinColor))

        // Other arm tucked at side
        let armRect = CGRect(x: cx - sw / 2 - 3, y: shoulderY + 2, width: 5, height: 8)
        context.fill(Path(armRect), with: .color(jerseyColor))

        // Wide legs (crouched stance)
        let legW: CGFloat = 8
        let legH: CGFloat = 10
        let legY = shoulderY + 15
        let leftLeg = CGRect(x: cx - legW - 4, y: legY, width: legW, height: legH)
        let rightLeg = CGRect(x: cx + 4, y: legY, width: legW, height: legH)
        context.fill(Path(leftLeg), with: .color(pantsColor))
        context.fill(Path(rightLeg), with: .color(pantsColor))

        // Cleats
        let cleatH: CGFloat = 3
        context.fill(Path(CGRect(x: cx - legW - 5, y: legY + legH, width: legW + 2, height: cleatH)), with: .color(.black))
        context.fill(Path(CGRect(x: cx + 3, y: legY + legH, width: legW + 2, height: cleatH)), with: .color(.black))
    }

    // MARK: - Pose: Standing (pre-snap QB, receivers, DBs)

    private func drawStanding(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let sw = shoulderWidth

        drawShadow(context: context, cx: cx, cy: cy + 20, width: sw + 4)

        // Helmet
        let helmetRect = CGRect(x: cx - 9, y: cy - 26, width: 18, height: 16)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1.5)
        drawFacemask(context: context, cx: cx, maskY: cy - 12)

        // Shoulder pads
        let shoulderY = cy - 8
        let shoulderRect = CGRect(x: cx - sw / 2, y: shoulderY, width: sw, height: 8)
        context.fill(Path(shoulderRect), with: .color(jerseyColor))
        drawShoulderHighlight(context: context, cx: cx, sw: sw, y: shoulderY)
        context.stroke(Path(shoulderRect), with: .color(.black), lineWidth: 1)

        // Jersey body
        let bodyW = sw - 4
        let bodyH: CGFloat = 14
        let bodyY = shoulderY + 8
        let bodyRect = CGRect(x: cx - bodyW / 2, y: bodyY, width: bodyW, height: bodyH)
        context.fill(Path(bodyRect), with: .color(jerseyColor))
        context.stroke(Path(bodyRect), with: .color(.black), lineWidth: 0.5)

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: bodyY + bodyH / 2))

        // Arms at sides
        drawArmsAtSides(context: context, cx: cx, sw: sw, armY: shoulderY + 2)

        // Legs together
        let legW: CGFloat = 7
        let legH: CGFloat = 12
        let legY = bodyY + bodyH
        let leftLeg = CGRect(x: cx - legW - 1, y: legY, width: legW, height: legH)
        let rightLeg = CGRect(x: cx + 1, y: legY, width: legW, height: legH)
        context.fill(Path(leftLeg), with: .color(pantsColor))
        context.fill(Path(rightLeg), with: .color(pantsColor))
        context.stroke(Path(leftLeg), with: .color(.black), lineWidth: 0.5)
        context.stroke(Path(rightLeg), with: .color(.black), lineWidth: 0.5)

        // Cleats
        drawCleats(context: context, cx: cx, legW: legW, legY: legY + legH, leftOffset: -1, rightOffset: 1)
    }

    // MARK: - Pose: Running (ball carrier, routes, pursuit)

    private func drawRunning(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let sw = shoulderWidth

        drawShadow(context: context, cx: cx, cy: cy + 20, width: sw + 4)

        // Helmet (slightly forward lean)
        let helmetRect = CGRect(x: cx - 9, y: cy - 24, width: 18, height: 15)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1.5)
        drawFacemask(context: context, cx: cx, maskY: cy - 11)

        // Shoulder pads (slight lean)
        let shoulderY = cy - 7
        let shoulderRect = CGRect(x: cx - sw / 2, y: shoulderY, width: sw, height: 7)
        context.fill(Path(shoulderRect), with: .color(jerseyColor))
        drawShoulderHighlight(context: context, cx: cx, sw: sw, y: shoulderY)
        context.stroke(Path(shoulderRect), with: .color(.black), lineWidth: 1)

        // Jersey body
        let bodyW = sw - 4
        let bodyH: CGFloat = 12
        let bodyY = shoulderY + 7
        let bodyRect = CGRect(x: cx - bodyW / 2, y: bodyY, width: bodyW, height: bodyH)
        context.fill(Path(bodyRect), with: .color(jerseyColor))

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: bodyY + bodyH / 2))

        // Arms pumping — one forward, one back
        let armW: CGFloat = 5
        let armH: CGFloat = 10
        // Left arm forward
        let leftArm = CGRect(x: cx - sw / 2 - armW, y: shoulderY - 2, width: armW, height: armH)
        context.fill(Path(leftArm), with: .color(jerseyColor))
        context.fill(Path(CGRect(x: cx - sw / 2 - armW, y: shoulderY + armH - 2, width: armW, height: 3)), with: .color(skinColor))
        // Right arm back
        let rightArm = CGRect(x: cx + sw / 2, y: shoulderY + 4, width: armW, height: armH)
        context.fill(Path(rightArm), with: .color(jerseyColor))
        context.fill(Path(CGRect(x: cx + sw / 2, y: shoulderY + armH + 4, width: armW, height: 3)), with: .color(skinColor))

        // Legs in stride (split wide)
        let legW: CGFloat = 7
        let legH: CGFloat = 12
        let legY = bodyY + bodyH
        // Left leg forward
        let leftLeg = CGRect(x: cx - legW - 3, y: legY - 4, width: legW, height: legH)
        // Right leg back
        let rightLeg = CGRect(x: cx + 3, y: legY + 4, width: legW, height: legH)
        context.fill(Path(leftLeg), with: .color(pantsColor))
        context.fill(Path(rightLeg), with: .color(pantsColor))
        context.stroke(Path(leftLeg), with: .color(.black), lineWidth: 0.5)
        context.stroke(Path(rightLeg), with: .color(.black), lineWidth: 0.5)

        // Cleats
        context.fill(Path(CGRect(x: cx - legW - 4, y: legY + legH - 4, width: legW + 2, height: 4)), with: .color(.black))
        context.fill(Path(CGRect(x: cx + 2, y: legY + legH + 4, width: legW + 2, height: 4)), with: .color(.black))
    }

    // MARK: - Pose: Blocking (OL engaging, leaned forward)

    private func drawBlocking(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let sw = shoulderWidth + 2 // Slightly wider when blocking

        drawShadow(context: context, cx: cx, cy: cy + 14, width: sw + 6)

        // Helmet (down, forward)
        let helmetRect = CGRect(x: cx - 9, y: cy - 14, width: 18, height: 14)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1.5)
        drawFacemask(context: context, cx: cx, maskY: cy - 2)

        // Shoulder pads (low, wide)
        let shoulderY = cy
        let shoulderRect = CGRect(x: cx - sw / 2, y: shoulderY, width: sw, height: 8)
        context.fill(Path(shoulderRect), with: .color(jerseyColor))
        context.stroke(Path(shoulderRect), with: .color(.black), lineWidth: 1)

        // Arms extended forward (blocking hands)
        let armW: CGFloat = 6
        let armH: CGFloat = 12
        let leftArm = CGRect(x: cx - sw / 2 - armW, y: shoulderY - 2, width: armW, height: armH)
        let rightArm = CGRect(x: cx + sw / 2, y: shoulderY - 2, width: armW, height: armH)
        context.fill(Path(leftArm), with: .color(jerseyColor))
        context.fill(Path(rightArm), with: .color(jerseyColor))
        // Hands pushing
        context.fill(Path(CGRect(x: cx - sw / 2 - armW - 2, y: shoulderY + 1, width: 5, height: 6)), with: .color(skinColor))
        context.fill(Path(CGRect(x: cx + sw / 2 + armW - 3, y: shoulderY + 1, width: 5, height: 6)), with: .color(skinColor))

        // Short body (crouched)
        let bodyW = sw - 4
        let bodyRect = CGRect(x: cx - bodyW / 2, y: shoulderY + 8, width: bodyW, height: 8)
        context.fill(Path(bodyRect), with: .color(jerseyColor))

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: shoulderY + 12))

        // Wide base legs
        let legW: CGFloat = 8
        let legH: CGFloat = 10
        let legY = shoulderY + 16
        let leftLeg = CGRect(x: cx - legW - 5, y: legY, width: legW, height: legH)
        let rightLeg = CGRect(x: cx + 5, y: legY, width: legW, height: legH)
        context.fill(Path(leftLeg), with: .color(pantsColor))
        context.fill(Path(rightLeg), with: .color(pantsColor))

        // Cleats
        context.fill(Path(CGRect(x: cx - legW - 6, y: legY + legH, width: legW + 2, height: 3)), with: .color(.black))
        context.fill(Path(CGRect(x: cx + 4, y: legY + legH, width: legW + 2, height: 3)), with: .color(.black))
    }

    // MARK: - Pose: Catching (arms up, reaching for ball)

    private func drawCatching(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let sw = shoulderWidth

        drawShadow(context: context, cx: cx, cy: cy + 20, width: sw + 4)

        // Helmet (looking up)
        let helmetRect = CGRect(x: cx - 9, y: cy - 28, width: 18, height: 16)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1.5)
        drawFacemask(context: context, cx: cx, maskY: cy - 14)

        // Shoulder pads
        let shoulderY = cy - 10
        let shoulderRect = CGRect(x: cx - sw / 2, y: shoulderY, width: sw, height: 7)
        context.fill(Path(shoulderRect), with: .color(jerseyColor))
        context.stroke(Path(shoulderRect), with: .color(.black), lineWidth: 1)

        // Arms reaching UP
        let armW: CGFloat = 5
        let leftArmUp = CGRect(x: cx - 10, y: cy - 38, width: armW, height: 14)
        let rightArmUp = CGRect(x: cx + 5, y: cy - 38, width: armW, height: 14)
        context.fill(Path(leftArmUp), with: .color(jerseyColor))
        context.fill(Path(rightArmUp), with: .color(jerseyColor))
        // Hands (open, reaching)
        context.fill(Path(CGRect(x: cx - 11, y: cy - 42, width: 6, height: 5)), with: .color(skinColor))
        context.fill(Path(CGRect(x: cx + 5, y: cy - 42, width: 6, height: 5)), with: .color(skinColor))

        // Jersey body
        let bodyW = sw - 4
        let bodyH: CGFloat = 13
        let bodyY = shoulderY + 7
        let bodyRect = CGRect(x: cx - bodyW / 2, y: bodyY, width: bodyW, height: bodyH)
        context.fill(Path(bodyRect), with: .color(jerseyColor))

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: bodyY + bodyH / 2))

        // Legs (slightly apart, braking)
        let legW: CGFloat = 7
        let legH: CGFloat = 12
        let legY = bodyY + bodyH
        let leftLeg = CGRect(x: cx - legW - 2, y: legY, width: legW, height: legH)
        let rightLeg = CGRect(x: cx + 2, y: legY, width: legW, height: legH)
        context.fill(Path(leftLeg), with: .color(pantsColor))
        context.fill(Path(rightLeg), with: .color(pantsColor))

        drawCleats(context: context, cx: cx, legW: legW, legY: legY + legH, leftOffset: -2, rightOffset: 2)
    }

    // MARK: - Pose: Throwing (QB arm cocked back)

    private func drawThrowing(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let sw: CGFloat = 20 // QBs are slimmer

        drawShadow(context: context, cx: cx, cy: cy + 20, width: sw + 4)

        // Helmet
        let helmetRect = CGRect(x: cx - 9, y: cy - 26, width: 18, height: 16)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1.5)
        drawFacemask(context: context, cx: cx, maskY: cy - 12)

        // Shoulder pads
        let shoulderY = cy - 8
        let shoulderRect = CGRect(x: cx - sw / 2, y: shoulderY, width: sw, height: 7)
        context.fill(Path(shoulderRect), with: .color(jerseyColor))
        context.stroke(Path(shoulderRect), with: .color(.black), lineWidth: 1)

        // Left arm forward (guiding hand)
        let leftArm = CGRect(x: cx - sw / 2 - 5, y: shoulderY - 2, width: 5, height: 10)
        context.fill(Path(leftArm), with: .color(jerseyColor))
        context.fill(Path(CGRect(x: cx - sw / 2 - 6, y: shoulderY + 8, width: 5, height: 3)), with: .color(skinColor))

        // Right arm cocked back (throwing arm) — raised up and back
        let throwArmX = cx + sw / 2
        let throwArm = CGRect(x: throwArmX, y: shoulderY - 12, width: 5, height: 12)
        context.fill(Path(throwArm), with: .color(jerseyColor))
        // Hand with ball
        context.fill(Path(CGRect(x: throwArmX - 1, y: shoulderY - 16, width: 7, height: 5)), with: .color(skinColor))

        // Jersey body
        let bodyW = sw - 4
        let bodyH: CGFloat = 14
        let bodyY = shoulderY + 7
        let bodyRect = CGRect(x: cx - bodyW / 2, y: bodyY, width: bodyW, height: bodyH)
        context.fill(Path(bodyRect), with: .color(jerseyColor))

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: bodyY + bodyH / 2))

        // Legs (slightly stepped)
        let legW: CGFloat = 7
        let legH: CGFloat = 12
        let legY = bodyY + bodyH
        let leftLeg = CGRect(x: cx - legW - 1, y: legY + 2, width: legW, height: legH)
        let rightLeg = CGRect(x: cx + 1, y: legY - 2, width: legW, height: legH)
        context.fill(Path(leftLeg), with: .color(pantsColor))
        context.fill(Path(rightLeg), with: .color(pantsColor))

        drawCleats(context: context, cx: cx, legW: legW, legY: legY + legH, leftOffset: -1, rightOffset: 1)
    }

    // MARK: - Pose: Tackling (diving/reaching toward ball carrier)

    private func drawTackling(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let sw = shoulderWidth

        drawShadow(context: context, cx: cx, cy: cy + 16, width: sw + 6)

        // Helmet (low, forward)
        let helmetRect = CGRect(x: cx - 9, y: cy - 16, width: 18, height: 14)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1.5)
        drawFacemask(context: context, cx: cx, maskY: cy - 4)

        // Shoulder pads (leaning forward heavily)
        let shoulderY = cy - 2
        let shoulderRect = CGRect(x: cx - sw / 2, y: shoulderY, width: sw, height: 7)
        context.fill(Path(shoulderRect), with: .color(jerseyColor))
        context.stroke(Path(shoulderRect), with: .color(.black), lineWidth: 1)

        // Arms reaching forward to tackle
        let armW: CGFloat = 5
        let armH: CGFloat = 14
        let leftArm = CGRect(x: cx - sw / 2 - armW - 2, y: shoulderY - 6, width: armW, height: armH)
        let rightArm = CGRect(x: cx + sw / 2 + 2, y: shoulderY - 6, width: armW, height: armH)
        context.fill(Path(leftArm), with: .color(jerseyColor))
        context.fill(Path(rightArm), with: .color(jerseyColor))
        // Reaching hands
        context.fill(Path(CGRect(x: cx - sw / 2 - armW - 3, y: shoulderY - 9, width: 6, height: 4)), with: .color(skinColor))
        context.fill(Path(CGRect(x: cx + sw / 2 + 2, y: shoulderY - 9, width: 6, height: 4)), with: .color(skinColor))

        // Short body
        let bodyW = sw - 4
        let bodyRect = CGRect(x: cx - bodyW / 2, y: shoulderY + 7, width: bodyW, height: 8)
        context.fill(Path(bodyRect), with: .color(jerseyColor))

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: shoulderY + 11))

        // Legs trailing behind (stretched out)
        let legW: CGFloat = 7
        let legH: CGFloat = 14
        let legY = shoulderY + 15
        let leftLeg = CGRect(x: cx - legW - 3, y: legY + 3, width: legW, height: legH)
        let rightLeg = CGRect(x: cx + 3, y: legY, width: legW, height: legH)
        context.fill(Path(leftLeg), with: .color(pantsColor))
        context.fill(Path(rightLeg), with: .color(pantsColor))

        context.fill(Path(CGRect(x: cx - legW - 4, y: legY + legH + 3, width: legW + 2, height: 3)), with: .color(.black))
        context.fill(Path(CGRect(x: cx + 2, y: legY + legH, width: legW + 2, height: 3)), with: .color(.black))
    }

    // MARK: - Pose: Down (on the ground after tackle)

    private func drawDown(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let sw = shoulderWidth

        // Horizontal shadow (wider for lying player)
        let shadowRect = CGRect(x: cx - sw, y: cy + 6, width: sw * 2, height: 6)
        context.fill(Ellipse().path(in: shadowRect), with: .color(.black.opacity(0.35)))

        // Draw player lying on side — horizontal layout
        // Helmet
        let helmetRect = CGRect(x: cx - 22, y: cy - 6, width: 14, height: 12)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1)

        // Body (horizontal)
        let bodyRect = CGRect(x: cx - 10, y: cy - 5, width: 20, height: 10)
        context.fill(Path(bodyRect), with: .color(jerseyColor))
        context.stroke(Path(bodyRect), with: .color(.black), lineWidth: 0.5)

        // Number on torso
        let numText = Text("\(player.number)")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: cy))

        // Legs (stretched out)
        let legsRect = CGRect(x: cx + 10, y: cy - 3, width: 16, height: 7)
        context.fill(Path(legsRect), with: .color(pantsColor))

        // Cleats at end
        context.fill(Path(CGRect(x: cx + 26, y: cy - 3, width: 4, height: 7)), with: .color(.black))
    }

    // MARK: - Pose: Backpedaling (DBs dropping into coverage)

    private func drawBackpedaling(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let sw = shoulderWidth

        drawShadow(context: context, cx: cx, cy: cy + 20, width: sw + 4)

        // Helmet (looking forward while moving back)
        let helmetRect = CGRect(x: cx - 9, y: cy - 24, width: 18, height: 15)
        context.fill(Ellipse().path(in: helmetRect), with: .color(helmetColor))
        context.stroke(Ellipse().path(in: helmetRect), with: .color(.black), lineWidth: 1.5)
        drawFacemask(context: context, cx: cx, maskY: cy - 11)

        // Shoulder pads (slightly back)
        let shoulderY = cy - 6
        let shoulderRect = CGRect(x: cx - sw / 2, y: shoulderY, width: sw, height: 7)
        context.fill(Path(shoulderRect), with: .color(jerseyColor))
        context.stroke(Path(shoulderRect), with: .color(.black), lineWidth: 1)

        // Arms out wide for balance
        let armW: CGFloat = 5
        let armH: CGFloat = 9
        let leftArm = CGRect(x: cx - sw / 2 - armW - 1, y: shoulderY + 1, width: armW, height: armH)
        let rightArm = CGRect(x: cx + sw / 2 + 1, y: shoulderY + 1, width: armW, height: armH)
        context.fill(Path(leftArm), with: .color(jerseyColor))
        context.fill(Path(rightArm), with: .color(jerseyColor))
        // Hands
        context.fill(Path(CGRect(x: cx - sw / 2 - armW - 1, y: shoulderY + armH + 1, width: armW, height: 3)), with: .color(skinColor))
        context.fill(Path(CGRect(x: cx + sw / 2 + 1, y: shoulderY + armH + 1, width: armW, height: 3)), with: .color(skinColor))

        // Jersey body
        let bodyW = sw - 4
        let bodyH: CGFloat = 12
        let bodyY = shoulderY + 7
        let bodyRect = CGRect(x: cx - bodyW / 2, y: bodyY, width: bodyW, height: bodyH)
        context.fill(Path(bodyRect), with: .color(jerseyColor))

        // Number
        let numText = Text("\(player.number)")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(numberColor)
        context.draw(context.resolve(numText), at: CGPoint(x: cx, y: bodyY + bodyH / 2))

        // Legs crossing (backpedal step)
        let legW: CGFloat = 7
        let legH: CGFloat = 12
        let legY = bodyY + bodyH
        let leftLeg = CGRect(x: cx - legW, y: legY + 3, width: legW, height: legH)
        let rightLeg = CGRect(x: cx, y: legY - 2, width: legW, height: legH)
        context.fill(Path(leftLeg), with: .color(pantsColor))
        context.fill(Path(rightLeg), with: .color(pantsColor))

        context.fill(Path(CGRect(x: cx - legW - 1, y: legY + legH + 3, width: legW + 2, height: 3)), with: .color(.black))
        context.fill(Path(CGRect(x: cx - 1, y: legY + legH - 2, width: legW + 2, height: 3)), with: .color(.black))
    }

    // MARK: - Shared Drawing Helpers

    private func drawShadow(context: GraphicsContext, cx: CGFloat, cy: CGFloat, width: CGFloat) {
        let shadowRect = CGRect(x: cx - width / 2, y: cy, width: width, height: 8)
        context.fill(Ellipse().path(in: shadowRect), with: .color(.black.opacity(0.4)))
    }

    private func drawFacemask(context: GraphicsContext, cx: CGFloat, maskY: CGFloat) {
        let maskPath = Path { p in
            p.move(to: CGPoint(x: cx - 5, y: maskY))
            p.addLine(to: CGPoint(x: cx + 5, y: maskY))
        }
        context.stroke(maskPath, with: .color(Color(red: 0.55, green: 0.55, blue: 0.55)), lineWidth: 2.0)
        let maskPath2 = Path { p in
            p.move(to: CGPoint(x: cx - 4, y: maskY + 2))
            p.addLine(to: CGPoint(x: cx + 4, y: maskY + 2))
        }
        context.stroke(maskPath2, with: .color(Color(red: 0.5, green: 0.5, blue: 0.5)), lineWidth: 1.0)
    }

    private func drawShoulderHighlight(context: GraphicsContext, cx: CGFloat, sw: CGFloat, y: CGFloat) {
        let highlight = Path { p in
            p.move(to: CGPoint(x: cx - sw / 2, y: y))
            p.addLine(to: CGPoint(x: cx + sw / 2, y: y))
        }
        context.stroke(highlight, with: .color(.white.opacity(0.3)), lineWidth: 1)
    }

    private func drawArmsAtSides(context: GraphicsContext, cx: CGFloat, sw: CGFloat, armY: CGFloat) {
        let armW: CGFloat = 5
        let armH: CGFloat = 10
        let leftArm = CGRect(x: cx - sw / 2 - armW + 1, y: armY, width: armW, height: armH)
        let rightArm = CGRect(x: cx + sw / 2 - 1, y: armY, width: armW, height: armH)
        context.fill(Path(leftArm), with: .color(jerseyColor))
        context.fill(Path(rightArm), with: .color(jerseyColor))
        // Hands
        let handH: CGFloat = 3
        context.fill(Path(CGRect(x: cx - sw / 2 - armW + 1, y: armY + armH, width: armW, height: handH)), with: .color(skinColor))
        context.fill(Path(CGRect(x: cx + sw / 2 - 1, y: armY + armH, width: armW, height: handH)), with: .color(skinColor))
    }

    private func drawCleats(context: GraphicsContext, cx: CGFloat, legW: CGFloat, legY: CGFloat, leftOffset: CGFloat, rightOffset: CGFloat) {
        let cleatH: CGFloat = 4
        context.fill(Path(CGRect(x: cx - legW + leftOffset - 1, y: legY, width: legW + 2, height: cleatH)), with: .color(.black))
        context.fill(Path(CGRect(x: cx + rightOffset - 1, y: legY, width: legW + 2, height: cleatH)), with: .color(.black))
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

// MARK: - Preview

#Preview {
    FPSFieldView(viewModel: GameViewModel())
        .frame(width: 700, height: 500)
        .background(Color.black)
}
