//
//  FPSRefereeOverlay.swift
//  footballPro
//
//  FPS '93 referee overlay — rectangular inset window on field
//  Matches the original game's close-up inset with referee signal + text
//

import SwiftUI

struct FPSRefereeOverlay: View {
    let message: String
    let onDismiss: () -> Void

    @State private var opacity: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Semi-transparent background — field still visible around inset
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                // Inset window (~40% of screen) — gray bordered rectangle
                let insetW = geo.size.width * 0.40
                let insetH = geo.size.height * 0.55

                VStack(spacing: 0) {
                    // Gray title bar
                    HStack {
                        Text("OFFICIAL'S SIGNAL")
                            .font(RetroFont.small())
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.75, green: 0.75, blue: 0.75))

                    // Referee figure inside dark inset
                    Canvas { context, size in
                        let cx = size.width / 2
                        let cy = size.height / 2

                        // Dark background
                        context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                                     with: .color(Color(red: 0.15, green: 0.25, blue: 0.15)))

                        // Head
                        let head = Path(ellipseIn: CGRect(x: cx - 10, y: cy - 40, width: 20, height: 20))
                        context.fill(head, with: .color(.white))

                        // Body (black and white stripes)
                        for i in 0..<6 {
                            let y = cy - 18 + CGFloat(i) * 7
                            let stripe = Path(CGRect(x: cx - 12, y: y, width: 24, height: 7))
                            context.fill(stripe, with: .color(i % 2 == 0 ? .black : .white))
                        }

                        // Black pants
                        let pants = Path(CGRect(x: cx - 10, y: cy + 24, width: 20, height: 16))
                        context.fill(pants, with: .color(.black))

                        // Arms (signal depends on message)
                        let armY = cy - 12
                        if message.contains("TOUCHDOWN") || message.contains("GOOD") {
                            // Both arms up
                            let leftArm = Path { p in
                                p.move(to: CGPoint(x: cx - 12, y: armY))
                                p.addLine(to: CGPoint(x: cx - 24, y: armY - 28))
                            }
                            let rightArm = Path { p in
                                p.move(to: CGPoint(x: cx + 12, y: armY))
                                p.addLine(to: CGPoint(x: cx + 24, y: armY - 28))
                            }
                            context.stroke(leftArm, with: .color(.white), lineWidth: 4)
                            context.stroke(rightArm, with: .color(.white), lineWidth: 4)
                        } else {
                            // One arm pointing for first down / direction
                            let rightArm = Path { p in
                                p.move(to: CGPoint(x: cx + 12, y: armY))
                                p.addLine(to: CGPoint(x: cx + 32, y: armY - 8))
                            }
                            context.stroke(rightArm, with: .color(.white), lineWidth: 4)
                            // Left arm at side
                            let leftArm = Path { p in
                                p.move(to: CGPoint(x: cx - 12, y: armY))
                                p.addLine(to: CGPoint(x: cx - 16, y: armY + 16))
                            }
                            context.stroke(leftArm, with: .color(.white), lineWidth: 4)
                        }
                    }
                    .frame(height: insetH * 0.55)

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
                .opacity(opacity)
            }
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
