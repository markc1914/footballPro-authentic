//
//  AuthenticSplashScreen.swift
//  footballPro
//
//  Authentic FPS Football Pro '93 splash — shows original Dynamix logo (INTDYNA.SCR)
//  then crossfades to the title screen (CREDIT.SCR) from the original game files.
//  Falls back gracefully to the existing SplashScreen if game files are unavailable.
//

import SwiftUI
import CoreGraphics

struct AuthenticSplashScreen: View {
    var onComplete: () -> Void

    @State private var phase: SplashPhase = .dynamixLogo
    @State private var opacity: Double = 0
    @State private var logoImage: CGImage?
    @State private var titleImage: CGImage?
    @State private var filesAvailable = false
    @State private var showPressAnyKey = false
    @State private var pressKeyBlink = true

    private enum SplashPhase {
        case dynamixLogo
        case titleScreen
        case fadeOut
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if filesAvailable {
                // Dynamix logo phase
                if phase == .dynamixLogo, let logo = logoImage {
                    Image(decorative: logo, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(opacity)
                }

                // Title screen phase
                if phase == .titleScreen || phase == .fadeOut, let title = titleImage {
                    Image(decorative: title, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(phase == .fadeOut ? 0 : opacity)
                }

                // "PRESS ANY KEY" text during title screen
                if phase == .titleScreen && showPressAnyKey {
                    VStack {
                        Spacer()
                        Text("PRESS ANY KEY")
                            .font(RetroFont.body())
                            .foregroundColor(VGA.lightGray)
                            .opacity(pressKeyBlink ? 1.0 : 0.3)
                            .padding(.bottom, 40)
                    }
                }

                // CRT scanlines overlay
                Canvas { context, size in
                    for y in stride(from: 0, to: size.height, by: 3) {
                        let line = Path(CGRect(x: 0, y: y, width: size.width, height: 1))
                        context.fill(line, with: .color(Color.black.opacity(0.08)))
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            loadAssets()
        }
        .onTapGesture {
            skipToEnd()
        }
        .onKeyPress(.space) {
            skipToEnd()
            return .handled
        }
        .onKeyPress(.return) {
            skipToEnd()
            return .handled
        }
        .onKeyPress(.escape) {
            skipToEnd()
            return .handled
        }
    }

    private func loadAssets() {
        // Load Dynamix logo: TTM/INTDYNA.SCR with TTM/INTDYNA.PAL
        let gameDir = SCRDecoder.defaultDirectory

        let intdynaSCR = try? SCRDecoder.decode(at: gameDir.appendingPathComponent("TTM/INTDYNA.SCR"))
        let intdynaPAL = PALDecoder.loadPalette(at: gameDir.appendingPathComponent("TTM/INTDYNA.PAL"))

        let creditSCR = try? SCRDecoder.decode(at: gameDir.appendingPathComponent("TTM/CREDIT.SCR"))
        let creditPAL = PALDecoder.loadPalette(at: gameDir.appendingPathComponent("TTM/CREDIT.PAL"))

        if let scr = intdynaSCR, let pal = intdynaPAL {
            logoImage = scr.cgImage(palette: pal)
        }

        if let scr = creditSCR, let pal = creditPAL {
            titleImage = scr.cgImage(palette: pal)
        }

        if logoImage != nil || titleImage != nil {
            filesAvailable = true
            animateSplash()
        } else {
            // No game files available — skip splash entirely
            onComplete()
        }
    }

    private func animateSplash() {
        // Phase 1: Fade in Dynamix logo
        withAnimation(.easeIn(duration: 0.5)) {
            opacity = 1.0
        }

        // Phase 2: After 2.5 seconds, crossfade to title screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if phase == .fadeOut { return } // already skipped
            withAnimation(.easeInOut(duration: 0.5)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if phase == .fadeOut { return }
                phase = .titleScreen
                withAnimation(.easeIn(duration: 0.5)) {
                    opacity = 1.0
                }
                // Show "PRESS ANY KEY" after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showPressAnyKey = true
                    startBlinkTimer()
                }
            }
        }

        // Phase 3: Auto-advance after title screen shows for 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
            if phase == .fadeOut { return }
            fadeOutAndComplete()
        }
    }

    private func startBlinkTimer() {
        // Blink the "PRESS ANY KEY" text
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { timer in
            if phase == .fadeOut {
                timer.invalidate()
                return
            }
            pressKeyBlink.toggle()
        }
    }

    private func skipToEnd() {
        guard phase != .fadeOut else { return }

        if phase == .dynamixLogo && titleImage != nil {
            // Skip to title screen
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                phase = .titleScreen
                showPressAnyKey = true
                startBlinkTimer()
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1.0
                }
            }
        } else {
            // Skip to main menu
            fadeOutAndComplete()
        }
    }

    private func fadeOutAndComplete() {
        phase = .fadeOut
        withAnimation(.easeOut(duration: 0.4)) {
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
}

// MARK: - PALDecoder extension for loading by URL

extension PALDecoder {
    /// Load a palette from a specific file URL
    static func loadPalette(at url: URL) -> VGAPalette? {
        guard let palette = try? decode(at: url) else { return nil }
        return palette
    }
}

#Preview {
    AuthenticSplashScreen(onComplete: {})
}
