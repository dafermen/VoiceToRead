#if compiler(>=6.2)
import XCTest
import AVFoundation
import CoreMedia
@testable import VoiceToRead

final class AudioConversionTests: XCTestCase {
    func testSampleRateConversionProducesAnalyzerCompatibleInput() async throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Requires the modern iOS 26 speech engine") }
        let sourceFormat = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
        let targetFormat = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: 4800))
        buffer.frameLength = 4800
        let samples = try XCTUnwrap(buffer.floatChannelData)
        for frame in 0..<4800 { samples[0][frame] = sin(Float(frame) * 0.05) }
        let conversion = AudioConversion(target: targetFormat)
        let converted = try await conversion.convert(CapturedAudio(buffer: buffer))
        let input = try XCTUnwrap(converted)
        XCTAssertEqual(input.bufferFormat.sampleRate, 16000)
        XCTAssertEqual(CMTimeGetSeconds(input.bufferDuration), 0.1, accuracy: 0.03)
        _ = try await conversion.flush()
    }
}
#endif
