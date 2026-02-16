//
//  FPSPlayCallingScreen.swift
//  footballPro
//
//  FPS Football Pro '93 play calling interface — matched from actual gameplay video
//  Gray frame, green slot grid (1-8 left, 9-16 right), red 3D buttons,
//  scoreboard bar in center, mirror layout for opponent
//

import SwiftUI

struct FPSPlayCallingScreen: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var selectedSlot: Int? = nil
    @State private var showSpecialTeams = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // TOP BAND: Button bar + user play grid
                topButtonBar
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                // Status message
                statusMessageBox
                    .padding(.horizontal, 20)
                    .padding(.vertical, 2)

                // User play slot grid (8 rows)
                playSlotGrid
                    .padding(.horizontal, 4)
                    .frame(maxHeight: .infinity)

                // MIDDLE BAND: Scoreboard
                FPSScoreboardBar(viewModel: viewModel)

                // BOTTOM BAND: Opponent play grid (8 rows)
                opponentSlotGrid
                    .padding(.horizontal, 4)
                    .frame(maxHeight: .infinity)

                // Bottom button bar (mirror)
                bottomButtonBar
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            }
            .background(VGA.panelBg)
        }
    }

    // MARK: - Top Button Bar

    private var topButtonBar: some View {
        HStack(spacing: 0) {
            FPSButton("TIME OUT") {
                viewModel.callTimeout()
            }
            .opacity(viewModel.possessingTeamTimeouts > 0 ? 1.0 : 0.3)
            .disabled(viewModel.possessingTeamTimeouts <= 0)

            Spacer()

            // PREV page button
            FPSButton("< PREV") {
                viewModel.previousPage(isSpecialTeams: showSpecialTeams)
                selectedSlot = nil
            }
            .opacity(viewModel.currentPlaybookPage > 0 ? 1.0 : 0.5)
            .disabled(viewModel.currentPlaybookPage <= 0)

            // Page indicator
            Text("PG \(viewModel.currentPlaybookPage + 1)/\(viewModel.totalPages(isSpecialTeams: showSpecialTeams))")
                .font(RetroFont.small())
                .foregroundColor(.black)
                .padding(.horizontal, 4)

            // NEXT page button
            FPSButton("NEXT >") {
                viewModel.nextPage(isSpecialTeams: showSpecialTeams)
                selectedSlot = nil
            }
            .opacity(viewModel.currentPlaybookPage < viewModel.totalPages(isSpecialTeams: showSpecialTeams) - 1 ? 1.0 : 0.5)
            .disabled(viewModel.currentPlaybookPage >= viewModel.totalPages(isSpecialTeams: showSpecialTeams) - 1)

            Spacer()

            FPSButton(showSpecialTeams ? "REGULAR PLAYS" : "SPECIAL TEAMS") {
                showSpecialTeams.toggle()
                viewModel.currentPlaybookPage = 0
                selectedSlot = nil
            }

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
        HStack(spacing: 0) {
            FPSButton("TIME OUT") { }
                .disabled(true)

            Spacer()

            FPSButton(showSpecialTeams ? "REGULAR PLAYS" : "SPECIAL TEAMS") { }
                .disabled(true)

            Spacer()

            FPSButton("READY - BREAK!") { }
                .disabled(true)
        }
    }

    // MARK: - Status Message (raised gray box with black text, like original)

    private var statusMessageBox: some View {
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

    private func downOrdinal(_ down: Int) -> String {
        switch down {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        default: return "\(down)th"
        }
    }

    // MARK: - Play Slot Grid (8 rows, numbers 1-8 left / 9-16 right)

    private var playSlotGrid: some View {
        VStack(spacing: 1) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 0) {
                    // Left number (1-8)
                    Text("\(row + 1)")
                        .font(RetroFont.bodyBold())
                        .foregroundColor(.black)
                        .frame(width: 18, alignment: .trailing)
                        .padding(.trailing, 2)

                    // Left play slots (row spans from slot 1-8 on left side)
                    greenSlot(number: row + 1, name: playNameForSlot(row + 1))

                    // Right play slots (slots 9-16)
                    greenSlot(number: row + 9, name: playNameForSlot(row + 9))

                    // Right number (9-16)
                    Text("\(row + 9)")
                        .font(RetroFont.bodyBold())
                        .foregroundColor(.black)
                        .frame(width: 18, alignment: .leading)
                        .padding(.leading, 2)
                }
            }
        }
    }

    // MARK: - Green Slot View

    private func greenSlot(number: Int, name: String) -> some View {
        Button(action: {
            if !name.isEmpty && name != "---" {
                selectedSlot = number
            }
        }) {
            HStack {
                if !name.isEmpty && name != "---" {
                    Text(name)
                        .font(RetroFont.small())
                        .foregroundColor(selectedSlot == number ? .black : .white)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selectedSlot == number ? VGA.playSlotSelected : VGA.playSlotGreen)
            .border(VGA.playSlotDark, width: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Opponent Slot Grid (hidden plays with notification overlay)

    private var opponentSlotGrid: some View {
        ZStack {
            VStack(spacing: 1) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 0) {
                        Text("\(row + 1)")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(.black)
                            .frame(width: 18, alignment: .trailing)
                            .padding(.trailing, 2)

                        // Empty green slots for opponent
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(VGA.playSlotGreen)
                                .border(VGA.playSlotDark, width: 1)
                            Rectangle()
                                .fill(VGA.playSlotGreen)
                                .border(VGA.playSlotDark, width: 1)
                        }

                        Text("\(row + 9)")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(.black)
                            .frame(width: 18, alignment: .leading)
                            .padding(.leading, 2)
                    }
                }
            }

            // Opponent notification panel (raised gray panel like original FPS '93)
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
        return "\(opponentName) has called a regular play"
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
                    Task { await viewModel.punt() }
                } else if upper.contains("FG") || upper.contains("PAT") {
                    Task { await viewModel.attemptFieldGoal() }
                } else if upper.contains("KICK") {
                    // Kickoff — run as regular play for now
                    viewModel.selectedOffensivePlay = play
                    Task { await viewModel.runPlay() }
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