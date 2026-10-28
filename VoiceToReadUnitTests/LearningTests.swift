import XCTest
import SwiftData
import AVFoundation
@testable import VoiceToRead

@MainActor final class LearningTests: XCTestCase {
    func testSpokenTrainingWordsRespectUTF16AndRejectInvalidRanges() {
        var progress = TrainingSpokenWordProgress()
        let token = UUID()
        let text = "Hola 👋 mundo. 日本語"
        progress.begin(text: text, token: token)
        let word = (text as NSString).range(of: "mundo")
        progress.receive(word, token: token)
        XCTAssertEqual(progress.range, word)
        for invalid in [NSRange(location: NSNotFound, length: 1), NSRange(location: -1, length: 2),
                        NSRange(location: 0, length: 0), NSRange(location: 0, length: Int.max),
                        NSRange(location: text.utf16.count, length: 1), NSRange(location: 5, length: 1)] {
            progress.receive(invalid, token: token)
            XCTAssertEqual(progress.range, word, "Invalid or partial-surrogate ranges cannot change the highlighted word")
        }
        let japanese = (text as NSString).range(of: "日本語")
        progress.receive(japanese, token: token)
        XCTAssertEqual(progress.range, japanese)
    }

    func testSpokenTrainingWordTokensIgnoreStoppedAndPreviousExamples() {
        var progress = TrainingSpokenWordProgress()
        let first = UUID(), next = UUID()
        progress.begin(text: "go go", token: first)
        progress.receive(NSRange(location: 3, length: 2), token: first)
        XCTAssertEqual(progress.range?.location, 3, "Repeated words must follow the spoken offset")
        progress.reset()
        progress.receive(NSRange(location: 0, length: 2), token: first)
        XCTAssertNil(progress.range)
        XCTAssertTrue(progress.text.isEmpty)
        progress.begin(text: "Hola", token: next)
        progress.receive(NSRange(location: 0, length: 2), token: first)
        XCTAssertNil(progress.range)
        progress.receive(NSRange(location: 0, length: 4), token: next)
        XCTAssertEqual(progress.range?.length, 4)
        progress.reset()
        XCTAssertNil(progress.range)
    }

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
        let requested = expectation(description: "Permission request started")
        var permission: CheckedContinuation<Bool, Never>?
        let practice = PronunciationPractice(microphonePermission: {
            await withCheckedContinuation { continuation in
                permission = continuation
                requested.fulfill()
            }
        })
        let pending = Task { await practice.startRecording() }
        await fulfillment(of: [requested], timeout: 3)
        XCTAssertEqual(practice.activity, .permission)
        practice.close()
        permission?.resume(returning: true)
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
        try player.load(url); player.speed = .slow
        let unit = LearningUnit(id: "test", paragraphID: UUID(), english: "Test", spanish: nil, context: "Test", start: 0, end: 0.15)
        player.play(unit); XCTAssertTrue(player.playing)
        try await Task.sleep(for: .milliseconds(650)); XCTAssertFalse(player.playing)
        player.repeating = true; player.play(unit)
        try await Task.sleep(for: .milliseconds(650)); XCTAssertTrue(player.playing)
        player.close(); XCTAssertFalse(player.playing); XCTAssertEqual(player.duration, 0)
        player.play(unit); XCTAssertFalse(player.playing)
    }
}


