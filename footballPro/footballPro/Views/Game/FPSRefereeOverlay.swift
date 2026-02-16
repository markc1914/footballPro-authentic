//
//  FPSRefereeOverlay.swift
//  footballPro
//
//  FPS '93 referee overlay — PIP window on the field (field visible around it)
//  Uses authentic RCSTAND sprite from ANIM.DAT when available.
//  Falls back to Canvas geometric drawing if sprites aren't loaded.
//

import SwiftUI

struct FPSRefereeOverlay: View {
    let message: String
    let onDismiss: () -> Void

    @State private var opacity: Double = 0

    /// Whether this is a stoppage call (timeout, FG, penalty) that shows on black background
    private var isStoppage: Bool {
        let upper = message.uppercased()
        return upper.contains("TIMEOUT") || upper.contains("FIELD GOAL") ||
               upper.contains("PENALTY") || upper.contains("SAFETY") ||
               upper.contains("TWO MINUTE") || upper.contains("GOOD")
    }

    /// Determine the arm signal type based on message content
    private var signalType: RefereeSignal {
        let upper = message.uppercased()
        if upper.contains("TOUCHDOWN") || upper.contains("GOOD") {
            return .touchdown      // Both arms straight up
        } else if upper.contains("INCOMPLETE") {
            return .incomplete     // Arms crossed/waving at waist
        } else if upper.contains("PENALTY") || upper.contains("FLAG") {
            return .penalty        // One arm throwing flag overhead
        } else if upper.contains("TIMEOUT") {
            return .timeout        // Hands forming T
        } else if upper.contains("SAFETY") {
            return .safety         // Hands clasped above head
        } else {
            return .firstDown      // One arm pointing forward
        }
    }

    private enum RefereeSignal {
        case touchdown, firstDown, incomplete, penalty, timeout, safety
    }

    /// Try to get the authentic RCSTAND sprite from SpriteCache
    private var authenticRefereeImage: CGImage? {
        guard SpriteCache.shared.isAvailable else { return nil }
        // RCSTAND is a 1-frame, 8-view animation. Use view 0 (front-facing).
        return SpriteCache.shared.sprite(animation: "RCSTAND", frame: 0, view: 0)?.image
    }

