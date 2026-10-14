import XCTest
import AVFoundation
import SwiftData
@testable import VoiceToRead

@MainActor
final class SessionMediaTests: XCTestCase {
    func testParagraphRangesRetainWholeParagraphAndClampDamagedAudio() throws {
        let a = ReviewParagraph(id: UUID(), text: String(repeating: "word ", count: 100))
        let b = ReviewParagraph(id: UUID(), text: "next")
        let c = ReviewParagraph(id: UUID(), text: "bad")
        let times = [a.id.uuidString: CaptionTiming(start: 0, end: 10, words: []),
                     b.id.uuidString: CaptionTiming(start: 10, end: 20, words: []),
                     c.id.uuidString: CaptionTiming(start: .nan, end: 50, words: [])]
        XCTAssertGreaterThan(SubtitleExport.cues(paragraphs: [a], timings: times).count, 1)
        let ranges = PlaybackParagraph.make([a, b, c], timings: times, duration: 15)
        XCTAssertEqual(ranges.map(\.id), [a.id, b.id])
        XCTAssertEqual(ranges[0].end, 10)
        XCTAssertEqual(ranges[1].end, 15)
        XCTAssertEqual(ranges[0].text, a.text)
        XCTAssertTrue(PlaybackParagraph.make([a], timings: times, duration: .nan).isEmpty)
    }

