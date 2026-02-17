//
//  PlayerEditorView.swift
//  footballPro
//
//  Player rating editor + team info editor
//  DOS/VGA aesthetic matching FPS Football Pro '93
//  Ratings editable only before first game of the season
//

import SwiftUI

// MARK: - Player Editor View

struct PlayerEditorView: View {
    @EnvironmentObject var gameState: GameState
    let playerId: UUID
    let onDismiss: () -> Void

    // MARK: - State

    @State private var editedRatings: PlayerRatings?
    @State private var showTeamEditor = false

    // MARK: - Computed

    private var team: Team? {
        gameState.userTeam
    }

    private var player: Player? {
        team?.roster.first { $0.id == playerId }
    }

    /// Editing is only allowed before the first game of the season
    private var canEdit: Bool {
        guard let season = gameState.currentSeason else { return true }
        // Allow editing if no games have been completed yet
        let completedGames = season.schedule.filter { $0.isCompleted }
        return completedGames.isEmpty
    }

    // The 8 original FPS '93 rating categories mapped to our rating system
    // Original: SP, AC, AG, ST, HA, EN, IN, DI
    private struct RatingRow: Identifiable {
        let id: String
        let label: String
        let abbrev: String
        let current: Int
        let potential: Int
        let keyPath: WritableKeyPath<PlayerRatings, Int>
    }

