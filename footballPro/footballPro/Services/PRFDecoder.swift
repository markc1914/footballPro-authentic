//
//  PRFDecoder.swift
//  footballPro
//
//  Decoder for Front Page Sports: Football Pro '93 PRF/PLN binary play files.
//

import Foundation

enum PRFDecoderError: Error, LocalizedError {
    case fileTooSmall(url: URL, expectedAtLeast: Int, actual: Int)
    case invalidPRFShape(url: URL, groupsFound: Int, expectedAtLeast: Int)
    case invalidOffset(url: URL, offset: Int, length: Int)
    case invalidASCIIName(url: URL, offset: Int)

    var errorDescription: String? {
        switch self {
        case .fileTooSmall(let url, let expectedAtLeast, let actual):
            return "File \(url.lastPathComponent) is too small. Expected at least \(expectedAtLeast) bytes, got \(actual)."
        case .invalidPRFShape(let url, let groupsFound, let expectedAtLeast):
            return "PRF payload in \(url.lastPathComponent) is malformed. Found \(groupsFound) groups, expected at least \(expectedAtLeast)."
        case .invalidOffset(let url, let offset, let length):
            return "Read out of bounds in \(url.lastPathComponent) at offset \(offset) with length \(length)."
        case .invalidASCIIName(let url, let offset):
            return "Encountered non-printable play name in \(url.lastPathComponent) at offset \(offset)."
        }
    }
}

struct PRFCell: Equatable {
    let byte0: UInt8
    let byte1: UInt8
    let byte2: UInt8
    let byte3: UInt8
    let byte4: UInt8
    let byte5: UInt8

    var actionCodes: [UInt8] { [byte0, byte2, byte4] }
    var stateBytes: [UInt8] { [byte1, byte3, byte5] }

    var hasActiveState: Bool {
        stateBytes.contains(0x0A)
    }

    var rawBytes: [UInt8] {
        [byte0, byte1, byte2, byte3, byte4, byte5]
    }
}

struct PRFPlayPhase: Equatable {
    let phaseIndex: Int
    let routeRows: [[PRFCell]]  // 3 rows x 18 columns
    let formationRow: [PRFCell] // 1 row x 18 columns
}

struct PRFPlayGrid: Equatable {
    let playIndex: Int
    let rows: [[PRFCell]] // 20 rows x 18 columns

    var phases: [PRFPlayPhase] {
        (0..<5).map { phase in
            let baseRow = phase * 4
            return PRFPlayPhase(
                phaseIndex: phase,
                routeRows: Array(rows[baseRow..<(baseRow + 3)]),
                formationRow: rows[baseRow + 3]
            )
        }
    }

    func cell(row: Int, column: Int) -> PRFCell {
        rows[row][column]
    }

    func actionHistogram(includeFormationRows: Bool = false) -> [UInt8: Int] {
        var histogram: [UInt8: Int] = [:]

        for row in 0..<rows.count {
            if !includeFormationRows && row % 4 == 3 {
                continue
            }
            for column in 0..<rows[row].count {
                for code in rows[row][column].actionCodes {
                    histogram[code, default: 0] += 1
                }
            }
        }

        return histogram
    }

    func activeColumnCount(formationRow: Int = 3) -> Int {
        guard rows.indices.contains(formationRow) else { return 0 }
        return rows[formationRow].filter { $0.hasActiveState }.count
    }
}

struct PRFFile: Equatable {
    let sourceURL: URL
    let headerBytes: Data
    let footerBytes: Data?
    let playGrids: [PRFPlayGrid] // 7 plays
    let uniformGroupCount: Int

    var headerMagic: String {
        String(data: headerBytes.prefix(4), encoding: .ascii) ?? ""
    }
}

struct PLNEntry: Equatable {
    let index: Int
    let byteOffset: Int
    let formationCode: UInt16
    let formationMirrorCode: UInt16
    let name: String
    let prfPage: UInt16
    let prfOffset: UInt16
    let prfReferenceRaw: UInt32
    let size: UInt16

    var formationDisplayName: String {
        PRFDecoder.decodeFormation(formationCode: formationCode, mirrorCode: formationMirrorCode)
    }
}

struct PLNFile: Equatable {
    let sourceURL: URL
    let headerMagic: String
    let configHex: String
    let offsetTable: [UInt16]
    let entries: [PLNEntry]
    let footerBytes: Data?

    var activeOffsetSlots: Int {
        offsetTable.filter { $0 != 0 }.count
    }
}

struct PRFDecoder {
    // PRF format constants
    static let prfHeaderSize = 0x28
    static let prfRows = 20
    static let prfColumns = 18
    static let prfCellSize = 6
    static let prfPlaysPerBank = 7
    static let prfGroupSize = prfCellSize * prfPlaysPerBank // 42
    static let prfGroups = prfRows * prfColumns             // 360

    // PLN format constants
    static let plnHeaderSize = 12
    static let plnOffsetSlots = 86
    static let plnOffsetTableSize = plnOffsetSlots * 2
    static let plnEntryAreaStart = plnHeaderSize + plnOffsetTableSize // 184
    static let plnEntrySize = 18