extension LearningTests {
    func testIndependentTrainingSeedsTwentyEverydayPracticesOnlyOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try EnglishTrainingStore(directory: directory)
        XCTAssertEqual(store.trainings.count, 20)
        XCTAssertEqual(Set(store.trainings.map(\.id)).count, 20)
        XCTAssertEqual(Set(store.trainings.map(\.title)).count, 20)
        XCTAssertTrue(store.trainings.allSatisfy { $0.valid && !$0.ready && $0.sourceLanguage == .spanish && $0.targetLanguage == .english })
        let first = try XCTUnwrap(store.trainings.first)
        XCTAssertEqual(first.title, "Presentarme y conversar")
        XCTAssertEqual(first.phrases.count, 20)
        XCTAssertEqual(first.phrases.first?.spanish, "Hola, me llamo Alex.")
        XCTAssertEqual(first.phrases.last?.spanish, "Gracias por escucharme. ¿Tienes alguna pregunta?")
        XCTAssertFalse(first.ready)
        let sibling = directory.appendingPathComponent("legacy-data.txt")
        try Data("preserve".utf8).write(to: sibling)
        let second = try EnglishTraining.edited(title: "Otro entrenamiento", text: "Buenos días.\nGracias.")
        try store.save(second)
        let reopened = try EnglishTrainingStore(directory: directory)
        XCTAssertEqual(reopened.trainings, store.trainings)
        XCTAssertEqual(reopened.trainings.count, 21)
        XCTAssertEqual(try Data(contentsOf: sibling), Data("preserve".utf8))
    }

    func testTrainingEditsKeepUnchangedCorrectionsAndIndependentDuplicates() throws {
        var old = try EnglishTraining.edited(title: "Example", text: "Hola\nHola\nAdiós")
        old.phrases[0].english = "Hello"; old.phrases[0].reviewed = true; old.phrases[0].needsPractice = false
        old.phrases[1].english = "Hi"
        let edited = try EnglishTraining.edited(title: "Renamed", text: "\nHola\nHasta luego\nHola\n", previous: old)
        XCTAssertEqual(edited.id, old.id)
        XCTAssertEqual(edited.phrases[0], old.phrases[0])
        XCTAssertEqual(edited.phrases[2], old.phrases[1])
        XCTAssertNotEqual(edited.phrases[1].id, old.phrases[2].id)
        XCTAssertTrue(edited.phrases[1].english.isEmpty)
        XCTAssertTrue(edited.phrases[1].needsPractice)
        XCTAssertFalse(edited.phrases[1].reviewed)
        XCTAssertThrowsError(try EnglishTraining.edited(title: " ", text: "Hola"))
        XCTAssertThrowsError(try EnglishTraining.edited(title: "Example", text: "\n "))
        XCTAssertThrowsError(try EnglishTraining.edited(title: "Example", text: Array(repeating: "Hola", count: 201).joined(separator: "\n")))
        XCTAssertThrowsError(try EnglishTraining.edited(title: "Example", text: String(repeating: "x", count: 1001)))
    }

    func testTrainingTranslationIsAtomicAndRejectsStaleOrOverwritingResponses() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try EnglishTrainingStore(directory: directory)
        let training = try EnglishTraining.edited(title: "Example", text: "Hola\nGracias")
        try store.save(training)
        let responses = zip(training.source, ["Hello", "Thank you"]).map { ReviewParagraph(id: $0.0.id, text: $0.1) }
        XCTAssertThrowsError(try store.acceptTranslation(training.id, source: training.source, responses: Array(responses.reversed())))
        XCTAssertEqual(store.training(training.id), training)
        try store.acceptTranslation(training.id, source: training.source, responses: responses)
        XCTAssertTrue(try XCTUnwrap(store.training(training.id)).ready)
        let translated = store.training(training.id)
        XCTAssertThrowsError(try store.acceptTranslation(training.id, source: training.source, responses: responses))
        XCTAssertEqual(store.training(training.id), translated)
        var changed = training; changed.phrases[1].spanish = "Otra frase"
        try store.save(changed)
        XCTAssertThrowsError(try store.acceptTranslation(training.id, source: training.source, responses: responses))
        XCTAssertEqual(store.training(training.id), changed, "Earlier responses must not be partly persisted")
        XCTAssertThrowsError(try store.saveEnglish(training.id, source: training.source, values: Dictionary(uniqueKeysWithValues: responses.map { ($0.id, $0.text) })))
    }

    func testTrainingCorrectionAndSelfAssessmentPersistWithoutClearingOtherProgress() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try EnglishTrainingStore(directory: directory)
        let training = try EnglishTraining.edited(title: "Example", text: "Hola\nGracias")
        try store.save(training)
        let ids = training.phrases.map(\.id)
        try store.saveEnglish(training.id, source: training.source, values: [ids[0]: "Hello", ids[1]: "Thanks"])
        for id in ids { try store.mark(training.id, phraseID: id, needsPractice: false) }
        try store.saveEnglish(training.id, source: training.source, values: [ids[0]: "Good morning", ids[1]: "Thanks"])
        let reopened = try EnglishTrainingStore(directory: directory)
        let saved = try XCTUnwrap(reopened.training(training.id))
        XCTAssertFalse(saved.phrases[0].reviewed); XCTAssertTrue(saved.phrases[0].needsPractice)
        XCTAssertTrue(saved.phrases[1].reviewed); XCTAssertFalse(saved.phrases[1].needsPractice)
        XCTAssertEqual(saved.phrases[0].english, "Good morning")
    }

    func testUnreadableTrainingFileIsNeverReplacedWithSeed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("trainings.json")
        for bytes in [Data("broken file".utf8), Data(#"{"version":99,"trainings":[]}"#.utf8)] {
            try bytes.write(to: file)
            XCTAssertThrowsError(try EnglishTrainingStore(directory: directory))
            XCTAssertEqual(try Data(contentsOf: file), bytes)
        }
    }

    func testTrainingComparisonHandlesMissingExtraAndNormalizedWords() {
        let exact = TrainingComparison.compare(expected: "Hello, WORLD!", heard: "hello world")
        XCTAssertTrue(exact.expected.allSatisfy(\.matched)); XCTAssertTrue(exact.heard.allSatisfy(\.matched))
        let missing = TrainingComparison.compare(expected: "I went to school", heard: "I went school yesterday")
        XCTAssertEqual(missing.expected.filter { !$0.matched }.map(\.text), ["to"])
        XCTAssertEqual(missing.heard.filter { !$0.matched }.map(\.text), ["yesterday"])
        XCTAssertTrue(TrainingComparison.compare(expected: "Hello", heard: "").expected.allSatisfy { !$0.matched })
        XCTAssertTrue(TrainingComparison.compare(expected: "", heard: "Hello").heard.allSatisfy { !$0.matched })
        XCTAssertTrue(TrainingComparison.compare(expected: "", heard: "").expected.isEmpty)
    }
}


