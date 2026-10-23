import XCTest
import SwiftData
@testable import VoiceToRead

@MainActor
final class CaptionViewModelTests: XCTestCase {
    func testStopAutomaticallyTranslatesDraftAndDiscardRejectsLateResult() async throws {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults); settings.saveAudio = false
        let repo = try TranscriptRepository(inMemory: true)
        let model = CaptionViewModel(microphone: CaptionMicrophone(), speech: MockSpeech())
        let coordinator = SessionCoordinator(repository: repo, caption: model, settings: settings, translationSupported: { true })
        await model.start(); await model.pause()
        XCTAssertNil(coordinator.automaticTranslationJob, "Pause is not the end of a recording")
        await model.stop()
        let session = try XCTUnwrap(coordinator.currentSession)
        let job = try XCTUnwrap(coordinator.automaticTranslationJob)
        XCTAssertNotNil(try repo.draft(for: session.id))
        let translated = job.source.map { ReviewParagraph(id: $0.id, text: "Traducción") }
        coordinator.completeAutomaticTranslation(job, result: .success(translated))
        XCTAssertNotNil(try repo.translation(for: session.id))
        XCTAssertNotNil(try repo.draft(for: session.id), "Translation must not publish a recovery draft")
        await coordinator.discardCurrent()
        coordinator.completeAutomaticTranslation(job, result: .success(translated))
        XCTAssertNil(try repo.translation(for: session.id), "Late callbacks must not recreate discarded data")
    }

    func testAutomaticTranslationFailureRetryAndForegroundCancellation() async throws {
        let repo = try TranscriptRepository(inMemory: true)
        let session = try repo.create(title: "Ready", draft: true)
        let paragraph = CaptionSegment(runID: UUID(), start: 0, end: 1, text: "Hello")
        try repo.apply(.init(removedIDs: [], upserted: [paragraph]), to: session)
        try repo.checkpoint(session, duration: 1, ended: true)
        let coordinator = SessionCoordinator(repository: repo, translationSupported: { true })
        coordinator.enqueueTranslation(session)
        let old = try XCTUnwrap(coordinator.automaticTranslationJob)
        coordinator.automaticTranslationForeground(false)
        XCTAssertNil(coordinator.automaticTranslationJob)
        coordinator.completeAutomaticTranslation(old, result: .success([.init(id: paragraph.id, text: "Hola")]))
        XCTAssertNil(try repo.translation(for: session.id))
        coordinator.automaticTranslationForeground(true)
        let resumed = try XCTUnwrap(coordinator.automaticTranslationJob)
        XCTAssertNotEqual(old.id, resumed.id)
        coordinator.completeAutomaticTranslation(resumed, result: .failure(TranslationFailure.incomplete))
        XCTAssertNotNil(coordinator.automaticTranslationMessage)
        coordinator.retryAutomaticTranslation()
        XCTAssertNotNil(coordinator.automaticTranslationJob)
        coordinator.cancelAutomaticTranslation()
        XCTAssertNil(coordinator.automaticTranslationJob)
    }

    func testLanguageIsFixedAcrossPauseAndResumeUntilNewSession() async throws {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        settings.saveAudio = false // Fake speech/microphone tests do not provide a real audio recorder.
        let speech = MockSpeech()
        let model = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        let repository = try TranscriptRepository(inMemory: true)
        let coordinator = SessionCoordinator(repository: repository, caption: model, settings: settings)
        settings.captureLanguage = .spanish
        await coordinator.changeCaptureLanguage()
        XCTAssertEqual(model.language, .spanish); XCTAssertEqual(speech.language, .spanish)
        await model.start()
        XCTAssertEqual(coordinator.currentSession?.language, "es-ES")
        await model.pause()
        settings.captureLanguage = .english
        await coordinator.changeCaptureLanguage()
        XCTAssertEqual(model.language, .spanish)
        await model.start()
        XCTAssertEqual(speech.language, .spanish)
        XCTAssertEqual(coordinator.currentSession?.language, "es-ES")
        await model.stop(); XCTAssertTrue(coordinator.saveCurrent(ended: true))
        await coordinator.newSession()
        XCTAssertEqual(model.language, .english); XCTAssertEqual(speech.language, .english)
    }

    func testInterruptionKeepsDraftAndResumesOnlyOnRequest() async throws {
        let speech = MockSpeech()
        let microphone = CaptionMicrophone()
        let model = CaptionViewModel(microphone: microphone, speech: speech)
        let repository = try TranscriptRepository(inMemory: true)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)
        settings.saveAudio = false // Recording is covered by the audio integration tests.
        let coordinator = SessionCoordinator(repository: repository, caption: model, settings: settings)
        await model.start()
        let id = try XCTUnwrap(coordinator.currentSession?.id)
        microphone.onLevel?(0.7)
        XCTAssertEqual(model.inputLevel, 0.7, accuracy: 0.01)
        speech.interrupt()
        for _ in 0..<1000 { if model.canResume { break }; await Task.yield() }
        XCTAssertTrue(model.canResume)
        XCTAssertEqual(model.inputLevel, 0)
        XCTAssertEqual(speech.starts, 1)
        XCTAssertEqual(model.transcript.text, "Before interruption.")
        XCTAssertEqual(coordinator.currentSession?.id, id)
        XCTAssertNotNil(try repository.draft(for: id))
        await model.start()
        XCTAssertEqual(speech.starts, 2)
        await model.pause()
        XCTAssertEqual(model.state, .paused)
        XCTAssertTrue(model.canResume)
        XCTAssertEqual(model.inputLevel, 0)
        await model.start()
        await model.stop()
        coordinator.sessionTitle = "  Weekly planning  "
        XCTAssertTrue(coordinator.saveCurrent(ended: true))
        XCTAssertEqual(coordinator.currentSession?.title, "Weekly planning")
        XCTAssertEqual(coordinator.currentSession?.id, id)
        XCTAssertTrue(coordinator.currentSession?.fullTranscript.contains("Before interruption.") == true)
    }

    func testNoiseReductionSnapshotSurvivesPauseAndChangesOnlyForNewSession() async throws {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        settings.saveAudio = false
        settings.reduceBackgroundNoise = true
        let microphone = CaptionMicrophone()
        let speech = MockSpeech()
        let model = CaptionViewModel(microphone: microphone, speech: speech)
        let coordinator = SessionCoordinator(repository: try TranscriptRepository(inMemory: true), caption: model, settings: settings)
        XCTAssertEqual(speech.starts, 0, "Changing preferences never starts capture")
        await model.start()
        XCTAssertEqual(model.state, .listening)
        XCTAssertEqual(microphone.noiseChoices, [true])
        await model.pause()
        settings.reduceBackgroundNoise = false
        await model.start()
        XCTAssertEqual(model.state, .listening)
        XCTAssertTrue(model.reduceBackgroundNoise)
        XCTAssertEqual(microphone.noiseChoices, [true, true])
        await model.stop()
        XCTAssertTrue(coordinator.saveCurrent(ended: true))
        await coordinator.newSession()
        XCTAssertFalse(model.reduceBackgroundNoise)
        await model.start()
        XCTAssertEqual(microphone.noiseChoices, [true, true, false])
        await model.stop()
    }

    func testNoiseConfigurationFailureDoesNotSilentlyStartUnfilteredSpeech() async {
        let microphone = CaptionMicrophone()
        microphone.rejectNoise = true
        let speech = MockSpeech()
        let model = CaptionViewModel(microphone: microphone, speech: speech)
        model.reduceBackgroundNoise = true
        var prepared = false
        model.onWillStart = { prepared = true }
        await model.start()
        XCTAssertEqual(model.state, .problem(CaptureFailure.noiseReductionUnavailable.message))
        XCTAssertEqual(speech.starts, 0)
        XCTAssertFalse(prepared)
        XCTAssertNil(model.startedAt)
        XCTAssertTrue(model.canChooseCaptureOptions)
        model.reduceBackgroundNoise = false
        await model.start()
        XCTAssertEqual(model.state, .listening)
        XCTAssertEqual(speech.starts, 1)
        await model.stop()
    }

    func testDraftRequiresExplicitSaveAndPreferencesSurviveNewSession() async throws {
        let name = "FlowTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        settings.saveAudio = false // Fake speech/microphone tests do not provide a real audio recorder.
        settings.continueInBackground = true
        settings.saveAudio = false
        let repository = try TranscriptRepository(inMemory: true)
        let model = CaptionViewModel(microphone: CaptionMicrophone(), speech: MockSpeech())
        let coordinator = SessionCoordinator(repository: repository, caption: model, settings: settings)
        await model.start()
        let session = try XCTUnwrap(coordinator.currentSession)
        XCTAssertNotNil(try repository.draft(for: session.id))
        await model.stop()
        XCTAssertTrue(coordinator.needsSessionDecision)
        try repository.rename(session, title: "Renamed from history")
        XCTAssertEqual(coordinator.sessionTitle, "Renamed from history")
        await coordinator.newSession()
        XCTAssertEqual(model.state, .ended, "A pending draft cannot be silently replaced")
        XCTAssertEqual(session.fullTranscript, "Final sentence.")
        settings.saveAudio = true // next session only
        XCTAssertFalse(model.saveAudio)
        XCTAssertTrue(coordinator.saveCurrent(ended: true))
        XCTAssertNil(try repository.draft(for: session.id))
        XCTAssertEqual(session.title, "Renamed from history")
        await coordinator.newSession()
        XCTAssertEqual(model.state, .idle)
        XCTAssertTrue(model.saveAudio)
        XCTAssertTrue(model.continueInBackground)
        XCTAssertEqual(try repository.container.mainContext.fetchCount(FetchDescriptor<ConferenceSession>()), 1)
    }

    func testDiscardRemovesDraftAndKeepsPreviouslySavedSession() async throws {
        let repository = try TranscriptRepository(inMemory: true)
        let previous = try repository.create(title: "Keep me")
        let settingsName = "DiscardTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: settingsName)!
        defer { defaults.removePersistentDomain(forName: settingsName) }
        let model = CaptionViewModel(microphone: CaptionMicrophone(), speech: MockSpeech())
        let settings = AppSettings(defaults: defaults)
        settings.saveAudio = false // Recording is covered by the audio integration tests.
        let coordinator = SessionCoordinator(repository: repository, caption: model, settings: settings)
        await model.start()
        await model.stop()
        let id = try XCTUnwrap(coordinator.currentSession?.id)
        await coordinator.discardCurrent()
        XCTAssertNil(coordinator.storageMessage)
        XCTAssertEqual(model.state, .idle)
        XCTAssertFalse(coordinator.needsSessionDecision)
        XCTAssertNil(try repository.draft(for: id))
        let sessions = try repository.container.mainContext.fetch(FetchDescriptor<ConferenceSession>())
        XCTAssertEqual(sessions.map(\.id), [previous.id])
    }

    func testBackgroundListeningRequiresOptInAndNewSessionResetsChoices() async {
        let speech = MockSpeech()
        let model = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        XCTAssertFalse(model.saveAudio)
        XCTAssertFalse(model.continueInBackground)
        await model.start()
        await model.background()
        XCTAssertNotEqual(model.state, .listening)
        await model.reset()
        model.foregrounded()
        model.continueInBackground = true
        await model.start()
        await model.background()
        XCTAssertEqual(model.state, .listening)
        await model.stop()
        await model.reset()
        XCTAssertFalse(model.continueInBackground)
        XCTAssertFalse(model.saveAudio)
    }

    func testPreparingMicrophoneNeverStartsListening() async {
        let microphone = CaptionMicrophone()
        microphone.permission = .undetermined
        let speech = MockSpeech()
        let model = CaptionViewModel(microphone: microphone, speech: speech)
        XCTAssertEqual(model.microphonePermission, .undetermined)
        await model.requestMicrophonePermission()
        XCTAssertEqual(model.microphonePermission, .granted)
        XCTAssertEqual(speech.starts, 0)
        XCTAssertEqual(model.state, .idle)
        microphone.permission = .denied
        model.refreshMicrophonePermission()
        XCTAssertTrue(model.permissionDenied)
    }

    func testLateReadinessCannotUndoSuccessfulInstallation() async {
        let speech = MockSpeech(); speech.status = .missingAssets; speech.delayReadiness = true
        let model = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        let oldCheck = Task { await model.checkReadiness() }
        while speech.pendingReadiness == nil { await Task.yield() }
        await model.installAssets()
        XCTAssertEqual(model.readiness, .ready)
        speech.pendingReadiness?.resume(returning: .missingAssets); speech.pendingReadiness = nil
        await oldCheck.value
        XCTAssertEqual(model.readiness, .ready)
        XCTAssertEqual(speech.starts, 0)
        XCTAssertFalse(model.preparationPending)
    }

    func testIncompleteInstallationShowsProblemAndCanBeRetried() async {
        let speech = MockSpeech(); speech.status = .missingAssets; speech.installationCompletes = false
        let model = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        await model.installAssets()
        guard case .problem = model.readiness else { return XCTFail("An incomplete installation must explain the problem") }
        XCTAssertFalse(model.preparationPending)
        speech.installationCompletes = true
        await model.installAssets()
        XCTAssertEqual(model.readiness, .ready)
        XCTAssertEqual(speech.installations, 2)
        XCTAssertEqual(speech.starts, 0)
    }

    func testMissingModelNeverStartsCaptureOrInstallsImplicitly() async {
        let speech = MockSpeech()
        speech.status = .missingAssets
        let model = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        await model.start()
        XCTAssertEqual(speech.starts, 0)
        XCTAssertEqual(speech.installations, 0)
        XCTAssertEqual(model.readiness, .missingAssets)
    }

    func testStopKeepsFinalResultDeliveredDuringFinalization() async {
        let speech = MockSpeech()
        let model = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        await model.start()
        await model.stop()
        XCTAssertEqual(model.state, .ended)
        XCTAssertEqual(model.transcript.text, "Final sentence.")
    }

    func testPauseResumeUsesIndependentRunsAndRetainsText() async {
        let speech = MockSpeech()
        let model = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        await model.start()
        await model.pause()
        XCTAssertEqual(model.state, .paused)
        await model.start()
        await model.stop()
        XCTAssertEqual(model.transcript.finalized.count, 2)
    }

    func testBackgroundDuringPreparationInvalidatesLateStart() async {
        let speech = MockSpeech()
        speech.delayStart = true
        let model = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        let starting = Task { await model.start() }
        while speech.pendingStart == nil { await Task.yield() }
        await model.background()
        speech.resolveStart()
        await starting.value
        XCTAssertNotEqual(model.state, .listening)
        model.foregrounded()
        XCTAssertNotEqual(model.state, .listening)
        XCTAssertGreaterThan(speech.cancellations, 0)
    }
}

