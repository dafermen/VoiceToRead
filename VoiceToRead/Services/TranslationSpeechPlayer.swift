import Foundation
import AVFoundation
import Observation

/// Small boundary around Apple's speaker. Tests can finish a paragraph without downloading a voice.
@MainActor
protocol TranslationSpeechOutput: AnyObject {
    var onFinish: ((UUID) -> Void)? { get set }
    func speak(_ text: String, language: CaptureLanguage, rate: Float, token: UUID) throws
    func pause() -> Bool
    func resume() -> Bool
    func stop()
}

@MainActor
final class AppleTranslationSpeechOutput: NSObject, TranslationSpeechOutput, AVSpeechSynthesizerDelegate {
    var onFinish: ((UUID) -> Void)?
    private let synthesizer = AVSpeechSynthesizer()
    private var current: (utterance: AVSpeechUtterance, token: UUID)?

    override init() { super.init(); synthesizer.delegate = self }
    func speak(_ text: String, language: CaptureLanguage, rate: Float, token: UUID) throws {
        guard let voice = AVSpeechSynthesisVoice(language: language.rawValue) else { throw TranslationSpeechFailure.voiceUnavailable }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = rate
        current = (utterance, token)
        synthesizer.speak(utterance)
    }
    func pause() -> Bool { synthesizer.pauseSpeaking(at: .immediate) }
    func resume() -> Bool { synthesizer.continueSpeaking() }
    func stop() { current = nil; synthesizer.stopSpeaking(at: .immediate) }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Move only a value across actors. Retain the utterance until we process its completion.
        let identity = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, let current = self.current, ObjectIdentifier(current.utterance) == identity else { return }
            self.current = nil
            self.onFinish?(current.token)
        }
    }
}

enum TranslationSpeechFailure: LocalizedError {
    case voiceUnavailable
    var errorDescription: String? {
        "A voice for this language is unavailable. Download an English or Spanish voice in device Settings → Accessibility → Spoken Content → Voices, then try again."
    }
}

enum TranslationSpeechSpeed: String, CaseIterable, Identifiable {
    case slow = "Slow", normal = "Normal", fast = "Fast"
    var id: Self { self }
    var playbackRate: Float { self == .slow ? 0.75 : self == .fast ? 1.25 : 1 }
    var rate: Float {
        switch self { case .slow: return 0.35; case .normal: return AVSpeechUtteranceDefaultSpeechRate; case .fast: return 0.58 }
    }
}

/// Owns synthesized playback only; it never records, changes a transcript, or writes an audio file.
/// Queue one corrected destination paragraph at a time, so highlighting follows spoken text.
@MainActor @Observable
final class TranslationSpeechPlayer {
    var onFinish: (() -> Void)?
    var onInterrupted: (() -> Void)?
    enum State { case idle, speaking, paused }
    private(set) var state: State = .idle
    private(set) var paragraphID: UUID?
    private(set) var completedParagraphID: UUID?
    var message: String?
    private var queue: [ReviewParagraph] = []
    private var index = 0
    private var language: CaptureLanguage = .spanish
    private var rate = AVSpeechUtteranceDefaultSpeechRate
    private var token = UUID()
    private var ownsAudio = false
    private let output: TranslationSpeechOutput
    private let activate: () throws -> Void
    private let deactivate: () -> Void
    private var observers: [NSObjectProtocol] = []

    init(output: TranslationSpeechOutput? = nil,
         activate: @escaping () throws -> Void = {
             let session = AVAudioSession.sharedInstance()
             try session.setCategory(.playback, mode: .spokenAudio)
             try session.setActive(true)
         }, deactivate: @escaping () -> Void = {
             try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
         }) {
        self.output = output ?? AppleTranslationSpeechOutput()
        self.activate = activate; self.deactivate = deactivate
        self.output.onFinish = { [weak self] token in self?.finished(token) }
    }

