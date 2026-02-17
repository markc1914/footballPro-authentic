//
//  FPSSubstitutionPanel.swift
//  footballPro
//
//  DOS-style substitution window for swapping players during play calling.
//  Shows current starters by position group with jersey#, name, rating, energy bar.
//  Tap a player to see available substitutes, confirm swap with SUBSTITUTE button.
//

import SwiftUI

struct FPSSubstitutionPanel: View {
    @ObservedObject var viewModel: GameViewModel
    @Binding var isPresented: Bool

    @State private var selectedPosition: Position? = nil
    @State private var selectedReplacementId: UUID? = nil

    /// Position groups to display, in order
    private let offensivePositions: [Position] = [
        .quarterback, .runningBack, .fullback, .wideReceiver, .tightEnd,
        .leftTackle, .leftGuard, .center, .rightGuard, .rightTackle
    ]
    private let defensivePositions: [Position] = [
        .defensiveEnd, .defensiveTackle, .middleLinebacker, .outsideLinebacker,
        .cornerback, .freeSafety, .strongSafety
    ]

    private var positions: [Position] {
        viewModel.isUserPossession ? offensivePositions : defensivePositions
    }

    private var team: Team? {
        viewModel.userTeamForSubstitution
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("SUBSTITUTIONS")
                    .font(RetroFont.header())
                    .foregroundColor(.white)
                Spacer()
                FPSButton("CLOSE") {
                    isPresented = false
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(VGA.titleBarBg)

            // Column headers
            HStack(spacing: 0) {
                Text("POS")
                    .frame(width: 36, alignment: .leading)
                Text("NO")
                    .frame(width: 28, alignment: .trailing)
                Text("NAME")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
                Text("OVR")
                    .frame(width: 32, alignment: .trailing)
                Text("ENERGY")
                    .frame(width: 60, alignment: .center)
            }
            .font(RetroFont.tiny())
            .foregroundColor(VGA.lightGray)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(VGA.panelDark)

            // Starter list
            ScrollView {
                VStack(spacing: 0) {
                    if let team = team {
                        ForEach(positions, id: \.self) { position in
                            if let starter = team.starter(at: position) {
                                starterRow(player: starter, position: position, team: team)
                            }
                        }
                    } else {
                        Text("No team data available")
                            .font(RetroFont.body())
                            .foregroundColor(VGA.darkGray)
                            .padding()
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(VGA.screenBg)
            .modifier(DOSPanelBorder(.sunken, width: 1))
            .padding(.horizontal, 4)
            .padding(.top, 2)

            // Substitute selection (appears when a position is selected)
            if let pos = selectedPosition, let team = team {
                substituteList(position: pos, team: team)
            }
        }
        .background(VGA.panelBg)
        .modifier(DOSPanelBorder(.raised, width: 2))
        .frame(maxWidth: 420, maxHeight: 450)
    }

    // MARK: - Starter Row

    private func starterRow(player: Player, position: Position, team: Team) -> some View {
        let isSelected = selectedPosition == position
        return Button(action: {
            if selectedPosition == position {
                selectedPosition = nil
                selectedReplacementId = nil
            } else {
                selectedPosition = position
                selectedReplacementId = nil
            }
        }) {
            HStack(spacing: 0) {
                Text(position.rawValue)
                    .frame(width: 36, alignment: .leading)
                Text("\(player.jerseyNumber)")
                    .frame(width: 28, alignment: .trailing)
                Text(player.lastName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
                    .lineLimit(1)
                Text("\(player.overall)")
                    .frame(width: 32, alignment: .trailing)
                // Energy bar
                energyBar(fatigue: player.status.fatigue)
                    .frame(width: 56, height: 10)
                    .padding(.leading, 4)
            }
            .font(RetroFont.small())
            .foregroundColor(isSelected ? .black : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isSelected ? VGA.playSlotSelected : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Substitute List

    private func substituteList(position: Position, team: Team) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("AVAILABLE AT \(position.rawValue)")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.digitalAmber)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.panelDark)

            let backupIds = team.depthChart.backups(at: position)
            let backups = backupIds.compactMap { id in team.player(withId: id) }

            if backups.isEmpty {
                Text("No backups available")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.darkGray)
                    .padding(8)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(backups, id: \.id) { backup in
                            substituteRow(player: backup, position: position)
                        }
                    }
                }
                .frame(maxHeight: 100)
                .background(VGA.screenBg)
                .modifier(DOSPanelBorder(.sunken, width: 1))
            }

            // Action buttons
            HStack {
                Spacer()
                FPSButton("SUBSTITUTE") {
                    if let replacementId = selectedReplacementId {
                        viewModel.substitutePlayer(
                            teamIsHome: viewModel.isUserHome,
                            position: position,
                            starterIndex: 0,
                            replacementId: replacementId
                        )
                        selectedPosition = nil
                        selectedReplacementId = nil
                    }
                }
                .opacity(selectedReplacementId != nil ? 1.0 : 0.3)
                .disabled(selectedReplacementId == nil)

                Spacer()

                FPSButton("CANCEL") {
                    selectedPosition = nil
                    selectedReplacementId = nil
                }

                Spacer()
            }
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func substituteRow(player: Player, position: Position) -> some View {
        let isSelected = selectedReplacementId == player.id
        return Button(action: {
            selectedReplacementId = player.id
        }) {
            HStack(spacing: 0) {
                Text(position.rawValue)
                    .frame(width: 36, alignment: .leading)
                Text("\(player.jerseyNumber)")
                    .frame(width: 28, alignment: .trailing)
                Text(player.lastName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
                    .lineLimit(1)
                Text("\(player.overall)")
                    .frame(width: 32, alignment: .trailing)
                energyBar(fatigue: player.status.fatigue)
                    .frame(width: 56, height: 10)
                    .padding(.leading, 4)
            }
            .font(RetroFont.small())
            .foregroundColor(isSelected ? .black : VGA.lightGray)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isSelected ? VGA.playSlotSelected : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Energy Bar

    private func energyBar(fatigue: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Black background
                Rectangle()
                    .fill(Color.black)

                // Green fill proportional to remaining energy (100 - fatigue)
                let energy = max(0, min(100, 100 - fatigue))
                let fillWidth = geo.size.width * CGFloat(energy) / 100.0
                Rectangle()
                    .fill(Color(red: 0.15, green: 0.58, blue: 0.15))  // VGA.playSlotGreen equivalent
                    .frame(width: fillWidth)
            }
        }
    }
}
