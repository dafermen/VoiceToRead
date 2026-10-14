import XCTest
@testable import VoiceToRead

@MainActor
final class ListeningViewModelTests: XCTestCase {
    func testCancelledPermissionRequestDoesNotCapture() async {
        let audio = MockAudio()
        audio.permission = .undetermined
        let model = ListeningViewModel(audio: audio)
        let start = Task { await model.start() }
        while audio.permissionContinuation == nil { await Task.yield() }
        start.cancel()
        audio.resolvePermission(granted: true)
        await start.value
        XCTAssertEqual(audio.starts, 0)
        XCTAssertEqual(model.state, .ready)
    }

    func testSettingsGrantRecoversAndFailureSurvivesForeground() async {
        let audio = MockAudio()
        audio.permission = .denied
        let model = ListeningViewModel(audio: audio)
        await model.start()
        audio.permission = .granted
        model.enteredForeground()
        XCTAssertEqual(model.state, .ready)
        XCTAssertFalse(model.showSettings)
        await model.start()
        audio.onFailure?(.interruption)
        model.enteredForeground()
        XCTAssertEqual(model.state, .error(.interruption))
        XCTAssertEqual(audio.starts, 1)
    }

    func testUnexpectedStreamEndStopsCapture() async {
        let audio = MockAudio()
        let model = ListeningViewModel(audio: audio)
        await model.start()
        audio.endStream()
        for _ in 0..<100 {
            if model.state != .listening { break }
            await Task.yield()
        }
        XCTAssertEqual(model.state, .error(.stalled))
        XCTAssertEqual(audio.stops, 1)
    }
    func testGrantedStartStopAndRepeat() async {
        let audio = MockAudio()
        let model = ListeningViewModel(audio: audio)
        await model.start()
        XCTAssertEqual(model.state, .listening)
        await model.start()
        XCTAssertEqual(audio.starts, 1)
        model.stop()
        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.level, 0)
        await model.start()
        XCTAssertEqual(audio.starts, 2)
        model.stop()
    }

    func testDeniedDoesNotStartAndOffersSettings() async {
        let audio = MockAudio()
        audio.permission = .denied
        let model = ListeningViewModel(audio: audio)
        await model.start()
        XCTAssertEqual(model.state, .error(.permissionDenied))
        XCTAssertTrue(model.showSettings)
        XCTAssertEqual(audio.starts, 0)
    }

    func testPermissionRequestDoesNotStartUntilGranted() async {
        let audio = MockAudio()
        audio.permission = .undetermined
        let model = ListeningViewModel(audio: audio)
        let start = Task { await model.start() }
        while audio.permissionContinuation == nil { await Task.yield() }
        XCTAssertEqual(model.state, .requestingPermission)
        audio.resolvePermission(granted: true)
        await start.value
        XCTAssertEqual(model.state, .listening)
        model.stop()
    }

    func testStopDuringPermissionPromptPreventsLateStart() async {
        let audio = MockAudio()
        audio.permission = .undetermined
        let model = ListeningViewModel(audio: audio)
        let start = Task { await model.start() }
        while audio.permissionContinuation == nil { await Task.yield() }
        model.stop()
        audio.resolvePermission(granted: true)
        await start.value
        XCTAssertEqual(audio.starts, 0)
        XCTAssertEqual(model.state, .ready)
    }

    func testBackgroundDuringPermissionPromptPreventsLateStart() async {
        let audio = MockAudio()
        audio.permission = .undetermined
        let model = ListeningViewModel(audio: audio)
        let start = Task { await model.start() }
        while audio.permissionContinuation == nil { await Task.yield() }
        model.enteredBackground()
        audio.resolvePermission(granted: true)
        await start.value
        XCTAssertEqual(audio.starts, 0)
        model.enteredForeground()
        XCTAssertEqual(model.state, .ready)
        XCTAssertNotNil(model.notice)
    }

    func testEngineErrorsAndCleanupFailureAreVisible() async {
        let audio = MockAudio()
        audio.startFailure = .noInput
        let model = ListeningViewModel(audio: audio)
        await model.start()
        XCTAssertEqual(model.state, .error(.noInput))
        XCTAssertEqual(audio.stops, 1)
        audio.startFailure = nil
        await model.start()
        audio.stopFailure = true
        model.stop()
        XCTAssertEqual(model.state, .error(.sessionFailure))
    }

    func testInterruptionsStopAndRequireExplicitRestart() async {
        for failure in [CaptureFailure.interruption, .routeChanged, .configurationChanged, .mediaServicesChanged] {
            let audio = MockAudio()
            let model = ListeningViewModel(audio: audio)
            await model.start()
            audio.onFailure?(failure)
            XCTAssertEqual(model.state, .error(failure))
            XCTAssertEqual(audio.stops, 1)
            XCTAssertEqual(audio.starts, 1)
            model.enteredForeground()
            XCTAssertEqual(audio.starts, 1)
        }
    }

    func testBackgroundStopsAndForegroundDoesNotRestart() async {
        let audio = MockAudio()
        let model = ListeningViewModel(audio: audio)
        await model.start()
        model.enteredBackground()
        XCTAssertEqual(model.state, .ready)
        await model.start()
        XCTAssertEqual(audio.starts, 1)
        model.enteredForeground()
        XCTAssertEqual(audio.starts, 1)
        XCTAssertEqual(model.state, .ready)
    }

    func testPermissionDeniedAfterPromptAndUnknownPermission() async {
        let audio = MockAudio()
        audio.permission = .undetermined
        let model = ListeningViewModel(audio: audio)
        let start = Task { await model.start() }
        while audio.permissionContinuation == nil { await Task.yield() }
        audio.resolvePermission(granted: false)
        await start.value
        XCTAssertEqual(model.state, .error(.permissionDenied))
        XCTAssertEqual(audio.starts, 0)
        audio.permission = .unavailable
        await model.start()
        XCTAssertEqual(model.state, .error(.permissionUnavailable))
    }
}

@MainActor
private final class MockAudio: AudioCapturing {
    var permission: MicrophonePermission = .granted
    var onFailure: (@MainActor @Sendable (CaptureFailure) -> Void)?
    var permissionContinuation: CheckedContinuation<Bool, Never>?
    var startFailure: CaptureFailure?
    var stopFailure = false
    var starts = 0
    var stops = 0
    private var streamContinuation: AsyncStream<Float>.Continuation?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { permissionContinuation = $0 }
    }

    func resolvePermission(granted: Bool) {
        permission = granted ? .granted : .denied
        permissionContinuation?.resume(returning: granted)
        permissionContinuation = nil
    }

    func start() throws -> AsyncStream<Float> {
        starts += 1
        if let startFailure { throw startFailure }
        let stream = AsyncStream<Float>.makeStream(bufferingPolicy: .bufferingNewest(1))
        streamContinuation = stream.continuation
        return stream.stream
    }

    func endStream() {
        streamContinuation?.finish()
    }
    func stop() throws {
        stops += 1
        streamContinuation?.finish()
        streamContinuation = nil
        if stopFailure { throw CaptureFailure.sessionFailure }
    }
}
