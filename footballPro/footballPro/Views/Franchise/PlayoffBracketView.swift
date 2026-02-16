//
//  PlayoffBracketView.swift
//  footballPro
//
//  Playoff bracket display — FPS Football Pro '93 authentic style
//

import SwiftUI

struct PlayoffBracketView: View {
    @ObservedObject var viewModel: SeasonViewModel
    var onBack: () -> Void
    var onPlayGame: ((ScheduledGame) -> Void)?

    // MARK: - Layout Constants

    private let matchupBoxWidth: CGFloat = 200
    private let matchupBoxHeight: CGFloat = 56
    private let bracketSpacing: CGFloat = 40
    private let connectorLineWidth: CGFloat = 2

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            titleBar

            // Bracket content
            ScrollView {
                VStack(spacing: 24) {
                    bracketLayout
                        .padding(.top, 24)

                    // Champion banner
                    if let champion = viewModel.champion {
                        championBanner(team: champion)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            // Bottom bar with back button
            bottomBar
        }
        .background(VGA.screenBg)
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack {
            Spacer()
            Text("PLAYOFF BRACKET")
                .font(RetroFont.title())
                .foregroundColor(VGA.digitalAmber)
            Spacer()
        }
        .padding(.vertical, 10)
        .background(VGA.panelVeryDark)
        .modifier(DOSPanelBorder(.raised, width: 1))
    }

    // MARK: - Bracket Layout

    private var bracketLayout: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let centerY: CGFloat = 160

            ZStack {
                // Connecting lines
                bracketConnectors(centerX: centerX, centerY: centerY)

                // Left semifinal (top)
                if let semi1 = semiGame(index: 0) {
                    matchupBox(game: semi1, seed1: 1, seed2: 4)
                        .position(x: centerX - matchupBoxWidth - bracketSpacing,
                                  y: centerY - matchupBoxHeight - 20)
                }

                // Right semifinal (bottom)
                if let semi2 = semiGame(index: 1) {
                    matchupBox(game: semi2, seed1: 2, seed2: 3)
                        .position(x: centerX + matchupBoxWidth + bracketSpacing,
                                  y: centerY - matchupBoxHeight - 20)
                }

                // Championship at center
                if let champ = championshipGame {
                    matchupBox(game: champ, seed1: nil, seed2: nil)
                        .position(x: centerX, y: centerY + matchupBoxHeight + 30)
                } else {
                    // Placeholder for championship
                    championshipPlaceholder
                        .position(x: centerX, y: centerY + matchupBoxHeight + 30)
                }

                // Round labels
                Text("SEMIFINALS")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.lightGray)
                    .position(x: centerX, y: centerY - matchupBoxHeight * 2 - 20)

                Text("CHAMPIONSHIP")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.digitalAmber)
                    .position(x: centerX, y: centerY + 2)
            }
        }
        .frame(height: 340)
    }

    // MARK: - Bracket Connectors

    private func bracketConnectors(centerX: CGFloat, centerY: CGFloat) -> some View {
        let leftBoxCenter = CGPoint(
            x: centerX - matchupBoxWidth - bracketSpacing,
            y: centerY - matchupBoxHeight - 20
        )
        let rightBoxCenter = CGPoint(
            x: centerX + matchupBoxWidth + bracketSpacing,
            y: centerY - matchupBoxHeight - 20
        )
        let champBoxCenter = CGPoint(
            x: centerX,
            y: centerY + matchupBoxHeight + 30
        )

        return Path { path in
            // Left semi -> championship
            let leftOut = CGPoint(x: leftBoxCenter.x + matchupBoxWidth / 2, y: leftBoxCenter.y)
            let champLeft = CGPoint(x: champBoxCenter.x - matchupBoxWidth / 2, y: champBoxCenter.y)
            path.move(to: leftOut)
            path.addLine(to: CGPoint(x: leftOut.x + 20, y: leftOut.y))
            path.addLine(to: CGPoint(x: leftOut.x + 20, y: champLeft.y))
            path.addLine(to: champLeft)

            // Right semi -> championship
            let rightOut = CGPoint(x: rightBoxCenter.x - matchupBoxWidth / 2, y: rightBoxCenter.y)
            let champRight = CGPoint(x: champBoxCenter.x + matchupBoxWidth / 2, y: champBoxCenter.y)
            path.move(to: rightOut)
            path.addLine(to: CGPoint(x: rightOut.x - 20, y: rightOut.y))
            path.addLine(to: CGPoint(x: rightOut.x - 20, y: champRight.y))
            path.addLine(to: champRight)
        }
        .stroke(VGA.panelLight, lineWidth: connectorLineWidth)
    }

    // MARK: - Matchup Box

    private func matchupBox(game: ScheduledGame, seed1: Int?, seed2: Int?) -> some View {
        let isUserGame = isUserTeamGame(game)
        let hasResult = game.isCompleted
        let winnerId = game.result.flatMap { result in
            result.homeScore > result.awayScore ? game.homeTeamId :
            (result.awayScore > result.homeScore ? game.awayTeamId : nil)
        }

        return VStack(spacing: 0) {
            // Home team row
            teamRow(
                teamId: game.homeTeamId,
                seed: seed1,
                score: game.result?.homeScore,
                isWinner: winnerId == game.homeTeamId,
                isUserTeam: game.homeTeamId == viewModel.userTeam?.id,
                hasResult: hasResult
            )

            Rectangle()
                .fill(VGA.panelDark)
                .frame(height: 1)

            // Away team row
            teamRow(
                teamId: game.awayTeamId,
                seed: seed2,
                score: game.result?.awayScore,
                isWinner: winnerId == game.awayTeamId,
                isUserTeam: game.awayTeamId == viewModel.userTeam?.id,
                hasResult: hasResult
            )

            // Play button for user's next unplayed game
            if isUserGame && !hasResult {
                FPSButton("PLAY GAME", width: matchupBoxWidth - 8) {
                    onPlayGame?(game)
                }
                .padding(.top, 4)
                .padding(.bottom, 4)
            }
        }
        .frame(width: matchupBoxWidth)
        .background(VGA.panelVeryDark)
        .modifier(DOSPanelBorder(.raised, width: 1))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isUserGame ? VGA.digitalAmber : Color.clear, lineWidth: isUserGame ? 2 : 0)
        )
    }

    private func teamRow(
        teamId: UUID,
        seed: Int?,
        score: Int?,
        isWinner: Bool,
        isUserTeam: Bool,
        hasResult: Bool
    ) -> some View {
        let isChampion = viewModel.season?.playoffBracket?.championId == teamId

        return HStack(spacing: 6) {
            // Seed number
            if let seed = seed {
                Text("\(seed)")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.darkGray)
                    .frame(width: 14, alignment: .center)
            }

            // Team name
            Text(viewModel.teamName(for: teamId))
                .font(RetroFont.body())
                .foregroundColor(teamNameColor(isWinner: isWinner, isUserTeam: isUserTeam, isChampion: isChampion, hasResult: hasResult))
                .lineLimit(1)

            Spacer()

            // Score
            if let score = score {
                Text("\(score)")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(isWinner ? VGA.white : VGA.darkGray)
                    .frame(width: 28, alignment: .trailing)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(teamRowBackground(isWinner: isWinner, isChampion: isChampion))
    }

    private func teamNameColor(isWinner: Bool, isUserTeam: Bool, isChampion: Bool, hasResult: Bool) -> Color {
        if isChampion {
            return VGA.playSlotGreen
        }
        if isWinner {
            return VGA.white
        }
        if isUserTeam {
            return VGA.digitalAmber
        }
        if hasResult {
            return VGA.darkGray
        }
        return VGA.lightGray
    }

    private func teamRowBackground(isWinner: Bool, isChampion: Bool) -> Color {
        if isChampion {
            return VGA.playSlotDark.opacity(0.4)
        }
        return Color.clear
    }

    // MARK: - Championship Placeholder

    private var championshipPlaceholder: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TBD")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.darkGray)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)

            Rectangle()
                .fill(VGA.panelDark)
                .frame(height: 1)

            HStack {
                Text("TBD")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.darkGray)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .frame(width: matchupBoxWidth)
        .background(VGA.panelVeryDark)
        .modifier(DOSPanelBorder(.raised, width: 1))
    }

    // MARK: - Champion Banner

    private func championBanner(team: Team) -> some View {
        VStack(spacing: 8) {
            Text("CHAMPION")
                .font(RetroFont.large())
                .foregroundColor(VGA.digitalAmber)

            Text(team.fullName)
                .font(RetroFont.title())
                .foregroundColor(VGA.playSlotGreen)

            Text(viewModel.teamRecord(for: team.id))
                .font(RetroFont.header())
                .foregroundColor(VGA.lightGray)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 32)
        .background(VGA.panelVeryDark)
        .modifier(DOSPanelBorder(.raised))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            FPSButton("BACK") {
                onBack()
            }
            Spacer()

            if let season = viewModel.season {
                Text("WEEK \(season.currentWeek)")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.lightGray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelBg)
        .modifier(DOSPanelBorder(.raised, width: 1))
    }

    // MARK: - Helpers

    private func semiGame(index: Int) -> ScheduledGame? {
        guard let bracket = viewModel.season?.playoffBracket else { return nil }
        let semis = bracket.games(for: .conference)
        guard index < semis.count else { return nil }
        return semis[index]
    }

    private var championshipGame: ScheduledGame? {
        viewModel.season?.playoffBracket?.games(for: .championship).first
    }

    private func isUserTeamGame(_ game: ScheduledGame) -> Bool {
        guard let userTeamId = viewModel.userTeam?.id else { return false }
        return game.homeTeamId == userTeamId || game.awayTeamId == userTeamId
    }
}

// MARK: - Preview

#Preview {
    PlayoffBracketView(
        viewModel: SeasonViewModel(),
        onBack: {}
    )
}
