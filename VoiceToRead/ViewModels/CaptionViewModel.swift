import Foundation
import Observation

enum CaptionState: Equatable {
    case idle, preparing, listening, stopping, paused, ended
    case problem(String)
    var busy: Bool { self == .preparing || self == .stopping }
    var active: Bool { self == .listening || self == .preparing }
}

/// Máquina de estados de la escucha: transforma resultados de Speech en estado para SwiftUI.
/// Las dependencias se inyectan para probar permisos y resultados sin usar un micrófono real.
/// No escribe SwiftData directamente: comunica cambios al coordinador mediante callbacks.
@MainActor
@Observable
final class CaptionViewModel {
    private(set) var state: CaptionState = .idle
    private(set) var language: CaptureLanguage = .english
    private(set) var readiness: SpeechReadiness = .checking
    private(set) var transcript = TranscriptAssembler()
    private(set) var startedAt: Date?
    private(set) var elapsed: TimeInterval = 0
    private(set) var permissionDenied = false
    private(set) var microphonePermission: MicrophonePermission = .undetermined
    private(set) var preparationPending = false
    private(set) var inputLevel: Float = 0
    @ObservationIgnored private var lastMeterUpdate = Date.distantPast
    var isRecordingAudio: Bool { state == .listening && recordingPrepared }
    var canResume: Bool { startedAt != nil && (state == .paused || isProblem) && !preparationPending }
    private(set) var notice: String?
    // Snapshot of global choices for this capture; the coordinator restores defaults after reset.
    var reduceBackgroundNoise = false
    var saveAudio = false
    var continueInBackground = false
    private(set) var recordingPrepared = false
    var canChooseCaptureOptions: Bool { startedAt == nil && !recordingPrepared && !state.active && !state.busy && !preparationPending && state != .ended }
    func prepareRecording(at url: URL) throws {
        guard let capture = microphone as? AudioCaptureService else { throw RecordingFailure.unavailable }
        guard !recordingPrepared else { return }
        capture.recorder = SessionAudioRecorder(url: url)
        recordingPrepared = true
    }

    var onFinalized: ((FinalizedChange) -> Void)?
    var onEnded: (() -> Void)?
    var onPrepareCapture: (() -> Void)?
    var onWillStart: (() throws -> Void)?
    var onRunStarted: (() -> Void)?
    var onCheckpoint: ((TimeInterval) -> Void)?
    @ObservationIgnored private let microphone: any AudioCapturing
    @ObservationIgnored private let speech: any SpeechTranscribing
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var consumer: Task<Void, Never>?
    @ObservationIgnored private var foreground = true
    @ObservationIgnored private var activeSince: ContinuousClock.Instant?

    init(microphone: any AudioCapturing, speech: any SpeechTranscribing) {
        self.microphone = microphone
        microphonePermission = microphone.permission
        self.speech = speech
        microphone.onLevel = { [weak self] value in
            guard let self, self.state == .listening, value.isFinite,
                  Date().timeIntervalSince(self.lastMeterUpdate) >= 0.1 else { return }
            self.lastMeterUpdate = Date()
            self.inputLevel = min(max(value, 0), 1)
        }
    }

