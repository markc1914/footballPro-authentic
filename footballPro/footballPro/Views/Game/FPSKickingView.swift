//
//  FPSKickingView.swift
//  footballPro
//
//  DOS-style kicking controls: angle bar (left) + aim bar (top)
//  Matches original FPS Football Pro '93 kicking minigame
//  Sequence: set angle -> set aim -> kick executes
//

import SwiftUI

// MARK: - Kicking Phase State

enum KickingPhase {
    case settingAngle   // Cursor oscillates on vertical bar
    case settingAim     // Cursor oscillates on horizontal bar
    case executing      // Both locked, kick result calculating
}

// MARK: - Kick Type

public enum KickType: Equatable {
    case fieldGoal
    case punt
    case kickoff
    case extraPoint
}

// MARK: - FPSKickingView

struct FPSKickingView: View {
    @ObservedObject var viewModel: GameViewModel
    let kickType: KickType
    let onKickComplete: (Double, Double) -> Void  // (angle 25-65, aimOffset -1...1)

    @State private var kickingPhase: KickingPhase = .settingAngle
    @State private var angleCursorPosition: Double = 0.5   // 0=bottom(25deg), 1=top(65deg)
    @State private var aimCursorPosition: Double = 0.5     // 0=left, 1=right
    @State private var angleLocked: Double? = nil
    @State private var aimLocked: Double? = nil
    @State private var oscillationTimer: Timer? = nil

    // Oscillation speed (cycles per second) — affected by kicker skill
    private let angleOscillationSpeed: Double = 1.2
    private let aimOscillationSpeed: Double = 1.6

    // Bar dimensions
    private let angleBarWidth: CGFloat = 28
    private let aimBarHeight: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Field background (semi-transparent to show field behind)
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                // Kick type label at center
                VStack(spacing: 8) {
                    Text(kickTypeLabel)
                        .font(RetroFont.title())
                        .foregroundColor(VGA.digitalAmber)
                        .shadow(color: .black, radius: 2, x: 1, y: 1)

                    if kickType == .fieldGoal, let game = viewModel.game {
                        let distance = 100 - game.fieldPosition.yardLine + 17
                        Text("\(distance) YARDS")
                            .font(RetroFont.header())
                            .foregroundColor(VGA.white)
                            .shadow(color: .black, radius: 2, x: 1, y: 1)
                    }

                    Text(phaseInstruction)
                        .font(RetroFont.body())
                        .foregroundColor(VGA.lightGray)
                        .shadow(color: .black, radius: 1, x: 1, y: 1)
                }

                // Angle bar (left side)
                angleBar(screenHeight: geo.size.height)
                    .position(x: angleBarWidth / 2 + 8, y: geo.size.height / 2)

                // Aim bar (top) — only visible after angle is locked
                if kickingPhase == .settingAim || kickingPhase == .executing {
                    aimBar(screenWidth: geo.size.width)
                        .position(x: geo.size.width / 2, y: aimBarHeight / 2 + 8)
                }

