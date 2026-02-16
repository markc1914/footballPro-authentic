//
//  FPSPlayResultOverlay.swift
//  footballPro
//
//  FPS '93 play result — dark charcoal text box overlaid on field (field visible behind)
//  White text with team names highlighted in cyan/red, Instant Replay + Continue buttons
//  Matched from actual gameplay video frames
//

import SwiftUI

struct FPSPlayResultOverlay: View {
    @ObservedObject var viewModel: GameViewModel

    /// Whether this result is from a FG/PAT (shows on black background instead of field)
    private var isSpecialResult: Bool {
        guard let result = viewModel.lastPlayResult else { return false }
        let desc = result.description.uppercased()
        return desc.contains("FIELD GOAL") || desc.contains("EXTRA POINT") || desc.contains("PAT")
    }

    var body: some View {
        ZStack {
            // FG/PAT results show on black background
            if isSpecialResult {
                Color.black.ignoresSafeArea()
            }

            // Center the overlay vertically, slightly left of center
            GeometryReader { geo in
                resultBox
                    .frame(maxWidth: 500)
                    .position(x: geo.size.width * 0.45, y: geo.size.height * 0.5)
            }
        }
    }

    private var resultBox: some View {
        VStack(spacing: 6) {
            if let result = viewModel.lastPlayResult {
                // Play description with colored team names
                Text(attributedDescription(result.description))
                    .font(RetroFont.body())
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                // Down and distance info
                if let game = viewModel.game {
                    Text("\(game.downAndDistance.displayDownAndDistance).")
                        .font(RetroFont.body())
                        .foregroundColor(VGA.white)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                }

                // User offense: show Quick Huddle / Select Play
                // User defense: show Instant Replay / Continue
                if viewModel.isUserPossession {
                    VStack(spacing: 4) {
                        Text(viewModel.possessionTeamName)
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.white)

                        HStack(spacing: 16) {
                            FPSButton("Quick Huddle") {
                                viewModel.continueAfterResult()
                            }
                            FPSButton("Select Play") {
                                viewModel.continueAfterResult()
                            }
                        }
                    }
                    .padding(.vertical, 6)
                } else {
                    HStack(spacing: 16) {
                        FPSButton("Instant Replay") {
                            viewModel.enterReplay()
                        }
                        FPSButton("Continue") {
                            viewModel.continueAfterResult()
                        }
                    }
                    .padding(.vertical, 6)
                }
            } else {
                Text("Play complete")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.lightGray)
                    .padding(12)

                FPSButton("Continue") {
                    viewModel.continueAfterResult()
                }
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: 500)
        .background(VGA.panelVeryDark.opacity(0.92))
        .modifier(DOSPanelBorder(.raised, width: 1))
    }

    // MARK: - Attributed Description (color team names by possession)

    private func attributedDescription(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = VGA.white
        result.font = RetroFont.body()

        // Possessing team highlighted in cyan, opposing team in red
        let possTeam = viewModel.game?.isHomeTeamPossession == true ? viewModel.homeTeam : viewModel.awayTeam
        let oppTeam = viewModel.game?.isHomeTeamPossession == true ? viewModel.awayTeam : viewModel.homeTeam

        if let team = possTeam {
            for name in [team.name, team.fullName, team.city] {
                if let range = result.range(of: name, options: .caseInsensitive) {
                    result[range].foregroundColor = VGA.teamCyan
                }
            }
        }

        if let team = oppTeam {
            for name in [team.name, team.fullName, team.city] {
                if let range = result.range(of: name, options: .caseInsensitive) {
                    result[range].foregroundColor = VGA.teamRed
                }
            }
        }

        return result
    }
}
