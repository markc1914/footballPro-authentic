//
//  RetroFieldView.swift
//  footballPro
//
//  Classic Football Pro '95 style 2D top-down field view
//  Shows X's and O's formations with animated play execution
//

import SwiftUI

// MARK: - Retro Field View (Football Pro '95 Style)

struct RetroFieldView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var offensePlayers: [PlayerMarker] = []
    @State private var defensePlayers: [PlayerMarker] = []
    @State private var ballPosition: CGPoint = .zero
    @State private var isAnimating = false
    @State private var showPlayLine = false
    @State private var playLineEnd: CGPoint = .zero

    // Field dimensions in view coordinates
    let fieldWidth: CGFloat = 400
    let fieldHeight: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            // Field header
            HStack {
                Text(viewModel.awayTeam?.abbreviation ?? "AWY")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.awayTeam?.colors.primaryColor ?? .blue)

                Spacer()

                Text("FIELD VIEW")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)

                Spacer()

                Text(viewModel.homeTeam?.abbreviation ?? "HME")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(viewModel.homeTeam?.colors.primaryColor ?? .red)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black)

            // The field
            ZStack {
                // Field background
                RetroFieldBackground(fieldWidth: fieldWidth, fieldHeight: fieldHeight)

                // Line of scrimmage
                LineOfScrimmage(yardLine: viewModel.game?.fieldPosition.yardLine ?? 25, fieldWidth: fieldWidth)

                // First down marker
                if let game = viewModel.game {
                    FirstDownMarker(
                        yardLine: game.fieldPosition.yardLine + game.downAndDistance.yardsToGo,
                        fieldWidth: fieldWidth
                    )
                }

                // Play line (shows trajectory during animation)
                if showPlayLine {
                    PlayTrajectoryLine(start: ballPosition, end: playLineEnd)
                }

                // Offensive players (O's)
                ForEach(offensePlayers) { player in
                    PlayerMarkerView(marker: player, isOffense: true)
                }

                // Defensive players (X's)
                ForEach(defensePlayers) { player in
                    PlayerMarkerView(marker: player, isOffense: false)
                }

                // Football
                FootballMarker(position: ballPosition)
            }
            .frame(width: fieldWidth, height: fieldHeight)
            .background(Color(red: 0.1, green: 0.3, blue: 0.1))
            .border(Color.white, width: 2)
            .clipShape(Rectangle())

            // Down and distance display (retro style)
            RetroDownDisplay(game: viewModel.game)
        }
        .background(Color.black)
        .onAppear {
            setupFormations()
        }
        .onChange(of: viewModel.game?.fieldPosition.yardLine) { _, _ in
            setupFormations()
        }
        .onChange(of: viewModel.lastPlayResult) { _, result in
            if let result = result {
                animatePlay(result: result)
            }
        }
    }

    // MARK: - Setup Formations

    private func setupFormations() {
        guard let game = viewModel.game else { return }

        let los = Double(game.fieldPosition.yardLine)
        let yardToX: (Int) -> CGFloat = { yard in
            CGFloat(yard) / 100.0 * fieldWidth
        }

        // Reset ball position
        ballPosition = CGPoint(x: yardToX(game.fieldPosition.yardLine), y: fieldHeight / 2)

        // Get formation based on last play call (or default to I-Formation)
        let offFormation: OffensiveFormation = viewModel.selectedOffensivePlay?.formation ?? .iFormation
        let defFormation: DefensiveFormation = viewModel.selectedDefensivePlay?.formation ?? .base43

        // Use physics engine to get realistic formation positions
        let offPositions = FieldPhysics.getFormationPositions(
            formation: offFormation,
            lineOfScrimmage: los,
            fieldWidth: Double(fieldWidth),
            fieldHeight: Double(fieldHeight)
        )

        let defPositions = FieldPhysics.getDefensiveFormationPositions(
            formation: defFormation,
            lineOfScrimmage: los,
            fieldWidth: Double(fieldWidth),
            fieldHeight: Double(fieldHeight)
        )

        // Convert to PlayerMarkers
        offensePlayers = offPositions.enumerated().map { index, pos in
            PlayerMarker(id: index, position: pos.position, label: pos.label)
        }

        defensePlayers = defPositions.enumerated().map { index, pos in
            PlayerMarker(id: index, position: pos.position, label: pos.label)
        }
    }

    // MARK: - Animate Play

    private func animatePlay(result: PlayResult) {
        guard !isAnimating else { return }
        isAnimating = true

        let yards = result.yardsGained
        let isPass = result.playType.isPass
        let isRun = result.playType.isRun

        // Calculate movement
        let movement = CGFloat(yards) / 100.0 * fieldWidth

        if isPass {
            animatePassPlay(yards: yards, movement: movement, result: result)
        } else if isRun {
            animateRunPlay(yards: yards, movement: movement, result: result)
        } else {
            isAnimating = false
        }
    }

    private func animateRunPlay(yards: Int, movement: CGFloat, result: PlayResult) {
        // HB runs with ball
        guard offensePlayers.count > 2 else {
            isAnimating = false
            return
        }

        let hbIndex = 2  // Running back
        let hbStart = offensePlayers[hbIndex].position
        let targetX = hbStart.x + movement
        let targetPos = CGPoint(x: targetX, y: hbStart.y)

        // Show play line
        showPlayLine = true
        playLineEnd = targetPos

        // HB accelerates realistically (0.8 second to full speed)
        // Use easeIn for acceleration at start, easeOut for deceleration at tackle
        let runDuration: Double
        if yards > 0 {
            runDuration = 0.7 + Double(abs(yards)) * 0.02  // Longer runs take longer
        } else {
            runDuration = 0.3  // Stuffed plays are quick
        }

        // Animate HB with realistic acceleration curve
        withAnimation(.timingCurve(0.2, 0.0, 0.4, 1.0, duration: runDuration)) {
            offensePlayers[hbIndex].position = targetPos
            ballPosition = targetPos
        }

        // Blockers push forward (faster than HB at first, then slow)
        withAnimation(.easeOut(duration: 0.5)) {
            for i in 3...7 {
                if i < offensePlayers.count {
                    offensePlayers[i].position.x += movement * 0.25
                }
            }
        }

        // Defenders pursue with different speeds based on position
        for i in defensePlayers.indices {
            let defender = defensePlayers[i]
            let distanceToPlay = abs(defender.position.x - hbStart.x)

            // Closer defenders reach ball carrier faster
            let pursuitDelay = min(0.3, Double(distanceToPlay) / 200.0)
            let pursuitSpeed = movement * (0.4 + Double.random(in: 0...0.3))

            withAnimation(.easeIn(duration: 0.6).delay(pursuitDelay)) {
                defensePlayers[i].position.x += pursuitSpeed

                // Check for collision/tackle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + pursuitDelay) {
                    if FieldPhysics.checkCollision(
                        player1: defensePlayers[i].position,
                        player2: targetPos,
                        radius: 12.0
                    ) {
                        // Tackle animation - defender hits ball carrier
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            defensePlayers[i].position.x = targetPos.x - 8
                        }
                    }
                }
            }
        }

        // Play sound and complete (after run duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + runDuration + 0.1) {
            SoundManager.shared.play(.tackle)

            // Brief pause to show tackle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showPlayLine = false
                isAnimating = false
            }
        }
    }

    private func animatePassPlay(yards: Int, movement: CGFloat, result: PlayResult) {
        guard offensePlayers.count > 9 else {
            isAnimating = false
            return
        }

        let qbIndex = 0
        let receiverIndex = 8  // WR

        let targetX = offensePlayers[receiverIndex].position.x + movement
        let targetY = offensePlayers[receiverIndex].position.y

        // Receiver runs route with acceleration
        withAnimation(.easeInOut(duration: 0.5)) {
            offensePlayers[receiverIndex].position.x = targetX
        }

        // QB drops back
        withAnimation(.easeIn(duration: 0.25)) {
            offensePlayers[qbIndex].position.x -= 15
        }

        // After QB sets, throw ball with REALISTIC ARC
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let qbPos = offensePlayers[qbIndex].position
            let receiverPos = CGPoint(x: targetX, y: targetY)

            // Calculate parabolic arc using physics
            let isDeep = abs(yards) > 15
            let passArc = FieldPhysics.calculatePassArc(
                from: qbPos,
                to: receiverPos,
                power: 85.0,  // QB throw power
                accuracy: 80.0,  // QB accuracy
                isDeep: isDeep
            )

            // Animate ball along the arc using keyframe animation
            animateBallAlongArc(passArc, duration: isDeep ? 1.0 : 0.6, isComplete: yards > 0)
        }

        // Defenders react to pass
        withAnimation(.easeInOut(duration: 0.7)) {
            for i in defensePlayers.indices {
                // DBs follow receivers
                if defensePlayers[i].label.contains("CB") || defensePlayers[i].label.contains("S") {
                    defensePlayers[i].position.x += movement * 0.6
                } else {
                    // Rush the passer
                    defensePlayers[i].position.x += movement * 0.2
                }
            }
        }
    }

    // Animate ball along parabolic arc
    private func animateBallAlongArc(_ arc: [CGPoint], duration: Double, isComplete: Bool) {
        guard !arc.isEmpty else {
            isAnimating = false
            return
        }

        showPlayLine = true
        playLineEnd = arc.last!

        // Animate ball through each point in the arc
        var currentIndex = 0
        let stepDuration = duration / Double(arc.count)

        func animateNextPoint() {
            guard currentIndex < arc.count else {
                // Animation complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if isComplete {
                        SoundManager.shared.play(.catch_sound)
                    } else {
                        SoundManager.shared.play(.incomplete)
                    }

                    showPlayLine = false
                    isAnimating = false
                }
                return
            }

            withAnimation(.linear(duration: stepDuration)) {
                ballPosition = arc[currentIndex]
            }

            currentIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) {
                animateNextPoint()
            }
        }

        animateNextPoint()
    }
}

