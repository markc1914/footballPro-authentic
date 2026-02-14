//
//  StatTable.swift
//  footballPro
//
//  Reusable statistics display components — DOS panel style
//

import SwiftUI

// MARK: - Stat Table

struct StatTable<Row: Identifiable>: View {
    let title: String
    let columns: [StatColumn]
    let rows: [Row]
    let valueProvider: (Row, String) -> String

    var body: some View {
        DOSWindowFrame(title.isEmpty ? "STATS" : title.uppercased()) {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(columns) { column in
                        Text(column.header)
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.cyan)
                            .frame(width: column.width, alignment: column.alignment)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(VGA.titleBarBg)

                // Data rows
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 0) {
                        ForEach(columns) { column in
                            Text(valueProvider(row, column.id))
                                .font(column.isMonospaced ? RetroFont.small() : RetroFont.small())
                                .fontWeight(column.isBold ? .bold : .regular)
                                .foregroundColor(column.color ?? VGA.white)
                                .frame(width: column.width, alignment: column.alignment)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(index % 2 == 0 ? VGA.panelVeryDark : VGA.panelVeryDark.opacity(0.8))

                    Rectangle().fill(VGA.shadowInner).frame(height: 1)
                }
            }
            .background(VGA.panelVeryDark)
        }
    }
}

struct StatColumn: Identifiable {
    let id: String
    let header: String
    let width: CGFloat
    var alignment: Alignment = .leading
    var isMonospaced: Bool = false
    var isBold: Bool = false
    var color: Color?
}

// MARK: - Standings Table

struct StandingsTable: View {
    let title: String
    let entries: [StandingsEntry]
    let teamNameProvider: (UUID) -> String

    var body: some View {
        DOSWindowFrame(title.uppercased()) {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    Text("#")
                        .frame(width: 30, alignment: .center)
                    Text("TEAM")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("W")
                        .frame(width: 40, alignment: .center)
                    Text("L")
                        .frame(width: 40, alignment: .center)
                    Text("PCT")
                        .frame(width: 60, alignment: .center)
                    Text("PF")
                        .frame(width: 50, alignment: .center)
                    Text("PA")
                        .frame(width: 50, alignment: .center)
                    Text("DIFF")
                        .frame(width: 50, alignment: .center)
                    Text("STRK")
                        .frame(width: 50, alignment: .center)
                }
                .font(RetroFont.tiny())
                .foregroundColor(VGA.cyan)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(VGA.titleBarBg)

                // Rows
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 0) {
                        Text("\(index + 1)")
                            .frame(width: 30, alignment: .center)
                            .foregroundColor(VGA.darkGray)

                        Text(teamNameProvider(entry.teamId))
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(VGA.white)

                        Text("\(entry.wins)")
                            .frame(width: 40, alignment: .center)
                            .foregroundColor(VGA.green)

                        Text("\(entry.losses)")
                            .frame(width: 40, alignment: .center)
                            .foregroundColor(VGA.brightRed)

                        Text(String(format: "%.3f", entry.winPercentage))
                            .frame(width: 60, alignment: .center)
                            .foregroundColor(VGA.white)

                        Text("\(entry.pointsFor)")
                            .frame(width: 50, alignment: .center)
                            .foregroundColor(VGA.white)

                        Text("\(entry.pointsAgainst)")
                            .frame(width: 50, alignment: .center)
                            .foregroundColor(VGA.white)

                        Text(diffString(entry.pointDifferential))
                            .foregroundColor(entry.pointDifferential >= 0 ? VGA.green : VGA.brightRed)
                            .frame(width: 50, alignment: .center)

                        Text(entry.streakDisplay)
                            .foregroundColor(entry.streak > 0 ? VGA.green : (entry.streak < 0 ? VGA.brightRed : VGA.darkGray))
                            .frame(width: 50, alignment: .center)
                    }
                    .font(RetroFont.small())
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(index < 4 ? VGA.titleBarBg.opacity(0.3) : (index % 2 == 0 ? VGA.panelVeryDark : VGA.panelVeryDark.opacity(0.8)))

                    Rectangle().fill(VGA.shadowInner).frame(height: 1)
                }
            }
            .background(VGA.panelVeryDark)
        }
    }

    private func diffString(_ diff: Int) -> String {
        if diff > 0 {
            return "+\(diff)"
        }
        return "\(diff)"
    }
}

// MARK: - League Leaders Table

struct LeagueLeadersTable: View {
    let title: String
    let category: String
    let leaders: [(player: Player, team: String, value: Int)]

    var body: some View {
        DOSWindowFrame(title.uppercased()) {
            VStack(spacing: 0) {
                // Category label
                HStack {
                    Spacer()
                    Text(category)
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.darkGray)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(VGA.panelBg)

                // Rows
                ForEach(Array(leaders.enumerated()), id: \.offset) { index, leader in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(RetroFont.small())
                            .foregroundColor(VGA.darkGray)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(leader.player.fullName.uppercased())
                                .font(RetroFont.small())
                                .foregroundColor(VGA.white)
                            Text("\(leader.team) \u{2502} \(leader.player.position.rawValue)")
                                .font(RetroFont.tiny())
                                .foregroundColor(VGA.cyan)
                        }

                        Spacer()

                        Text("\(leader.value)")
                            .font(RetroFont.header())
                            .foregroundColor(VGA.yellow)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(index % 2 == 0 ? VGA.panelVeryDark : VGA.panelVeryDark.opacity(0.8))

                    if index < leaders.count - 1 {
                        Rectangle().fill(VGA.shadowInner).frame(height: 1)
                    }
                }
            }
            .background(VGA.panelVeryDark)
        }
    }
}

