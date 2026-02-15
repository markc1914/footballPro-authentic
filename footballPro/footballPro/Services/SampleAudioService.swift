//
//  SampleAudioService.swift
//  footballPro
//
//  Plays authentic SAMPLE.DAT audio via AVAudioPlayer. Falls back silently if unavailable.
//

import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

final class SampleAudioService {
    static let shared = SampleAudioService()

    private let sampleBank: SampleBank?
    private var playerCache: [Int: Any] = [:] // AVAudioPlayer, but erased to keep Linux builds happy
    private let sampleRate: UInt32 = 11025

    // For testing/telemetry
    private(set) var lastPlayedSampleId: Int?

    private init() {
        self.sampleBank = SampleDecoder.loadDefault()
    }

    func hasSample(id: Int) -> Bool {
        guard let bank = sampleBank else { return false }
        return bank[id] != nil
    }

    @discardableResult
    func play(id: Int, volume: Float = 1.0, allowOverlap: Bool = false) -> Bool {
        lastPlayedSampleId = id
        guard let bank = sampleBank, let sample = bank[id] else { return false }

#if canImport(AVFoundation)
        let wavData = makeWavData(for: sample, sampleRate: sampleRate)

        if !allowOverlap, let cached = playerCache[id] as? AVAudioPlayer {
            cached.stop()
            cached.currentTime = 0
            cached.volume = volume
            cached.play()
            return true
        }

        do {
            let player = try AVAudioPlayer(data: wavData)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            playerCache[id] = player
            return true
        } catch {
            print("[SampleAudioService] Failed to play sample \(id): \(error)")
            return false
        }
#else
        return true // Non-AV platforms: no-op success
#endif
    }

    @discardableResult
    func play(effect: SoundEffect, volume: Float = 1.0) -> Bool {
        guard let sampleId = effectSampleMap[effect] else { return false }
        return play(id: sampleId, volume: volume, allowOverlap: effect.allowsOverlap)
    }

    // MARK: - WAV header builder

    private func makeWavData(for sample: Sample, sampleRate: UInt32) -> Data {
        var data = Data()

        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 8
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * bitsPerSample / 8
        let subchunk2Size = UInt32(sample.length)
        let chunkSize = 36 + subchunk2Size

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(uint32LE: chunkSize)
        data.append(contentsOf: "WAVE".utf8)

        // fmt subchunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(uint32LE: 16)              // Subchunk1Size for PCM
        data.append(uint16LE: 1)               // PCM format
        data.append(uint16LE: numChannels)
        data.append(uint32LE: sampleRate)
        data.append(uint32LE: byteRate)
        data.append(uint16LE: blockAlign)
        data.append(uint16LE: bitsPerSample)

        // data subchunk
        data.append(contentsOf: "data".utf8)
        data.append(uint32LE: subchunk2Size)
        data.append(contentsOf: sample.data)

        return data
    }

    // MARK: - Effect mapping

    private let effectSampleMap: [SoundEffect: Int] = [
        .whistle: 0,
        .hike: 1,
        .tackle: 2,
        .touchdown: 3,
        .crowdCheer: 4,
        .crowdBoo: 5,
        .fieldGoalGood: 6,
        .fieldGoalMiss: 7,
        .menuSelect: 8,
        .menuNavigate: 9
    ]
}

// MARK: - Helpers

private extension Data {
    mutating func append(uint16LE value: UInt16) {
        var v = value
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func append(uint32LE value: UInt32) {
        var v = value
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}

private extension SoundEffect {
    var allowsOverlap: Bool {
        switch self {
        case .crowdAmbient, .crowdCheer, .crowdBoo: return true
        default: return false
        }
    }
}
