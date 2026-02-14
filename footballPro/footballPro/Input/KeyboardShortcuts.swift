//
//  KeyboardShortcuts.swift
//  footballPro
//
//  Keyboard bindings and shortcuts
//

import SwiftUI

// MARK: - Keyboard Action

enum KeyboardAction: String, CaseIterable {
    // Navigation
    case navigateUp = "Navigate Up"
    case navigateDown = "Navigate Down"
    case navigateLeft = "Navigate Left"
    case navigateRight = "Navigate Right"

    // Selection
    case select = "Select/Confirm"
    case back = "Back/Cancel"

    // Tabs
    case previousTab = "Previous Tab"
    case nextTab = "Next Tab"

    // Game Actions
    case pause = "Pause"
    case quickSave = "Quick Save"
    case quickLoad = "Quick Load"

    // Info
    case showInfo = "Show Info"
    case toggleStats = "Toggle Stats"

    // Play Calling
    case hotRoute1 = "Hot Route 1"
    case hotRoute2 = "Hot Route 2"
    case hotRoute3 = "Hot Route 3"
    case audible = "Audible"
    case snapBall = "Snap Ball"

    var category: KeyboardCategory {
        switch self {
        case .navigateUp, .navigateDown, .navigateLeft, .navigateRight:
            return .navigation
        case .select, .back:
            return .selection
        case .previousTab, .nextTab:
            return .tabs
        case .pause, .quickSave, .quickLoad:
            return .game
        case .showInfo, .toggleStats:
            return .info
        case .hotRoute1, .hotRoute2, .hotRoute3, .audible, .snapBall:
            return .playCalling
        }
    }
}

enum KeyboardCategory: String, CaseIterable {
    case navigation = "Navigation"
    case selection = "Selection"
    case tabs = "Tabs"
    case game = "Game"
    case info = "Info"
    case playCalling = "Play Calling"
}

// MARK: - Key Binding

struct KeyBinding: Equatable {
    var primary: KeyEquivalent
    var modifiers: EventModifiers
    var alternate: KeyEquivalent?
    var alternateModifiers: EventModifiers

    init(primary: KeyEquivalent, modifiers: EventModifiers = [], alternate: KeyEquivalent? = nil, alternateModifiers: EventModifiers = []) {
        self.primary = primary
        self.modifiers = modifiers
        self.alternate = alternate
        self.alternateModifiers = alternateModifiers
    }

    var displayString: String {
        var parts: [String] = []

        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.control) { parts.append("⌃") }

        parts.append(keyDisplayString(primary))

        return parts.joined()
    }

    private func keyDisplayString(_ key: KeyEquivalent) -> String {
        switch key {
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .return: return "↩"
        case .space: return "Space"
        case .escape: return "Esc"
        case .tab: return "Tab"
        case .delete: return "⌫"
        default:
            return String(key.character).uppercased()
        }
    }
}

// MARK: - Default Key Bindings

struct DefaultKeyBindings {
    static let bindings: [KeyboardAction: KeyBinding] = [
        // Navigation
        .navigateUp: KeyBinding(primary: .upArrow, alternate: "w"),
        .navigateDown: KeyBinding(primary: .downArrow, alternate: "s"),
        .navigateLeft: KeyBinding(primary: .leftArrow, alternate: "a"),
        .navigateRight: KeyBinding(primary: .rightArrow, alternate: "d"),

        // Selection
        .select: KeyBinding(primary: .return, alternate: .space),
        .back: KeyBinding(primary: .escape),

        // Tabs
        .previousTab: KeyBinding(primary: "q", alternate: "["),
        .nextTab: KeyBinding(primary: "e", alternate: "]"),

        // Game
        .pause: KeyBinding(primary: .escape),
        .quickSave: KeyBinding(primary: "s", modifiers: .command),
        .quickLoad: KeyBinding(primary: "l", modifiers: .command),

        // Info
        .showInfo: KeyBinding(primary: "i"),
        .toggleStats: KeyBinding(primary: "t"),

        // Play Calling
        .hotRoute1: KeyBinding(primary: "1"),
        .hotRoute2: KeyBinding(primary: "2"),
        .hotRoute3: KeyBinding(primary: "3"),
        .audible: KeyBinding(primary: "x"),
        .snapBall: KeyBinding(primary: .space)
    ]

    static func binding(for action: KeyboardAction) -> KeyBinding {
        bindings[action] ?? KeyBinding(primary: .space)
    }
}

// MARK: - Keyboard Shortcuts View

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(KeyboardCategory.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.rawValue)
                                .font(.headline)
                                .foregroundColor(.secondary)

                            ForEach(KeyboardAction.allCases.filter { $0.category == category }, id: \.self) { action in
                                HStack {
                                    Text(action.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(DefaultKeyBindings.binding(for: action).displayString)
                                        .font(.system(.body, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}

// MARK: - Keyboard Help Overlay

struct KeyboardHelpOverlay: View {
    let shortcuts: [(action: String, key: String)]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(shortcuts, id: \.action) { shortcut in
                HStack(spacing: 4) {
                    Text(shortcut.key)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)

                    Text(shortcut.action)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }
}

// MARK: - Keyboard Shortcuts Modifier

struct GameKeyboardShortcuts: ViewModifier {
    @EnvironmentObject var inputManager: InputManager

    var onNavigate: ((InputDirection) -> Void)?
    var onSelect: (() -> Void)?
    var onBack: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .onKeyPress(.upArrow) {
                onNavigate?(.up)
                return .handled
            }
            .onKeyPress(.downArrow) {
                onNavigate?(.down)
                return .handled
            }
            .onKeyPress(.leftArrow) {
                onNavigate?(.left)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                onNavigate?(.right)
                return .handled
            }
            .onKeyPress("w") {
                onNavigate?(.up)
                return .handled
            }
            .onKeyPress("s") {
                onNavigate?(.down)
                return .handled
            }
            .onKeyPress("a") {
                onNavigate?(.left)
                return .handled
            }
            .onKeyPress("d") {
                onNavigate?(.right)
                return .handled
            }
            .onKeyPress(.return) {
                onSelect?()
                return .handled
            }
            .onKeyPress(.space) {
                onSelect?()
                return .handled
            }
            .onKeyPress(.escape) {
                onBack?()
                return .handled
            }
    }
}

extension View {
    func gameKeyboardShortcuts(
        onNavigate: ((InputDirection) -> Void)? = nil,
        onSelect: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil
    ) -> some View {
        modifier(GameKeyboardShortcuts(
            onNavigate: onNavigate,
            onSelect: onSelect,
            onBack: onBack
        ))
    }
}
