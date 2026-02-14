//
//  MainMenuView.swift
//  footballPro
//
//  FPS Football Pro '93 main menu — black background, charcoal dialog, red buttons
//

import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var inputManager: InputManager

    @State private var selectedIndex = 0
    @State private var showNewGameSheet = false
    @State private var showLoadGameSheet = false
    @State private var showSettingsSheet = false

    private let menuItems = ["New Game", "Load Game", "Settings", "Quit"]

    var body: some View {
        ZStack {
            // Pure black background
            Color.black.ignoresSafeArea()

            // Scanline CRT effect
            Canvas { context, size in
                for y in stride(from: 0, to: size.height, by: 3) {
                    let line = Path(CGRect(x: 0, y: y, width: size.width, height: 1))
                    context.fill(line, with: .color(Color.white.opacity(0.03)))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Title block
                VStack(spacing: 8) {
                    Text("FRONT PAGE SPORTS")
                        .font(RetroFont.header())
                        .foregroundColor(VGA.lightGray)
                        .tracking(4)

                    HStack(spacing: 0) {
                        Text("FOOTBALL ")
                            .font(RetroFont.huge())
                            .foregroundColor(VGA.white)
                        Text("PRO")
                            .font(RetroFont.huge())
                            .foregroundColor(VGA.brightRed)
                    }
                    .shadow(color: .black, radius: 0, x: 2, y: 2)

                    Text("'93 SEASON")
                        .font(RetroFont.body())
                        .foregroundColor(VGA.digitalAmber)
                        .tracking(2)
                }
                .padding(.bottom, 50)

                // Menu dialog — charcoal frame with red buttons
                FPSDialog {
                    VStack(spacing: 6) {
                        ForEach(Array(menuItems.enumerated()), id: \.offset) { index, item in
                            FPSMenuButton(
                                title: item.uppercased(),
                                isSelected: selectedIndex == index
                            ) {
                                handleSelection(index)
                            }
                            .onHover { hovering in
                                if hovering { selectedIndex = index }
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(width: 300)

                Spacer()

                // Footer
                HStack {
                    Text("v1.0")
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.darkGray)

                    Spacer()

                    if inputManager.isControllerConnected {
                        HStack(spacing: 4) {
                            Text("\u{25A0}")
                                .foregroundColor(VGA.green)
                            Text("CONTROLLER CONNECTED")
                        }
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.green)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .handleKeyboardInput()
        .sheet(isPresented: $showNewGameSheet) {
            NewGameView()
        }
        .sheet(isPresented: $showLoadGameSheet) {
            LoadGameView()
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
    }

    private func handleSelection(_ index: Int) {
        switch index {
        case 0:
            showNewGameSheet = true
        case 1:
            showLoadGameSheet = true
        case 2:
            showSettingsSheet = true
        case 3:
            NSApplication.shared.terminate(nil)
        default:
            break
        }
    }
}

// MARK: - FPS Menu Button (Dark Maroon, highlighted on select)

struct FPSMenuButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(isSelected ? "\u{25BA}" : " ")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.digitalAmber)
                    .frame(width: 16)

                Text(title)
                    .font(RetroFont.header())
                    .foregroundColor(isSelected ? .white : VGA.lightGray)

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? VGA.buttonBg : VGA.panelDark)
            .overlay(
                GeometryReader { geo in
                    if isSelected {
                        let w = geo.size.width
                        let h = geo.size.height
                        // Top highlight
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: 0))
                            p.addLine(to: CGPoint(x: w, y: 0))
                            p.addLine(to: CGPoint(x: w - 1, y: 1))
                            p.addLine(to: CGPoint(x: 1, y: 1))
                            p.closeSubpath()
                        }.fill(VGA.buttonHighlight)

                        // Left highlight
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: 0))
                            p.addLine(to: CGPoint(x: 1, y: 1))
                            p.addLine(to: CGPoint(x: 1, y: h - 1))
                            p.addLine(to: CGPoint(x: 0, y: h))
                            p.closeSubpath()
                        }.fill(VGA.buttonHighlight)

                        // Bottom shadow
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: h))
                            p.addLine(to: CGPoint(x: w, y: h))
                            p.addLine(to: CGPoint(x: w - 1, y: h - 1))
                            p.addLine(to: CGPoint(x: 1, y: h - 1))
                            p.closeSubpath()
                        }.fill(VGA.buttonShadow)

                        // Right shadow
                        Path { p in
                            p.move(to: CGPoint(x: w, y: 0))
                            p.addLine(to: CGPoint(x: w, y: h))
                            p.addLine(to: CGPoint(x: w - 1, y: h - 1))
                            p.addLine(to: CGPoint(x: w - 1, y: 1))
                            p.closeSubpath()
                        }.fill(VGA.buttonShadow)
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - DOS Menu Item Button (legacy compat)

