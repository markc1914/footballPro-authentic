import Foundation
import Testing
@testable import footballPro

@Suite("SCR Decoder Tests")
struct SCRDecoderTests {

    @Test("GAMINTRO.SCR decodes with expected dimensions")
    func decodeGAMINTRO() throws {
        guard let image = SCRDecoder.load(named: "GAMINTRO.SCR") else {
            Issue.record("Missing GAMINTRO.SCR")
            return
        }
        #expect(image.width == 320)
        #expect(image.height == 200)
        #expect(image.pixels.count == image.width * image.height)
        #expect(Set(image.pixels).count > 16) // ensure data variance
    }

    @Test("CHAMP.SCR decodes")
    func decodeChamp() throws {
        guard let image = SCRDecoder.load(named: "CHAMP.SCR") else {
            Issue.record("Missing CHAMP.SCR")
            return
        }
        #expect(image.pixels.count == image.width * image.height)
        #expect(image.width > 0 && image.height > 0)
    }

    @Test("Palette conversion builds CGImage")
    func paletteConversion() throws {
        guard let image = SCRDecoder.load(named: "GAMINTRO.SCR") else {
            Issue.record("Missing GAMINTRO.SCR")
            return
        }
        guard let palette = PALDecoder.loadPalette(named: "GAMINTRO.PAL") else {
            Issue.record("Missing GAMINTRO.PAL")
            return
        }
        let cg = image.cgImage(palette: palette)
        #expect(cg != nil)
        #expect(cg?.width == image.width)
        #expect(cg?.height == image.height)
    }
}
