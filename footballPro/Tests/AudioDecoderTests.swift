import Foundation
import Testing
@testable import footballPro

@Suite("Audio Decoder Tests")
struct AudioDecoderTests {

    @Test("SAMPLE.DAT decodes and has samples")
    func decodeSampleBank() throws {
        guard let bank = SampleDecoder.loadDefault() else {
            Issue.record("Missing SAMPLE.DAT")
            return
        }
        #expect(!bank.samples.isEmpty)
        #expect(bank.samples.first?.length ?? 0 > 0)
    }

    @Test("Offsets are increasing and within file bounds")
    func offsetsMonotonic() throws {
        guard let url = SampleDecoder.defaultURL(),
              let bank = SampleDecoder.loadDefault(),
              let data = try? Data(contentsOf: url) else {
            Issue.record("Missing SAMPLE.DAT")
            return
        }
        var lastEnd = 0
        for sample in bank.samples {
            #expect(sample.offset >= lastEnd)
            #expect(sample.offset + sample.length <= data.count)
            lastEnd = sample.offset + sample.length
        }
    }

    @Test("SampleAudioService records playback requests")
    func audioServicePlay() throws {
        guard let bank = SampleDecoder.loadDefault(),
              let firstId = bank.samples.first?.id else {
            Issue.record("Missing SAMPLE.DAT")
            return
        }

        let service = SampleAudioService.shared
        #expect(service.hasSample(id: firstId))
        _ = service.play(id: firstId, volume: 0.0, allowOverlap: true)
        #expect(service.lastPlayedSampleId == firstId)
    }
}
