//
//  FPSGameSettingsView.swift
//  footballPro
//
//  In-game settings overlay (F1 key) — FPS Football Pro '93 style
//  View options, field detail, audio, and field conditions
//

import SwiftUI

// MARK: - Game Settings State (persisted via @AppStorage)

@MainActor
class GameSettingsState: ObservableObject {
    static let shared = GameSettingsState()

    // View options
    @AppStorage("cameraAngle") var cameraAngle: String = "BEHIND OFFENSE"

    // Field detail
    @AppStorage("fieldDetailLevel") var fieldDetailLevel: String = "high"
    @AppStorage("showHashMarks") var showHashMarks: Bool = true
    @AppStorage("showYardNumbers") var showYardNumbers: Bool = true
    @AppStorage("showEndZoneText") var showEndZoneText: Bool = true
    @AppStorage("showSidelineDetails") var showSidelineDetails: Bool = true

    // Audio
    @AppStorage("soundEffectsEnabled") var soundEffectsEnabled: Bool = true
    @AppStorage("crowdNoiseEnabled") var crowdNoiseEnabled: Bool = true
    @AppStorage("refereeWhistleEnabled") var refereeWhistleEnabled: Bool = true

    // Field conditions
    @AppStorage("fieldCondition") var fieldCondition: String = "grass"

    /// Apply a detail preset (HIGH/MEDIUM/LOW)
    func applyDetailPreset(_ preset: String) {
        fieldDetailLevel = preset
        switch preset {
        case "high":
            showHashMarks = true
            showYardNumbers = true
            showEndZoneText = true
            showSidelineDetails = true
        case "medium":
            showHashMarks = true
            showYardNumbers = true
            showEndZoneText = false
            showSidelineDetails = false
        case "low":
            showHashMarks = false
            showYardNumbers = false
            showEndZoneText = false
            showSidelineDetails = false
        default:
            break
        }
    }

    /// Sync audio settings to SoundManager
    func syncAudioSettings() {
        SoundManager.shared.isSoundEnabled = soundEffectsEnabled
        SoundManager.shared.isCrowdEnabled = crowdNoiseEnabled
    }
}

// MARK: - Field Condition Options

enum FieldConditionOption: String, CaseIterable {
    case grass = "grass"
    case artificialTurf = "artificialTurf"
    case mud = "mud"
    case snow = "snow"

    var displayName: String {
        switch self {
        case .grass: return "GRASS"
        case .artificialTurf: return "ARTIFICIAL TURF"
        case .mud: return "MUD"
        case .snow: return "SNOW"
        }
    }
}

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable {
    case view = "VIEW"
    case fieldDetail = "FIELD"
    case audio = "AUDIO"
    case conditions = "CONDITIONS"
}

// MARK: - FPS Game Settings View