extension LearningTests {
    func testTrainingRoundCountsLatestRecognizedAttemptOncePerPhrase() {
        let a = UUID(), b = UUID(), c = UUID()
        var round = EnglishTrainingRound(phraseIDs: [a, b, c])
        XCTAssertEqual(round.unattemptedCount, 3)
        round.record(phraseID: a, expected: "Hello, WORLD!", heard: "hello world")
        round.record(phraseID: b, expected: "I went to school", heard: "I went home")
        XCTAssertEqual(round.matchedCount, 1)
        XCTAssertEqual(round.differentIDs, [b])
        XCTAssertEqual(round.unattemptedCount, 1)
        round.record(phraseID: a, expected: "Hello world", heard: "Hello world")
        XCTAssertEqual(round.matchedCount, 1, "Revisiting a phrase must not inflate counts")
        round.record(phraseID: b, expected: "I went to school", heard: "I went to school.")
        XCTAssertEqual(round.matchedCount, 2)
        XCTAssertTrue(round.differentIDs.isEmpty)
        XCTAssertEqual(round.unattemptedCount, 1)
        round.record(phraseID: a, expected: "Hello world", heard: "Hello")
        XCTAssertEqual(round.matchedCount, 1)
        XCTAssertEqual(round.differentIDs, [a], "Latest valid attempt replaces the previous result")
    }

    func testTrainingRoundDoesNotTreatMissingRecognitionAsIncorrect() {
        let a = UUID(), b = UUID()
        var round = EnglishTrainingRound(phraseIDs: [a, b])
        round.record(phraseID: a, expected: "Hello", heard: "   ")
        round.record(phraseID: b, expected: "Hello", heard: "!!!")
        round.record(phraseID: UUID(), expected: "Hello", heard: "Hello")
        round.record(phraseID: a, expected: "", heard: "Hello")
        XCTAssertTrue(round.results.isEmpty)
        XCTAssertEqual(round.unattemptedCount, 2)
        XCTAssertTrue(round.differentIDs.isEmpty)
        round.record(phraseID: a, expected: "Hello", heard: "Goodbye")
        round.clearResult(for: a)
        XCTAssertTrue(round.results.isEmpty, "A fresh recorded take must not retain a stale check")
        XCTAssertEqual(round.unattemptedCount, 2)
    }

