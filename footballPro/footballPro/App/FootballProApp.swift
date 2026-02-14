//
//  FootballProApp.swift
//  footballPro
//
//  Front Page Sports: Football Pro - macOS
//

import SwiftUI
import SwiftData

@main
struct FootballProApp: App {
    @StateObject private var inputManager = InputManager()
    @StateObject private var gameState = GameState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SavedGame.self,
            PlayerData.self,
            TeamData.self,
            SeasonData.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(inputManager)
                .environmentObject(gameState)
                .frame(minWidth: 1024, minHeight: 768)
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Debug") {
                Button("Capture Screenshots...") {
                    gameState.showScreenshotCapture = true
                }
                .keyboardShortcut("s", modifiers: [.command, .shift, .option])
            }
            CommandMenu("Game") {
                Button("New Game") {
                    gameState.showNewGameDialog = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Load Game") {
                    gameState.showLoadGameDialog = true
                }
                .keyboardShortcut("o", modifiers: [.command])

                Divider()

                Button("Save Game") {
                    gameState.showSaveGameDialog = true
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!gameState.hasActiveGame)
            }
        }
    }
}

// MARK: - Content View (Root Navigation)

struct ContentView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var inputManager: InputManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch gameState.currentScreen {
            case .mainMenu:
                MainMenuView()
            case .teamManagement:
                TeamManagementView()
            case .gameDay:
                GameDayContainerView()
            case .season:
                SeasonView()
            case .management:
                ManagementHubView()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            inputManager.startListening()
        }
        .sheet(isPresented: $gameState.showSaveGameDialog) {
            SaveGameDialogView(modelContext: modelContext)
        }
        .sheet(isPresented: $gameState.showScreenshotCapture) {
            ScreenshotCaptureWindow()
                .frame(width: 560, height: 400)
        }
    }
}

// MARK: - Save Game Dialog

struct SaveGameDialogView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss
    let modelContext: ModelContext

    @State private var saveName: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FPSDialog {
                VStack(spacing: 16) {
                    Text("SAVE FRANCHISE")
                        .font(RetroFont.header())
                        .foregroundColor(VGA.digitalAmber)

                    if let team = gameState.userTeam, let season = gameState.currentSeason {
                        VStack(spacing: 4) {
                            Text(team.fullName)
                                .font(RetroFont.body())
                                .foregroundColor(VGA.white)
                            Text("\(season.year) Season - Week \(season.currentWeek)")
                                .font(RetroFont.small())
                                .foregroundColor(VGA.lightGray)
                        }
                    }

                    TextField("Save Name", text: $saveName)
                        .textFieldStyle(.plain)
                        .font(RetroFont.body())
                        .foregroundColor(VGA.white)
                        .padding(6)
                        .background(Color.black)
                        .overlay(Rectangle().stroke(VGA.panelDark, lineWidth: 1))
                        .frame(width: 280)
                        .onAppear {
                            saveName = gameState.franchiseName.isEmpty ? (gameState.userTeam?.fullName ?? "My Franchise") : gameState.franchiseName
                        }

                    HStack(spacing: 16) {
                        FPSButton("CANCEL") {
                            dismiss()
                        }
                        .keyboardShortcut(.escape, modifiers: [])

                        FPSButton("SAVE") {
                            saveGame()
                        }
                        .keyboardShortcut(.return, modifiers: [])
                        .disabled(saveName.isEmpty)
                    }
                }
                .padding(20)
            }
            .frame(width: 400, height: 250)
        }
    }

    private func saveGame() {
        gameState.saveCurrentGame(name: saveName, modelContext: modelContext)
        dismiss()
    }
}

// MARK: - Game State

enum GameScreen {
    case mainMenu
    case teamManagement
    case gameDay
    case season
    case management
}

enum Difficulty: String, CaseIterable {
    case rookie = "Rookie"
    case normal = "Normal"
    case allPro = "All-Pro"
    case allMadden = "All-Madden"

