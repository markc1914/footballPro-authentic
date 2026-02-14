//
//  FPSReplayControls.swift
//  footballPro
//
//  FPS '93 VCR-style instant replay controls
//  Red transport buttons overlay on field view
//  Manual progress scrubbing of play animation blueprint
//

import SwiftUI

struct FPSReplayControls: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var replayProgress: Double = 0
    @State private var isPlaying = false
    @State private var playbackSpeed: Double = 1.0

    let onExit: () -> Void

    var body: some View {
        VStack {
            // Top toolbar with VCR buttons
            HStack(spacing: 4) {
                Spacer()

                // Rewind to start
                replayButton("\u{23EE}") {
                    replayProgress = 0
                    isPlaying = false
                }

                // Step back
                replayButton("\u{23EA}") {
                    replayProgress = max(0, replayProgress - 0.05)
                    isPlaying = false
                }

                // Stop
                replayButton("\u{23F9}") {
                    isPlaying = false
                }

                // Play
                replayButton(isPlaying ? "\u{23F8}" : "\u{25B6}") {
                    isPlaying.toggle()
                }

                // Fast forward
                replayButton("\u{23E9}") {
                    replayProgress = min(1.0, replayProgress + 0.05)
                    isPlaying = false
                }

                // Skip to end
                replayButton("\u{23ED}") {
                    replayProgress = 1.0
                    isPlaying = false
                }

                Spacer().frame(width: 16)

                // Speed selector
                HStack(spacing: 2) {
                    speedButton("1/4x", speed: 0.25)
                    speedButton("1/2x", speed: 0.5)
                    speedButton("1x", speed: 1.0)
                    speedButton("2x", speed: 2.0)
                }

                Spacer().frame(width: 16)

                // Exit replay
                FPSButton("EXIT REPLAY") {
                    isPlaying = false
                    onExit()
                }

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(VGA.panelVeryDark.opacity(0.9))
            .modifier(DOSPanelBorder(.raised, width: 1))

            Spacer()

            // Progress bar at bottom
            VStack(spacing: 2) {
                // Progress slider
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track background
                        Rectangle()
                            .fill(VGA.panelDark)
                            .frame(height: 8)

                        // Filled portion
                        Rectangle()
                            .fill(VGA.digitalAmber)
                            .frame(width: geo.size.width * replayProgress, height: 8)

                        // Scrub handle
                        Circle()
                            .fill(VGA.digitalAmber)
                            .frame(width: 14, height: 14)
                            .offset(x: geo.size.width * replayProgress - 7)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isPlaying = false
                                replayProgress = min(max(value.location.x / geo.size.width, 0), 1)
                            }
                    )
                }
                .frame(height: 14)

                // Time labels
                HStack {
                    Text(formatTime(replayProgress))
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.digitalAmber)
                    Spacer()
                    Text("INSTANT REPLAY")
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.darkGray)
                    Spacer()
                    Text(formatTime(1.0))
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.darkGray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(VGA.panelVeryDark.opacity(0.9))
        }
        .onReceive(Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()) { _ in
            guard isPlaying else { return }
            let duration = viewModel.currentAnimationBlueprint?.totalDuration ?? 3.0
            let increment = (1.0 / 30.0) * playbackSpeed / duration
            replayProgress = min(1.0, replayProgress + increment)
            if replayProgress >= 1.0 {
                isPlaying = false
            }
        }
    }

    private func replayButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 32, height: 28)
                .background(VGA.buttonBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(VGA.buttonHighlight, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func speedButton(_ label: String, speed: Double) -> some View {
        Button(action: { playbackSpeed = speed }) {
            Text(label)
                .font(RetroFont.tiny())
                .foregroundColor(playbackSpeed == speed ? .black : .white)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(playbackSpeed == speed ? VGA.digitalAmber : VGA.panelDark)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatTime(_ progress: Double) -> String {
        let duration = viewModel.currentAnimationBlueprint?.totalDuration ?? 3.0
        let seconds = progress * duration
        return String(format: "%.1fs", seconds)
    }
}