    func testTrainingReviewRoundContainsOnlyDifferencesInOriginalOrder() {
        let ids = [UUID(), UUID(), UUID(), UUID()]
        var round = EnglishTrainingRound(phraseIDs: ids)
        round.record(phraseID: ids[2], expected: "Hello", heard: "Goodbye")
        round.record(phraseID: ids[0], expected: "Hello", heard: "Goodbye")
        round.record(phraseID: ids[1], expected: "Hello", heard: "Hello")
        XCTAssertEqual(round.differentIDs, [ids[0], ids[2]])
        let review = EnglishTrainingRound(phraseIDs: round.differentIDs)
        XCTAssertEqual(review.phraseIDs, [ids[0], ids[2]])
        XCTAssertTrue(review.results.isEmpty)
        XCTAssertEqual(review.unattemptedCount, 2)
        XCTAssertEqual(review.matchedCount, 0)
    }

    func testTrainingRoundDoesNotPersistResultsOrChangeSavedPhrases() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try EnglishTrainingStore(directory: directory)
        let training = try XCTUnwrap(store.trainings.first)
        let file = directory.appendingPathComponent("trainings.json")
        let before = try Data(contentsOf: file)
        var round = EnglishTrainingRound(phraseIDs: training.phrases.map(\.id))
        round.record(phraseID: training.phrases[0].id, expected: "Hello", heard: "Hello")
        round.record(phraseID: training.phrases[1].id, expected: "Hello", heard: "Goodbye")
        XCTAssertEqual(round.matchedCount, 1)
        XCTAssertEqual(round.differentIDs.count, 1)
        XCTAssertEqual(try Data(contentsOf: file), before)
        XCTAssertEqual(try EnglishTrainingStore(directory: directory).trainings, store.trainings)
    }
}