@MainActor
private final class CaptionMicrophone: AudioCapturing {
    var noiseChoices: [Bool] = []
    var rejectNoise = false
    func configureNoiseReduction(_ enabled: Bool) throws {
        if enabled && rejectNoise { throw CaptureFailure.noiseReductionUnavailable }
        noiseChoices.append(enabled)
    }
    var onLevel: (@MainActor @Sendable (Float) -> Void)?
    var permission: MicrophonePermission = .granted
    var onFailure: (@MainActor @Sendable (CaptureFailure) -> Void)?
    func requestPermission() async -> Bool { permission = .granted; return true }
    func start() throws -> AsyncStream<Float> { AsyncStream { $0.finish() } }
    func stop() throws {}
}

@MainActor
private final class MockSpeech: SpeechTranscribing {
    var language: CaptureLanguage = .english
    func configure(language: CaptureLanguage) { self.language = language }
    var status: SpeechReadiness = .ready
    var starts = 0
    var installations = 0
    var installedLanguages: [CaptureLanguage] = []
    var installationCompletes = true
    var delayReadiness = false
    var pendingReadiness: CheckedContinuation<SpeechReadiness, Never>?
    var cancellations = 0
    var delayStart = false
    var finalText = "Final sentence."
    var finishError: Error?
    var pendingStart: CheckedContinuation<Void, Never>?
    private var output: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation?
    private var runID = UUID()

