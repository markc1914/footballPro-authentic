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

// MARK: - Mini Play Diagram Data (for play calling green slots)

/// Pre-computed diagram data for a single play, normalized to 0..1 for scaling.
struct MiniDiagramData: Identifiable {
    let id = UUID()
    let isOffensive: Bool
    let players: [MiniDiagramPlayer]

    struct MiniDiagramPlayer {
        let normalizedPosition: CGPoint  // 0..1 range
        let isSkillPosition: Bool        // WR/TE/RB/QB (circles) vs linemen (filled dots)
        let isQB: Bool
        let route: [CGPoint]?            // Normalized route waypoints (nil = no route)
        let hasRushAssignment: Bool       // Defensive rush toward LOS
        let isPrimaryTarget: Bool         // Primary receiver (highlighted route)
    }
}

// MARK: - Mini Play Diagram Cache

/// Caches computed mini diagram data keyed by play name.
final class MiniDiagramCache {
    static let shared = MiniDiagramCache()

    private var cache: [String: MiniDiagramData] = [:]
    private let stockDB: StockDatabase?

    private init() {
        stockDB = StockDATDecoder.shared
    }

    func diagram(forPlayName name: String, isOffensive: Bool) -> MiniDiagramData? {
        let cacheKey = "\(isOffensive ? "O" : "D"):\(name)"
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let db = stockDB else { return nil }

        // Try to find matching STOCK.DAT play
        let stockPlay: StockPlay?
        let upper = name.uppercased().replacingOccurrences(of: " ", with: "")
        if isOffensive {
            stockPlay = db.offensivePlays.first(where: {
                $0.name.uppercased().replacingOccurrences(of: " ", with: "") == upper
            }) ?? db.offensivePlays.first(where: {
                let su = $0.name.uppercased().replacingOccurrences(of: " ", with: "")
                return su.contains(upper) || upper.contains(su)
            })
        } else {
            stockPlay = db.defensivePlays.first(where: {
                $0.name.uppercased().replacingOccurrences(of: " ", with: "") == upper
            }) ?? db.defensivePlays.first(where: {
                let su = $0.name.uppercased().replacingOccurrences(of: " ", with: "")
                return su.contains(upper) || upper.contains(su)
            })
        }

        guard let play = stockPlay, !play.players.isEmpty else { return nil }

        let diagram = buildMiniDiagram(from: play, isOffensive: isOffensive)
        cache[cacheKey] = diagram
        return diagram
    }

