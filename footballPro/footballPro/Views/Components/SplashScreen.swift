//
//  SplashScreen.swift
//  footballPro
//
//  FPS Football Pro '93 splash screen — night stadium scene
//  Dark sky, stadium silhouettes, green field, yellow goal posts, light poles with glow
//

import SwiftUI

struct SplashScreen: View {
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var fadeOut = false

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()

            // Night stadium scene
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // Dark sky gradient
                for y in stride(from: 0, to: h * 0.55, by: 2) {
                    let t = y / (h * 0.55)
                    let r = 0.01 + t * 0.03
                    let g = 0.01 + t * 0.02
                    let b = 0.05 + t * 0.08
                    let skyLine = Path(CGRect(x: 0, y: y, width: w, height: 2))
                    context.fill(skyLine, with: .color(Color(red: r, green: g, blue: b)))
                }

                // Stars
                let starSeed: [CGFloat] = [0.12, 0.34, 0.56, 0.78, 0.91, 0.23, 0.45, 0.67, 0.89, 0.01,
                                            0.15, 0.37, 0.59, 0.81, 0.93, 0.26, 0.48, 0.62, 0.84, 0.06,
                                            0.18, 0.32, 0.54, 0.76, 0.98, 0.21, 0.43, 0.65, 0.87, 0.09,
                                            0.11, 0.33, 0.55, 0.77, 0.99, 0.22, 0.44, 0.66, 0.88, 0.03]
                for i in 0..<40 {
                    let x = starSeed[i] * w
                    let yIdx = (i + 7) % 40
                    let y = starSeed[yIdx] * h * 0.45
                    let brightness = 0.2 + starSeed[(i + 3) % 40] * 0.6
                    let sz: CGFloat = starSeed[(i + 5) % 40] > 0.7 ? 2.0 : 1.0
                    let star = Path(ellipseIn: CGRect(x: x, y: y, width: sz, height: sz))
                    context.fill(star, with: .color(Color.white.opacity(brightness)))
                }

                // Stadium silhouettes (left side)
                drawStadiumSide(context: context, x: 0, width: w * 0.25, h: h, side: .left)

                // Stadium silhouettes (right side)
                drawStadiumSide(context: context, x: w * 0.75, width: w * 0.25, h: h, side: .right)

                // Field (green strip)
                let fieldTop = h * 0.60
                let fieldHeight = h * 0.30
                let fieldRect = CGRect(x: w * 0.15, y: fieldTop, width: w * 0.70, height: fieldHeight)
                context.fill(Path(fieldRect), with: .color(Color(red: 0.10, green: 0.36, blue: 0.10)))

                // Grass stripes
                let stripeWidth = fieldRect.width / 10
                for i in 0..<10 {
                    if i % 2 == 0 {
                        let stripe = CGRect(x: fieldRect.minX + CGFloat(i) * stripeWidth, y: fieldTop,
                                          width: stripeWidth, height: fieldHeight)
                        context.fill(Path(stripe), with: .color(Color(red: 0.13, green: 0.42, blue: 0.13)))
                    }
                }

                // Yard lines
                for i in 0...10 {
                    let lx = fieldRect.minX + CGFloat(i) * stripeWidth
                    let yardLine = Path(CGRect(x: lx - 0.5, y: fieldTop, width: 1, height: fieldHeight))
                    context.fill(yardLine, with: .color(Color.white.opacity(0.5)))
                }

                // Goal post (center)
                let postX = w / 2
                let postBase = fieldTop

                // Main vertical post
                let mainPost = CGRect(x: postX - 3, y: postBase - 110, width: 6, height: 110)
                context.fill(Path(mainPost), with: .color(Color(red: 0.9, green: 0.8, blue: 0.2)))

                // Crossbar
                let crossbar = CGRect(x: postX - 30, y: postBase - 110, width: 60, height: 5)
                context.fill(Path(crossbar), with: .color(Color(red: 0.9, green: 0.8, blue: 0.2)))

                // Uprights
                let leftUpright = CGRect(x: postX - 30, y: postBase - 170, width: 4, height: 60)
                context.fill(Path(leftUpright), with: .color(Color(red: 0.9, green: 0.8, blue: 0.2)))

                let rightUpright = CGRect(x: postX + 26, y: postBase - 170, width: 4, height: 60)
                context.fill(Path(rightUpright), with: .color(Color(red: 0.9, green: 0.8, blue: 0.2)))