    func readiness() async -> SpeechReadiness {
        if delayReadiness {
            delayReadiness = false
            return await withCheckedContinuation { pendingReadiness = $0 }
        }
        return status
    }
    func installAssets() async throws {
        installations += 1; installedLanguages.append(language)
        if installationCompletes { status = .ready }
    }
    func start() async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        starts += 1
        if delayStart { await withCheckedContinuation { pendingStart = $0 } }
        runID = UUID()
        let stream = AsyncThrowingStream<TranscriptionUpdate, Error>.makeStream()
        output = stream.continuation
        return stream.stream
    }
    func interrupt() {
        output?.yield(.init(runID: runID, start: 0, end: 1, text: "Before interruption.", isFinal: true))
        output?.finish(throwing: TranscriptionFailure.interrupted("Microphone interrupted."))
    }
    func resolveStart() { pendingStart?.resume(); pendingStart = nil }
    func emitPartial(_ text: String) {
        output?.yield(.init(runID: runID, start: 0, end: 1, text: text, isFinal: false))
    }
    func finish() async throws {
        if let finishError { output?.finish(throwing: finishError); throw finishError }
        output?.yield(.init(runID: runID, start: 0, end: 1, text: finalText, isFinal: true))
        output?.finish()
    }
    func cancel() async { cancellations += 1; output?.finish() }
}


