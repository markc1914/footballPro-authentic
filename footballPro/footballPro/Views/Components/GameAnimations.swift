//
//  GameAnimations.swift
//  footballPro
//
//  Retro-style animations inspired by 1993 Front Page Sports: Football Pro
//

import SwiftUI

// MARK: - Retro Text Animation

struct RetroTextAnimation: View {
    let text: String
    let color: Color
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.5
    @State private var offset: CGFloat = -20

    var body: some View {
        Text(text)
            .font(.system(size: 48, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .shadow(color: .black, radius: 4, x: 2, y: 2)
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(y: offset)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    opacity = 1
                    scale = 1
                    offset = 0
                }
            }
    }
}

// MARK: - Touchdown Animation

struct TouchdownAnimation: View {
    @State private var showText = false
    @State private var showStars = false
    @State private var flashOpacity: Double = 0

    var body: some View {
        ZStack {
            // Flash effect
            Color.yellow.opacity(flashOpacity)
                .ignoresSafeArea()

            // Stars/sparkle effect
            if showStars {
                ForEach(0..<12, id: \.self) { index in
                    StarBurst(index: index)
                }
            }

            // Main text
            if showText {
                VStack(spacing: 8) {
                    RetroTextAnimation(text: "TOUCHDOWN!", color: .green)

                    Text("6 POINTS")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(showText ? 1 : 0)
                }
            }
        }
        .onAppear {
            // Flash sequence
            withAnimation(.easeIn(duration: 0.1)) {
                flashOpacity = 0.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.2)) {
                    flashOpacity = 0
                }
            }

            // Show stars
            withAnimation(.easeIn(duration: 0.2).delay(0.1)) {
                showStars = true
            }

            // Show text
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
                showText = true
            }

            // Play sound
            SoundManager.shared.playTouchdown()
        }
    }
}

struct StarBurst: View {
    let index: Int
    @State private var scale: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    private var angle: Double {
        Double(index) * (360.0 / 12.0)
    }

    var body: some View {
        Image(systemName: "star.fill")
            .font(.title)
            .foregroundColor(.yellow)
            .scaleEffect(scale)
            .offset(x: offset * cos(angle * .pi / 180),
                    y: offset * sin(angle * .pi / 180))
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    scale = 1.5
                    offset = 150
                    opacity = 0
                }
            }
    }
}

// MARK: - Field Goal Animation

struct FieldGoalAnimation: View {
    let isGood: Bool
    @State private var ballOffset: CGFloat = 200
    @State private var ballScale: CGFloat = 1.5
    @State private var showResult = false

    var body: some View {
        ZStack {
            // Goal posts (retro style)
            VStack(spacing: 0) {
                HStack(spacing: 60) {
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 100)
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 100)
                }
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 76, height: 8)
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 50)
            }
            .offset(y: -50)

            // Football
            Text("🏈")
                .font(.system(size: 40))
                .scaleEffect(ballScale)
                .offset(y: ballOffset)
                .rotation3DEffect(.degrees(ballOffset), axis: (x: 0, y: 0, z: 1))

            // Result text
            if showResult {
                RetroTextAnimation(
                    text: isGood ? "IT'S GOOD!" : "NO GOOD!",
                    color: isGood ? .green : .red
                )
                .offset(y: 100)
            }
        }
        .onAppear {
            // Animate ball
            withAnimation(.easeOut(duration: 1.0)) {
                ballOffset = isGood ? -150 : -80
                ballScale = 0.5
            }

            // Show result
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    showResult = true
                }
                SoundManager.shared.playFieldGoal(good: isGood)
            }
        }
    }
}

// MARK: - Turnover Animation

struct TurnoverAnimation: View {
    let type: String // "INTERCEPTION" or "FUMBLE"
    @State private var shakeOffset: CGFloat = 0
    @State private var showText = false

