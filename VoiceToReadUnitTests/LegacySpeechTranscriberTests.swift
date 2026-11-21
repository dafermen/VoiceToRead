import AVFoundation
import Speech
import XCTest
@testable import VoiceToRead

@MainActor
final class LegacySpeechTranscriberTests: XCTestCase {
    func testSampleTimelineSurvivesRequestRotationAndResume() async throws {
        let backend = TestSpeechBackend()
        let audio = TestSpeechAudio()
        let service = LegacySpeechTranscriber(audio: audio, backend: backend, requestDuration: 0.015)
        let updates = try await service.start()
        let collection = collect(updates)
        for start in [20.0, 20.01, 20.02] {
            var frame = try makeFrame()
            frame.sessionStart = start
            audio.audioSink?(frame)
        }
        try await service.finish()
        let first = try await collection.value
        XCTAssertEqual(first.finalized.map(\.start), [20, 20.02])
        XCTAssertTrue(first.finalized.allSatisfy { $0.sessionTime == true })
        let resumed = try await service.start()
        let resumedCollection = collect(resumed)
        var frame = try makeFrame()
        frame.sessionStart = 20.03
        audio.audioSink?(frame)
        try await service.finish()
        let second = try await resumedCollection.value
        XCTAssertEqual(second.finalized.first?.start, 20.03)
    }

    func testRequestsRequireOfflineRecognition() {
        let request = LegacySpeechBackend.offlineRequest()
        XCTAssertTrue(request.requiresOnDeviceRecognition)
        XCTAssertTrue(request.shouldReportPartialResults)
    }

    func testAuthorizationIsExplicitAndUnavailableOfflineSupportNeverStartsAudio() async {
        let backend = TestSpeechBackend()
        let audio = TestSpeechAudio()
        let service = LegacySpeechTranscriber(audio: audio, backend: backend)
        backend.authorization = .notDetermined
        let initial = await service.readiness()
        XCTAssertEqual(initial, .authorizationRequired)
        XCTAssertEqual(backend.permissionRequests, 0)
        do { _ = try await service.start(); XCTFail("Must require permission") } catch {}
        XCTAssertEqual(audio.starts, 0)
        await service.requestAuthorization()
        XCTAssertEqual(backend.permissionRequests, 1)
        backend.supportsOnDeviceRecognition = false
        let unsupported = await service.readiness()
        XCTAssertEqual(unsupported, .systemModelUnavailable)
        do { _ = try await service.start(); XCTFail("Must refuse server recognition") } catch {}
        XCTAssertEqual(audio.starts, 0)
        XCTAssertEqual(backend.starts, 0)
    }

    func testDeniedRestrictedAndUnavailableStates() async {
        let backend = TestSpeechBackend()
        let service = LegacySpeechTranscriber(audio: TestSpeechAudio(), backend: backend)
        backend.authorization = .denied
        let denied = await service.readiness()
        XCTAssertEqual(denied, .authorizationDenied)
        backend.authorization = .restricted
        let restricted = await service.readiness()
        XCTAssertEqual(restricted, .authorizationRestricted)
        backend.authorization = .authorized
        backend.isAvailable = false
        let unavailable = await service.readiness()
        if case .problem = unavailable {} else { XCTFail("Unavailable recognizer must not be ready") }
    }

    func testRotationPreservesQueuedAudioAndFinalTranscripts() async throws {
        let backend = TestSpeechBackend()
        let audio = TestSpeechAudio()
        let service = LegacySpeechTranscriber(audio: audio, backend: backend, requestDuration: 0.015)
        let updates = try await service.start()
        let collection = collect(updates)
        let frame = try makeFrame()
        // 30ms total: first request gets two 10ms frames, next gets one.
        for _ in 0..<3 { audio.audioSink?(frame) }
        try await service.finish()
        let transcript = try await collection.value
        XCTAssertEqual(backend.frameCounts, [2, 1])
        XCTAssertEqual(transcript.text, "Final 1\nFinal 2")
        XCTAssertEqual(transcript.finalized.count, 2)
        XCTAssertTrue(transcript.partial.isEmpty)
        XCTAssertEqual(audio.starts, 1)
        XCTAssertNil(audio.audioSink)
    }