                // Result readout (after both locked)
                if kickingPhase == .executing {
                    VStack(spacing: 4) {
                        let angle = angleFromPosition(angleLocked ?? 0.5)
                        let aimText = aimDescriptionFromPosition(aimLocked ?? 0.5)
                        Text("ANGLE: \(Int(angle))deg")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.digitalAmber)
                        Text("AIM: \(aimText)")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.digitalAmber)
                    }
                    .padding(8)
                    .background(VGA.panelVeryDark.opacity(0.9))
                    .modifier(DOSPanelBorder(.raised, width: 1))
                    .position(x: geo.size.width / 2, y: geo.size.height - 60)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                handleInput()
            }
            .onKeyPress(.space) {
                handleInput()
                return .handled
            }
            .onKeyPress(.return) {
                handleInput()
                return .handled
            }
            .onAppear {
                startAngleOscillation()
            }
            .onDisappear {
                oscillationTimer?.invalidate()
                oscillationTimer = nil
            }
        }
    }

    // MARK: - Kick Type Label

    private var kickTypeLabel: String {
        switch kickType {
        case .fieldGoal: return "FIELD GOAL"
        case .punt: return "PUNT"
        case .kickoff: return "KICKOFF"
        case .extraPoint: return "EXTRA POINT"
        }
    }

    private var phaseInstruction: String {
        switch kickingPhase {
        case .settingAngle: return "PRESS SPACE TO SET ANGLE"
        case .settingAim: return "PRESS SPACE TO SET AIM"
        case .executing: return "KICKING..."
        }
    }

    // MARK: - Angle Bar (Vertical, left side)

    private func angleBar(screenHeight: CGFloat) -> some View {
        let barHeight = screenHeight * 0.6
        let cursorY = (1.0 - angleCursorPosition) * barHeight  // Invert: top=65, bottom=25

        return ZStack(alignment: .topLeading) {
            // Background
            Rectangle()
                .fill(Color.black)
                .frame(width: angleBarWidth, height: barHeight)
                .modifier(DOSPanelBorder(.sunken, width: 1))

            // Fill from bottom up to cursor
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(VGA.playSlotGreen)
                    .frame(width: angleBarWidth - 4, height: barHeight * CGFloat(angleCursorPosition))
            }
            .frame(width: angleBarWidth - 4, height: barHeight)
            .padding(.leading, 2)

            // Sweet spot marker at 45 degrees (center)
            let sweetSpotY = barHeight * 0.5
            Rectangle()
                .fill(VGA.white.opacity(0.5))
                .frame(width: angleBarWidth, height: 1)
                .offset(y: sweetSpotY)

            // Cursor line
            Rectangle()
                .fill(angleLocked != nil ? VGA.brightRed : VGA.digitalAmber)
                .frame(width: angleBarWidth + 8, height: 3)
                .offset(x: -4, y: cursorY)

            // Degree labels
            VStack {
                Text("65\u{00B0}")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.lightGray)
                Spacer()
                Text("45\u{00B0}")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.white)
                Spacer()
                Text("25\u{00B0}")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.lightGray)
            }
            .frame(height: barHeight)
            .offset(x: angleBarWidth + 4)
        }
        .frame(width: angleBarWidth + 30, height: barHeight)
    }

    // MARK: - Aim Bar (Horizontal, top)

    private func aimBar(screenWidth: CGFloat) -> some View {
        let barWidth = screenWidth * 0.6
        let cursorX = aimCursorPosition * barWidth

        return ZStack(alignment: .topLeading) {
            // Background
            Rectangle()
                .fill(Color.black)
                .frame(width: barWidth, height: aimBarHeight)
                .modifier(DOSPanelBorder(.sunken, width: 1))

            // Center marker
            let centerX = barWidth * 0.5
            Rectangle()
                .fill(VGA.white.opacity(0.5))
                .frame(width: 1, height: aimBarHeight)
                .offset(x: centerX)

            // Cursor line
            Rectangle()
                .fill(aimLocked != nil ? VGA.brightRed : VGA.digitalAmber)
                .frame(width: 3, height: aimBarHeight + 8)
                .offset(x: cursorX, y: -4)

            // Direction labels
            HStack {
                Text("LEFT")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.lightGray)
                Spacer()
                Text("CENTER")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.white)
                Spacer()
                Text("RIGHT")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.lightGray)
            }
            .frame(width: barWidth)
            .offset(y: aimBarHeight + 4)
        }
        .frame(width: barWidth, height: aimBarHeight + 20)
    }

    // MARK: - Input Handling

    private func handleInput() {
        switch kickingPhase {
        case .settingAngle:
            angleLocked = angleCursorPosition
            kickingPhase = .settingAim
            startAimOscillation()

        case .settingAim:
            aimLocked = aimCursorPosition
            kickingPhase = .executing
            oscillationTimer?.invalidate()
            oscillationTimer = nil

            // Brief delay then execute
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let angle = angleFromPosition(angleLocked ?? 0.5)
                let aimOffset = (aimLocked ?? 0.5) * 2.0 - 1.0  // Map 0..1 to -1..1
                onKickComplete(angle, aimOffset)
            }

        case .executing:
            break  // Already executing
        }
    }

    // MARK: - Oscillation Timers

    private func startAngleOscillation() {
        oscillationTimer?.invalidate()
        let startTime = Date()
        oscillationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            // Sine wave oscillation: 0..1..0..1...
            let raw = sin(elapsed * angleOscillationSpeed * .pi)
            DispatchQueue.main.async {
                self.angleCursorPosition = (raw + 1.0) / 2.0
            }
        }
    }

    private func startAimOscillation() {
        oscillationTimer?.invalidate()
        let startTime = Date()
        oscillationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            // Sine wave oscillation: 0..1..0..1...
            let raw = sin(elapsed * aimOscillationSpeed * .pi)
            DispatchQueue.main.async {
                self.aimCursorPosition = (raw + 1.0) / 2.0
            }
        }
    }

    // MARK: - Conversion Helpers

    /// Convert cursor position (0..1) to angle in degrees (25..65)
    private func angleFromPosition(_ position: Double) -> Double {
        return 25.0 + position * 40.0
    }

    /// Describe aim direction from position (0..1)
    private func aimDescriptionFromPosition(_ position: Double) -> String {
        let offset = position * 2.0 - 1.0  // -1..1
        if abs(offset) < 0.1 {
            return "STRAIGHT"
        } else if offset < -0.3 {
            return "HARD LEFT"
        } else if offset < 0 {
            return "SLIGHT LEFT"
        } else if offset > 0.3 {
            return "HARD RIGHT"
        } else {
            return "SLIGHT RIGHT"
        }
    }
}