    var body: some View {
        ZStack {
            // Red flash
            Color.red.opacity(0.3)
                .ignoresSafeArea()
                .offset(x: shakeOffset)

            if showText {
                VStack(spacing: 16) {
                    RetroTextAnimation(text: type, color: .red)

                    Text("TURNOVER!")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            // Screen shake effect
            withAnimation(.easeInOut(duration: 0.05).repeatCount(10, autoreverses: true)) {
                shakeOffset = 10
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shakeOffset = 0
                withAnimation {
                    showText = true
                }
            }

            SoundManager.shared.playTurnover()
        }
    }
}

// MARK: - First Down Animation

struct FirstDownAnimation: View {
    @State private var lineOffset: CGFloat = -300
    @State private var showText = false

    var body: some View {
        ZStack {
            // Moving first down line
            Rectangle()
                .fill(Color.yellow)
                .frame(width: 4, height: 200)
                .offset(x: lineOffset)

            if showText {
                Text("FIRST DOWN!")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .shadow(color: .black, radius: 3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                lineOffset = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring()) {
                    showText = true
                }
            }

            SoundManager.shared.playFirstDown()
        }
    }
}

// MARK: - Scoreboard Flash Animation

struct ScoreboardFlash: ViewModifier {
    @Binding var isFlashing: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                Color.white.opacity(isFlashing ? 0.5 : 0)
                    .animation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true), value: isFlashing)
            )
    }
}

extension View {
    func scoreboardFlash(isFlashing: Binding<Bool>) -> some View {
        modifier(ScoreboardFlash(isFlashing: isFlashing))
    }
}

// MARK: - Play Clock Animation

struct PlayClockAnimation: View {
    let seconds: Int
    @State private var pulseScale: CGFloat = 1.0

    var isUrgent: Bool {
        seconds <= 5
    }

    var body: some View {
        Text(String(format: ":%02d", seconds))
            .font(.system(size: 32, weight: .bold, design: .monospaced))
            .foregroundColor(isUrgent ? .red : .white)
            .scaleEffect(pulseScale)
            .onChange(of: seconds) { _, _ in
                if isUrgent {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pulseScale = 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation {
                            pulseScale = 1.0
                        }
                    }
                    SoundManager.shared.play(.clockTick)
                }
            }
    }
}

// MARK: - Retro Field Position Indicator

struct FieldPositionIndicator: View {
    let yardLine: Int
    let isRedZone: Bool
    @State private var markerOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Field background
                HStack(spacing: 0) {
                    // Left end zone
                    Rectangle()
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: geometry.size.width * 0.1)

                    // Field
                    ZStack {
                        Rectangle()
                            .fill(Color.green.opacity(0.3))

                        // Yard lines
                        HStack(spacing: 0) {
                            ForEach(0..<10, id: \.self) { i in
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 1)
                                if i < 9 {
                                    Spacer()
                                }
                            }
                        }

                        // Red zone overlay
                        HStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.red.opacity(isRedZone ? 0.3 : 0))
                                .frame(width: geometry.size.width * 0.2)
                        }
                    }
                    .frame(width: geometry.size.width * 0.8)

                    // Right end zone
                    Rectangle()
                        .fill(Color.orange.opacity(0.5))
                        .frame(width: geometry.size.width * 0.1)
                }

                // Ball marker
                let fieldWidth = geometry.size.width * 0.8
                let offset = geometry.size.width * 0.1 + (CGFloat(yardLine) / 100.0) * fieldWidth

                Circle()
                    .fill(Color.yellow)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black, radius: 2)
                    .offset(x: offset - 6)
                    .animation(.spring(response: 0.3), value: yardLine)
            }
        }
        .frame(height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Play Result Animation Container

struct PlayResultAnimationView: View {
    let result: PlayResult
    @State private var isShowing = true

    var body: some View {
        ZStack {
            if isShowing {
                if result.isTouchdown {
                    TouchdownAnimation()
                } else if result.isTurnover {
                    TurnoverAnimation(type: result.description.contains("INT") ? "INTERCEPTION" : "FUMBLE")
                } else if result.isFirstDown {
                    FirstDownAnimation()
                }
            }
        }
        .onAppear {
            // Auto-dismiss after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    isShowing = false
                }
            }
        }
    }
}

// MARK: - Retro Blinking Text

struct BlinkingText: View {
    let text: String
    let color: Color
    @State private var isVisible = true

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    isVisible.toggle()
                }
            }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 40) {
            TouchdownAnimation()
        }
    }
}
