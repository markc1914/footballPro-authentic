//
//  AuthenticPlaybookLoaderTests.swift
//  footballProTests
//

import Foundation
import Testing
@testable import footballPro

@Suite("Authentic Playbook Loader Tests")
struct AuthenticPlaybookLoaderTests {

    @Test("OFF playbook resolves banks/pages and preserves known counts")
    func testOffenseBookLoad() throws {
        let book = try AuthenticPlaybookLoader.load(from: originalDataURL(), kind: .offense)

        #expect(book.plays.count == 76)

        let bankCounts = book.bankCounts
        #expect(bankCounts[.first] == 39)
        #expect(bankCounts[.second] == 37)

        // Known special teams signature in OFF.PLN
        let fg = book.plays.first(where: { $0.name == "FGPAT" })
        #expect(fg != nil)
        #expect(fg?.isSpecialTeams == true)
        #expect(fg?.reference.bank == .first)
        #expect(fg?.reference.page == 6)

        // Ensure every resolved page is valid
        #expect(book.plays.allSatisfy { Int($0.reference.page) >= 0 && Int($0.reference.page) < PRFDecoder.prfPlaysPerBank })
    }

    @Test("DEF playbook resolves banks/pages and preserves known counts")
    func testDefenseBookLoad() throws {
        let book = try AuthenticPlaybookLoader.load(from: originalDataURL(), kind: .defense)

        #expect(book.plays.count == 74)

        let bankCounts = book.bankCounts
        #expect(bankCounts[.first] == 51)
        #expect(bankCounts[.second] == 23)

        let kickRet = book.plays.first(where: { $0.name == "KICKRET" })
        #expect(kickRet != nil)
        #expect(kickRet?.isSpecialTeams == true)
        #expect(kickRet?.reference.page == 6)
    }

    @Test("Bank resolution follows offset high-bit model")
    func testBankResolution() {
        #expect(AuthenticPlaybookLoader.resolveBank(forRawOffset: 0x7FFF) == .first)
        #expect(AuthenticPlaybookLoader.resolveBank(forRawOffset: 0x8000) == .second)
        #expect(AuthenticPlaybookLoader.resolveBank(forRawOffset: 0xFAAA) == .second)

        #expect(AuthenticPlaybookLoader.normalizedVirtualOffset(from: 0x8ABC) == 0x0ABC)
        #expect(AuthenticPlaybookLoader.normalizedVirtualOffset(from: 0x1ABC) == 0x1ABC)
    }

    private func originalDataURL() -> URL {
        // Tests/AuthenticPlaybookLoaderTests.swift -> package root -> FBPRO_ORIGINAL
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FBPRO_ORIGINAL", isDirectory: true)
    }
}
