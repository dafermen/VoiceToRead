import XCTest
import SwiftData
@testable import VoiceToRead

@MainActor
final class CaptionViewModelTests: XCTestCase {
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
    var cancellations = 0
    var delayStart = false
    var pendingStart: CheckedContinuation<Void, Never>?
    private var output: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation?
    private var runID = UUID()

    func readiness() async -> SpeechReadiness { status }
    func installAssets() async throws { installations += 1; status = .ready }
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
    func finish() async throws {
        output?.yield(.init(runID: runID, start: 0, end: 1, text: "Final sentence.", isFinal: true))
        output?.finish()
    }
    func cancel() async { cancellations += 1; output?.finish() }
}
