//
//  SplashScreen.swift
//  footballPro
//
//  FPS Football Pro '93 splash screen — faithful recreation of the original
//  Low-angle endzone camera: goal posts left-of-center, stadium upper-right,
//  perspective field with grass stripes, light towers with glow, scrolling credits.
//

import SwiftUI

struct SplashScreen: View {
    @State private var showTitle = false
    @State private var creditIndex = -1
    @State private var fadeOut = false

    var onComplete: () -> Void

    // Credits that scroll in the upper-right, matching original
    private let credits: [(String, String)] = [
        ("Game Design", "Dave Kaemmer"),
        ("Lead Programming", "Dave Kaemmer"),
        ("Shell and Stats Programming", "Glen Wolfram"),
        ("Additional Programming", "Rick Relationship"),
        ("Additional Artwork", "Ian Gilliland"),
        ("Front Page Sports:\nFootball PRO", ""),
        ("Copyright 1993, Dynamix Inc.", ""),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Stadium scene canvas
            Canvas { context, size in
                drawScene(context: context, size: size)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Title text overlay — positioned on the field, lower-center-right
            if showTitle {
                VStack(spacing: 0) {
                    Spacer()

                    HStack {
                        Spacer()
                            .frame(width: 80)

                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                Text("FRONT PAGE SPORTS")
                                    .font(RetroFont.header())
                                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                                    .tracking(1)
                                Text(" \u{2122}")
                                    .font(RetroFont.tiny())
                                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                                    .baselineOffset(8)
                            }

                            HStack(alignment: .bottom, spacing: 0) {
                                Text("FOOTBALL")
                                    .font(.custom("Menlo-Bold", size: 42))
                                    .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                                    .shadow(color: Color(red: 0.15, green: 0.15, blue: 0.15), radius: 0, x: 3, y: 3)
                                Text("PRO")
                                    .font(.custom("Menlo-Bold", size: 42))
                                    .foregroundColor(Color(red: 0.95, green: 0.15, blue: 0.15))
                                    .shadow(color: Color(red: 0.3, green: 0.0, blue: 0.0), radius: 0, x: 3, y: 3)
                            }
                        }
                        .scaleEffect(x: 1.0, y: 0.85, anchor: .bottom)

                        Spacer()
                    }

                    Spacer()
                        .frame(height: 60)
                }
                .opacity(fadeOut ? 0 : 1)
            }

            // Scrolling credits — upper right, matching original style
            if creditIndex >= 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    Spacer()
                        .frame(height: 40)

