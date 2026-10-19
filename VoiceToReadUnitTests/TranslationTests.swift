import XCTest
import AVFoundation
import SwiftData
@testable import VoiceToRead

@MainActor
final class TranslationTests: XCTestCase {
    func testJapaneseAndChineseSubtitlesPreserveUnspacedTextAcrossCues() throws {
        for language in [CaptureLanguage.japanese, .chinese] {
            let text = String(repeating: language == .japanese ? "日本語の字幕を読みます。" : "我们一起阅读中文字幕。", count: 12)
            let paragraph = ReviewParagraph(id: UUID(), text: text)
            let timings = [paragraph.id.uuidString: CaptionTiming(start: 0, end: 18, words: [])]
            let cues = SubtitleExport.cues(paragraphs: [paragraph], timings: timings)
            XCTAssertGreaterThan(cues.count, 1)
            XCTAssertEqual(cues.map(\.text).joined().replacingOccurrences(of: "\n", with: ""), text)
            XCTAssertTrue(cues.allSatisfy { $0.end > $0.start && $0.text.count <= 77 })
            for pair in zip(cues, cues.dropFirst()) { XCTAssertLessThanOrEqual(pair.0.end, pair.1.start) }
            let translation = String(repeating: "你好。こんにちは。", count: 9)
            let snapshot = TranslationSnapshot(source: [paragraph], generated: [.init(id: paragraph.id, text: translation)],
                sourceLocale: language.rawValue, targetLocale: language == .japanese ? "zh-CN" : "ja-JP")
            let translated = TranslatedSubtitles.cues(snapshot: snapshot, timings: timings, mode: snapshot.target.mode)
            XCTAssertEqual(translated.map(\.text).joined(), translation)
            XCTAssertTrue(SubtitleExport.render(translated, format: .vtt).hasPrefix("WEBVTT"))
        }
        XCTAssertEqual(CaptureLanguage.chinese.code, "zh-Hans")
        XCTAssertEqual(CaptureLanguage.chinese.rawValue, "zh-CN")
        XCTAssertEqual(CaptureLanguage.japanese.code, "ja")
        XCTAssertEqual(PracticeRecognition.words("こんにちは 世界"), PracticeRecognition.words("こんにちは世界"))
    }


    func testAllLanguageDirectionsKeepTextVoiceAndExportRoles() throws {
        for sourceLanguage in CaptureLanguage.allCases {
            for target in CaptureLanguage.allCases where target != sourceLanguage {
                let source = [ReviewParagraph(id: UUID(), text: sourceLanguage.greeting)]
                let translated = [ReviewParagraph(id: source[0].id, text: target.greeting)]
                let plan = IncrementalTranslation(source: source, previous: nil, language: sourceLanguage, targetLanguage: target)
                let snapshot = try plan.merging(translated)
                XCTAssertEqual(snapshot.language, sourceLanguage)
                XCTAssertEqual(snapshot.target, target)
                XCTAssertEqual(snapshot.paragraphs(mode: sourceLanguage.mode), source)
                XCTAssertEqual(snapshot.paragraphs(mode: target.mode), translated)
                XCTAssertEqual(snapshot.fileSuffix(mode: .both), sourceLanguage.code + "-" + target.code)
                let steps = ParagraphAudioStep.make(source: source, translated: translated, language: sourceLanguage,
                    mode: .both, ranges: [], target: target)
                XCTAssertEqual(steps.map(\.language), [sourceLanguage, target])
                XCTAssertEqual(PlaybackLanguagePreference.translation.mode(source: sourceLanguage, hasTranslation: true, target: target), target.mode)
                let old = TranslationSnapshot(source: source, generated: translated, sourceLocale: sourceLanguage.rawValue,
                                              targetLocale: target.rawValue)
                let newTarget = CaptureLanguage.allCases.first { $0 != sourceLanguage && $0 != target }!
                XCTAssertEqual(IncrementalTranslation(source: source, previous: old, language: sourceLanguage,
                    targetLanguage: newTarget).pending, source, "Never reuse another destination's text")
            }
        }
    }