    var cpuBonus: Int {
        switch self {
        case .rookie: return -10
        case .normal: return 0
        case .allPro: return 5
        case .allMadden: return 10
        }
    }
}

enum QuarterLength: Int, CaseIterable {
    case short = 5
    case normal = 10
    case long = 15

    var displayName: String {
        "\(rawValue) minutes"
    }
}

@MainActor
class GameState: ObservableObject {
    @Published var currentScreen: GameScreen = .mainMenu
    @Published var showNewGameDialog = false
    @Published var showLoadGameDialog = false
    @Published var showSaveGameDialog = false
    @Published var showScreenshotCapture = false
    @Published var hasActiveGame = false

    @Published var currentLeague: League?
    @Published var userTeam: Team?
    @Published var currentSeason: Season?
    @Published var currentGame: Game?

    // Game settings
    @Published var difficulty: Difficulty = .normal
    @Published var quarterLength: QuarterLength = .normal

    // Current franchise name for saves
    @Published var franchiseName: String = ""

    func startNewGame(teamId: UUID, league: League, franchiseName: String, modelContext: ModelContext) {
        self.currentLeague = league
        self.userTeam = league.teams.first { $0.id == teamId }
        self.currentSeason = SeasonGenerator.generateSeason(for: league)
        self.franchiseName = franchiseName
        self.hasActiveGame = true

        // Auto-save new franchise
        autoSave(modelContext: modelContext)

        self.currentScreen = .teamManagement
    }

    func loadGame(from savedGame: SavedGame, modelContext: ModelContext) {
        let saveService = SaveGameService(modelContext: modelContext)

        do {
            let gameData = try saveService.loadGame(savedGame)
            self.currentLeague = gameData.league
            self.currentSeason = gameData.season
            self.userTeam = gameData.league.teams.first { $0.id == gameData.userTeamId }
            self.franchiseName = savedGame.name
            self.hasActiveGame = true
            self.currentScreen = .teamManagement
        } catch {
            print("Failed to load game: \(error)")
        }
    }

    func saveCurrentGame(name: String, modelContext: ModelContext) {
        guard let league = currentLeague,
              let season = currentSeason,
              let userTeam = userTeam else { return }

        let saveService = SaveGameService(modelContext: modelContext)

        do {
            _ = try saveService.saveGame(
                name: name,
                league: league,
                season: season,
                userTeamId: userTeam.id
            )
            self.franchiseName = name
        } catch {
            print("Failed to save game: \(error)")
        }
    }

    func autoSave(modelContext: ModelContext) {
        guard let league = currentLeague,
              let season = currentSeason,
              let userTeam = userTeam else { return }

        let saveService = SaveGameService(modelContext: modelContext)
        saveService.autoSave(league: league, season: season, userTeamId: userTeam.id)
    }

    func navigateTo(_ screen: GameScreen) {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentScreen = screen
        }
    }

    func teamName(for teamId: UUID) -> String {
        currentLeague?.teams.first { $0.id == teamId }?.fullName ?? "Unknown Team"
    }

    func team(for teamId: UUID) -> Team? {
        currentLeague?.teams.first { $0.id == teamId }
    }

    /// Update the user's team properties (name, city, abbreviation, stadium)
    /// Also updates the team in the league's team list so persistence works
    func updateUserTeamInfo(name: String, city: String, abbreviation: String, stadiumName: String) {
        guard var team = userTeam,
              var league = currentLeague else { return }

        team.name = name
        team.city = city
        team.abbreviation = abbreviation
        team.stadiumName = stadiumName

        // Update in league teams array
        if let idx = league.teams.firstIndex(where: { $0.id == team.id }) {
            league.teams[idx] = team
        }

        self.userTeam = team
        self.currentLeague = league
    }
}

// MARK: - SwiftData Models for Persistence

