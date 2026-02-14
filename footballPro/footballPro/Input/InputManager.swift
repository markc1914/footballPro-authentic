//
//  InputManager.swift
//  footballPro
//
//  Unified input handling for keyboard, mouse, and controllers
//

import Foundation
import SwiftUI
import GameController
import Combine

// MARK: - Input Types

enum InputDirection: Equatable {
    case up
    case down
    case left
    case right
}

enum QuickAction: Equatable {
    case tabLeft
    case tabRight
    case info
    case back
    case pause
    case confirm
    case cancel
}

enum InputDevice: Equatable {
    case keyboard
    case mouse
    case controller(GCController)

    var displayName: String {
        switch self {
        case .keyboard: return "Keyboard"
        case .mouse: return "Mouse"
        case .controller(let gc):
            return gc.vendorName ?? "Controller"
        }
    }

    var isController: Bool {
        if case .controller = self { return true }
        return false
    }
}

// MARK: - Button Prompts

struct ButtonPrompt {
    var action: String
    var keyboardKey: String
    var controllerButton: String

    static let confirm = ButtonPrompt(action: "Select", keyboardKey: "Enter", controllerButton: "A")
    static let cancel = ButtonPrompt(action: "Back", keyboardKey: "Esc", controllerButton: "B")
    static let info = ButtonPrompt(action: "Info", keyboardKey: "I", controllerButton: "Y")
    static let pause = ButtonPrompt(action: "Menu", keyboardKey: "Esc", controllerButton: "Menu")
    static let tabLeft = ButtonPrompt(action: "Prev Tab", keyboardKey: "Q", controllerButton: "LB")
    static let tabRight = ButtonPrompt(action: "Next Tab", keyboardKey: "E", controllerButton: "RB")
}

// MARK: - Input Handler Protocol

protocol InputHandler: AnyObject {
    func onNavigate(direction: InputDirection)
    func onSelect()
    func onBack()
    func onMenu()
    func onQuickAction(_ action: QuickAction)
}

// MARK: - Input Manager

@MainActor
class InputManager: ObservableObject {
    @Published var activeDevice: InputDevice = .keyboard
    @Published var connectedControllers: [GCController] = []
    @Published var isControllerConnected: Bool = false

