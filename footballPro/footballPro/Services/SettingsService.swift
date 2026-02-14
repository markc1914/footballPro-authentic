//
//  SettingsService.swift
//  footballPro
//
//  User preferences and settings service
//

import Foundation
import SwiftUI

// MARK: - Settings Keys

enum SettingsKey: String {
    case simulationSpeed = "settings.simulationSpeed"
    case soundEnabled = "settings.soundEnabled"
    case musicEnabled = "settings.musicEnabled"
    case musicVolume = "settings.musicVolume"
    case sfxVolume = "settings.sfxVolume"
    case showTutorials = "settings.showTutorials"
    case autoSaveEnabled = "settings.autoSaveEnabled"
    case autoSaveInterval = "settings.autoSaveInterval"
    case difficulty = "settings.difficulty"
    case playClockLength = "settings.playClockLength"
    case injuryFrequency = "settings.injuryFrequency"
    case tradeDeadline = "settings.tradeDeadline"
    case controllerVibration = "settings.controllerVibration"
    case colorScheme = "settings.colorScheme"
}

// MARK: - Settings Service

@MainActor
class SettingsService: ObservableObject {
    static let shared = SettingsService()

    @AppStorage(SettingsKey.simulationSpeed.rawValue) var simulationSpeed: SimulationSpeedSetting = .normal
    @AppStorage(SettingsKey.soundEnabled.rawValue) var soundEnabled: Bool = true
    @AppStorage(SettingsKey.musicEnabled.rawValue) var musicEnabled: Bool = true
    @AppStorage(SettingsKey.musicVolume.rawValue) var musicVolume: Double = 0.7
    @AppStorage(SettingsKey.sfxVolume.rawValue) var sfxVolume: Double = 1.0
    @AppStorage(SettingsKey.showTutorials.rawValue) var showTutorials: Bool = true
    @AppStorage(SettingsKey.autoSaveEnabled.rawValue) var autoSaveEnabled: Bool = true
    @AppStorage(SettingsKey.autoSaveInterval.rawValue) var autoSaveInterval: Int = 5
    @AppStorage(SettingsKey.difficulty.rawValue) var difficulty: DifficultySetting = .normal
    @AppStorage(SettingsKey.playClockLength.rawValue) var playClockLength: Int = 40
    @AppStorage(SettingsKey.injuryFrequency.rawValue) var injuryFrequency: InjuryFrequencySetting = .normal
    @AppStorage(SettingsKey.tradeDeadline.rawValue) var tradeDeadline: Int = 10
    @AppStorage(SettingsKey.controllerVibration.rawValue) var controllerVibration: Bool = true
    @AppStorage(SettingsKey.colorScheme.rawValue) var colorScheme: ColorSchemeSetting = .system

    private init() {}

    // MARK: - Reset

    func resetToDefaults() {
        simulationSpeed = .normal
        soundEnabled = true
        musicEnabled = true
        musicVolume = 0.7
        sfxVolume = 1.0
        showTutorials = true
        autoSaveEnabled = true
        autoSaveInterval = 5
        difficulty = .normal
        playClockLength = 40
        injuryFrequency = .normal
        tradeDeadline = 10
        controllerVibration = true
        colorScheme = .system
    }

    // MARK: - Computed Properties

    var simulationDelay: Int {
        simulationSpeed.delayMs
    }

    var injuryChance: Double {
        injuryFrequency.chance
    }