    /// El compilador decide si conoce el motor moderno; el iOS del teléfono decide si puede usarlo.
    /// Disponibilidad de API no implica modelo instalado: readiness comprueba esa condición después.
    convenience init() {
        let audio = AudioCaptureService()
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.init(microphone: audio, speech: AppleSpeechTranscriber(audio: audio))
            return
        }
#endif
        self.init(microphone: audio, speech: LegacySpeechTranscriber(audio: audio))
    }

    /// Capture language is fixed after the first start, including paused/failed resumable runs.
    func configureLanguage(_ language: CaptureLanguage) {
        guard canChooseCaptureOptions, self.language != language else { return }
        self.language = language
        speech.configure(language: language)
        readiness = .checking
    }

    func refreshMicrophonePermission() {
        microphonePermission = microphone.permission
        permissionDenied = microphonePermission == .denied
    }

    func requestMicrophonePermission() async {
        guard !state.active, !state.busy, !preparationPending else { return }
        preparationPending = true
        defer { preparationPending = false }
        _ = await microphone.requestPermission()
        refreshMicrophonePermission()
    }

    func requestSpeechPermission() async {
        guard !state.active, !state.busy, !preparationPending else { return }
        preparationPending = true
        defer { preparationPending = false }
        await speech.requestAuthorization()
        await checkReadiness()
    }

    func checkReadiness() async {
        let selected = language
        let result = await speech.readiness()
        if selected == language { readiness = result }
    }

    func installAssets() async {
        guard !state.active, !state.busy, !preparationPending, readiness != .downloading else { return }
        preparationPending = true
        defer { preparationPending = false }
        readiness = .downloading
        do { try await speech.installAssets(); await checkReadiness() }
        catch { readiness = .problem(error.localizedDescription) }
    }

    /// Cada intento recibe una generación. Tras un await, esa identidad evita aplicar respuestas
    /// antiguas si el usuario canceló, salió de la app o inició otra operación mientras esperaba.
    func start() async {
        guard foreground, !state.active, !state.busy, !preparationPending, state != .ended else { return }
        onPrepareCapture?()
        preparationPending = true
        defer { preparationPending = false }
        let identifier = UUID()
        generation = identifier
        notice = nil
        state = .preparing
        readiness = await speech.readiness()
        guard generation == identifier, foreground else { return }
        guard !Task.isCancelled else { await abort(message: "Start cancelled."); return }
        guard readiness == .ready else { state = .problem(readiness.description); return }
        if microphone.permission == .undetermined {
            _ = await microphone.requestPermission()
        }
        guard generation == identifier, foreground else { return }
        guard !Task.isCancelled else { await abort(message: "Start cancelled."); return }
        refreshMicrophonePermission()
        guard microphone.permission == .granted else {
            permissionDenied = true
            state = .problem(CaptureFailure.permissionDenied.message)
            return
        }
        refreshMicrophonePermission()
        permissionDenied = false
        do {
            try microphone.configureNoiseReduction(reduceBackgroundNoise)
            if startedAt == nil { try onWillStart?() }
            let updates = try await speech.start()
            guard generation == identifier, foreground else { await speech.cancel(); return }
            if startedAt == nil { startedAt = Date() }
            activeSince = .now
            state = .listening
            onRunStarted?()
            consumer = Task { @MainActor [weak self] in
                do {
                    for try await update in updates {
                        guard let self, self.generation == identifier, !Task.isCancelled else { return }
                        let change = self.transcript.apply(update)
                        if self.transcript.partial.count > 64 { throw TranscriptionFailure.overflow }
                        if !change.upserted.isEmpty || !change.removedIDs.isEmpty {
                            self.onFinalized?(change)
                        }
                    }
                    guard let self, self.generation == identifier, self.state == .listening else { return }
                    await self.abort(message: "Speech recognition ended unexpectedly. Tap Resume to continue.")
                } catch {
                    guard let self, self.generation == identifier else { return }
                    if self.state == .stopping {
                        self.notice = error.localizedDescription
                        return
                    }
                    await self.abort(message: error.localizedDescription)
                }
            }
        } catch {
            guard generation == identifier else { return }
            state = .problem(error.localizedDescription)
        }
    }

    func stop() async {
        guard state.active || state == .paused || isProblem else { return }
        if state == .listening {
            state = .stopping
            settleDuration()
            do { try await speech.finish() }
            catch { notice = error.localizedDescription }
            await consumer?.value
        } else {
            state = .stopping
            generation = UUID()
            await speech.cancel()
        }
        generation = UUID()
        consumer?.cancel()
        consumer = nil
        transcript.discardPartial()
        if let capture = microphone as? AudioCaptureService {
            do { try capture.recorder?.finish() }
            catch { notice = "Audio recording was interrupted. The saved portion is available in Sessions. " + error.localizedDescription }
        }
        state = .ended
        onEnded?()
    }

    func pause() async {
        guard state == .listening else { return }
        state = .stopping
        settleDuration()
        do {
            try await speech.finish()
            await consumer?.value
            generation = UUID()
            transcript.discardPartial()
            state = .paused
        } catch {
            await abort(message: error.localizedDescription)
        }
    }

    /// Called synchronously by scene changes so a queued cleanup cannot restart or prolong capture.
    func prepareForBackground() -> UUID? {
        foreground = false
        if continueInBackground && state == .listening { return nil }
        guard state.active else { return nil }
        generation = UUID()
        do { try microphone.stop() } catch { notice = CaptureFailure.sessionFailure.message }
        settleDuration()
        consumer?.cancel()
        consumer = nil
        transcript.discardPartial()
        state = .problem("Listening stopped in the background. Tap Resume to continue. Unfinished captions may be lost.")
        return generation
    }

    func cleanupBackground(_ identifier: UUID) async {
        guard generation == identifier else { return }
        await speech.cancel()
    }

    func background() async {
        if let identifier = prepareForBackground() { await cleanupBackground(identifier) }
    }

    func foregrounded() { foreground = true; refreshMicrophonePermission(); Task { await checkReadiness() } }

    func reset() async {
        generation = UUID()
        state = .stopping
        consumer?.cancel()
        consumer = nil
        await speech.cancel()
        if let capture = microphone as? AudioCaptureService {
            try? capture.recorder?.finish()
            capture.recorder = nil
            capture.timeline.reset()
        }
        recordingPrepared = false
        saveAudio = false
        reduceBackgroundNoise = false
        continueInBackground = false
        transcript = TranscriptAssembler()
        startedAt = nil
        elapsed = 0
        activeSince = nil
        inputLevel = 0
        notice = nil
        state = .idle
    }

    func currentDuration(at now: Date) -> TimeInterval {
        elapsed + (activeSince.map { SessionClock.seconds($0.duration(to: .now)) } ?? 0)
    }

    private var isProblem: Bool { if case .problem = state { true } else { false } }

    private func settleDuration() {
        inputLevel = 0
        if let activeSince { elapsed += SessionClock.seconds(activeSince.duration(to: .now)) }
        activeSince = nil
        onCheckpoint?(elapsed)
    }

    private func abort(message: String) async {
        generation = UUID()
        settleDuration()
        consumer?.cancel()
        consumer = nil
        await speech.cancel()
        transcript.discardPartial()
        state = .problem(message)
    }
}