@MainActor
final class SpeakTranslateTests: XCTestCase {
    func testExplicitModelPreparationUsesSelectedLanguageAndKeepsConversation() async throws {
        let speech = MockSpeech()
        let capture = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        await capture.start(); await capture.stop()
        XCTAssertEqual(capture.state, .ended)
        let model = SpeakTranslateModel(capture: capture, speaker: TranslationSpeechPlayer(output: ConversationTestOutput(), activate: {}, deactivate: {}), supported: { true })
        model.selectLanguage(.french, target: .korean)
        model.edit("Bonjour"); model.translate()
        let job = try XCTUnwrap(model.job)
        model.complete(job, result: .success(job.source.map { .init(id: $0.id, text: "안녕하세요") }))
        speech.status = .missingAssets
        model.prepareSpeechModel()
        await eventually { model.phase == .ready }
        XCTAssertEqual(capture.language, .french)
        XCTAssertEqual(capture.readiness, .missingAssets)
        XCTAssertEqual(speech.installations, 0, "Preparation does not silently download a model")
        model.prepareSpeechModel(install: true)
        await eventually { model.phase == .ready }
        XCTAssertEqual(speech.installedLanguages, [.french])
        XCTAssertEqual(capture.readiness, .ready)
        XCTAssertEqual(model.source, "Bonjour")
        XCTAssertEqual(model.translated, "안녕하세요")
        XCTAssertEqual(model.target, .korean)
        XCTAssertEqual(speech.starts, 1, "Installing must not start another microphone run")
    }

