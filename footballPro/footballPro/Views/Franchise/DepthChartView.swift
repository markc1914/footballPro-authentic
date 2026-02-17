//
//  DepthChartView.swift
//  footballPro
//
//  Depth chart management screen — 47-slot roster structure matching FPS '93
//  34 assigned + 11 open + 2 IR slots, DOS/VGA aesthetic
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

    private enum SidebarSection: Hashable {
        case position(Position)
        case openSlots
        case injuredReserve
    }

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

    @State private var selectedSection: SidebarSection = .position(.quarterback)
    @State private var selectedPlayerId: UUID? = nil
    @State private var showAutoLineupConfirm = false
    @State private var editingPlayerId: UUID? = nil

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

    /// Players filling open (flex) slots.
    private var openSlotPlayers: [Player] {
        guard let team = team else { return [] }
        let openPlayerIds = team.openSlots.compactMap { $0.playerId }
        return openPlayerIds.compactMap { id in team.player(withId: id) }
    }

    /// Players on injured reserve.
    private var irPlayersList: [Player] {
        guard let team = team else { return [] }
        return team.irPlayers
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
            DOSSeparator()

            // Roster summary bar
            rosterSummaryBar

            HStack(spacing: 0) {
                // Left sidebar — position list + open/IR
                positionSidebar
                    .frame(width: 200)

                // Vertical separator
                VStack(spacing: 0) {
                    Rectangle().fill(VGA.shadowInner).frame(width: 1)
                }

                // Right panel — players at selected section
                playerPanel
            }
        }
        .background(VGA.screenBg)
        .overlay(
            Group {
                if showAutoLineupConfirm {
                    autoLineupDialog
                }
            }
        )
        .overlay(
            Group {
                if let pid = editingPlayerId {
                    ZStack {
                        Color.black.opacity(0.7).ignoresSafeArea()
                        PlayerEditorView(
                            playerId: pid,
                            onDismiss: { editingPlayerId = nil }
                        )
                        .environmentObject(gameState)
                        .frame(width: 700, height: 500)
                        .modifier(DOSPanelBorder(.raised, width: 2))
                    }
                }
            }
        )
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

    // MARK: - Roster Summary Bar

    private var rosterSummaryBar: some View {
        let total = team?.roster.count ?? 0
        let assigned = team?.rosterSlots.filter {
            if case .assigned = $0.slotType { return $0.playerId != nil }
            return false
        }.count ?? 0
        let open = team?.openSlots.filter { $0.playerId != nil }.count ?? 0
        let ir = team?.irSlots.filter { $0.playerId != nil }.count ?? 0

        return HStack(spacing: 16) {
            Text("ROSTER: \(total)/47")
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.white)

            Text("ASSIGNED: \(assigned)/34")
                .font(RetroFont.small())
                .foregroundColor(VGA.cyan)

            Text("OPEN: \(open)/11")
                .font(RetroFont.small())
                .foregroundColor(VGA.digitalAmber)

            Text("IR: \(ir)/2")
                .font(RetroFont.small())
                .foregroundColor(VGA.brightRed)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(VGA.panelVeryDark)
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

                // OPEN SLOTS section
                HStack {
                    Text("OPEN SLOTS")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.digitalAmber)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(VGA.panelVeryDark)

                sidebarSpecialRow(
                    label: "OPEN",
                    detail: "\(openSlotPlayers.count)/11",
                    section: .openSlots,
                    color: VGA.digitalAmber
                )

                // INJURED RESERVE section
                HStack {
                    Text("INJURED RESERVE")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.brightRed)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(VGA.panelVeryDark)

                sidebarSpecialRow(
                    label: "IR",
                    detail: "\(irPlayersList.count)/2",
                    section: .injuredReserve,
                    color: VGA.brightRed
                )
            }
        }
        .background(VGA.screenBg)
    }

    private func positionRow(_ position: Position) -> some View {
        let isSelected: Bool = {
            if case .position(let p) = selectedSection { return p == position }
            return false
        }()
        let starterName = team?.starter(at: position)?.fullName ?? "---"
        let slotCount = team?.assignedSlots(for: position).count ?? 0
        let filledCount = team?.assignedSlots(for: position).filter { $0.playerId != nil }.count ?? 0

        return Button(action: {
            selectedSection = .position(position)
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

                Text("\(filledCount)/\(slotCount)")
                    .font(RetroFont.tiny())
                    .foregroundColor(filledCount < slotCount ? VGA.digitalAmber : VGA.darkGray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? VGA.playSlotGreen : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func sidebarSpecialRow(label: String, detail: String, section: SidebarSection, color: Color) -> some View {
        let isSelected = selectedSection == section

        return Button(action: {
            selectedSection = section
            selectedPlayerId = nil
        }) {
            HStack(spacing: 6) {
                Text(label)
                    .font(RetroFont.bodyBold())
                    .foregroundColor(isSelected ? VGA.white : color)
                    .frame(width: 36, alignment: .leading)

                Spacer()

                Text(detail)
                    .font(RetroFont.small())
                    .foregroundColor(isSelected ? VGA.white : VGA.lightGray)
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
            switch selectedSection {
            case .position(let position):
                positionPlayerPanel(position)
            case .openSlots:
                openSlotsPanel
            case .injuredReserve:
                irPanel
            }
        }
        .background(VGA.screenBg)
    }

    private func positionPlayerPanel(_ position: Position) -> some View {
        VStack(spacing: 0) {
            // Position header
            HStack {
                Text("\(position.rawValue) - \(position.displayName.uppercased())")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.digitalAmber)
                Spacer()

                let total = orderedPlayers(at: position).count
                let slots = team?.assignedSlots(for: position).count ?? 0
                Text("\(total) PLAYER\(total == 1 ? "" : "S") / \(slots) SLOT\(slots == 1 ? "" : "S")")
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
                    let players = orderedPlayers(at: position)
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
                positionActionBar
            }
        }
    }

    private var openSlotsPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("OPEN SLOTS")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.digitalAmber)
                Spacer()

                let filled = openSlotPlayers.count
                Text("\(filled)/11 FILLED")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.lightGray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VGA.panelVeryDark)

            playerListHeader

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(openSlotPlayers.enumerated()), id: \.element.id) { index, player in
                        openSlotRow(player: player, slotIndex: index)
                    }

                    // Show empty slots
                    let emptyCount = (team?.availableOpenSlots ?? 0)
                    ForEach(0..<emptyCount, id: \.self) { i in
                        emptySlotRow(label: "OPEN SLOT \(openSlotPlayers.count + i + 1)")
                    }
                }
            }

            Spacer(minLength: 0)

            if selectedPlayerId != nil {
                openSlotActionBar
            }
        }
    }

    private var irPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("INJURED RESERVE")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.brightRed)
                Spacer()

                let filled = irPlayersList.count
                Text("\(filled)/2 FILLED")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.lightGray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VGA.panelVeryDark)

            playerListHeader

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(irPlayersList, id: \.id) { player in
                        irPlayerRow(player: player)
                    }

                    // Show empty IR slots
                    let emptyCount = (team?.availableIRSlots ?? 0)
                    ForEach(0..<emptyCount, id: \.self) { i in
                        emptySlotRow(label: "IR SLOT \(irPlayersList.count + i + 1)")
                    }
                }
            }

            Spacer(minLength: 0)

            if selectedPlayerId != nil {
                irActionBar
            }
        }
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
            Text("POS")
                .frame(width: 36, alignment: .center)
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
        let isOnIR = team?.isOnIR(player.id) ?? false
        let depthLabel = isStarter ? "1ST" : (depth == 1 ? "2ND" : (depth == 2 ? "3RD" : "\(depth + 1)TH"))

        let bgColor: Color = {
            if isSelected {
                return VGA.buttonBg.opacity(0.6)
            } else if isOnIR {
                return VGA.brightRed.opacity(0.15)
            } else if isStarter {
                return VGA.playSlotGreen.opacity(0.3)
            } else {
                return Color.clear
            }
        }()

        let statusText: String = {
            if isOnIR { return "IR" }
            if player.status.injuryType == .seasonEnding { return "IR" }
            if player.status.isInjured { return "INJ" }
            if !player.status.canPlay { return "OUT" }
            return "OK"
        }()

        let statusColor: Color = {
            if isOnIR || player.status.isInjured || !player.status.canPlay {
                return VGA.brightRed
            }
            return VGA.green
        }()

        return Button(action: {
            selectedPlayerId = selectedPlayerId == player.id ? nil : player.id
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

                Text(player.position.rawValue)
                    .frame(width: 36, alignment: .center)
                    .foregroundColor(VGA.cyan)

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

    private func openSlotRow(player: Player, slotIndex: Int) -> some View {
        let isSelected = selectedPlayerId == player.id

        return Button(action: {
            selectedPlayerId = selectedPlayerId == player.id ? nil : player.id
        }) {
            HStack(spacing: 0) {
                Text("\(player.jerseyNumber)")
                    .frame(width: 30, alignment: .center)
                    .foregroundColor(VGA.lightGray)

                Text("\(slotIndex + 1)")
                    .frame(width: 50, alignment: .center)
                    .foregroundColor(VGA.digitalAmber)

                Text(player.fullName.uppercased())
                    .frame(minWidth: 160, alignment: .leading)
                    .lineLimit(1)
                    .foregroundColor(VGA.white)

                Spacer()

                Text(player.position.rawValue)
                    .frame(width: 36, alignment: .center)
                    .foregroundColor(VGA.cyan)

                Text("\(player.overall)")
                    .frame(width: 44, alignment: .center)
                    .foregroundColor(overallColor(player.overall))

                Text("\(player.age)")
                    .frame(width: 40, alignment: .center)
                    .foregroundColor(VGA.lightGray)

                Text(player.status.isInjured ? "INJ" : "OK")
                    .frame(width: 70, alignment: .center)
                    .foregroundColor(player.status.isInjured ? VGA.brightRed : VGA.green)
            }
            .font(RetroFont.body())
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isSelected ? VGA.buttonBg.opacity(0.6) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func irPlayerRow(player: Player) -> some View {
        let isSelected = selectedPlayerId == player.id

        return Button(action: {
            selectedPlayerId = selectedPlayerId == player.id ? nil : player.id
        }) {
            HStack(spacing: 0) {
                Text("\(player.jerseyNumber)")
                    .frame(width: 30, alignment: .center)
                    .foregroundColor(VGA.lightGray)

                Text("IR")
                    .frame(width: 50, alignment: .center)
                    .foregroundColor(VGA.brightRed)

                Text(player.fullName.uppercased())
                    .frame(minWidth: 160, alignment: .leading)
                    .lineLimit(1)
                    .foregroundColor(VGA.lightGray)

                Spacer()

                Text(player.position.rawValue)
                    .frame(width: 36, alignment: .center)
                    .foregroundColor(VGA.cyan)

                Text("\(player.overall)")
                    .frame(width: 44, alignment: .center)
                    .foregroundColor(overallColor(player.overall))

                Text("\(player.age)")
                    .frame(width: 40, alignment: .center)
                    .foregroundColor(VGA.lightGray)

                Text(player.status.injuryType?.rawValue.uppercased().prefix(6).description ?? "INJ")
                    .frame(width: 70, alignment: .center)
                    .foregroundColor(VGA.brightRed)
            }
            .font(RetroFont.body())
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isSelected ? VGA.buttonBg.opacity(0.6) : VGA.brightRed.opacity(0.1))
        }
        .buttonStyle(.plain)
    }

    private func emptySlotRow(label: String) -> some View {
        HStack(spacing: 0) {
            Text("--")
                .frame(width: 30, alignment: .center)
            Text("")
                .frame(width: 50, alignment: .center)
            Text(label)
                .frame(minWidth: 160, alignment: .leading)
                .lineLimit(1)

            Spacer()

            Text("---")
                .frame(width: 36, alignment: .center)
            Text("--")
                .frame(width: 44, alignment: .center)
            Text("--")
                .frame(width: 40, alignment: .center)
            Text("EMPTY")
                .frame(width: 70, alignment: .center)
        }
        .font(RetroFont.body())
        .foregroundColor(VGA.darkGray)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func overallColor(_ ovr: Int) -> Color {
        if ovr >= 85 { return VGA.green }
        if ovr >= 75 { return VGA.cyan }
        if ovr >= 65 { return VGA.white }
        if ovr >= 55 { return VGA.orange }
        return VGA.brightRed
    }

    // MARK: - Action Bars

    private var positionActionBar: some View {
        let position: Position = {
            if case .position(let p) = selectedSection { return p }
            return .quarterback
        }()
        let players = orderedPlayers(at: position)
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

            // Move to IR button (only for injured players)
            if let playerId = selectedPlayerId,
               let player = team?.player(withId: playerId),
               player.status.isInjured,
               !(team?.isOnIR(playerId) ?? false) {
                FPSButton("MOVE TO IR") {
                    movePlayerToIR(playerId)
                }
            }

            FPSButton("EDIT") {
                guard let playerId = selectedPlayerId else { return }
                editingPlayerId = playerId
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelDark)
    }

    private var openSlotActionBar: some View {
        HStack(spacing: 12) {
            if let playerId = selectedPlayerId,
               let player = team?.player(withId: playerId) {
                Text(player.fullName.uppercased())
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.white)
                    .lineLimit(1)
            }

            Spacer()

            FPSButton("EDIT") {
                guard let playerId = selectedPlayerId else { return }
                editingPlayerId = playerId
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelDark)
    }

    private var irActionBar: some View {
        HStack(spacing: 12) {
            if let playerId = selectedPlayerId,
               let player = team?.player(withId: playerId) {
                Text(player.fullName.uppercased())
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.white)
                    .lineLimit(1)
            }

            Spacer()

            FPSButton("ACTIVATE") {
                guard let playerId = selectedPlayerId else { return }
                activateFromIR(playerId)
            }

            FPSButton("EDIT") {
                guard let playerId = selectedPlayerId else { return }
                editingPlayerId = playerId
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelDark)
    }

    // MARK: - Auto-Lineup Dialog

    private var autoLineupDialog: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

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
        guard case .position(let position) = selectedSection else { return }
        guard var league = gameState.currentLeague,
              let teamIndex = league.teams.firstIndex(where: { $0.id == team?.id }) else { return }

        var depthList = league.teams[teamIndex].depthChart.positions[position] ?? []
        let players = orderedPlayers(at: position)

        // Rebuild depth list from current ordered players
        depthList = players.map { $0.id }

        guard fromIndex >= 0, fromIndex < depthList.count,
              toIndex >= 0, toIndex < depthList.count else { return }

        let movingId = depthList.remove(at: fromIndex)
        depthList.insert(movingId, at: toIndex)

        league.teams[teamIndex].depthChart.positions[position] = depthList
        gameState.currentLeague = league
    }

    private func setStarter(_ playerId: UUID) {
        guard case .position(let position) = selectedSection else { return }
        guard var league = gameState.currentLeague,
              let teamIndex = league.teams.firstIndex(where: { $0.id == team?.id }) else { return }

        league.teams[teamIndex].setStarter(playerId, at: position)
        gameState.currentLeague = league
        selectedPlayerId = nil
    }

    private func movePlayerToIR(_ playerId: UUID) {
        guard var league = gameState.currentLeague,
              let teamIndex = league.teams.firstIndex(where: { $0.id == team?.id }) else { return }

        league.teams[teamIndex].moveToIR(playerId)
        gameState.currentLeague = league
        selectedPlayerId = nil
    }

    private func activateFromIR(_ playerId: UUID) {
        guard var league = gameState.currentLeague,
              let teamIndex = league.teams.firstIndex(where: { $0.id == team?.id }) else { return }

        league.teams[teamIndex].activateFromIR(playerId)
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