    func testAudioWaitsForFinalResultBeforeStartingNextRequest() async throws {
        let backend = TestSpeechBackend()
        backend.autoFinalize = false
        let ending = expectation(description: "Request is ending")
        backend.onEndAudio = { ending.fulfill() }
        let audio = TestSpeechAudio()
        let service = LegacySpeechTranscriber(audio: audio, backend: backend, requestDuration: 0.005)
        let updates = try await service.start()
        let collection = collect(updates)
        let frame = try makeFrame()
        audio.audioSink?(frame)
        audio.audioSink?(frame)
        await fulfillment(of: [ending], timeout: 2)
        XCTAssertEqual(backend.frameCounts, [1])
        backend.onEndAudio = nil
        backend.autoFinalize = true
        backend.finalize()
        try await service.finish()
        _ = try await collection.value
        XCTAssertEqual(backend.frameCounts, [1, 1])
    }

    func testCancelDuringFinalizationUnblocksFinishAndIgnoresLateResults() async throws {
        let backend = TestSpeechBackend()
        backend.autoFinalize = false
        let ending = expectation(description: "Finalization started")
        backend.onEndAudio = { ending.fulfill() }
        let audio = TestSpeechAudio()
        let service = LegacySpeechTranscriber(audio: audio, backend: backend)
        let stream = try await service.start()
        let collection = collect(stream)
        let oldCallback = backend.receive
        let finishing = Task { try await service.finish() }
        await fulfillment(of: [ending], timeout: 2)
        await service.cancel()
        oldCallback?(.success(.init(text: "Stale", end: 1, isFinal: true)))
        do { try await finishing.value; XCTFail("Expected cancellation") } catch is CancellationError {} catch { XCTFail("\(error)") }
        do { _ = try await collection.value; XCTFail("Expected cancellation") } catch is CancellationError {} catch { XCTFail("\(error)") }
        XCTAssertNil(audio.audioSink)
    }

    func testFinalizationTimeoutStopsCaptureAndFailsStream() async throws {
        let backend = TestSpeechBackend()
        backend.autoFinalize = false
        let audio = TestSpeechAudio()
        let service = LegacySpeechTranscriber(audio: audio, backend: backend, finalizationTimeout: .milliseconds(20))
        let stream = try await service.start()
        let collection = collect(stream)
        do { try await service.finish(); XCTFail("Expected timeout") }
        catch TranscriptionFailure.finalizationTimeout {} catch { XCTFail("\(error)") }
        do { _ = try await collection.value; XCTFail("Expected stream timeout") }
        catch TranscriptionFailure.finalizationTimeout {} catch { XCTFail("\(error)") }
        XCTAssertNil(audio.audioSink)
    }

    func testQueueOverflowFailsInsteadOfDroppingAudioSilently() async throws {
        let backend = TestSpeechBackend()
        let audio = TestSpeechAudio()
        let service = LegacySpeechTranscriber(audio: audio, backend: backend)
        let stream = try await service.start()
        let collection = collect(stream)
        let frame = try makeFrame()
        for _ in 0..<129 { audio.audioSink?(frame) }
        do { try await service.finish(); XCTFail("Expected overflow") }
        catch TranscriptionFailure.overflow {} catch { XCTFail("\(error)") }
        do { _ = try await collection.value; XCTFail("Expected stream overflow") }
        catch TranscriptionFailure.overflow {} catch { XCTFail("\(error)") }
    }

    private func makeFrame() throws -> CapturedAudio {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 160))
        buffer.frameLength = 160
        buffer.floatChannelData?[0].initialize(repeating: 0, count: 160)
        return CapturedAudio(buffer: buffer)
    }

    private func collect(_ stream: AsyncThrowingStream<TranscriptionUpdate, Error>) -> Task<TranscriptAssembler, Error> {
        Task {
            var assembler = TranscriptAssembler()
            for try await update in stream { _ = assembler.apply(update) }
            return assembler
        }
    }
}

@MainActor
private final class TestSpeechBackend: LegacySpeechRecognizing {
    var authorization: SFSpeechRecognizerAuthorizationStatus = .authorized
    var supportsLocale = true
    var supportsOnDeviceRecognition = true
    var isAvailable = true
    var permissionRequests = 0
    var starts = 0
    var frameCounts: [Int] = []
    var autoFinalize = true
    var onEndAudio: (() -> Void)?
    var receive: (@MainActor (Result<LegacySpeechResult, Error>) -> Void)?
    func requestAuthorization() async { permissionRequests += 1; authorization = .authorized }
    func start(receive: @escaping @MainActor (Result<LegacySpeechResult, Error>) -> Void) throws {
        starts += 1
        frameCounts.append(0)
        self.receive = receive
    }
    func append(_ audio: CapturedAudio) {
        frameCounts[starts - 1] += 1
        receive?(.success(.init(text: "Partial \(starts)", end: Double(frameCounts[starts - 1]), isFinal: false)))
    }
    func endAudio() {
        onEndAudio?()
        if autoFinalize { finalize() }
    }
    func finalize() { receive?(.success(.init(text: "Final \(starts)", end: 1, isFinal: true))) }
    func cancel() { receive = nil }
}

