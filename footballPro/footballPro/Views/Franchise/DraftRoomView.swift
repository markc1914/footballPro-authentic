//
//  DraftRoomView.swift
//  footballPro
//
//  NFL Draft room view — authentic FPS '93 DOS style
//

import SwiftUI

struct DraftRoomView: View {
    @EnvironmentObject var gameState: GameState

    // MARK: - State

    @State private var draftClass: [DraftEngine.DraftProspect] = []
    @State private var currentRound: Int = 1
    @State private var currentPick: Int = 1
    @State private var selectedProspect: DraftEngine.DraftProspect? = nil
    @State private var draftLog: [DraftLogEntry] = []
    @State private var isUserPick: Bool = false
    @State private var isDraftComplete: Bool = false
    @State private var isSimulating: Bool = false
    @State private var draftOrder: [Team] = []
    @State private var filterPosition: Position? = nil

    private let draftEngine = DraftEngine()
    private let numberOfRounds = 5

    // MARK: - Body

    var body: some View {
        ZStack {
            VGA.screenBg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                currentPickBanner
                HSplitContent
                draftLogPanel
            }
        }
        .onAppear {
            initializeDraft()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            FPSButton("< BACK") {
                gameState.navigateTo(.management)
            }

            Spacer()

            Text("NFL DRAFT \(gameState.currentSeason?.year ?? 1993)")
                .font(RetroFont.title())
                .foregroundColor(VGA.digitalAmber)

            Spacer()

            if !isDraftComplete {
                HStack(spacing: 8) {
                    FPSButton("AUTO PICK") {
                        autoPickCurrent()
                    }

                    FPSButton("SIM TO NEXT PICK") {
                        simToNextUserPick()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(VGA.panelDark)
        .modifier(DOSPanelBorder(.raised, width: 1))
    }

    // MARK: - Current Pick Banner

    private var currentPickBanner: some View {
        HStack(spacing: 20) {
            if isDraftComplete {
                Text("DRAFT COMPLETE")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.green)
            } else {
                Text("ROUND \(currentRound) - PICK \(currentPick)")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.digitalAmber)

                if let pickingTeam = currentPickingTeam {
                    Text(pickingTeam.fullName.uppercased())
                        .font(RetroFont.header())
                        .foregroundColor(isUserPick ? VGA.cyan : VGA.lightGray)

                    if isUserPick {
                        Text("YOUR PICK")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.screenBg)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(VGA.digitalAmber)
                    }
                }
            }

            Spacer()

            Text("AVAILABLE: \(availableProspects.count)")
                .font(RetroFont.body())
                .foregroundColor(VGA.lightGray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(VGA.panelVeryDark)
    }

    // MARK: - Split Content (Prospects + Detail)

    private var HSplitContent: some View {
        HStack(spacing: 0) {
            // Left panel: Available prospects
            VStack(spacing: 0) {
                prospectListHeader
                prospectList
            }
            .frame(minWidth: 500)
            .background(VGA.screenBg)
            .modifier(DOSPanelBorder(.sunken, width: 1))

            // Right panel: Prospect detail
            prospectDetailPanel
                .frame(minWidth: 340, maxWidth: 400)
                .background(VGA.panelBg)
                .modifier(DOSPanelBorder(.raised, width: 1))
        }
    }

    // MARK: - Prospect List Header

    private var prospectListHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AVAILABLE PROSPECTS")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.digitalAmber)

                Spacer()

                // Position filter
                HStack(spacing: 4) {
                    Text("FILTER:")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.lightGray)

                    Button(action: { filterPosition = nil }) {
                        Text("ALL")
                            .font(RetroFont.small())
                            .foregroundColor(filterPosition == nil ? VGA.screenBg : VGA.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(filterPosition == nil ? VGA.digitalAmber : VGA.panelDark)
                    }
                    .buttonStyle(.plain)

                    ForEach(positionFilterGroups, id: \.self) { pos in
                        Button(action: { filterPosition = pos }) {
                            Text(pos.rawValue)
                                .font(RetroFont.small())
                                .foregroundColor(filterPosition == pos ? VGA.screenBg : VGA.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(filterPosition == pos ? VGA.digitalAmber : VGA.panelDark)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.titleBarBg)

            // Column headers
            HStack(spacing: 0) {
                Text("NAME")
                    .frame(width: 180, alignment: .leading)
                Text("POS")
                    .frame(width: 40)
                Text("COLLEGE")
                    .frame(width: 140, alignment: .leading)
                Text("OVR")
                    .frame(width: 40)
                Text("DEV")
                    .frame(width: 80)
                Spacer()
            }
            .font(RetroFont.small())
            .foregroundColor(VGA.lightGray)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(VGA.panelDark)
        }
    }

    // MARK: - Prospect List

    private var prospectList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredProspects) { prospect in
                    prospectRow(prospect)
                }
            }
        }
    }

    private func prospectRow(_ prospect: DraftEngine.DraftProspect) -> some View {
        let isSelected = selectedProspect?.id == prospect.id

        return Button(action: {
            selectedProspect = prospect
        }) {
            HStack(spacing: 0) {
                Text(prospect.player.fullName)
                    .frame(width: 180, alignment: .leading)
                    .lineLimit(1)

                Text(prospect.player.position.rawValue)
                    .frame(width: 40)
                    .foregroundColor(positionColor(prospect.player.position))

                Text(prospect.player.college)
                    .frame(width: 140, alignment: .leading)
                    .lineLimit(1)

                Text("\(prospect.scoutingGrade.overall)")
                    .frame(width: 40)
                    .foregroundColor(ratingColor(prospect.scoutingGrade.overall))

                Text(prospect.scoutingGrade.development.rawValue)
                    .frame(width: 80)
                    .foregroundColor(developmentColor(prospect.scoutingGrade.development))

                Spacer()
            }
            .font(RetroFont.body())
            .foregroundColor(isSelected ? VGA.screenBg : VGA.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? VGA.playSlotGreen : VGA.screenBg)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Prospect Detail Panel

    @ViewBuilder
    private var prospectDetailPanel: some View {
        if let prospect = selectedProspect {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Name and position header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prospect.player.fullName.uppercased())
                            .font(RetroFont.header())
                            .foregroundColor(VGA.digitalAmber)

                        HStack(spacing: 12) {
                            Text(prospect.player.position.displayName)
                                .font(RetroFont.body())
                                .foregroundColor(positionColor(prospect.player.position))

                            Text(prospect.player.college)
                                .font(RetroFont.body())
                                .foregroundColor(VGA.white)

                            Text("AGE \(prospect.player.age)")
                                .font(RetroFont.body())
                                .foregroundColor(VGA.lightGray)
                        }
                    }
                    .padding(.bottom, 4)

                    DOSSeparator()

                    // Scouting Grade
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SCOUTING REPORT")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.cyan)

                        HStack(spacing: 16) {
                            scoutingStatBox(label: "GRADE", value: "\(prospect.scoutingGrade.overall)", color: ratingColor(prospect.scoutingGrade.overall))
                            scoutingStatBox(label: "CEILING", value: "\(prospect.scoutingGrade.ceiling)", color: ratingColor(prospect.scoutingGrade.ceiling))
                            scoutingStatBox(label: "FLOOR", value: "\(prospect.scoutingGrade.floor)", color: ratingColor(prospect.scoutingGrade.floor))
                        }

                        HStack(spacing: 8) {
                            Text("DEVELOPMENT:")
                                .font(RetroFont.small())
                                .foregroundColor(VGA.lightGray)
                            Text(prospect.scoutingGrade.development.rawValue.uppercased())
                                .font(RetroFont.bodyBold())
                                .foregroundColor(developmentColor(prospect.scoutingGrade.development))
                        }

                        HStack(spacing: 8) {
                            Text("PROJ. ROUND:")
                                .font(RetroFont.small())
                                .foregroundColor(VGA.lightGray)
                            Text("\(prospect.projectedRound)")
                                .font(RetroFont.bodyBold())
                                .foregroundColor(VGA.white)
                        }

                        HStack(spacing: 8) {
                            Text("ACCURACY:")
                                .font(RetroFont.small())
                                .foregroundColor(VGA.lightGray)
                            Text(scoutingAccuracyLabel(prospect.scoutingGrade.accuracy))
                                .font(RetroFont.body())
                                .foregroundColor(VGA.white)
                        }
                    }

                    DOSSeparator()

                    // Combine Results
                    VStack(alignment: .leading, spacing: 6) {
                        Text("COMBINE RESULTS")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.cyan)

                        combineRow(label: "40-YARD DASH", value: String(format: "%.2fs", prospect.combine.fortyYardDash))
                        combineRow(label: "BENCH PRESS", value: "\(prospect.combine.benchPress) REPS")
                        combineRow(label: "VERTICAL", value: String(format: "%.1f\"", prospect.combine.verticalJump))
                        combineRow(label: "BROAD JUMP", value: "\(prospect.combine.broadJump)\"")
                        combineRow(label: "3-CONE", value: String(format: "%.2fs", prospect.combine.threeConeDrill))
                        combineRow(label: "SHUTTLE", value: String(format: "%.2fs", prospect.combine.shuttleRun))
                    }

                    DOSSeparator()

                    // College Stats
                    VStack(alignment: .leading, spacing: 6) {
                        Text("COLLEGE STATS (\(prospect.collegeStats.gamesPlayed) GP)")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.cyan)

                        collegeStatsView(prospect)
                    }

                    DOSSeparator()

                    // Strengths & Weaknesses
                    if !prospect.strengths.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STRENGTHS")
                                .font(RetroFont.bodyBold())
                                .foregroundColor(VGA.green)

                            ForEach(prospect.strengths, id: \.self) { strength in
                                HStack(spacing: 6) {
                                    Text("+")
                                        .foregroundColor(VGA.green)
                                    Text(strength)
                                        .foregroundColor(VGA.white)
                                }
                                .font(RetroFont.body())
                            }
                        }
                    }

                    if !prospect.weaknesses.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("WEAKNESSES")
                                .font(RetroFont.bodyBold())
                                .foregroundColor(VGA.brightRed)

                            ForEach(prospect.weaknesses, id: \.self) { weakness in
                                HStack(spacing: 6) {
                                    Text("-")
                                        .foregroundColor(VGA.brightRed)
                                    Text(weakness)
                                        .foregroundColor(VGA.white)
                                }
                                .font(RetroFont.body())
                            }
                        }
                    }

                    // Draft button (only when it's user's turn)
                    if isUserPick && !isDraftComplete {
                        VStack(spacing: 8) {
                            DOSSeparator()

                            FPSButton("DRAFT PLAYER", width: 200) {
                                draftSelectedProspect()
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(12)
            }
        } else {
            VStack {
                Spacer()
                Text("SELECT A PROSPECT")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.darkGray)
                Text("Click a player on the left")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.darkGray)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Draft Log Panel

    private var draftLogPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DRAFT LOG")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.digitalAmber)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.titleBarBg)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(draftLog.enumerated()), id: \.element.id) { index, entry in
                            HStack(spacing: 0) {
                                Text("RD\(entry.round) PK\(entry.pick): ")
                                    .font(RetroFont.small())
                                    .foregroundColor(VGA.lightGray)

                                Text(entry.teamName)
                                    .font(RetroFont.small())
                                    .foregroundColor(entry.isUserTeam ? VGA.cyan : VGA.white)

                                Text(" selects ")
                                    .font(RetroFont.small())
                                    .foregroundColor(VGA.lightGray)

                                Text("\(entry.playerName) (\(entry.position))")
                                    .font(RetroFont.small())
                                    .foregroundColor(entry.isUserTeam ? VGA.digitalAmber : VGA.white)

                                Text(" from \(entry.college)")
                                    .font(RetroFont.small())
                                    .foregroundColor(VGA.lightGray)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 1)
                            .id(entry.id)
                        }
                    }
                }
                .onChange(of: draftLog.count) { _, _ in
                    if let lastId = draftLog.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(height: 120)
            .background(VGA.screenBg)
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
    }

    // MARK: - Helper Views

    private func scoutingStatBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(RetroFont.tiny())
                .foregroundColor(VGA.lightGray)
            Text(value)
                .font(RetroFont.header())
                .foregroundColor(color)
        }
        .frame(width: 70, height: 44)
        .background(VGA.panelVeryDark)
        .modifier(DOSPanelBorder(.sunken, width: 1))
    }

    private func combineRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(RetroFont.small())
                .foregroundColor(VGA.lightGray)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.white)
        }
    }

    @ViewBuilder
    private func collegeStatsView(_ prospect: DraftEngine.DraftProspect) -> some View {
        let stats = prospect.collegeStats
        let pos = prospect.player.position

        if pos == .quarterback {
            combineRow(label: "PASS YDS", value: "\(stats.passingYards)")
            combineRow(label: "PASS TD", value: "\(stats.passingTDs)")
            if stats.rushingYards > 0 {
                combineRow(label: "RUSH YDS", value: "\(stats.rushingYards)")
            }
        } else if pos == .runningBack {
            combineRow(label: "RUSH YDS", value: "\(stats.rushingYards)")
            combineRow(label: "RUSH TD", value: "\(stats.rushingTDs)")
            if stats.receivingYards > 0 {
                combineRow(label: "REC YDS", value: "\(stats.receivingYards)")
            }
        } else if pos == .wideReceiver || pos == .tightEnd {
            combineRow(label: "REC YDS", value: "\(stats.receivingYards)")
            combineRow(label: "REC TD", value: "\(stats.receivingTDs)")
        } else if pos == .defensiveEnd || pos == .defensiveTackle {
            combineRow(label: "TACKLES", value: "\(stats.tackles)")
            combineRow(label: "SACKS", value: String(format: "%.1f", stats.sacks))
        } else if pos == .outsideLinebacker || pos == .middleLinebacker {
            combineRow(label: "TACKLES", value: "\(stats.tackles)")
            combineRow(label: "SACKS", value: String(format: "%.1f", stats.sacks))
        } else if pos == .cornerback || pos == .freeSafety || pos == .strongSafety {
            combineRow(label: "TACKLES", value: "\(stats.tackles)")
            combineRow(label: "INT", value: "\(stats.interceptions)")
        } else {
            Text("--")
                .font(RetroFont.small())
                .foregroundColor(VGA.darkGray)
        }
    }

    // MARK: - Computed Properties

    private var availableProspects: [DraftEngine.DraftProspect] {
        draftClass.filter { prospect in
            !draftLog.contains(where: { $0.prospectId == prospect.id })
        }
    }

    private var filteredProspects: [DraftEngine.DraftProspect] {
        if let filter = filterPosition {
            return availableProspects.filter { $0.player.position == filter }
        }
        return availableProspects
    }

    private var currentPickingTeam: Team? {
        let pickIndex = currentPick - 1
        guard pickIndex >= 0, pickIndex < draftOrder.count else { return nil }
        return draftOrder[pickIndex]
    }

    private var positionFilterGroups: [Position] {
        [.quarterback, .runningBack, .wideReceiver, .tightEnd,
         .leftTackle, .defensiveEnd, .defensiveTackle,
         .outsideLinebacker, .middleLinebacker, .cornerback, .freeSafety]
    }

    // MARK: - Draft Logic

    private func initializeDraft() {
        guard let league = gameState.currentLeague else { return }

        // Build draft order: reverse standings (worst record picks first)
        let sortedTeams = league.teams.sorted { a, b in
            if a.record.winPercentage != b.record.winPercentage {
                return a.record.winPercentage < b.record.winPercentage
            }
            return a.record.pointDifferential < b.record.pointDifferential
        }
        draftOrder = sortedTeams

        // Generate draft class
        let year = gameState.currentSeason?.year ?? 1993
        draftClass = draftEngine.generateDraftClass(
            year: year,
            numberOfRounds: numberOfRounds,
            teamsCount: league.teams.count
        )

        // Set initial pick state
        currentRound = 1
        currentPick = 1
        updateIsUserPick()
    }

    private func updateIsUserPick() {
        guard let userTeam = gameState.userTeam,
              let pickingTeam = currentPickingTeam else {
            isUserPick = false
            return
        }
        isUserPick = pickingTeam.id == userTeam.id
    }

    private func draftSelectedProspect() {
        guard let prospect = selectedProspect,
              let pickingTeam = currentPickingTeam else { return }

        executePick(prospect: prospect, team: pickingTeam)
    }

    private func autoPickCurrent() {
        guard let pickingTeam = currentPickingTeam else { return }

        let needs = draftEngine.evaluateTeamNeeds(for: pickingTeam)
        if let bestPick = draftEngine.selectBestAvailable(from: availableProspects, for: pickingTeam, needs: needs) {
            executePick(prospect: bestPick, team: pickingTeam)
        }
    }

    private func executePick(prospect: DraftEngine.DraftProspect, team: Team) {
        let isUser = team.id == gameState.userTeam?.id

        let entry = DraftLogEntry(
            round: currentRound,
            pick: currentPick,
            teamName: team.fullName,
            teamId: team.id,
            playerName: prospect.player.fullName,
            position: prospect.player.position.rawValue,
            college: prospect.player.college,
            prospectId: prospect.id,
            isUserTeam: isUser
        )
        draftLog.append(entry)

        // Add player to team roster
        if var league = gameState.currentLeague,
           let teamIndex = league.teams.firstIndex(where: { $0.id == team.id }) {
            var draftedPlayer = prospect.player
            draftedPlayer.contract = Contract.rookie(round: currentRound, pick: currentPick)
            league.teams[teamIndex].addPlayer(draftedPlayer)
            gameState.currentLeague = league

            // Update userTeam reference if it was the user's pick
            if isUser {
                gameState.userTeam = league.teams[teamIndex]
            }
        }

        // Clear selection
        selectedProspect = nil

        // Advance to next pick
        advancePick()
    }

    private func advancePick() {
        let teamsCount = draftOrder.count
        guard teamsCount > 0 else { return }

        if currentPick >= teamsCount {
            // Move to next round
            if currentRound >= numberOfRounds {
                isDraftComplete = true
                return
            }
            currentRound += 1
            currentPick = 1
        } else {
            currentPick += 1
        }

        updateIsUserPick()
    }

    private func simToNextUserPick() {
        guard !isDraftComplete else { return }
        isSimulating = true

        // Run AI picks until it's the user's turn or draft is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            performSimStep()
        }
    }

    private func performSimStep() {
        guard !isDraftComplete, !isUserPick else {
            isSimulating = false
            return
        }

        autoPickCurrent()

        if !isDraftComplete && !isUserPick {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                performSimStep()
            }
        } else {
            isSimulating = false
        }
    }

    // MARK: - Color Helpers

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 90...99: return VGA.green
        case 80...89: return VGA.cyan
        case 70...79: return VGA.digitalAmber
        case 60...69: return VGA.orange
        default: return VGA.brightRed
        }
    }

    private func developmentColor(_ trait: DraftEngine.DevelopmentTrait) -> Color {
        switch trait {
        case .superstar: return VGA.digitalAmber
        case .star: return VGA.green
        case .normal: return VGA.white
        case .slow: return VGA.brightRed
        }
    }

    private func positionColor(_ position: Position) -> Color {
        if position.isOffense { return VGA.cyan }
        if position.isDefense { return VGA.orange }
        return VGA.lightGray
    }

    private func scoutingAccuracyLabel(_ accuracy: Int) -> String {
        switch accuracy {
        case 9...10: return "ELITE"
        case 7...8: return "HIGH"
        case 5...6: return "AVERAGE"
        case 3...4: return "LOW"
        default: return "UNKNOWN"
        }
    }
}

// MARK: - Draft Log Entry

struct DraftLogEntry: Identifiable, Equatable {
    let id = UUID()
    let round: Int
    let pick: Int
    let teamName: String
    let teamId: UUID
    let playerName: String
    let position: String
    let college: String
    let prospectId: UUID
    let isUserTeam: Bool
}