    private func buildMiniDiagram(from play: StockPlay, isOffensive: Bool) -> MiniDiagramData {
        var positions: [(CGPoint, StockPlayerEntry)] = []
        for player in play.players {
            if let pos = player.preSnapPosition {
                positions.append((pos, player))
            }
        }

        guard !positions.isEmpty else {
            return MiniDiagramData(isOffensive: isOffensive, players: [])
        }

        // Collect all coords for bounds (pre-snap + routes)
        var allXs: [CGFloat] = []
        var allYs: [CGFloat] = []
        for (pos, player) in positions {
            allXs.append(pos.x)
            allYs.append(pos.y)
            if let post = player.postSnapPosition {
                allXs.append(post.x); allYs.append(post.y)
            }
            if let rp = player.routePhasePosition {
                allXs.append(rp.x); allYs.append(rp.y)
            }
            for wp in player.routeWaypoints {
                allXs.append(wp.x); allYs.append(wp.y)
            }
            if let zone = player.zoneTarget {
                allXs.append(zone.x); allYs.append(zone.y)
            }
        }

        let minX = allXs.min() ?? 0, maxX = allXs.max() ?? 1
        let minY = allYs.min() ?? 0, maxY = allYs.max() ?? 1
        let rangeX = max(maxX - minX, 1)
        let rangeY = max(maxY - minY, 1)
        let padX = rangeX * 0.08, padY = rangeY * 0.08
        let adjMinX = minX - padX, adjRangeX = rangeX + padX * 2
        let adjMinY = minY - padY, adjRangeY = rangeY + padY * 2

        // Find primary target
        let primaryIdx: Int? = play.players.firstIndex(where: {
            $0.assignments.contains(where: { $0.type == .passTarget })
        })

        func normalize(_ pt: CGPoint) -> CGPoint {
            CGPoint(
                x: (pt.x - adjMinX) / adjRangeX,
                y: (pt.y - adjMinY) / adjRangeY
            )
        }

        var diagramPlayers: [MiniDiagramData.MiniDiagramPlayer] = []

        for (idx, (pos, player)) in positions.enumerated() {
            let nPos = normalize(pos)

            var routePoints: [CGPoint]? = nil
            let hasRoute = player.postSnapPosition != nil ||
                           player.routePhasePosition != nil ||
                           !player.routeWaypoints.isEmpty

            if hasRoute {
                var route: [CGPoint] = [nPos]
                if let post = player.postSnapPosition { route.append(normalize(post)) }
                for wp in player.routeWaypoints { route.append(normalize(wp)) }
                if let rEnd = player.routePhasePosition { route.append(normalize(rEnd)) }
                if route.count > 1 { routePoints = route }
            }

            if !isOffensive && routePoints == nil, let zone = player.zoneTarget {
                routePoints = [nPos, normalize(zone)]
            }

            diagramPlayers.append(MiniDiagramData.MiniDiagramPlayer(
                normalizedPosition: nPos,
                isSkillPosition: player.isSkillPosition,
                isQB: player.positionCode == StockPositionType.QB.rawValue,
                route: routePoints,
                hasRushAssignment: player.hasRushAssignment,
                isPrimaryTarget: primaryIdx != nil && idx == primaryIdx
            ))
        }

        return MiniDiagramData(isOffensive: isOffensive, players: diagramPlayers)
    }
}

// MARK: - Mini Play Diagram View (for green slots)

/// Compact play diagram rendered inside a play calling green slot.
/// Offensive: O marks with route lines. Defensive: X marks with rush arrows.
struct MiniPlayDiagramView: View {
    let diagram: MiniDiagramData
    let isSelected: Bool

