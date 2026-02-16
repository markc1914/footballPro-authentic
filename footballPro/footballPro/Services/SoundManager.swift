//
//  SoundManager.swift
//  footballPro
//
//  Sound effects manager - inspired by classic 1993 FPS Football Pro
//

import Foundation
import AVFoundation
import AppKit
import Foundation

// MARK: - Sound Effect Types

enum SoundEffect: String, CaseIterable {
    // Game sounds
    case whistle = "whistle"
    case crowdCheer = "crowd_cheer"
    case crowdBoo = "crowd_boo"
    case crowdAmbient = "crowd_ambient"
    case touchdown = "touchdown"
    case fieldGoalGood = "field_goal_good"
    case fieldGoalMiss = "field_goal_miss"

    // Play sounds
    case hike = "hike"
    case tackle = "tackle"
    case catch_sound = "catch"
    case incomplete = "incomplete"
    case fumble = "fumble"
    case interception = "interception"

    // UI sounds
    case menuSelect = "menu_select"
    case menuNavigate = "menu_navigate"
    case playSelect = "play_select"
    case clockTick = "clock_tick"

    // Retro synthesized frequencies for each sound
    var frequency: Double {
        switch self {
        case .whistle: return 1200
        case .crowdCheer: return 400
        case .crowdBoo: return 200
        case .crowdAmbient: return 150
        case .touchdown: return 800
        case .fieldGoalGood: return 600
        case .fieldGoalMiss: return 300
        case .hike: return 350
        case .tackle: return 180
        case .catch_sound: return 500
        case .incomplete: return 400
        case .fumble: return 250
        case .interception: return 350
        case .menuSelect: return 700
        case .menuNavigate: return 500
        case .playSelect: return 600
        case .clockTick: return 1000
        }
    }

    var duration: Double {
        switch self {
        case .whistle: return 0.5
        case .crowdCheer: return 2.0
        case .crowdBoo: return 1.5
        case .crowdAmbient: return 3.0
        case .touchdown: return 1.5
        case .fieldGoalGood: return 1.0
        case .fieldGoalMiss: return 0.8
        case .hike: return 0.2
        case .tackle: return 0.3
        case .catch_sound: return 0.2
        case .incomplete: return 0.4
        case .fumble: return 0.5
        case .interception: return 0.6
        case .menuSelect: return 0.1
        case .menuNavigate: return 0.05
        case .playSelect: return 0.15
        case .clockTick: return 0.05
        }
    }
}

// MARK: - Sound Manager

@MainActor
class SoundManager: ObservableObject {
    static let shared = SoundManager()

    @Published var isSoundEnabled = true
    @Published var volume: Float = 0.7
    @Published var isCrowdEnabled = true

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var crowdPlayerNode: AVAudioPlayerNode?

    // Disable audio when running under tests/CI or when explicitly requested.
    private static let audioAllowed: Bool = {
        let env = ProcessInfo.processInfo.environment
        if env["DISABLE_AUDIO"] != nil { return false }
        if env["CI"] != nil { return false }
        if env["XCTestConfigurationFilePath"] != nil { return false }
        if Bundle.allBundles.contains(where: { $0.bundleURL.pathExtension == "xctest" }) { return false }
        return true
    }()