    var body: some View {
        GeometryReader { geo in
            // PIP window overlaid on field — no full-screen backdrop (field visible around it)
            let insetW = geo.size.width * 0.38
            let insetH = geo.size.height * 0.50

            VStack(spacing: 0) {
                // Referee figure inside inset — authentic sprite or Canvas fallback
                if let cgImage = authenticRefereeImage {
                    // Authentic RCSTAND sprite from ANIM.DAT
                    ZStack {
                        // Background — dark green for field continuity, black for stoppages
                        Rectangle()
                            .fill(isStoppage
                                ? Color(red: 0.05, green: 0.05, blue: 0.05)
                                : Color(red: 0.15, green: 0.25, blue: 0.15))

                        Image(decorative: cgImage, scale: 1.0)
                            .interpolation(.none)
                            .scaleEffect(min(
                                (insetW * 0.6) / CGFloat(cgImage.width),
                                (insetH * 0.55 * 0.8) / CGFloat(cgImage.height)
                            ))
                    }
                    .frame(height: insetH * 0.55)
                    .clipped()
                } else {
                    // Fallback: Canvas geometric referee
                    Canvas { context, size in
                        let cx = size.width / 2
                        let cy = size.height / 2

                        // Background — dark green field for continuation, black for stoppages
                        let bgColor = isStoppage
                            ? Color(red: 0.05, green: 0.05, blue: 0.05)
                            : Color(red: 0.15, green: 0.25, blue: 0.15)
                        context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                                     with: .color(bgColor))

                        // Hat (black cap)
                        let hat = Path(CGRect(x: cx - 8, y: cy - 48, width: 16, height: 6))
                        context.fill(hat, with: .color(.black))

                        // Head
                        let head = Path(ellipseIn: CGRect(x: cx - 10, y: cy - 42, width: 20, height: 20))
                        context.fill(head, with: .color(.white))

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

                        // Arms based on signal type
                        let armY = cy - 14
                        switch signalType {
                        case .touchdown:
                            let leftArm = Path { p in
                                p.move(to: CGPoint(x: cx - 12, y: armY))
                                p.addLine(to: CGPoint(x: cx - 16, y: armY - 34))
                            }
                            let rightArm = Path { p in
                                p.move(to: CGPoint(x: cx + 12, y: armY))
                                p.addLine(to: CGPoint(x: cx + 16, y: armY - 34))
                            }
                            context.stroke(leftArm, with: .color(.white), lineWidth: 4)
                            context.stroke(rightArm, with: .color(.white), lineWidth: 4)

                        case .firstDown:
                            let rightArm = Path { p in
                                p.move(to: CGPoint(x: cx + 12, y: armY))
                                p.addLine(to: CGPoint(x: cx + 32, y: armY - 8))
                            }
                            context.stroke(rightArm, with: .color(.white), lineWidth: 4)
                            let leftArm = Path { p in
                                p.move(to: CGPoint(x: cx - 12, y: armY))
                                p.addLine(to: CGPoint(x: cx - 16, y: armY + 16))
                            }
                            context.stroke(leftArm, with: .color(.white), lineWidth: 4)

                        case .incomplete:
                            let leftArm = Path { p in
                                p.move(to: CGPoint(x: cx - 12, y: armY))
                                p.addLine(to: CGPoint(x: cx + 18, y: armY + 12))
                            }
                            let rightArm = Path { p in
                                p.move(to: CGPoint(x: cx + 12, y: armY))
                                p.addLine(to: CGPoint(x: cx - 18, y: armY + 12))
                            }
                            context.stroke(leftArm, with: .color(.white), lineWidth: 4)
                            context.stroke(rightArm, with: .color(.white), lineWidth: 4)

                        case .penalty:
                            let rightArm = Path { p in
                                p.move(to: CGPoint(x: cx + 12, y: armY))
                                p.addLine(to: CGPoint(x: cx + 24, y: armY - 28))
                            }
                            context.stroke(rightArm, with: .color(.white), lineWidth: 4)
                            let flagRect = CGRect(x: cx + 22, y: armY - 32, width: 8, height: 6)
                            context.fill(Path(flagRect), with: .color(VGA.yellow))
                            let leftArm = Path { p in
                                p.move(to: CGPoint(x: cx - 12, y: armY))
                                p.addLine(to: CGPoint(x: cx - 16, y: armY + 16))
                            }
                            context.stroke(leftArm, with: .color(.white), lineWidth: 4)

                        case .timeout:
                            let leftArm = Path { p in
                                p.move(to: CGPoint(x: cx - 12, y: armY))
                                p.addLine(to: CGPoint(x: cx - 24, y: armY - 16))
                            }
                            let rightArm = Path { p in
                                p.move(to: CGPoint(x: cx + 12, y: armY))
                                p.addLine(to: CGPoint(x: cx + 24, y: armY - 16))
                            }
                            context.stroke(leftArm, with: .color(.white), lineWidth: 4)
                            context.stroke(rightArm, with: .color(.white), lineWidth: 4)
                            let tBar = Path { p in
                                p.move(to: CGPoint(x: cx - 10, y: armY - 20))
                                p.addLine(to: CGPoint(x: cx + 10, y: armY - 20))
                            }
                            context.stroke(tBar, with: .color(.white), lineWidth: 4)

                        case .safety:
                            let leftArm = Path { p in
                                p.move(to: CGPoint(x: cx - 12, y: armY))
                                p.addLine(to: CGPoint(x: cx - 4, y: armY - 30))
                            }
                            let rightArm = Path { p in
                                p.move(to: CGPoint(x: cx + 12, y: armY))
                                p.addLine(to: CGPoint(x: cx + 4, y: armY - 30))
                            }
                            context.stroke(leftArm, with: .color(.white), lineWidth: 4)
                            context.stroke(rightArm, with: .color(.white), lineWidth: 4)
                        }
                    }
                    .frame(height: insetH * 0.55)
                }

                // Message text area
                VStack(spacing: 6) {
                    Text(message)
                        .font(RetroFont.header())
                        .foregroundColor(VGA.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(red: 0.20, green: 0.20, blue: 0.20))
            }
            .frame(width: insetW, height: insetH)
            .background(VGA.panelBg)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(red: 0.60, green: 0.60, blue: 0.60), lineWidth: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(.black, lineWidth: 1)
            )
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
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
}
