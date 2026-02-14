//
//  SaveGameService.swift
//  footballPro
//
//  Save/load game state service
//

import Foundation
import SwiftData

@MainActor
class SaveGameService: ObservableObject {
    private let modelContext: ModelContext?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    // MARK: - Save Game

    func saveGame(
        name: String,
        league: League,
        season: Season,
        userTeamId: UUID
    ) throws -> SavedGame {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // Encode game state
        let gameState = GameSaveState(
            league: league,
            season: season,
            userTeamId: userTeamId
        )

        let gameData = try encoder.encode(gameState)

        // Create saved game record
        let savedGame = SavedGame(
            name: name,
            teamName: league.team(withId: userTeamId)?.fullName ?? "Unknown",
            seasonYear: season.year,
            week: season.currentWeek,
            gameData: gameData
        )

        modelContext?.insert(savedGame)
        try modelContext?.save()

        return savedGame
    }

    // MARK: - Load Game

    func loadGame(_ savedGame: SavedGame) throws -> GameSaveState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(GameSaveState.self, from: savedGame.gameData)
    }

    // MARK: - List Saved Games

    func listSavedGames() throws -> [SavedGame] {
        let descriptor = FetchDescriptor<SavedGame>(
            sortBy: [SortDescriptor(\.lastSaved, order: .reverse)]
        )
        return try modelContext?.fetch(descriptor) ?? []
    }

    // MARK: - Delete Saved Game

    func deleteSavedGame(_ savedGame: SavedGame) throws {
        modelContext?.delete(savedGame)
        try modelContext?.save()
    }

    // MARK: - Auto Save

    func autoSave(league: League, season: Season, userTeamId: UUID) {
        do {
            // Check for existing auto-save
            let descriptor = FetchDescriptor<SavedGame>(
                predicate: #Predicate { $0.name == "Auto Save" }
            )
            let existingAutoSaves = try modelContext?.fetch(descriptor) ?? []

            // Delete old auto-save
            for autoSave in existingAutoSaves {
                modelContext?.delete(autoSave)
            }

            // Create new auto-save
            _ = try saveGame(name: "Auto Save", league: league, season: season, userTeamId: userTeamId)
        } catch {
            print("Auto save failed: \(error)")
        }
    }
}

// MARK: - Game Save State

struct GameSaveState: Codable {
    var league: League
    var season: Season
    var userTeamId: UUID
    var savedAt: Date

    init(league: League, season: Season, userTeamId: UUID) {
        self.league = league
        self.season = season
        self.userTeamId = userTeamId
        self.savedAt = Date()
    }
}

// MARK: - Quick Save/Load

extension SaveGameService {

    private static let quickSaveKey = "footballPro.quickSave"

    func quickSave(league: League, season: Season, userTeamId: UUID) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let gameState = GameSaveState(
            league: league,
            season: season,
            userTeamId: userTeamId
        )

        let data = try encoder.encode(gameState)
        UserDefaults.standard.set(data, forKey: Self.quickSaveKey)
    }

    func quickLoad() throws -> GameSaveState? {
        guard let data = UserDefaults.standard.data(forKey: Self.quickSaveKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(GameSaveState.self, from: data)
    }

    func hasQuickSave() -> Bool {
        UserDefaults.standard.data(forKey: Self.quickSaveKey) != nil
    }

    func clearQuickSave() {
        UserDefaults.standard.removeObject(forKey: Self.quickSaveKey)
    }
}

// MARK: - Export/Import

extension SaveGameService {

    func exportSave(_ savedGame: SavedGame) throws -> URL {
        let fileName = "\(savedGame.name.replacingOccurrences(of: " ", with: "_"))_\(savedGame.id.uuidString.prefix(8)).fpsave"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let exportData = ExportedSave(
            name: savedGame.name,
            teamName: savedGame.teamName,
            seasonYear: savedGame.seasonYear,
            week: savedGame.week,
            gameData: savedGame.gameData,
            exportedAt: Date()
        )

        let data = try encoder.encode(exportData)
        try data.write(to: tempURL)

        return tempURL
    }

    func importSave(from url: URL) throws -> SavedGame {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        let exportedSave = try decoder.decode(ExportedSave.self, from: data)

        let savedGame = SavedGame(
            name: exportedSave.name,
            teamName: exportedSave.teamName,
            seasonYear: exportedSave.seasonYear,
            week: exportedSave.week,
            gameData: exportedSave.gameData
        )

        modelContext?.insert(savedGame)
        try modelContext?.save()

        return savedGame
    }
}

struct ExportedSave: Codable {
    var name: String
    var teamName: String
    var seasonYear: Int
    var week: Int
    var gameData: Data
    var exportedAt: Date
}
