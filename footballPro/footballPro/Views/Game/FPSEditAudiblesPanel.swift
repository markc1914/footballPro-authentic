//
//  FPSEditAudiblesPanel.swift
//  footballPro
//
//  DOS-style panel for customizing audible assignments.
//  Shows four arrow-key slots with current audible play names.
//  Tap a slot to pick a different play from the playbook.
//

import SwiftUI

struct FPSEditAudiblesPanel: View {
    @ObservedObject var viewModel: GameViewModel
    @Binding var isPresented: Bool

    @State private var editingDirection: AudibleDirection? = nil

    private var isOffense: Bool { viewModel.isUserPossession }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(isOffense ? "OFFENSIVE AUDIBLES" : "DEFENSIVE AUDIBLES")
                    .font(RetroFont.header())
                    .foregroundColor(.white)
                Spacer()
                FPSButton("DONE") {
                    isPresented = false
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(VGA.titleBarBg)

            // Instructions
            Text("Arrow keys change play at the line of scrimmage")
                .font(RetroFont.small())
                .foregroundColor(VGA.lightGray)
                .padding(.vertical, 4)

            // Four audible slots
            VStack(spacing: 2) {
                ForEach(AudibleDirection.allCases, id: \.self) { direction in
                    audibleSlotRow(direction: direction)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Play picker (appears when a slot is being edited)
            if let direction = editingDirection {
                playPicker(for: direction)
            }

            Spacer().frame(height: 4)
        }
        .background(VGA.panelBg)
        .modifier(DOSPanelBorder(.raised, width: 2))
        .frame(maxWidth: 400, maxHeight: 400)
    }

    // MARK: - Audible Slot Row

    private func audibleSlotRow(direction: AudibleDirection) -> some View {
        let audibles = isOffense ? viewModel.offensiveAudibles : viewModel.defensiveAudibles
        let slot: AudibleSlot?
        switch direction {
        case .up: slot = audibles.up
        case .down: slot = audibles.down
        case .left: slot = audibles.left
        case .right: slot = audibles.right
        }

        let arrowSymbol: String
        switch direction {
        case .up: arrowSymbol = "\u{2191}"
        case .down: arrowSymbol = "\u{2193}"
        case .left: arrowSymbol = "\u{2190}"
        case .right: arrowSymbol = "\u{2192}"
        }

        let label = isOffense ? direction.offensiveLabel : direction.defensiveLabel
        let playName = slot?.playName ?? "(none)"
        let isEditing = editingDirection == direction

        return Button(action: {
            if editingDirection == direction {
                editingDirection = nil
            } else {
                editingDirection = direction
            }
        }) {
            HStack(spacing: 6) {
                Text(arrowSymbol)
                    .font(RetroFont.title())
                    .foregroundColor(VGA.digitalAmber)
                    .frame(width: 24)
                Text(label)
                    .font(RetroFont.bodyBold())
                    .foregroundColor(.white)
                    .frame(width: 100, alignment: .leading)
                Text(playName)
                    .font(RetroFont.small())
                    .foregroundColor(isEditing ? .black : VGA.lightGray)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isEditing ? VGA.playSlotSelected : VGA.playSlotGreen)
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Play Picker

    private func playPicker(for direction: AudibleDirection) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("SELECT PLAY FOR \(direction.rawValue.uppercased()) ARROW")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.digitalAmber)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.panelDark)

            ScrollView {
                VStack(spacing: 0) {
                    if isOffense {
                        let plays = viewModel.availableOffensivePlays
                        ForEach(plays.indices, id: \.self) { idx in
                            playPickerRow(name: plays[idx].displayName, index: idx)
                        }
                    } else {
                        let plays = viewModel.availableDefensivePlays
                        ForEach(plays.indices, id: \.self) { idx in
                            playPickerRow(name: plays[idx].displayName, index: idx)
                        }
                    }
                }
            }
            .frame(maxHeight: 120)
            .background(VGA.screenBg)
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }

    private func playPickerRow(name: String, index: Int) -> some View {
        Button(action: {
            assignAudible(index: index)
        }) {
            HStack {
                Text(name)
                    .font(RetroFont.small())
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func assignAudible(index: Int) {
        guard let direction = editingDirection else { return }

        if isOffense {
            let plays = viewModel.availableOffensivePlays
            guard index >= 0 && index < plays.count else { return }
            let play = plays[index]
            let slot = AudibleSlot(
                playName: play.displayName,
                playType: play.playType,
                formationName: play.formationDisplayName,
                playbookIndex: index
            )
            switch direction {
            case .up: viewModel.offensiveAudibles.up = slot
            case .down: viewModel.offensiveAudibles.down = slot
            case .left: viewModel.offensiveAudibles.left = slot
            case .right: viewModel.offensiveAudibles.right = slot
            }
        } else {
            let plays = viewModel.availableDefensivePlays
            guard index >= 0 && index < plays.count else { return }
            let play = plays[index]
            let slot = AudibleSlot(
                playName: play.displayName,
                playType: play.coverage,
                formationName: play.formation.rawValue,
                playbookIndex: index
            )
            switch direction {
            case .up: viewModel.defensiveAudibles.up = slot
            case .down: viewModel.defensiveAudibles.down = slot
            case .left: viewModel.defensiveAudibles.left = slot
            case .right: viewModel.defensiveAudibles.right = slot
            }
        }

        editingDirection = nil
    }
}
