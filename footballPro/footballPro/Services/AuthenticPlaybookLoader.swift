//
//  AuthenticPlaybookLoader.swift
//  footballPro
//
//  High-level loader for original FPS '93 OFF/DEF playbooks.
//

import Foundation

public enum PRFBookKind: String, Codable { // Made public
    case offense
    case defense

    var plnFileName: String {
        switch self {
        case .offense: return "OFF.PLN"
        case .defense: return "DEF.PLN"
        }
    }

    var firstPRFFileName: String {
        switch self {
        case .offense: return "OFF1.PRF"
        case .defense: return "DEF1.PRF"
        }
    }

    var secondPRFFileName: String {
        switch self {
        case .offense: return "OFF2.PRF"
        case .defense: return "DEF2.PRF"
        }
    }
}

public enum PRFBank: Int, Codable { // Made public
    case first = 1
    case second = 2
}

public struct AuthenticPlayReference: Codable, Equatable { // Made public
    let bank: PRFBank
    let page: UInt16
    let rawOffset: UInt16
    let virtualOffset: UInt16
    let size: UInt16

    public var virtualRange: Range<Int> { // Made public
        let start = Int(virtualOffset)
        let end = start + Int(size)
        return start..<end
    }
}

// MARK: - Play Category (inferred from FPS '93 naming conventions)

public enum AuthenticPlayCategory: String, Codable {
    case run        // RL, RR suffixes (run left/right)
    case pass       // PL, PR, PS suffixes (pass left/right/short)
    case screen     // SA prefix (screen)
    case draw       // DR prefix
    case playAction // Names containing "PA" or "FA" (fake)
    case specialTeams
    case unknown
}

public struct AuthenticPlayDefinition: Identifiable, Codable, Equatable { // Made public
    public let id: UUID // Made public
    public let index: Int
    public let name: String
    public let formationCode: UInt16
    public let formationMirrorCode: UInt16
    public let formationName: String
    public let sourcePLNOffset: Int
    public let reference: AuthenticPlayReference
    public let isSpecialTeams: Bool

    // A compact signature of the resolved PRF page so callers can detect page reuse.
    public let pageSignature: String

    /// Category inferred from FPS '93 play naming conventions
    public var category: AuthenticPlayCategory {
        if isSpecialTeams { return .specialTeams }

        let upper = name.uppercased()

        // Screen plays: SA prefix
        if upper.hasPrefix("SA") { return .screen }

        // Draw plays: DR prefix
        if upper.hasPrefix("DR") { return .draw }

        // Play action: contains PA or FA (fake action)
        if upper.contains("PA") || upper.hasPrefix("FA") { return .playAction }

        // Run plays: RL/RR suffix (run left/run right)
        if upper.hasSuffix("RL") || upper.hasSuffix("RR") ||
           upper.contains("RL") || upper.contains("RR") { return .run }

        // Pass plays: PL/PR/PS suffix (pass left/pass right/pass short)
        if upper.hasSuffix("PL") || upper.hasSuffix("PR") || upper.hasSuffix("PS") ||
           upper.contains("PL") || upper.contains("PR") || upper.contains("PS") { return .pass }

        return .unknown
    }
}

public struct AuthenticPlaybook: Codable, Equatable { // Made public
    public let kind: PRFBookKind
    public let sourceDirectory: URL
    public let plays: [AuthenticPlayDefinition]

    public var bankCounts: [PRFBank: Int] {
        Dictionary(grouping: plays, by: { $0.reference.bank }).mapValues(\.count)
    }

    public var pageCounts: [String: Int] {
        Dictionary(grouping: plays) { play in
            "b\(play.reference.bank.rawValue)-p\(play.reference.page)"
        }.mapValues(\.count)
    }

    public func plays(bank: PRFBank, page: UInt16) -> [AuthenticPlayDefinition] {
        plays.filter { $0.reference.bank == bank && $0.reference.page == page }
    }

    public func sortedByVirtualOffset(bank: PRFBank, page: UInt16) -> [AuthenticPlayDefinition] {
        plays(bank: bank, page: page).sorted { lhs, rhs in
            if lhs.reference.virtualOffset == rhs.reference.virtualOffset {
                return lhs.index < rhs.index
            }
            return lhs.reference.virtualOffset < rhs.reference.virtualOffset
        }
    }
}