@Model
final class SavedGame {
    var id: UUID
    var name: String
    var teamName: String
    var seasonYear: Int
    var week: Int
    var lastSaved: Date
    var gameData: Data

    init(name: String, teamName: String, seasonYear: Int, week: Int, gameData: Data) {
        self.id = UUID()
        self.name = name
        self.teamName = teamName
        self.seasonYear = seasonYear
        self.week = week
        self.lastSaved = Date()
        self.gameData = gameData
    }
}

@Model
final class PlayerData {
    var id: UUID
    var savedGameId: UUID
    var playerJSON: Data

    init(savedGameId: UUID, playerJSON: Data) {
        self.id = UUID()
        self.savedGameId = savedGameId
        self.playerJSON = playerJSON
    }
}

@Model
final class TeamData {
    var id: UUID
    var savedGameId: UUID
    var teamJSON: Data

    init(savedGameId: UUID, teamJSON: Data) {
        self.id = UUID()
        self.savedGameId = savedGameId
        self.teamJSON = teamJSON
    }
}

@Model
final class SeasonData {
    var id: UUID
    var savedGameId: UUID
    var seasonJSON: Data

    init(savedGameId: UUID, seasonJSON: Data) {
        self.id = UUID()
        self.savedGameId = savedGameId
        self.seasonJSON = seasonJSON
    }
}

// MARK: - Team Management View

