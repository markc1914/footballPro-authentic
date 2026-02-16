import SwiftUI

// MARK: - Standings View

struct StandingsView: View {
    @EnvironmentObject var gameState: GameState

    enum ViewMode: String, CaseIterable {
        case division = "DIVISION"
        case overall = "OVERALL"
    }

    @State private var viewMode: ViewMode = .division

    private var season: Season? { gameState.currentSeason }
    private var league: League? { gameState.currentLeague }
    private var userTeamId: UUID? { gameState.userTeam?.id }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar

            // View mode toggle
            viewModeToggle
                .padding(.top, 8)

            // Standings content
            ScrollView {
                VStack(spacing: 12) {
                    switch viewMode {
                    case .division:
                        divisionView
                    case .overall:
                        overallView
                    }
                }
                .padding(12)
            }

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

            Text("STANDINGS")
                .font(RetroFont.title())
                .foregroundColor(VGA.digitalAmber)

            Spacer()

            // Spacer to balance the back button
            Color.clear
                .frame(width: 80, height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelDark)
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        HStack(spacing: 2) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button(action: { viewMode = mode }) {
                    Text(mode.rawValue)
                        .font(RetroFont.bodyBold())
                        .foregroundColor(viewMode == mode ? VGA.white : VGA.lightGray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(viewMode == mode ? VGA.buttonBg : VGA.panelDark)
                }
                .buttonStyle(.plain)
            }
        }
        .modifier(DOSPanelBorder(.sunken, width: 2))
    }

    // MARK: - Division View

    private var divisionView: some View {
        ForEach(divisions, id: \.id) { division in
            VStack(spacing: 0) {
                // Division header
                HStack {
                    Text(division.name.uppercased())
                        .font(RetroFont.header())
                        .foregroundColor(VGA.digitalAmber)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(VGA.panelDark)

                // Column headers
                standingsHeader

                // Team rows
                let entries = season?.divisionStandings(for: division.id) ?? []
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    standingsRow(rank: index + 1, entry: entry)
                }
            }
            .modifier(DOSPanelBorder(.raised, width: 2))
        }
    }

    // MARK: - Overall View

    private var overallView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LEAGUE STANDINGS")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.digitalAmber)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(VGA.panelDark)

            // Column headers
            standingsHeader

            // All team rows
            let entries = season?.overallStandings() ?? []
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                standingsRow(rank: index + 1, entry: entry)
            }
        }
        .modifier(DOSPanelBorder(.raised, width: 2))
    }

    // MARK: - Standings Header

    private var standingsHeader: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 30, alignment: .center)
            Text("TEAM")
                .frame(minWidth: 160, alignment: .leading)
            Spacer()
            Text("W")
                .frame(width: 36, alignment: .center)
            Text("L")
                .frame(width: 36, alignment: .center)
            Text("T")
                .frame(width: 36, alignment: .center)
            Text("PCT")
                .frame(width: 52, alignment: .center)
            Text("PF")
                .frame(width: 44, alignment: .center)
            Text("PA")
                .frame(width: 44, alignment: .center)
            Text("DIFF")
                .frame(width: 50, alignment: .center)
        }
        .font(RetroFont.small())
        .foregroundColor(VGA.lightGray)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(VGA.panelVeryDark)
    }

    // MARK: - Standings Row

    private func standingsRow(rank: Int, entry: StandingsEntry) -> some View {
        let isUserTeam = entry.teamId == userTeamId
        let teamName = gameState.teamName(for: entry.teamId)
        let pctString = String(format: ".%03d", Int(entry.winPercentage * 1000))
        let diffString = entry.pointDifferential >= 0
            ? "+\(entry.pointDifferential)"
            : "\(entry.pointDifferential)"

        return HStack(spacing: 0) {
            Text("\(rank)")
                .frame(width: 30, alignment: .center)
            Text(teamName)
                .frame(minWidth: 160, alignment: .leading)
                .lineLimit(1)
            Spacer()
            Text("\(entry.wins)")
                .frame(width: 36, alignment: .center)
            Text("\(entry.losses)")
                .frame(width: 36, alignment: .center)
            Text("\(entry.ties)")
                .frame(width: 36, alignment: .center)
            Text(pctString)
                .frame(width: 52, alignment: .center)
            Text("\(entry.pointsFor)")
                .frame(width: 44, alignment: .center)
            Text("\(entry.pointsAgainst)")
                .frame(width: 44, alignment: .center)
            Text(diffString)
                .frame(width: 50, alignment: .center)
                .foregroundColor(
                    entry.pointDifferential > 0 ? VGA.green :
                    entry.pointDifferential < 0 ? VGA.brightRed :
                    VGA.lightGray
                )
        }
        .font(RetroFont.body())
        .foregroundColor(isUserTeam ? VGA.white : VGA.lightGray)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isUserTeam ? VGA.playSlotGreen.opacity(0.6) : Color.clear)
    }

    // MARK: - Helpers

    private var divisions: [Division] {
        // Prefer season divisions, fall back to league divisions
        if let seasonDivisions = season?.divisions, !seasonDivisions.isEmpty {
            return seasonDivisions
        }
        return league?.divisions ?? []
    }
}

#Preview {
    StandingsView()
        .environmentObject(GameState())
        .frame(width: 800, height: 600)
}
