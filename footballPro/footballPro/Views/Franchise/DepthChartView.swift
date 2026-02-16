//
//  DepthChartView.swift
//  footballPro
//
//  Depth chart management screen — reorder starters/backups by position
//  DOS/VGA aesthetic matching FPS Football Pro '93
//

import SwiftUI

struct DepthChartView: View {
    @EnvironmentObject var gameState: GameState

    // MARK: - Position Groups

    private static let offensePositions: [Position] = [
        .quarterback, .runningBack, .fullback, .wideReceiver, .tightEnd,
        .leftTackle, .leftGuard, .center, .rightGuard, .rightTackle
    ]

    private static let defensePositions: [Position] = [
        .defensiveEnd, .defensiveTackle, .outsideLinebacker, .middleLinebacker,
        .cornerback, .freeSafety, .strongSafety
    ]

    private static let specialPositions: [Position] = [
        .kicker, .punter
    ]

    private enum PositionGroup: String, CaseIterable {
        case offense = "OFFENSE"
        case defense = "DEFENSE"
        case special = "SPECIAL TEAMS"

        var positions: [Position] {
            switch self {
            case .offense: return DepthChartView.offensePositions
            case .defense: return DepthChartView.defensePositions
            case .special: return DepthChartView.specialPositions
            }
        }
    }

    // MARK: - State

    @State private var selectedPosition: Position = .quarterback
    @State private var selectedPlayerId: UUID? = nil
    @State private var showAutoLineupConfirm = false

    // MARK: - Computed

    private var team: Team? {
        gameState.userTeam
    }

    private func orderedPlayers(at position: Position) -> [Player] {
        guard let team = team else { return [] }
        let depthOrder = team.depthChart.positions[position] ?? []
        let positionPlayers = team.players(at: position)

        // Players in depth chart order first, then any unassigned players
        var ordered: [Player] = []
        for playerId in depthOrder {
            if let player = positionPlayers.first(where: { $0.id == playerId }) {
                ordered.append(player)
            }
        }
        // Add any players not yet in depth chart
        for player in positionPlayers {
            if !ordered.contains(where: { $0.id == player.id }) {
                ordered.append(player)
            }
        }
        return ordered
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
            DOSSeparator()

            HStack(spacing: 0) {
                // Left sidebar — position list
                positionSidebar
                    .frame(width: 200)

                // Vertical separator
                VStack(spacing: 0) {
                    Rectangle().fill(VGA.shadowInner).frame(width: 1)
                }

                // Right panel — players at selected position
                playerPanel
            }
        }
        .background(VGA.screenBg)
        .sheet(isPresented: $showAutoLineupConfirm) {
            autoLineupDialog
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            FPSButton("< BACK") {
                gameState.navigateTo(.management)
            }

            Spacer()

            Text("DEPTH CHART")
                .font(RetroFont.title())
                .foregroundColor(VGA.digitalAmber)

            Spacer()

            FPSButton("AUTO-LINEUP") {
                showAutoLineupConfirm = true
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelDark)
    }

    // MARK: - Position Sidebar