    /// Refuse stale translations and always apply the user's saved edits before speaking.
    static func paragraphs(snapshot: TranslationSnapshot?, source: [ReviewParagraph], id: UUID? = nil) -> [ReviewParagraph] {
        guard let snapshot, snapshot.isCurrent(source) else { return [] }
        return snapshot.translated.filter { (id == nil || $0.id == id) && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    func start(_ paragraphs: [ReviewParagraph], language: CaptureLanguage, speed: TranslationSpeechSpeed) {
        stop(); message = nil
        queue = paragraphs.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !queue.isEmpty else { return }
        self.language = language; rate = speed.rate; index = 0
        do {
            try activate(); ownsAudio = true
            state = .speaking
            try speakCurrent()
        } catch {
            stop()
            message = error is TranslationSpeechFailure ? error.localizedDescription : "Translation audio could not start. Please try again."
        }
    }
    func togglePause() {
        switch state {
        case .speaking:
            if output.pause() { state = .paused }
            else { interrupt() }
        case .paused:
            // A paragraph can finish just as Pause is pressed. Do not start the next until Resume.
            if paragraphID == nil {
                state = .speaking
                do { try speakCurrent() } catch { interrupt() }
            } else if output.resume() { state = .speaking }
            else { interrupt() }
        case .idle: break
        }
    }
    func stop() {
        token = UUID() // Reject late callbacks from a previous phrase or a dismissed screen.
        output.stop(); queue = []; index = 0; completedParagraphID = nil; paragraphID = nil; state = .idle
        if ownsAudio { deactivate(); ownsAudio = false }
    }
    func interrupt() {
        guard state != .idle else { return }
        stop(); message = "Translation interrupted. Tap Play to restart this paragraph."; onInterrupted?()
    }
    private func speakCurrent() throws {
        guard queue.indices.contains(index) else { stop(); return }
        paragraphID = queue[index].id
        token = UUID()
        try output.speak(queue[index].text, language: language, rate: rate, token: token)
    }
    private func finished(_ completed: UUID) {
        guard completed == token, state != .idle else { return }
        token = UUID(); index += 1; paragraphID = nil
        guard index < queue.count else {
            let last = queue.last?.id
            stop(); completedParagraphID = last
            onFinish?()
            return
        }
        guard state == .speaking else { return }
        do { try speakCurrent() } catch { interrupt() }
    }
    func observeInterruptions() {
        guard observers.isEmpty else { return }
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
                     AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if name == AVAudioSession.interruptionNotification {
                    let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
                    guard type == AVAudioSession.InterruptionType.began.rawValue else { return }
                }
                if name == AVAudioSession.routeChangeNotification {
                    let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
                    guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue ||
                          reason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue else { return }
                }
                Task { @MainActor [weak self] in self?.interrupt() }
            })
        }
    }
    func close() {
        stop(); observers.forEach(NotificationCenter.default.removeObserver); observers = []
    }
}


/// A queue contains one language at a time: original then translation, before advancing the paragraph.
/// Recorded ranges are preferred; without a recording the corrected original is synthesized.
struct ParagraphAudioStep: Equatable {
    let paragraph: ReviewParagraph
    let language: CaptureLanguage
    let translated: Bool
    let recording: ClosedRange<Double>?

    static func make(source: [ReviewParagraph], translated: [ReviewParagraph], language: CaptureLanguage,
                     mode: TranscriptLanguage, ranges: [PlaybackParagraph]) -> [Self] {
        source.flatMap { original -> [Self] in
            var result: [Self] = []
            if mode == language.mode || mode == .both, !original.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let range = ranges.first { $0.id == original.id }
                result.append(Self(paragraph: original, language: language, translated: false,
                                   recording: range.map { $0.start...$0.end }))
            }
            if mode != language.mode, let text = translated.first(where: { $0.id == original.id }),
               !text.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(Self(paragraph: text, language: language.opposite, translated: true, recording: nil))
            }
            return result
        }
    }
}

