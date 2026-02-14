//
//  PlayDiagramView.swift
//  footballPro
//
//  Draws play diagrams with chalk X's, O's, and route arrows
//  Chalkboard style — just like Front Page Sports Football Pro '93
//

import SwiftUI

struct PlayDiagramView: View {
    let playArt: PlayArt
    let showDetails: Bool

    private let diagramWidth: CGFloat = 400
    private let diagramHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 8) {
            if showDetails {
                // Play info header (chalk style)
                VStack(spacing: 2) {
                    Text(playArt.playName)
                        .font(RetroFont.header())
                        .foregroundColor(VGA.chalk)

                    Text(playArt.description)
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.chalkFaint)
                        .multilineTextAlignment(.center)

                    Text("EXP: \(playArt.expectedYards) YDS")
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.chalkYellow)
                }
                .padding(.top, 4)
            }

            // Diagram canvas — chalkboard rendering
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // Chalkboard background
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(VGA.chalkboardBg)
                )

                // Chalk dust grain effect (subtle)
                for _ in 0..<80 {
                    let x = CGFloat.random(in: 0...w)
                    let y = CGFloat.random(in: 0...h)
                    let dot = Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5))
                    context.fill(dot, with: .color(VGA.chalk.opacity(0.05)))
                }

                // Line of scrimmage (thick chalk line)
                let losPath = Path { p in
                    p.move(to: CGPoint(x: w / 2, y: 0))
                    p.addLine(to: CGPoint(x: w / 2, y: h))
                }
                context.stroke(losPath, with: .color(VGA.chalk.opacity(0.6)), lineWidth: 3)

                // "LOS" label
                let losLabel = Text("LOS")
                    .font(.system(size: 7, weight: .regular, design: .monospaced))
                    .foregroundColor(VGA.chalkFaint)
                context.draw(context.resolve(losLabel), at: CGPoint(x: w / 2 + 14, y: 10))

                // Draw offensive positions (O's as chalk circles)
                let positions = offensivePositions(in: size)
                for (_, point, label) in positions {
                    // Chalk circle (O)
                    let circleRect = CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)
                    context.stroke(
                        Circle().path(in: circleRect),
                        with: .color(VGA.chalk),
                        lineWidth: 2
                    )

                    // Position label below
                    let labelText = Text(label)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(VGA.chalk)
                    context.draw(context.resolve(labelText), at: CGPoint(x: point.x, y: point.y + 16))
                }

                // Draw routes
                for route in playArt.routes {
                    if route.route == .block || route.route == .runBlock || route.route == .passBlock {
                        continue
                    }

                    let startPoint = getPosition(for: route.position, in: size)
                    let endPoint = calculateRouteEndpoint(for: route, from: startPoint)

                    // Route path
                    var routePath = Path()
                    routePath.move(to: startPoint)

                    switch route.route {
                    case .post, .corner, .slant, .out:
                        let breakPoint = CGPoint(
                            x: startPoint.x + CGFloat(route.depth) * 2,
                            y: startPoint.y
                        )
                        routePath.addLine(to: breakPoint)
                        routePath.addLine(to: endPoint)

                    case .curl, .comeBack:
                        let deepPoint = CGPoint(
                            x: startPoint.x + CGFloat(route.depth) * 3,
                            y: startPoint.y
                        )
                        routePath.addLine(to: deepPoint)
                        routePath.addLine(to: endPoint)

                    default:
                        routePath.addLine(to: endPoint)
                    }

                    // Chalk-style dashed line
                    context.stroke(
                        routePath,
                        with: .color(VGA.chalkYellow),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )

                    // Arrowhead
                    let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
                    let arrowLen: CGFloat = 10
                    var arrowPath = Path()
                    arrowPath.move(to: endPoint)
                    arrowPath.addLine(to: CGPoint(
                        x: endPoint.x - arrowLen * cos(angle - .pi / 6),
                        y: endPoint.y - arrowLen * sin(angle - .pi / 6)
                    ))
                    arrowPath.move(to: endPoint)
                    arrowPath.addLine(to: CGPoint(
                        x: endPoint.x - arrowLen * cos(angle + .pi / 6),
                        y: endPoint.y - arrowLen * sin(angle + .pi / 6)
                    ))
                    context.stroke(arrowPath, with: .color(VGA.chalkYellow), lineWidth: 2)
                }
            }
            .frame(width: diagramWidth, height: diagramHeight)
            .dosPanel(.sunken)

            if showDetails {
                // Route legend (chalk style)
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(playArt.routes.filter { $0.route != .block && $0.route != .runBlock && $0.route != .passBlock }) { route in
                        HStack(spacing: 8) {
                            Text(route.position.rawValue)
                                .font(RetroFont.tiny())
                                .foregroundColor(VGA.chalkYellow)
                                .frame(width: 30, alignment: .leading)

                            Text("\u{25BA}")
                                .font(RetroFont.tiny())
                                .foregroundColor(VGA.chalk)

                            Text(route.route.rawValue)
                                .font(RetroFont.tiny())
                                .foregroundColor(VGA.chalk)
                        }
                    }
                }
                .padding(6)
                .background(VGA.chalkboardBg.opacity(0.8))
                .dosPanel(.sunken)
            }
        }
    }

    // MARK: - Offensive Formation Positions

    private func offensivePositions(in size: CGSize) -> [(PlayerPosition, CGPoint, String)] {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let losX = centerX - 5

        var positions: [(PlayerPosition, CGPoint, String)] = []

        // Offensive line
        positions.append((.leftTackle, CGPoint(x: losX, y: centerY - 50), "LT"))
        positions.append((.leftGuard, CGPoint(x: losX, y: centerY - 25), "LG"))
        positions.append((.center, CGPoint(x: losX, y: centerY), "C"))
        positions.append((.rightGuard, CGPoint(x: losX, y: centerY + 25), "RG"))
        positions.append((.rightTackle, CGPoint(x: losX, y: centerY + 50), "RT"))

        // Quarterback
        positions.append((.quarterback, CGPoint(x: losX - 30, y: centerY), "QB"))

        // Skill positions by formation
        switch playArt.formation {
        case .shotgun:
            positions.append((.runningBack, CGPoint(x: losX - 60, y: centerY), "RB"))
            positions.append((.wideReceiverLeft, CGPoint(x: losX, y: centerY - 120), "WR"))
            positions.append((.wideReceiverRight, CGPoint(x: losX, y: centerY + 120), "WR"))
            positions.append((.slotReceiver, CGPoint(x: losX - 5, y: centerY - 80), "WR"))
            positions.append((.tightEnd, CGPoint(x: losX, y: centerY + 75), "TE"))

        case .singleback:
            positions.append((.runningBack, CGPoint(x: losX - 40, y: centerY - 15), "RB"))
            positions.append((.fullback, CGPoint(x: losX - 50, y: centerY + 15), "FB"))
            positions.append((.wideReceiverLeft, CGPoint(x: losX, y: centerY - 120), "WR"))
            positions.append((.wideReceiverRight, CGPoint(x: losX, y: centerY + 120), "WR"))
            positions.append((.tightEnd, CGPoint(x: losX, y: centerY + 75), "TE"))

        case .iFormation:
            positions.append((.runningBack, CGPoint(x: losX - 50, y: centerY), "RB"))
            positions.append((.fullback, CGPoint(x: losX - 35, y: centerY), "FB"))
            positions.append((.wideReceiverLeft, CGPoint(x: losX, y: centerY - 120), "WR"))
            positions.append((.wideReceiverRight, CGPoint(x: losX, y: centerY + 120), "WR"))
            positions.append((.tightEnd, CGPoint(x: losX, y: centerY + 75), "TE"))

        default:
            positions.append((.runningBack, CGPoint(x: losX - 40, y: centerY), "RB"))
            positions.append((.wideReceiverLeft, CGPoint(x: losX, y: centerY - 120), "WR"))
            positions.append((.wideReceiverRight, CGPoint(x: losX, y: centerY + 120), "WR"))
        }

        return positions
    }

    // MARK: - Helpers

    private func getPosition(for position: PlayerPosition, in size: CGSize) -> CGPoint {
        offensivePositions(in: size).first { $0.0 == position }?.1 ?? CGPoint(x: diagramWidth / 2, y: diagramHeight / 2)
    }

    private func calculateRouteEndpoint(for route: PlayRoute, from start: CGPoint) -> CGPoint {
        let depthPixels = CGFloat(route.depth) * 3

        switch route.route {
        case .fly:
            return CGPoint(x: start.x + depthPixels, y: start.y)
        case .post:
            return CGPoint(x: start.x + depthPixels, y: start.y + depthPixels * 0.5)
        case .corner:
            return CGPoint(x: start.x + depthPixels, y: start.y - depthPixels * 0.5)
        case .slant:
            return CGPoint(x: start.x + depthPixels * 0.7, y: start.y + depthPixels * 0.5)
        case .out:
            return CGPoint(x: start.x + depthPixels * 0.8, y: start.y - depthPixels * 0.6)
        case .curl:
            return CGPoint(x: start.x + depthPixels * 0.5, y: start.y)
        case .drag:
            return CGPoint(x: start.x + depthPixels * 0.5, y: route.direction == .right ? start.y + 60 : start.y - 60)
        case .flat:
            return CGPoint(x: start.x + depthPixels * 0.3, y: route.direction == .left ? start.y - 40 : start.y + 40)
        case .wheel:
            return CGPoint(x: start.x + depthPixels, y: start.y - depthPixels * 0.8)
        case .swing:
            return CGPoint(x: start.x - depthPixels * 0.2, y: route.direction == .left ? start.y - 50 : start.y + 50)
        case .angle:
            return CGPoint(x: start.x + depthPixels, y: route.direction == .right ? start.y + 30 : start.y - 30)
        default:
            return CGPoint(x: start.x + depthPixels, y: start.y)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PlayDiagramView(
            playArt: PlayArtDatabase.shared.passingPlays[0],
            showDetails: true
        )

        PlayDiagramView(
            playArt: PlayArtDatabase.shared.runningPlays[0],
            showDetails: true
        )
    }
    .padding()
    .background(VGA.chalkboardBg)
}
