//
//  FPSScoreboardBar.swift
//  footballPro
//
//  FPS Football Pro '93 scoreboard bar — matched from actual gameplay video frames
//  Two-row layout: Away team top, Home team bottom
//  QTR column headers between rows, game clock + situation on right side
//

import SwiftUI

struct FPSScoreboardBar: View {
    @ObservedObject var viewModel: GameViewModel

    // Random wind generated once per game (cosmetic display)
    @State private var windDirection: String = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"].randomElement()!
    @State private var windSpeed: Int = Int.random(in: 0...15)

    var body: some View {
        if let game = viewModel.game {
            HStack(spacing: 0) {
                // Left section: Team names + scores in two rows with QTR headers
                VStack(spacing: 0) {
                    // Row 1: Away team
                    teamRow(
                        name: viewModel.awayTeam?.name ?? "Away",
                        rating: viewModel.awayTeam?.overallRating,
                        hasPossession: !game.isHomeTeamPossession,
                        quarterScores: quarterScoresArray(game: game, isHome: false),
                        totalScore: game.score.awayScore,
                        currentQuarter: game.clock.quarter
                    )

                    // QTR header row (column labels between team rows)
                    HStack(spacing: 0) {
                        // Team name placeholder space
                        Spacer().frame(width: 120)

                        Text("1")
                            .font(RetroFont.tiny())
                            .foregroundColor(game.clock.quarter == 1 ? VGA.digitalAmber : VGA.lightGray)
                            .frame(width: 28)
                        Text("2")
                            .font(RetroFont.tiny())
                            .foregroundColor(game.clock.quarter == 2 ? VGA.digitalAmber : VGA.lightGray)
                            .frame(width: 28)
                        Text("3")
                            .font(RetroFont.tiny())
                            .foregroundColor(game.clock.quarter == 3 ? VGA.digitalAmber : VGA.lightGray)
                            .frame(width: 28)
                        Text("4")
                            .font(RetroFont.tiny())
                            .foregroundColor(game.clock.quarter == 4 ? VGA.digitalAmber : VGA.lightGray)
                            .frame(width: 28)
                        Text("TOTAL")
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.lightGray)
                            .frame(width: 48)
                    }
                    .frame(height: 12)

                    // Row 2: Home team
                    teamRow(
                        name: viewModel.homeTeam?.name ?? "Home",
                        rating: viewModel.homeTeam?.overallRating,
                        hasPossession: game.isHomeTeamPossession,
                        quarterScores: quarterScoresArray(game: game, isHome: true),
                        totalScore: game.score.homeScore,
                        currentQuarter: game.clock.quarter
                    )
                }
                .frame(width: 280)

                // Center: Game clock + WIND
                VStack(spacing: 2) {
                    FPSDigitalClock(time: game.clock.displayTime, fontSize: 20)

                    HStack(spacing: 4) {
                        Text("WIND")
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.lightGray)
                        Text("\(windDirection) \(String(format: "%02d", windSpeed))")
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.white)
                    }
                }
                .frame(width: 110)

                // Right section: Situation (two rows: away timeouts top, home timeouts bottom + DOWN/TO GO/BALL ON)
                VStack(spacing: 2) {
                    // Away team timeouts row
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Text("T/O")
                                .font(RetroFont.tiny())
                                .foregroundColor(VGA.lightGray)
                            Text("\(game.awayTimeouts)")
                                .font(RetroFont.small())
                                .foregroundColor(VGA.digitalAmber)
                        }

                        Spacer()
                    }

                    // Situation data row
                    HStack(spacing: 8) {
                        VStack(spacing: 0) {
                            Text("DOWN")
                                .font(RetroFont.tiny())
                                .foregroundColor(VGA.lightGray)
                            Text("\(game.downAndDistance.down)")
                                .font(RetroFont.small())
                                .foregroundColor(VGA.digitalAmber)
                        }

                        VStack(spacing: 0) {
                            Text("TO GO")
                                .font(RetroFont.tiny())
                                .foregroundColor(VGA.lightGray)
                            Text("\(game.downAndDistance.yardsToGo)")
                                .font(RetroFont.small())
                                .foregroundColor(VGA.white)
                        }

                        VStack(spacing: 0) {
                            Text("BALL ON")
                                .font(RetroFont.tiny())
                                .foregroundColor(VGA.lightGray)
                            Text(game.fieldPosition.displayYardLine)
                                .font(RetroFont.small())
                                .foregroundColor(VGA.digitalAmber)
                        }

                        VStack(spacing: 0) {
                            Text("PLAY CLK")
                                .font(RetroFont.tiny())
                                .foregroundColor(VGA.lightGray)
                            FPSDigitalClock(time: "\(viewModel.playClockSeconds)", fontSize: 12)
                        }
                    }

                    // Home team timeouts row
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Text("T/O")
                                .font(RetroFont.tiny())
                                .foregroundColor(VGA.lightGray)
                            Text("\(game.homeTimeouts)")
                                .font(RetroFont.small())
                                .foregroundColor(VGA.digitalAmber)
                        }

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
            }
            .frame(height: 60)
            .background(VGA.panelVeryDark)
            .modifier(DOSPanelBorder(.raised, width: 1))
        }
    }

    // MARK: - Team Row

    private func teamRow(
        name: String,
        rating: Int?,
        hasPossession: Bool,
        quarterScores: [String],
        totalScore: Int,
        currentQuarter: Int
    ) -> some View {
        HStack(spacing: 0) {
            // Team name + possession football + rating
            HStack(spacing: 3) {
                Text(name)
                    .font(RetroFont.small())
                    .foregroundColor(VGA.white)
                    .lineLimit(1)

                // Possession indicator (small football shape)
                if hasPossession {
                    Ellipse()
                        .fill(VGA.digitalAmber)
                        .frame(width: 8, height: 5)
                }

                if let rating = rating {
                    Text("(\(rating))")
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.digitalAmber)
                }
            }
            .frame(width: 120, alignment: .leading)
            .padding(.leading, 4)

            // Quarter scores
            ForEach(0..<4, id: \.self) { q in
                Text(quarterScores[q])
                    .font(RetroFont.small())
                    .foregroundColor(VGA.white)
                    .frame(width: 28)
            }

            // Total
            Text(String(format: "%02d", totalScore))
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.white)
                .frame(width: 48)
        }
        .frame(height: 16)
    }

    // MARK: - Helpers

    private func quarterScoresArray(game: Game, isHome: Bool) -> [String] {
        let scores = isHome ? game.score.homeQuarterScores : game.score.awayQuarterScores
        return (0..<4).map { i in
            if i < scores.count {
                return String(format: "%02d", scores[i])
            }
            return "00"
        }
    }
}
