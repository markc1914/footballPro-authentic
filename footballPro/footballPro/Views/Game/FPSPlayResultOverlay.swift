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

    var body: some View {
        VStack {
            Spacer()

            // Dark charcoal result box (field visible behind)
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

                    // 4th down options or standard buttons
                    if viewModel.game?.downAndDistance.down == 4 {
                        // 4th down: show team name + Quick Huddle / Select Play
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
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Attributed Description (color team names)

    private func attributedDescription(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = VGA.white
        result.font = RetroFont.body()

        // Highlight home team name in cyan
        if let home = viewModel.homeTeam {
            for name in [home.name, home.fullName, home.city] {
                if let range = result.range(of: name, options: .caseInsensitive) {
                    result[range].foregroundColor = VGA.cyan
                }
            }
        }

        // Highlight away team name in red
        if let away = viewModel.awayTeam {
            for name in [away.name, away.fullName, away.city] {
                if let range = result.range(of: name, options: .caseInsensitive) {
                    result[range].foregroundColor = VGA.brightRed
                }
            }
        }

        return result
    }
}