    func testPauseRequiresRecognizedTextQuietAndStableWords() {
        var detector = ConversationPause()
        XCTAssertFalse(detector.shouldFinish(text: "", level: 0, now: 100, delay: 3))
        XCTAssertFalse(detector.shouldFinish(text: "Quiero agua", level: 0, now: 101, delay: 3))
        XCTAssertFalse(detector.shouldFinish(text: "Quiero agua", level: 0.8, now: 103, delay: 3))
        XCTAssertFalse(detector.shouldFinish(text: "Quiero agua", level: 0, now: 105, delay: 3))
        XCTAssertTrue(detector.shouldFinish(text: "Quiero agua", level: 0, now: 106, delay: 3))
        XCTAssertFalse(detector.shouldFinish(text: "Quiero agua fría", level: 0, now: 107, delay: 3))
        XCTAssertFalse(detector.shouldFinish(text: "Quiero agua fría", level: 0, now: 200, delay: 0))
    }
    func testFinalizesMicrophoneBeforeTranslatingAndWaitsForManualPlayback() async throws {
        let speech = MockSpeech()
        let capture = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        let output = ConversationTestOutput()
        let player = TranslationSpeechPlayer(output: output, activate: {
            XCTAssertEqual(capture.state, .ended)
        }, deactivate: {})
        let model = SpeakTranslateModel(capture: capture, speaker: player, supported: { true })
        model.start()
        await eventually { model.phase == .listening }
        XCTAssertEqual(speech.language, .spanish)
        XCTAssertFalse(capture.saveAudio)
        model.finish()
        await eventually { model.phase == .translating }
        let job = try XCTUnwrap(model.job)
        XCTAssertEqual(job.plan.language, .spanish)
        XCTAssertEqual(capture.state, .ended)
        let reply = job.source.map { ReviewParagraph(id: $0.id, text: "A glass of water, please.") }
        model.complete(job, result: .success(reply))
        model.complete(job, result: .success(reply))
        XCTAssertTrue(output.spoken.isEmpty)
        model.togglePlayback(.translation)
        XCTAssertEqual(output.spoken, ["A glass of water, please."])
        XCTAssertEqual(output.language, .english)
        XCTAssertEqual(speech.starts, 1, "Playback never reopens the microphone")
        model.cancel()
        await eventually { model.phase == .ready }
        XCTAssertEqual(player.state, .idle)
    }
    func testCancelRejectsLateTranslationAndAllowsNextTurn() async throws {
        let speech = MockSpeech()
        let capture = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        let output = ConversationTestOutput()
        let player = TranslationSpeechPlayer(output: output, activate: {}, deactivate: {})
        let model = SpeakTranslateModel(capture: capture, speaker: player, supported: { true })
        model.edit("Un café por favor")
        model.translate()
        let old = try XCTUnwrap(model.job)
        model.cancel()
        model.complete(old, result: .success(old.source.map { .init(id: $0.id, text: "Coffee, please") }))
        XCTAssertTrue(output.spoken.isEmpty)
        await eventually { model.phase == .ready }
        model.edit("Agua")
        model.translate()
        let current = try XCTUnwrap(model.job)
        XCTAssertNotEqual(old.id, current.id)
        model.complete(current, result: .success([]))
        XCTAssertNotNil(model.message)
        XCTAssertTrue(output.spoken.isEmpty, "Incomplete translation cannot be spoken")
        model.cancel()
        await eventually { model.phase == .ready }
    }
    func testInterruptionDoesNotAutomaticallyTranslateOrResume() async {
        let speech = MockSpeech()
        let capture = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        let output = ConversationTestOutput()
        let model = SpeakTranslateModel(capture: capture,
            speaker: TranslationSpeechPlayer(output: output, activate: {}, deactivate: {}), supported: { true })
        model.start()
        await eventually { model.phase == .listening }
        speech.interrupt()
        await eventually { if case .problem = capture.state { return true }; return false }
        model.poll(now: ProcessInfo.processInfo.systemUptime)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertNil(model.job)
        XCTAssertTrue(output.spoken.isEmpty)
        XCTAssertNotNil(model.message)
        model.cancel()
        await eventually { model.phase == .ready }
    }
    func testQuietPauseAutomaticallyFinalizesAndUsesFinalRevision() async throws {
        let speech = MockSpeech(); speech.finalText = "Quiero agua fría."
        let capture = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        let model = SpeakTranslateModel(capture: capture, supported: { true })
        model.selectMode(.automatic)
        model.start()
        await eventually { model.phase == .listening }
        speech.emitPartial("Quiero agua")
        await eventually { !capture.transcript.partial.isEmpty }
        let now = ProcessInfo.processInfo.systemUptime
        model.poll(now: now)
        XCTAssertEqual(model.phase, .listening)
        model.poll(now: now + 4)
        await eventually { model.phase == .translating }
        XCTAssertEqual(model.job?.source.first?.text, "Quiero agua fría.")
        XCTAssertEqual(capture.state, .ended)
        model.cancel()
        await eventually { model.phase == .ready }
    }
    func testFailedFinalizationRequiresReviewInsteadOfAutomaticSpeech() async {
        let speech = MockSpeech(); speech.finishError = TranscriptionFailure.finalizationTimeout
        let capture = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        let model = SpeakTranslateModel(capture: capture, supported: { true })
        model.start()
        await eventually { model.phase == .listening }
        speech.emitPartial("Un café")
        await eventually { !capture.transcript.partial.isEmpty }
        model.poll(now: ProcessInfo.processInfo.systemUptime)
        model.finish()
        await eventually { model.phase == .ready }
        XCTAssertEqual(model.source, "Un café")
        XCTAssertNil(model.job)
        XCTAssertNotNil(model.message)
        model.cancel()
        await eventually { model.phase == .ready }
    }
    func testCancelDuringRecognitionStartupCannotStartTranslation() async {
        let speech = MockSpeech(); speech.delayStart = true
        let capture = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        let model = SpeakTranslateModel(capture: capture, supported: { true })
        model.start()
        await eventually { speech.pendingStart != nil }
        model.cancel()
        speech.resolveStart()
        await eventually { model.phase == .ready }
        XCTAssertEqual(capture.state, .idle)
        XCTAssertNil(model.job)
    }
    func testByButtonDoesNotFinishOnPauseAndFinishWaitsForManualAudio() async throws {
        let speech = MockSpeech(); speech.finalText = "Un café, por favor."
        let capture = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        let output = ConversationTestOutput()
        let model = SpeakTranslateModel(capture: capture,
            speaker: TranslationSpeechPlayer(output: output, activate: {}, deactivate: {}), supported: { true })
        model.selectMode(.byButton)
        model.start()
        await eventually { model.phase == .listening }
        speech.emitPartial("Un café")
        await eventually { !capture.transcript.partial.isEmpty }
        let now = ProcessInfo.processInfo.systemUptime
        model.poll(now: now); model.poll(now: now + 10)
        XCTAssertEqual(model.phase, .listening)
        model.finish()
        await eventually { model.phase == .translating }
        model.selectMode(.automatic)
        XCTAssertEqual(model.mode, .byButton, "Changing mode cannot alter a pending turn")
        let job = try XCTUnwrap(model.job)
        model.complete(job, result: .success(job.source.map { .init(id: $0.id, text: "A coffee, please.") }))
        XCTAssertTrue(output.spoken.isEmpty)
        model.togglePlayback(.translation)
        XCTAssertEqual(output.spoken, ["A coffee, please."])
        XCTAssertEqual(capture.state, .ended)
        XCTAssertEqual(model.translated, "A coffee, please.")
        XCTAssertEqual(output.spoken, ["A coffee, please."])
        XCTAssertEqual(speech.starts, 1)
        model.cancel()
        await eventually { model.phase == .ready }
    }
    func testNewConversationClearsTextAndKeepsDirectionAndPreferences() throws {
        let output = ConversationTestOutput()
        let model = SpeakTranslateModel(speaker: TranslationSpeechPlayer(output: output, activate: {}, deactivate: {}), supported: { true })
        model.selectLanguage(.japanese, target: .chinese)
        model.selectMode(.automatic); model.pauseSeconds = 5
        model.edit("こんにちは"); model.translate()
        let job = try XCTUnwrap(model.job)
        model.newConversation()
        XCTAssertEqual(model.phase, .translating, "An active operation must not be cleared")
        XCTAssertEqual(model.source, "こんにちは")
        model.complete(job, result: .success(job.source.map { .init(id: $0.id, text: "你好") }))
        XCTAssertEqual(model.translated, "你好")
        model.message = "Old notice"
        model.speaker.message = "Old speech notice"
        model.newConversation()
        XCTAssertTrue(model.source.isEmpty)
        XCTAssertTrue(model.translated.isEmpty)
        XCTAssertNil(model.message)
        XCTAssertNil(model.speaker.message)
        XCTAssertEqual(model.language, .japanese)
        XCTAssertEqual(model.target, .chinese)
        XCTAssertEqual(model.mode, .automatic)
        XCTAssertEqual(model.pauseSeconds, 5)
        XCTAssertTrue(model.canEdit)
        model.complete(job, result: .success(job.source.map { .init(id: $0.id, text: "Late result") }))
        XCTAssertTrue(model.translated.isEmpty)
        model.newConversation()
        XCTAssertTrue(output.spoken.isEmpty)
    }

