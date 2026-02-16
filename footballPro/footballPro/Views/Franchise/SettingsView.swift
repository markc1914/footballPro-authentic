//
//  FranchiseSettingsView.swift
//  footballPro
//
//  Settings/preferences view with DOS aesthetic.
//

import SwiftUI

// MARK: - Settings View

struct FranchiseSettingsView: View {
    @EnvironmentObject var gameState: GameState

    // MARK: - AppStorage Settings

    @AppStorage("settings.difficulty") private var difficulty: String = "NORMAL"
    @AppStorage("settings.gameSpeed") private var gameSpeed: String = "NORMAL"
    @AppStorage("settings.audioVolume") private var audioVolume: Double = 80
    @AppStorage("settings.musicVolume") private var musicVolume: Double = 60
    @AppStorage("settings.quarterLength") private var quarterLength: Int = 15
    @AppStorage("settings.autoSave") private var autoSave: Bool = true
    @AppStorage("settings.showPlayDiagrams") private var showPlayDiagrams: Bool = true

    private let difficulties = ["EASY", "NORMAL", "HARD"]
    private let speeds = ["SLOW", "NORMAL", "FAST"]
    private let quarterLengths = [5, 10, 15]

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(spacing: 16) {
                    gameplaySection
                    audioSection
                    displaySection
                    resetSection
                }
                .padding(16)
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

            Text("SETTINGS")
                .font(RetroFont.title())
                .foregroundColor(VGA.digitalAmber)

            Spacer()

            // Spacer button for symmetry
            FPSButton("< BACK") {
                gameState.navigateTo(.management)
            }
            .hidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelVeryDark)
    }

    // MARK: - Gameplay Section

    private var gameplaySection: some View {
        VStack(spacing: 0) {
            sectionHeader("GAMEPLAY")

            VStack(spacing: 1) {
                settingRow("DIFFICULTY") {
                    segmentedControl(options: difficulties, selection: $difficulty)
                }

                DOSSeparator()

                settingRow("GAME SPEED") {
                    segmentedControl(options: speeds, selection: $gameSpeed)
                }

                DOSSeparator()

                settingRow("QUARTER LENGTH") {
                    segmentedControl(
                        options: quarterLengths.map { "\($0) MIN" },
                        selection: Binding(
                            get: { "\(quarterLength) MIN" },
                            set: { newValue in
                                if let mins = Int(newValue.replacingOccurrences(of: " MIN", with: "")) {
                                    quarterLength = mins
                                }
                            }
                        )
                    )
                }
            }
            .padding(8)
            .background(VGA.panelBg)
        }
        .modifier(DOSPanelBorder(.raised))
    }

    // MARK: - Audio Section

    private var audioSection: some View {
        VStack(spacing: 0) {
            sectionHeader("AUDIO")

            VStack(spacing: 1) {
                settingRow("SOUND VOLUME") {
                    volumeSlider(value: $audioVolume)
                }

                DOSSeparator()

                settingRow("MUSIC VOLUME") {
                    volumeSlider(value: $musicVolume)
                }
            }
            .padding(8)
            .background(VGA.panelBg)
        }
        .modifier(DOSPanelBorder(.raised))
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(spacing: 0) {
            sectionHeader("DISPLAY")

            VStack(spacing: 1) {
                settingRow("AUTO-SAVE") {
                    dosToggle(isOn: $autoSave)
                }

                DOSSeparator()

                settingRow("PLAY DIAGRAMS") {
                    dosToggle(isOn: $showPlayDiagrams)
                }
            }
            .padding(8)
            .background(VGA.panelBg)
        }
        .modifier(DOSPanelBorder(.raised))
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        HStack {
            Spacer()
            FPSButton("RESET DEFAULTS", width: 180) {
                resetToDefaults()
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(RetroFont.header())
                .foregroundColor(VGA.digitalAmber)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(VGA.panelVeryDark)
    }

    private func settingRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(RetroFont.bodyBold())
                .foregroundColor(VGA.white)
                .frame(width: 160, alignment: .leading)

            Spacer()

            content()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }

    private func segmentedControl(options: [String], selection: Binding<String>) -> some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection.wrappedValue == option
                Button(action: {
                    selection.wrappedValue = option
                }) {
                    Text(option)
                        .font(RetroFont.small())
                        .foregroundColor(isSelected ? VGA.screenBg : VGA.lightGray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isSelected ? VGA.green : VGA.darkGray)
                        .modifier(DOSPanelBorder(isSelected ? .sunken : .raised, width: 1))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func volumeSlider(value: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            ZStack {
                // Track background
                RoundedRectangle(cornerRadius: 0)
                    .fill(VGA.panelVeryDark)
                    .frame(height: 12)
                    .modifier(DOSPanelBorder(.sunken, width: 1))

                // Fill bar
                GeometryReader { geo in
                    let fillWidth = geo.size.width * (value.wrappedValue / 100.0)
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(VGA.green)
                            .frame(width: max(0, fillWidth))
                        Spacer(minLength: 0)
                    }
                }
                .padding(2)
            }
            .frame(width: 180, height: 16)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let pct = max(0, min(1, drag.location.x / 180))
                        value.wrappedValue = Double(Int(pct * 100))
                    }
            )

            Text("\(Int(value.wrappedValue))")
                .font(RetroFont.body())
                .foregroundColor(VGA.digitalAmber)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func dosToggle(isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Button(action: { isOn.wrappedValue = true }) {
                Text("ON")
                    .font(RetroFont.small())
                    .foregroundColor(isOn.wrappedValue ? VGA.screenBg : VGA.lightGray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(isOn.wrappedValue ? VGA.green : VGA.darkGray)
                    .modifier(DOSPanelBorder(isOn.wrappedValue ? .sunken : .raised, width: 1))
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: { isOn.wrappedValue = false }) {
                Text("OFF")
                    .font(RetroFont.small())
                    .foregroundColor(!isOn.wrappedValue ? VGA.screenBg : VGA.lightGray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(!isOn.wrappedValue ? VGA.brightRed : VGA.darkGray)
                    .modifier(DOSPanelBorder(!isOn.wrappedValue ? .sunken : .raised, width: 1))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Actions

    private func resetToDefaults() {
        difficulty = "NORMAL"
        gameSpeed = "NORMAL"
        audioVolume = 80
        musicVolume = 60
        quarterLength = 15
        autoSave = true
        showPlayDiagrams = true
    }
}
