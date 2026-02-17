//
//  FPSPlayCallingScreen.swift
//  footballPro
//
//  FPS Football Pro '93 play calling interface — matched from actual gameplay video
//  Gray frame, green slot grid (2 columns x 8 rows), red 3D buttons,
//  scoreboard bar in center, mirror layout for opponent
//

import SwiftUI

struct FPSPlayCallingScreen: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var selectedSlot: Int? = nil
    @State private var showSpecialTeams = false
    @State private var showSubstitution = false
    @State private var showEditAudibles = false

    var body: some View {
        ZStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // TOP BAND: Button bar + user play grid
                    topButtonBar
                        .padding(.horizontal, 4)
                        .padding(.top, 4)

                    // User play slot grid (2 cols x 8 rows) with status overlay
                    ZStack {
                        playSlotGrid

                        // Status message overlaid in CENTER of user's grid (like original)
                        statusMessageOverlay
                    }
                    .padding(.horizontal, 4)
                    .frame(maxHeight: .infinity)

                    // MIDDLE BAND: Scoreboard
                    FPSScoreboardBar(viewModel: viewModel)

                    // BOTTOM BAND: Opponent play grid (2 cols x 8 rows) with notification overlay
                    opponentSlotGrid
                        .padding(.horizontal, 4)
                        .frame(maxHeight: .infinity)

                    // Bottom button bar (mirror)
                    bottomButtonBar
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                }
                .background(VGA.panelBg)
                .onAppear {
                    if viewModel.game?.isKickoff == true || viewModel.game?.isExtraPoint == true {
                        showSpecialTeams = true
                    }
                }
                .onKeyPress(.leftArrow) {
                    viewModel.previousPage(isSpecialTeams: showSpecialTeams)
                    selectedSlot = nil
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    viewModel.nextPage(isSpecialTeams: showSpecialTeams)
                    selectedSlot = nil
                    return .handled
                }
                .onKeyPress(.tab) {
                    showSpecialTeams.toggle()
                    viewModel.currentPlaybookPage = 0
                    selectedSlot = nil
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "sS")) { _ in
                    showSubstitution = true
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "aA")) { _ in
                    showEditAudibles = true
                    return .handled
                }
            }

            // Substitution overlay panel
            if showSubstitution {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { showSubstitution = false }
                FPSSubstitutionPanel(viewModel: viewModel, isPresented: $showSubstitution)
            }

            // Edit Audibles overlay panel
            if showEditAudibles {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { showEditAudibles = false }
                FPSEditAudiblesPanel(viewModel: viewModel, isPresented: $showEditAudibles)
            }
        }
    }

    // MARK: - Top Button Bar

    private var topButtonBar: some View {
        HStack(spacing: 4) {
            FPSButton("TIME OUT") {
                viewModel.callTimeout()
            }
            .opacity(viewModel.possessingTeamTimeouts > 0 ? 1.0 : 0.3)
            .disabled(viewModel.possessingTeamTimeouts <= 0)

            Spacer()

            FPSButton("READY - BREAK!") {
                executeSelectedPlay()
            }
            .opacity(selectedSlot != nil ? 1.0 : 0.5)
            .disabled(selectedSlot == nil)
        }
    }

    // MARK: - Bottom Button Bar (mirror)

    private var bottomButtonBar: some View {
        HStack(spacing: 4) {
            FPSButton("TIME OUT") { }
                .disabled(true)
                .opacity(0.3)

            Spacer()

            FPSButton("READY - BREAK!") { }
                .disabled(true)
                .opacity(0.3)
        }
    }

    // MARK: - Status Message Overlay (centered over user's play grid, like original FPS '93)

    private var statusMessageOverlay: some View {
        Text(statusText)
            .font(RetroFont.body())
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(VGA.panelBg)
            .modifier(DOSPanelBorder(.raised, width: 1))
    }

    private var statusText: String {
        let teamName = viewModel.possessionTeamName
        // Show selected play info when a slot is selected
        if let slot = selectedSlot, let playInfo = selectedPlayInfo(slot) {
            return playInfo
        }
        if showSpecialTeams {
            return "\(teamName) is in a special teams formation"
        }
        if let game = viewModel.game {
            let down = game.downAndDistance.down
            let toGo = game.downAndDistance.yardsToGo
            let yard = game.fieldPosition.displayYardLine
            return "\(teamName) — \(downOrdinal(down)) and \(toGo) on \(yard)"
        }
        return "\(teamName) has called a regular play"
    }

    private func selectedPlayInfo(_ slot: Int) -> String? {
        let globalIndex = globalIndexForSlot(slot)
        if viewModel.isUserPossession {
            let plays = showSpecialTeams ? viewModel.availableSpecialTeamsPlays : viewModel.availableOffensivePlays
            guard globalIndex >= 0 && globalIndex < plays.count else { return nil }
            let play = plays[globalIndex]
            let formation = play.formationDisplayName
            let category = play.displayName
            return "\(category)  [\(formation)]"
        } else {
            let plays = viewModel.availableDefensivePlays
            guard globalIndex >= 0 && globalIndex < plays.count else { return nil }
            let play = plays[globalIndex]
            return "\(play.displayName)  [\(play.play.formationName)]"
        }
    }

    private func downOrdinal(_ down: Int) -> String {
        switch down {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        default: return "\(down)th"
        }
    }

    // MARK: - Play Slot Grid (2 columns x 8 rows = 16 slots, matching original FPS '93)
    // Left column = slots 1-8, right column = slots 9-16
    // Row numbers 1-8 on far left, 9-16 on far right

    private var playSlotGrid: some View {
        VStack(spacing: 1) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 0) {
                    // Row number on far left (1-8)
                    Text("\(row + 1)")
                        .font(RetroFont.bodyBold())
                        .foregroundColor(.white)
                        .frame(width: 16, alignment: .trailing)
                        .padding(.trailing, 2)

                    // Left column slot (slots 1-8)
                    let leftSlot = row + 1
                    greenSlot(number: leftSlot, name: playNameForSlot(leftSlot))

                    // Right column slot (slots 9-16)
                    let rightSlot = row + 9
                    greenSlot(number: rightSlot, name: playNameForSlot(rightSlot))

                    // Row number on far right (9-16)
                    Text("\(row + 9)")
                        .font(RetroFont.bodyBold())
                        .foregroundColor(.white)
                        .frame(width: 16, alignment: .leading)
                        .padding(.leading, 2)
                }
            }
        }
    }

    // MARK: - Green Slot View

    private func greenSlot(number: Int, name: String) -> some View {
        let isSelected = selectedSlot == number
        let hasPlay = !name.isEmpty && name != "---"
        let rawPlayName = rawPlayNameForSlot(number)
        let isOffensive = viewModel.isUserPossession
        let diagram = hasPlay ? MiniDiagramCache.shared.diagram(
            forPlayName: rawPlayName, isOffensive: isOffensive
        ) : nil

        return Button(action: {
            if hasPlay {
                selectedSlot = number
            }
        }) {
            VStack(spacing: 0) {
                if hasPlay {
                    if let diagram = diagram {
                        // Diagram + play name layout
                        MiniPlayDiagramView(diagram: diagram, isSelected: isSelected)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Text(name)
                            .font(RetroFont.tiny())
                            .foregroundColor(isSelected ? .black : .white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 1)
                    } else {
                        // Text-only fallback (no STOCK.DAT data)
                        HStack {
                            Text(name)
                                .font(RetroFont.small())
                                .foregroundColor(isSelected ? .black : .white)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? VGA.playSlotSelected : VGA.playSlotGreen)
            .border(VGA.playSlotDark, width: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Opponent Slot Grid (2 columns x 8 rows, showing opponent's plays like original FPS '93)

    /// The opponent's plays: when user is on offense, show defensive plays; when on defense, show offensive plays.
    /// During special teams, show special teams plays. The AI-recommended play is highlighted.
    private var opponentPlays: [String] {
        if showSpecialTeams {
            return viewModel.availableSpecialTeamsPlays.map { $0.displayName }
        }
        if viewModel.isUserPossession {
            // User on offense — opponent is on defense
            return viewModel.availableDefensivePlays.map { $0.displayName }
        } else {
            // User on defense — opponent is on offense
            return viewModel.availableOffensivePlays.map { $0.displayName }
        }
    }

    /// Index of the AI-recommended play within opponentPlays (deterministic pick, stable per play).
    /// Uses a simple offset into the list to simulate "computer recommends" highlight from original.
    private var aiRecommendedIndex: Int? {
        let plays = opponentPlays
        guard !plays.isEmpty else { return nil }
        // Pick a deterministic "recommended" play — roughly first third of the list
        let pick = plays.count / 3
        return min(pick, plays.count - 1)
    }

    private var opponentSlotGrid: some View {
        let plays = opponentPlays
        let hasPlays = !plays.isEmpty

        return ZStack {
            VStack(spacing: 1) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 0) {
                        // Row number on far left (1-8)
                        Text("\(row + 1)")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(.white)
                            .frame(width: 16, alignment: .trailing)
                            .padding(.trailing, 2)

                        // Left column slot (slots 1-8)
                        let leftIndex = row
                        opponentGreenSlot(
                            name: leftIndex < plays.count ? plays[leftIndex] : "",
                            isRecommended: leftIndex == aiRecommendedIndex
                        )

                        // Right column slot (slots 9-16)
                        let rightIndex = row + 8
                        opponentGreenSlot(
                            name: rightIndex < plays.count ? plays[rightIndex] : "",
                            isRecommended: rightIndex == aiRecommendedIndex
                        )

                        // Row number on far right (9-16)
                        Text("\(row + 9)")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(.white)
                            .frame(width: 16, alignment: .leading)
                            .padding(.leading, 2)
                    }
                }
            }

            // Show notification overlay only when there are no plays to display
            if !hasPlays {
                Text(opponentNotificationText)
                    .font(RetroFont.body())
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(VGA.panelBg)
                    .modifier(DOSPanelBorder(.raised, width: 1))
            }
        }
    }

    /// Opponent grid slot: non-interactive, shows play name in white text on green background.
    /// The AI-recommended play gets a white border and amber text (like original FPS '93 "computer recommends").
    private func opponentGreenSlot(name: String, isRecommended: Bool) -> some View {
        let hasPlay = !name.isEmpty
        return HStack {
            if hasPlay {
                Text(name)
                    .font(RetroFont.small())
                    .foregroundColor(isRecommended ? VGA.digitalAmber : .white)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VGA.playSlotGreen)
        .border(isRecommended && hasPlay ? Color.white : VGA.playSlotDark, width: isRecommended && hasPlay ? 2 : 1)
    }

    private var opponentNotificationText: String {
        // When user is on offense, opponent = defense (non-possessing team)
        // When user is on defense, opponent = offense (possessing team)
        let opponentName: String
        if viewModel.isUserPossession {
            // User has the ball — opponent is the other team
            if let game = viewModel.game {
                let defTeam = game.isHomeTeamPossession ? viewModel.awayTeam : viewModel.homeTeam
                opponentName = defTeam?.name ?? "Opponent"
            } else {
                opponentName = "Opponent"
            }
        } else {
            opponentName = viewModel.possessionTeamName
        }
        if showSpecialTeams {
            return "\(opponentName) is in a special teams formation"
        }
        let page = viewModel.currentPlaybookPage + 1
        let total = viewModel.totalPages(isSpecialTeams: showSpecialTeams)
        return "\(opponentName) has called a regular play — page \(page)/\(total)"
    }

    // MARK: - Play Data (reads from viewModel's authentic playbook)

    private func playNameForSlot(_ number: Int) -> String {
        let pagePlays = viewModel.currentPagePlays(isSpecialTeams: showSpecialTeams)
        let index = number - 1
        if index >= 0 && index < pagePlays.count {
            return pagePlays[index]
        }
        return ""
    }

    /// Returns the raw (8-char) play name for STOCK.DAT lookup, not the human-readable display name.
    private func rawPlayNameForSlot(_ number: Int) -> String {
        let globalIndex = globalIndexForSlot(number)
        if viewModel.isUserPossession {
            let plays = showSpecialTeams ? viewModel.availableSpecialTeamsPlays : viewModel.availableOffensivePlays
            guard globalIndex >= 0 && globalIndex < plays.count else { return "" }
            return plays[globalIndex].play.name
        } else {
            let plays = viewModel.availableDefensivePlays
            guard globalIndex >= 0 && globalIndex < plays.count else { return "" }
            return plays[globalIndex].play.name
        }
    }

    /// Resolve the global index of a slot on the current page
    private func globalIndexForSlot(_ slot: Int) -> Int {
        return viewModel.currentPlaybookPage * viewModel.playsPerPage + (slot - 1)
    }

    // MARK: - Execute Play

    private func executeSelectedPlay() {
        guard let slot = selectedSlot else { return }
        let globalIndex = globalIndexForSlot(slot)

        if viewModel.isUserPossession {
            if showSpecialTeams {
                let stPlays = viewModel.availableSpecialTeamsPlays
                guard globalIndex >= 0 && globalIndex < stPlays.count else { return }
                let play = stPlays[globalIndex]

                // Check for special teams actions by name
                let upper = play.play.name.uppercased()
                if upper.contains("PUNT") {
                    viewModel.startKickingMinigame(.punt)
                } else if upper.contains("FG") || upper.contains("PAT") {
                    viewModel.startKickingMinigame(.fieldGoal)
                } else if upper.contains("ONSIDE") {
                    Task { await viewModel.executeOnsideKick() }
                } else if upper.contains("KICK") {
                    viewModel.startKickingMinigame(.kickoff)
                } else {
                    viewModel.selectedOffensivePlay = play
                    Task { await viewModel.runPlay() }
                }
            } else {
                let offPlays = viewModel.availableOffensivePlays
                guard globalIndex >= 0 && globalIndex < offPlays.count else { return }
                let play = offPlays[globalIndex]
                // Play art decoding happens inside runPlay() for AuthenticPlayCall
                viewModel.selectedOffensivePlay = play
                Task { await viewModel.runPlay() }
            }
        } else {
            let defPlays = viewModel.availableDefensivePlays
            guard globalIndex >= 0 && globalIndex < defPlays.count else { return }
            let play = defPlays[globalIndex]
            viewModel.selectedDefensivePlay = play
            Task { await viewModel.runPlay() }
        }

        selectedSlot = nil
    }
}
