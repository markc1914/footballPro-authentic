//
//  SampleDecoder.swift
//  footballPro
//
//  Decoder for SAMPLE.DAT (8-bit unsigned PCM audio bank)
//

import Foundation

public struct Sample: Equatable {
    public let id: Int
    public let offset: Int
    public let length: Int
    public let data: [UInt8]
}

public struct SampleBank: Equatable {
    public let samples: [Sample]

    public subscript(id: Int) -> Sample? {
        samples.first { $0.id == id }
    }
}

enum SampleDecoderError: Error {
    case fileTooSmall
    case invalidCount
    case invalidOffset
}

struct SampleDecoder {
    static func decode(data: Data) throws -> SampleBank {
        guard data.count > 6 else { throw SampleDecoderError.fileTooSmall }

        let count = Int(UInt16(littleEndian: data[0...1].withUnsafeBytes { $0.load(as: UInt16.self) }))
        guard count > 0 else { throw SampleDecoderError.invalidCount }

        var offsets: [Int] = []
        offsets.reserveCapacity(count + 1)

        let tableEnd = 2 + count * 4
        guard tableEnd <= data.count else { throw SampleDecoderError.invalidOffset }

        for i in 0..<count {
            let base = 2 + i * 4
            let offset = Int(data[base]) |
                         (Int(data[base + 1]) << 8) |
                         (Int(data[base + 2]) << 16) |
                         (Int(data[base + 3]) << 24)
            offsets.append(offset)
        }
        offsets.append(data.count) // sentinel for last sample

        // Validate monotonic offsets
        for i in 0..<(offsets.count - 1) {
            if offsets[i] < tableEnd || offsets[i] >= offsets[i + 1] || offsets[i + 1] > data.count {
                throw SampleDecoderError.invalidOffset
            }
        }

        var samples: [Sample] = []
        samples.reserveCapacity(count)

        for i in 0..<count {
            let start = offsets[i]
            let end = offsets[i + 1]
            let length = end - start
            let slice = data[start..<end]
            samples.append(
                Sample(
                    id: i,
                    offset: start,
                    length: length,
                    data: Array(slice)
                )
            )
        }

        return SampleBank(samples: samples)
    }

    static func loadDefault() -> SampleBank? {
        guard let url = defaultURL() else { return nil }
        return try? decode(data: Data(contentsOf: url))
    }

    /// First existing SAMPLE.DAT path across known locations
    static func defaultURL() -> URL? {
        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            URL(fileURLWithPath: cwd).appendingPathComponent("footballPro/Resources/GameData/SAMPLE.DAT"),
            URL(fileURLWithPath: cwd).appendingPathComponent("footballPro/footballPro/Resources/GameData/SAMPLE.DAT"),
            URL(fileURLWithPath: cwd).appendingPathComponent("Resources/GameData/SAMPLE.DAT"),
            URL(fileURLWithPath: "/Users/markcornelius/projects/claude/footballPro/footballPro/FBPRO_ORIGINAL/SAMPLE.DAT")
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