extension LearningTests {
    func testLegacyTrainingArchiveDefaultsLanguagesAndBacksUpBeforeAddingExamples() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var original = try EnglishTraining.edited(title: "Existing training", text: "Hola\nGracias")
        original.phrases[0].english = "My corrected greeting"
        original.phrases[0].reviewed = true; original.phrases[0].needsPractice = false
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        legacy.removeValue(forKey: "sourceLanguage"); legacy.removeValue(forKey: "targetLanguage")
        let bytes = try JSONSerialization.data(withJSONObject: ["version": 1, "trainings": [legacy]])
        let file = directory.appendingPathComponent("trainings.json")
        try bytes.write(to: file)
        let store = try EnglishTrainingStore(directory: directory)
        let saved = try XCTUnwrap(store.training(original.id))
        XCTAssertEqual(saved, original)
        XCTAssertEqual(saved.sourceLanguage, .spanish); XCTAssertEqual(saved.targetLanguage, .english)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("trainings-before-samples-v2.json")), bytes)
        XCTAssertEqual(store.trainings.count, 21)
        try store.save(EnglishTraining.edited(title: "French", text: "Hello", sourceLanguage: .english, targetLanguage: .french))
        let reopened = try EnglishTrainingStore(directory: directory)
        XCTAssertEqual(reopened.training(original.id), original)
        XCTAssertEqual(reopened.trainings.count, 22)
        let archive = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertEqual(archive["version"] as? Int, 2)
    }

    func testTrainingSupportsEveryDistinctCurrentLanguagePairAndRejectsIdenticalLanguages() throws {
        var pairs = 0
        for source in CaptureLanguage.allCases {
            for target in CaptureLanguage.allCases {
                if source == target {
                    XCTAssertThrowsError(try EnglishTraining.edited(title: "Invalid", text: source.greeting, sourceLanguage: source, targetLanguage: target))
                } else {
                    let training = try EnglishTraining.edited(title: "Pair", text: source.greeting, sourceLanguage: source, targetLanguage: target)
                    XCTAssertTrue(training.valid)
                    let decoded = try JSONDecoder().decode(EnglishTraining.self, from: JSONEncoder().encode(training))
                    XCTAssertEqual(decoded.sourceLanguage, source); XCTAssertEqual(decoded.targetLanguage, target)
                    XCTAssertEqual(decoded.phrases, training.phrases)
                    pairs += 1
                }
            }
        }
        XCTAssertEqual(pairs, 30)
    }

    func testTrainingLanguageChangesInvalidateOnlyTranslationsAndPreserveSourceIDs() throws {
        var old = try EnglishTraining.edited(title: "Example", text: "Hola\nGracias")
        old.phrases[0].english = "Corrected hello"; old.phrases[1].english = "Thanks"
        let unchanged = try EnglishTraining.edited(title: "Renamed", text: "Hola\nGracias", previous: old)
        XCTAssertEqual(unchanged.phrases, old.phrases)
        for (source, target) in [(CaptureLanguage.french, CaptureLanguage.english), (.spanish, .japanese), (.chinese, .korean)] {
            let changed = try EnglishTraining.edited(title: "New pair", text: "Hola\nGracias", previous: old, sourceLanguage: source, targetLanguage: target)
            XCTAssertEqual(changed.phrases.map(\.id), old.phrases.map(\.id))
            XCTAssertEqual(changed.source, old.source)
            XCTAssertTrue(changed.phrases.allSatisfy { $0.english.isEmpty })
            XCTAssertFalse(changed.ready)
            XCTAssertEqual(changed.sourceLanguage, source); XCTAssertEqual(changed.targetLanguage, target)
            XCTAssertEqual(old.phrases[0].english, "Corrected hello", "Building an edit must not mutate saved data before confirmation")
        }
    }

    func testTrainingRetranslationKeepsCorrectionsUntilCompleteAndRejectsStaleSnapshots() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try EnglishTrainingStore(directory: directory)
        var training = try EnglishTraining.edited(title: "French", text: "Hello\nThanks", sourceLanguage: .english, targetLanguage: .french)
        training.phrases[0].english = "Bonjour corrigé"; training.phrases[1].english = "Merci corrigé"
        try store.save(training)
        let responses = zip(training.source, ["Bonjour", "Merci"]).map { ReviewParagraph(id: $0.0.id, text: $0.1) }
        let file = directory.appendingPathComponent("trainings.json")
        let bytes = try Data(contentsOf: file)
        XCTAssertThrowsError(try store.acceptTranslation(training.id, source: training.source, responses: Array(responses.prefix(1)), language: .english, targetLanguage: .french, replacing: training))
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        XCTAssertThrowsError(try store.acceptTranslation(training.id, source: training.source, responses: responses, language: .english, targetLanguage: .japanese, replacing: training))
        XCTAssertEqual(store.training(training.id), training)
        let edits = Dictionary(uniqueKeysWithValues: zip(training.phrases.map(\.id), ["Salut", "Merci"]))
        try store.saveEnglish(training.id, source: training.source, values: edits, language: .english, targetLanguage: .french)
        let updated = try XCTUnwrap(store.training(training.id))
        XCTAssertThrowsError(try store.acceptTranslation(training.id, source: training.source, responses: responses, language: .english, targetLanguage: .french, replacing: training))
        XCTAssertEqual(store.training(training.id), updated)
        try store.acceptTranslation(training.id, source: updated.source, responses: responses, language: .english, targetLanguage: .french, replacing: updated)
        XCTAssertEqual(store.training(training.id)?.phrases.map(\.english), ["Bonjour", "Merci"])
        XCTAssertEqual(try EnglishTrainingStore(directory: directory).training(training.id)?.targetLanguage, .french)
    }

    func testTrainingMissingTranslationsAndManualEditsRequireMatchingLanguages() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try EnglishTrainingStore(directory: directory)
        let training = try EnglishTraining.edited(title: "Japanese", text: "Hello", sourceLanguage: .english, targetLanguage: .japanese)
        try store.save(training)
        let response = ReviewParagraph(id: training.phrases[0].id, text: "こんにちは")
        XCTAssertThrowsError(try store.acceptTranslation(training.id, source: training.source, responses: [response]))
        XCTAssertThrowsError(try store.saveEnglish(training.id, source: training.source, values: [response.id: response.text]))
        try store.acceptTranslation(training.id, source: training.source, responses: [response], language: .english, targetLanguage: .japanese)
        XCTAssertEqual(store.training(training.id)?.phrases[0].english, "こんにちは")
    }

    func testTrainingComparisonPreservesUnspacedScriptAndMarksCharacterDifferences() {
        let japanese = TrainingComparison.compare(expected: "私は学校へ行きます。", heard: "私は学校に行きます")
        XCTAssertEqual(japanese.expected.filter { !$0.matched }.map(\.text), ["へ"])
        XCTAssertEqual(japanese.heard.filter { !$0.matched }.map(\.text), ["に"])
        XCTAssertTrue(japanese.expected.allSatisfy { $0.separator.isEmpty })
        XCTAssertEqual(japanese.expected.map(\.text).joined(), "私は学校へ行きます。")
        let chinese = TrainingComparison.compare(expected: "我喜欢 apple。", heard: "我喜欢 apple")
        XCTAssertTrue(chinese.expected.allSatisfy(\.matched))
        XCTAssertTrue(chinese.heard.allSatisfy(\.matched))
        XCTAssertTrue(PracticeRecognition.matches("你好", target: "你好。"))
    }
}


