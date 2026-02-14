//
//  InteractiveFieldView.swift
//  footballPro
//
//  Interactive gameplay where you control the players
//

import SwiftUI
import GameController

// MARK: - Interactive Field View

struct InteractiveFieldView: View {
    @ObservedObject var viewModel: GameViewModel
    @StateObject private var gameController = InteractiveGameController()
    @State private var showPlaybook = true
    @State private var gamePhase: InteractiveGamePhase = .playCalling

    var body: some View {
        ZStack {
            // Field background
            FieldCanvas(gameController: gameController)

            // UI Overlays
            VStack {
                // Top bar - Score and game info
                GameInfoBar(viewModel: viewModel, gameController: gameController)

                Spacer()

                // Bottom controls
                if gamePhase == .playCalling {
                    PlaySelectionOverlay(
                        isOffense: viewModel.isUserPossession,
                        onPlaySelected: { play in
                            gameController.setPlay(play, isOffense: viewModel.isUserPossession)
                            showPlaybook = false
                            gamePhase = .presnap
                        }
                    )
                } else if gamePhase == .presnap {
                    PresnapControls(
                        onSnap: {
                            gameController.snapBall()
                            gamePhase = .playing
                        }
                    )
                } else if gamePhase == .playing {
                    PlayingControls(gameController: gameController)
                }
            }

            // Play result overlay
            if gamePhase == .playOver {
                PlayResultOverlay(
                    result: gameController.lastPlayResult,
                    onContinue: {
                        // Update view model and reset
                        if let result = gameController.lastPlayResult {
                            viewModel.playByPlay.insert(result, at: 0)
                            viewModel.lastPlayResult = result
                        }
                        gameController.reset()
                        gamePhase = .playCalling
                    }
                )
            }
        }
        .onAppear {
            setupGame()
        }
        .onReceive(gameController.$playEnded) { ended in
            if ended {
                gamePhase = .playOver
            }
        }
        .handleKeyboardInput()
        .focusable()
        .onKeyPress { press in
            gameController.handleKeyPress(press)
            return .handled
        }
    }

    private func setupGame() {
        guard let homeTeam = viewModel.homeTeam,
              let awayTeam = viewModel.awayTeam,
              let game = viewModel.game else { return }

        let offenseTeam = game.isHomeTeamPossession ? homeTeam : awayTeam
        let defenseTeam = game.isHomeTeamPossession ? awayTeam : homeTeam

        gameController.setupGame(
            offense: offenseTeam,
            defense: defenseTeam,
            lineOfScrimmage: game.fieldPosition.yardLine,
            yardsToGo: game.downAndDistance.yardsToGo,
            isUserOnOffense: viewModel.isUserPossession
        )
    }
}

// MARK: - Game Phase

enum InteractiveGamePhase {
    case playCalling
    case presnap
    case playing
    case playOver
}

// MARK: - Interactive Game Controller

@MainActor
class InteractiveGameController: ObservableObject {
    // Field dimensions (in points)
    let fieldWidth: CGFloat = 800
    let fieldHeight: CGFloat = 400

    // Game state
    @Published var players: [FieldPlayer] = []
    @Published var ballPosition: CGPoint = .zero
    @Published var lineOfScrimmage: CGFloat = 0
    @Published var firstDownLine: CGFloat = 0
    @Published var controlledPlayerIndex: Int = 0
    @Published var isBallSnapped = false
    @Published var playEnded = false
    @Published var lastPlayResult: PlayResult?

    // Teams
    var offenseTeam: Team?
    var defenseTeam: Team?
    var isUserOnOffense = true
    var selectedPlay: SelectedPlay?

    // Movement
    var moveDirection: CGPoint = .zero
    var isSprinting = false

    // Play tracking
    private var startYardLine: Int = 0
    private var currentYardLine: Int = 0
    private var yardsToGo: Int = 10

    // Timer for game loop
    private var gameTimer: Timer?