    func testEditingManualTranslationInvalidatesPreviousSpeech() throws {
        let output = ConversationTestOutput()
        let model = SpeakTranslateModel(speaker: TranslationSpeechPlayer(output: output, activate: {}, deactivate: {}), supported: { true })
        model.selectMode(.byButton); model.edit("Hola"); model.translate()
        let job = try XCTUnwrap(model.job)
        model.complete(job, result: .success(job.source.map { .init(id: $0.id, text: "Hello") }))
        model.edit("Adiós"); model.togglePlayback(.translation)
        XCTAssertTrue(model.translated.isEmpty)
        XCTAssertTrue(output.spoken.isEmpty)
    }
    func testEnglishTurnProducesSpanishAndBlocksAnotherMicrophoneDuringPlayback() async throws {
        let speech = MockSpeech(); speech.finalText = "Would you like cold water?"
        let capture = CaptionViewModel(microphone: CaptionMicrophone(), speech: speech)
        let output = ConversationTestOutput()
        let model = SpeakTranslateModel(capture: capture,
            speaker: TranslationSpeechPlayer(output: output, activate: { XCTAssertEqual(capture.state, .ended) }, deactivate: {}), supported: { true })
        XCTAssertEqual(model.mode, .byButton)
        model.start(language: .english)
        await eventually { model.phase == .listening }
        XCTAssertEqual(speech.language, .english)
        model.selectLanguage(.spanish)
        XCTAssertEqual(model.language, .english, "An active turn cannot change direction")
        model.finish()
        await eventually { model.phase == .translating }
        let job = try XCTUnwrap(model.job)
        XCTAssertEqual(job.plan.language, .english)
        model.complete(job, result: .success(job.source.map { .init(id: $0.id, text: "¿Quieres agua fría?") }))
        XCTAssertTrue(output.spoken.isEmpty)
        model.togglePlayback(.translation)
        XCTAssertEqual(output.language, .spanish)
        XCTAssertEqual(output.spoken, ["¿Quieres agua fría?"])
        model.start(language: .spanish)
        XCTAssertEqual(speech.starts, 1, "Output must finish or be stopped before listening again")
        XCTAssertEqual(model.translated, "¿Quieres agua fría?")
        model.speaker.stop()
        speech.finalText = "Sí, gracias."
        model.start(language: .spanish)
        await eventually { model.phase == .listening }
        XCTAssertEqual(speech.language, .spanish)
        XCTAssertEqual(speech.starts, 2)
        XCTAssertFalse(capture.saveAudio)
        model.cancel()
        await eventually { model.phase == .ready }
    }
    func testFailedEnglishTranslationKeepsSourceForRetryAndRejectsOldResult() throws {
        let output = ConversationTestOutput()
        let model = SpeakTranslateModel(speaker: TranslationSpeechPlayer(output: output, activate: {}, deactivate: {}), supported: { true })
        model.selectLanguage(.english); model.edit("How can I help?"); model.translate()
        let first = try XCTUnwrap(model.job)
        model.complete(first, result: .success([]))
        XCTAssertEqual(model.source, "How can I help?")
        XCTAssertEqual(model.language, .english)
        XCTAssertNotNil(model.message)
        model.translate()
        let retry = try XCTUnwrap(model.job)
        model.complete(first, result: .success(first.source.map { .init(id: $0.id, text: "Old") }))
        XCTAssertTrue(output.spoken.isEmpty)
        model.complete(retry, result: .success(retry.source.map { .init(id: $0.id, text: "¿En qué puedo ayudarte?") }))
        XCTAssertTrue(output.spoken.isEmpty)
        model.togglePlayback(.translation)
        XCTAssertEqual(output.language, .spanish)
        model.speaker.stop()
        model.togglePlayback(.translation)
        XCTAssertEqual(output.spoken.count, 2, "Replay reuses the translation without recognition")
        model.speaker.stop()
    }
    func testManualTimeLimitTranslatesButWaitsForExplicitPlay() async throws {
        let speech = MockSpeech(); speech.finalText = "One minute of speech."
        let output = ConversationTestOutput()
        let model = SpeakTranslateModel(capture: CaptionViewModel(microphone: CaptionMicrophone(), speech: speech),
            speaker: TranslationSpeechPlayer(output: output, activate: {}, deactivate: {}), supported: { true })
        model.start(language: .english)
        await eventually { model.phase == .listening }
        speech.emitPartial("One minute")
        await eventually { !model.capture.transcript.partial.isEmpty }
        model.poll(now: ProcessInfo.processInfo.systemUptime + 61)
        await eventually { model.phase == .translating }
        let job = try XCTUnwrap(model.job)
        model.complete(job, result: .success(job.source.map { .init(id: $0.id, text: "Un minuto de voz.") }))
        XCTAssertTrue(output.spoken.isEmpty)
        model.togglePlayback(.translation)
        XCTAssertEqual(output.language, .spanish)
        model.cancel()
        await eventually { model.phase == .ready }
    }
    func testUnsupportedDeviceDoesNotStartCaptureOrTranslation() {
        let speech = MockSpeech()
        let model = SpeakTranslateModel(capture: CaptionViewModel(microphone: CaptionMicrophone(), speech: speech), supported: { false })
        model.start(); model.edit("Hola"); model.translate()
        XCTAssertEqual(speech.starts, 0)
        XCTAssertNil(model.job)
        XCTAssertEqual(model.phase, .ready)
    }
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Conversation did not reach the expected state")
    }
}

