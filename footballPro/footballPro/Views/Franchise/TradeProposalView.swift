//
//  TradeProposalView.swift
//  footballPro
//
//  Trade Center — two-column roster view for proposing player trades
//  Authentic FPS Football Pro '93 visual style
//

import SwiftUI

struct TradeProposalView: View {
    @Binding var league: League
    let userTeamId: UUID
    let onDismiss: () -> Void

    @State private var selectedPartnerIndex: Int = 0
    @State private var offeredPlayerIds: Set<UUID> = []
    @State private var requestedPlayerIds: Set<UUID> = []
    @State private var tradeResultMessage: String? = nil
    @State private var showingResult: Bool = false

    private var userTeam: Team? {
        league.team(withId: userTeamId)
    }

    private var partnerTeams: [Team] {
        league.teams.filter { $0.id != userTeamId }
    }

    private var partnerTeam: Team? {
        guard !partnerTeams.isEmpty, selectedPartnerIndex < partnerTeams.count else { return nil }
        return partnerTeams[selectedPartnerIndex]
    }

    private var offeredTotal: Int {
        guard let team = userTeam else { return 0 }
        return team.roster
            .filter { offeredPlayerIds.contains($0.id) }
            .reduce(0) { $0 + $1.overall }
    }

    private var requestedTotal: Int {
        guard let team = partnerTeam else { return 0 }
        return team.roster
            .filter { requestedPlayerIds.contains($0.id) }
            .reduce(0) { $0 + $1.overall }
    }

    private var fairnessDelta: Int {
        offeredTotal - requestedTotal
    }

    private var fairnessLabel: String {
        let delta = fairnessDelta
        if offeredPlayerIds.isEmpty && requestedPlayerIds.isEmpty {
            return "SELECT PLAYERS"
        }
        if abs(delta) <= 5 {
            return "FAIR TRADE"
        } else if delta > 5 {
            return "OVERPAYING +\(delta)"
        } else {
            return "UNDERPAYING \(delta)"
        }
    }

    private var fairnessColor: Color {
        let delta = fairnessDelta
        if offeredPlayerIds.isEmpty && requestedPlayerIds.isEmpty {
            return VGA.lightGray
        }
        if abs(delta) <= 5 {
            return VGA.green
        } else if abs(delta) <= 10 {
            return VGA.digitalAmber
        } else {
            return VGA.brightRed
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            titleBar

            // Team selector
            teamSelector

            // Two-column roster area
            HStack(spacing: 2) {
                // Left column: YOUR PLAYERS
                rosterColumn(
                    title: "YOUR PLAYERS",
                    team: userTeam,
                    selectedIds: $offeredPlayerIds
                )

                // Right column: THEIR PLAYERS
                rosterColumn(
                    title: "THEIR PLAYERS",
                    team: partnerTeam,
                    selectedIds: $requestedPlayerIds
                )
            }
            .padding(4)

            // Fairness indicator
            fairnessBar

            // Action buttons
            actionBar
        }
        .background(VGA.screenBg)
        .overlay(
            Group {
                if showingResult, let message = tradeResultMessage {
                    tradeResultOverlay(message: message)
                }
            }
        )
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            FPSButton("BACK") {
                onDismiss()
            }
            Spacer()
            Text("TRADE CENTER")
                .font(RetroFont.title())
                .foregroundColor(VGA.digitalAmber)
            Spacer()
            // Spacer to balance the back button
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(VGA.panelVeryDark)
    }

    // MARK: - Team Selector

    private var teamSelector: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TRADE PARTNER:")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.lightGray)

                Spacer()

                FPSButton("< PREV") {
                    if selectedPartnerIndex > 0 {
                        selectedPartnerIndex -= 1
                        requestedPlayerIds.removeAll()
                        tradeResultMessage = nil
                        showingResult = false
                    }
                }