extension LearningTests {
    func testRetiredStoryPracticeIsRemovedFromListAndPreservedInBackup() throws {
        struct LegacyArchive: Codable { var version = 2; var trainings: [EnglishTraining] }
        for edited in [false, true] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var old = try EnglishTraining.edited(title: "Los tres cerditos", text: EnglishTraining.firstText)
            if edited {
                old.phrases[0].english = "My correction"
                old.phrases[0].reviewed = true
                old.phrases[0].needsPractice = false
            }
            let file = directory.appendingPathComponent("trainings.json")
            try JSONEncoder().encode(LegacyArchive(trainings: [old])).write(to: file)
            let store = try EnglishTrainingStore(directory: directory)
            XCTAssertTrue(store.trainings.contains { $0.title == EnglishTraining.sampleTitle })
            XCTAssertEqual(store.trainings.count, 20)
            XCTAssertFalse(store.trainings.contains { $0.title == "Los tres cerditos" })
            XCTAssertEqual(store.training(old.id)?.title, EnglishTraining.sampleTitle)
            let backup = try JSONDecoder().decode(LegacyArchive.self, from: Data(contentsOf: directory.appendingPathComponent("trainings-before-samples-v2.json")))
            XCTAssertEqual(backup.trainings, [old], "Retired example corrections remain recoverable")
            XCTAssertEqual(try EnglishTrainingStore(directory: directory).trainings, store.trainings)
        }
    }
}

extension LearningTests {
    func testSampleExpansionKeepsExistingPracticeAndDoesNotReinsertRemovedSample() throws {
        struct OldArchive: Codable { var version = 2; var trainings: [EnglishTraining]; var sampleRevision = 1 }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var custom = try EnglishTraining.edited(title: EnglishTraining.sampleTitle, text: "Mi frase personalizada")
        custom.phrases[0].english = "My custom phrase"; custom.phrases[0].reviewed = true
        let file = directory.appendingPathComponent("trainings.json")
        try JSONEncoder().encode(OldArchive(trainings: [custom])).write(to: file)
        let store = try EnglishTrainingStore(directory: directory)
        XCTAssertEqual(store.trainings.count, 20)
        XCTAssertEqual(store.training(custom.id), custom)
        XCTAssertEqual(store.trainings.filter { $0.title == custom.title }.count, 1)
        var archive = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        var practices = try XCTUnwrap(archive["trainings"] as? [[String: Any]])
        practices.removeLast(); archive["trainings"] = practices
        try JSONSerialization.data(withJSONObject: archive).write(to: file)
        let reopened = try EnglishTrainingStore(directory: directory)
        XCTAssertEqual(reopened.trainings.count, 19, "Completed sample migration is not repeated")
        XCTAssertEqual(reopened.training(custom.id), custom)
    }
}