@MainActor
private final class ConversationTestOutput: TranslationSpeechOutput {
    var onFinish: ((UUID) -> Void)?
    var spoken: [String] = []
    var language: CaptureLanguage?
    var tokens: [UUID] = []
    var stopCount = 0
    func speak(_ text: String, language: CaptureLanguage, rate: Float, token: UUID) throws {
        spoken.append(text); self.language = language; tokens.append(token)
    }
    func pause() -> Bool { true }
    func resume() -> Bool { true }
    func stop() { stopCount += 1 }
}


extension CaptionViewModelTests {
    func testConversationCardPlaybackSwitchesOriginalAndTranslationAndRejectsStaleCompletion() throws {
        let output = ConversationTestOutput()
        let player = TranslationSpeechPlayer(output: output, activate: {}, deactivate: {})
        let model = SpeakTranslateModel(speaker: player, supported: { true })
        model.selectLanguage(.french, target: .korean)
        model.edit("Bonjour"); model.translate()
        let job = try XCTUnwrap(model.job)
        model.togglePlayback(.original)
        XCTAssertTrue(output.spoken.isEmpty, "Playback must wait until translation/capture finishes")
        model.complete(job, result: .success(job.source.map { .init(id: $0.id, text: "안녕하세요") }))
        XCTAssertTrue(output.spoken.isEmpty, "Written replies translate without starting audio")
        model.togglePlayback(.original)
        XCTAssertEqual(output.spoken, ["Bonjour"]); XCTAssertEqual(output.language, .french)
        XCTAssertTrue(model.isPlaying(.original)); XCTAssertFalse(model.isPlaying(.translation))
        let oldToken = try XCTUnwrap(output.tokens.last)
        let stops = output.stopCount
        model.togglePlayback(.translation)
        XCTAssertGreaterThan(output.stopCount, stops, "Switching cards must stop the previous utterance")
        XCTAssertEqual(output.spoken.last, "안녕하세요"); XCTAssertEqual(output.language, .korean)
        XCTAssertFalse(model.isPlaying(.original)); XCTAssertTrue(model.isPlaying(.translation))
        output.onFinish?(oldToken)
        XCTAssertTrue(model.isPlaying(.translation), "A cancelled original cannot end translation playback")
        let translatedToken = try XCTUnwrap(output.tokens.last)
        output.onFinish?(translatedToken)
        XCTAssertFalse(model.isPlaying(.original)); XCTAssertFalse(model.isPlaying(.translation))
        XCTAssertEqual(player.state, .idle)
        model.togglePlayback(.translation)
        let count = output.spoken.count
        model.togglePlayback(.translation)
        XCTAssertEqual(output.spoken.count, count, "Pressing an active card stops instead of replaying it")
        XCTAssertEqual(player.state, .idle)
        XCTAssertEqual(model.source, "Bonjour"); XCTAssertEqual(model.translated, "안녕하세요")
    }