                Text(partnerTeam.map { "\($0.abbreviation) \($0.fullName)" } ?? "---")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.digitalAmber)
                    .frame(minWidth: 180)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VGA.panelVeryDark)
                    .modifier(DOSPanelBorder(.sunken, width: 1))

                FPSButton("NEXT >") {
                    if selectedPartnerIndex < partnerTeams.count - 1 {
                        selectedPartnerIndex += 1
                        requestedPlayerIds.removeAll()
                        tradeResultMessage = nil
                        showingResult = false
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.panelDark)
        }
    }

    // MARK: - Roster Column

    private func rosterColumn(
        title: String,
        team: Team?,
        selectedIds: Binding<Set<UUID>>
    ) -> some View {
        VStack(spacing: 0) {
            // Column header
            Text(title)
                .font(RetroFont.header())
                .foregroundColor(VGA.digitalAmber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(VGA.panelVeryDark)
                .modifier(DOSPanelBorder(.sunken, width: 1))

            // Table header row
            HStack(spacing: 0) {
                Text("NAME")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("POS")
                    .frame(width: 40, alignment: .center)
                Text("OVR")
                    .frame(width: 36, alignment: .center)
                Text("AGE")
                    .frame(width: 36, alignment: .center)
            }
            .font(RetroFont.small())
            .foregroundColor(VGA.cyan)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(VGA.panelDark)

            // Scrollable roster
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let team = team {
                        let sortedRoster = team.roster.sorted { $0.overall > $1.overall }
                        ForEach(sortedRoster) { player in
                            playerRow(
                                player: player,
                                isSelected: selectedIds.wrappedValue.contains(player.id),
                                onTap: {
                                    if selectedIds.wrappedValue.contains(player.id) {
                                        selectedIds.wrappedValue.remove(player.id)
                                    } else {
                                        selectedIds.wrappedValue.insert(player.id)
                                    }
                                    tradeResultMessage = nil
                                    showingResult = false
                                }
                            )
                        }
                    }
                }
            }
            .background(VGA.screenBg)
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
    }

    // MARK: - Player Row

    private func playerRow(player: Player, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Text(player.fullName)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(player.position.rawValue)
                    .frame(width: 40, alignment: .center)
                Text("\(player.overall)")
                    .frame(width: 36, alignment: .center)
                Text("\(player.age)")
                    .frame(width: 36, alignment: .center)
            }
            .font(RetroFont.small())
            .foregroundColor(isSelected ? VGA.screenBg : VGA.lightGray)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isSelected ? VGA.playSlotGreen : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Fairness Bar

    private var fairnessBar: some View {
        HStack {
            Text("OFFERED: \(offeredTotal) OVR")
                .font(RetroFont.body())
                .foregroundColor(VGA.lightGray)

            Spacer()

            Text(fairnessLabel)
                .font(RetroFont.bodyBold())
                .foregroundColor(fairnessColor)

            Spacer()

            Text("REQUESTED: \(requestedTotal) OVR")
                .font(RetroFont.body())
                .foregroundColor(VGA.lightGray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(VGA.panelVeryDark)
        .modifier(DOSPanelBorder(.sunken, width: 1))
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            Spacer()

            FPSButton("CLEAR", width: 100) {
                offeredPlayerIds.removeAll()
                requestedPlayerIds.removeAll()
                tradeResultMessage = nil
                showingResult = false
            }

            FPSButton("PROPOSE TRADE", width: 160) {
                proposeTrade()
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .background(VGA.panelDark)
    }

    // MARK: - Trade Result Overlay

    private func tradeResultOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            FPSDialog("TRADE RESULT") {
                VStack(spacing: 12) {
                    Text(message)
                        .font(RetroFont.large())
                        .foregroundColor(
                            message.contains("ACCEPTED") ? VGA.green : VGA.brightRed
                        )
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)

                    if message.contains("ACCEPTED") {
                        tradeSummaryView
                    }

                    FPSButton("OK", width: 80) {
                        showingResult = false
                        if message.contains("ACCEPTED") {
                            offeredPlayerIds.removeAll()
                            requestedPlayerIds.removeAll()
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: 400)
        }
    }

    private var tradeSummaryView: some View {
        VStack(spacing: 4) {
            if let team = userTeam {
                ForEach(Array(offeredPlayerIds), id: \.self) { playerId in
                    if let player = team.roster.first(where: { $0.id == playerId }) {
                        Text("SENT: \(player.fullName) (\(player.position.rawValue))")
                            .font(RetroFont.small())
                            .foregroundColor(VGA.brightRed)
                    }
                }
            }
            if let team = partnerTeam {
                ForEach(Array(requestedPlayerIds), id: \.self) { playerId in
                    if let player = team.roster.first(where: { $0.id == playerId }) {
                        Text("RECV: \(player.fullName) (\(player.position.rawValue))")
                            .font(RetroFont.small())
                            .foregroundColor(VGA.green)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Trade Logic

    private func proposeTrade() {
        guard !offeredPlayerIds.isEmpty, !requestedPlayerIds.isEmpty else {
            tradeResultMessage = "SELECT PLAYERS FIRST"
            showingResult = true
            return
        }

        guard let partner = partnerTeam else { return }

        // AI evaluates: accept if within +/- 10 overall rating points
        let delta = fairnessDelta
        let accepted = delta >= -10 // AI accepts if user is offering fair or overpaying

        if accepted {
            // Create and execute trade
            var trade = TradeOffer(
                proposingTeamId: userTeamId,
                receivingTeamId: partner.id
            )
            trade.playersOffered = Array(offeredPlayerIds)
            trade.playersRequested = Array(requestedPlayerIds)
            trade.status = .accepted

            league.pendingTrades.append(trade)
            league.executeTrade(trade.id)

            tradeResultMessage = "TRADE ACCEPTED!"
        } else {
            tradeResultMessage = "TRADE REJECTED"
        }

        showingResult = true
    }
}