    func testTranslationLibraryPreservesCorrectionsAcrossDestinationsAndReopen() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let id = try autoreleasepool { () throws -> UUID in
            let repo = try TranscriptRepository(directory: folder)
            let session = try repo.create(title: "French conversation", language: .french, target: .korean)
            let segment = CaptionSegment(runID: UUID(), start: 0, end: 2, text: "Bonjour, merci.")
            try repo.apply(.init(removedIDs: [], upserted: [segment]), to: session)
            let source = try repo.reviewedParagraphs(for: session)
            var korean = try IncrementalTranslation(source: source, previous: nil, language: .french, targetLanguage: .korean)
                .merging([ReviewParagraph(id: segment.id, text: "안녕하세요. 감사합니다.")])
            korean.edits[segment.id.uuidString] = "안녕하세요. 정말 감사합니다."
            try repo.saveTranslation(korean, for: session)
            let spanish = try IncrementalTranslation(source: source, previous: nil, language: .french, targetLanguage: .spanish)
                .merging([ReviewParagraph(id: segment.id, text: "Hola, gracias.")])
            try repo.saveTranslation(spanish, for: session)
            XCTAssertEqual(try repo.translation(for: session.id)?.decoded().target, .spanish)
            try repo.activateTranslation(for: session, target: .korean)
            XCTAssertEqual(try repo.translationTarget(for: session), .korean)
            XCTAssertEqual(try repo.translation(for: session.id)?.decoded().translated.first?.text, "안녕하세요. 정말 감사합니다.")
            return session.id
        }
        let repo = try TranscriptRepository(directory: folder)
        let record = try XCTUnwrap(repo.translation(for: id))
        XCTAssertEqual(try record.library().snapshots.count, 2)
        XCTAssertEqual(try record.decoded().target, .korean)
        XCTAssertEqual(try record.decoded(target: .spanish)?.translated.first?.text, "Hola, gracias.")
        let session = try XCTUnwrap(repo.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
        try repo.delete(session)
        XCTAssertNil(try repo.languagePair(for: id))
        XCTAssertNil(try repo.translation(for: id))
    }