struct FPSGameSettingsView: View {
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject var settings = GameSettingsState.shared
    @State private var selectedTab: SettingsTab = .view
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Centered DOS panel
            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Text("GAME SETTINGS")
                        .font(RetroFont.title())
                        .foregroundColor(VGA.digitalAmber)
                    Spacer()
                    FPSButton("DONE") {
                        onDismiss()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(VGA.titleBarBg)

                // Tab bar
                HStack(spacing: 2) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        tabButton(tab)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(VGA.panelDark)

                // Tab content
                VStack(spacing: 0) {
                    switch selectedTab {
                    case .view:
                        viewOptionsSection
                    case .fieldDetail:
                        fieldDetailSection
                    case .audio:
                        audioSection
                    case .conditions:
                        conditionsSection
                    }
                }
                .frame(minHeight: 260)
                .background(VGA.panelBg)
            }
            .frame(width: 480)
            .modifier(DOSPanelBorder(.raised, width: 2))
        }
    }

    // MARK: - Tab Button

    private func tabButton(_ tab: SettingsTab) -> some View {
        Button(action: { selectedTab = tab }) {
            Text(tab.rawValue)
                .font(RetroFont.bodyBold())
                .foregroundColor(selectedTab == tab ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(selectedTab == tab ? VGA.panelLight : VGA.panelDark)
                .modifier(DOSPanelBorder(selectedTab == tab ? .raised : .sunken, width: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - View Options Section

    private var viewOptionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("CAMERA ANGLE")

            VStack(spacing: 2) {
                ForEach(CameraAngle.allCases, id: \.self) { angle in
                    cameraAngleRow(angle)
                }
            }
            .padding(6)
            .background(VGA.panelVeryDark.opacity(0.3))
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
        .padding(10)
    }

    private func cameraAngleRow(_ angle: CameraAngle) -> some View {
        let isSelected = settings.cameraAngle == angle.rawValue
        return Button(action: {
            settings.cameraAngle = angle.rawValue
        }) {
            HStack(spacing: 8) {
                // Selection indicator
                Text(isSelected ? ">" : " ")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.digitalAmber)
                    .frame(width: 12)

                Text(angle.rawValue)
                    .font(RetroFont.body())
                    .foregroundColor(isSelected ? VGA.digitalAmber : VGA.white)

                Spacer()
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(isSelected ? VGA.panelVeryDark : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Field Detail Section

    private var fieldDetailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("DETAIL LEVEL")

            // Preset buttons
            HStack(spacing: 8) {
                detailPresetButton("HIGH", preset: "high")
                detailPresetButton("MEDIUM", preset: "medium")
                detailPresetButton("LOW", preset: "low")
            }
            .padding(.horizontal, 10)

            sectionHeader("CUSTOM TOGGLES")

            // Individual toggles
            VStack(spacing: 4) {
                toggleRow("HASH MARKS (M)", isOn: settings.showHashMarks) {
                    settings.showHashMarks.toggle()
                    settings.fieldDetailLevel = "custom"
                }
                toggleRow("YARD NUMBERS (N)", isOn: settings.showYardNumbers) {
                    settings.showYardNumbers.toggle()
                    settings.fieldDetailLevel = "custom"
                }
                toggleRow("END ZONE TEXT", isOn: settings.showEndZoneText) {
                    settings.showEndZoneText.toggle()
                    settings.fieldDetailLevel = "custom"
                }
                toggleRow("SIDELINE DETAILS", isOn: settings.showSidelineDetails) {
                    settings.showSidelineDetails.toggle()
                    settings.fieldDetailLevel = "custom"
                }
            }
            .padding(6)
            .background(VGA.panelVeryDark.opacity(0.3))
            .modifier(DOSPanelBorder(.sunken, width: 1))
            .padding(.horizontal, 10)

            Spacer()
        }
        .padding(.vertical, 10)
    }

    private func detailPresetButton(_ label: String, preset: String) -> some View {
        let isSelected = settings.fieldDetailLevel == preset
        return Button(action: {
            settings.applyDetailPreset(preset)
        }) {
            Text(label)
                .font(RetroFont.bodyBold())
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isSelected ? VGA.playSlotSelected : VGA.buttonBg)
                .modifier(DOSPanelBorder(isSelected ? .sunken : .raised, width: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("AUDIO SETTINGS")

            VStack(spacing: 4) {
                toggleRow("SOUND EFFECTS", isOn: settings.soundEffectsEnabled) {
                    settings.soundEffectsEnabled.toggle()
                    settings.syncAudioSettings()
                }
                toggleRow("CROWD NOISE", isOn: settings.crowdNoiseEnabled) {
                    settings.crowdNoiseEnabled.toggle()
                    settings.syncAudioSettings()
                }
                toggleRow("REFEREE WHISTLE", isOn: settings.refereeWhistleEnabled) {
                    settings.refereeWhistleEnabled.toggle()
                }
            }
            .padding(6)
            .background(VGA.panelVeryDark.opacity(0.3))
            .modifier(DOSPanelBorder(.sunken, width: 1))
            .padding(.horizontal, 10)

            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Conditions Section

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("FIELD CONDITION")

            VStack(spacing: 4) {
                ForEach(FieldConditionOption.allCases, id: \.self) { condition in
                    conditionRow(condition)
                }
            }
            .padding(6)
            .background(VGA.panelVeryDark.opacity(0.3))
            .modifier(DOSPanelBorder(.sunken, width: 1))
            .padding(.horizontal, 10)

            // Current weather info
            if let game = viewModel.game, let weather = game.gameWeather {
                VStack(alignment: .leading, spacing: 4) {
                    sectionHeader("CURRENT WEATHER")
                    Text(weather.narrativeDescription)
                        .font(RetroFont.body())
                        .foregroundColor(VGA.lightGray)
                        .padding(.horizontal, 10)
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }

    private func conditionRow(_ condition: FieldConditionOption) -> some View {
        let isSelected = settings.fieldCondition == condition.rawValue
        return Button(action: {
            settings.fieldCondition = condition.rawValue
        }) {
            HStack(spacing: 8) {
                Text(isSelected ? ">" : " ")
                    .font(RetroFont.body())
                    .foregroundColor(VGA.digitalAmber)
                    .frame(width: 12)

                Text(condition.displayName)
                    .font(RetroFont.body())
                    .foregroundColor(isSelected ? VGA.digitalAmber : VGA.white)

                Spacer()
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(isSelected ? VGA.panelVeryDark : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Shared Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(RetroFont.header())
            .foregroundColor(VGA.white)
            .padding(.horizontal, 10)
            .padding(.top, 4)
    }

    private func toggleRow(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(RetroFont.body())
                    .foregroundColor(VGA.white)

                Spacer()

                Text(isOn ? "ON" : "OFF")
                    .font(RetroFont.bodyBold())
                    .foregroundColor(isOn ? .black : VGA.lightGray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(isOn ? VGA.playSlotGreen : VGA.panelDark)
                    .modifier(DOSPanelBorder(isOn ? .raised : .sunken, width: 1))
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