                // Stadium light poles
                for xOffset: CGFloat in [-0.28, -0.20, 0.20, 0.28] {
                    let lightX = w / 2 + w * xOffset
                    let towerBottom = fieldTop
                    let towerTop = h * 0.25

                    // Tower pole
                    let tower = CGRect(x: lightX - 3, y: towerTop, width: 6, height: towerBottom - towerTop)
                    context.fill(Path(tower), with: .color(Color(red: 0.15, green: 0.15, blue: 0.18)))

                    // Light bank
                    let bank = CGRect(x: lightX - 12, y: towerTop - 4, width: 24, height: 8)
                    context.fill(Path(bank), with: .color(Color(red: 0.7, green: 0.7, blue: 0.7)))

                    // Light glow
                    let glow = Path(ellipseIn: CGRect(x: lightX - 20, y: towerTop - 20, width: 40, height: 30))
                    context.fill(glow, with: .color(Color.white.opacity(0.06)))
                }

                // Scanlines
                for y in stride(from: 0, to: h, by: 3) {
                    let line = Path(CGRect(x: 0, y: y, width: w, height: 1))
                    context.fill(line, with: .color(Color.black.opacity(0.10)))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Title overlay
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 60)

                if showTitle {
                    VStack(spacing: 8) {
                        Text("FRONT PAGE SPORTS")
                            .font(RetroFont.header())
                            .foregroundColor(VGA.lightGray)
                            .tracking(4)

                        HStack(spacing: 0) {
                            Text("FOOTBALL ")
                                .font(RetroFont.huge())
                                .foregroundColor(VGA.white)
                            Text("PRO")
                                .font(RetroFont.huge())
                                .foregroundColor(VGA.brightRed)
                        }
                        .shadow(color: .black, radius: 0, x: 3, y: 3)

                        Text("'93")
                            .font(RetroFont.large())
                            .foregroundColor(VGA.digitalAmber)
                            .tracking(2)
                    }
                    .opacity(fadeOut ? 0 : 1)
                    .animation(.easeIn(duration: 0.5), value: showTitle)
                }

                Spacer()

                if showSubtitle {
                    VStack(spacing: 4) {
                        Text("A DYNAMIX PRODUCT")
                            .font(RetroFont.small())
                            .foregroundColor(VGA.darkGray)
                            .tracking(2)

                        Text("Recreated with Swift & SwiftUI")
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.darkGray.opacity(0.7))
                    }
                    .opacity(fadeOut ? 0 : 1)
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            animateSplash()
        }
    }

    // MARK: - Stadium Side Silhouette

    enum StadiumSide {
        case left, right
    }

    private func drawStadiumSide(context: GraphicsContext, x: CGFloat, width: CGFloat, h: CGFloat, side: StadiumSide) {
        let baseY = h * 0.60
        let topY = h * 0.35

        var path = Path()
        if side == .left {
            path.move(to: CGPoint(x: x, y: baseY))
            path.addLine(to: CGPoint(x: x, y: topY))
            path.addLine(to: CGPoint(x: x + width * 0.3, y: topY - 10))
            path.addLine(to: CGPoint(x: x + width * 0.6, y: topY + 20))
            path.addLine(to: CGPoint(x: x + width * 0.8, y: topY + 40))
            path.addLine(to: CGPoint(x: x + width, y: baseY))
            path.closeSubpath()
        } else {
            path.move(to: CGPoint(x: x, y: baseY))
            path.addLine(to: CGPoint(x: x + width * 0.2, y: topY + 40))
            path.addLine(to: CGPoint(x: x + width * 0.4, y: topY + 20))
            path.addLine(to: CGPoint(x: x + width * 0.7, y: topY - 10))
            path.addLine(to: CGPoint(x: x + width, y: topY))
            path.addLine(to: CGPoint(x: x + width, y: baseY))
            path.closeSubpath()
        }

        context.fill(path, with: .color(Color(red: 0.08, green: 0.08, blue: 0.10)))

        // Stadium rows (horizontal lines within silhouette)
        for row in stride(from: topY + 10, to: baseY, by: 12) {
            let rowLine = Path(CGRect(x: x, y: row, width: width, height: 1))
            context.fill(rowLine, with: .color(Color(red: 0.10, green: 0.10, blue: 0.13)))
        }
    }

    // MARK: - Animation

    private func animateSplash() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                showTitle = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSubtitle = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                fadeOut = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            onComplete()
        }
    }
}

#Preview {
    SplashScreen(onComplete: {})
}