    var body: some View {
        Canvas { context, size in
            // Scale marker sizes relative to slot dimensions for consistent readability
            let scale = min(size.width, size.height) / 60.0
            let offenseColor: Color = isSelected ? .black : Color(red: 1.0, green: 1.0, blue: 1.0)
            let defenseColor: Color = isSelected ? .black : Color(red: 1.0, green: 0.55, blue: 0.55)
            let lineColor: Color = diagram.isOffensive ? offenseColor : defenseColor
            let primaryColor: Color = isSelected ? .black : VGA.digitalAmber
            let secondaryRouteColor: Color = isSelected ? .black.opacity(0.7) : Color(red: 0.85, green: 0.85, blue: 0.85)
            let dimColor: Color = isSelected ? .black.opacity(0.5) : .white.opacity(0.25)

            // Inset the drawing area to keep marks away from edges
            let insetX = size.width * 0.06
            let insetY = size.height * 0.06
            let drawW = size.width - insetX * 2
            let drawH = size.height - insetY * 2

            // Draw LOS as dashed horizontal line
            let losY = insetY + drawH * 0.45
            var losPath = Path()
            losPath.move(to: CGPoint(x: insetX, y: losY))
            losPath.addLine(to: CGPoint(x: insetX + drawW, y: losY))
            context.stroke(losPath, with: .color(dimColor),
                           style: StrokeStyle(lineWidth: max(1.0, 0.8 * scale), dash: [3, 2]))

            for player in diagram.players {
                // STOCK.DAT: X = lateral, Y = depth (negative = behind LOS)
                let px = insetX + player.normalizedPosition.x * drawW
                let py = insetY + (1.0 - player.normalizedPosition.y) * drawH

                // Draw route lines first (behind marks)
                if let route = player.route, route.count > 1 {
                    var routePath = Path()
                    let sx = insetX + route[0].x * drawW
                    let sy = insetY + (1.0 - route[0].y) * drawH
                    routePath.move(to: CGPoint(x: sx, y: sy))

                    for i in 1..<route.count {
                        let rx = insetX + route[i].x * drawW
                        let ry = insetY + (1.0 - route[i].y) * drawH
                        routePath.addLine(to: CGPoint(x: rx, y: ry))
                    }

                    let routeColor = player.isPrimaryTarget ? primaryColor : secondaryRouteColor
                    let lw: CGFloat = player.isPrimaryTarget ? max(2.0, 1.8 * scale) : max(1.2, 1.0 * scale)

                    if player.isPrimaryTarget {
                        // Primary route: solid, bright amber, thick
                        context.stroke(routePath, with: .color(routeColor), lineWidth: lw)
                    } else {
                        // Secondary routes: dashed
                        context.stroke(routePath, with: .color(routeColor),
                                       style: StrokeStyle(lineWidth: lw, dash: [3, 2]))
                    }

                    // Arrow at end of route
                    if route.count >= 2 {
                        let lastPt = route[route.count - 1]
                        let prevPt = route[route.count - 2]
                        let ex = insetX + lastPt.x * drawW
                        let ey = insetY + (1.0 - lastPt.y) * drawH
                        let bx = insetX + prevPt.x * drawW
                        let by = insetY + (1.0 - prevPt.y) * drawH

                        let angle = atan2(ey - by, ex - bx)
                        let aLen: CGFloat = max(5.0, 4.0 * scale)
                        let aAng: CGFloat = .pi / 5

                        var arrow = Path()
                        arrow.move(to: CGPoint(x: ex, y: ey))
                        arrow.addLine(to: CGPoint(
                            x: ex - aLen * cos(angle - aAng),
                            y: ey - aLen * sin(angle - aAng)
                        ))
                        arrow.move(to: CGPoint(x: ex, y: ey))
                        arrow.addLine(to: CGPoint(
                            x: ex - aLen * cos(angle + aAng),
                            y: ey - aLen * sin(angle + aAng)
                        ))
                        context.stroke(arrow, with: .color(routeColor), lineWidth: lw)
                    }
                }

                // Draw player mark — sized relative to slot
                let ms: CGFloat = max(4.0, 3.5 * scale)

                if diagram.isOffensive {
                    if player.isQB {
                        // QB: filled bright circle
                        let r = CGRect(x: px - ms, y: py - ms, width: ms * 2, height: ms * 2)
                        context.fill(Path(ellipseIn: r), with: .color(lineColor))
                    } else if player.isSkillPosition {
                        // Skill positions: open circle with thicker stroke
                        let r = CGRect(x: px - ms, y: py - ms, width: ms * 2, height: ms * 2)
                        context.stroke(Path(ellipseIn: r), with: .color(lineColor),
                                       lineWidth: max(1.5, 1.2 * scale))
                    } else {
                        // Linemen: filled square for visual distinction
                        let sq: CGFloat = max(3.0, 2.5 * scale)
                        let r = CGRect(x: px - sq, y: py - sq, width: sq * 2, height: sq * 2)
                        context.fill(Path(r), with: .color(lineColor))
                    }
                } else {
                    // Defense: X marks with thicker lines
                    var xPath = Path()
                    xPath.move(to: CGPoint(x: px - ms, y: py - ms))
                    xPath.addLine(to: CGPoint(x: px + ms, y: py + ms))
                    xPath.move(to: CGPoint(x: px + ms, y: py - ms))
                    xPath.addLine(to: CGPoint(x: px - ms, y: py + ms))
                    context.stroke(xPath, with: .color(lineColor),
                                   lineWidth: max(1.5, 1.2 * scale))
                }
            }
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
