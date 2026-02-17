//
//  SaveLoadView.swift
//  footballPro
//
//  Save/Load game screen with 8 slots, DOS-style UI
//

import SwiftUI

struct SaveLoadView: View {
    @EnvironmentObject var gameState: GameState

    struct SlotInfo {
        var teamName: String
        var weekInfo: String
        var savedDate: Date
    }

    @State private var slots: [SlotInfo?] = Array(repeating: nil, count: 8)
    @State private var selectedSlot: Int? = nil
    @State private var statusMessage: String = ""
    @State private var statusIsError: Bool = false
    @State private var showSaveConfirm: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private static let slotKeyPrefix = "footballPro.saveSlot."

    var body: some View {
        VStack(spacing: 0) {
            topBar

            DOSSeparator()

            columnHeaders
                .padding(.top, 8)
                .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(1...8, id: \.self) { slot in
                        slotRow(slot: slot)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Spacer(minLength: 0)

            if !statusMessage.isEmpty {
                statusBar
            }

            DOSSeparator()

            actionButtons
                .padding(12)
        }
        .background(VGA.screenBg)
        .onAppear { refreshSlots() }
        .overlay(
            Group {
                if showSaveConfirm {
                    saveConfirmDialog
                }
                if showDeleteConfirm {
                    deleteConfirmDialog
                }
            }
        )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            FPSButton("< BACK") {
                gameState.navigateTo(.management)
            }

            Spacer()

            Text("SAVE / LOAD GAME")
                .font(RetroFont.title())
                .foregroundColor(VGA.digitalAmber)

            Spacer()

            Color.clear.frame(width: 80, height: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VGA.panelVeryDark)
    }

    // MARK: - Column Headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Text("SLOT")
                .frame(width: 50, alignment: .leading)
            Text("TEAM")
                .frame(width: 160, alignment: .leading)
            Text("WEEK")
                .frame(width: 120, alignment: .leading)
            Text("DATE SAVED")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(RetroFont.small())
        .foregroundColor(VGA.digitalAmber)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(VGA.panelDark)
        .modifier(DOSPanelBorder(.sunken, width: 1))
    }

    // MARK: - Slot Row