/// Shared by inline paragraph controls and the bilingual media player. Completion, not a timer,
/// advances the queue. Stop, selection changes and interruptions invalidate the underlying callbacks.
@MainActor @Observable
final class ParagraphPlayback {
    enum State { case idle, playing, paused, completed }
    private(set) var state: State = .idle
    private(set) var paragraphID: UUID?
    private(set) var translated = false
    var message: String?
    private let recording: SessionPlayer
    private let voice: TranslationSpeechPlayer
    private var steps: [ParagraphAudioStep] = []
    private var index = 0
    private var speed: TranslationSpeechSpeed = .normal
    private var originalSpeed: TranslationSpeechSpeed = .normal
    private var gapSeconds = 0
    private(set) var waitingBetweenLanguages = false
    private var gapTask: Task<Void, Never>?
    private var gapToken = UUID()
    private var gapObservers: [NSObjectProtocol] = []
    private let wait: (Int) async throws -> Void
    private var current: ParagraphAudioStep? { steps.indices.contains(index) ? steps[index] : nil }
    init(recording: SessionPlayer? = nil, voice: TranslationSpeechPlayer? = nil,
         wait: @escaping (Int) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) {
        self.wait = wait
        self.recording = recording ?? SessionPlayer(); self.voice = voice ?? TranslationSpeechPlayer()
        self.recording.onFinish = { [weak self] in self?.advance() }
        self.voice.onFinish = { [weak self] in self?.advance() }
        self.recording.onInterrupted = { [weak self] in self?.interrupt() }
        self.voice.onInterrupted = { [weak self] in self?.interrupt() }
    }
    func load(_ url: URL?) {
        stop(); recording.stop()
        if let url { recording.load(url) }
        voice.observeInterruptions()
    }
    func start(_ steps: [ParagraphAudioStep], speed: TranslationSpeechSpeed,
               originalSpeed: TranslationSpeechSpeed? = nil, gapSeconds: Int = 0) {
        stop(); message = nil; self.steps = steps; self.speed = speed
        self.originalSpeed = originalSpeed ?? speed; self.gapSeconds = min(2, max(0, gapSeconds))
        guard !steps.isEmpty else { message = "No playable text in this paragraph."; return }
        observeGapInterruptions(); state = .playing; playCurrent()
    }
    private func playCurrent() {
        guard let step = current else { state = .completed; return }
        waitingBetweenLanguages = false
        paragraphID = step.paragraph.id; translated = step.translated
        let speed = step.translated ? self.speed : originalSpeed
        if let range = step.recording {
            recording.speed = speed; recording.select(range: range); recording.toggle()
            if let failure = recording.failure { stop(); message = failure }
        } else {
            voice.start([step.paragraph], language: step.language, speed: speed)
            if let failure = voice.message { stop(); message = failure }
        }
    }
    private func advance() {
        guard state == .playing || state == .paused else { return }
        let previous = current
        index += 1
        guard index < steps.count else { state = .completed; return }
        waitingBetweenLanguages = gapSeconds > 0 && previous?.paragraph.id == current?.paragraph.id && previous?.translated != current?.translated
        if state == .playing {
            if waitingBetweenLanguages { scheduleGap() } else { playCurrent() }
        }
    }
    /// Cancellation plus a token prevents an old timer from starting audio after Stop or navigation.
    private func scheduleGap() {
        gapTask?.cancel(); gapToken = UUID()
        let token = gapToken
        gapTask = Task { [weak self, wait, gapSeconds] in
            do { try await wait(gapSeconds) } catch { return }
            guard let self, !Task.isCancelled, self.gapToken == token, self.state == .playing else { return }
            self.playCurrent()
        }
    }
    func pause() {
        guard state == .playing else { return }
        state = .paused
        gapTask?.cancel(); gapToken = UUID()
        recording.pause()
        if voice.state == .speaking { voice.togglePause() }
    }
    func resume() {
        guard state == .paused, let step = current else { return }
        state = .playing
        // Resume gives the reader the full selected gap again, without skipping the translation.
        if waitingBetweenLanguages { scheduleGap(); return }
        if step.paragraph.id != paragraphID || step.translated != translated { playCurrent() }
        else if step.recording != nil {
            recording.toggle()
            if let failure = recording.failure { stop(); message = failure }
        }
        else if voice.state == .paused { voice.togglePause() }
        else { playCurrent() }
    }
    func stop() {
        gapTask?.cancel(); gapTask = nil; gapToken = UUID(); waitingBetweenLanguages = false
        state = .idle; steps = []; index = 0; paragraphID = nil
        recording.pause(); voice.stop()
    }
    func interrupt() {
        guard state == .playing || state == .paused else { return }
        stop(); message = "Playback interrupted. Tap Play to restart this paragraph."
    }
    /// Engines are idle during the gap, so the queue itself must observe interruptions too.
    private func observeGapInterruptions() {
        guard gapObservers.isEmpty else { return }
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification, AVAudioSession.mediaServicesWereResetNotification] {
            gapObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                if name == AVAudioSession.interruptionNotification,
                   (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue != AVAudioSession.InterruptionType.began.rawValue { return }
                if name == AVAudioSession.routeChangeNotification {
                    let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
                    guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue || reason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue else { return }
                }
                Task { @MainActor [weak self] in
                    if self?.waitingBetweenLanguages == true { self?.interrupt() }
                }
            })
        }
    }
    func close() {
        stop(); recording.stop(); voice.close()
        gapObservers.forEach(NotificationCenter.default.removeObserver); gapObservers = []
    }
}

/// Store the role (original/translation/both), not English/Spanish: sessions can use either language.
enum PlaybackLanguagePreference: String {
    case original, translation, both
    init(mode: TranscriptLanguage, source: CaptureLanguage) {
        self = mode == .both ? .both : mode == source.mode ? .original : .translation
    }
    func mode(source: CaptureLanguage, hasTranslation: Bool) -> TranscriptLanguage {
        guard hasTranslation else { return source.mode }
        return self == .both ? .both : self == .translation ? source.opposite.mode : source.mode
    }
}
