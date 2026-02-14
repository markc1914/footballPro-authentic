//
//  FPSRefereeOverlay.swift
//  footballPro
//
//  FPS '93 referee overlay — displays after first downs, scores, penalties
//  Gray-bordered window overlaid on field with signal and message
//

import SwiftUI

struct FPSRefereeOverlay: View {
    let message: String
    let onDismiss: () -> Void

    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 12) {
                // Referee figure (simple Canvas-drawn)
                Canvas { context, size in
                    let cx = size.width / 2
                    let cy = size.height / 2

                    // Head
                    let head = Path(ellipseIn: CGRect(x: cx - 8, y: cy - 30, width: 16, height: 16))
                    context.fill(head, with: .color(.white))

                    // Body (black and white stripes)
                    for i in 0..<5 {
                        let y = cy - 12 + CGFloat(i) * 6
                        let stripe = Path(CGRect(x: cx - 10, y: y, width: 20, height: 6))
                        context.fill(stripe, with: .color(i % 2 == 0 ? .black : .white))
                    }

                    // Arms (signal depends on message)
                    let armY = cy - 8
                    // Both arms up for TD
                    if message.contains("TOUCHDOWN") || message.contains("GOOD") {
                        let leftArm = Path { p in
                            p.move(to: CGPoint(x: cx - 10, y: armY))
                            p.addLine(to: CGPoint(x: cx - 20, y: armY - 20))
                        }
                        let rightArm = Path { p in
                            p.move(to: CGPoint(x: cx + 10, y: armY))
                            p.addLine(to: CGPoint(x: cx + 20, y: armY - 20))
                        }
                        context.stroke(leftArm, with: .color(.white), lineWidth: 3)
                        context.stroke(rightArm, with: .color(.white), lineWidth: 3)
                    } else {
                        // One arm pointing for first down / direction
                        let rightArm = Path { p in
                            p.move(to: CGPoint(x: cx + 10, y: armY))
                            p.addLine(to: CGPoint(x: cx + 25, y: armY - 5))
                        }
                        context.stroke(rightArm, with: .color(.white), lineWidth: 3)
                    }
                }
                .frame(width: 60, height: 60)

                // Message text
                Text(message)
                    .font(RetroFont.header())
                    .foregroundColor(VGA.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(20)
            .background(VGA.panelBg)
            .modifier(DOSPanelBorder(.raised))
            .opacity(opacity)
        }
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