    var preferredColorScheme: ColorScheme? {
        switch colorScheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Setting Enums

enum SimulationSpeedSetting: String, CaseIterable, Codable {
    case slow = "Slow"
    case normal = "Normal"
    case fast = "Fast"
    case instant = "Instant"

    var delayMs: Int {
        switch self {
        case .slow: return 2000
        case .normal: return 1000
        case .fast: return 500
        case .instant: return 0
        }
    }
}

enum DifficultySetting: String, CaseIterable, Codable {
    case rookie = "Rookie"
    case normal = "Normal"
    case allPro = "All-Pro"
    case allMadden = "All-Madden"

    var aiBonus: Int {
        switch self {
        case .rookie: return -10
        case .normal: return 0
        case .allPro: return 5
        case .allMadden: return 10
        }
    }

    var userBonus: Int {
        switch self {
        case .rookie: return 10
        case .normal: return 0
        case .allPro: return 0
        case .allMadden: return -5
        }
    }
}

enum InjuryFrequencySetting: String, CaseIterable, Codable {
    case off = "Off"
    case low = "Low"
    case normal = "Normal"
    case high = "High"

    var chance: Double {
        switch self {
        case .off: return 0
        case .low: return 0.02
        case .normal: return 0.05
        case .high: return 0.10
        }
    }
}

enum ColorSchemeSetting: String, CaseIterable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

// MARK: - Settings View

struct SettingsView2: View {
    @StateObject private var settings = SettingsService.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()

            // Settings form
            Form {
                Section("Gameplay") {
                    Picker("Simulation Speed", selection: $settings.simulationSpeed) {
                        ForEach(SimulationSpeedSetting.allCases, id: \.self) { speed in
                            Text(speed.rawValue).tag(speed)
                        }
                    }

                    Picker("Difficulty", selection: $settings.difficulty) {
                        ForEach(DifficultySetting.allCases, id: \.self) { diff in
                            Text(diff.rawValue).tag(diff)
                        }
                    }

                    Picker("Injury Frequency", selection: $settings.injuryFrequency) {
                        ForEach(InjuryFrequencySetting.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }

                    Stepper("Trade Deadline: Week \(settings.tradeDeadline)", value: $settings.tradeDeadline, in: 6...14)
                }

                Section("Audio") {
                    Toggle("Sound Effects", isOn: $settings.soundEnabled)

                    Toggle("Music", isOn: $settings.musicEnabled)

                    if settings.musicEnabled {
                        HStack {
                            Text("Music Volume")
                            Slider(value: $settings.musicVolume, in: 0...1)
                        }
                    }

                    if settings.soundEnabled {
                        HStack {
                            Text("SFX Volume")
                            Slider(value: $settings.sfxVolume, in: 0...1)
                        }
                    }
                }

                Section("Saving") {
                    Toggle("Auto Save", isOn: $settings.autoSaveEnabled)

                    if settings.autoSaveEnabled {
                        Stepper("Save every \(settings.autoSaveInterval) minutes", value: $settings.autoSaveInterval, in: 1...30)
                    }
                }

                Section("Display") {
                    Picker("Color Scheme", selection: $settings.colorScheme) {
                        ForEach(ColorSchemeSetting.allCases, id: \.self) { scheme in
                            Text(scheme.rawValue).tag(scheme)
                        }
                    }

                    Toggle("Show Tutorials", isOn: $settings.showTutorials)
                }

                Section("Controls") {
                    Toggle("Controller Vibration", isOn: $settings.controllerVibration)

                    Button("View Keyboard Shortcuts") {
                        // Open keyboard shortcuts
                    }
                }

                Section {
                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Compact Settings Picker

struct QuickSettingsPicker: View {
    @StateObject private var settings = SettingsService.shared

    var body: some View {
        Menu {
            Section("Simulation Speed") {
                ForEach(SimulationSpeedSetting.allCases, id: \.self) { speed in
                    Button(action: { settings.simulationSpeed = speed }) {
                        HStack {
                            Text(speed.rawValue)
                            if settings.simulationSpeed == speed {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section("Difficulty") {
                ForEach(DifficultySetting.allCases, id: \.self) { diff in
                    Button(action: { settings.difficulty = diff }) {
                        HStack {
                            Text(diff.rawValue)
                            if settings.difficulty == diff {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "gearshape.fill")
        }
    }
}