    func setupGame(offense: Team, defense: Team, lineOfScrimmage los: Int, yardsToGo ytg: Int, isUserOnOffense: Bool) {
        self.offenseTeam = offense
        self.defenseTeam = defense
        self.isUserOnOffense = isUserOnOffense
        self.startYardLine = los
        self.currentYardLine = los
        self.yardsToGo = ytg

        // Convert yard line to screen position
        let losX = CGFloat(los) / 100.0 * fieldWidth
        self.lineOfScrimmage = losX
        self.firstDownLine = CGFloat(min(100, los + ytg)) / 100.0 * fieldWidth

        setupPlayers()
    }

    private func setupPlayers() {
        players.removeAll()

        let losX = lineOfScrimmage

        // Create offensive players
        let offenseColor = offenseTeam?.colors.primaryColor ?? .blue
        let offensePositions: [(CGPoint, String, PlayerRole)] = [
            (CGPoint(x: losX - 30, y: fieldHeight / 2), "QB", .quarterback),
            (CGPoint(x: losX - 60, y: fieldHeight / 2), "HB", .runningBack),
            (CGPoint(x: losX - 50, y: fieldHeight / 2 - 20), "FB", .fullback),
            (CGPoint(x: losX - 5, y: fieldHeight / 2), "C", .lineman),
            (CGPoint(x: losX - 5, y: fieldHeight / 2 - 25), "LG", .lineman),
            (CGPoint(x: losX - 5, y: fieldHeight / 2 + 25), "RG", .lineman),
            (CGPoint(x: losX - 5, y: fieldHeight / 2 - 50), "LT", .lineman),
            (CGPoint(x: losX - 5, y: fieldHeight / 2 + 50), "RT", .lineman),
            (CGPoint(x: losX - 5, y: 40), "WR", .receiver),
            (CGPoint(x: losX - 5, y: fieldHeight - 40), "WR", .receiver),
            (CGPoint(x: losX - 5, y: fieldHeight / 2 + 70), "TE", .receiver),
        ]

        for (pos, label, role) in offensePositions {
            players.append(FieldPlayer(
                position: pos,
                label: label,
                color: offenseColor,
                isOffense: true,
                role: role
            ))
        }

        // Create defensive players
        let defenseColor = defenseTeam?.colors.primaryColor ?? .red
        let defensePositions: [(CGPoint, String, PlayerRole)] = [
            (CGPoint(x: losX + 10, y: fieldHeight / 2 - 40), "DE", .lineman),
            (CGPoint(x: losX + 10, y: fieldHeight / 2 - 15), "DT", .lineman),
            (CGPoint(x: losX + 10, y: fieldHeight / 2 + 15), "DT", .lineman),
            (CGPoint(x: losX + 10, y: fieldHeight / 2 + 40), "DE", .lineman),
            (CGPoint(x: losX + 40, y: fieldHeight / 2 - 30), "LB", .linebacker),
            (CGPoint(x: losX + 35, y: fieldHeight / 2), "LB", .linebacker),
            (CGPoint(x: losX + 40, y: fieldHeight / 2 + 30), "LB", .linebacker),
            (CGPoint(x: losX + 60, y: 50), "CB", .cornerback),
            (CGPoint(x: losX + 60, y: fieldHeight - 50), "CB", .cornerback),
            (CGPoint(x: losX + 100, y: fieldHeight / 2 - 60), "S", .safety),
            (CGPoint(x: losX + 100, y: fieldHeight / 2 + 60), "S", .safety),
        ]

        for (pos, label, role) in defensePositions {
            players.append(FieldPlayer(
                position: pos,
                label: label,
                color: defenseColor,
                isOffense: false,
                role: role
            ))
        }

        // Set ball position
        ballPosition = CGPoint(x: losX - 30, y: fieldHeight / 2)  // At QB

        // Set controlled player
        if isUserOnOffense {
            controlledPlayerIndex = 1  // Control HB by default on offense
        } else {
            controlledPlayerIndex = 15  // Control MLB by default on defense
        }
    }

    func setPlay(_ play: SelectedPlay, isOffense: Bool) {
        self.selectedPlay = play
    }

