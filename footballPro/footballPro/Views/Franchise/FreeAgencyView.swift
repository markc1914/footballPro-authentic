//
//  FreeAgencyView.swift
//  footballPro
//
//  Free Agent market — browse, filter, and sign available players
//  Authentic FPS Football Pro '93 visual style
//

import SwiftUI

struct FreeAgencyView: View {
    @Binding var league: League
    let userTeamId: UUID
    let onDismiss: () -> Void

    @State private var selectedPositionFilter: PositionFilter = .all
    @State private var sortMode: SortMode = .rating
    @State private var selectedPlayerId: UUID? = nil
    @State private var signingMessage: String? = nil
    @State private var showingSignResult: Bool = false
    @State private var contractYears: Int = 1

    enum PositionFilter: String, CaseIterable {
        case all = "ALL"
        case qb = "QB"
        case rb = "RB"
        case wr = "WR"
        case te = "TE"
        case ol = "OL"
        case dl = "DL"
        case lb = "LB"
        case db = "DB"
        case st = "ST"

        var matchesPosition: (Position) -> Bool {
            switch self {
            case .all: return { _ in true }
            case .qb: return { $0 == .quarterback }
            case .rb: return { $0 == .runningBack || $0 == .fullback }
            case .wr: return { $0 == .wideReceiver }
            case .te: return { $0 == .tightEnd }
            case .ol: return { $0 == .leftTackle || $0 == .leftGuard || $0 == .center || $0 == .rightGuard || $0 == .rightTackle }
            case .dl: return { $0 == .defensiveEnd || $0 == .defensiveTackle }
            case .lb: return { $0 == .outsideLinebacker || $0 == .middleLinebacker }
            case .db: return { $0 == .cornerback || $0 == .freeSafety || $0 == .strongSafety }
            case .st: return { $0 == .kicker || $0 == .punter }
            }
        }
    }

    enum SortMode: String, CaseIterable {
        case rating = "RATING"
        case position = "POS"
        case age = "AGE"
    }

    private var userTeam: Team? {
        league.team(withId: userTeamId)
    }

    private var capSpace: Int {
        userTeam?.finances.availableCap ?? 0
    }

    private var filteredAgents: [FreeAgent] {
        let filtered = league.freeAgents.filter { selectedPositionFilter.matchesPosition($0.player.position) }
        switch sortMode {
        case .rating:
            return filtered.sorted { $0.player.overall > $1.player.overall }
        case .position:
            return filtered.sorted { $0.player.position.rawValue < $1.player.position.rawValue }
        case .age:
            return filtered.sorted { $0.player.age < $1.player.age }
        }
    }

