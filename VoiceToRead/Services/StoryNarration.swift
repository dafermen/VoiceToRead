import Foundation
import AVFoundation
import Observation

@MainActor
protocol StorySpeechOutput: AnyObject {
    var onWord: ((NSRange, UUID) -> Void)? { get set }
    var onFinish: ((UUID) -> Void)? { get set }
    func speak(_ text: String, language: CaptureLanguage, slow: Bool, token: UUID) throws
    func pause() -> Bool
    func resume() -> Bool
    func stop()
}

@MainActor
private final class AppleStorySpeechOutput: NSObject, StorySpeechOutput, AVSpeechSynthesizerDelegate {
    var onWord: ((NSRange, UUID) -> Void)?
    var onFinish: ((UUID) -> Void)?
    private let synthesizer = AVSpeechSynthesizer()
    private var current: (utterance: AVSpeechUtterance, token: UUID)?
    override init() { super.init(); synthesizer.delegate = self }
    func speak(_ text: String, language: CaptureLanguage, slow: Bool, token: UUID) throws {
        guard let voice = PlaybackVoicePreference.voice(for: language) else { throw TranslationSpeechFailure.voiceUnavailable }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice; utterance.rate = slow ? TranslationSpeechSpeed.slow.rate : TranslationSpeechSpeed.normal.rate
        current = (utterance, token); synthesizer.speak(utterance)
    }
    func pause() -> Bool { synthesizer.pauseSpeaking(at: .immediate) }
    func resume() -> Bool { synthesizer.continueSpeaking() }
    func stop() { current = nil; synthesizer.stopSpeaking(at: .immediate) }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let identity = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, let current = self.current, ObjectIdentifier(current.utterance) == identity else { return }
            self.onWord?(characterRange, current.token)
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { complete(utterance) }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { complete(utterance) }
    nonisolated private func complete(_ utterance: AVSpeechUtterance) {
        let identity = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard let self, let current = self.current, ObjectIdentifier(current.utterance) == identity else { return }
            self.current = nil; self.onFinish?(current.token)
        }
    }
}

/// Complete-story narration has no microphone, recorder, practice results or saved audio.
@MainActor @Observable
final class StoryNarrator {
    enum State { case idle, playing, paused }
    private(set) var state: State = .idle
    private(set) var progress = TrainingSpokenWordProgress()
    var message: String?
    private var token = UUID()
    private let output: StorySpeechOutput
    private let activate: () throws -> Void
    private let deactivate: () -> Void
    private var ownsAudio = false
    private var observers: [NSObjectProtocol] = []
    init(output: StorySpeechOutput? = nil, activate: @escaping () throws -> Void = {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio); try session.setActive(true)
    }, deactivate: @escaping () -> Void = {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }) {
        self.output = output ?? AppleStorySpeechOutput(); self.activate = activate; self.deactivate = deactivate
        self.output.onWord = { [weak self] range, token in
            guard let self, self.state == .playing, self.token == token else { return }
            self.progress.receive(range, token: token)
        }
        self.output.onFinish = { [weak self] token in
            guard let self, self.token == token, self.state != .idle else { return }
            self.stop()
        }
    }
    func start(text: String, language: CaptureLanguage, slow: Bool) {
        stop(); message = nil
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try activate(); ownsAudio = true
            progress.begin(text: text, token: token); state = .playing
            try output.speak(text, language: language, slow: slow, token: token)
        } catch { stop(); message = error is TranslationSpeechFailure ? error.localizedDescription : "Story audio could not start. Please try again." }
    }
    func togglePause() {
        switch state {
        case .playing: if output.pause() { state = .paused } else { interrupt() }
        case .paused: if output.resume() { state = .playing } else { interrupt() }
        case .idle: break
        }
    }
    func stop() {
        token = UUID(); output.stop(); progress.reset(); state = .idle
        if ownsAudio { deactivate(); ownsAudio = false }
    }
    private func interrupt() { stop(); message = "Story narration was interrupted. Tap Play to start again." }
    func observeInterruptions() {
        guard observers.isEmpty else { return }
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification, AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notice in
                if name == AVAudioSession.interruptionNotification {
                    guard (notice.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue else { return }
                }
                if name == AVAudioSession.routeChangeNotification {
                    let reason = (notice.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
                    guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue || reason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue else { return }
                }
                Task { @MainActor [weak self] in if self?.state != .idle { self?.interrupt() } }
            })
        }
    }
    func close() { stop(); observers.forEach(NotificationCenter.default.removeObserver); observers = [] }
}
