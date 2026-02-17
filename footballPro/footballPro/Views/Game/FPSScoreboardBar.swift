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

    // Wind display — uses GameWeather if available, falls back to random
    @State private var fallbackWindDirection: String = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"].randomElement()!
    @State private var fallbackWindSpeed: Int = Int.random(in: 0...15)

    // Dark scoreboard background matching original FPS '93 (near-black)
    private let scoreboardBg = Color(red: 0.05, green: 0.05, blue: 0.06) // ~#0D0D0F
    // Slightly lighter cell background for subtle depth
    private let cellBg = Color(red: 0.08, green: 0.08, blue: 0.10) // ~#141419
    // Border/separator color for beveled cell edges
    private let borderLight = Color(red: 0.25, green: 0.25, blue: 0.28) // raised edge highlight
    private let borderDark = Color(red: 0.06, green: 0.06, blue: 0.08)  // shadow edge
    // Label color — brighter than before for contrast on dark bg
    private let labelColor = Color(red: 0.70, green: 0.70, blue: 0.72) // ~#B3B3B8

    private var windDirection: String {
        viewModel.game?.gameWeather?.windDirectionName ?? fallbackWindDirection
    }
    private var windSpeed: Int {
        viewModel.game?.gameWeather?.windSpeed ?? fallbackWindSpeed
    }

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
                        HStack(spacing: 3) {
                            Text("QTR:")
                                .font(RetroFont.tiny())
                                .foregroundColor(labelColor)
                        }
                        .frame(width: 120, alignment: .trailing)
                        .padding(.trailing, 4)

                        Text("1")
                            .font(RetroFont.tiny())
                            .foregroundColor(game.clock.quarter == 1 ? VGA.digitalAmber : labelColor)
                            .frame(width: 28)
                        Text("2")
                            .font(RetroFont.tiny())
                            .foregroundColor(game.clock.quarter == 2 ? VGA.digitalAmber : labelColor)
                            .frame(width: 28)
                        Text("3")
                            .font(RetroFont.tiny())
                            .foregroundColor(game.clock.quarter == 3 ? VGA.digitalAmber : labelColor)
                            .frame(width: 28)
                        Text("4")
                            .font(RetroFont.tiny())
                            .foregroundColor(game.clock.quarter == 4 ? VGA.digitalAmber : labelColor)
                            .frame(width: 28)
                        Text("TOTAL")
                            .font(RetroFont.tiny())
                            .foregroundColor(labelColor)
                            .frame(width: 48)
                    }
                    .frame(height: 12)
                    .background(scoreboardBg)

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

                // Vertical separator
                Rectangle()
                    .fill(borderLight)
                    .frame(width: 1)

                // Center: Game clock + WIND
                VStack(spacing: 2) {
                    FPSDigitalClock(time: game.clock.displayTime, fontSize: 20)

                    HStack(spacing: 4) {
                        Text("WIND")
                            .font(RetroFont.tiny())
                            .foregroundColor(labelColor)
                        Text("\(windDirection) \(String(format: "%02d", windSpeed))")
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.white)
                    }
                }
                .frame(width: 110)
                .background(scoreboardBg)

                // Vertical separator
                Rectangle()
                    .fill(borderLight)
                    .frame(width: 1)

                // Right section: 2-row x 3-column situation grid (matching FPS '93)
                VStack(spacing: 1) {
                    // Row 1: TIME OUTS (away) | DOWN | TO GO
                    HStack(spacing: 1) {
                        situationCell(label: "TIME OUTS", value: "\(game.awayTimeouts)", valueColor: VGA.digitalAmber)
                            .frame(width: 70)

                        situationCell(label: "DOWN", value: "\(game.downAndDistance.down)", valueColor: VGA.digitalAmber)
                            .frame(width: 55)

                        situationCell(label: "TO GO", value: "\(game.downAndDistance.yardsToGo)", valueColor: VGA.white)
                            .frame(width: 55)
                    }

                    // Row 2: TIME OUTS (home) | BALL ON | PLAY CLOCK
                    HStack(spacing: 1) {
                        situationCell(label: "TIME OUTS", value: "\(game.homeTimeouts)", valueColor: VGA.digitalAmber)
                            .frame(width: 70)

                        situationCell(label: "BALL ON", value: game.fieldPosition.displayYardLine, valueColor: VGA.digitalAmber)
                            .frame(width: 55)

                        situationCell(label: "PLAY CLK", value: "\(viewModel.playClockSeconds)", valueColor: VGA.digitalAmber)
                            .frame(width: 55)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
            }
            .frame(height: 60)
            .background(scoreboardBg)
            .overlay(
                // Top highlight edge
                VStack(spacing: 0) {
                    Rectangle().fill(borderLight).frame(height: 1)
                    Spacer()
                    Rectangle().fill(borderDark).frame(height: 1)
                }
            )
        }
    }

    // MARK: - Situation Cell (label + value with dark bg)

    private func situationCell(label: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(RetroFont.tiny())
                .foregroundColor(labelColor)
            Text(value)
                .font(RetroFont.small())
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cellBg)
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

                // Possession indicator (tiny football silhouette)
                if hasPossession {
                    Ellipse()
                        .fill(VGA.digitalAmber)
                        .frame(width: 10, height: 6)
                        .rotationEffect(.degrees(45))
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
        .background(cellBg)
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