    func snapBall() {
        isBallSnapped = true
        playEnded = false

        // Start game loop
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateGame()
            }
        }

        // If on offense, QB has ball initially
        if isUserOnOffense {
            // Give ball to QB, then player can hand off or pass
            players[0].hasBall = true
        }

        // Start AI movement
        startAIMovement()
    }

    private func startAIMovement() {
        // AI receivers run routes
        if let play = selectedPlay, isUserOnOffense {
            // Move receivers based on play type
            for i in players.indices where players[i].isOffense && players[i].role == .receiver {
                let route = getRouteForPlay(play, playerIndex: i)
                players[i].targetPosition = route
                players[i].isRunningRoute = true
            }
        }

        // Defensive AI pursues
        if !isUserOnOffense {
            // Offense runs their play
            runOffensiveAI()
        }
    }

    private func getRouteForPlay(_ play: SelectedPlay, playerIndex: Int) -> CGPoint {
        let player = players[playerIndex]
        let baseX = player.position.x

        switch play {
        case .shortPass:
            return CGPoint(x: baseX + 80, y: player.position.y + CGFloat.random(in: -30...30))
        case .mediumPass:
            return CGPoint(x: baseX + 150, y: player.position.y + CGFloat.random(in: -50...50))
        case .deepPass:
            return CGPoint(x: baseX + 250, y: fieldHeight / 2 + CGFloat.random(in: -100...100))
        case .run:
            return player.position  // Blockers stay
        default:
            return player.position
        }
    }

    private func runOffensiveAI() {
        // Simple AI - run or pass
        let isRun = Bool.random()

        if isRun {
            // Hand off to RB
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.players[0].hasBall = false
                self.players[1].hasBall = true
                self.players[1].targetPosition = CGPoint(x: self.fieldWidth, y: self.players[1].position.y)
            }
        } else {
            // QB drops back and throws
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                // Find open receiver
                if let receiverIndex = self.players.indices.first(where: { self.players[$0].role == .receiver && self.players[$0].isOffense }) {
                    self.throwBall(to: receiverIndex)
                }
            }
        }
    }

    func updateGame() {
        guard isBallSnapped && !playEnded else { return }

        // Update controlled player position
        if controlledPlayerIndex < players.count {
            let speed: CGFloat = isSprinting ? 8.0 : 5.0
            players[controlledPlayerIndex].position.x += moveDirection.x * speed
            players[controlledPlayerIndex].position.y += moveDirection.y * speed

            // Keep in bounds
            players[controlledPlayerIndex].position.x = max(0, min(fieldWidth, players[controlledPlayerIndex].position.x))
            players[controlledPlayerIndex].position.y = max(0, min(fieldHeight, players[controlledPlayerIndex].position.y))

            // Update ball position if carrying
            if players[controlledPlayerIndex].hasBall {
                ballPosition = players[controlledPlayerIndex].position
            }
        }

        // Update AI players
        for i in players.indices {
            if i != controlledPlayerIndex {
                updateAIPlayer(index: i)
            }
        }

        // Check for tackles
        checkTackles()

        // Check for touchdown
        checkTouchdown()

        // Update current yard line
        currentYardLine = Int(ballPosition.x / fieldWidth * 100)
    }

    private func updateAIPlayer(index: Int) {
        let player = players[index]

        if player.isRunningRoute, let target = player.targetPosition {
            // Move towards target
            let dx = target.x - player.position.x
            let dy = target.y - player.position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance > 5 {
                let speed: CGFloat = 4.0
                players[index].position.x += dx / distance * speed
                players[index].position.y += dy / distance * speed
            } else {
                players[index].isRunningRoute = false
            }
        } else if !player.isOffense {
            // Defensive players pursue the ball
            let dx = ballPosition.x - player.position.x
            let dy = ballPosition.y - player.position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance > 10 {
                let speed: CGFloat = player.role == .safety ? 4.5 : 3.5
                players[index].position.x += dx / distance * speed
                players[index].position.y += dy / distance * speed
            }
        }

        // If player has ball and is AI, move towards end zone
        if player.hasBall && index != controlledPlayerIndex {
            if player.isOffense {
                players[index].position.x += 3.0
            } else {
                players[index].position.x -= 3.0
            }
            ballPosition = players[index].position
        }
    }

    private func checkTackles() {
        // Find ball carrier
        guard let carrierIndex = players.indices.first(where: { players[$0].hasBall }) else { return }
        let carrier = players[carrierIndex]

        // Check if any defender is close enough to tackle
        for i in players.indices {
            let player = players[i]
            if player.isOffense == carrier.isOffense { continue }  // Same team

            let dx = player.position.x - carrier.position.x
            let dy = player.position.y - carrier.position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < 20 {  // Tackle radius
                endPlay(tackledAt: carrier.position)
                return
            }
        }
    }

    private func checkTouchdown() {
        guard let carrierIndex = players.indices.first(where: { players[$0].hasBall }) else { return }
        let carrier = players[carrierIndex]

        if carrier.isOffense && carrier.position.x >= fieldWidth - 20 {
            // Touchdown!
            endPlay(touchdown: true)
        } else if !carrier.isOffense && carrier.position.x <= 20 {
            // Defensive touchdown!
            endPlay(touchdown: true)
        }
    }

    private func endPlay(tackledAt position: CGPoint? = nil, touchdown: Bool = false) {
        gameTimer?.invalidate()
        gameTimer = nil
        isBallSnapped = false

        let yardsGained = currentYardLine - startYardLine

        let description: String
        if touchdown {
            description = "TOUCHDOWN!"
            SoundManager.shared.playTouchdown()
        } else {
            description = yardsGained >= 0 ?
                "Tackled for a gain of \(yardsGained) yards" :
                "Tackled for a loss of \(abs(yardsGained)) yards"
            SoundManager.shared.play(.tackle)
        }

        lastPlayResult = PlayResult(
            playType: selectedPlay?.toPlayType() ?? .insideRun,
            description: description,
            yardsGained: yardsGained,
            timeElapsed: 6,
            quarter: 1,
            timeRemaining: 900,
            isFirstDown: yardsGained >= yardsToGo,
            isTouchdown: touchdown,
            isTurnover: false
        )

        playEnded = true
    }

    func reset() {
        playEnded = false
        isBallSnapped = false
        selectedPlay = nil
        moveDirection = .zero

        // Reset players
        for i in players.indices {
            players[i].hasBall = false
            players[i].isRunningRoute = false
            players[i].targetPosition = nil
        }

        // Re-setup if we have teams
        if let offense = offenseTeam, let defense = defenseTeam {
            setupGame(
                offense: offense,
                defense: defense,
                lineOfScrimmage: currentYardLine,
                yardsToGo: yardsToGo,
                isUserOnOffense: isUserOnOffense
            )
        }
    }

    // MARK: - Input Handling

    func handleKeyPress(_ press: KeyPress) {
        switch press.key {
        case .upArrow, .init("w"):
            moveDirection.y = press.phase == .down ? -1 : 0
        case .downArrow, .init("s"):
            moveDirection.y = press.phase == .down ? 1 : 0
        case .leftArrow, .init("a"):
            moveDirection.x = press.phase == .down ? -1 : 0
        case .rightArrow, .init("d"):
            moveDirection.x = press.phase == .down ? 1 : 0
        case .space:
            if press.phase == .down {
                if isBallSnapped {
                    // Action button - pass, juke, dive, etc.
                    performAction()
                }
            }
        case .init(Character(UnicodeScalar(16))):  // Shift
            isSprinting = press.phase == .down
        default:
            break
        }
    }

    func setMoveDirection(_ direction: CGPoint) {
        moveDirection = direction
    }

    func performAction() {
        guard controlledPlayerIndex < players.count else { return }
        let controlled = players[controlledPlayerIndex]

        if controlled.hasBall && isUserOnOffense {
            // Try to pass to nearest receiver
            if let receiverIndex = findOpenReceiver() {
                throwBall(to: receiverIndex)
            }
        } else if !controlled.hasBall && isUserOnOffense {
            // Switch to ball carrier
            if let carrierIndex = players.indices.first(where: { players[$0].hasBall }) {
                controlledPlayerIndex = carrierIndex
            }
        }
    }

    private func findOpenReceiver() -> Int? {
        // Find the most open receiver
        var bestReceiver: Int?
        var bestOpenness: CGFloat = 0

        for i in players.indices {
            let player = players[i]
            guard player.isOffense && player.role == .receiver else { continue }

            // Calculate how "open" the receiver is
            var minDefenderDistance: CGFloat = 1000

            for j in players.indices {
                let defender = players[j]
                guard !defender.isOffense else { continue }

                let dx = defender.position.x - player.position.x
                let dy = defender.position.y - player.position.y
                let distance = sqrt(dx * dx + dy * dy)
                minDefenderDistance = min(minDefenderDistance, distance)
            }

            if minDefenderDistance > bestOpenness {
                bestOpenness = minDefenderDistance
                bestReceiver = i
            }
        }

        return bestReceiver
    }

    private func throwBall(to receiverIndex: Int) {
        guard let qbIndex = players.indices.first(where: { players[$0].hasBall && players[$0].isOffense }) else { return }

        players[qbIndex].hasBall = false

        // Simulate ball flight
        let receiver = players[receiverIndex]
        let qb = players[qbIndex]

        // Check if pass is complete (based on distance and coverage)
        let dx = receiver.position.x - qb.position.x
        let dy = receiver.position.y - qb.position.y
        let distance = sqrt(dx * dx + dy * dy)

        // Find closest defender to receiver
        var closestDefenderDistance: CGFloat = 1000
        for player in players where !player.isOffense {
            let defDx = player.position.x - receiver.position.x
            let defDy = player.position.y - receiver.position.y
            let defDistance = sqrt(defDx * defDx + defDy * defDy)
            closestDefenderDistance = min(closestDefenderDistance, defDistance)
        }

        // Completion probability based on coverage
        let completionChance = min(0.9, closestDefenderDistance / 50.0)
        let isComplete = Double.random(in: 0...1) < completionChance

        // Animate ball to receiver position
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(distance / 300)) { [weak self] in
            guard let self = self else { return }

            if isComplete {
                self.players[receiverIndex].hasBall = true
                self.ballPosition = self.players[receiverIndex].position
                self.controlledPlayerIndex = receiverIndex
                SoundManager.shared.play(.catch_sound)
            } else {
                // Incomplete
                SoundManager.shared.play(.incomplete)
                self.endPlay(tackledAt: nil)
            }
        }
    }
}

