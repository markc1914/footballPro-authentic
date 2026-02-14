//
//  ControllerManager.swift
//  footballPro
//
//  GameController framework integration for controller support
//

import Foundation
import GameController
import Combine

// MARK: - Controller Type

enum ControllerType: Equatable {
    case xbox
    case playStation
    case nintendo
    case mfi
    case unknown

    var buttonALabel: String {
        switch self {
        case .xbox, .mfi, .unknown: return "A"
        case .playStation: return "✕"
        case .nintendo: return "B"
        }
    }

    var buttonBLabel: String {
        switch self {
        case .xbox, .mfi, .unknown: return "B"
        case .playStation: return "○"
        case .nintendo: return "A"
        }
    }

    var buttonXLabel: String {
        switch self {
        case .xbox, .mfi, .unknown: return "X"
        case .playStation: return "□"
        case .nintendo: return "Y"
        }
    }

    var buttonYLabel: String {
        switch self {
        case .xbox, .mfi, .unknown: return "Y"
        case .playStation: return "△"
        case .nintendo: return "X"
        }
    }

    var leftBumperLabel: String {
        switch self {
        case .xbox, .mfi, .unknown: return "LB"
        case .playStation: return "L1"
        case .nintendo: return "L"
        }
    }

    var rightBumperLabel: String {
        switch self {
        case .xbox, .mfi, .unknown: return "RB"
        case .playStation: return "R1"
        case .nintendo: return "R"
        }
    }

    var leftTriggerLabel: String {
        switch self {
        case .xbox, .mfi, .unknown: return "LT"
        case .playStation: return "L2"
        case .nintendo: return "ZL"
        }
    }

    var rightTriggerLabel: String {
        switch self {
        case .xbox, .mfi, .unknown: return "RT"
        case .playStation: return "R2"
        case .nintendo: return "ZR"
        }
    }
}

// MARK: - Controller Info

struct ControllerInfo: Identifiable, Equatable {
    let id: ObjectIdentifier
    let controller: GCController
    let type: ControllerType
    var batteryLevel: Float?
    var isCharging: Bool

    init(controller: GCController) {
        self.id = ObjectIdentifier(controller)
        self.controller = controller
        self.type = ControllerInfo.detectType(controller)
        self.batteryLevel = controller.battery?.batteryLevel
        self.isCharging = controller.battery?.batteryState == .charging
    }

    static func == (lhs: ControllerInfo, rhs: ControllerInfo) -> Bool {
        lhs.id == rhs.id
    }

    private static func detectType(_ controller: GCController) -> ControllerType {
        let name = controller.vendorName?.lowercased() ?? ""

        if name.contains("xbox") || name.contains("microsoft") {
            return .xbox
        } else if name.contains("dualshock") || name.contains("dualsense") || name.contains("sony") || name.contains("playstation") {
            return .playStation
        } else if name.contains("nintendo") || name.contains("joy-con") || name.contains("pro controller") {
            return .nintendo
        } else if controller.extendedGamepad != nil {
            return .mfi
        }

        return .unknown
    }
}

// MARK: - Controller Manager

@MainActor
class ControllerManager: ObservableObject {
    @Published var controllers: [ControllerInfo] = []
    @Published var primaryController: ControllerInfo?
    @Published var controllerType: ControllerType = .unknown

    private var cancellables = Set<AnyCancellable>()
    private var batteryTimer: Timer?

    init() {
        setupNotifications()
        refreshControllers()
        startBatteryMonitoring()
    }

    deinit {
        batteryTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshControllers()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshControllers()
            }
            .store(in: &cancellables)
    }

    func refreshControllers() {
        controllers = GCController.controllers().map { ControllerInfo(controller: $0) }

        if let first = controllers.first {
            primaryController = first
            controllerType = first.type
        } else {
            primaryController = nil
            controllerType = .unknown
        }
    }

    private func startBatteryMonitoring() {
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryLevels()
            }
        }
    }

    private func updateBatteryLevels() {
        for i in controllers.indices {
            controllers[i].batteryLevel = controllers[i].controller.battery?.batteryLevel
            controllers[i].isCharging = controllers[i].controller.battery?.batteryState == .charging
        }
    }

    // MARK: - Rumble/Haptics

    func rumble(intensity: Float = 0.5, duration: TimeInterval = 0.2) {
        guard let controller = primaryController?.controller,
              let haptics = controller.haptics else { return }

        if let engine = haptics.createEngine(withLocality: .default) {
            do {
                try engine.start()
                let pattern = CHHapticPattern.rumblePattern(intensity: intensity, duration: duration)
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
            } catch {
                // Haptics not supported or failed
            }
        }
    }

    func lightRumble() {
        rumble(intensity: 0.3, duration: 0.1)
    }

    func heavyRumble() {
        rumble(intensity: 0.8, duration: 0.3)
    }

    // MARK: - Light Bar (PlayStation)

    func setLightBarColor(_ color: GCColor) {
        guard let controller = primaryController?.controller else { return }
        controller.light?.color = color
    }

    func setLightBarForTeam(primary: String) {
        // Convert hex to GCColor
        let hex = primary.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r = Float((int >> 16) & 0xFF) / 255.0
        let g = Float((int >> 8) & 0xFF) / 255.0
        let b = Float(int & 0xFF) / 255.0

        setLightBarColor(GCColor(red: r, green: g, blue: b))
    }

    // MARK: - Button Labels

    func buttonLabel(for button: ControllerButton) -> String {
        switch button {
        case .a: return controllerType.buttonALabel
        case .b: return controllerType.buttonBLabel
        case .x: return controllerType.buttonXLabel
        case .y: return controllerType.buttonYLabel
        case .leftBumper: return controllerType.leftBumperLabel
        case .rightBumper: return controllerType.rightBumperLabel
        case .leftTrigger: return controllerType.leftTriggerLabel
        case .rightTrigger: return controllerType.rightTriggerLabel
        case .dpadUp: return "↑"
        case .dpadDown: return "↓"
        case .dpadLeft: return "←"
        case .dpadRight: return "→"
        case .menu: return "Menu"
        case .options: return "Options"
        }
    }
}

enum ControllerButton {
    case a, b, x, y
    case leftBumper, rightBumper
    case leftTrigger, rightTrigger
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case menu, options
}

// MARK: - Haptic Pattern Extension

import CoreHaptics

extension CHHapticPattern {
    static func rumblePattern(intensity: Float, duration: TimeInterval) -> CHHapticPattern {
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: 0,
            duration: duration
        )

        do {
            return try CHHapticPattern(events: [event], parameters: [])
        } catch {
            return try! CHHapticPattern(events: [], parameters: [])
        }
    }
}
