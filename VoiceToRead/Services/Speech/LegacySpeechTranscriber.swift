import Foundation

/// Offline-only compatibility engine. Audio arriving during request finalization waits in a bounded queue.
/// Cada solicitud tiene identidad y desplazamiento temporal propios. La cola conserva audio
/// entrante mientras finaliza la solicitud anterior; el límite evita crecimiento de memoria sin control.
@MainActor
final class LegacySpeechTranscriber: SpeechTranscribing {
    private let audio: any SpeechAudioCapturing
    private let backend: any LegacySpeechRecognizing
    private let requestDuration: Double
    private let finalizationTimeout: Duration
    private var generation = UUID()
    private var runID = UUID()
    private var runCompleted = false
    private var runEnd: Double = 0
    private var runOffset: Double?
    private var raw: AsyncThrowingStream<CapturedAudio, Error>.Continuation?
    private var output: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation?
    private var processing: Task<Void, Never>?
    private var levels: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var timeout: Task<Void, Never>?
    private var finalWaiter: CheckedContinuation<Void, Error>?
    private var lastAudioAt = ContinuousClock.now
    private var terminalError: Error?

    init(audio: any SpeechAudioCapturing, backend: any LegacySpeechRecognizing,
         requestDuration: Double = 50, finalizationTimeout: Duration = .seconds(10)) {
        self.audio = audio
        self.backend = backend
        self.requestDuration = requestDuration
        self.finalizationTimeout = finalizationTimeout
    }

    convenience init(audio: any SpeechAudioCapturing) {
        self.init(audio: audio, backend: LegacySpeechBackend())
    }

    func configure(language: CaptureLanguage) { backend.configure(language: language) }

    func readiness() async -> SpeechReadiness {
        switch backend.authorization {
        case .notDetermined: return .authorizationRequired
        case .denied: return .authorizationDenied
        case .restricted: return .authorizationRestricted
        case .authorized: break
        @unknown default: return .problem("Speech permission is unavailable.")
        }
        guard backend.supportsLocale else { return .unsupportedLanguage }
        guard backend.supportsOnDeviceRecognition else { return .systemModelUnavailable }
        guard backend.isAvailable else { return .problem("On-device speech recognition is temporarily unavailable. Try again later.") }
        return .ready
    }

    func requestAuthorization() async { await backend.requestAuthorization() }
    func installAssets() async throws {
        // SFSpeechRecognizer has no explicit model installation API.
        throw TranscriptionFailure.notReady
    }

