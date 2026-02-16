//
//  StatsView.swift
//  footballPro
//
//  League stat leaders — tabbed: Passing, Rushing, Receiving, Defense
//  Authentic FPS Football Pro '93 visual style
//

import SwiftUI

struct StatsView: View {
    @EnvironmentObject var gameState: GameState

    enum StatTab: String, CaseIterable {
        case passing = "PASSING"
        case rushing = "RUSHING"
        case receiving = "RECEIVING"
        case defense = "DEFENSE"
    }

    @State private var selectedTab: StatTab = .passing

    private var allPlayers: [(player: Player, teamName: String)] {
        guard let league = gameState.currentLeague else { return [] }
        return league.teams.flatMap { team in
            team.roster.map { (player: $0, teamName: team.abbreviation) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            tabBar
            statsTable
            Spacer(minLength: 0)
        }
        .background(VGA.screenBg)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            FPSButton("< BACK") {
                gameState.navigateTo(.management)
            }

            Spacer()

            Text("STAT LEADERS")
                .font(RetroFont.title())
                .foregroundColor(VGA.digitalAmber)

            Spacer()

            Color.clear.frame(width: 80, height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelDark)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(StatTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(RetroFont.bodyBold())
                        .foregroundColor(selectedTab == tab ? VGA.screenBg : VGA.lightGray)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? VGA.buttonBg : VGA.panelDark)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(VGA.panelVeryDark)
    }

    // MARK: - Stats Table

    @ViewBuilder
    private var statsTable: some View {
        switch selectedTab {
        case .passing:
            passingTable
        case .rushing:
            rushingTable
        case .receiving:
            receivingTable
        case .defense:
            defenseTable
        }
    }

    // MARK: - Passing

    private var passingLeaders: [(player: Player, teamName: String)] {
        allPlayers
            .filter { $0.player.seasonStats.passAttempts > 0 }
            .sorted { $0.player.seasonStats.passingYards > $1.player.seasonStats.passingYards }
    }

    private var passingTable: some View {
        VStack(spacing: 0) {
            statHeader(columns: [
                ("PLAYER", 160, .leading),
                ("TEAM", 50, .center),
                ("CMP", 44, .center),
                ("ATT", 44, .center),
                ("PCT", 50, .center),
                ("YDS", 56, .center),
                ("TD", 36, .center),
                ("INT", 36, .center),
                ("SK", 36, .center),
            ])

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(passingLeaders.prefix(30).enumerated()), id: \.element.player.id) { index, entry in
                        let s = entry.player.seasonStats
                        statRow(
                            index: index,
                            name: entry.player.fullName,
                            teamName: entry.teamName,
                            isUserTeam: entry.player.id == gameState.userTeam?.roster.first(where: { $0.position == .quarterback })?.id,
                            values: [
                                "\(s.passCompletions)",
                                "\(s.passAttempts)",
                                String(format: "%.1f", s.completionPercentage),
                                "\(s.passingYards)",
                                "\(s.passingTouchdowns)",
                                "\(s.interceptions)",
                                "\(s.sacks)",
                            ]
                        )
                    }
                }
            }
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
        .padding(8)
    }

    // MARK: - Rushing

    private var rushingLeaders: [(player: Player, teamName: String)] {
        allPlayers
            .filter { $0.player.seasonStats.rushAttempts > 0 }
            .sorted { $0.player.seasonStats.rushingYards > $1.player.seasonStats.rushingYards }
    }

    private var rushingTable: some View {
        VStack(spacing: 0) {
            statHeader(columns: [
                ("PLAYER", 160, .leading),
                ("TEAM", 50, .center),
                ("ATT", 44, .center),
                ("YDS", 56, .center),
                ("AVG", 50, .center),
                ("TD", 36, .center),
                ("FUM", 36, .center),
            ])

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(rushingLeaders.prefix(30).enumerated()), id: \.element.player.id) { index, entry in
                        let s = entry.player.seasonStats
                        statRow(
                            index: index,
                            name: entry.player.fullName,
                            teamName: entry.teamName,
                            isUserTeam: gameState.userTeam?.roster.contains(where: { $0.id == entry.player.id }) ?? false,
                            values: [
                                "\(s.rushAttempts)",
                                "\(s.rushingYards)",
                                String(format: "%.1f", s.yardsPerCarry),
                                "\(s.rushingTouchdowns)",
                                "\(s.fumbles)",
                            ]
                        )
                    }
                }
            }
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
        .padding(8)
    }

    // MARK: - Receiving

    private var receivingLeaders: [(player: Player, teamName: String)] {
        allPlayers
            .filter { $0.player.seasonStats.receptions > 0 }
            .sorted { $0.player.seasonStats.receivingYards > $1.player.seasonStats.receivingYards }
    }

    private var receivingTable: some View {
        VStack(spacing: 0) {
            statHeader(columns: [
                ("PLAYER", 160, .leading),
                ("TEAM", 50, .center),
                ("REC", 44, .center),
                ("TGT", 44, .center),
                ("YDS", 56, .center),
                ("AVG", 50, .center),
                ("TD", 36, .center),
            ])

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(receivingLeaders.prefix(30).enumerated()), id: \.element.player.id) { index, entry in
                        let s = entry.player.seasonStats
                        statRow(
                            index: index,
                            name: entry.player.fullName,
                            teamName: entry.teamName,
                            isUserTeam: gameState.userTeam?.roster.contains(where: { $0.id == entry.player.id }) ?? false,
                            values: [
                                "\(s.receptions)",
                                "\(s.targets)",
                                "\(s.receivingYards)",
                                String(format: "%.1f", s.yardsPerReception),
                                "\(s.receivingTouchdowns)",
                            ]
                        )
                    }
                }
            }
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
        .padding(8)
    }

    // MARK: - Defense

    private var defenseLeaders: [(player: Player, teamName: String)] {
        allPlayers
            .filter { $0.player.seasonStats.totalTackles > 0 }
            .sorted { $0.player.seasonStats.totalTackles > $1.player.seasonStats.totalTackles }
    }

    private var defenseTable: some View {
        VStack(spacing: 0) {
            statHeader(columns: [
                ("PLAYER", 160, .leading),
                ("TEAM", 50, .center),
                ("TKL", 44, .center),
                ("TFL", 44, .center),
                ("SK", 50, .center),
                ("INT", 36, .center),
                ("PD", 36, .center),
                ("FF", 36, .center),
            ])

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(defenseLeaders.prefix(30).enumerated()), id: \.element.player.id) { index, entry in
                        let s = entry.player.seasonStats
                        statRow(
                            index: index,
                            name: entry.player.fullName,
                            teamName: entry.teamName,
                            isUserTeam: gameState.userTeam?.roster.contains(where: { $0.id == entry.player.id }) ?? false,
                            values: [
                                "\(s.totalTackles)",
                                "\(s.tacklesForLoss)",
                                String(format: "%.1f", s.defSacks),
                                "\(s.interceptionsDef)",
                                "\(s.passesDefended)",
                                "\(s.forcedFumbles)",
                            ]
                        )
                    }
                }
            }
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
        .padding(8)
    }

    // MARK: - Shared Components

    private func statHeader(columns: [(String, CGFloat, Alignment)]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                Text(col.0)
                    .frame(width: col.1, alignment: col.2)
            }
            Spacer()
        }
        .font(RetroFont.small())
        .foregroundColor(VGA.cyan)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(VGA.panelDark)
    }

    private func statRow(index: Int, name: String, teamName: String, isUserTeam: Bool, values: [String]) -> some View {
        HStack(spacing: 0) {
            Text(name)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
            Text(teamName)
                .frame(width: 50, alignment: .center)
            ForEach(Array(values.enumerated()), id: \.offset) { vIdx, value in
                let widths: [CGFloat] = {
                    switch selectedTab {
                    case .passing: return [44, 44, 50, 56, 36, 36, 36]
                    case .rushing: return [44, 56, 50, 36, 36]
                    case .receiving: return [44, 44, 56, 50, 36]
                    case .defense: return [44, 44, 50, 36, 36, 36]
                    }
                }()
                let w = vIdx < widths.count ? widths[vIdx] : 44
                Text(value)
                    .frame(width: w, alignment: .center)
            }
            Spacer()
        }
        .font(RetroFont.body())
        .foregroundColor(isUserTeam ? VGA.white : VGA.lightGray)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            index % 2 == 0
                ? (isUserTeam ? VGA.playSlotGreen.opacity(0.4) : Color.clear)
                : (isUserTeam ? VGA.playSlotGreen.opacity(0.4) : VGA.panelVeryDark.opacity(0.3))
        )
    }
}