@MainActor
private final class TestSpeechAudio: SpeechAudioCapturing {
    var audioSink: (@Sendable (CapturedAudio) -> Void)?
    var onFailure: (@MainActor @Sendable (CaptureFailure) -> Void)?
    var permission: MicrophonePermission = .granted
    var starts = 0
    private var levels: AsyncStream<Float>.Continuation?
    func requestPermission() async -> Bool { true }
    func start() throws -> AsyncStream<Float> {
        starts += 1
        let stream = AsyncStream<Float>.makeStream()
        levels = stream.continuation
        return stream.stream
    }
    func stop() throws { levels?.finish(); levels = nil }
}


extension LegacySpeechTranscriberTests {
    func testLanguageRoutingUsesAppleCompatibilityBeforeCaptureAndKeepsItForResume() async throws {
        let modern = LanguageRoutingSpeech(status: .unsupportedLanguage)
        let legacy = LanguageRoutingSpeech(status: .authorizationRequired)
        let speech = LanguageSpeechTranscriber(preferred: modern, compatibility: legacy)
        speech.configure(language: .dutch)
        XCTAssertEqual(modern.language, .dutch); XCTAssertEqual(legacy.language, .dutch)
        let needsPermission = await speech.readiness()
        XCTAssertEqual(needsPermission, .authorizationRequired)
        XCTAssertEqual(modern.starts, 0); XCTAssertEqual(legacy.starts, 0)
        await speech.requestAuthorization()
        XCTAssertEqual(legacy.authorizations, 1); XCTAssertEqual(modern.authorizations, 0)
        legacy.status = .ready
        _ = try await speech.start()
        modern.status = .ready
        let activeStatus = await speech.readiness()
        XCTAssertEqual(activeStatus, .ready)
        try await speech.finish(); await speech.cancel()
        _ = try await speech.start()
        XCTAssertEqual(legacy.starts, 2); XCTAssertEqual(modern.starts, 0)
        XCTAssertEqual(legacy.finishes, 1); XCTAssertEqual(legacy.cancels, 1)
        speech.configure(language: .german)
        let modernStatus = await speech.readiness()
        XCTAssertEqual(modernStatus, .ready)
        _ = try await speech.start()
        XCTAssertEqual(modern.starts, 1); XCTAssertEqual(legacy.starts, 2)
    }

    func testLanguageRoutingDoesNotBypassDownloadsOrRecoverRuntimeFailuresWithAnotherEngine() async throws {
        let modern = LanguageRoutingSpeech(status: .missingAssets)
        let legacy = LanguageRoutingSpeech(status: .ready)
        let speech = LanguageSpeechTranscriber(preferred: modern, compatibility: legacy)
        speech.configure(language: .russian)
        let status = await speech.readiness()
        XCTAssertEqual(status, .missingAssets)
        try await speech.installAssets()
        XCTAssertEqual(modern.installations, 1); XCTAssertEqual(legacy.installations, 0)
        modern.status = .ready; modern.failStart = true
        do { _ = try await speech.start(); XCTFail("Expected the original runtime failure") }
        catch { XCTAssertTrue(error is TranscriptionFailure) }
        XCTAssertEqual(legacy.starts, 0)
        modern.status = .problem("Temporary interruption")
        let interrupted = await speech.readiness()
        XCTAssertEqual(interrupted, .problem("Temporary interruption"))
        XCTAssertEqual(legacy.readinessChecks, 0)
    }

    func testCancelledLanguageReadinessCannotSelectOrStartAnOldEngine() async {
        let modern = LanguageRoutingSpeech(status: .unsupportedLanguage)
        let legacy = LanguageRoutingSpeech(status: .ready)
        let speech = LanguageSpeechTranscriber(preferred: modern, compatibility: legacy)
        modern.delayReadiness = true
        let pending = Task { await speech.readiness() }
        for _ in 0..<100 where modern.pendingReadiness == nil { await Task.yield() }
        XCTAssertNotNil(modern.pendingReadiness)
        await speech.cancel()
        modern.pendingReadiness?.resume(returning: .unsupportedLanguage); modern.pendingReadiness = nil
        let cancelled = await pending.value
        XCTAssertEqual(cancelled, .checking)
        XCTAssertEqual(legacy.readinessChecks, 0)
        XCTAssertEqual(modern.starts, 0); XCTAssertEqual(legacy.starts, 0)
        modern.status = .ready
        let refreshed = await speech.readiness()
        XCTAssertEqual(refreshed, .ready)
        XCTAssertEqual(legacy.readinessChecks, 0)
    }
}