    func start() async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        await cancel()
        let identifier = UUID()
        generation = identifier
        guard await readiness() == .ready else { throw TranscriptionFailure.notReady }
        guard generation == identifier, !Task.isCancelled else { throw CancellationError() }
        terminalError = nil
        let frames = AsyncThrowingStream<CapturedAudio, Error>.makeStream(bufferingPolicy: .bufferingOldest(128))
        let updates = AsyncThrowingStream<TranscriptionUpdate, Error>.makeStream(bufferingPolicy: .bufferingOldest(256))
        raw = frames.continuation
        output = updates.continuation
        audio.audioSink = { frame in
            if case .dropped = frames.continuation.yield(frame) {
                frames.continuation.finish(throwing: TranscriptionFailure.overflow)
            }
        }
        audio.onFailure = { [weak self] failure in
            guard let self, self.generation == identifier else { return }
            self.complete(error: TranscriptionFailure.interrupted(failure.message))
        }
        do {
            try beginRun(identifier: identifier)
            let meter = try audio.start()
            lastAudioAt = .now
            levels = Task { [weak self] in
                for await level in meter {
                    guard let self, self.generation == identifier, !Task.isCancelled else { return }
                    self.lastAudioAt = .now
                    self.audio.onLevel?(level)
                }
            }
            watchdog = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    guard let self, self.generation == identifier else { return }
                    if self.lastAudioAt.duration(to: .now) > .seconds(5) {
                        self.complete(error: TranscriptionFailure.interrupted(CaptureFailure.stalled.message))
                        return
                    }
                }
            }
            processing = Task { [weak self] in
                guard let self else { return }
                do {
                    var seconds = 0.0
                    for try await frame in frames.stream {
                        try Task.checkCancellation()
                        guard self.generation == identifier else { return }
                        if self.runCompleted || seconds >= self.requestDuration {
                            try await self.finishRun(identifier: identifier)
                            try Task.checkCancellation()
                            guard self.generation == identifier else { return }
                            try self.beginRun(identifier: identifier)
                            seconds = 0
                        }
                        if seconds == 0 { self.runOffset = frame.sessionStart }
                        self.backend.append(frame)
                        seconds += Double(frame.buffer.frameLength) / frame.buffer.format.sampleRate
                    }
                    try Task.checkCancellation()
                    try await self.finishRun(identifier: identifier)
                    guard self.generation == identifier else { return }
                    self.complete(error: nil)
                } catch {
                    guard self.generation == identifier else { return }
                    self.complete(error: error)
                }
            }
            return updates.stream
        } catch {
            complete(error: error)
            throw error
        }
    }

    private func beginRun(identifier: UUID) throws {
        runID = UUID()
        runCompleted = false
        runEnd = 0
        runOffset = nil
        let currentRun = runID
        try backend.start { [weak self] event in
            guard let self, self.generation == identifier, self.runID == currentRun else { return }
            switch event {
            case .success(let result):
                guard !self.runCompleted else { return }
                // Legacy results are cumulative for a whole request, not independent sentence ranges.
                self.runEnd = max(self.runEnd, result.end.isFinite ? result.end : 0, 0.001)
                let offset = self.runOffset ?? 0
                let update = TranscriptionUpdate(runID: currentRun, start: offset, end: offset + self.runEnd,
                    text: result.text, isFinal: result.isFinal,
                    words: result.words.map { TimedWord(text: $0.text, start: offset + $0.start, end: offset + $0.end) },
                    sessionTime: self.runOffset != nil)
                if case .dropped = self.output?.yield(update) {
                    self.complete(error: TranscriptionFailure.overflow)
                    return
                }
                if result.isFinal {
                    self.runCompleted = true
                    self.timeout?.cancel()
                    let waiter = self.finalWaiter
                    self.finalWaiter = nil
                    waiter?.resume()
                }
            case .failure(let error): self.complete(error: error)
            }
        }
    }

    private func finishRun(identifier: UUID) async throws {
        guard generation == identifier else { throw CancellationError() }
        if runCompleted { return }
        try await withCheckedThrowingContinuation { continuation in
            finalWaiter = continuation
            timeout = Task { [weak self] in
                guard let self else { return }
                do { try await Task.sleep(for: self.finalizationTimeout) } catch { return }
                guard self.generation == identifier else { return }
                self.complete(error: TranscriptionFailure.finalizationTimeout)
            }
            backend.endAudio()
        }
    }

    func finish() async throws {
        guard output != nil else {
            if let terminalError { throw terminalError }
            return
        }
        do { try audio.stop() } catch { complete(error: error); throw error }
        audio.audioSink = nil
        levels?.cancel()
        watchdog?.cancel()
        raw?.finish()
        let task = processing
        await task?.value
        if let terminalError { throw terminalError }
    }

    func cancel() async { complete(error: CancellationError()) }

    private func complete(error: Error?) {
        generation = UUID()
        terminalError = error
        audio.audioSink = nil
        audio.onFailure = nil
        do { try audio.stop() } catch { if terminalError == nil { terminalError = error } }
        backend.cancel()
        raw?.finish()
        raw = nil
        processing?.cancel()
        processing = nil
        levels?.cancel()
        levels = nil
        watchdog?.cancel()
        watchdog = nil
        timeout?.cancel()
        timeout = nil
        let waiter = finalWaiter
        finalWaiter = nil
        if let terminalError {
            output?.finish(throwing: terminalError)
            waiter?.resume(throwing: terminalError)
        } else {
            output?.finish()
            waiter?.resume()
        }
        output = nil
    }
}
