//
//  FPSScoreboardBar.swift
//  footballPro
//
//  FPS Football Pro '93 scoreboard bar — matched from actual gameplay video frames
//  Dark bg, team names with ratings, football possession icon, QTR grid,
//  amber LED game clock, WIND, TIME OUTS, DOWN, TO GO, BALL ON, PLAY CLOCK
//

import SwiftUI

struct FPSScoreboardBar: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        if let game = viewModel.game {
            VStack(spacing: 0) {
                // Top row: team info + scores + clock + situation
                HStack(spacing: 0) {
                    // Left side: Team names, possession, scores
                    teamScoresBlock(game: game)

                    // Center: Game clock (large amber LED)
                    VStack(spacing: 1) {
                        Text("WIND")
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.lightGray)
                        Text("SW 01")
                            .font(RetroFont.small())
                            .foregroundColor(VGA.white)
                    }
                    .frame(width: 60)

                    FPSDigitalClock(time: game.clock.displayTime, fontSize: 22)
                        .frame(width: 100)

                    // Right side: Game situation
                    situationBlock(game: game)
                }
                .frame(height: 52)
                .background(VGA.panelVeryDark)
                .modifier(DOSPanelBorder(.raised, width: 1))
            }
        }
    }

    // MARK: - Team Scores Block (left side)

    private func teamScoresBlock(game: Game) -> some View {
        VStack(spacing: 0) {
            // Away team row
            teamRow(
                name: viewModel.awayTeam?.name ?? "Away",
                rating: viewModel.awayTeam?.overallRating,
                hasPossession: !game.isHomeTeamPossession,
                quarterScores: quarterScoresArray(game: game, isHome: false),
                totalScore: game.score.awayScore,
                currentQuarter: game.clock.quarter
            )

            // QTR header row
            HStack(spacing: 0) {
                Text("QTR:")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.lightGray)
                    .frame(width: 100, alignment: .leading)
                    .padding(.leading, 4)

                ForEach(1...4, id: \.self) { q in
                    Text("\(q)")
                        .font(RetroFont.tiny())
                        .foregroundColor(game.clock.quarter == q ? VGA.digitalAmber : VGA.lightGray)
                        .frame(width: 28)
                }

                Text("TOTAL")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.lightGray)
                    .frame(width: 48)
            }

            // Home team row
            teamRow(
                name: viewModel.homeTeam?.name ?? "Home",
                rating: viewModel.homeTeam?.overallRating,
                hasPossession: game.isHomeTeamPossession,
                quarterScores: quarterScoresArray(game: game, isHome: true),
                totalScore: game.score.homeScore,
                currentQuarter: game.clock.quarter
            )
        }
        .frame(width: 320)
    }

    private func teamRow(
        name: String,
        rating: Int?,
        hasPossession: Bool,
        quarterScores: [String],
        totalScore: Int,
        currentQuarter: Int
    ) -> some View {
        HStack(spacing: 0) {
            // Team name
            HStack(spacing: 4) {
                Text(name)
                    .font(RetroFont.small())
                    .foregroundColor(VGA.white)
                    .lineLimit(1)

                // Football icon for possession
                if hasPossession {
                    Text("\u{1F3C8}")
                        .font(.system(size: 8))
                }
            }
            .frame(width: 80, alignment: .leading)
            .padding(.leading, 4)

            // Rating in parens
            if let rating = rating {
                Text("(\(rating))")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.digitalAmber)
                    .frame(width: 32)
            } else {
                Spacer().frame(width: 32)
            }

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
    }

    // MARK: - Situation Block (right side)

    private func situationBlock(game: Game) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text("TIME OUTS")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.lightGray)
                // Show timeout pips (filled = remaining, empty = used)
                let timeouts = game.isHomeTeamPossession ? game.homeTimeouts : game.awayTimeouts
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < timeouts ? VGA.digitalAmber : VGA.darkGray)
                            .frame(width: 8, height: 8)
                    }
                }
            }

            VStack(spacing: 1) {
                Text("DOWN")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.lightGray)
                Text("\(game.downAndDistance.down)")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.digitalAmber)
            }

            VStack(spacing: 1) {
                Text("TO GO")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.lightGray)
                Text("\(game.downAndDistance.yardsToGo)")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.white)
            }

            VStack(spacing: 1) {
                Text("BALL ON")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.lightGray)
                Text(game.fieldPosition.displayYardLine)
                    .font(RetroFont.small())
                    .foregroundColor(VGA.digitalAmber)
            }

            VStack(spacing: 1) {
                Text("PLAY CLOCK")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.lightGray)
                FPSDigitalClock(time: "\(viewModel.playClockSeconds)", fontSize: 14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private func quarterScoresArray(game: Game, isHome: Bool) -> [String] {
        (1...4).map { q in
            if q > game.clock.quarter { return "00" }
            if q == game.clock.quarter {
                return String(format: "%02d", isHome ? game.score.homeScore : game.score.awayScore)
            }
            return "00"
        }
    }
}