    weak var currentHandler: InputHandler?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupControllerNotifications()
    }

    func startListening() {
        // Check for already connected controllers
        checkConnectedControllers()

        // Start wireless controller discovery
        GCController.startWirelessControllerDiscovery {
            // Discovery completed
        }
    }

    func stopListening() {
        GCController.stopWirelessControllerDiscovery()
    }

    // MARK: - Controller Setup

    private func setupControllerNotifications() {
        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let controller = notification.object as? GCController {
                    self?.controllerConnected(controller)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let controller = notification.object as? GCController {
                    self?.controllerDisconnected(controller)
                }
            }
            .store(in: &cancellables)
    }

    private func checkConnectedControllers() {
        connectedControllers = GCController.controllers()
        isControllerConnected = !connectedControllers.isEmpty

        for controller in connectedControllers {
            configureController(controller)
        }

        if let firstController = connectedControllers.first {
            activeDevice = .controller(firstController)
        }
    }

    private func controllerConnected(_ controller: GCController) {
        if !connectedControllers.contains(where: { $0 === controller }) {
            connectedControllers.append(controller)
        }
        isControllerConnected = true
        configureController(controller)
        activeDevice = .controller(controller)
    }

    private func controllerDisconnected(_ controller: GCController) {
        connectedControllers.removeAll { $0 === controller }
        isControllerConnected = !connectedControllers.isEmpty

        if !isControllerConnected {
            activeDevice = .keyboard
        } else if let next = connectedControllers.first {
            activeDevice = .controller(next)
        }
    }

    private func configureController(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        // D-Pad
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            Task { @MainActor in
                if yValue > 0.5 {
                    self?.handleNavigation(.up)
                } else if yValue < -0.5 {
                    self?.handleNavigation(.down)
                }
                if xValue > 0.5 {
                    self?.handleNavigation(.right)
                } else if xValue < -0.5 {
                    self?.handleNavigation(.left)
                }
            }
        }

        // Left Thumbstick
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            Task { @MainActor in
                if yValue > 0.5 {
                    self?.handleNavigation(.up)
                } else if yValue < -0.5 {
                    self?.handleNavigation(.down)
                }
                if xValue > 0.5 {
                    self?.handleNavigation(.right)
                } else if xValue < -0.5 {
                    self?.handleNavigation(.left)
                }
            }
        }

        // A Button (Confirm)
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.handleSelect()
                }
            }
        }

        // B Button (Back)
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.handleBack()
                }
            }
        }

        // X Button
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.handleQuickAction(.info)
                }
            }
        }

        // Y Button
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.handleQuickAction(.info)
                }
            }
        }

        // Shoulder buttons
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.handleQuickAction(.tabLeft)
                }
            }
        }

        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.handleQuickAction(.tabRight)
                }
            }
        }

        // Menu button
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                Task { @MainActor in
                    self?.handleMenu()
                }
            }
        }
    }

    // MARK: - Input Handling

    func handleNavigation(_ direction: InputDirection) {
        if activeDevice == .keyboard {
            // Already keyboard, keep it
        } else if case .controller = activeDevice {
            // Already controller, keep it
        }
        currentHandler?.onNavigate(direction: direction)
    }

    func handleSelect() {
        currentHandler?.onSelect()
    }

    func handleBack() {
        currentHandler?.onBack()
    }

    func handleMenu() {
        currentHandler?.onMenu()
    }

    func handleQuickAction(_ action: QuickAction) {
        currentHandler?.onQuickAction(action)
    }

    // MARK: - Keyboard Input (called from view)

    func handleKeyPress(_ key: KeyEquivalent, modifiers: EventModifiers = []) {
        activeDevice = .keyboard

        switch key {
        case .upArrow, "w":
            handleNavigation(.up)
        case .downArrow, "s":
            handleNavigation(.down)
        case .leftArrow, "a":
            handleNavigation(.left)
        case .rightArrow, "d":
            handleNavigation(.right)
        case .return, .space:
            handleSelect()
        case .escape:
            handleBack()
        case "q":
            handleQuickAction(.tabLeft)
        case "e":
            handleQuickAction(.tabRight)
        case "i":
            handleQuickAction(.info)
        default:
            break
        }
    }

    // MARK: - Button Prompt Helpers

    func promptText(for prompt: ButtonPrompt) -> String {
        if case .controller = activeDevice {
            return prompt.controllerButton
        }
        return prompt.keyboardKey
    }

    func allPrompts() -> [(action: String, key: String)] {
        let prompts = [ButtonPrompt.confirm, .cancel, .tabLeft, .tabRight, .info]
        return prompts.map { prompt in
            (prompt.action, promptText(for: prompt))
        }
    }
}

// MARK: - Keyboard Event Handler View Modifier

struct KeyboardInputModifier: ViewModifier {
    @EnvironmentObject var inputManager: InputManager

    func body(content: Content) -> some View {
        content
            .onKeyPress(.upArrow) { inputManager.handleKeyPress(.upArrow); return .handled }
            .onKeyPress(.downArrow) { inputManager.handleKeyPress(.downArrow); return .handled }
            .onKeyPress(.leftArrow) { inputManager.handleKeyPress(.leftArrow); return .handled }
            .onKeyPress(.rightArrow) { inputManager.handleKeyPress(.rightArrow); return .handled }
            .onKeyPress(.return) { inputManager.handleKeyPress(.return); return .handled }
            .onKeyPress(.space) { inputManager.handleKeyPress(.space); return .handled }
            .onKeyPress(.escape) { inputManager.handleKeyPress(.escape); return .handled }
            .onKeyPress("w") { inputManager.handleKeyPress("w"); return .handled }
            .onKeyPress("a") { inputManager.handleKeyPress("a"); return .handled }
            .onKeyPress("s") { inputManager.handleKeyPress("s"); return .handled }
            .onKeyPress("d") { inputManager.handleKeyPress("d"); return .handled }
            .onKeyPress("q") { inputManager.handleKeyPress("q"); return .handled }
            .onKeyPress("e") { inputManager.handleKeyPress("e"); return .handled }
            .onKeyPress("i") { inputManager.handleKeyPress("i"); return .handled }
    }
}

extension View {
    func handleKeyboardInput() -> some View {
        modifier(KeyboardInputModifier())
    }
}

// MARK: - Focusable Navigation Item

struct NavigableItem<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @EnvironmentObject var inputManager: InputManager
    @State private var isHovered = false

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.3) : (isHovered ? Color.white.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    inputManager.activeDevice = .mouse
                }
            }
            .onTapGesture {
                inputManager.activeDevice = .mouse
                action()
            }
    }
}