    private func slotRow(slot: Int) -> some View {
        let info = slot <= slots.count ? slots[slot - 1] : nil
        let isSelected = selectedSlot == slot
        let isEmpty = info == nil

        return Button(action: {
            selectedSlot = slot
            clearStatus()
        }) {
            HStack(spacing: 0) {
                Text("\(slot)")
                    .frame(width: 50, alignment: .leading)
                    .foregroundColor(isSelected ? VGA.screenBg : VGA.lightGray)

                if let info = info {
                    Text(info.teamName.uppercased())
                        .frame(width: 160, alignment: .leading)
                        .foregroundColor(isSelected ? VGA.screenBg : VGA.white)

                    Text(info.weekInfo.uppercased())
                        .frame(width: 120, alignment: .leading)
                        .foregroundColor(isSelected ? VGA.screenBg : VGA.cyan)

                    Text(formatDate(info.savedDate))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(isSelected ? VGA.screenBg : VGA.lightGray)
                } else {
                    Text("--- EMPTY ---")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(isSelected ? VGA.screenBg : VGA.darkGray)
                }
            }
            .font(RetroFont.body())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? VGA.playSlotGreen : VGA.panelVeryDark)
            .modifier(DOSPanelBorder(.sunken, width: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Text(statusMessage)
                .font(RetroFont.bodyBold())
                .foregroundColor(statusIsError ? VGA.brightRed : VGA.green)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(VGA.panelVeryDark)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Spacer()

            FPSButton("SAVE", width: 100) {
                guard let slot = selectedSlot else {
                    showStatus("SELECT A SLOT FIRST", isError: true)
                    return
                }
                guard gameState.currentLeague != nil,
                      gameState.currentSeason != nil else {
                    showStatus("NO ACTIVE GAME TO SAVE", isError: true)
                    return
                }
                if slots[slot - 1] != nil {
                    showSaveConfirm = true
                } else {
                    performSave(slot: slot)
                }
            }

            FPSButton("LOAD", width: 100) {
                guard let slot = selectedSlot else {
                    showStatus("SELECT A SLOT FIRST", isError: true)
                    return
                }
                guard slots[slot - 1] != nil else {
                    showStatus("SLOT \(slot) IS EMPTY", isError: true)
                    return
                }
                performLoad(slot: slot)
            }

            FPSButton("DELETE", width: 100) {
                guard let slot = selectedSlot else {
                    showStatus("SELECT A SLOT FIRST", isError: true)
                    return
                }
                guard slots[slot - 1] != nil else {
                    showStatus("SLOT \(slot) IS EMPTY", isError: true)
                    return
                }
                showDeleteConfirm = true
            }

            Spacer()
        }
        .background(VGA.panelDark)
    }

    // MARK: - Confirmation Dialogs

    private var saveConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            FPSDialog("CONFIRM OVERWRITE") {
                VStack(spacing: 16) {
                    Text("SLOT \(selectedSlot ?? 0) ALREADY HAS A SAVE.\nOVERWRITE IT?")
                        .font(RetroFont.body())
                        .foregroundColor(VGA.white)
                        .multilineTextAlignment(.center)
                        .padding()

                    HStack(spacing: 20) {
                        FPSButton("YES", width: 80) {
                            showSaveConfirm = false
                            if let slot = selectedSlot {
                                performSave(slot: slot)
                            }
                        }
                        FPSButton("NO", width: 80) {
                            showSaveConfirm = false
                        }
                    }
                    .padding(.bottom, 12)
                }
                .frame(width: 340)
            }
        }
    }

    private var deleteConfirmDialog: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            FPSDialog("CONFIRM DELETE") {
                VStack(spacing: 16) {
                    Text("DELETE SAVE IN SLOT \(selectedSlot ?? 0)?\nTHIS CANNOT BE UNDONE.")
                        .font(RetroFont.body())
                        .foregroundColor(VGA.brightRed)
                        .multilineTextAlignment(.center)
                        .padding()

                    HStack(spacing: 20) {
                        FPSButton("YES", width: 80) {
                            showDeleteConfirm = false
                            if let slot = selectedSlot {
                                performDelete(slot: slot)
                            }
                        }
                        FPSButton("NO", width: 80) {
                            showDeleteConfirm = false
                        }
                    }
                    .padding(.bottom, 12)
                }
                .frame(width: 340)
            }
        }
    }

    // MARK: - Actions (UserDefaults-based slot persistence)

    private func performSave(slot: Int) {
        guard let league = gameState.currentLeague,
              let season = gameState.currentSeason,
              let userTeam = gameState.userTeam else {
            showStatus("NO ACTIVE GAME TO SAVE", isError: true)
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let state = GameSaveState(league: league, season: season, userTeamId: userTeam.id)
            let data = try encoder.encode(state)
            let key = Self.slotKeyPrefix + "\(slot)"
            UserDefaults.standard.set(data, forKey: key)

            // Save metadata
            let meta: [String: Any] = [
                "teamName": userTeam.fullName,
                "week": "WEEK \(season.currentWeek)",
                "savedDate": Date().timeIntervalSince1970
            ]
            UserDefaults.standard.set(meta, forKey: key + ".meta")

            showStatus("GAME SAVED TO SLOT \(slot)", isError: false)
            refreshSlots()
        } catch {
            showStatus("SAVE FAILED: \(error.localizedDescription.uppercased())", isError: true)
        }
    }

    private func performLoad(slot: Int) {
        let key = Self.slotKeyPrefix + "\(slot)"
        guard let data = UserDefaults.standard.data(forKey: key) else {
            showStatus("SLOT \(slot) IS EMPTY", isError: true)
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(GameSaveState.self, from: data)
            gameState.currentLeague = state.league
            gameState.currentSeason = state.season
            if let team = state.league.teams.first(where: { $0.id == state.userTeamId }) {
                gameState.userTeam = team
            }
            showStatus("GAME LOADED FROM SLOT \(slot)", isError: false)
        } catch {
            showStatus("LOAD FAILED: \(error.localizedDescription.uppercased())", isError: true)
        }
    }

    private func performDelete(slot: Int) {
        let key = Self.slotKeyPrefix + "\(slot)"
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: key + ".meta")
        showStatus("SLOT \(slot) DELETED", isError: false)
        if selectedSlot == slot {
            selectedSlot = nil
        }
        refreshSlots()
    }

    private func refreshSlots() {
        var newSlots: [SlotInfo?] = Array(repeating: nil, count: 8)
        for i in 1...8 {
            let key = Self.slotKeyPrefix + "\(i).meta"
            if let meta = UserDefaults.standard.dictionary(forKey: key) {
                newSlots[i - 1] = SlotInfo(
                    teamName: meta["teamName"] as? String ?? "UNKNOWN",
                    weekInfo: meta["week"] as? String ?? "???",
                    savedDate: Date(timeIntervalSince1970: meta["savedDate"] as? Double ?? 0)
                )
            }
        }
        slots = newSlots
    }

    private func showStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }

    private func clearStatus() {
        statusMessage = ""
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy HH:mm"
        return formatter.string(from: date)
    }
}