    func testV10MigrationAndLegacyTranslationKeepHistoricalPair() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let id = try autoreleasepool { () throws -> UUID in
            let schema = Schema(versionedSchema: SessionSchemaV10.self)
            let config = ModelConfiguration("Sessions", schema: schema, url: folder.appendingPathComponent("Sessions.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let session = ConferenceSession(title: "Legacy")
            container.mainContext.insert(session)
            let paragraph = ReviewParagraph(id: UUID(), text: "Hello")
            let payload = try JSONEncoder().encode(TranslationSnapshot(source: [paragraph], generated: [.init(id: paragraph.id, text: "Hola")]))
            container.mainContext.insert(SessionTranslation(sessionID: session.id, payload: payload))
            try container.mainContext.save()
            return session.id
        }
        let repo = try TranscriptRepository(directory: folder)
        let session = try XCTUnwrap(repo.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
        XCTAssertEqual(session.id, id)
        XCTAssertEqual(try repo.translationTarget(for: session), .spanish)
        XCTAssertEqual(try repo.translation(for: id)?.decoded().translated.first?.text, "Hola")
        XCTAssertNil(try repo.languagePair(for: id), "Migration is additive, no destructive rewriting")
    }

    func testKoreanSubtitleExportKeepsAllTextAndLegacyVocabularyIsPairScoped() throws {
        let paragraph = ReviewParagraph(id: UUID(), text: "Bonjour tout le monde")
        let korean = "안녕하세요 여러분. 만나서 반갑습니다."
        let snapshot = TranslationSnapshot(source: [paragraph], generated: [.init(id: paragraph.id, text: korean)],
            sourceLocale: "fr-FR", targetLocale: "ko-KR")
        let timing = [paragraph.id.uuidString: CaptionTiming(start: 0, end: 5, words: [])]
        let cues = TranslatedSubtitles.cues(snapshot: snapshot, timings: timing, mode: .korean)
        XCTAssertEqual(cues.map(\.text).joined(separator: " "), korean)
        XCTAssertTrue(SubtitleExport.render(cues, format: .srt).contains(korean))
        let name = UUID().uuidString; let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("hello = hola", forKey: PersonalVocabulary.key)
        XCTAssertTrue(PersonalVocabulary.saved(for: .english, target: .korean, defaults: defaults).isEmpty)
        XCTAssertTrue(PersonalVocabulary.saved(for: .french, target: .spanish, defaults: defaults).isEmpty)
        XCTAssertEqual(PersonalVocabulary.saved(for: .english, target: .spanish, defaults: defaults).first?.target, "hola")
    }

    func testGapCanPauseResumeAndCancelWithoutLateSpeech() async throws {
        let original = ReviewParagraph(id: UUID(), text: "Hello")
        let output = FakeTranslationSpeechOutput()
        var continuations: [CheckedContinuation<Void, Never>] = []
        let waiting = expectation(description: "both gap attempts started"); waiting.expectedFulfillmentCount = 2
        let player = ParagraphPlayback(voice: TranslationSpeechPlayer(output: output, activate: {}, deactivate: {}), wait: { seconds in
            XCTAssertEqual(seconds, 2)
            await withCheckedContinuation { continuations.append($0); waiting.fulfill() }
        })
        let steps = ParagraphAudioStep.make(source: [original], translated: [.init(id: original.id, text: "Hola")], language: .english, mode: .both, ranges: [])
        player.start(steps, speed: .fast, originalSpeed: .slow, gapSeconds: 2)
        XCTAssertEqual(output.rates, [TranslationSpeechSpeed.slow.rate])
        output.onFinish?(try XCTUnwrap(output.tokens.last))
        XCTAssertTrue(player.waitingBetweenLanguages)
        // Yield until the deliberately suspended timer is installed; no wall-clock sleep is needed.
        while continuations.isEmpty { await Task.yield() }
        player.pause(); XCTAssertEqual(player.state, .paused)
        player.resume()
        await fulfillment(of: [waiting], timeout: 5)
        player.stop()
        continuations.forEach { $0.resume() }
        await Task.yield()
        XCTAssertEqual(output.texts, ["Hello"])
        XCTAssertEqual(player.state, .idle)
        XCTAssertFalse(player.waitingBetweenLanguages)
        player.start(steps, speed: .fast, originalSpeed: .slow)
        output.onFinish?(try XCTUnwrap(output.tokens.last))
        XCTAssertEqual(output.rates.last, TranslationSpeechSpeed.fast.rate)
        XCTAssertEqual(output.texts.last, "Hola")
        player.close()
    }

    func testGapFinishesBeforeTranslationAndNeverBetweenParagraphs() async throws {
        let a = ReviewParagraph(id: UUID(), text: "First")
        let b = ReviewParagraph(id: UUID(), text: "Second")
        let output = FakeTranslationSpeechOutput()
        let entered = expectation(description: "gap entered")
        var release: CheckedContinuation<Void, Never>?
        let player = ParagraphPlayback(voice: TranslationSpeechPlayer(output: output, activate: {}, deactivate: {}), wait: { _ in
            await withCheckedContinuation { release = $0; entered.fulfill() }
        })
        let steps = ParagraphAudioStep.make(source: [a,b], translated: [.init(id: a.id, text: "Primero")], language: .english, mode: .both, ranges: [])
        player.start(steps, speed: .normal, gapSeconds: 1)
        output.onFinish?(try XCTUnwrap(output.tokens.last))
        await fulfillment(of: [entered], timeout: 5)
        XCTAssertEqual(output.texts, ["First"])
        release?.resume()
        let spoke = expectation(description: "translation after gap")
        Task { @MainActor in
            while output.texts.count < 2 { await Task.yield() }
            spoke.fulfill()
        }
        await fulfillment(of: [spoke], timeout: 5)
        XCTAssertFalse(player.waitingBetweenLanguages)
        output.onFinish?(try XCTUnwrap(output.tokens.last))
        XCTAssertEqual(output.texts, ["First", "Primero", "Second"])
        player.close()
    }

    func testSavedPlaybackRoleAdaptsToCaptureLanguageWithoutLosingPreference() {
        let preference = PlaybackLanguagePreference(mode: .spanish, source: .english)
        XCTAssertEqual(preference, .translation)
        XCTAssertEqual(preference.mode(source: .spanish, hasTranslation: true), .english)
        XCTAssertEqual(PlaybackLanguagePreference.both.mode(source: .english, hasTranslation: false), .english)
        XCTAssertEqual(PlaybackLanguagePreference.both.mode(source: .spanish, hasTranslation: true), .both)
    }


    func testBilingualQueueFinishesBothBeforeNextAndIgnoresCancelledVoice() {
        let a = ReviewParagraph(id: UUID(), text: "First original")
        let b = ReviewParagraph(id: UUID(), text: "Second original")
        let translated = [ReviewParagraph(id: a.id, text: "Primera traducción"), ReviewParagraph(id: b.id, text: "Segunda traducción")]
        let steps = ParagraphAudioStep.make(source: [a,b], translated: translated, language: .english, mode: .both, ranges: [])
        XCTAssertEqual(steps.map(\.language), [.english,.spanish,.english,.spanish])
        let output = FakeTranslationSpeechOutput()
        let voice = TranslationSpeechPlayer(output: output, activate: {}, deactivate: {})
        let player = ParagraphPlayback(voice: voice)
        player.start(steps, speed: .normal)
        XCTAssertEqual(output.texts, [a.text]); XCTAssertFalse(player.translated)
        output.onFinish?(output.tokens.last!)
        XCTAssertEqual(output.texts.last, translated[0].text); XCTAssertTrue(player.translated)
        XCTAssertEqual(player.paragraphID, a.id)
        player.pause(); XCTAssertEqual(player.state, .paused)
        player.resume(); XCTAssertEqual(output.resumeCount, 1)
        output.onFinish?(output.tokens.last!)
        XCTAssertEqual(player.paragraphID, b.id); XCTAssertFalse(player.translated)
        let cancelled = output.tokens.last!
        player.stop(); output.onFinish?(cancelled)
        XCTAssertEqual(player.state, .idle); XCTAssertEqual(output.texts.count, 3)
        player.start(Array(steps.prefix(2)), speed: .normal)
        output.onFinish?(output.tokens.last!); output.onFinish?(output.tokens.last!)
        XCTAssertEqual(player.state, .completed); XCTAssertEqual(player.paragraphID, a.id)
        player.close()
    }

    func testRecordingCompletionHandsOffToTranslationAndStopsAtParagraph() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16000))
        buffer.frameLength = 16000; buffer.floatChannelData?[0].initialize(repeating: 0, count: 16000)
        try autoreleasepool { try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer) }
        let a = ReviewParagraph(id: UUID(), text: "Original")
        let output = FakeTranslationSpeechOutput()
        let player = ParagraphPlayback(voice: TranslationSpeechPlayer(output: output, activate: {}, deactivate: {}))
        player.load(url); defer { player.close() }
        let steps = ParagraphAudioStep.make(source: [a], translated: [ReviewParagraph(id: a.id, text: "Traducción")], language: .english,
            mode: .both, ranges: [PlaybackParagraph(id: a.id, text: a.text, start: 0.1, end: 0.3)])
        player.start(steps, speed: .normal)
        XCTAssertTrue(output.texts.isEmpty)
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(output.texts, ["Traducción"]); XCTAssertTrue(player.translated)
        output.onFinish?(try XCTUnwrap(output.tokens.last))
        XCTAssertEqual(player.state, .completed); XCTAssertEqual(player.paragraphID, a.id)
    }

    func testMissingRecordingStopsQueueWithVisibleMessage() {
        let a = ReviewParagraph(id: UUID(), text: "Original")
        let output = FakeTranslationSpeechOutput()
        let player = ParagraphPlayback(voice: TranslationSpeechPlayer(output: output, activate: {}, deactivate: {}))
        defer { player.close() }
        let steps = ParagraphAudioStep.make(source: [a], translated: [.init(id: a.id, text: "Traducción")], language: .english,
            mode: .both, ranges: [.init(id: a.id, text: a.text, start: 0, end: 1)])
        player.start(steps, speed: .normal)
        XCTAssertEqual(player.state, .idle)
        XCTAssertNotNil(player.message)
        XCTAssertTrue(output.texts.isEmpty, "Do not silently skip an unreadable original recording")
    }

    func testLanguageSelectionAndOriginalRecordingRanges() {
        let a = ReviewParagraph(id: UUID(), text: "Hola")
        let translated = [ReviewParagraph(id: a.id, text: "Hello corrected")]
        let ranges = [PlaybackParagraph(id: a.id, text: a.text, start: 1, end: 3)]
        let both = ParagraphAudioStep.make(source: [a], translated: translated, language: .spanish, mode: .both, ranges: ranges)
        XCTAssertEqual(both.map(\.language), [.spanish, .english]); XCTAssertEqual(both[0].recording, 1...3)
        XCTAssertNil(both[1].recording)
        XCTAssertEqual(ParagraphAudioStep.make(source: [a], translated: translated, language: .spanish, mode: .english, ranges: ranges).map(\.paragraph.text), ["Hello corrected"])
        XCTAssertEqual(ParagraphAudioStep.make(source: [a], translated: translated, language: .spanish, mode: .spanish, ranges: ranges).count, 1)
    }

    func testInlineQueueInterruptionNeverContinuesIntoAnotherLanguage() {
        let a = ReviewParagraph(id: UUID(), text: "Hello")
        let output = FakeTranslationSpeechOutput()
        let voice = TranslationSpeechPlayer(output: output, activate: {}, deactivate: {})
        let player = ParagraphPlayback(voice: voice)
        let steps = ParagraphAudioStep.make(source: [a], translated: [ReviewParagraph(id: a.id, text: "Hola")], language: .english, mode: .both, ranges: [])
        player.start(steps, speed: .normal); let old = output.tokens.last!
        voice.interrupt(); output.onFinish?(old)
        XCTAssertEqual(player.state, .idle); XCTAssertNotNil(player.message); XCTAssertEqual(output.texts.count, 1)
        player.close()
    }

    func testSpokenTranslationUsesCorrectedDestinationAndRejectsStaleSource() {
        let id = UUID()
        let source = [ReviewParagraph(id: id, text: "Hello")]
        let saved = TranslationSnapshot(source: source, generated: [.init(id: id, text: "Hola")], edits: [id.uuidString: "Buenos días"])
        XCTAssertEqual(TranslationSpeechPlayer.paragraphs(snapshot: saved, source: source).map(\.text), ["Buenos días"])
        XCTAssertTrue(TranslationSpeechPlayer.paragraphs(snapshot: saved, source: [.init(id: id, text: "Changed")]).isEmpty)
        XCTAssertTrue(TranslationSpeechPlayer.paragraphs(snapshot: saved, source: source, id: UUID()).isEmpty)
        let reverse = TranslationSnapshot(source: [.init(id: id, text: "Hola")], generated: source, sourceLocale: "es-ES")
        XCTAssertEqual(TranslationSpeechPlayer.paragraphs(snapshot: reverse, source: reverse.source).map(\.text), ["Hello"])
    }

    func testSpeechQueuePauseResumeReplacementAndLateCompletion() throws {
        let output = FakeTranslationSpeechOutput()
        var releases = 0
        let player = TranslationSpeechPlayer(output: output, activate: {}, deactivate: { releases += 1 })
        let a = ReviewParagraph(id: UUID(), text: "Primera frase")
        let b = ReviewParagraph(id: UUID(), text: "Segunda frase")
        player.start([a, b], language: .spanish, speed: .slow)
        let oldToken = try XCTUnwrap(output.tokens.last)
        XCTAssertEqual(player.paragraphID, a.id)
        XCTAssertEqual(output.languages, [.spanish])
        XCTAssertEqual(output.rates, [TranslationSpeechSpeed.slow.rate])
        player.togglePause(); XCTAssertEqual(player.state, .paused)
        // Completion racing Pause must not start another paragraph until Resume.
        output.onFinish?(oldToken)
        XCTAssertEqual(output.texts.count, 1)
        player.togglePause()
        XCTAssertEqual(player.state, .speaking)
        XCTAssertEqual(player.paragraphID, b.id)
        XCTAssertEqual(output.texts, [a.text, b.text])
        player.togglePause(); player.togglePause()
        XCTAssertEqual(output.resumeCount, 1)
        player.start([a], language: .english, speed: .fast)
        let newToken = try XCTUnwrap(output.tokens.last)
        output.onFinish?(oldToken)
        XCTAssertEqual(player.paragraphID, a.id, "Old utterances cannot advance a replacement queue")
        XCTAssertEqual(output.languages.last, .english)
        output.onFinish?(newToken)
        XCTAssertEqual(player.state, .idle)
        XCTAssertNil(player.paragraphID)
        XCTAssertEqual(player.completedParagraphID, a.id)
        XCTAssertEqual(releases, 2)
    }

    func testSpeechInterruptionCloseEmptyAndMissingVoiceReleaseAudio() {
        let output = FakeTranslationSpeechOutput()
        var activations = 0; var releases = 0
        let player = TranslationSpeechPlayer(output: output, activate: { activations += 1 }, deactivate: { releases += 1 })
        let paragraph = ReviewParagraph(id: UUID(), text: "Hello")
        player.start([.init(id: UUID(), text: "  ")], language: .english, speed: .normal)
        XCTAssertEqual(activations, 0)
        player.start([paragraph], language: .english, speed: .normal)
        player.interrupt()
        XCTAssertEqual(player.state, .idle); XCTAssertNotNil(player.message)
        XCTAssertEqual(releases, 1)
        player.close(); XCTAssertEqual(releases, 1, "Idle cleanup must not deactivate another audio owner")
        output.failure = TranslationSpeechFailure.voiceUnavailable
        player.start([paragraph], language: .english, speed: .normal)
        XCTAssertEqual(player.state, .idle)
        XCTAssertEqual(player.message, TranslationSpeechFailure.voiceUnavailable.localizedDescription)
        XCTAssertEqual(releases, 2)
    }

    func testAutomaticTranslationCannotSaveIntoActiveOrDeletedDraft() throws {
        let repo = try TranscriptRepository(inMemory: true)
        let session = try repo.create(title: "Draft", draft: true)
        let caption = CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Hello")
        try repo.apply(.init(removedIDs: [], upserted: [caption]), to: session)
        let snapshot = TranslationSnapshot(source: [.init(id: caption.id, text: "Hello")], generated: [.init(id: caption.id, text: "Hola")])
        XCTAssertThrowsError(try repo.saveTranslation(snapshot, for: session, allowCompletedDraft: true))
        try repo.checkpoint(session, duration: 1, ended: true)
        try repo.saveTranslation(snapshot, for: session, allowCompletedDraft: true)
        try repo.delete(session)
        XCTAssertThrowsError(try repo.saveTranslation(snapshot, for: session, allowCompletedDraft: true))
    }

    func testAutomaticResultPreservesManualTranslationCompletedMeanwhile() throws {
        let repo = try TranscriptRepository(inMemory: true)
        let session = try repo.create(title: "Manual wins")
        let caption = CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Hello")
        try repo.apply(.init(removedIDs: [], upserted: [caption]), to: session)
        try repo.checkpoint(session, duration: 1, ended: true)
        let coordinator = SessionCoordinator(repository: repo, translationSupported: { true })
        coordinator.enqueueTranslation(session)
        let job = try XCTUnwrap(coordinator.automaticTranslationJob)
        let manual = TranslationSnapshot(source: [.init(id: caption.id, text: "Hello")],
            generated: [.init(id: caption.id, text: "Hola")], edits: [caption.id.uuidString: "Buenos días"])
        try repo.saveTranslation(manual, for: session)
        coordinator.completeAutomaticTranslation(job, result: .success([.init(id: caption.id, text: "Hola")]))
        XCTAssertEqual(try repo.translation(for: session.id)?.decoded().translated.first?.text, "Buenos días")
    }

    func testOldPayloadDefaultsToEnglishAndReverseSubtitlesKeepTimes() throws {
        let id = UUID()
        let source = [ReviewParagraph(id: id, text: "Hola mundo")]
        let target = [ReviewParagraph(id: id, text: "Hello world")]
        let legacy = TranslationSnapshot(source: target, generated: source)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        json.removeValue(forKey: "sourceLocale")
        let restored = try JSONDecoder().decode(TranslationSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.language, .english)
        let reverse = TranslationSnapshot(source: source, generated: target, sourceLocale: "es-ES")
        XCTAssertEqual(reverse.paragraphs(mode: .spanish), source)
        XCTAssertEqual(reverse.paragraphs(mode: .english), target)
        XCTAssertEqual(reverse.paragraphs(mode: .both).first?.text, "Hola mundo\nHello world")
        let timings = [id.uuidString: CaptionTiming(start: 1, end: 4, words: [])]
        let original = TranslatedSubtitles.cues(snapshot: reverse, timings: timings, mode: .spanish)
        let english = TranslatedSubtitles.cues(snapshot: reverse, timings: timings, mode: .english)
        XCTAssertEqual(original.first?.text, "Hola mundo")
        XCTAssertEqual(english.first?.text, "Hello world")
        XCTAssertEqual(original.first?.start, english.first?.start)
        XCTAssertEqual(original.first?.end, english.first?.end)
        let unit = LearningUnit.make(paragraphs: source, timings: timings, translation: reverse).first
        XCTAssertEqual(unit?.english, "Hola mundo") // V7 legacy field name means source text.
        XCTAssertEqual(unit?.spanish, "Hello world")
        let plan = IncrementalTranslation(source: source, previous: reverse, language: .spanish)
        XCTAssertTrue(plan.pending.isEmpty)
        XCTAssertEqual(try plan.merging([]), reverse)
        XCTAssertEqual(IncrementalTranslation(source: source, previous: reverse).pending, source)
    }

    func testSpanishSessionPersistsLanguageAndRejectsWrongTranslationDirection() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let id = try autoreleasepool { () throws -> UUID in
            let repo = try TranscriptRepository(directory: folder)
            let session = try repo.create(title: "Español", language: .spanish)
            let caption = CaptionSegment(runID: UUID(), start: 0, end: 2, text: "Buenos días")
            try repo.apply(.init(removedIDs: [], upserted: [caption]), to: session)
            let source = try repo.reviewedParagraphs(for: session)
            let target = [ReviewParagraph(id: caption.id, text: "Good morning")]
            XCTAssertThrowsError(try repo.saveTranslation(TranslationSnapshot(source: source, generated: target), for: session))
            let reverse = TranslationSnapshot(source: source, generated: target, sourceLocale: "es-ES")
            try repo.saveTranslation(reverse, for: session)
            return session.id
        }
        let reopened = try TranscriptRepository(directory: folder)
        XCTAssertEqual(try reopened.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first?.language, "es-ES")
        XCTAssertEqual(try reopened.translation(for: id)?.decoded().english.first?.text, "Good morning")
    }

    func testVocabularyReversesSpanishHintsWithoutDuplicateSources() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("meeting = reunión\nconference = reunión\nOpenAI", forKey: PersonalVocabulary.key)
        let values = PersonalVocabulary.saved(for: .spanish, defaults: defaults)
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values.first?.source, "reunión")
        XCTAssertEqual(values.first?.target, "meeting")
    }

    func testIncrementalTranslationRetainsOnlyUnchangedEdits() throws {
        let a = ReviewParagraph(id: UUID(), text: "First")
        let b = ReviewParagraph(id: UUID(), text: "Second")
        let c = ReviewParagraph(id: UUID(), text: "Third")
        let previous = TranslationSnapshot(source: [a, b], generated: [
            .init(id: a.id, text: "Primero"), .init(id: b.id, text: "Segundo")],
            edits: [a.id.uuidString: "Primera corrección", b.id.uuidString: "Vieja corrección"])
        let changed = ReviewParagraph(id: b.id, text: "New second")
        let plan = IncrementalTranslation(source: [c, a, changed], previous: previous)
        XCTAssertEqual(plan.pending, [c, changed])
        let result = try plan.merging([.init(id: c.id, text: "Tercero"), .init(id: b.id, text: "Nuevo segundo")])
        XCTAssertEqual(result.spanish.map(\.text), ["Tercero", "Primera corrección", "Nuevo segundo"])
        XCTAssertEqual(result.edits.count, 1)
        XCTAssertThrowsError(try plan.merging([]))
        XCTAssertThrowsError(try plan.merging([.init(id: c.id, text: "")] ))
        let removed = try IncrementalTranslation(source: [a], previous: previous).merging([])
        XCTAssertEqual(removed.spanish.first?.text, "Primera corrección")
        XCTAssertEqual(removed.edits.count, 1)
    }

    func testVocabularyValidatesLimitsAndLiteralBoundaries() {
        let terms = PersonalVocabulary.terms("OpenAI\nmeeting = reunión\nMEETING = otro\n = invalid\nempty = \nC++ = Cplusplus")
        XCTAssertEqual(terms.count, 3)
        XCTAssertEqual(terms[0].target, "OpenAI")
        let parts = PersonalVocabulary.parts("OpenAI meeting, meetings and C++!", terms: terms)
        XCTAssertEqual(parts.filter(\.literal).map(\.text), ["OpenAI", "reunión", "Cplusplus"])
        XCTAssertEqual(parts.map(\.text).joined(), "OpenAI reunión, meetings and Cplusplus!")
        XCTAssertEqual(PersonalVocabulary.terms((0..<105).map { "Term\($0)" }.joined(separator: "\n")).count, 100)
        XCTAssertTrue(PersonalVocabulary.terms(String(repeating: "a", count: 81)).isEmpty)
    }

    func testVocabularyPreservesSpacingAndDoesNotSendTermsToTranslator() async throws {
        var sent: [String] = []
        let result = try await PersonalVocabulary.translate("  Hello OpenAI!  ", terms: PersonalVocabulary.terms("OpenAI")) {
            sent.append($0); return "Hola"
        }
        XCTAssertEqual(sent, ["Hello"])
        XCTAssertEqual(result, "  Hola OpenAI!  ")
        let suite = "vocabulary-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("meeting = reunión", forKey: PersonalVocabulary.key)
        XCTAssertEqual(PersonalVocabulary.saved(defaults: defaults).first?.target, "reunión")
    }

    func testLiveTranslationRejectsLateChangedResultsAndBoundsQueue() throws {
        let a = ReviewParagraph(id: UUID(), text: "Original")
        var buffer = LiveTranslationBuffer()
        buffer.synchronize([a])
        let changed = ReviewParagraph(id: a.id, text: "Changed")
        buffer.synchronize([changed])
        try buffer.accept([.init(id: a.id, text: "Anterior")], for: [a])
        XCTAssertTrue(buffer.translated.isEmpty)
        try buffer.accept([.init(id: a.id, text: "Cambiado")], for: [changed])
        XCTAssertEqual(buffer.translated[a.id], "Cambiado")
        buffer.synchronize([changed])
        XCTAssertTrue(buffer.pending.isEmpty)
        let many = (0..<100).map { ReviewParagraph(id: UUID(), text: "\($0)") }
        buffer.synchronize(many)
        XCTAssertEqual(buffer.source.count, 40)
        XCTAssertEqual(buffer.pending.count, 4)
        XCTAssertTrue(buffer.translated.isEmpty)
        XCTAssertThrowsError(try buffer.accept([], for: buffer.pending))
        buffer.synchronize([])
        XCTAssertTrue(buffer.source.isEmpty)
    }

    private func sample(_ repository: TranscriptRepository) throws -> (ConferenceSession, TranslationSnapshot) {
        let session = try repository.create(title: "Conference")
        let segment = CaptionSegment(runID: UUID(), start: 1, end: 8,
            text: "Hello world. We are learning together.", sessionTime: true)
        try repository.apply(.init(removedIDs: [], upserted: [segment]), to: session)
        try repository.checkpoint(session, duration: 8, ended: true)
        let source = try repository.reviewedParagraphs(for: session)
        return (session, TranslationSnapshot(source: source,
            generated: [ReviewParagraph(id: segment.id, text: "Hola mundo. Estamos aprendiendo juntos.")]))
    }

    func testTranslationPersistsIndependentlyAndDeleteRemovesIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = try autoreleasepool { () throws -> UUID in
            let repository = try TranscriptRepository(directory: directory)
            let (session, snapshot) = try sample(repository)
            try repository.saveTranslation(snapshot, for: session)
            var edited = snapshot
            edited.edits[snapshot.source[0].id.uuidString] = "Hola, mundo. Aprendemos juntos."
            try repository.saveTranslation(edited, for: session)
            XCTAssertEqual(session.fullTranscript, snapshot.source[0].text)
            XCTAssertNil(try repository.review(for: session.id))
            return session.id
        }
        let reopened = try TranscriptRepository(directory: directory)
        let snapshot = try XCTUnwrap(reopened.translation(for: id)?.decoded())
        XCTAssertEqual(snapshot.spanish[0].text, "Hola, mundo. Aprendemos juntos.")
        XCTAssertEqual(snapshot.generated[0].text, "Hola mundo. Estamos aprendiendo juntos.")
        let session = try XCTUnwrap(reopened.container.mainContext.fetch(FetchDescriptor<ConferenceSession>()).first)
        try reopened.delete(session)
        XCTAssertNil(try reopened.translation(for: id))
    }

    func testChangedEnglishRejectsStaleTranslationAndKeepsPrevious() throws {
        let repository = try TranscriptRepository(inMemory: true)
        let (session, snapshot) = try sample(repository)
        try repository.saveTranslation(snapshot, for: session)
        var corrected = snapshot.source
        corrected[0].text = "New English meaning."
        try repository.saveCorrections(corrected, for: session)
        XCTAssertFalse(snapshot.isCurrent(try repository.reviewedParagraphs(for: session)))
        XCTAssertThrowsError(try repository.saveTranslation(snapshot, for: session))
        XCTAssertEqual(try repository.translation(for: session.id)?.decoded(), snapshot)
    }

    func testIncompleteOrMismatchedResultsNeverReplaceSavedTranslation() throws {
        let repository = try TranscriptRepository(inMemory: true)
        let (session, snapshot) = try sample(repository)
        try repository.saveTranslation(snapshot, for: session)
        let incomplete = TranslationSnapshot(source: snapshot.source, generated: [])
        XCTAssertThrowsError(try repository.saveTranslation(incomplete, for: session))
        let wrongID = TranslationSnapshot(source: snapshot.source,
            generated: [ReviewParagraph(id: UUID(), text: "Hola")])
        XCTAssertThrowsError(try repository.saveTranslation(wrongID, for: session))
        let blank = TranslationSnapshot(source: snapshot.source,
            generated: [ReviewParagraph(id: snapshot.source[0].id, text: "  ")])
        XCTAssertThrowsError(try repository.saveTranslation(blank, for: session))
        XCTAssertEqual(try repository.translation(for: session.id)?.decoded(), snapshot)
    }

    func testSpanishAndBilingualSubtitlesPreserveTimesAndAllWords() throws {
        let id = UUID()
        let source = [ReviewParagraph(id: id, text: "Hello world later today")]
        let target = [ReviewParagraph(id: id, text: "Hola mundo más tarde hoy & <amigos>")]
        let snapshot = TranslationSnapshot(source: source, generated: target)
        let timing = [id.uuidString: CaptionTiming(start: 1, end: 9, words: [
            TimedWord(text: "Hello world", start: 1, end: 2),
            TimedWord(text: "later today", start: 7, end: 9)])]
        let original = TranslatedSubtitles.cues(snapshot: snapshot, timings: timing, mode: .english)
        let spanish = TranslatedSubtitles.cues(snapshot: snapshot, timings: timing, mode: .spanish)
        XCTAssertEqual(original.map(\.start), spanish.map(\.start))
        XCTAssertEqual(original.map(\.end), spanish.map(\.end))
        XCTAssertEqual(spanish.map(\.text).joined(separator: " "), target[0].text)
        let both = TranslatedSubtitles.cues(snapshot: snapshot, timings: timing, mode: .both)
        XCTAssertTrue(both[0].text.hasPrefix(original[0].text + "\n"))
        let srt = SubtitleExport.render(spanish, format: .srt)
        XCTAssertTrue(srt.contains("00:00:07,000 --> 00:00:09,000"))
        XCTAssertTrue(srt.contains("&amp; &lt;amigos&gt;"))
        XCTAssertTrue(SubtitleExport.render(both, format: .vtt).hasPrefix("WEBVTT"))
        XCTAssertTrue(TranslatedSubtitles.cues(snapshot: snapshot, timings: [:], mode: .spanish).isEmpty)
        XCTAssertEqual(snapshot.paragraphs(mode: .both)[0].text, source[0].text + "\n" + target[0].text)
    }

    func testEmptyParagraphAndShortTranslationDoNotLoseText() throws {
        let ids = [UUID(), UUID()]
        let source = [ReviewParagraph(id: ids[0], text: ""), ReviewParagraph(id: ids[1], text: "One two three")]
        let snapshot = TranslationSnapshot(source: source,
            generated: [ReviewParagraph(id: ids[0], text: ""), ReviewParagraph(id: ids[1], text: "Sí")])
        try snapshot.validate()
        let timing = [ids[1].uuidString: CaptionTiming(start: 0, end: 12, words: [
            TimedWord(text: "One", start: 0, end: 1), TimedWord(text: "two", start: 5, end: 6),
            TimedWord(text: "three", start: 10, end: 12)])]
        XCTAssertEqual(TranslatedSubtitles.cues(snapshot: snapshot, timings: timing, mode: .spanish).map(\.text), ["Sí"])
    }

    func testV5MigrationKeepsSavedSessionsDraftsCorrectionsAndMedia() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = try autoreleasepool { () throws -> UUID in
            let schema = Schema(versionedSchema: SessionSchemaV5.self)
            let configuration = ModelConfiguration("Sessions", schema: schema,
                url: directory.appendingPathComponent("Sessions.store"), cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let session = ConferenceSession(title: "Before translation")
            container.mainContext.insert(session)
            container.mainContext.insert(SessionDraft(sessionID: session.id))
            let review = SessionReview(sessionID: session.id)
            review.corrections = Data("{}".utf8)
            container.mainContext.insert(review)
            container.mainContext.insert(SessionMedia(sessionID: session.id))
            try container.mainContext.save()
            return session.id
        }
        let migrated = try TranscriptRepository(directory: directory)
        let sessions = try migrated.container.mainContext.fetch(FetchDescriptor<ConferenceSession>())
        XCTAssertEqual(sessions.first?.title, "Before translation")
        XCTAssertNotNil(try migrated.draft(for: id))
        XCTAssertNotNil(try migrated.review(for: id))
        XCTAssertNotNil(try migrated.media(for: id))
        XCTAssertNil(try migrated.translation(for: id))
    }
}

/// Deliberate test double: tests state transitions and text selection, not voice quality.
@MainActor
private final class FakeTranslationSpeechOutput: TranslationSpeechOutput {
    var onFinish: ((UUID) -> Void)?
    var texts: [String] = []
    var tokens: [UUID] = []
    var languages: [CaptureLanguage] = []
    var rates: [Float] = []
    var resumeCount = 0
    var failure: Error?
    func speak(_ text: String, language: CaptureLanguage, rate: Float, token: UUID) throws {
        if let failure { throw failure }
        texts.append(text); tokens.append(token); languages.append(language); rates.append(rate)
    }
    func pause() -> Bool { true }
    func resume() -> Bool { resumeCount += 1; return true }
    func stop() {}
}
