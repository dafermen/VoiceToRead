import XCTest
import SwiftData
import AVFoundation
@testable import VoiceToRead

@MainActor final class LearningTests: XCTestCase {
    func testPracticeRecognitionMatchesWordsNotSubstringsOrEmptyAudio() {
        XCTAssertTrue(PracticeRecognition.matches("Hello, WORLD!", target: "hello world"))
        XCTAssertTrue(PracticeRecognition.matches("I’m here.", target: "I'm here"))
        XCTAssertFalse(PracticeRecognition.matches("", target: ""))
        XCTAssertFalse(PracticeRecognition.matches("think", target: "thing"))
        XCTAssertFalse(PracticeRecognition.matches("hello", target: "hello world"))
        XCTAssertFalse(PracticeRecognition.matches("hello world again", target: "hello world"))
    }
    func testPracticeBreaksLongTextAndOffersIndividualWords() {
        let prompts = PracticeRecognition.prompts("One two three four five six seven eight nine ten.")
        XCTAssertEqual(prompts.first, "One two three four five six seven eight")
        XCTAssertTrue(prompts.contains("nine ten."))
        XCTAssertTrue(prompts.contains("ten"))
        XCTAssertEqual(PracticeRecognition.prompts("hello hello").filter { $0 == "hello" }.count, 1)
        XCTAssertTrue(PracticeRecognition.prompts("   ").isEmpty)
        XCTAssertTrue(prompts.allSatisfy { $0.split(separator: " ").count <= 8 })
    }
    func testPracticeRequestRequiresOfflineAndDoesNotHintExpectedAnswer() {
        let request = PracticeRecognition.request(url: URL(fileURLWithPath: "/tmp/test.wav"))
        XCTAssertTrue(request.requiresOnDeviceRecognition)
        XCTAssertFalse(request.shouldReportPartialResults)
        XCTAssertTrue(request.contextualStrings.isEmpty)
    }
    func testPracticeDirectoryIsSeparateProtectedAndExcludedFromBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = try PracticeFiles.createDirectory(in: root)
        XCTAssertEqual(directory.deletingLastPathComponent().path, root.path)
        XCTAssertEqual(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        // The macOS simulator does not expose iPhone Data Protection attributes.
        #if !targetEnvironment(simulator)
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete)
        #endif
    }
    func testPracticeCleanupDoesNotRemoveSiblingSessionFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let practiceRoot = root.appendingPathComponent("practice")
        let directory = try PracticeFiles.createDirectory(in: practiceRoot)
        let session = root.appendingPathComponent("session.caf")
        try Data([1, 2, 3]).write(to: session)
        try Data([4, 5]).write(to: directory.appendingPathComponent("attempt.wav"))
        PracticeFiles.removeAbandonedAttempts(in: practiceRoot)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertEqual(try Data(contentsOf: session), Data([1, 2, 3]))
    }
    func testPracticeDeniedPermissionLeavesListeningAvailable() async {
        let practice = PronunciationPractice(microphonePermission: { false })
        defer { practice.close() }
        await practice.startRecording()
        XCTAssertEqual(practice.activity, .idle)
        XCTAssertNil(practice.take)
        XCTAssertNotNil(practice.message)
    }
    func testPracticeLatePermissionCannotStartRecordingAfterExit() async {
        let practice = PronunciationPractice(microphonePermission: {
            try? await Task.sleep(for: .milliseconds(100))
            return true
        })
        let pending = Task { await practice.startRecording() }
        await Task.yield()
        XCTAssertEqual(practice.activity, .permission)
        practice.close()
        await pending.value
        XCTAssertEqual(practice.activity, .idle)
        XCTAssertNil(practice.take)
        XCTAssertNil(practice.heard)
    }

    func testUnitsExcludeStaleSpanishAndRetainUntimedText() {
        let paragraph = ReviewParagraph(id: UUID(), text: "Hello world")
        let translation = TranslationSnapshot(source: [paragraph], generated: [.init(id: paragraph.id, text: "Hola mundo")])
        let plain = LearningUnit.make(paragraphs: [paragraph], timings: [:], translation: translation)
        XCTAssertEqual(plain.first?.spanish, "Hola mundo")
        XCTAssertNil(plain.first?.audioRange(duration: 10))
        let changed = ReviewParagraph(id: paragraph.id, text: "Different English")
        XCTAssertNil(LearningUnit.make(paragraphs: [changed], timings: [:], translation: translation).first?.spanish)
        let timings = [paragraph.id.uuidString: CaptionTiming(start: 1, end: 4, words: [])]
        let timed = LearningUnit.make(paragraphs: [paragraph], timings: timings, translation: translation)
        XCTAssertEqual(timed.first?.audioRange(duration: 2), 1...2)
        XCTAssertNil(timed.first?.audioRange(duration: 0.5))
        XCTAssertNil(timed.first?.audioRange(duration: .nan))
    }
    func testExpressionsSurviveReopenAndSessionDeletionRemovesThem() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = try autoreleasepool { () throws -> UUID in
            let repository = try TranscriptRepository(directory: directory)
            let session = try repository.create(title: "Learning")
            let caption = CaptionSegment(runID: UUID(), start: 0, end: 4, text: "Hello world")
            try repository.apply(.init(removedIDs: [], upserted: [caption]), to: session)
            let unit = LearningUnit(id: "1", paragraphID: caption.id, english: caption.text, spanish: "Hola mundo",
                context: caption.text, start: 0, end: 4)
            try repository.saveLearningExpression(unit: unit, english: "Hello", spanish: "Hola", for: session)
            try repository.saveLearningExpression(unit: unit, english: "Hello", spanish: "Hola", for: session)
            XCTAssertEqual(try repository.learningExpressions(for: session.id).count, 1)
            XCTAssertThrowsError(try repository.saveLearningExpression(unit: unit, english: "unrelated", spanish: "", for: session))
            try repository.saveCorrections([.init(id: caption.id, text: "New text")], for: session)
            XCTAssertThrowsError(try repository.saveLearningExpression(unit: unit, english: "world", spanish: "", for: session))
            return session.id
        }
        let repository = try TranscriptRepository(directory: directory)
        let expression = try XCTUnwrap(repository.learningExpressions(for: id).first)
        XCTAssertEqual(expression.english, "Hello"); XCTAssertEqual(expression.context, "Hello world")
        XCTAssertEqual(expression.spanish, "Hola"); XCTAssertEqual(expression.start, 0)
        let session = try XCTUnwrap(repository.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
        try repository.delete(session)
        XCTAssertTrue(try repository.learningExpressions(for: id).isEmpty)
    }
    func testRemovingExpressionKeepsSessionAndTranslation() throws {
        let repository = try TranscriptRepository(inMemory: true)
        let session = try repository.create(title: "Study")
        let caption = CaptionSegment(runID: UUID(), start: 0, end: 4, text: "Good morning")
        try repository.apply(.init(removedIDs: [], upserted: [caption]), to: session)
        let source = try repository.reviewedParagraphs(for: session)
        let translation = TranslationSnapshot(source: source, generated: [.init(id: caption.id, text: "Buenos días")])
        try repository.saveTranslation(translation, for: session)
        let unit = try XCTUnwrap(LearningUnit.make(paragraphs: source, timings: [:], translation: translation).first)
        try repository.saveLearningExpression(unit: unit, english: "morning", spanish: "mañana", for: session)
        try repository.removeLearningExpression(XCTUnwrap(repository.learningExpressions(for: session.id).first))
        XCTAssertTrue(try repository.learningExpressions(for: session.id).isEmpty)
        XCTAssertEqual(session.fullTranscript, "Good morning")
        XCTAssertEqual(try repository.translation(for: session.id)?.decoded(), translation)
    }
    func testV6MigrationPreservesSavedTranslation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let identifier = try autoreleasepool { () throws -> UUID in
            let schema = Schema(versionedSchema: SessionSchemaV6.self)
            let config = ModelConfiguration("Sessions", schema: schema, url: directory.appendingPathComponent("Sessions.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let session = ConferenceSession(title: "Old session")
            container.mainContext.insert(session)
            let paragraph = ReviewParagraph(id: UUID(), text: "Hello")
            let snapshot = TranslationSnapshot(source: [paragraph], generated: [.init(id: paragraph.id, text: "Hola")])
            container.mainContext.insert(SessionTranslation(sessionID: session.id, payload: try JSONEncoder().encode(snapshot)))
            try container.mainContext.save()
            return session.id
        }
        let upgraded = try TranscriptRepository(directory: directory)
        XCTAssertEqual(try upgraded.translation(for: identifier)?.decoded().spanish.first?.text, "Hola")
        XCTAssertTrue(try upgraded.learningExpressions(for: identifier).isEmpty)
        XCTAssertEqual(try upgraded.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first?.title, "Old session")
    }
    func testPracticePlaybackStopsAtRangeLoopsAndCloses() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16000))
        buffer.frameLength = 16000; buffer.floatChannelData![0].initialize(repeating: 0, count: 16000)
        let recorder = SessionAudioRecorder(url: url)
        recorder.append(CapturedAudio(buffer: buffer)) { XCTFail("Recording fixture failed") }; try recorder.finish()
        let player = PracticePlayer(); defer { player.close() }
        try player.load(url); player.rate = 0.75
        let unit = LearningUnit(id: "test", paragraphID: UUID(), english: "Test", spanish: nil, context: "Test", start: 0, end: 0.15)
        player.play(unit); XCTAssertTrue(player.playing)
        try await Task.sleep(for: .milliseconds(650)); XCTAssertFalse(player.playing)
        player.repeating = true; player.play(unit)
        try await Task.sleep(for: .milliseconds(650)); XCTAssertTrue(player.playing)
        player.close(); XCTAssertFalse(player.playing); XCTAssertEqual(player.duration, 0)
        player.play(unit); XCTAssertFalse(player.playing)
    }
}