    private init() {
        guard Self.audioAllowed else {
            isSoundEnabled = false
            isCrowdEnabled = false
            return
        }
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        crowdPlayerNode = AVAudioPlayerNode()

        guard let engine = audioEngine,
              let player = playerNode,
              let crowdPlayer = crowdPlayerNode else { return }

        engine.attach(player)
        engine.attach(crowdPlayer)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.connect(crowdPlayer, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    // MARK: - Play Sounds

    func play(_ effect: SoundEffect) {
        guard isSoundEnabled else { return }

        // Prefer authentic SAMPLE.DAT if available; fall back to generated tone
        if SampleAudioService.shared.play(effect: effect, volume: volume) {
            return
        }

        Task {
            await generateAndPlayTone(
                frequency: effect.frequency,
                duration: effect.duration,
                volume: volume
            )
        }
    }

    func playTouchdown() {
        guard isSoundEnabled else { return }

        // Play touchdown fanfare - ascending tones
        Task {
            for i in 0..<5 {
                await generateAndPlayTone(
                    frequency: 400 + Double(i) * 100,
                    duration: 0.15,
                    volume: volume
                )
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            play(.crowdCheer)
        }
    }

    func playFieldGoal(good: Bool) {
        guard isSoundEnabled else { return }

        if good {
            Task {
                // Rising tone for good kick
                for i in 0..<3 {
                    await generateAndPlayTone(
                        frequency: 500 + Double(i) * 150,
                        duration: 0.2,
                        volume: volume
                    )
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
                play(.crowdCheer)
            }
        } else {
            Task {
                // Descending sad tone for miss
                for i in 0..<3 {
                    await generateAndPlayTone(
                        frequency: 500 - Double(i) * 100,
                        duration: 0.25,
                        volume: volume
                    )
                    try? await Task.sleep(nanoseconds: 150_000_000)
                }
                play(.crowdBoo)
            }
        }
    }

    func playTurnover() {
        guard isSoundEnabled else { return }

        Task {
            // Dramatic descending tones
            for i in 0..<4 {
                await generateAndPlayTone(
                    frequency: 600 - Double(i) * 100,
                    duration: 0.2,
                    volume: volume
                )
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    func playFirstDown() {
        guard isSoundEnabled else { return }

        Task {
            await generateAndPlayTone(frequency: 500, duration: 0.1, volume: volume)
            try? await Task.sleep(nanoseconds: 50_000_000)
            await generateAndPlayTone(frequency: 700, duration: 0.15, volume: volume)
        }
    }

    func playBigPlay(yards: Int) {
        guard isSoundEnabled else { return }

        if yards >= 20 {
            Task {
                // Exciting ascending scale
                for i in 0..<min(yards / 5, 8) {
                    await generateAndPlayTone(
                        frequency: 400 + Double(i) * 75,
                        duration: 0.08,
                        volume: volume
                    )
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                play(.crowdCheer)
            }
        }
    }

    // MARK: - Crowd Ambient Sound

    func startCrowdAmbient() {
        guard isCrowdEnabled, isSoundEnabled else { return }
        // In a full implementation, this would loop crowd noise
    }

    func stopCrowdAmbient() {
        crowdPlayerNode?.stop()
    }

    func crowdReact(positive: Bool) {
        guard isSoundEnabled, isCrowdEnabled else { return }
        play(positive ? .crowdCheer : .crowdBoo)
    }

    // MARK: - Retro Tone Generation

    private func generateAndPlayTone(frequency: Double, duration: Double, volume: Float) async {
        guard let player = playerNode,
              let engine = audioEngine,
              engine.isRunning else { return }

        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(duration * sampleRate)

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!,
            frameCapacity: frameCount
        ) else { return }

        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?[0] else { return }

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate

            // Generate retro square wave with slight frequency wobble for that classic sound
            let wobble = sin(time * 5) * 0.02
            let phase = 2.0 * .pi * frequency * (1.0 + wobble) * time

            // Square wave with soft edges (more pleasant than pure square)
            var sample = sin(phase) > 0 ? 1.0 : -1.0

            // Add harmonics for richer sound
            sample += sin(phase * 2) * 0.3
            sample += sin(phase * 3) * 0.15

            // Apply envelope for click-free playback
            let envelope = min(1.0, min(time * 20, (duration - time) * 20))

            channelData[frame] = Float(sample * Double(volume) * 0.3 * envelope)
        }

        await player.scheduleBuffer(buffer)

        if !player.isPlaying {
            player.play()
        }
    }

    // MARK: - Volume Control

    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        audioEngine?.mainMixerNode.outputVolume = volume
    }

    func toggleSound() {
        isSoundEnabled.toggle()
        if !isSoundEnabled {
            stopCrowdAmbient()
        }
    }
}

// MARK: - Play Result Sound Effects

extension SoundManager {
    func playSoundForResult(_ result: PlayResult) {
        if result.isTouchdown {
            playTouchdown()
        } else if result.isTurnover {
            playTurnover()
        } else if result.isFirstDown {
            playFirstDown()
        } else if result.yardsGained >= 15 {
            playBigPlay(yards: result.yardsGained)
        } else if result.yardsGained < 0 {
            play(.tackle)
        } else {
            play(.whistle)
        }
    }
}