@MainActor
private final class LanguageRoutingSpeech: SpeechTranscribing {
    var status: SpeechReadiness
    var language: CaptureLanguage = .english
    var starts = 0, finishes = 0, cancels = 0, authorizations = 0, installations = 0, readinessChecks = 0
    var failStart = false, delayReadiness = false
    var pendingReadiness: CheckedContinuation<SpeechReadiness, Never>?
    init(status: SpeechReadiness) { self.status = status }
    func configure(language: CaptureLanguage) { self.language = language }
    func readiness() async -> SpeechReadiness {
        readinessChecks += 1
        if delayReadiness {
            delayReadiness = false
            return await withCheckedContinuation { pendingReadiness = $0 }
        }
        return status
    }
    func requestAuthorization() async { authorizations += 1 }
    func installAssets() async throws { installations += 1 }
    func start() async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        starts += 1
        if failStart { throw TranscriptionFailure.failed }
        return AsyncThrowingStream { $0.finish() }
    }
    func finish() async throws { finishes += 1 }
    func cancel() async { cancels += 1 }
}


extension LegacySpeechTranscriberTests {
    func testOldReservationsMakeRoomForAllNineLanguagesWithoutAccumulatingSlots() async throws {
        let inventory = ReservationInventory(limit: 2, reserved: ["en-US", "es-ES"])
        let manager = SpeechAssetReservationManager(inventory: inventory)
        for language in CaptureLanguage.allCases {
            let owner = UUID()
            try await manager.acquire(Locale(identifier: language.rawValue), owner: owner)
            XCTAssertTrue(inventory.reserved.contains { $0.identifier == Locale(identifier: language.rawValue).identifier })
            XCTAssertLessThanOrEqual(inventory.reserved.count, 2)
            manager.release(owner: owner)
        }
        XCTAssertFalse(inventory.released.isEmpty)
        XCTAssertEqual(Set(inventory.reserved.map(\.identifier)).count, inventory.reserved.count)
    }

    func testActiveRecognitionAndDownloadsCannotBeEvictedToInstallAnotherLanguage() async throws {
        let inventory = ReservationInventory(limit: 2, reserved: [])
        let manager = SpeechAssetReservationManager(inventory: inventory)
        let recording = UUID(), download = UUID(), german = UUID()
        try await manager.acquire(Locale(identifier: "en-US"), owner: recording)
        try await manager.acquire(Locale(identifier: "es-ES"), owner: download)
        do {
            try await manager.acquire(Locale(identifier: "de-DE"), owner: german)
            XCTFail("An active model must never be released")
        } catch { guard case TranscriptionFailure.assetReservationUnavailable = error else { return XCTFail("Unexpected error: \(error)") }
        }
        XCTAssertTrue(inventory.released.isEmpty)
        manager.release(owner: download)
        try await manager.acquire(Locale(identifier: "de-DE"), owner: german)
        XCTAssertEqual(inventory.released, ["es-ES"])
        XCTAssertTrue(inventory.reserved.contains { $0.identifier == "en-US" })
    }

    func testSharedLocaleRemainsProtectedUntilEveryOwnerFinishesAndVariantsDoNotTakeAnotherSlot() async throws {
        let inventory = ReservationInventory(limit: 1, reserved: ["en-US"])
        let manager = SpeechAssetReservationManager(inventory: inventory)
        let first = UUID(), second = UUID()
        try await manager.acquire(Locale(identifier: "en_US"), owner: first)
        try await manager.acquire(Locale(identifier: "en-US"), owner: second)
        XCTAssertEqual(inventory.reserveCalls, 0)
        manager.release(owner: first)
        do { try await manager.acquire(Locale(identifier: "de-DE"), owner: UUID()); XCTFail("Second owner still uses English") }
        catch { guard case TranscriptionFailure.assetReservationUnavailable = error else { return XCTFail("Unexpected error") } }
        XCTAssertTrue(inventory.released.isEmpty)
        manager.release(owner: second)
        try await manager.acquire(Locale(identifier: "de-DE"), owner: UUID())
        XCTAssertEqual(inventory.released, ["en-US"])
    }

    func testFailedReleaseHasBoundedRecoveryAndDoesNotAttemptOverQuotaReservation() async throws {
        let inventory = ReservationInventory(limit: 1, reserved: ["en-US"])
        inventory.refuseRelease = true
        let manager = SpeechAssetReservationManager(inventory: inventory)
        do { try await manager.acquire(Locale(identifier: "de-DE"), owner: UUID()); XCTFail("Expected an explanatory failure") }
        catch { guard case TranscriptionFailure.assetReservationUnavailable = error else { return XCTFail("Unexpected error") } }
        XCTAssertEqual(inventory.releaseCalls, 1)
        XCTAssertEqual(inventory.reserveCalls, 0)
    }