                    if creditIndex < credits.count {
                        let credit = credits[creditIndex]
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 6) {
                                // Red diamond bullet
                                Text("\u{25A0}")
                                    .font(RetroFont.tiny())
                                    .foregroundColor(Color(red: 0.8, green: 0.1, blue: 0.1))
                                Text(credit.0)
                                    .font(RetroFont.small())
                                    .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.75))
                            }
                            if !credit.1.isEmpty {
                                Text(credit.1)
                                    .font(RetroFont.small())
                                    .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.75))
                            }
                        }
                        .transition(.opacity)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 30)
                .opacity(fadeOut ? 0 : 1)
            }

            // CRT scanlines
            Canvas { context, size in
                for y in stride(from: 0, to: size.height, by: 3) {
                    let line = Path(CGRect(x: 0, y: y, width: size.width, height: 1))
                    context.fill(line, with: .color(Color.black.opacity(0.08)))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .onAppear {
            animateSplash()
        }
    }

    // MARK: - Scene Drawing

    private func drawScene(context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        // Pure black sky (no gradient, no stars — matching original)

        // === PERSPECTIVE FIELD ===
        // Low-angle endzone camera: field recedes from bottom-left to upper-right
        // The field is a trapezoid — wide at bottom (near), narrow at top (far)

        let fieldNearLeft = CGPoint(x: -w * 0.15, y: h)
        let fieldNearRight = CGPoint(x: w * 1.15, y: h)
        let fieldFarLeft = CGPoint(x: w * 0.10, y: h * 0.55)
        let fieldFarRight = CGPoint(x: w * 0.85, y: h * 0.55)

        // Base field color
        var fieldPath = Path()
        fieldPath.move(to: fieldNearLeft)
        fieldPath.addLine(to: fieldNearRight)
        fieldPath.addLine(to: fieldFarRight)
        fieldPath.addLine(to: fieldFarLeft)
        fieldPath.closeSubpath()
        context.fill(fieldPath, with: .color(Color(red: 0.10, green: 0.32, blue: 0.10)))

        // Grass stripes — alternating bands receding in perspective
        let stripeCount = 12
        for i in 0..<stripeCount {
            let t0 = CGFloat(i) / CGFloat(stripeCount)
            let t1 = CGFloat(i + 1) / CGFloat(stripeCount)

            // Interpolate left edge
            let leftBot0 = lerp(fieldNearLeft, fieldFarLeft, t0)
            let leftBot1 = lerp(fieldNearLeft, fieldFarLeft, t1)
            // Interpolate right edge
            let rightBot0 = lerp(fieldNearRight, fieldFarRight, t0)
            let rightBot1 = lerp(fieldNearRight, fieldFarRight, t1)

            if i % 2 == 0 {
                var stripe = Path()
                stripe.move(to: leftBot0)
                stripe.addLine(to: rightBot0)
                stripe.addLine(to: rightBot1)
                stripe.addLine(to: leftBot1)
                stripe.closeSubpath()
                context.fill(stripe, with: .color(Color(red: 0.13, green: 0.40, blue: 0.13)))
            }

            // Yard line (white line at each stripe boundary)
            var yardLine = Path()
            yardLine.move(to: leftBot0)
            yardLine.addLine(to: rightBot0)
            let lineOpacity = 0.25 + (1.0 - t0) * 0.25
            context.stroke(yardLine, with: .color(Color.white.opacity(lineOpacity)), lineWidth: 1)
        }

        // === STADIUM STRUCTURE — upper right ===
        // Dark silhouette with facade levels, matching the original's upper-right stadium mass
        let stadiumLeft = w * 0.52
        let stadiumRight = w
        let stadiumTop = h * 0.02
        let stadiumBottom = h * 0.55

        // Main stadium mass
        var stadiumPath = Path()
        stadiumPath.move(to: CGPoint(x: stadiumLeft, y: stadiumBottom))
        stadiumPath.addLine(to: CGPoint(x: stadiumLeft + (stadiumRight - stadiumLeft) * 0.05, y: stadiumBottom - 20))
        stadiumPath.addLine(to: CGPoint(x: stadiumLeft + (stadiumRight - stadiumLeft) * 0.15, y: stadiumTop + 60))
        stadiumPath.addLine(to: CGPoint(x: stadiumLeft + (stadiumRight - stadiumLeft) * 0.30, y: stadiumTop + 30))
        stadiumPath.addLine(to: CGPoint(x: stadiumLeft + (stadiumRight - stadiumLeft) * 0.50, y: stadiumTop + 10))
        stadiumPath.addLine(to: CGPoint(x: stadiumLeft + (stadiumRight - stadiumLeft) * 0.70, y: stadiumTop))
        stadiumPath.addLine(to: CGPoint(x: stadiumRight, y: stadiumTop))
        stadiumPath.addLine(to: CGPoint(x: stadiumRight, y: stadiumBottom))
        stadiumPath.closeSubpath()
        context.fill(stadiumPath, with: .color(Color(red: 0.08, green: 0.08, blue: 0.10)))

        // Stadium deck levels (horizontal lines suggesting tiers)
        let deckCount = 12
        for i in 1..<deckCount {
            let t = CGFloat(i) / CGFloat(deckCount)
            let deckY = stadiumBottom - t * (stadiumBottom - stadiumTop - 20)
            // Only draw within stadium silhouette bounds
            let leftX = stadiumLeft + (stadiumRight - stadiumLeft) * min(0.15, t * 0.3)
            var deckLine = Path()
            deckLine.move(to: CGPoint(x: leftX, y: deckY))
            deckLine.addLine(to: CGPoint(x: stadiumRight, y: deckY))
            context.stroke(deckLine, with: .color(Color(red: 0.12, green: 0.12, blue: 0.15)), lineWidth: 1)
        }

        // Stadium facade text "SPORTS" partially visible (like original frame 002)
        let facadeY = stadiumTop + 15
        let facadeX = w * 0.78
        context.draw(
            Text("SPORTS")
                .font(.custom("Menlo-Bold", size: 28))
                .foregroundColor(Color(red: 0.14, green: 0.14, blue: 0.17)),
            at: CGPoint(x: facadeX, y: facadeY)
        )

        // Stadium railing along the top edge
        var railPath = Path()
        railPath.move(to: CGPoint(x: stadiumLeft + (stadiumRight - stadiumLeft) * 0.15, y: stadiumTop + 58))
        railPath.addLine(to: CGPoint(x: stadiumRight, y: stadiumTop - 2))
        context.stroke(railPath, with: .color(Color(red: 0.18, green: 0.18, blue: 0.22)), lineWidth: 2)

        // === LIGHT TOWERS ===
        // Two towers in the background, center-left area (matching original placement)
        drawLightTower(context: context, baseX: w * 0.30, baseY: h * 0.55, topY: h * 0.12, w: w, h: h)
        drawLightTower(context: context, baseX: w * 0.46, baseY: h * 0.55, topY: h * 0.08, w: w, h: h)

        // === GOAL POST ===
        // Left-of-center, prominent, yellow — the hero element
        let postBaseX = w * 0.30
        let postBaseY = h * 0.72     // Base on the field
        let postTopY = h * 0.18      // Top of uprights
        let crossbarY = h * 0.32     // Crossbar height
        let uprightSpread: CGFloat = 50  // Half-width of crossbar

        let postColor = Color(red: 0.92, green: 0.82, blue: 0.20)
        let postShadow = Color(red: 0.70, green: 0.60, blue: 0.10)

        // Ground support (angled brace from base)
        var brace = Path()
        brace.move(to: CGPoint(x: postBaseX - 20, y: postBaseY + 10))
        brace.addLine(to: CGPoint(x: postBaseX, y: postBaseY - 20))
        brace.addLine(to: CGPoint(x: postBaseX + 4, y: postBaseY - 20))
        brace.addLine(to: CGPoint(x: postBaseX - 16, y: postBaseY + 10))
        brace.closeSubpath()
        context.fill(brace, with: .color(postColor))

        // Main vertical post
        let mainPostRect = CGRect(x: postBaseX - 3, y: crossbarY, width: 6, height: postBaseY - crossbarY)
        context.fill(Path(mainPostRect), with: .color(postColor))

        // Shadow side of main post
        let mainPostShadow = CGRect(x: postBaseX + 1, y: crossbarY, width: 2, height: postBaseY - crossbarY)
        context.fill(Path(mainPostShadow), with: .color(postShadow))

        // Crossbar
        let crossbarLeft = postBaseX - uprightSpread
        let crossbarRight = postBaseX + uprightSpread
        let crossbarRect = CGRect(x: crossbarLeft, y: crossbarY, width: crossbarRight - crossbarLeft, height: 5)
        context.fill(Path(crossbarRect), with: .color(postColor))
        // Crossbar shadow
        let crossShadow = CGRect(x: crossbarLeft, y: crossbarY + 3, width: crossbarRight - crossbarLeft, height: 2)
        context.fill(Path(crossShadow), with: .color(postShadow))

        // Left upright
        let leftUpright = CGRect(x: crossbarLeft - 2, y: postTopY, width: 4, height: crossbarY - postTopY)
        context.fill(Path(leftUpright), with: .color(postColor))

        // Right upright
        let rightUpright = CGRect(x: crossbarRight - 2, y: postTopY, width: 4, height: crossbarY - postTopY)
        context.fill(Path(rightUpright), with: .color(postColor))

        // Upright caps (small balls at top, like original)
        let capSize: CGFloat = 6
        context.fill(Path(ellipseIn: CGRect(x: crossbarLeft - capSize/2, y: postTopY - capSize/2, width: capSize, height: capSize)),
                     with: .color(postColor))
        context.fill(Path(ellipseIn: CGRect(x: crossbarRight - capSize/2, y: postTopY - capSize/2, width: capSize, height: capSize)),
                     with: .color(postColor))
    }

    // MARK: - Light Tower Drawing

    private func drawLightTower(context: GraphicsContext, baseX: CGFloat, baseY: CGFloat, topY: CGFloat, w: CGFloat, h: CGFloat) {
        let towerColor = Color(red: 0.12, green: 0.12, blue: 0.15)

        // Lattice tower structure — two angled legs converging at top
        let legSpreadBottom: CGFloat = 16
        let legSpreadTop: CGFloat = 4

        // Left leg
        var leftLeg = Path()
        leftLeg.move(to: CGPoint(x: baseX - legSpreadBottom, y: baseY))
        leftLeg.addLine(to: CGPoint(x: baseX - legSpreadTop, y: topY + 8))
        leftLeg.addLine(to: CGPoint(x: baseX - legSpreadTop + 3, y: topY + 8))
        leftLeg.addLine(to: CGPoint(x: baseX - legSpreadBottom + 3, y: baseY))
        leftLeg.closeSubpath()
        context.fill(leftLeg, with: .color(towerColor))

        // Right leg
        var rightLeg = Path()
        rightLeg.move(to: CGPoint(x: baseX + legSpreadBottom, y: baseY))
        rightLeg.addLine(to: CGPoint(x: baseX + legSpreadTop, y: topY + 8))
        rightLeg.addLine(to: CGPoint(x: baseX + legSpreadTop - 3, y: topY + 8))
        rightLeg.addLine(to: CGPoint(x: baseX + legSpreadBottom - 3, y: baseY))
        rightLeg.closeSubpath()
        context.fill(rightLeg, with: .color(towerColor))

        // Cross braces
        let braceCount = 5
        for i in 1..<braceCount {
            let t = CGFloat(i) / CGFloat(braceCount)
            let y = baseY - t * (baseY - topY - 8)
            let spread = legSpreadBottom - t * (legSpreadBottom - legSpreadTop)
            var brace = Path()
            brace.move(to: CGPoint(x: baseX - spread, y: y))
            brace.addLine(to: CGPoint(x: baseX + spread, y: y))
            context.stroke(brace, with: .color(towerColor), lineWidth: 1)
        }

        // Light bank — bright white rectangle at top
        let bankWidth: CGFloat = 28
        let bankHeight: CGFloat = 10
        let bankRect = CGRect(x: baseX - bankWidth/2, y: topY - 2, width: bankWidth, height: bankHeight)
        context.fill(Path(bankRect), with: .color(Color(red: 0.85, green: 0.85, blue: 0.85)))

        // Inner light panels (bright white)
        let innerRect = CGRect(x: baseX - bankWidth/2 + 2, y: topY, width: bankWidth - 4, height: bankHeight - 4)
        context.fill(Path(innerRect), with: .color(Color.white))

        // Light glow — large soft radial glow
        let glowSize: CGFloat = 60
        for r in stride(from: glowSize, through: 4, by: -4) {
            let alpha = 0.015 * (1.0 - r / glowSize)
            let glow = Path(ellipseIn: CGRect(x: baseX - r, y: topY - r * 0.6, width: r * 2, height: r * 1.2))
            context.fill(glow, with: .color(Color.white.opacity(alpha)))
        }
    }

    // MARK: - Utility

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    // MARK: - Animation

    private func animateSplash() {
        // Title fades in after brief pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 1.0)) {
                showTitle = true
            }
        }

        // Credits cycle through one at a time
        for i in 0..<credits.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0 + Double(i) * 1.8) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    creditIndex = i
                }
            }
        }

        // Fade out
        let totalCreditTime = 2.0 + Double(credits.count) * 1.8
        DispatchQueue.main.asyncAfter(deadline: .now() + totalCreditTime + 0.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                fadeOut = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + totalCreditTime + 1.0) {
            onComplete()
        }
    }
}

#Preview {
    SplashScreen(onComplete: {})
}