    private static let prfFooterMarker = Data("#I93:".utf8)
    private static let plnFooterMarker = Data("J93:".utf8)

    private static let formationNames: [UInt16: String] = [
        0x8501: "I-Form", 0x8502: "I-Form Var", 0x8503: "Split Back",
        0x8504: "Pro Set", 0x8505: "Shotgun", 0x8506: "Singleback",
        0x8507: "Near Back", 0x8508: "Far Back", 0x8509: "Wishbone",
        0x850A: "Goal Line Off",
        0x8401: "4-3", 0x8402: "3-4", 0x8403: "4-4", 0x8404: "Nickel",
        0x8405: "Dime", 0x8406: "3-5-3", 0x8407: "Goal Line Def",
        0x8408: "Prevent",
        0x0004: "ST: Run", 0x0400: "ST: Pass", 0x0002: "ST: Blitz",
        0x0012: "ST: Special", 0x000C: "ST: Zone", 0x0008: "ST: Mix",
        0x0030: "GL: Run", 0x0032: "GL: Pass", 0x0022: "ST: Deep"
    ]

    private static let specialOffenseSubtypes: [UInt16: String] = [
        0x0101: "FG/PAT", 0x0102: "Kickoff", 0x0103: "Punt",
        0x0104: "Onside Kick", 0x0105: "Fake FG Run", 0x0106: "Fake FG Pass",
        0x0107: "Fake Punt Run", 0x0108: "Fake Punt Pass", 0x0109: "Free Kick",
        0x010A: "Squib", 0x010B: "Run Clock", 0x010C: "Stop Clock"
    ]

    private static let specialDefenseSubtypes: [UInt16: String] = [
        0x0001: "FG/PAT Def", 0x0002: "Kick Return", 0x0003: "Punt Return",
        0x0004: "Onside Return", 0x0005: "Fake FG Run D", 0x0006: "Fake FG Pass D",
        0x0007: "Fake Punt Run D", 0x0008: "Fake Punt Pass D",
        0x0009: "Free Return", 0x000A: "Squib Return"
    ]

    private static let actionNames: [UInt8: String] = [
        0x00: "ZERO", 0x02: "MOVE_A", 0x03: "MOVE_B", 0x04: "MOVE_C",
        0x05: "MOVE_D", 0x0A: "BREAK", 0x0C: "CUT", 0x10: "POS_A",
        0x13: "POS_B", 0x16: "SPECIAL", 0x17: "HOLD", 0x18: "HOLD+1",
        0x19: "DEEP", 0x1A: "BLOCK"
    ]

    static func decodePRF(at url: URL) throws -> PRFFile {
        let data = try Data(contentsOf: url)
        let minimumSize = prfHeaderSize + (prfGroups * prfGroupSize)
        guard data.count >= minimumSize else {
            throw PRFDecoderError.fileTooSmall(url: url, expectedAtLeast: minimumSize, actual: data.count)
        }

        let footerStart = data.range(of: prfFooterMarker)?.lowerBound
        let payloadEnd = footerStart ?? data.count
        let groupCount = (payloadEnd - prfHeaderSize) / prfGroupSize

        guard groupCount >= prfGroups else {
            throw PRFDecoderError.invalidPRFShape(url: url, groupsFound: groupCount, expectedAtLeast: prfGroups)
        }

        let header = try data.slice(from: 0, length: prfHeaderSize, in: url)
        let footer = footerStart.map { Data(data[$0..<data.count]) }

        var plays: [PRFPlayGrid] = []
        plays.reserveCapacity(prfPlaysPerBank)

        for playIndex in 0..<prfPlaysPerBank {
            var rows: [[PRFCell]] = []
            rows.reserveCapacity(prfRows)

            for row in 0..<prfRows {
                var columns: [PRFCell] = []
                columns.reserveCapacity(prfColumns)

                for column in 0..<prfColumns {
                    let groupIndex = row * prfColumns + column
                    let groupOffset = prfHeaderSize + (groupIndex * prfGroupSize)
                    let recordOffset = groupOffset + (playIndex * prfCellSize)
                    columns.append(try parsePRFCell(from: data, at: recordOffset, fileURL: url))
                }

                rows.append(columns)
            }

            plays.append(PRFPlayGrid(playIndex: playIndex, rows: rows))
        }

        var uniformGroups = 0
        for groupIndex in 0..<prfGroups {
            let groupOffset = prfHeaderSize + (groupIndex * prfGroupSize)
            let first = try data.slice(from: groupOffset, length: prfCellSize, in: url)
            var isUniform = true

            for playIndex in 1..<prfPlaysPerBank {
                let recordOffset = groupOffset + (playIndex * prfCellSize)
                let record = try data.slice(from: recordOffset, length: prfCellSize, in: url)
                if record != first {
                    isUniform = false
                    break
                }
            }

            if isUniform {
                uniformGroups += 1
            }
        }

        return PRFFile(
            sourceURL: url,
            headerBytes: header,
            footerBytes: footer,
            playGrids: plays,
            uniformGroupCount: uniformGroups
        )
    }

