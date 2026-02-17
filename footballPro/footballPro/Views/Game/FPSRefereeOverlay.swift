//
//  FPSRefereeOverlay.swift
//  footballPro
//
//  FPS '93 referee overlay — DOS-style bordered popup window inset on the field.
//  Matches the original game: gray raised panel with RCSTAND sprite inside,
//  and a separate text banner below showing the call (e.g., "First down, Buffalo").
//

import SwiftUI

struct FPSRefereeOverlay: View {
    let message: String
    let onDismiss: () -> Void

    @State private var opacity: Double = 0

    /// Try to get the authentic RCSTAND sprite from SpriteCache
    private var authenticRefereeImage: CGImage? {
        guard SpriteCache.shared.isAvailable else { return nil }
        // RCSTAND is a 1-frame, 8-view animation. Use view 0 (front-facing).
        return SpriteCache.shared.sprite(animation: "RCSTAND", frame: 0, view: 0)?.image
    }

    var body: some View {
        GeometryReader { geo in
            // Panel sizing — matches original FPS '93 proportions
            let panelW = geo.size.width * 0.32
            let panelH = panelW * 0.85  // roughly square referee window
            let textH: CGFloat = 28      // text banner height

            VStack(spacing: 0) {
                // ── Referee panel: raised DOS border around green field + sprite ──
                ZStack {
                    // Green field background inside the panel (matching surrounding field)
                    Color(red: 0.14, green: 0.50, blue: 0.14)

                    // Referee sprite (authentic or fallback)
                    if let cgImage = authenticRefereeImage {
                        Image(decorative: cgImage, scale: 1.0)
                            .interpolation(.none)
                            .scaleEffect(min(
                                (panelW * 0.7) / CGFloat(cgImage.width),
                                (panelH * 0.85) / CGFloat(cgImage.height)
                            ))
                    } else {
                        // Fallback: simple geometric referee silhouette
                        fallbackReferee(width: panelW, height: panelH)
                    }
                }
                .frame(width: panelW, height: panelH)
                .background(VGA.panelBg)
                .modifier(DOSPanelBorder(.raised, width: 3))

                // ── Text banner: separate raised panel below with the call text ──
                Text(message)
                    .font(RetroFont.body())
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .frame(minWidth: panelW * 0.7, maxWidth: panelW * 1.1)
                    .frame(height: textH)
                    .background(VGA.panelBg)
                    .modifier(DOSPanelBorder(.raised, width: 2))
                    .offset(y: -2)  // slight overlap with panel above
            }
            .position(x: geo.size.width / 2, y: geo.size.height * 0.45)
            .opacity(opacity)
        }
        .onTapGesture { onDismiss() }
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                opacity = 1.0
            }
            // Auto-dismiss after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }

    /// Fallback geometric referee when RCSTAND sprite is unavailable
    @ViewBuilder
    private func fallbackReferee(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2

            // Hat (black cap)
            let hat = Path(CGRect(x: cx - 8, y: cy - 48, width: 16, height: 6))
            context.fill(hat, with: .color(.black))

            // Head
            let head = Path(ellipseIn: CGRect(x: cx - 10, y: cy - 42, width: 20, height: 20))
            context.fill(head, with: .color(Color(red: 0.9, green: 0.8, blue: 0.7)))

            // Body (black and white stripes)
            for i in 0..<6 {
                let y = cy - 20 + CGFloat(i) * 7
                let stripe = Path(CGRect(x: cx - 12, y: y, width: 24, height: 7))
                context.fill(stripe, with: .color(i % 2 == 0 ? .black : .white))
            }

            // Black pants
            let pants = Path(CGRect(x: cx - 10, y: cy + 22, width: 20, height: 16))
            context.fill(pants, with: .color(.black))

            // Legs
            let leftLeg = Path(CGRect(x: cx - 8, y: cy + 38, width: 6, height: 12))
            let rightLeg = Path(CGRect(x: cx + 2, y: cy + 38, width: 6, height: 12))
            context.fill(leftLeg, with: .color(.black))
            context.fill(rightLeg, with: .color(.black))

            // Arms at sides (standing pose)
            let leftArm = Path { p in
                p.move(to: CGPoint(x: cx - 12, y: cy - 14))
                p.addLine(to: CGPoint(x: cx - 16, y: cy + 10))
            }
            let rightArm = Path { p in
                p.move(to: CGPoint(x: cx + 12, y: cy - 14))
                p.addLine(to: CGPoint(x: cx + 16, y: cy + 10))
            }
            context.stroke(leftArm, with: .color(.white), lineWidth: 4)
            context.stroke(rightArm, with: .color(.white), lineWidth: 4)
        }
        .frame(width: width, height: height)
    }
}
