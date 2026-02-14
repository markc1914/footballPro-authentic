//
//  RosterView.swift
//  footballPro
//
//  Player roster management view
//

import SwiftUI

struct RosterView: View {
    @ObservedObject var viewModel: TeamViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header with team info
            if let team = viewModel.team {
                TeamHeaderView(team: team)
            }

            // Toolbar
            HStack {
                // Sort picker
                Picker("Sort", selection: $viewModel.sortOption) {
                    ForEach(TeamViewModel.RosterSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 400)

                Spacer()

                // Position filter
                Menu {
                    Button("All Positions") {
                        viewModel.filterPosition = nil
                    }

                    Divider()

                    ForEach(Position.allCases, id: \.self) { position in
                        Button(position.displayName) {
                            viewModel.filterPosition = position
                        }
                    }
                } label: {
                    Label(viewModel.filterPosition?.displayName ?? "All Positions", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            .padding()

            // Roster table
            RosterTableView(
                players: viewModel.sortedRoster,
                selectedPlayer: viewModel.selectedPlayer
            ) { player in
                viewModel.selectPlayer(player)
            }
        }
        .sheet(isPresented: $viewModel.showPlayerDetail) {
            if let player = viewModel.selectedPlayer {
                PlayerDetailView(player: player, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Team Header

struct TeamHeaderView: View {
    let team: Team

    var body: some View {
        HStack(spacing: 24) {
            // Team logo placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(team.colors.primaryColor)
                .frame(width: 80, height: 80)
                .overlay(
                    Text(team.abbreviation)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(team.fullName)
                    .font(.title)
                    .fontWeight(.bold)

                Text(team.record.displayRecord)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Quick stats
            HStack(spacing: 32) {
                QuickStatView(label: "OVR", value: "\(team.overallRating)")
                QuickStatView(label: "OFF", value: "\(team.offensiveRating)")
                QuickStatView(label: "DEF", value: "\(team.defensiveRating)")
                QuickStatView(label: "CAP", value: formatCurrency(team.finances.availableCap))
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }

    private func formatCurrency(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value * 1000)) ?? "$0"
    }
}

struct QuickStatView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
        }
    }
}

// MARK: - Roster Table

struct RosterTableView: View {
    let players: [Player]
    let selectedPlayer: Player?
    let onSelect: (Player) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("POS")
                        .frame(width: 50, alignment: .leading)
                    Text("NAME")
                        .frame(width: 200, alignment: .leading)
                    Text("OVR")
                        .frame(width: 50, alignment: .center)
                    Text("AGE")
                        .frame(width: 50, alignment: .center)
                    Text("EXP")
                        .frame(width: 50, alignment: .center)
                    Text("CAP HIT")
                        .frame(width: 100, alignment: .trailing)
                    Text("YRS")
                        .frame(width: 50, alignment: .center)
                    Text("STATUS")
                        .frame(width: 80, alignment: .center)
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))

                // Player rows
                ForEach(players) { player in
                    PlayerRowView(
                        player: player,
                        isSelected: selectedPlayer?.id == player.id
                    ) {
                        onSelect(player)
                    }

                    Divider()
                }
            }
        }
    }
}

struct PlayerRowView: View {
    let player: Player
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Text(player.position.rawValue)
                .frame(width: 50, alignment: .leading)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)

            Text(player.fullName)
                .frame(width: 200, alignment: .leading)
                .fontWeight(.medium)

            Text("\(player.overall)")
                .frame(width: 50, alignment: .center)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(ratingColor(player.overall))

            Text("\(player.age)")
                .frame(width: 50, alignment: .center)
                .foregroundColor(ageColor(player.age))

            Text("\(player.experience)")
                .frame(width: 50, alignment: .center)
                .foregroundColor(.secondary)

            Text(formatSalary(player.contract.capHit))
                .frame(width: 100, alignment: .trailing)
                .font(.system(.body, design: .monospaced))

            Text("\(player.contract.yearsRemaining)")
                .frame(width: 50, alignment: .center)
                .foregroundColor(.secondary)

            statusView
                .frame(width: 80, alignment: .center)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            isSelected ? Color.blue.opacity(0.2) :
            (isHovered ? Color.white.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }

    @ViewBuilder
    var statusView: some View {
        if player.status.isInjured {
            Text("INJ")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red)
                .cornerRadius(4)
        } else {
            Text("OK")
                .font(.caption)
                .foregroundColor(.green)
        }
    }

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 90...99: return .green
        case 80...89: return .blue
        case 70...79: return .orange
        default: return .red
        }
    }

    private func ageColor(_ age: Int) -> Color {
        switch age {
        case ...26: return .green
        case 27...30: return .primary
        default: return .orange
        }
    }

    private func formatSalary(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "$%.1fM", Double(value) / 1000.0)
        }
        return "$\(value)K"
    }
}