    func testAutomaticConversationTranslatesAfterPauseWithoutSpeaking() async throws {
        let speech = MockSpeech(); speech.finalText = "Hola"
        let output = ConversationTestOutput()
        let model = SpeakTranslateModel(capture: CaptionViewModel(microphone: CaptionMicrophone(), speech: speech),
            speaker: TranslationSpeechPlayer(output: output, activate: {}, deactivate: {}), supported: { true })
        model.selectMode(.automatic)
        model.start(language: .spanish)
        await eventually { model.phase == .listening }
        speech.emitPartial("Hola")
        await eventually { !model.capture.transcript.partial.isEmpty }
        let now = ProcessInfo.processInfo.systemUptime
        model.poll(now: now); model.poll(now: now + 4)
        await eventually { model.phase == .translating }
        let job = try XCTUnwrap(model.job)
        model.complete(job, result: .success(job.source.map { .init(id: $0.id, text: "Hello") }))
        XCTAssertEqual(model.source, "Hola"); XCTAssertEqual(model.translated, "Hello")
        XCTAssertTrue(output.spoken.isEmpty)
        XCTAssertEqual(model.speaker.state, .idle)
        XCTAssertTrue(model.canEdit)
        model.togglePlayback(.original)
        XCTAssertEqual(output.spoken.last, "Hola"); XCTAssertEqual(output.language, .spanish)
        XCTAssertEqual(speech.starts, 1, "Manual audio must not reopen the microphone")
        model.cancel(); await eventually { model.phase == .ready }
    }
}
