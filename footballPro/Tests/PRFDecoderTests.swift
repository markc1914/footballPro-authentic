//
//  PRFDecoderTests.swift
//  footballProTests
//

import Foundation
import Testing
@testable import footballPro

@Suite("PRF/PLN Decoder Tests")
struct PRFDecoderTests {

    @Test("PRF decoder parses OFF1.PRF grid shape")
    func testDecodePRFGridShape() throws {
        let url = originalDataURL().appendingPathComponent("OFF1.PRF")
        let decoded = try PRFDecoder.decodePRF(at: url)

        #expect(decoded.headerMagic == "F93:")
        #expect(decoded.playGrids.count == PRFDecoder.prfPlaysPerBank)
        #expect(decoded.uniformGroupCount >= 0)

        for play in decoded.playGrids {
            #expect(play.rows.count == PRFDecoder.prfRows)
            #expect(play.rows.allSatisfy { $0.count == PRFDecoder.prfColumns })
            #expect(play.phases.count == 5)
        }
    }

    @Test("PLN decoder parses OFF.PLN entries and offsets")
    func testDecodePLNEntries() throws {
        let url = originalDataURL().appendingPathComponent("OFF.PLN")
        let decoded = try PRFDecoder.decodePLN(at: url)

        #expect(decoded.headerMagic == "G93:")
        #expect(decoded.offsetTable.count == PRFDecoder.plnOffsetSlots)
        #expect(decoded.entries.count == 76)
        #expect(decoded.activeOffsetSlots == 76)
        #expect(decoded.entries.first?.name.isEmpty == false)
    }

    @Test("Action and formation decoding uses expected labels")
    func testActionAndFormationLabeling() {
        #expect(PRFDecoder.decodeAction(0x19) == "DEEP")
        #expect(PRFDecoder.decodeAction(0xFF) == "ACT_FF")

        #expect(PRFDecoder.decodeFormation(formationCode: 0x8501, mirrorCode: 0x8500) == "I-Form (m:0x8500)")
        #expect(PRFDecoder.decodeFormation(formationCode: 0x0100, mirrorCode: 0x0102) == "ST: Kickoff")
    }

    private func originalDataURL() -> URL {
        // Tests/PRFDecoderTests.swift -> package root -> FBPRO_ORIGINAL
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FBPRO_ORIGINAL", isDirectory: true)
    }
}