// MARK: - Player Detail

struct PlayerDetailView: View {
    let player: Player
    @ObservedObject var viewModel: TeamViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.position.rawValue)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(player.fullName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("OVERALL")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(player.overall)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(ratingColor(player.overall))
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Bio section
                    GroupBox("BIO") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                BioItem(label: "Age", value: "\(player.age)")
                                BioItem(label: "Height", value: player.displayHeight)
                                BioItem(label: "Weight", value: "\(player.weight) lbs")
                            }
                            HStack {
                                BioItem(label: "Experience", value: "\(player.experience) years")
                                BioItem(label: "College", value: player.college)
                            }
                        }
                    }

                    // Ratings section
                    GroupBox("RATINGS") {
                        RatingsGridView(player: player)
                    }

                    // Stats section
                    GroupBox("SEASON STATS") {
                        SeasonStatsView(stats: player.seasonStats, position: player.position)
                    }

                    // Contract section
                    GroupBox("CONTRACT") {
                        ContractView(contract: player.contract)
                    }
                }
                .padding()
            }

            // Actions
            HStack {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Spacer()

                Button("Release Player") {
                    viewModel.releasePlayer(player)
                    dismiss()
                }
                .foregroundColor(.red)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
    }

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 90...99: return .green
        case 80...89: return .blue
        case 70...79: return .orange
        default: return .red
        }
    }
}

struct BioItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RatingsGridView: View {
    let player: Player

    var body: some View {
        let ratings = keyRatings(for: player.position)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
            ForEach(ratings, id: \.name) { rating in
                RatingItem(name: rating.name, value: rating.value)
            }
        }
    }

    private func keyRatings(for position: Position) -> [(name: String, value: Int)] {
        let r = player.ratings
        switch position {
        case .quarterback:
            return [
                ("Throw Power", r.throwPower),
                ("Short Acc", r.throwAccuracyShort),
                ("Mid Acc", r.throwAccuracyMid),
                ("Deep Acc", r.throwAccuracyDeep),
                ("Awareness", r.awareness),
                ("Speed", r.speed)
            ]
        case .runningBack:
            return [
                ("Speed", r.speed),
                ("Agility", r.agility),
                ("Elusiveness", r.elusiveness),
                ("Carrying", r.carrying),
                ("Break Tackle", r.breakTackle),
                ("Catching", r.catching)
            ]
        case .wideReceiver:
            return [
                ("Speed", r.speed),
                ("Catching", r.catching),
                ("Route Running", r.routeRunning),
                ("Release", r.release),
                ("Catch Traffic", r.catchInTraffic),
                ("Agility", r.agility)
            ]
        default:
            return [
                ("Speed", r.speed),
                ("Strength", r.strength),
                ("Agility", r.agility),
                ("Awareness", r.awareness),
                ("Stamina", r.stamina),
                ("Toughness", r.toughness)
            ]
        }
    }
}

struct RatingItem: View {
    let name: String
    let value: Int

    var body: some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(value)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(ratingColor(value))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
    }

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 90...99: return .green
        case 80...89: return .blue
        case 70...79: return .orange
        default: return .red
        }
    }
}

struct SeasonStatsView: View {
    let stats: SeasonStats
    let position: Position

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if position == .quarterback {
                StatLine(label: "Passing", value: "\(stats.passCompletions)/\(stats.passAttempts), \(stats.passingYards) yds, \(stats.passingTouchdowns) TD, \(stats.interceptions) INT")
            }

            if position == .runningBack || position == .quarterback {
                StatLine(label: "Rushing", value: "\(stats.rushAttempts) att, \(stats.rushingYards) yds, \(stats.rushingTouchdowns) TD")
            }

            if position == .wideReceiver || position == .tightEnd || position == .runningBack {
                StatLine(label: "Receiving", value: "\(stats.receptions) rec, \(stats.receivingYards) yds, \(stats.receivingTouchdowns) TD")
            }

            if position.isDefense {
                StatLine(label: "Defense", value: "\(stats.totalTackles) tackles, \(stats.defSacks) sacks, \(stats.interceptionsDef) INT")
            }

            StatLine(label: "Games", value: "\(stats.gamesPlayed)")
        }
    }
}

struct StatLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct ContractView: View {
    let contract: Contract

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ContractItem(label: "Years Remaining", value: "\(contract.yearsRemaining)")
                ContractItem(label: "Cap Hit", value: formatSalary(contract.capHit))
            }
            HStack {
                ContractItem(label: "Total Value", value: formatSalary(contract.totalValue))
                ContractItem(label: "Guaranteed", value: formatSalary(contract.guaranteedMoney))
            }
        }
    }

    private func formatSalary(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "$%.1fM", Double(value) / 1000.0)
        }
        return "$\(value)K"
    }
}

struct ContractItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