    static func decodePLN(at url: URL) throws -> PLNFile {
        let data = try Data(contentsOf: url)
        let minimumSize = plnEntryAreaStart
        guard data.count >= minimumSize else {
            throw PRFDecoderError.fileTooSmall(url: url, expectedAtLeast: minimumSize, actual: data.count)
        }

        let headerMagic = String(data: try data.slice(from: 0, length: 4, in: url), encoding: .ascii) ?? ""
        let configHex = (try data.slice(from: 4, length: 8, in: url)).hexString()

        var offsets: [UInt16] = []
        offsets.reserveCapacity(plnOffsetSlots)
        for slot in 0..<plnOffsetSlots {
            let offset = try data.u16LE(at: plnHeaderSize + (slot * 2), in: url)
            offsets.append(offset)
        }

        let footerStart = data.range(of: plnFooterMarker)?.lowerBound
        let entryEnd = footerStart ?? data.count
        let footer = footerStart.map { Data(data[$0..<data.count]) }

        var entries: [PLNEntry] = []
        var cursor = plnEntryAreaStart
        var index = 0

        while cursor + plnEntrySize <= entryEnd {
            let formationCode = try data.u16LE(at: cursor, in: url)
            let formationMirrorCode = try data.u16LE(at: cursor + 2, in: url)
            let nameBytes = try data.slice(from: cursor + 4, length: 8, in: url)
            let prfReference = try data.u32LE(at: cursor + 12, in: url)
            let size = try data.u16LE(at: cursor + 16, in: url)

            let name = String.zeroTerminatedASCII(from: nameBytes)
            if name.isEmpty {
                break
            }

            guard name.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value <= 0x7E }) else {
                throw PRFDecoderError.invalidASCIIName(url: url, offset: cursor + 4)
            }

            entries.append(PLNEntry(
                index: index,
                byteOffset: cursor,
                formationCode: formationCode,
                formationMirrorCode: formationMirrorCode,
                name: name,
                prfPage: UInt16((prfReference >> 16) & 0xFFFF),
                prfOffset: UInt16(prfReference & 0xFFFF),
                prfReferenceRaw: prfReference,
                size: size
            ))

            index += 1
            cursor += plnEntrySize
        }

        return PLNFile(
            sourceURL: url,
            headerMagic: headerMagic,
            configHex: configHex,
            offsetTable: offsets,
            entries: entries,
            footerBytes: footer
        )
    }

    static func decodeAction(_ code: UInt8) -> String {
        actionNames[code] ?? String(format: "ACT_%02X", code)
    }

    static func decodeFormation(formationCode: UInt16, mirrorCode: UInt16) -> String {
        if formationCode <= 0x0100 {
            if let label = specialOffenseSubtypes[mirrorCode] ?? specialDefenseSubtypes[mirrorCode] {
                return "ST: \(label)"
            }
            return String(format: "ST: 0x%04X/0x%04X", formationCode, mirrorCode)
        }

        let name = formationNames[formationCode] ?? String(format: "Form 0x%04X", formationCode)
        if mirrorCode != formationCode {
            return String(format: "%@ (m:0x%04X)", name, mirrorCode)
        }
        return name
    }

    private static func parsePRFCell(from data: Data, at offset: Int, fileURL: URL) throws -> PRFCell {
        guard offset + prfCellSize <= data.count else {
            throw PRFDecoderError.invalidOffset(url: fileURL, offset: offset, length: prfCellSize)
        }

        return PRFCell(
            byte0: data[offset],
            byte1: data[offset + 1],
            byte2: data[offset + 2],
            byte3: data[offset + 3],
            byte4: data[offset + 4],
            byte5: data[offset + 5]
        )
    }
}

private extension Data {
    func slice(from offset: Int, length: Int, in fileURL: URL) throws -> Data {
        guard offset >= 0, length >= 0, offset + length <= count else {
            throw PRFDecoderError.invalidOffset(url: fileURL, offset: offset, length: length)
        }
        return Data(self[offset..<(offset + length)])
    }

    func u16LE(at offset: Int, in fileURL: URL) throws -> UInt16 {
        let bytes = try slice(from: offset, length: 2, in: fileURL)
        return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
    }

    func u32LE(at offset: Int, in fileURL: URL) throws -> UInt32 {
        let bytes = try slice(from: offset, length: 4, in: fileURL)
        return UInt32(bytes[0]) |
            (UInt32(bytes[1]) << 8) |
            (UInt32(bytes[2]) << 16) |
            (UInt32(bytes[3]) << 24)
    }

    func hexString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private extension String {
    static func zeroTerminatedASCII(from data: Data) -> String {
        let trimmed = data.prefix { $0 != 0x00 }
        return String(bytes: trimmed, encoding: .ascii) ?? ""
    }
}
