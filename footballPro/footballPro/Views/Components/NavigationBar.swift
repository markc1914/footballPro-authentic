//
//  NavigationBar.swift
//  footballPro
//
//  Custom navigation bar with controller hints and DOS-era styling
//

import SwiftUI

// MARK: - Navigation Bar

struct GameNavigationBar: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var inputManager: InputManager

    let title: String
    var subtitle: String?
    var showBackButton: Bool = true
    var backAction: (() -> Void)?
    var trailingContent: AnyView?

    var body: some View {
        DOSPanel(.raised) {
            HStack(spacing: 12) {
                // Back button
                if showBackButton {
                    Button(action: {
                        backAction?() ?? gameState.navigateTo(.mainMenu)
                    }) {
                        HStack(spacing: 4) {
                            Text("\u{25C4}")
                                .font(RetroFont.body())

                            if inputManager.isControllerConnected {
                                ControllerButtonHint(button: "B")
                            } else {
                                Text("ESC")
                                    .font(RetroFont.tiny())
                            }
                        }
                        .foregroundColor(VGA.darkGray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(VGA.panelBg)
                        .dosPanel(.raised)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }

                // Title
                VStack(alignment: .leading, spacing: 1) {
                    Text(title.uppercased())
                        .font(RetroFont.header())
                        .foregroundColor(VGA.black)

                    if let subtitle = subtitle {
                        Text(subtitle.uppercased())
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.darkGray)
                    }
                }

                Spacer()

                // Trailing content
                if let trailing = trailingContent {
                    trailing
                }

                // Quick settings
                QuickSettingsPicker()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(VGA.panelBg)
        }
    }
}

// MARK: - Tab Bar

struct GameTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    @EnvironmentObject var inputManager: InputManager

    var body: some View {
        DOSPanel(.raised) {
            HStack(spacing: 0) {
                // Controller hint for previous tab
                if inputManager.isControllerConnected {
                    ControllerButtonHint(button: "LB")
                        .padding(.horizontal, 4)
                }

                // Tabs
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    RetroTabButton(
                        tab: tab,
                        isSelected: selectedTab == index
                    ) {
                        selectedTab = index
                    }

                    if index < tabs.count - 1 {
                        Rectangle()
                            .fill(VGA.shadowInner)
                            .frame(width: 1, height: 20)
                    }
                }

                // Controller hint for next tab
                if inputManager.isControllerConnected {
                    ControllerButtonHint(button: "RB")
                        .padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(VGA.panelBg)
        }
        .onKeyPress("q") {
            selectedTab = max(0, selectedTab - 1)
            return .handled
        }
        .onKeyPress("e") {
            selectedTab = min(tabs.count - 1, selectedTab + 1)
            return .handled
        }
    }
}

struct TabItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
}

struct RetroTabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(tab.title.uppercased())
                .font(isSelected ? RetroFont.bodyBold() : RetroFont.body())
                .foregroundColor(isSelected ? .black : VGA.darkGray)
                .frame(minWidth: 70)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(isSelected ? VGA.yellow : VGA.panelBg)
                .modifier(DOSPanelBorder(isSelected ? .sunken : .raised, width: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Controller Button Hint

struct ControllerButtonHint: View {
    let button: String
    var size: CGFloat = 24

    var body: some View {
        Text(button)
            .font(RetroFont.tiny())
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(VGA.panelDark)
            .dosPanel(.raised)
    }
}

// MARK: - Keyboard Hint

struct KeyboardHint: View {
    let key: String

    var body: some View {
        Text(key)
            .font(RetroFont.tiny())
            .foregroundColor(VGA.darkGray)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(VGA.panelBg)
            .dosPanel(.raised)
    }
}

// MARK: - Input Hint Bar

struct InputHintBar: View {
    @EnvironmentObject var inputManager: InputManager
    let hints: [(action: String, keyboard: String, controller: String)]

    var body: some View {
        DOSPanel(.raised) {
            HStack(spacing: 16) {
                ForEach(hints, id: \.action) { hint in
                    HStack(spacing: 4) {
                        if inputManager.isControllerConnected {
                            ControllerButtonHint(button: hint.controller, size: 18)
                        } else {
                            KeyboardHint(key: hint.keyboard)
                        }

                        Text(hint.action.uppercased())
                            .font(RetroFont.tiny())
                            .foregroundColor(VGA.darkGray)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VGA.panelBg)
        }
    }
}

// MARK: - Breadcrumb Navigation

struct BreadcrumbNavigation: View {
    let items: [String]
    var onSelect: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Text("\u{25BA}")
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.darkGray)
                }

                if index < items.count - 1 {
                    Button(item.uppercased()) {
                        onSelect?(index)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(VGA.darkGray)
                    .font(RetroFont.small())
                } else {
                    Text(item.uppercased())
                        .font(RetroFont.bodyBold())
                        .foregroundColor(VGA.black)
                }
            }
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionTitle: String?

    var body: some View {
        HStack(spacing: 4) {
            Text(title.uppercased())
                .font(RetroFont.small())
                .foregroundColor(VGA.cyan)
                .tracking(1)

            DOSSeparator()

            if let actionTitle = actionTitle {
                Button(actionTitle.uppercased()) {
                    action?()
                }
                .font(RetroFont.tiny())
                .foregroundColor(VGA.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Retro Info Box (Classic DOS Style)

struct RetroInfoBox: View {
    let title: String
    let content: String

    var body: some View {
        DOSWindowFrame(title) {
            Text(content)
                .font(RetroFont.body())
                .foregroundColor(VGA.green)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VGA.black)
        }
    }
}

// MARK: - Retro Table (Classic Stats Display)

struct RetroTable: View {
    let headers: [String]
    let rows: [[String]]
    var columnWidths: [CGFloat]?

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                    Text(header)
                        .font(RetroFont.tiny())
                        .foregroundColor(VGA.cyan)
                        .frame(width: columnWidths?[safe: index] ?? 80, alignment: .leading)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                }
            }
            .background(VGA.titleBarBg)

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                        Text(cell)
                            .font(RetroFont.small())
                            .foregroundColor(VGA.white)
                            .frame(width: columnWidths?[safe: colIndex] ?? 80, alignment: .leading)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                    }
                }
                .background(rowIndex % 2 == 0 ? VGA.panelVeryDark : VGA.panelVeryDark.opacity(0.8))
            }
        }
        .background(VGA.panelVeryDark)
        .dosPanel(.sunken)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    VStack(spacing: 20) {
        GameNavigationBar(title: "Team Management", subtitle: "Austin Thunder")

        GameTabBar(
            selectedTab: .constant(0),
            tabs: [
                TabItem(title: "Roster", icon: "person.3"),
                TabItem(title: "Depth", icon: "list.number"),
                TabItem(title: "Finances", icon: "dollarsign.circle")
            ]
        )

        InputHintBar(hints: [
            ("Select", "Enter", "A"),
            ("Back", "Esc", "B"),
            ("Info", "I", "Y")
        ])

        RetroInfoBox(title: "GAME INFO", content: """
        Week 5 - Regular Season
        vs Portland Wolves
        Sunday, 1:00 PM
        """)

        RetroTable(
            headers: ["PLAYER", "POS", "OVR", "AGE"],
            rows: [
                ["J. Smith", "QB", "92", "27"],
                ["M. Johnson", "RB", "88", "25"],
                ["T. Williams", "WR", "85", "24"]
            ],
            columnWidths: [100, 50, 50, 50]
        )
    }
    .padding()
    .background(VGA.screenBg)
    .environmentObject(GameState())
    .environmentObject(InputManager())
}
