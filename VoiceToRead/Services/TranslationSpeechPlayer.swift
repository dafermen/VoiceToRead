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
    var rate: Float {
        switch self { case .slow: return 0.35; case .normal: return AVSpeechUtteranceDefaultSpeechRate; case .fast: return 0.58 }
    }
}

/// Owns synthesized playback only; it never records, changes a transcript, or writes an audio file.
/// Queue one corrected destination paragraph at a time, so highlighting follows spoken text.
@MainActor @Observable
final class TranslationSpeechPlayer {
    enum State { case idle, speaking, paused }
    private(set) var state: State = .idle
    private(set) var paragraphID: UUID?
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
        output.stop(); queue = []; index = 0; paragraphID = nil; state = .idle
        if ownsAudio { deactivate(); ownsAudio = false }
    }
    func interrupt() {
        guard state != .idle else { return }
        stop(); message = "Translation reading stopped. Tap a speaker when you are ready to listen again."
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
        guard index < queue.count else { stop(); return }
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