    private var selectedAgent: FreeAgent? {
        guard let id = selectedPlayerId else { return nil }
        return league.freeAgents.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            titleBar

            // Cap space display
            capSpaceBar

            // Position filter tabs
            positionFilterBar

            // Main content: list + detail
            HStack(spacing: 2) {
                // Left: agent list
                agentListPanel

                // Right: selected player detail
                playerDetailPanel
            }
            .padding(4)
        }
        .background(VGA.screenBg)
        .overlay(
            Group {
                if showingSignResult, let message = signingMessage {
                    signResultOverlay(message: message)
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
            Text("FREE AGENTS")
                .font(RetroFont.title())
                .foregroundColor(VGA.digitalAmber)
            Spacer()
            // Balance spacer
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(VGA.panelVeryDark)
    }

    // MARK: - Cap Space Bar

    private var capSpaceBar: some View {
        HStack {
            Text("CAP SPACE:")
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.lightGray)

            Text("$\(formatSalary(capSpace))")
                .font(RetroFont.bodyBold())
                .foregroundColor(capSpace > 10000 ? VGA.green : (capSpace > 0 ? VGA.digitalAmber : VGA.brightRed))

            Spacer()

            Text("ROSTER: \(userTeam?.roster.count ?? 0) PLAYERS")
                .font(RetroFont.body())
                .foregroundColor(VGA.lightGray)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(VGA.panelDark)
    }

    // MARK: - Position Filter Bar

    private var positionFilterBar: some View {
        HStack(spacing: 1) {
            ForEach(PositionFilter.allCases, id: \.self) { filter in
                Button(action: {
                    selectedPositionFilter = filter
                    selectedPlayerId = nil
                }) {
                    Text(filter.rawValue)
                        .font(RetroFont.tiny())
                        .foregroundColor(selectedPositionFilter == filter ? VGA.screenBg : VGA.lightGray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(selectedPositionFilter == filter ? VGA.digitalAmber : VGA.panelDark)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()

            // Sort controls
            Text("SORT:")
                .font(RetroFont.tiny())
                .foregroundColor(VGA.lightGray)

            ForEach(SortMode.allCases, id: \.self) { mode in
                Button(action: { sortMode = mode }) {
                    Text(mode.rawValue)
                        .font(RetroFont.tiny())
                        .foregroundColor(sortMode == mode ? VGA.screenBg : VGA.lightGray)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(sortMode == mode ? VGA.playSlotGreen : VGA.panelDark)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(VGA.panelVeryDark)
    }

    // MARK: - Agent List Panel

    private var agentListPanel: some View {
        VStack(spacing: 0) {
            // Table header
            HStack(spacing: 0) {
                Text("NAME")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("POS")
                    .frame(width: 40, alignment: .center)
                Text("OVR")
                    .frame(width: 36, alignment: .center)
                Text("AGE")
                    .frame(width: 36, alignment: .center)
                Text("PRICE")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(RetroFont.small())
            .foregroundColor(VGA.cyan)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(VGA.panelDark)

            // Scrollable list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredAgents) { agent in
                        agentRow(agent: agent)
                    }

                    if filteredAgents.isEmpty {
                        Text("NO FREE AGENTS")
                            .font(RetroFont.body())
                            .foregroundColor(VGA.darkGray)
                            .padding(.vertical, 20)
                    }
                }
            }
            .background(VGA.screenBg)
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
        .frame(minWidth: 300)
    }

    private func agentRow(agent: FreeAgent) -> some View {
        let isSelected = selectedPlayerId == agent.id
        return Button(action: {
            selectedPlayerId = agent.id
        }) {
            HStack(spacing: 0) {
                Text(agent.player.fullName)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(agent.player.position.rawValue)
                    .frame(width: 40, alignment: .center)
                Text("\(agent.player.overall)")
                    .frame(width: 36, alignment: .center)
                Text("\(agent.player.age)")
                    .frame(width: 36, alignment: .center)
                Text("$\(formatSalary(agent.askingPrice))")
                    .frame(width: 60, alignment: .trailing)
            }
            .font(RetroFont.small())
            .foregroundColor(isSelected ? VGA.screenBg : VGA.lightGray)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isSelected ? VGA.playSlotGreen : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Player Detail Panel

    private var playerDetailPanel: some View {
        VStack(spacing: 0) {
            Text("PLAYER DETAILS")
                .font(RetroFont.header())
                .foregroundColor(VGA.digitalAmber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(VGA.panelVeryDark)
                .modifier(DOSPanelBorder(.sunken, width: 1))

            if let agent = selectedAgent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        // Name and position
                        Text(agent.player.fullName)
                            .font(RetroFont.large())
                            .foregroundColor(VGA.white)

                        HStack {
                            detailLabel("POS", value: agent.player.position.rawValue)
                            detailLabel("OVR", value: "\(agent.player.overall)")
                            detailLabel("AGE", value: "\(agent.player.age)")
                            detailLabel("EXP", value: "\(agent.player.experience)yr")
                        }

                        HStack {
                            detailLabel("HT", value: agent.player.displayHeight)
                            detailLabel("WT", value: "\(agent.player.weight)lb")
                        }

                        Divider().background(VGA.panelDark)

                        // Key ratings for position
                        Text("RATINGS")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.digitalAmber)
                            .padding(.top, 4)

                        ratingsGrid(for: agent.player)

                        Divider().background(VGA.panelDark)

                        // Contract terms
                        Text("CONTRACT")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.digitalAmber)
                            .padding(.top, 4)

                        HStack {
                            Text("ASKING:")
                                .font(RetroFont.body())
                                .foregroundColor(VGA.lightGray)
                            Text("$\(formatSalary(agent.askingPrice))/yr")
                                .font(RetroFont.bodyBold())
                                .foregroundColor(VGA.green)
                        }

                        // Contract length picker
                        HStack {
                            Text("YEARS:")
                                .font(RetroFont.body())
                                .foregroundColor(VGA.lightGray)

                            ForEach(1...5, id: \.self) { years in
                                Button(action: { contractYears = years }) {
                                    Text("\(years)")
                                        .font(RetroFont.bodyBold())
                                        .foregroundColor(contractYears == years ? VGA.screenBg : VGA.lightGray)
                                        .frame(width: 28, height: 24)
                                        .background(contractYears == years ? VGA.digitalAmber : VGA.panelDark)
                                        .modifier(DOSPanelBorder(contractYears == years ? .sunken : .raised, width: 1))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        let totalCost = agent.askingPrice * contractYears
                        Text("TOTAL: $\(formatSalary(totalCost))")
                            .font(RetroFont.body())
                            .foregroundColor(VGA.lightGray)

                        Spacer().frame(height: 12)

                        // Sign button
                        HStack {
                            Spacer()
                            FPSButton("SIGN PLAYER", width: 140) {
                                signPlayer(agent: agent)
                            }
                            Spacer()
                        }
                    }
                    .padding(8)
                }
                .background(VGA.screenBg)
                .modifier(DOSPanelBorder(.sunken, width: 1))
            } else {
                VStack {
                    Spacer()
                    Text("SELECT A PLAYER")
                        .font(RetroFont.body())
                        .foregroundColor(VGA.darkGray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VGA.screenBg)
                .modifier(DOSPanelBorder(.sunken, width: 1))
            }
        }
        .frame(minWidth: 240, maxWidth: 300)
    }

    // MARK: - Detail Helpers

    private func detailLabel(_ label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(RetroFont.tiny())
                .foregroundColor(VGA.darkGray)
            Text(value)
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.white)
        }
        .frame(minWidth: 44)
    }

    private func ratingsGrid(for player: Player) -> some View {
        let r = player.ratings
        let pairs: [(String, Int)]

        switch player.position {
        case .quarterback:
            pairs = [
                ("SPD", r.speed), ("THR PWR", r.throwPower),
                ("ACC S", r.throwAccuracyShort), ("ACC M", r.throwAccuracyMid),
                ("ACC D", r.throwAccuracyDeep), ("AWR", r.awareness),
                ("AGI", r.agility), ("PLY ACT", r.playAction)
            ]
        case .runningBack, .fullback:
            pairs = [
                ("SPD", r.speed), ("AGI", r.agility),
                ("CAR", r.carrying), ("BRK TKL", r.breakTackle),
                ("ELU", r.elusiveness), ("BCV", r.ballCarrierVision),
                ("CTH", r.catching), ("STR", r.strength)
            ]
        case .wideReceiver:
            pairs = [
                ("SPD", r.speed), ("CTH", r.catching),
                ("RTE", r.routeRunning), ("RLS", r.release),
                ("CIT", r.catchInTraffic), ("SPC", r.spectacularCatch),
                ("AGI", r.agility), ("AWR", r.awareness)
            ]
        case .tightEnd:
            pairs = [
                ("SPD", r.speed), ("CTH", r.catching),
                ("RBK", r.runBlock), ("RTE", r.routeRunning),
                ("STR", r.strength), ("CIT", r.catchInTraffic),
                ("PBK", r.passBlock), ("AWR", r.awareness)
            ]
        case .leftTackle, .leftGuard, .center, .rightGuard, .rightTackle:
            pairs = [
                ("RBK", r.runBlock), ("PBK", r.passBlock),
                ("STR", r.strength), ("AWR", r.awareness),
                ("AGI", r.agility), ("IMP", r.impactBlock),
                ("TGH", r.toughness), ("STA", r.stamina)
            ]
        case .defensiveEnd, .defensiveTackle:
            pairs = [
                ("PRS", r.passRush), ("BSH", r.blockShedding),
                ("SPD", r.speed), ("STR", r.strength),
                ("TKL", r.tackle), ("PUR", r.pursuit),
                ("AWR", r.awareness), ("TGH", r.toughness)
            ]
        case .outsideLinebacker, .middleLinebacker:
            pairs = [
                ("TKL", r.tackle), ("PUR", r.pursuit),
                ("PRS", r.passRush), ("ZCV", r.zoneCoverage),
                ("SPD", r.speed), ("PLR", r.playRecognition),
                ("STR", r.strength), ("AWR", r.awareness)
            ]
        case .cornerback, .freeSafety, .strongSafety:
            pairs = [
                ("MCV", r.manCoverage), ("ZCV", r.zoneCoverage),
                ("SPD", r.speed), ("PRS", r.press),
                ("AGI", r.agility), ("PLR", r.playRecognition),
                ("TKL", r.tackle), ("CTH", r.catching)
            ]
        case .kicker, .punter:
            pairs = [
                ("KPW", r.kickPower), ("KAC", r.kickAccuracy),
                ("AWR", r.awareness), ("TGH", r.toughness)
            ]
        }

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 3) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                ratingBar(label: pair.0, value: pair.1)
            }
        }
    }

    private func ratingBar(label: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(RetroFont.tiny())
                .foregroundColor(VGA.lightGray)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(VGA.panelDark)
                        .frame(height: 8)

                    Rectangle()
                        .fill(ratingColor(value))
                        .frame(width: geo.size.width * CGFloat(value) / 100.0, height: 8)
                }
            }
            .frame(height: 8)

            Text("\(value)")
                .font(RetroFont.tiny())
                .foregroundColor(VGA.white)
                .frame(width: 22, alignment: .trailing)
        }
    }

    private func ratingColor(_ value: Int) -> Color {
        if value >= 85 { return VGA.green }
        if value >= 70 { return VGA.digitalAmber }
        if value >= 55 { return VGA.orange }
        return VGA.brightRed
    }

    // MARK: - Sign Result Overlay

    private func signResultOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            FPSDialog("FREE AGENCY") {
                VStack(spacing: 12) {
                    Text(message)
                        .font(RetroFont.header())
                        .foregroundColor(
                            message.contains("SIGNED") ? VGA.green : VGA.brightRed
                        )
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)

                    FPSButton("OK", width: 80) {
                        showingSignResult = false
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: 400)
        }
    }

    // MARK: - Sign Logic

    private func signPlayer(agent: FreeAgent) {
        guard capSpace >= agent.askingPrice else {
            signingMessage = "NOT ENOUGH CAP SPACE"
            showingSignResult = true
            return
        }

        // Build contract
        var yearlyValues: [Int] = []
        for i in 0..<contractYears {
            yearlyValues.append(agent.askingPrice + (i * 200))
        }

        let contract = Contract(
            yearsRemaining: contractYears,
            totalValue: yearlyValues.reduce(0, +),
            yearlyValues: yearlyValues,
            signingBonus: agent.askingPrice / 4,
            guaranteedMoney: agent.askingPrice
        )

        league.signFreeAgent(playerId: agent.player.id, to: userTeamId, contract: contract)

        signingMessage = "\(agent.player.fullName) SIGNED!\n\(agent.player.position.rawValue) - \(contractYears)yr / $\(formatSalary(contract.totalValue))"
        selectedPlayerId = nil
        showingSignResult = true
    }

    // MARK: - Helpers

    private func formatSalary(_ amount: Int) -> String {
        if amount >= 1000 {
            let millions = Double(amount) / 1000.0
            return String(format: "%.1fM", millions)
        }
        return "\(amount)K"
    }
}