struct DOSMenuItemButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        FPSMenuButton(title: title.uppercased(), isSelected: isSelected, action: action)
    }
}

// MARK: - New Game View

struct NewGameView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTeamId: UUID?
    @State private var league: League?
    @State private var teams: [Team] = []
    @State private var franchiseName: String = ""
    @State private var showNamePrompt = false
    @State private var pendingTeam: Team?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                FPSDialog("NEW FRANCHISE") {
                    if teams.isEmpty {
                        VStack(spacing: 12) {
                            Text("GENERATING LEAGUE...")
                                .font(RetroFont.body())
                                .foregroundColor(VGA.digitalAmber)
                            ProgressView()
                                .tint(VGA.digitalAmber)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                        .onAppear {
                            let generatedLeague = LeagueGenerator.generateLeague()
                            league = generatedLeague
                            teams = generatedLeague.teams
                        }
                    } else {
                        VStack(spacing: 0) {
                            Text("SELECT YOUR TEAM")
                                .font(RetroFont.small())
                                .foregroundColor(VGA.darkGray)
                                .padding(.vertical, 4)

                            ScrollView {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 4) {
                                    ForEach(teams) { team in
                                        TeamSelectionCard(
                                            team: team,
                                            isSelected: selectedTeamId == team.id
                                        ) {
                                            selectedTeamId = team.id
                                            pendingTeam = team
                                            franchiseName = "\(team.city) \(team.name)"
                                            showNamePrompt = true
                                        }
                                    }
                                }
                                .padding(4)
                            }

                            HStack {
                                Spacer()
                                FPSButton("CANCEL") {
                                    dismiss()
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
        .sheet(isPresented: $showNamePrompt) {
            FranchiseNamePrompt(
                franchiseName: $franchiseName,
                teamName: pendingTeam?.fullName ?? "",
                onConfirm: {
                    startFranchise()
                },
                onCancel: {
                    showNamePrompt = false
                    selectedTeamId = nil
                    pendingTeam = nil
                }
            )
        }
    }

    private func startFranchise() {
        guard let league = league, let team = pendingTeam else { return }
        showNamePrompt = false
        gameState.startNewGame(
            teamId: team.id,
            league: league,
            franchiseName: franchiseName,
            modelContext: modelContext
        )
        dismiss()
    }
}

// MARK: - Franchise Name Prompt

struct FranchiseNamePrompt: View {
    @Binding var franchiseName: String
    let teamName: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FPSDialog("NAME YOUR FRANCHISE") {
                VStack(spacing: 16) {
                    Text("PLAYING AS: \(teamName.uppercased())")
                        .font(RetroFont.small())
                        .foregroundColor(VGA.cyan)

                    DOSPanel(.sunken, backgroundColor: Color.black) {
                        TextField("", text: $franchiseName)
                            .font(RetroFont.body())
                            .foregroundColor(VGA.green)
                            .textFieldStyle(.plain)
                            .padding(6)
                    }
                    .frame(width: 280)

                    HStack(spacing: 12) {
                        FPSButton("CANCEL") {
                            onCancel()
                        }
                        FPSButton("START") {
                            onConfirm()
                        }
                        .disabled(franchiseName.isEmpty)
                    }
                }
                .padding(16)
            }
            .frame(width: 360)
        }
        .frame(width: 400, height: 250)
    }
}

// MARK: - Team Selection Card

struct TeamSelectionCard: View {
    let team: Team
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Team color header
                HStack {
                    Text(team.abbreviation)
                        .font(RetroFont.header())
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(team.colors.primaryColor)

                // Team info
                VStack(spacing: 2) {
                    Text(team.city.uppercased())
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.darkGray)

                    Text(team.name.uppercased())
                        .font(RetroFont.bodyBold())
                        .foregroundColor(VGA.white)

                    HStack(spacing: 4) {
                        Text("OVR:")
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.darkGray)
                        Text("\(team.overallRating)")
                            .font(RetroFont.bodyBold())
                            .foregroundColor(ratingColor(team.overallRating))
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(isSelected ? VGA.buttonBg : VGA.panelDark)
            }
            .modifier(DOSPanelBorder(isSelected ? .sunken : .raised, width: 1))
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Load Game View

struct LoadGameView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var savedGames: [SavedGame] = []
    @State private var selectedGame: SavedGame?
    @State private var isLoading = true
    @State private var showDeleteConfirm = false
    @State private var gameToDelete: SavedGame?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FPSDialog("LOAD FRANCHISE") {
                VStack(spacing: 0) {
                    if isLoading {
                        VStack(spacing: 8) {
                            Text("LOADING SAVED GAMES...")
                                .font(RetroFont.body())
                                .foregroundColor(VGA.digitalAmber)
                            ProgressView()
                                .tint(VGA.digitalAmber)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                    } else if savedGames.isEmpty {
                        VStack(spacing: 8) {
                            Text("NO SAVED FRANCHISES")
                                .font(RetroFont.header())
                                .foregroundColor(VGA.digitalAmber)
                            Text("Start a new franchise to begin playing!")
                                .font(RetroFont.small())
                                .foregroundColor(VGA.darkGray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(16)
                    } else {
                        DOSPanel(.sunken, backgroundColor: Color.black) {
                            ScrollView {
                                VStack(spacing: 1) {
                                    ForEach(savedGames) { save in
                                        SavedGameRow(
                                            savedGame: save,
                                            isSelected: selectedGame?.id == save.id
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedGame = save
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                gameToDelete = save
                                                showDeleteConfirm = true
                                            } label: {
                                                Text("Delete")
                                            }
                                        }
                                    }
                                }
                                .padding(2)
                            }
                        }
                        .frame(height: 250)
                    }

                    HStack(spacing: 12) {
                        Spacer()

                        FPSButton("CANCEL") {
                            dismiss()
                        }

                        FPSButton("LOAD") {
                            loadSelectedGame()
                        }
                        .opacity(selectedGame == nil ? 0.4 : 1.0)
                        .disabled(selectedGame == nil)

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 600, height: 450)
        .onAppear {
            loadSavedGames()
        }
        .alert("Delete Save?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let game = gameToDelete {
                    deleteSavedGame(game)
                }
            }
        } message: {
            Text("Are you sure you want to delete this saved franchise? This cannot be undone.")
        }
    }

    private func loadSavedGames() {
        let saveService = SaveGameService(modelContext: modelContext)
        do {
            savedGames = try saveService.listSavedGames()
        } catch {
            print("Failed to load saved games: \(error)")
            savedGames = []
        }
        isLoading = false
    }

    private func loadSelectedGame() {
        guard let save = selectedGame else { return }
        gameState.loadGame(from: save, modelContext: modelContext)
        dismiss()
    }

    private func deleteSavedGame(_ save: SavedGame) {
        let saveService = SaveGameService(modelContext: modelContext)
        do {
            try saveService.deleteSavedGame(save)
            savedGames.removeAll { $0.id == save.id }
            if selectedGame?.id == save.id {
                selectedGame = nil
            }
        } catch {
            print("Failed to delete saved game: \(error)")
        }
    }
}

// MARK: - Saved Game Row

struct SavedGameRow: View {
    let savedGame: SavedGame
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(isSelected ? "\u{25BA}" : " ")
                .font(RetroFont.small())
                .foregroundColor(VGA.digitalAmber)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(savedGame.name.uppercased())
                    .font(RetroFont.bodyBold())
                    .foregroundColor(isSelected ? .white : VGA.lightGray)

                HStack(spacing: 8) {
                    Text(savedGame.teamName)
                        .font(RetroFont.tiny())
                        .foregroundColor(isSelected ? VGA.digitalAmber : VGA.cyan)

                    Text("\u{2502}")
                        .foregroundColor(VGA.darkGray)

                    Text("\(savedGame.seasonYear) Season")
                        .font(RetroFont.tiny())
                        .foregroundColor(isSelected ? VGA.digitalAmber : VGA.lightGray)

                    Text("\u{2502}")
                        .foregroundColor(VGA.darkGray)

                    Text("Week \(savedGame.week)")
                        .font(RetroFont.tiny())
                        .foregroundColor(isSelected ? VGA.digitalAmber : VGA.orange)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(savedGame.lastSaved, style: .date)
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.darkGray)
                Text(savedGame.lastSaved, style: .time)
                    .font(RetroFont.tiny())
                    .foregroundColor(VGA.darkGray)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? VGA.buttonBg : Color.black)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("simulationSpeed") private var simulationSpeed = "Normal"
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("showTutorials") private var showTutorials = true

    private let speeds = ["Slow", "Normal", "Fast", "Instant"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FPSDialog("SETTINGS") {
                VStack(spacing: 0) {
                    // Gameplay section
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GAMEPLAY")
                            .font(RetroFont.small())
                            .foregroundColor(VGA.cyan)
                            .padding(.horizontal, 8)
                            .padding(.top, 8)

                        DOSSeparator()

                        HStack {
                            Text("SIM SPEED:")
                                .font(RetroFont.body())
                                .foregroundColor(VGA.lightGray)

                            Spacer()

                            HStack(spacing: 2) {
                                ForEach(speeds, id: \.self) { speed in
                                    Button(action: { simulationSpeed = speed }) {
                                        Text(speed.uppercased())
                                            .font(RetroFont.small())
                                            .foregroundColor(simulationSpeed == speed ? .white : VGA.darkGray)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(simulationSpeed == speed ? VGA.buttonBg : VGA.panelDark)
                                            .modifier(DOSPanelBorder(simulationSpeed == speed ? .sunken : .raised, width: 1))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)

                        HStack {
                            Text("TUTORIALS:")
                                .font(RetroFont.body())
                                .foregroundColor(VGA.lightGray)
                            Spacer()
                            DOSToggle(isOn: $showTutorials)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }

                    // Audio section
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AUDIO")
                            .font(RetroFont.small())
                            .foregroundColor(VGA.cyan)
                            .padding(.horizontal, 8)
                            .padding(.top, 8)

                        DOSSeparator()

                        HStack {
                            Text("SOUND FX:")
                                .font(RetroFont.body())
                                .foregroundColor(VGA.lightGray)
                            Spacer()
                            DOSToggle(isOn: $soundEnabled)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }

                    Spacer()

                    HStack {
                        Spacer()
                        FPSButton("DONE") {
                            dismiss()
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - DOS Toggle

struct DOSToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 4) {
                Text(isOn ? "[\u{2588}]" : "[ ]")
                    .font(RetroFont.body())
                    .foregroundColor(isOn ? VGA.green : VGA.darkGray)
                Text(isOn ? "ON" : "OFF")
                    .font(RetroFont.small())
                    .foregroundColor(isOn ? VGA.green : VGA.darkGray)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MainMenuView()
        .environmentObject(GameState())
        .environmentObject(InputManager())
}