    private func ratingRows(for ratings: PlayerRatings) -> [RatingRow] {
        [
            RatingRow(id: "SP", label: "SPEED", abbrev: "SP",
                      current: ratings.speed, potential: min(99, ratings.speed + 5),
                      keyPath: \.speed),
            RatingRow(id: "AC", label: "ACCELERATION", abbrev: "AC",
                      current: ratings.agility, potential: min(99, ratings.agility + 5),
                      keyPath: \.agility),
            RatingRow(id: "AG", label: "AGILITY", abbrev: "AG",
                      current: ratings.elusiveness, potential: min(99, ratings.elusiveness + 5),
                      keyPath: \.elusiveness),
            RatingRow(id: "ST", label: "STRENGTH", abbrev: "ST",
                      current: ratings.strength, potential: min(99, ratings.strength + 5),
                      keyPath: \.strength),
            RatingRow(id: "HA", label: "HANDS", abbrev: "HA",
                      current: ratings.catching, potential: min(99, ratings.catching + 5),
                      keyPath: \.catching),
            RatingRow(id: "EN", label: "ENDURANCE", abbrev: "EN",
                      current: ratings.stamina, potential: min(99, ratings.stamina + 5),
                      keyPath: \.stamina),
            RatingRow(id: "IN", label: "INTELLIGENCE", abbrev: "IN",
                      current: ratings.awareness, potential: min(99, ratings.awareness + 5),
                      keyPath: \.awareness),
            RatingRow(id: "DI", label: "DISCIPLINE", abbrev: "DI",
                      current: ratings.toughness, potential: min(99, ratings.toughness + 5),
                      keyPath: \.toughness),
        ]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
            DOSSeparator()

            if let player = player {
                ScrollView {
                    VStack(spacing: 12) {
                        playerInfoCard(player)
                        ratingsPanel(player)

                        if !canEdit {
                            HStack {
                                Text("RATINGS LOCKED - SEASON IN PROGRESS")
                                    .font(RetroFont.small())
                                    .foregroundColor(VGA.brightRed)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(12)
                }
            } else {
                Spacer()
                Text("PLAYER NOT FOUND")
                    .font(RetroFont.header())
                    .foregroundColor(VGA.brightRed)
                Spacer()
            }
        }
        .background(VGA.screenBg)
        .onAppear {
            if let player = player {
                editedRatings = player.ratings
            }
        }
        .sheet(isPresented: $showTeamEditor) {
            if let team = team {
                TeamEditorSheet(teamId: team.id, onDismiss: { showTeamEditor = false })
                    .environmentObject(gameState)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            FPSButton("< BACK") {
                onDismiss()
            }

            Spacer()

            Text("PLAYER EDITOR")
                .font(RetroFont.title())
                .foregroundColor(VGA.digitalAmber)

            Spacer()

            FPSButton("TEAM INFO") {
                showTeamEditor = true
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelDark)
    }

    // MARK: - Player Info Card

    private func playerInfoCard(_ player: Player) -> some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("PLAYER CARD")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.lightGray)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.titleBarBg)

            // Content
            HStack(spacing: 16) {
                // Jersey number box
                VStack(spacing: 2) {
                    Text("#\(player.jerseyNumber)")
                        .font(RetroFont.large())
                        .foregroundColor(VGA.digitalAmber)
                    Text(player.position.rawValue)
                        .font(RetroFont.header())
                        .foregroundColor(VGA.cyan)
                }
                .frame(width: 80, height: 70)
                .background(VGA.screenBg)
                .modifier(DOSPanelBorder(.sunken, width: 1))

                // Player details
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.fullName.uppercased())
                        .font(RetroFont.header())
                        .foregroundColor(VGA.white)

                    Text(player.position.displayName.uppercased())
                        .font(RetroFont.body())
                        .foregroundColor(VGA.cyan)

                    HStack(spacing: 16) {
                        detailItem("AGE", "\(player.age)")
                        detailItem("HT", player.displayHeight)
                        detailItem("WT", "\(player.weight)")
                        detailItem("EXP", "\(player.experience) YR\(player.experience == 1 ? "" : "S")")
                        detailItem("OVR", "\(player.overall)")
                    }
                }

                Spacer()

                // Status
                VStack(alignment: .trailing, spacing: 4) {
                    Text(playerStatusText(player))
                        .font(RetroFont.bodyBold())
                        .foregroundColor(playerStatusColor(player))

                    Text("\(player.college.uppercased())")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.lightGray)
                }
            }
            .padding(12)
            .background(VGA.panelBg)
        }
        .modifier(DOSPanelBorder(.raised, width: 2))
    }

    private func detailItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(RetroFont.tiny())
                .foregroundColor(VGA.darkGray)
            Text(value)
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.white)
        }
    }

    // MARK: - Ratings Panel

    private func ratingsPanel(_ player: Player) -> some View {
        let ratings = editedRatings ?? player.ratings
        let rows = ratingRows(for: ratings)

        return VStack(spacing: 0) {
            // Header
            HStack {
                Text("RATINGS")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.lightGray)
                Spacer()
                Text("ACTUAL")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.lightGray)
                    .frame(width: 50)
                Text("POT")
                    .font(RetroFont.small())
                    .foregroundColor(VGA.darkGray)
                    .frame(width: 40)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.titleBarBg)

            // Rating rows
            VStack(spacing: 2) {
                ForEach(rows) { row in
                    ratingRowView(row)
                }
            }
            .padding(8)
            .background(VGA.panelBg)

            // Save/Cancel bar
            if canEdit {
                HStack(spacing: 12) {
                    Spacer()
                    FPSButton("SAVE", width: 80) {
                        saveRatings()
                    }
                    FPSButton("RESET", width: 80) {
                        editedRatings = self.player?.ratings
                    }
                }
                .padding(8)
                .background(VGA.panelDark)
            }
        }
        .modifier(DOSPanelBorder(.raised, width: 2))
    }

    private func ratingRowView(_ row: RatingRow) -> some View {
        HStack(spacing: 8) {
            // Label
            Text(row.abbrev)
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.digitalAmber)
                .frame(width: 24, alignment: .leading)

            Text(row.label)
                .font(RetroFont.body())
                .foregroundColor(VGA.white)
                .frame(width: 120, alignment: .leading)

            // Rating bar
            ratingBar(current: row.current, potential: row.potential)

            // Numeric value
            Text(String(format: "%02d", row.current))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(ratingColor(row.current))
                .frame(width: 28, alignment: .trailing)

            // Potential value
            Text(String(format: "%02d", row.potential))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(VGA.darkGray)
                .frame(width: 28, alignment: .trailing)

            // +/- buttons (only if editable)
            if canEdit {
                FPSButton("-", width: 26) {
                    adjustRating(row.keyPath, by: -1)
                }
                FPSButton("+", width: 26) {
                    adjustRating(row.keyPath, by: 1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func ratingBar(current: Int, potential: Int) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(VGA.screenBg)

                // Potential bar (dimmer)
                Rectangle()
                    .fill(VGA.playSlotDark)
                    .frame(width: w * CGFloat(potential) / 99.0)

                // Current bar (bright green)
                Rectangle()
                    .fill(VGA.playSlotGreen)
                    .frame(width: w * CGFloat(current) / 99.0)
            }
            .frame(height: h)
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
        .frame(height: 14)
    }

    private func ratingColor(_ value: Int) -> Color {
        if value >= 90 { return VGA.green }
        if value >= 80 { return VGA.cyan }
        if value >= 70 { return VGA.white }
        if value >= 60 { return VGA.orange }
        return VGA.brightRed
    }

    // MARK: - Helpers

    private func playerStatusText(_ player: Player) -> String {
        if player.status.injuryType == .seasonEnding {
            return "IR - SEASON ENDING"
        } else if player.status.isInjured {
            return "INJURED"
        } else {
            return "HEALTHY"
        }
    }

    private func playerStatusColor(_ player: Player) -> Color {
        if player.status.injuryType == .seasonEnding {
            return VGA.brightRed
        } else if player.status.isInjured {
            return VGA.orange
        } else {
            return VGA.green
        }
    }

    // MARK: - Actions

    private func adjustRating(_ keyPath: WritableKeyPath<PlayerRatings, Int>, by amount: Int) {
        guard canEdit else { return }
        guard var ratings = editedRatings else { return }
        let newValue = max(1, min(99, ratings[keyPath: keyPath] + amount))
        ratings[keyPath: keyPath] = newValue
        editedRatings = ratings
    }

    private func saveRatings() {
        guard canEdit,
              let ratings = editedRatings,
              var league = gameState.currentLeague,
              let teamIndex = league.teams.firstIndex(where: { $0.id == team?.id }),
              let playerIndex = league.teams[teamIndex].roster.firstIndex(where: { $0.id == playerId })
        else { return }

        league.teams[teamIndex].roster[playerIndex].ratings = ratings
        gameState.currentLeague = league

        // Update userTeam reference
        if let userTeamId = gameState.userTeam?.id,
           let updatedTeam = league.teams.first(where: { $0.id == userTeamId }) {
            gameState.userTeam = updatedTeam
        }
    }
}

// MARK: - Team Editor Sheet

struct TeamEditorSheet: View {
    @EnvironmentObject var gameState: GameState
    let teamId: UUID
    let onDismiss: () -> Void

    @State private var editedName: String = ""
    @State private var editedCity: String = ""
    @State private var editedAbbreviation: String = ""
    @State private var editedStadium: String = ""
    @State private var editedCoach: String = ""
    @State private var editedPrimaryColor: String = ""
    @State private var editedSecondaryColor: String = ""
    @State private var editedAccentColor: String = ""

    private var team: Team? {
        gameState.currentLeague?.teams.first { $0.id == teamId }
    }

    /// Editing is only allowed before the first game
    private var canEdit: Bool {
        guard let season = gameState.currentSeason else { return true }
        let completedGames = season.schedule.filter { $0.isCompleted }
        return completedGames.isEmpty
    }

    var body: some View {
        ZStack {
            VGA.screenBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Text("TEAM EDITOR")
                        .font(RetroFont.title())
                        .foregroundColor(VGA.digitalAmber)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(VGA.panelDark)

                DOSSeparator()

                ScrollView {
                    VStack(spacing: 12) {
                        teamInfoPanel
                        teamColorsPanel
                    }
                    .padding(12)
                }

                // Bottom buttons
                HStack(spacing: 12) {
                    Spacer()
                    if canEdit {
                        FPSButton("SAVE", width: 80) {
                            saveTeam()
                            onDismiss()
                        }
                    }
                    FPSButton(canEdit ? "CANCEL" : "CLOSE", width: 80) {
                        onDismiss()
                    }
                }
                .padding(12)
                .background(VGA.panelDark)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            loadTeamData()
        }
    }

    // MARK: - Team Info Panel

    private var teamInfoPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TEAM INFORMATION")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.lightGray)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.titleBarBg)

            VStack(spacing: 8) {
                teamField("CITY", $editedCity)
                teamField("NICKNAME", $editedName)
                teamField("ABBREVIATION", $editedAbbreviation)
                teamField("STADIUM", $editedStadium)
                teamField("HEAD COACH", $editedCoach)
            }
            .padding(12)
            .background(VGA.panelBg)
        }
        .modifier(DOSPanelBorder(.raised, width: 2))
    }

    private func teamField(_ label: String, _ binding: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.digitalAmber)
                .frame(width: 120, alignment: .trailing)

            if canEdit {
                TextField("", text: binding)
                    .font(RetroFont.body())
                    .foregroundColor(VGA.white)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(VGA.screenBg)
                    .modifier(DOSPanelBorder(.sunken, width: 1))
            } else {
                Text(binding.wrappedValue.uppercased())
                    .font(RetroFont.body())
                    .foregroundColor(VGA.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VGA.screenBg)
                    .modifier(DOSPanelBorder(.sunken, width: 1))
            }
        }
    }

    // MARK: - Team Colors Panel

    private var teamColorsPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("UNIFORM COLORS")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(VGA.lightGray)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.titleBarBg)

            VStack(spacing: 8) {
                colorRow("PRIMARY", $editedPrimaryColor)
                colorRow("SECONDARY", $editedSecondaryColor)
                colorRow("ACCENT", $editedAccentColor)

                // Preview swatches
                HStack(spacing: 4) {
                    Text("PREVIEW:")
                        .font(RetroFont.bodyBold())
                        .foregroundColor(VGA.digitalAmber)
                        .frame(width: 120, alignment: .trailing)

                    colorSwatch(editedPrimaryColor)
                    colorSwatch(editedSecondaryColor)
                    colorSwatch(editedAccentColor)

                    Spacer()
                }
            }
            .padding(12)
            .background(VGA.panelBg)
        }
        .modifier(DOSPanelBorder(.raised, width: 2))
    }

    private func colorRow(_ label: String, _ binding: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.digitalAmber)
                .frame(width: 120, alignment: .trailing)

            // Color swatch
            colorSwatch(binding.wrappedValue)

            if canEdit {
                // Hex input
                HStack(spacing: 2) {
                    Text("#")
                        .font(RetroFont.body())
                        .foregroundColor(VGA.darkGray)
                    TextField("", text: binding)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(VGA.white)
                        .textFieldStyle(.plain)
                        .frame(width: 70)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(VGA.screenBg)
                .modifier(DOSPanelBorder(.sunken, width: 1))

                // Quick preset colors
                HStack(spacing: 2) {
                    colorPreset("FF0000", binding)
                    colorPreset("0000FF", binding)
                    colorPreset("00AA00", binding)
                    colorPreset("FFD700", binding)
                    colorPreset("FF6600", binding)
                    colorPreset("800080", binding)
                    colorPreset("FFFFFF", binding)
                    colorPreset("000000", binding)
                }
            } else {
                Text("#\(binding.wrappedValue.uppercased())")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(VGA.lightGray)
            }

            Spacer()
        }
    }

    private func colorSwatch(_ hex: String) -> some View {
        Rectangle()
            .fill(Color(hex: hex))
            .frame(width: 28, height: 20)
            .modifier(DOSPanelBorder(.sunken, width: 1))
    }

    private func colorPreset(_ hex: String, _ binding: Binding<String>) -> some View {
        Button(action: { binding.wrappedValue = hex }) {
            Rectangle()
                .fill(Color(hex: hex))
                .frame(width: 16, height: 16)
                .border(VGA.shadowInner, width: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadTeamData() {
        guard let team = team else { return }
        editedName = team.name
        editedCity = team.city
        editedAbbreviation = team.abbreviation
        editedStadium = team.stadiumName
        editedCoach = team.coachName
        editedPrimaryColor = team.colors.primary
        editedSecondaryColor = team.colors.secondary
        editedAccentColor = team.colors.accent
    }

    private func saveTeam() {
        guard canEdit,
              var league = gameState.currentLeague,
              let teamIndex = league.teams.firstIndex(where: { $0.id == teamId })
        else { return }

        league.teams[teamIndex].name = editedName
        league.teams[teamIndex].city = editedCity
        league.teams[teamIndex].abbreviation = editedAbbreviation
        league.teams[teamIndex].stadiumName = editedStadium
        league.teams[teamIndex].coachName = editedCoach
        league.teams[teamIndex].colors = TeamColors(
            primary: editedPrimaryColor,
            secondary: editedSecondaryColor,
            accent: editedAccentColor
        )

        gameState.currentLeague = league

        // Update userTeam reference
        if let userTeamId = gameState.userTeam?.id,
           let updatedTeam = league.teams.first(where: { $0.id == userTeamId }) {
            gameState.userTeam = updatedTeam
        }
    }
}

// MARK: - Preview

#Preview {
    PlayerEditorView(
        playerId: UUID(),
        onDismiss: {}
    )
    .environmentObject(GameState())
    .frame(width: 800, height: 600)
}