// MARK: - Field Player

struct FieldPlayer: Identifiable {
    let id = UUID()
    var position: CGPoint
    var label: String
    var color: Color
    var isOffense: Bool
    var role: PlayerRole
    var hasBall: Bool = false
    var isRunningRoute: Bool = false
    var targetPosition: CGPoint?
}

// MARK: - Selected Play

enum SelectedPlay {
    case run
    case shortPass
    case mediumPass
    case deepPass
    case screen
    case playAction

    // Defense
    case coverTwo
    case coverThree
    case manCoverage
    case blitz

    func toPlayType() -> PlayType {
        switch self {
        case .run: return .insideRun
        case .shortPass: return .shortPass
        case .mediumPass: return .mediumPass
        case .deepPass: return .deepPass
        case .screen: return .screen
        case .playAction: return .playAction
        case .coverTwo: return .coverTwo
        case .coverThree: return .coverThree
        case .manCoverage: return .manCoverage
        case .blitz: return .blitz
        }
    }
}

// MARK: - Field Canvas

struct FieldCanvas: View {
    @ObservedObject var gameController: InteractiveGameController

    var body: some View {
        Canvas { context, size in
            let fieldWidth = gameController.fieldWidth
            let fieldHeight = gameController.fieldHeight

            // Scale to fit
            let scaleX = size.width / fieldWidth
            let scaleY = size.height / fieldHeight
            let scale = min(scaleX, scaleY)

            let offsetX = (size.width - fieldWidth * scale) / 2
            let offsetY = (size.height - fieldHeight * scale) / 2

            // Draw field background
            let fieldRect = CGRect(x: offsetX, y: offsetY, width: fieldWidth * scale, height: fieldHeight * scale)
            context.fill(Path(fieldRect), with: .color(Color(red: 0.1, green: 0.4, blue: 0.1)))

            // Draw yard lines
            for yard in stride(from: 0, through: 100, by: 10) {
                let x = offsetX + CGFloat(yard) / 100.0 * fieldWidth * scale
                var path = Path()
                path.move(to: CGPoint(x: x, y: offsetY))
                path.addLine(to: CGPoint(x: x, y: offsetY + fieldHeight * scale))
                context.stroke(path, with: .color(.white.opacity(0.3)), lineWidth: 1)
            }

            // Draw end zones
            let leftEndZone = CGRect(x: offsetX, y: offsetY, width: 20 * scale, height: fieldHeight * scale)
            context.fill(Path(leftEndZone), with: .color(.blue.opacity(0.4)))

            let rightEndZone = CGRect(x: offsetX + (fieldWidth - 20) * scale, y: offsetY, width: 20 * scale, height: fieldHeight * scale)
            context.fill(Path(rightEndZone), with: .color(.orange.opacity(0.4)))

            // Draw line of scrimmage
            let losX = offsetX + gameController.lineOfScrimmage * scale
            var losPath = Path()
            losPath.move(to: CGPoint(x: losX, y: offsetY))
            losPath.addLine(to: CGPoint(x: losX, y: offsetY + fieldHeight * scale))
            context.stroke(losPath, with: .color(.blue), lineWidth: 3)

            // Draw first down line
            let fdX = offsetX + gameController.firstDownLine * scale
            var fdPath = Path()
            fdPath.move(to: CGPoint(x: fdX, y: offsetY))
            fdPath.addLine(to: CGPoint(x: fdX, y: offsetY + fieldHeight * scale))
            context.stroke(fdPath, with: .color(.yellow), lineWidth: 3)

            // Draw players
            for (index, player) in gameController.players.enumerated() {
                let playerX = offsetX + player.position.x * scale
                let playerY = offsetY + player.position.y * scale
                let playerSize: CGFloat = 24 * scale

                let isControlled = index == gameController.controlledPlayerIndex

                // Player circle
                let playerRect = CGRect(
                    x: playerX - playerSize / 2,
                    y: playerY - playerSize / 2,
                    width: playerSize,
                    height: playerSize
                )

                // Draw glow for controlled player
                if isControlled {
                    let glowRect = playerRect.insetBy(dx: -4, dy: -4)
                    context.fill(Path(ellipseIn: glowRect), with: .color(.yellow.opacity(0.5)))
                }

                context.fill(Path(ellipseIn: playerRect), with: .color(player.color))

                // Player outline
                if player.isOffense {
                    context.stroke(Path(ellipseIn: playerRect), with: .color(.white), lineWidth: 2)
                } else {
                    // X for defense
                    var xPath = Path()
                    xPath.move(to: CGPoint(x: playerX - 6, y: playerY - 6))
                    xPath.addLine(to: CGPoint(x: playerX + 6, y: playerY + 6))
                    xPath.move(to: CGPoint(x: playerX + 6, y: playerY - 6))
                    xPath.addLine(to: CGPoint(x: playerX - 6, y: playerY + 6))
                    context.stroke(xPath, with: .color(.white), lineWidth: 2)
                }

                // Ball indicator
                if player.hasBall {
                    let ballRect = CGRect(x: playerX - 4, y: playerY - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: ballRect), with: .color(.brown))
                }
            }
        }
        .background(Color.black)
    }
}