struct TeamManagementView: View {
    @EnvironmentObject var gameState: GameState
    @StateObject private var viewModel = TeamViewModel()
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button(action: { gameState.navigateTo(.mainMenu) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Menu")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                Spacer()

                if let team = gameState.userTeam {
                    Text(team.fullName)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button("Schedule") {
                        gameState.navigateTo(.season)
                    }

                    Button("Play Game") {
                        gameState.navigateTo(.gameDay)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            // Tab bar
            HStack(spacing: 0) {
                TeamTabButton(title: "Roster", isSelected: selectedTab == 0) { selectedTab = 0 }
                TeamTabButton(title: "Depth Chart", isSelected: selectedTab == 1) { selectedTab = 1 }
                TeamTabButton(title: "Finances", isSelected: selectedTab == 2) { selectedTab = 2 }
                TeamTabButton(title: "Stats", isSelected: selectedTab == 3) { selectedTab = 3 }
                TeamTabButton(title: "Team Info", isSelected: selectedTab == 4) { selectedTab = 4 }
                Spacer()
            }
            .padding(.horizontal)
            .background(Color.gray.opacity(0.2))

            // Content
            if let team = gameState.userTeam {
                Group {
                    switch selectedTab {
                    case 0:
                        RosterView(viewModel: viewModel)
                    case 1:
                        DepthChartTabView(team: team)
                    case 2:
                        TeamFinancesTabView(team: team)
                    case 3:
                        TeamStatsTabView(team: team)
                    case 4:
                        TeamInfoTabView()
                    default:
                        RosterView(viewModel: viewModel)
                    }
                }
                .onAppear {
                    viewModel.loadTeam(team)
                }
            } else {
                VStack {
                    Spacer()
                    Text("No team selected")
                        .foregroundColor(.secondary)
                    Button("Go to Main Menu") {
                        gameState.navigateTo(.mainMenu)
                    }
                    Spacer()
                }
            }
        }
    }
}

struct TeamTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(isSelected ? Color.blue : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Team Info Tab View (Rename Team)

struct TeamInfoTabView: View {
    @EnvironmentObject var gameState: GameState

    @State private var teamName: String = ""
    @State private var teamCity: String = ""
    @State private var teamAbbr: String = ""
    @State private var stadiumName: String = ""
    @State private var showSavedConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("TEAM IDENTITY")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 16)

                // Current preview
                if !teamCity.isEmpty && !teamName.isEmpty {
                    HStack {
                        Text("Preview:")
                            .foregroundColor(.secondary)
                        Text("\(teamCity) \(teamName)")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("(\(teamAbbr.uppercased()))")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }

                // Edit fields
                VStack(alignment: .leading, spacing: 16) {
                    teamInfoField(label: "CITY", placeholder: "e.g. Philadelphia", text: $teamCity)
                    teamInfoField(label: "TEAM NAME", placeholder: "e.g. Eagles", text: $teamName)
                    teamInfoField(label: "ABBREVIATION", placeholder: "e.g. PHI (3 letters)", text: $teamAbbr)
                        .onChange(of: teamAbbr) { _, newValue in
                            // Limit to 3 characters, uppercase
                            if newValue.count > 3 {
                                teamAbbr = String(newValue.prefix(3)).uppercased()
                            } else {
                                teamAbbr = newValue.uppercased()
                            }
                        }
                    teamInfoField(label: "STADIUM", placeholder: "e.g. Veterans Stadium", text: $stadiumName)
                }

                // Save button
                HStack {
                    Button(action: saveChanges) {
                        Text("SAVE CHANGES")
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(hasChanges ? Color.green : Color.gray)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasChanges)

                    if showSavedConfirmation {
                        Text("Saved!")
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }

                    Spacer()

                    Button(action: resetFields) {
                        Text("RESET")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .background(Color(.windowBackgroundColor))
        .onAppear {
            resetFields()
        }
    }

    private var hasChanges: Bool {
        guard let team = gameState.userTeam else { return false }
        return teamName != team.name ||
               teamCity != team.city ||
               teamAbbr != team.abbreviation ||
               stadiumName != team.stadiumName
    }

    private func resetFields() {
        guard let team = gameState.userTeam else { return }
        teamName = team.name
        teamCity = team.city
        teamAbbr = team.abbreviation
        stadiumName = team.stadiumName
        showSavedConfirmation = false
    }

    private func saveChanges() {
        let trimmedName = teamName.trimmingCharacters(in: .whitespaces)
        let trimmedCity = teamCity.trimmingCharacters(in: .whitespaces)
        let trimmedAbbr = teamAbbr.trimmingCharacters(in: .whitespaces).uppercased()
        let trimmedStadium = stadiumName.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty, !trimmedCity.isEmpty, !trimmedAbbr.isEmpty else { return }

        gameState.updateUserTeamInfo(
            name: trimmedName,
            city: trimmedCity,
            abbreviation: trimmedAbbr,
            stadiumName: trimmedStadium
        )

        showSavedConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showSavedConfirmation = false
        }
    }

    private func teamInfoField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(.white)
                .font(.body)
        }
    }
}

// MARK: - Depth Chart Tab View

struct DepthChartTabView: View {
    let team: Team

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("DEPTH CHART")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                // Offense
                DepthChartSectionView(
                    title: "OFFENSE",
                    positions: [.quarterback, .runningBack, .wideReceiver, .tightEnd, .leftTackle, .leftGuard, .center, .rightGuard, .rightTackle],
                    depthChart: team.depthChart,
                    roster: team.roster
                )

                // Defense
                DepthChartSectionView(
                    title: "DEFENSE",
                    positions: [.defensiveEnd, .defensiveTackle, .outsideLinebacker, .middleLinebacker, .cornerback, .freeSafety, .strongSafety],
                    depthChart: team.depthChart,
                    roster: team.roster
                )

                // Special Teams
                DepthChartSectionView(
                    title: "SPECIAL TEAMS",
                    positions: [.kicker, .punter],
                    depthChart: team.depthChart,
                    roster: team.roster
                )
            }
            .padding()
        }
    }
}

