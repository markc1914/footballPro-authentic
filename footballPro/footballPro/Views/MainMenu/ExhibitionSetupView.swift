//
//  ExhibitionSetupView.swift
//  footballPro
//
//  DOS-style team picker for Exhibition mode — pick Home and Away teams
//

import SwiftUI

struct ExhibitionSetupView: View {
    @EnvironmentObject var gameState: GameState

    @State private var teams: [Team] = []
    @State private var selectedHomeTeam: Team?
    @State private var selectedAwayTeam: Team?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title bar
                HStack {
                    FPSButton("< MENU") {
                        gameState.navigateTo(.mainMenu)
                    }

                    Spacer()

                    Text("EXHIBITION GAME")
                        .font(RetroFont.title())
                        .foregroundColor(VGA.digitalAmber)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(VGA.panelDark)
                .modifier(DOSPanelBorder(.raised, width: 1))

                if isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("LOADING TEAMS...")
                            .font(RetroFont.body())
                            .foregroundColor(VGA.digitalAmber)
                        ProgressView()
                            .tint(VGA.digitalAmber)
                    }
                    Spacer()
                } else {
                    // Team picker columns
                    HStack(spacing: 0) {
                        // VISITING TEAM column
                        teamColumn(
                            title: "VISITING TEAM",
                            selectedTeam: $selectedAwayTeam,
                            otherSelected: selectedHomeTeam
                        )

                        // Divider
                        Rectangle()
                            .fill(VGA.panelDark)
                            .frame(width: 2)

                        // HOME TEAM column
                        teamColumn(
                            title: "HOME TEAM",
                            selectedTeam: $selectedHomeTeam,
                            otherSelected: selectedAwayTeam
                        )
                    }

                    // Matchup preview + Play button
                    VStack(spacing: 12) {
                        DOSSeparator()

                        HStack(spacing: 24) {
                            // Away team preview
                            VStack(spacing: 4) {
                                Text("VISITOR")
                                    .font(RetroFont.tiny())
                                    .foregroundColor(VGA.darkGray)
                                if let away = selectedAwayTeam {
                                    Text(away.city.uppercased())
                                        .font(RetroFont.small())
                                        .foregroundColor(VGA.lightGray)
                                    Text(away.name.uppercased())
                                        .font(RetroFont.header())
                                        .foregroundColor(VGA.teamCyan)
                                } else {
                                    Text("---")
                                        .font(RetroFont.header())
                                        .foregroundColor(VGA.darkGray)
                                }
                            }
                            .frame(width: 180)

                            Text("@")
                                .font(RetroFont.large())
                                .foregroundColor(VGA.darkGray)

                            // Home team preview
                            VStack(spacing: 4) {
                                Text("HOME")
                                    .font(RetroFont.tiny())
                                    .foregroundColor(VGA.darkGray)
                                if let home = selectedHomeTeam {
                                    Text(home.city.uppercased())
                                        .font(RetroFont.small())
                                        .foregroundColor(VGA.lightGray)
                                    Text(home.name.uppercased())
                                        .font(RetroFont.header())
                                        .foregroundColor(VGA.teamRed)
                                } else {
                                    Text("---")
                                        .font(RetroFont.header())
                                        .foregroundColor(VGA.darkGray)
                                }
                            }
                            .frame(width: 180)
                        }
                        .padding(.vertical, 8)

                        // Difficulty and Quarter Length selectors
                        HStack(spacing: 32) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DIFFICULTY")
                                    .font(RetroFont.tiny())
                                    .foregroundColor(VGA.darkGray)
                                HStack(spacing: 4) {
                                    ForEach(Difficulty.allCases, id: \.self) { diff in
                                        Button(action: { gameState.difficulty = diff }) {
                                            Text(diff.rawValue.uppercased())
                                                .font(RetroFont.tiny())
                                                .foregroundColor(gameState.difficulty == diff ? .black : VGA.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(gameState.difficulty == diff ? VGA.digitalAmber : VGA.buttonBg)
                                                .modifier(DOSPanelBorder(gameState.difficulty == diff ? .sunken : .raised, width: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("QUARTER LENGTH")
                                    .font(RetroFont.tiny())
                                    .foregroundColor(VGA.darkGray)
                                HStack(spacing: 4) {
                                    ForEach(QuarterLength.allCases, id: \.self) { length in
                                        Button(action: { gameState.quarterLength = length }) {
                                            Text(length.displayName.uppercased())
                                                .font(RetroFont.tiny())
                                                .foregroundColor(gameState.quarterLength == length ? .black : VGA.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(gameState.quarterLength == length ? VGA.digitalAmber : VGA.buttonBg)
                                                .modifier(DOSPanelBorder(gameState.quarterLength == length ? .sunken : .raised, width: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        // Play Football button
                        FPSButton("PLAY FOOTBALL") {
                            startExhibition()
                        }
                        .opacity(canPlay ? 1.0 : 0.4)
                        .disabled(!canPlay)

                        Spacer().frame(height: 8)
                    }
                    .padding(.horizontal, 16)
                    .background(VGA.panelBg)
                    .modifier(DOSPanelBorder(.raised, width: 1))
                }
            }
        }
        .onAppear {
            loadTeams()
        }
    }

    private var canPlay: Bool {
        selectedHomeTeam != nil && selectedAwayTeam != nil &&
        selectedHomeTeam?.id != selectedAwayTeam?.id
    }

    private func loadTeams() {
        // Reuse cached league if available, otherwise load
        if let league = gameState.exhibitionLeague {
            teams = league.teams.sorted { $0.city < $1.city }
        } else {
            let league = LeagueGenerator.loadAuthenticLeague() ?? LeagueGenerator.generateLeague()
            gameState.exhibitionLeague = league
            teams = league.teams.sorted { $0.city < $1.city }
        }
        isLoading = false
    }

    private func startExhibition() {
        guard let home = selectedHomeTeam, let away = selectedAwayTeam else { return }
        gameState.startExhibitionGame(homeTeam: home, awayTeam: away)
    }

    @ViewBuilder
    private func teamColumn(title: String, selectedTeam: Binding<Team?>, otherSelected: Team?) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(RetroFont.header())
                .foregroundColor(VGA.digitalAmber)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(VGA.panelVeryDark)

            ScrollView {
                VStack(spacing: 1) {
                    ForEach(teams) { team in
                        let isSelected = selectedTeam.wrappedValue?.id == team.id
                        let isOtherSelected = otherSelected?.id == team.id

                        Button(action: {
                            if !isOtherSelected {
                                selectedTeam.wrappedValue = team
                            }
                        }) {
                            HStack(spacing: 8) {
                                // Team color swatch
                                Rectangle()
                                    .fill(team.colors.primaryColor)
                                    .frame(width: 6, height: 24)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(team.city.uppercased())
                                        .font(RetroFont.tiny())
                                        .foregroundColor(isSelected ? VGA.digitalAmber : VGA.darkGray)
                                    Text(team.name.uppercased())
                                        .font(RetroFont.bodyBold())
                                        .foregroundColor(isSelected ? .white : (isOtherSelected ? VGA.darkGray : VGA.lightGray))
                                }

                                Spacer()

                                Text("\(team.overallRating)")
                                    .font(RetroFont.body())
                                    .foregroundColor(isSelected ? VGA.digitalAmber : ratingColor(team.overallRating))
                                    .frame(width: 28)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSelected ? VGA.buttonBg : (isOtherSelected ? Color.black.opacity(0.3) : Color.black))
                        }
                        .buttonStyle(.plain)
                        .disabled(isOtherSelected)
                    }
                }
            }
            .background(Color.black)
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
    }

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 90...99: return VGA.green
        case 80...89: return VGA.cyan
        case 70...79: return VGA.orange
        default: return VGA.brightRed
        }
    }
}

#Preview {
    ExhibitionSetupView()
        .environmentObject(GameState())
        .environmentObject(InputManager())
}