// MARK: - Box Score Table

struct GameBoxScoreTable: View {
    let homeTeam: Team
    let awayTeam: Team
    let homeStats: TeamGameStats
    let awayStats: TeamGameStats

    var body: some View {
        DOSWindowFrame("TEAM STATS") {
            VStack(spacing: 0) {
                // Team headers
                HStack {
                    Spacer()
                    HStack(spacing: 20) {
                        Text(awayTeam.abbreviation)
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.cyan)
                        Text(homeTeam.abbreviation)
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.yellow)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(VGA.titleBarBg)

                // Stats
                StatComparisonRow(label: "Total Yards", away: awayStats.totalYards, home: homeStats.totalYards)
                StatComparisonRow(label: "Passing Yards", away: awayStats.passingYards, home: homeStats.passingYards)
                StatComparisonRow(label: "Rushing Yards", away: awayStats.rushingYards, home: homeStats.rushingYards)
                StatComparisonRow(label: "First Downs", away: awayStats.firstDowns, home: homeStats.firstDowns)
                StatComparisonRow(label: "3rd Down", away: awayStats.thirdDownConversions, home: homeStats.thirdDownConversions, suffix: "/\(awayStats.thirdDownAttempts)", homeSuffix: "/\(homeStats.thirdDownAttempts)")
                StatComparisonRow(label: "Turnovers", away: awayStats.turnovers, home: homeStats.turnovers, reverseColors: true)
                StatComparisonRow(label: "Penalties", away: awayStats.penalties, home: homeStats.penalties, suffix: "-\(awayStats.penaltyYards)", homeSuffix: "-\(homeStats.penaltyYards)", reverseColors: true)
                StatComparisonRow(label: "Time of Poss.", awayText: awayStats.timeOfPossessionDisplay, homeText: homeStats.timeOfPossessionDisplay)
            }
            .background(VGA.panelVeryDark)
        }
    }
}

struct StatComparisonRow: View {
    let label: String
    var away: Int = 0
    var home: Int = 0
    var awayText: String?
    var homeText: String?
    var suffix: String = ""
    var homeSuffix: String = ""
    var reverseColors: Bool = false

    var body: some View {
        HStack {
            // Away value
            HStack(spacing: 2) {
                Text(awayText ?? "\(away)")
                    .foregroundColor(getColor(away, home, isAway: true))
                if !suffix.isEmpty {
                    Text(suffix)
                        .foregroundColor(VGA.darkGray)
                }
            }
            .font(RetroFont.small())
            .frame(width: 80, alignment: .trailing)

            // Label
            Text(label.uppercased())
                .font(RetroFont.tiny())
                .foregroundColor(VGA.lightGray)
                .frame(maxWidth: .infinity)

            // Home value
            HStack(spacing: 2) {
                Text(homeText ?? "\(home)")
                    .foregroundColor(getColor(home, away, isAway: false))
                if !homeSuffix.isEmpty {
                    Text(homeSuffix)
                        .foregroundColor(VGA.darkGray)
                }
            }
            .font(RetroFont.small())
            .frame(width: 80, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(VGA.panelVeryDark)
    }

    private func getColor(_ value: Int, _ other: Int, isAway: Bool) -> Color {
        if awayText != nil || homeText != nil { return VGA.white }

        let isWinning = reverseColors ? value < other : value > other
        if isWinning {
            return VGA.green
        }
        return VGA.white
    }
}

// MARK: - Schedule Table

struct ScheduleTable: View {
    let games: [ScheduledGame]
    let userTeamId: UUID
    let teamNameProvider: (UUID) -> String
    let onSelect: ((ScheduledGame) -> Void)?

    var body: some View {
        DOSWindowFrame("SCHEDULE") {
            VStack(spacing: 0) {
                ForEach(games) { game in
                    ScheduleRow(
                        game: game,
                        userTeamId: userTeamId,
                        teamNameProvider: teamNameProvider
                    ) {
                        onSelect?(game)
                    }

                    Rectangle().fill(VGA.shadowInner).frame(height: 1)
                }
            }
            .background(VGA.panelVeryDark)
        }
    }
}

struct ScheduleRow: View {
    let game: ScheduledGame
    let userTeamId: UUID
    let teamNameProvider: (UUID) -> String
    let onTap: () -> Void

    var body: some View {
        let isHome = game.homeTeamId == userTeamId
        let opponentId = isHome ? game.awayTeamId : game.homeTeamId

        HStack {
            Text("WK \(game.week)")
                .font(RetroFont.tiny())
                .foregroundColor(VGA.darkGray)
                .frame(width: 50)

            Text(isHome ? "vs" : "@")
                .font(RetroFont.tiny())
                .foregroundColor(VGA.darkGray)

            Text(teamNameProvider(opponentId).uppercased())
                .font(RetroFont.small())
                .foregroundColor(VGA.white)

            Spacer()

            if let result = game.result {
                let userScore = isHome ? result.homeScore : result.awayScore
                let oppScore = isHome ? result.awayScore : result.homeScore
                let won = userScore > oppScore

                Text(won ? "W" : "L")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(won ? VGA.green : VGA.brightRed)

                Text("\(userScore)-\(oppScore)")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.white)
            } else {
                Text("\u{25BA}")
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.darkGray)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(VGA.panelVeryDark)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}