// MARK: - Player Marker Model

struct PlayerMarker: Identifiable {
    let id: Int
    var position: CGPoint
    var label: String
}

// MARK: - Player Marker View

struct PlayerMarkerView: View {
    let marker: PlayerMarker
    let isOffense: Bool

    var body: some View {
        ZStack {
            // Player symbol (O for offense, X for defense)
            Text(isOffense ? "O" : "X")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(isOffense ? .yellow : .red)

            // Position label
            Text(marker.label)
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .offset(y: 10)
        }
        .position(marker.position)
    }
}

// MARK: - Football Marker

struct FootballMarker: View {
    let position: CGPoint

    var body: some View {
        Text("●")
            .font(.system(size: 10))
            .foregroundColor(.brown)
            .shadow(color: .black, radius: 1)
            .position(position)
    }
}

// MARK: - Retro Field Background

struct RetroFieldBackground: View {
    let fieldWidth: CGFloat
    let fieldHeight: CGFloat

    var body: some View {
        ZStack {
            // Field color
            Rectangle()
                .fill(Color(red: 0.1, green: 0.35, blue: 0.1))

            // Yard lines (every 10 yards)
            ForEach(0..<11, id: \.self) { i in
                let x = CGFloat(i) / 10.0 * fieldWidth
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: fieldHeight))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
            }