// MARK: - UI Components

struct GameInfoBar: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var gameController: InteractiveGameController

    var body: some View {
        HStack {
            // Away team
            Text(viewModel.awayTeam?.abbreviation ?? "AWY")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("\(viewModel.game?.score.awayScore ?? 0)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Spacer()

            // Game info
            VStack {
                Text(viewModel.game?.clock.quarterDisplay ?? "1st")
                    .font(.system(size: 14, design: .monospaced))
                Text(viewModel.game?.clock.displayTime ?? "15:00")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.orange)

            Spacer()

            // Home team
            Text("\(viewModel.game?.score.homeScore ?? 0)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text(viewModel.homeTeam?.abbreviation ?? "HME")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
}

struct PlaySelectionOverlay: View {
    let isOffense: Bool
    let onPlaySelected: (SelectedPlay) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(isOffense ? "SELECT OFFENSIVE PLAY" : "SELECT DEFENSIVE PLAY")
                .font(.headline)
                .foregroundColor(.orange)

            if isOffense {
                HStack(spacing: 12) {
                    PlayButton(title: "RUN", subtitle: "HB Dive") { onPlaySelected(.run) }
                    PlayButton(title: "SHORT", subtitle: "Slant") { onPlaySelected(.shortPass) }
                    PlayButton(title: "MEDIUM", subtitle: "Out Route") { onPlaySelected(.mediumPass) }
                    PlayButton(title: "DEEP", subtitle: "Go Route") { onPlaySelected(.deepPass) }
                }
            } else {
                HStack(spacing: 12) {
                    PlayButton(title: "COVER 2", subtitle: "Zone") { onPlaySelected(.coverTwo) }
                    PlayButton(title: "COVER 3", subtitle: "Zone") { onPlaySelected(.coverThree) }
                    PlayButton(title: "MAN", subtitle: "Coverage") { onPlaySelected(.manCoverage) }
                    PlayButton(title: "BLITZ", subtitle: "Pressure") { onPlaySelected(.blitz) }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
    }
}

struct PlayButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.yellow)
                Text(subtitle)
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.darkGray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VGA.panelVeryDark)
            .dosPanel(.raised)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PresnapControls: View {
    let onSnap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Press SPACE or click to SNAP")
                .font(.headline)
                .foregroundColor(.white)

            Button("SNAP BALL") {
                onSnap()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
    }
}

struct PlayingControls: View {
    @ObservedObject var gameController: InteractiveGameController

    var body: some View {
        HStack(spacing: 20) {
            // Virtual D-pad for touch/mouse control
            VStack {
                Button("▲") { gameController.setMoveDirection(CGPoint(x: 0, y: -1)) }
                HStack {
                    Button("◀") { gameController.setMoveDirection(CGPoint(x: -1, y: 0)) }
                    Button("■") { gameController.setMoveDirection(.zero) }
                    Button("▶") { gameController.setMoveDirection(CGPoint(x: 1, y: 0)) }
                }
                Button("▼") { gameController.setMoveDirection(CGPoint(x: 0, y: 1)) }
            }
            .font(.title)
            .buttonStyle(.plain)
            .foregroundColor(.white)

            VStack(spacing: 8) {
                Text("WASD/Arrows: Move")
                Text("SPACE: Pass/Action")
                Text("SHIFT: Sprint")
            }
            .font(.caption)
            .foregroundColor(.gray)

            Button("PASS/ACTION") {
                gameController.performAction()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(8)
    }
}

struct PlayResultOverlay: View {
    let result: PlayResult?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if let result = result {
                if result.isTouchdown {
                    Text("TOUCHDOWN!")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.green)
                }

                Text(result.description)
                    .font(.title2)
                    .foregroundColor(.white)

                if result.isFirstDown && !result.isTouchdown {
                    Text("FIRST DOWN!")
                        .font(.title3)
                        .foregroundColor(.yellow)
                }

                Text("\(result.yardsGained >= 0 ? "+" : "")\(result.yardsGained) yards")
                    .font(.headline)
                    .foregroundColor(result.yardsGained >= 0 ? .green : .red)
            }

            Button("CONTINUE") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(40)
        .background(Color.black.opacity(0.9))
        .cornerRadius(16)
    }
}

#Preview {
    InteractiveFieldView(viewModel: GameViewModel())
}