    func testBoundedPlaybackStopsRepeatsSeeksAndIgnoresOldCompletion() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32000))
        buffer.frameLength = 32000; buffer.floatChannelData?[0].initialize(repeating: 0, count: 32000)
        try autoreleasepool { try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer) }
        let player = SessionPlayer(); player.load(url)
        defer { player.stop() }
        player.select(range: 0.1...0.4); player.toggle()
        XCTAssertTrue(player.playing)
        try await Task.sleep(for: .seconds(1))
        XCTAssertFalse(player.playing)
        XCTAssertEqual(player.time, 0.4, accuracy: 0.01)
        player.toggle() // repeat starts at the chosen paragraph, not the next one
        XCTAssertTrue(player.playing)
        XCTAssertEqual(player.time, 0.1, accuracy: 0.03)
        player.select(range: 0.6...1.4); player.toggle()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(player.playing, "An old completion must not stop the newly selected paragraph")
        player.pause(); let paused = player.time
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(player.time, paused)
        player.seek(10)
        XCTAssertEqual(player.time, 1.4)
        player.seek(-10)
        XCTAssertEqual(player.time, 0.6)
        player.select(range: nil)
        player.play(from: 1.8)
        try await Task.sleep(for: .seconds(1))
        XCTAssertFalse(player.playing)
        XCTAssertEqual(player.time, 2, accuracy: 0.01)
    }

    func testAudioPauseAppendsWithoutGapsAndM4AExportDecodes() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("test.caf")
        let writer = SessionAudioRecorder(url: source)
        let clock = CaptureTimeline()
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16000))
        buffer.frameLength = 16000
        for index in 0..<16000 { buffer.floatChannelData?[0][index] = Float(sin(Double(index) * 0.17)) * 0.2 }
        XCTAssertEqual(clock.stamp(frames: buffer.frameLength, sampleRate: 16000), 0)
        writer.append(CapturedAudio(buffer: buffer)) { XCTFail("Recording unexpectedly failed") }
        try writer.flush() // pause drains the queue, but leaves the file open
        XCTAssertEqual(clock.stamp(frames: buffer.frameLength, sampleRate: 16000), 1)
        writer.append(CapturedAudio(buffer: buffer)) { XCTFail("Recording unexpectedly failed") }
        try writer.finish()
        XCTAssertEqual(clock.duration, 2, accuracy: 0.0001)
        let player = SessionPlayer()
        player.load(source)
        player.play(from: 0.5)
        XCTAssertTrue(player.playing)
        XCTAssertEqual(player.time, 0.5, accuracy: 0.1)
        player.play(from: 1)
        XCTAssertTrue(player.playing, "Selecting another phrase must not toggle playback off")
        player.pause()
        XCTAssertFalse(player.playing)
        let stoppedTime = player.time
        player.seek(.nan)
        player.play(from: 999)
        XCTAssertEqual(player.time, stoppedTime)
        XCTAssertFalse(player.playing)
        player.stop()
        let decoded = try AVAudioFile(forReading: source)
        XCTAssertEqual(decoded.length, 32000)
        let destination = folder.appendingPathComponent("test.m4a")
        try await RecordingExport.m4a(from: source, to: destination)
        let compressed = try AVAudioFile(forReading: destination)
        XCTAssertEqual(Double(compressed.length) / compressed.processingFormat.sampleRate, 2, accuracy: 0.15)
        XCTAssertGreaterThan(try Data(contentsOf: destination).count, 100)
        clock.reset()
        XCTAssertEqual(clock.duration, 0)
    }

    func testRecordingFailureKeepsSavedPrefixAndRefusesMoreAudio() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: source) }
        let writer = SessionAudioRecorder(url: source)
        func buffer(rate: Double) throws -> AVAudioPCMBuffer {
            let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
            let result = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 160))
            result.frameLength = 160
            result.floatChannelData?[0].initialize(repeating: 0, count: 160)
            return result
        }
        writer.append(CapturedAudio(buffer: try buffer(rate: 16000))) { XCTFail("First buffer must succeed") }
        try writer.flush()
        writer.append(CapturedAudio(buffer: try buffer(rate: 48000))) {}
        XCTAssertThrowsError(try writer.flush())
        XCTAssertThrowsError(try writer.finish())
        XCTAssertEqual(try AVAudioFile(forReading: source).length, 160)
    }

    func testSRTAndVTTCarryTimestampsEscapeTextAndHonorSilence() {
        let id = UUID()
        let paragraph = ReviewParagraph(id: id, text: "Hello & <world> later")
        let timing = CaptionTiming(start: 0, end: 10, words: [
            TimedWord(text: "Hello", start: 1.1, end: 1.5),
            TimedWord(text: "&", start: 1.5, end: 1.6),
            TimedWord(text: "<world>", start: 1.6, end: 2),
            TimedWord(text: "later", start: 8, end: 9)
        ])
        let cues = SubtitleExport.cues(paragraphs: [paragraph], timings: [id.uuidString: timing])
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues.first?.start, 1.1)
        XCTAssertEqual(cues.last?.start, 8)
        let srt = SubtitleExport.render(cues, format: .srt)
        XCTAssertTrue(srt.contains("00:00:01,100 --> 00:00:02,000"))
        XCTAssertTrue(srt.contains("Hello &amp; &lt;world&gt;"))
        XCTAssertTrue(SubtitleExport.render(cues, format: .vtt).hasPrefix("WEBVTT\n\n1\n00:00:01.100"))
        XCTAssertEqual(SubtitleExport.timestamp(3599.9996, format: .srt), "01:00:00,000")
    }

    func testCorrectedSubtitlesUseSavedRangeAndOldSessionsHaveNoInventedTiming() {
        let id = UUID()
        let paragraphs = [ReviewParagraph(id: id, text: "Corrected words are exported.")]
        XCTAssertTrue(SubtitleExport.cues(paragraphs: paragraphs, timings: [:]).isEmpty)
        let cues = SubtitleExport.cues(paragraphs: paragraphs, timings: [id.uuidString: CaptionTiming(start: 12, end: 16, words: [])])
        XCTAssertEqual(cues.first?.start, 12)
        XCTAssertEqual(cues.last?.end, 16)
        XCTAssertEqual(cues.map(\.text).joined(separator: " "), "Corrected words are exported.")
        XCTAssertTrue(SubtitleExport.cues(paragraphs: [ReviewParagraph(id: id, text: "")], timings: [id.uuidString: CaptionTiming(start: 12, end: 16, words: [])]).isEmpty)
    }

    func testRecordingDeletionKeepsCorrectedTextAndSubtitles() throws {
        let repository = try TranscriptRepository(inMemory: true)
        let session = try repository.create(title: "Media")
        let segment = CaptionSegment(runID: UUID(), start: 1, end: 3, text: "Original", sessionTime: true)
        try repository.apply(.init(removedIDs: [], upserted: [segment]), to: session)
        try repository.saveCorrections([ReviewParagraph(id: segment.id, text: "Corrected")], for: session)
        let url = try repository.prepareRecording(for: session)
        try Data("fixture".utf8).write(to: url)
        try repository.deleteAudio(for: session.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNil(try repository.audioURL(for: session.id))
        XCTAssertEqual(try repository.media(for: session.id)?.decodedTimings()[segment.id.uuidString]?.start, 1)
        XCTAssertEqual(session.fullTranscript, "Original")
        XCTAssertEqual(try repository.review(for: session.id)?.decodedCorrections()[segment.id.uuidString], "Corrected")
        let secondURL = try repository.prepareRecording(for: session)
        try Data("fixture".utf8).write(to: secondURL)
        try repository.delete(session)
        XCTAssertFalse(FileManager.default.fileExists(atPath: secondURL.path))
        XCTAssertNil(try repository.media(for: session.id))
    }

    func testV3MigrationPreservesEditsAndDoesNotInventMedia() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MediaMigration-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = try autoreleasepool { () throws -> UUID in
            let schema = Schema(versionedSchema: SessionSchemaV3.self)
            let config = ModelConfiguration("Sessions", schema: schema, url: directory.appendingPathComponent("Sessions.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let session = ConferenceSession(title: "Existing")
            let review = SessionReview(sessionID: session.id)
            review.corrections = try JSONEncoder().encode(["keep": "My correction"])
            container.mainContext.insert(session)
            container.mainContext.insert(review)
            try container.mainContext.save()
            return session.id
        }
        let repository = try TranscriptRepository(directory: directory)
        XCTAssertEqual(try repository.review(for: id)?.decodedCorrections()["keep"], "My correction")
        XCTAssertNil(try repository.media(for: id))
    }
}
