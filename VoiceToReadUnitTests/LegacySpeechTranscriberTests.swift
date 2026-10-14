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