    func testCancelledReservationCannotLeaveAnInvisibleOwnerThatBlocksRetry() async throws {
        let inventory = ReservationInventory(limit: 1, reserved: [])
        inventory.pauseReserve = true
        let manager = SpeechAssetReservationManager(inventory: inventory)
        let cancelled = Task { try await manager.acquire(Locale(identifier: "en-US"), owner: UUID()) }
        for _ in 0..<200 where inventory.pendingReserve == nil { await Task.yield() }
        let pending = try XCTUnwrap(inventory.pendingReserve)
        cancelled.cancel(); pending.resume(); inventory.pendingReserve = nil
        do { try await cancelled.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        try await manager.acquire(Locale(identifier: "de-DE"), owner: UUID())
        XCTAssertEqual(inventory.released, ["en-US"])
    }
}

@MainActor
private final class ReservationInventory: SpeechAssetInventoryAccess {
    let maximumReservations: Int
    var reserved: [Locale]
    var released: [String] = []
    var reserveCalls = 0, releaseCalls = 0
    var refuseRelease = false, pauseReserve = false
    var pendingReserve: CheckedContinuation<Void, Never>?
    init(limit: Int, reserved: [String]) {
        maximumReservations = limit; self.reserved = reserved.map { Locale(identifier: $0) }
    }
    func reservations() async -> [Locale] { reserved }
    func key(for locale: Locale) async -> String {
        locale.identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }
    func reserve(_ locale: Locale) async throws {
        reserveCalls += 1
        if pauseReserve {
            pauseReserve = false
            await withCheckedContinuation { pendingReserve = $0 }
        }
        guard reserved.count < maximumReservations else { throw TranscriptionFailure.assetReservationUnavailable }
        reserved.append(locale)
    }
    func release(_ locale: Locale) async -> Bool {
        releaseCalls += 1
        guard !refuseRelease else { return false }
        let before = reserved.count
        reserved.removeAll { $0.identifier == locale.identifier }
        released.append(locale.identifier)
        return reserved.count != before
    }
}


extension LegacySpeechTranscriberTests {
    func testInstallableDictationIsUsedBeforeLegacyWhenModernLanguageIsUnsupported() async throws {
        let modern = LanguageRoutingSpeech(status: .unsupportedLanguage)
        let dictation = LanguageRoutingSpeech(status: .missingAssets)
        let legacy = LanguageRoutingSpeech(status: .ready)
        let fallback = LanguageSpeechTranscriber(preferred: dictation, compatibility: legacy)
        let speech = LanguageSpeechTranscriber(preferred: modern, compatibility: fallback)
        speech.configure(language: .russian)
        let readiness = await speech.readiness()
        XCTAssertEqual(readiness, .missingAssets)
        XCTAssertEqual(dictation.language, .russian)
        XCTAssertEqual(legacy.readinessChecks, 0)
        try await speech.installAssets()
        XCTAssertEqual(dictation.installations, 1)
        XCTAssertEqual(modern.installations, 0)
        XCTAssertEqual(legacy.installations, 0)
        dictation.status = .ready
        _ = try await speech.start()
        XCTAssertEqual(dictation.starts, 1)
        XCTAssertEqual(legacy.starts, 0)
        XCTAssertEqual(modern.starts, 0)
        try await speech.finish()
        await speech.cancel()
        XCTAssertEqual(dictation.finishes, 1)
        XCTAssertEqual(dictation.cancels, 1)
    }

    func testUnsupportedDictationPreservesExistingOfflineLegacyPermissionFlow() async {
        let modern = LanguageRoutingSpeech(status: .unsupportedDevice)
        let dictation = LanguageRoutingSpeech(status: .unsupportedLanguage)
        let legacy = LanguageRoutingSpeech(status: .authorizationRequired)
        let speech = LanguageSpeechTranscriber(preferred: modern,
            compatibility: LanguageSpeechTranscriber(preferred: dictation, compatibility: legacy))
        speech.configure(language: .dutch)
        let readiness = await speech.readiness()
        XCTAssertEqual(readiness, .authorizationRequired)
        await speech.requestAuthorization()
        XCTAssertEqual(legacy.authorizations, 1)
        XCTAssertEqual(dictation.authorizations, 0)
        XCTAssertEqual(modern.starts + dictation.starts + legacy.starts, 0)
    }
}