    private var positionSidebar: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(PositionGroup.allCases, id: \.self) { group in
                    // Group header
                    HStack {
                        Text(group.rawValue)
                            .font(RetroFont.small())
                            .foregroundColor(VGA.digitalAmber)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VGA.panelVeryDark)

                    // Position rows
                    ForEach(group.positions, id: \.self) { position in
                        positionRow(position)
                    }
                }
            }
        }
        .background(VGA.screenBg)
    }

    private func positionRow(_ position: Position) -> some View {
        let isSelected = selectedPosition == position
        let starterName = team?.starter(at: position)?.fullName ?? "---"

        return Button(action: {
            selectedPosition = position
            selectedPlayerId = nil
        }) {
            HStack(spacing: 6) {
                Text(position.rawValue)
                    .font(RetroFont.bodyBold())
                    .foregroundColor(isSelected ? VGA.white : VGA.cyan)
                    .frame(width: 36, alignment: .leading)

                Text(starterName.uppercased())
                    .font(RetroFont.small())
                    .foregroundColor(isSelected ? VGA.white : VGA.lightGray)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? VGA.playSlotGreen : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Player Panel

    private var playerPanel: some View {
        VStack(spacing: 0) {
            // Position header
            HStack {
                Text("\(selectedPosition.rawValue) - \(selectedPosition.displayName.uppercased())")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.digitalAmber)
                Spacer()

                let count = orderedPlayers(at: selectedPosition).count
                Text("\(count) PLAYER\(count == 1 ? "" : "S")")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.lightGray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VGA.panelVeryDark)

            // Column headers
            playerListHeader

            // Player rows
            ScrollView {
                VStack(spacing: 0) {
                    let players = orderedPlayers(at: selectedPosition)
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        playerRow(player: player, depth: index, totalCount: players.count)
                    }

                    if players.isEmpty {
                        Text("NO PLAYERS AT THIS POSITION")
                            .font(RetroFont.body())
                            .foregroundColor(VGA.darkGray)
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Spacer(minLength: 0)

            // Bottom action bar
            if selectedPlayerId != nil {
                playerActionBar
            }
        }
        .background(VGA.screenBg)
    }

    private var playerListHeader: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 30, alignment: .center)
            Text("DEPTH")
                .frame(width: 50, alignment: .center)
            Text("NAME")
                .frame(minWidth: 160, alignment: .leading)
            Spacer()
            Text("OVR")
                .frame(width: 44, alignment: .center)
            Text("AGE")
                .frame(width: 40, alignment: .center)
            Text("STATUS")
                .frame(width: 70, alignment: .center)
        }
        .font(RetroFont.small())
        .foregroundColor(VGA.lightGray)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(VGA.panelVeryDark.opacity(0.7))
    }

    private func playerRow(player: Player, depth: Int, totalCount: Int) -> some View {
        let isStarter = depth == 0
        let isSelected = selectedPlayerId == player.id
        let depthLabel = isStarter ? "1ST" : (depth == 1 ? "2ND" : (depth == 2 ? "3RD" : "\(depth + 1)TH"))

        let bgColor: Color = {
            if isSelected {
                return VGA.buttonBg.opacity(0.6)
            } else if isStarter {
                return VGA.playSlotGreen.opacity(0.3)
            } else {
                return Color.clear
            }
        }()

        let statusText: String = {
            if player.status.injuryType == .seasonEnding {
                return "IR"
            } else if player.status.isInjured {
                return "INJ"
            } else if !player.status.canPlay {
                return "OUT"
            } else {
                return "OK"
            }
        }()

        let statusColor: Color = {
            if player.status.isInjured || !player.status.canPlay {
                return VGA.brightRed
            } else {
                return VGA.green
            }
        }()

        return Button(action: {
            if selectedPlayerId == player.id {
                selectedPlayerId = nil
            } else {
                selectedPlayerId = player.id
            }
        }) {
            HStack(spacing: 0) {
                Text("\(player.jerseyNumber)")
                    .frame(width: 30, alignment: .center)
                    .foregroundColor(isStarter ? VGA.white : VGA.lightGray)

                Text(depthLabel)
                    .frame(width: 50, alignment: .center)
                    .foregroundColor(isStarter ? VGA.digitalAmber : VGA.darkGray)

                Text(player.fullName.uppercased())
                    .frame(minWidth: 160, alignment: .leading)
                    .lineLimit(1)
                    .foregroundColor(isStarter ? VGA.white : VGA.lightGray)

                Spacer()

                Text("\(player.overall)")
                    .frame(width: 44, alignment: .center)
                    .foregroundColor(overallColor(player.overall))

                Text("\(player.age)")
                    .frame(width: 40, alignment: .center)
                    .foregroundColor(VGA.lightGray)

                Text(statusText)
                    .frame(width: 70, alignment: .center)
                    .foregroundColor(statusColor)
            }
            .font(RetroFont.body())
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(bgColor)
        }
        .buttonStyle(.plain)
    }

    private func overallColor(_ ovr: Int) -> Color {
        if ovr >= 85 { return VGA.green }
        if ovr >= 75 { return VGA.cyan }
        if ovr >= 65 { return VGA.white }
        if ovr >= 55 { return VGA.orange }
        return VGA.brightRed
    }

    // MARK: - Player Action Bar

    private var playerActionBar: some View {
        let players = orderedPlayers(at: selectedPosition)
        let selectedIndex = players.firstIndex(where: { $0.id == selectedPlayerId })

        return HStack(spacing: 12) {
            if let playerId = selectedPlayerId,
               let player = team?.player(withId: playerId) {
                Text(player.fullName.uppercased())
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.white)
                    .lineLimit(1)
            }

            Spacer()

            FPSButton("PROMOTE") {
                guard let idx = selectedIndex, idx > 0 else { return }
                movePlayer(at: idx, to: idx - 1)
            }

            FPSButton("DEMOTE") {
                guard let idx = selectedIndex, idx < players.count - 1 else { return }
                movePlayer(at: idx, to: idx + 1)
            }

            FPSButton("SET STARTER") {
                guard let playerId = selectedPlayerId else { return }
                setStarter(playerId)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelDark)
    }

    // MARK: - Auto-Lineup Dialog

    private var autoLineupDialog: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FPSDialog("AUTO-LINEUP") {
                VStack(spacing: 16) {
                    Text("SET ALL STARTERS BY\nOVERALL RATING?")
                        .font(RetroFont.header())
                        .foregroundColor(VGA.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)

                    Text("THIS WILL REORDER ALL POSITIONS\nSO THE HIGHEST-RATED PLAYER\nIS THE STARTER.")
                        .font(RetroFont.body())
                        .foregroundColor(VGA.lightGray)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        FPSButton("CONFIRM", width: 100) {
                            autoLineup()
                            showAutoLineupConfirm = false
                        }

                        FPSButton("CANCEL", width: 100) {
                            showAutoLineupConfirm = false
                        }
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
            }
            .frame(width: 360)
        }
    }

    // MARK: - Actions

    private func movePlayer(at fromIndex: Int, to toIndex: Int) {
        guard var league = gameState.currentLeague,
              let teamIndex = league.teams.firstIndex(where: { $0.id == team?.id }) else { return }

        var depthList = league.teams[teamIndex].depthChart.positions[selectedPosition] ?? []
        let players = orderedPlayers(at: selectedPosition)

        // Rebuild depth list from current ordered players
        depthList = players.map { $0.id }

        guard fromIndex >= 0, fromIndex < depthList.count,
              toIndex >= 0, toIndex < depthList.count else { return }

        let movingId = depthList.remove(at: fromIndex)
        depthList.insert(movingId, at: toIndex)

        league.teams[teamIndex].depthChart.positions[selectedPosition] = depthList
        gameState.currentLeague = league
    }

    private func setStarter(_ playerId: UUID) {
        guard var league = gameState.currentLeague,
              let teamIndex = league.teams.firstIndex(where: { $0.id == team?.id }) else { return }

        league.teams[teamIndex].setStarter(playerId, at: selectedPosition)
        gameState.currentLeague = league
        selectedPlayerId = nil
    }

    private func autoLineup() {
        guard var league = gameState.currentLeague,
              let teamIndex = league.teams.firstIndex(where: { $0.id == team?.id }) else { return }

        for position in Position.allCases {
            let positionPlayers = league.teams[teamIndex].players(at: position)
                .sorted { $0.overall > $1.overall }
            let sortedIds = positionPlayers.map { $0.id }
            league.teams[teamIndex].depthChart.positions[position] = sortedIds
        }

        gameState.currentLeague = league
    }
}

// MARK: - Preview

#Preview {
    DepthChartView()
        .environmentObject(GameState())
        .frame(width: 1024, height: 768)
}