            // Hash marks
            ForEach(0..<100, id: \.self) { yard in
                let x = CGFloat(yard) / 100.0 * fieldWidth
                Path { path in
                    path.move(to: CGPoint(x: x, y: fieldHeight * 0.33))
                    path.addLine(to: CGPoint(x: x, y: fieldHeight * 0.33 + 3))
                    path.move(to: CGPoint(x: x, y: fieldHeight * 0.67))
                    path.addLine(to: CGPoint(x: x, y: fieldHeight * 0.67 - 3))
                }
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            }

            // End zones
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: fieldWidth * 0.1)
                .position(x: fieldWidth * 0.05, y: fieldHeight / 2)

            Rectangle()
                .fill(Color.orange.opacity(0.3))
                .frame(width: fieldWidth * 0.1)
                .position(x: fieldWidth * 0.95, y: fieldHeight / 2)

            // Yard numbers
            ForEach([10, 20, 30, 40, 50, 40, 30, 20, 10], id: \.self) { yard in
                let index = [10, 20, 30, 40, 50, 40, 30, 20, 10].firstIndex(of: yard)!
                let x = CGFloat(index + 1) / 10.0 * fieldWidth
                Text("\(yard)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .position(x: x, y: 10)
            }
        }
    }
}

// MARK: - Line of Scrimmage

struct LineOfScrimmage: View {
    let yardLine: Int
    let fieldWidth: CGFloat

    var body: some View {
        let x = CGFloat(yardLine) / 100.0 * fieldWidth
        Path { path in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: 500))
        }
        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
    }
}

// MARK: - First Down Marker

struct FirstDownMarker: View {
    let yardLine: Int
    let fieldWidth: CGFloat

    var body: some View {
        let x = CGFloat(min(100, yardLine)) / 100.0 * fieldWidth
        Path { path in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: 500))
        }
        .stroke(Color.yellow, lineWidth: 2)
    }
}

// MARK: - Play Trajectory Line

struct PlayTrajectoryLine: View {
    let start: CGPoint
    let end: CGPoint

    var body: some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
    }
}

// MARK: - Retro Down Display

struct RetroDownDisplay: View {
    let game: Game?

    var body: some View {
        HStack(spacing: 20) {
            // Down
            VStack(spacing: 2) {
                Text("DOWN")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray)
                Text(game?.downAndDistance.down.description ?? "1")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }

            // Yards to go
            VStack(spacing: 2) {
                Text("TO GO")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray)
                Text("\(game?.downAndDistance.yardsToGo ?? 10)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }

            // Ball on
            VStack(spacing: 2) {
                Text("BALL ON")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray)
                Text(game?.fieldPosition.displayYardLine ?? "25")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }

            // Quarter/Time
            VStack(spacing: 2) {
                Text("QTR")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray)
                Text(game?.clock.quarterDisplay ?? "1st")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.black)
    }
}

#Preview {
    RetroFieldView(viewModel: GameViewModel())
        .frame(width: 420, height: 280)
}