public struct AuthenticPlaybookLoader { // Made public

    public static func load(from directory: URL, kind: PRFBookKind) throws -> AuthenticPlaybook { // Added throws
        let plnURL = directory.appendingPathComponent(kind.plnFileName)
        let firstPRFURL = directory.appendingPathComponent(kind.firstPRFFileName)
        let secondPRFURL = directory.appendingPathComponent(kind.secondPRFFileName)

        let pln = try PRFDecoder.decodePLN(at: plnURL)
        let firstBank = try PRFDecoder.decodePRF(at: firstPRFURL)
        let secondBank = try PRFDecoder.decodePRF(at: secondPRFURL)

        var plays: [AuthenticPlayDefinition] = []
        plays.reserveCapacity(pln.entries.count)

        for entry in pln.entries {
            let bank = AuthenticPlaybookLoader.resolveBank(forRawOffset: entry.prfOffset) // Use static self
            let page = Int(entry.prfPage)

            guard page >= 0 && page < PRFDecoder.prfPlaysPerBank else {
                throw PRFDecoderError.invalidOffset(url: plnURL, offset: page, length: PRFDecoder.prfPlaysPerBank)
            }

            let grid = bank == .first ? firstBank.playGrids[page] : secondBank.playGrids[page]

            let reference = AuthenticPlayReference(
                bank: bank,
                page: entry.prfPage,
                rawOffset: entry.prfOffset,
                virtualOffset: AuthenticPlaybookLoader.normalizedVirtualOffset(from: entry.prfOffset), // Use static self
                size: entry.size
            )

            let pageSignature = AuthenticPlaybookLoader.pageFingerprint(for: grid) // Use static self
            let formationName = PRFDecoder.decodeFormation(
                formationCode: entry.formationCode,
                mirrorCode: entry.formationMirrorCode
            )

            plays.append(
                AuthenticPlayDefinition(
                    id: UUID(),
                    index: entry.index,
                    name: entry.name,
                    formationCode: entry.formationCode,
                    formationMirrorCode: entry.formationMirrorCode,
                    formationName: formationName,
                    sourcePLNOffset: entry.byteOffset,
                    reference: reference,
                    isSpecialTeams: AuthenticPlaybookLoader.isSpecialTeamsEntry(name: entry.name, formationCode: entry.formationCode, mirrorCode: entry.formationMirrorCode), // Use static self
                    pageSignature: pageSignature
                )
            )
        }

        return AuthenticPlaybook(kind: kind, sourceDirectory: directory, plays: plays)
    }

    public static func resolveBank(forRawOffset rawOffset: UInt16) -> PRFBank { // Made public
        // Reverse-engineered pointer model:
        // - High bit set => second PRF bank (OFF2/DEF2)
        // - High bit clear => first PRF bank (OFF1/DEF1)
        (rawOffset & 0x8000) == 0 ? .first : .second
    }

    public static func normalizedVirtualOffset(from rawOffset: UInt16) -> UInt16 { // Made public
        rawOffset & 0x7FFF
    }

    private static func isSpecialTeamsEntry(name: String, formationCode: UInt16, mirrorCode: UInt16) -> Bool {
        if formationCode <= 0x0100 || mirrorCode <= 0x010C {
            return true
        }

        let upper = name.uppercased()
        let keywords = ["FG", "PAT", "KICK", "PUNT", "ONSID", "FREE", "SQUIB", "RET"]
        return keywords.contains { upper.contains($0) }
    }

    private static func pageFingerprint(for grid: PRFPlayGrid) -> String {
        var hasher = Hasher()
        hasher.combine(grid.playIndex)

        for row in grid.rows {
            for cell in row {
                hasher.combine(cell.byte0)
                hasher.combine(cell.byte1)
                hasher.combine(cell.byte2)
                hasher.combine(cell.byte3)
                hasher.combine(cell.byte4)
                hasher.combine(cell.byte5)
            }
        }

        return String(hasher.finalize(), radix: 16, uppercase: false)
    }
}