struct DepthChartSectionView: View {
    let title: String
    let positions: [Position]
    let depthChart: DepthChart
    let roster: [Player]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.orange)

            ForEach(Array(positions), id: \.rawValue) { position in
                depthChartRow(for: position)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func depthChartRow(for position: Position) -> some View {
        HStack {
            Text(position.displayName)
                .frame(width: 120, alignment: .leading)
                .foregroundColor(.secondary)

            if let playerIds = depthChart.positions[position] {
                let playersToShow = Array(playerIds.prefix(3))
                ForEach(Array(playersToShow.enumerated()), id: \.offset) { index, playerId in
                    if let player = roster.first(where: { $0.id == playerId }) {
                        playerDepthItem(player: player, depth: index + 1)
                    }
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func playerDepthItem(player: Player, depth: Int) -> some View {
        HStack {
            Text("\(depth).")
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(player.fullName)
                .frame(width: 150, alignment: .leading)
            Text("\(player.overall)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(ratingColor(player.overall))
                .frame(width: 40)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(depth == 1 ? Color.blue.opacity(0.2) : Color.clear)
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

// MARK: - Team Finances Tab View

struct TeamFinancesTabView: View {
    let team: Team

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("TEAM FINANCES")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                GroupBox("SALARY CAP") {
                    VStack(spacing: 12) {
                        FinanceRow(label: "Salary Cap", value: formatCurrency(team.finances.salaryCap))
                        FinanceRow(label: "Current Payroll", value: formatCurrency(team.finances.currentPayroll))
                        FinanceRow(label: "Available Cap", value: formatCurrency(team.finances.availableCap), isHighlighted: true)
                        FinanceRow(label: "Dead Money", value: formatCurrency(team.finances.deadMoney))
                    }
                }

                GroupBox("HIGHEST PAID PLAYERS") {
                    let topContracts = team.roster.sorted { $0.contract.capHit > $1.contract.capHit }.prefix(10)
                    ForEach(Array(topContracts.enumerated()), id: \.element.id) { index, player in
                        HStack {
                            Text("\(index + 1).")
                                .frame(width: 30)
                                .foregroundColor(.secondary)
                            Text(player.position.rawValue)
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                            Text(player.fullName)
                                .frame(width: 200, alignment: .leading)
                            Spacer()
                            Text(formatCurrency(player.contract.capHit))
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
        }
    }

    private func formatCurrency(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "$%.1fM", Double(value) / 1000.0)
        }
        return "$\(value)K"
    }
}

struct FinanceRow: View {
    let label: String
    let value: String
    var isHighlighted: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(isHighlighted ? .bold : .regular)
                .foregroundColor(isHighlighted ? .green : .primary)
        }
    }
}

// MARK: - Team Stats Tab View

struct TeamStatsTabView: View {
    let team: Team

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("TEAM STATISTICS")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                GroupBox("TEAM RATINGS") {
                    HStack(spacing: 40) {
                        RatingCircle(label: "OVERALL", value: team.overallRating)
                        RatingCircle(label: "OFFENSE", value: team.offensiveRating)
                        RatingCircle(label: "DEFENSE", value: team.defensiveRating)
                    }
                    .padding()
                }

                GroupBox("RECORD") {
                    HStack(spacing: 40) {
                        VStack {
                            Text("\(team.record.wins)")
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                            Text("WINS")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(team.record.losses)")
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                            Text("LOSSES")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(team.record.ties)")
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Text("TIES")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }

                GroupBox("STAT LEADERS") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let qb = team.roster.filter({ $0.position == .quarterback }).max(by: { $0.seasonStats.passingYards < $1.seasonStats.passingYards }) {
                            StatLeaderRow(title: "Passing Yards", player: qb, value: "\(qb.seasonStats.passingYards) yds")
                        }
                        if let rb = team.roster.max(by: { $0.seasonStats.rushingYards < $1.seasonStats.rushingYards }) {
                            StatLeaderRow(title: "Rushing Yards", player: rb, value: "\(rb.seasonStats.rushingYards) yds")
                        }
                        if let wr = team.roster.filter({ $0.position == .wideReceiver }).max(by: { $0.seasonStats.receivingYards < $1.seasonStats.receivingYards }) {
                            StatLeaderRow(title: "Receiving Yards", player: wr, value: "\(wr.seasonStats.receivingYards) yds")
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct RatingCircle: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(value) / 100)
                    .stroke(ratingColor(value), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(value)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(ratingColor(value))
            }
            .frame(width: 80, height: 80)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
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
}

struct StatLeaderRow: View {
    let title: String
    let player: Player
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 150, alignment: .leading)
                .foregroundColor(.secondary)
            Text(player.fullName)
                .frame(width: 200, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
            Spacer()
        }
    }
}

// MARK: - Season View

struct SeasonView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = SeasonViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { gameState.navigateTo(.teamManagement) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Team")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                Spacer()

                Text("SEASON SCHEDULE")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                // Sim Week Button
                if let season = gameState.currentSeason {
                    let hasUnplayedGames = season.gamesForWeek(season.currentWeek).contains { !$0.isCompleted }
                    if hasUnplayedGames {
                        Button(action: {
                            Task {
                                await simulateCurrentWeek()
                            }
                        }) {
                            HStack(spacing: 6) {
                                if viewModel.isSimulating {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "forward.fill")
                                }
                                Text("Sim Week")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSimulating)
                    }
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            if let season = gameState.currentSeason, let team = gameState.userTeam {
                // Next Game Banner
                if let nextGame = season.nextGame(for: team.id) {
                    NextGameBanner(
                        game: nextGame,
                        gameState: gameState,
                        onPlay: { gameState.navigateTo(.gameDay) }
                    )
                } else {
                    // Season complete
                    VStack(spacing: 12) {
                        Text("SEASON COMPLETE")
                            .font(.title2.bold())
                            .foregroundColor(.green)
                        Text("Final Record: \(team.record.displayRecord)")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Week \(season.currentWeek) of \(season.totalWeeks)")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        ForEach(1...season.totalWeeks, id: \.self) { week in
                            let weekGames = season.gamesForWeek(week)
                            WeekSectionView(
                                week: week,
                                games: weekGames,
                                currentWeek: season.currentWeek,
                                userTeamId: team.id,
                                gameState: gameState
                            )
                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    Spacer()
                    Text("No season data")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .onAppear {
            loadViewModel()
        }
        .onChange(of: gameState.currentSeason?.currentWeek) { _, _ in
            loadViewModel()
        }
    }

    private func loadViewModel() {
        if let season = gameState.currentSeason,
           let league = gameState.currentLeague,
           let team = gameState.userTeam {
            viewModel.loadSeason(season, league: league, userTeam: team)
        }
    }

    private func simulateCurrentWeek() async {
        await viewModel.simulateWeek()

        // Update game state with simulated results
        if let updatedSeason = viewModel.season {
            gameState.currentSeason = updatedSeason
        }

        // Auto-save after simulation
        gameState.autoSave(modelContext: modelContext)
    }
}

// MARK: - Next Game Banner

struct NextGameBanner: View {
    let game: ScheduledGame
    let gameState: GameState
    let onPlay: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT GAME - WEEK \(game.week)")
                    .font(.caption.bold())
                    .foregroundColor(.orange)

                HStack(spacing: 8) {
                    Text(gameState.teamName(for: game.awayTeamId))
                        .font(.title3.bold())
                    Text("@")
                        .foregroundColor(.secondary)
                    Text(gameState.teamName(for: game.homeTeamId))
                        .font(.title3.bold())
                }
            }

            Spacer()

            Button(action: onPlay) {
                Text("PLAY GAME")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.orange.opacity(0.15))
    }
}

struct WeekSectionView: View {
    let week: Int
    let games: [ScheduledGame]
    let currentWeek: Int
    let userTeamId: UUID
    let gameState: GameState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WEEK \(week)")
                    .font(.headline)
                    .foregroundColor(week == currentWeek ? .orange : .secondary)

                if week == currentWeek {
                    Text("CURRENT")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .foregroundColor(.black)
                        .cornerRadius(4)
                }
            }

            ForEach(games) { game in
                let isUserGame = game.homeTeamId == userTeamId || game.awayTeamId == userTeamId
                HStack {
                    Text(gameState.teamName(for: game.awayTeamId))
                        .frame(width: 150, alignment: .trailing)

                    Text("@")
                        .foregroundColor(.secondary)

                    Text(gameState.teamName(for: game.homeTeamId))
                        .frame(width: 150, alignment: .leading)

                    Spacer()

                    if let result = game.result {
                        Text("\(result.awayScore) - \(result.homeScore)")
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("--")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(isUserGame ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(4)
            }
        }
        .padding()
        .background(week == currentWeek ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Game Day Container View

struct GameDayContainerView: View {
    @EnvironmentObject var gameState: GameState
    @State private var showGameSetup = true

    var body: some View {
        if showGameSetup {
            GameSetupView(showGameSetup: $showGameSetup)
        } else if gameState.currentGame != nil {
            GameDayView()
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("NO GAME SCHEDULED")
                        .font(RetroFont.header())
                        .foregroundColor(VGA.lightGray)
                    FPSButton("BACK TO TEAM") {
                        gameState.navigateTo(.teamManagement)
                    }
                }
            }
        }
    }
}

// MARK: - Game Setup View

struct GameSetupView: View {
    @EnvironmentObject var gameState: GameState
    @Binding var showGameSetup: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    FPSButton("< BACK") {
                        gameState.navigateTo(.teamManagement)
                    }

                    Spacer()

                    Text("GAME SETUP")
                        .font(RetroFont.header())
                        .foregroundColor(VGA.digitalAmber)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(VGA.panelDark)
                .modifier(DOSPanelBorder(.raised, width: 1))

                Spacer()

                FPSDialog {
                    VStack(spacing: 24) {
                        // Matchup
                        if let userTeam = gameState.userTeam,
                           let season = gameState.currentSeason,
                           let nextGame = season.nextGame(for: userTeam.id) {
                            let opponent = nextGame.homeTeamId == userTeam.id
                                ? gameState.team(for: nextGame.awayTeamId)
                                : gameState.team(for: nextGame.homeTeamId)
                            let isHome = nextGame.homeTeamId == userTeam.id

                            VStack(spacing: 12) {
                                Text("WEEK \(nextGame.week)")
                                    .font(RetroFont.small())
                                    .foregroundColor(VGA.lightGray)

                                HStack(spacing: 40) {
                                    TeamPreviewCard(team: isHome ? opponent : userTeam, isUser: !isHome)
                                    Text("@")
                                        .font(RetroFont.large())
                                        .foregroundColor(VGA.darkGray)
                                    TeamPreviewCard(team: isHome ? userTeam : opponent, isUser: isHome)
                                }
                            }
                        }

                        DOSSeparator()

                        // Settings
                        VStack(spacing: 16) {
                            // Difficulty
                            VStack(alignment: .leading, spacing: 6) {
                                Text("DIFFICULTY")
                                    .font(RetroFont.small())
                                    .foregroundColor(VGA.lightGray)

                                HStack(spacing: 8) {
                                    ForEach(Difficulty.allCases, id: \.self) { diff in
                                        Button(action: { gameState.difficulty = diff }) {
                                            Text(diff.rawValue.uppercased())
                                                .font(RetroFont.small())
                                                .foregroundColor(gameState.difficulty == diff ? .black : VGA.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(gameState.difficulty == diff ? VGA.digitalAmber : VGA.buttonBg)
                                                .modifier(DOSPanelBorder(gameState.difficulty == diff ? .sunken : .raised, width: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            // Quarter Length
                            VStack(alignment: .leading, spacing: 6) {
                                Text("QUARTER LENGTH")
                                    .font(RetroFont.small())
                                    .foregroundColor(VGA.lightGray)

                                HStack(spacing: 8) {
                                    ForEach(QuarterLength.allCases, id: \.self) { length in
                                        Button(action: { gameState.quarterLength = length }) {
                                            Text(length.displayName.uppercased())
                                                .font(RetroFont.small())
                                                .foregroundColor(gameState.quarterLength == length ? .black : VGA.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(gameState.quarterLength == length ? VGA.digitalAmber : VGA.buttonBg)
                                                .modifier(DOSPanelBorder(gameState.quarterLength == length ? .sunken : .raised, width: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Start button
                        FPSButton("START GAME") {
                            startGame()
                        }
                    }
                    .padding(24)
                }

                Spacer()
            }
        }
    }

    private func startGame() {
        guard let userTeam = gameState.userTeam,
              let season = gameState.currentSeason,
              let nextGame = season.nextGame(for: userTeam.id) else { return }

        let homeTeam = gameState.currentLeague?.team(withId: nextGame.homeTeamId)
        let weather = Weather.forZone(homeTeam?.weatherZone ?? 2)
        let game = Game(
            homeTeamId: nextGame.homeTeamId,
            awayTeamId: nextGame.awayTeamId,
            week: nextGame.week,
            seasonYear: season.year,
            weather: weather
        )
        gameState.currentGame = game
        showGameSetup = false
    }
}

struct TeamPreviewCard: View {
    let team: Team?
    let isUser: Bool

    var body: some View {
        VStack(spacing: 8) {
            if let team = team {
                Rectangle()
                    .fill(team.colors.primaryColor)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(team.abbreviation)
                            .font(RetroFont.large())
                            .foregroundColor(.white)
                    )
                    .modifier(DOSPanelBorder(.raised, width: 1))

                Text(team.name.uppercased())
                    .font(RetroFont.body())
                    .foregroundColor(isUser ? VGA.digitalAmber : VGA.white)

                Text(team.record.displayRecord)
                    .font(RetroFont.small())
                    .foregroundColor(VGA.lightGray)

                Text("OVR \(team.overallRating)")
                    .font(RetroFont.body())
                    .foregroundColor(ratingColor(team.overallRating))
            }
        }
        .frame(width: 150)
    }

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 90...99: return VGA.green
        case 80...89: return VGA.cyan
        case 70...79: return VGA.digitalAmber
        default: return VGA.brightRed
        }
    }
}

// MARK: - Management Hub View

struct ManagementHubView: View {
    @EnvironmentObject var gameState: GameState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    FPSButton("< TEAM") {
                        gameState.navigateTo(.teamManagement)
                    }

                    Spacer()

                    Text("MANAGEMENT")
                        .font(RetroFont.header())
                        .foregroundColor(VGA.digitalAmber)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(VGA.panelDark)
                .modifier(DOSPanelBorder(.raised, width: 1))

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 20) {
                        ManagementCard(title: "Free Agency", icon: "person.badge.plus", description: "Sign free agents")
                        ManagementCard(title: "Trade", icon: "arrow.left.arrow.right", description: "Trade players")
                        ManagementCard(title: "Draft", icon: "list.number", description: "View draft prospects")
                        ManagementCard(title: "Injuries", icon: "cross.case", description: "View injured players")
                    }
                    .padding()
                }
            }
        }
    }
}

struct ManagementCard: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(VGA.digitalAmber)

            Text(title.uppercased())
                .font(RetroFont.body())
                .foregroundColor(VGA.white)

            Text(description)
                .font(RetroFont.small())
                .foregroundColor(VGA.lightGray)
                .multilineTextAlignment(.center)
        }
        .frame(width: 200, height: 150)
        .padding()
        .background(VGA.panelBg)
        .modifier(DOSPanelBorder(.raised, width: 1))
    }
}
