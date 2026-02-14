//
//  PlayerCard.swift
//  footballPro
//
//  Reusable player info card component — DOS panel style
//

import SwiftUI

struct PlayerCard: View {
    let player: Player
    var isCompact: Bool = false
    var showStats: Bool = false
    var onTap: (() -> Void)?

    var body: some View {
        if isCompact {
            compactCard
        } else {
            fullCard
        }
    }

    private var compactCard: some View {
        DOSPanel(.raised) {
            HStack(spacing: 8) {
                // Position badge
                Text(player.position.rawValue)
                    .font(RetroFont.small())
                    .foregroundColor(.white)
                    .frame(width: 32, height: 24)
                    .background(positionColor)
                    .dosPanel(.raised)

                VStack(alignment: .leading, spacing: 1) {
                    Text(player.fullName.uppercased())
                        .font(RetroFont.small())
                        .foregroundColor(VGA.black)
                        .lineLimit(1)

                    Text("\(player.age) YRS \u{2502} \(player.experience) EXP")
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.darkGray)
                }

                Spacer()

                // Overall rating
                Text("\(player.overall)")
                    .font(RetroFont.header())
                    .foregroundColor(ratingColor)
            }
            .padding(6)
            .background(VGA.panelBg)
        }
        .onTapGesture {
            onTap?()
        }
    }

    private var fullCard: some View {
        DOSWindowFrame("\(player.position.rawValue) - \(player.fullName.uppercased())", titleBarColor: positionColor) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(player.position.rawValue)
                                .font(RetroFont.bodyBold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(positionColor)

                            if player.status.isInjured {
                                Text("INJ")
                                    .font(RetroFont.small())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(VGA.brightRed)
                            }
                        }

                        Text(player.fullName.uppercased())
                            .font(RetroFont.header())
                            .foregroundColor(VGA.black)

                        Text("\(player.college) \u{2502} \(player.experience) YEAR\(player.experience == 1 ? "" : "S")")
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.darkGray)
                    }

                    Spacer()

                    // Overall rating (DOS style box)
                    VStack(spacing: 1) {
                        Text("OVR")
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.darkGray)
                        Text("\(player.overall)")
                            .font(RetroFont.large())
                            .foregroundColor(ratingColor)
                    }
                    .frame(width: 56, height: 56)
                    .background(VGA.panelVeryDark)
                    .dosPanel(.sunken)
                }
                .padding(8)

                DOSSeparator()

                // Physical attributes
                HStack(spacing: 0) {
                    RetroAttributeView(label: "AGE", value: "\(player.age)")
                    RetroAttributeView(label: "HT", value: player.displayHeight)
                    RetroAttributeView(label: "WT", value: "\(player.weight)")
                }
                .padding(.vertical, 6)

                if showStats {
                    DOSSeparator()
                    keyStatsView
                        .padding(8)
                }

                DOSSeparator()

                // Contract info
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("CAP HIT")
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.darkGray)
                        Text(formatSalary(player.contract.capHit))
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.green)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("CONTRACT")
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.darkGray)
                        Text("\(player.contract.yearsRemaining) YR\(player.contract.yearsRemaining == 1 ? "" : "S")")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(VGA.yellow)
                    }
                }
                .padding(8)
            }
            .background(VGA.panelBg)
        }
        .onTapGesture {
            onTap?()
        }
    }

    @ViewBuilder
    private var keyStatsView: some View {
        let stats = player.seasonStats

        switch player.position {
        case .quarterback:
            HStack(spacing: 0) {
                RetroStatView(label: "PASS YDS", value: "\(stats.passingYards)")
                RetroStatView(label: "TD", value: "\(stats.passingTouchdowns)")
                RetroStatView(label: "INT", value: "\(stats.interceptions)")
                RetroStatView(label: "CMP%", value: String(format: "%.1f", stats.completionPercentage))
            }

        case .runningBack:
            HStack(spacing: 0) {
                RetroStatView(label: "RUSH YDS", value: "\(stats.rushingYards)")
                RetroStatView(label: "TD", value: "\(stats.rushingTouchdowns)")
                RetroStatView(label: "AVG", value: String(format: "%.1f", stats.yardsPerCarry))
                RetroStatView(label: "REC", value: "\(stats.receptions)")
            }

        case .wideReceiver, .tightEnd:
            HStack(spacing: 0) {
                RetroStatView(label: "REC", value: "\(stats.receptions)")
                RetroStatView(label: "YDS", value: "\(stats.receivingYards)")
                RetroStatView(label: "TD", value: "\(stats.receivingTouchdowns)")
                RetroStatView(label: "AVG", value: String(format: "%.1f", stats.yardsPerReception))
            }

        default:
            HStack(spacing: 0) {
                RetroStatView(label: "TACKLES", value: "\(stats.totalTackles)")
                RetroStatView(label: "SACKS", value: String(format: "%.1f", stats.defSacks))
                RetroStatView(label: "INT", value: "\(stats.interceptionsDef)")
                RetroStatView(label: "PD", value: "\(stats.passesDefended)")
            }
        }
    }

    private var positionColor: Color {
        switch player.position {
        case _ where player.position.isOffense:
            return VGA.titleBarBg
        case _ where player.position.isDefense:
            return Color(red: 0.5, green: 0.0, blue: 0.0)
        default:
            return Color(red: 0.5, green: 0.3, blue: 0.0)
        }
    }

    private var ratingColor: Color {
        switch player.overall {
        case 90...99: return VGA.green
        case 80...89: return VGA.cyan
        case 70...79: return VGA.orange
        default: return VGA.brightRed
        }
    }

    private func formatSalary(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "$%.1fM", Double(value) / 1000.0)
        }
        return "$\(value)K"
    }
}

// MARK: - Retro Attribute View

struct RetroAttributeView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(RetroFont.tiny())
                .foregroundColor(VGA.darkGray)
            Text(value)
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.black)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Retro Stat View

struct RetroStatView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(RetroFont.header())
                .foregroundColor(VGA.yellow)
            Text(label)
                .font(RetroFont.tiny())
                .foregroundColor(VGA.darkGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(VGA.panelVeryDark)
        .dosPanel(.sunken)
    }
}

// MARK: - Player Card Grid

struct PlayerCardGrid: View {
    let players: [Player]
    let columns: Int
    var isCompact: Bool = false
    var onSelect: ((Player) -> Void)?

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns),
            spacing: 4
        ) {
            ForEach(players) { player in
                PlayerCard(
                    player: player,
                    isCompact: isCompact
                ) {
                    onSelect?(player)
                }
            }
        }
    }
}

// MARK: - Mini Player Badge

struct MiniPlayerBadge: View {
    let player: Player

    var body: some View {
        HStack(spacing: 4) {
            Text(player.position.rawValue)
                .font(RetroFont.tiny())
                .foregroundColor(.white)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(VGA.titleBarBg)

            Text(player.lastName.uppercased())
                .font(RetroFont.tiny())
                .foregroundColor(VGA.black)
                .lineLimit(1)

            Text("\(player.overall)")
                .font(RetroFont.small())
                .foregroundColor(VGA.darkGray)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(VGA.panelBg)
        .dosPanel(.raised)
    }
}

#Preview {
    VStack(spacing: 20) {
        PlayerCard(
            player: PlayerGenerator.generate(position: .quarterback, tier: .elite),
            showStats: true
        )
        .frame(width: 350)

        PlayerCard(
            player: PlayerGenerator.generate(position: .runningBack, tier: .starter),
            isCompact: true
        )
        .frame(width: 300)
    }
    .padding()
    .background(VGA.screenBg)
}
