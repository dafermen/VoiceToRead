import Foundation
import AVFoundation
import Observation

struct GuidedWordTiming: Decodable {
    struct Word: Decodable { let location: Int; let length: Int; let start: Double; let end: Double }
    let text: String
    let words: [Word]
    func validate(expected: String) throws {
        guard text == expected, !words.isEmpty else { throw SpeakingLesson.Failure.invalidContent }
        var last = 0.0
        for word in words {
            guard word.location >= 0, word.location <= text.utf16.count, word.length > 0,
                  word.length <= text.utf16.count - word.location, word.start.isFinite, word.end.isFinite,
                  word.start >= last, word.end >= word.start,
                  Range(NSRange(location: word.location, length: word.length), in: text) != nil else {
                throw SpeakingLesson.Failure.invalidContent
            }
            last = word.start
        }
    }
    func range(at time: Double) -> NSRange? {
        words.first { time >= $0.start && time < $0.end }.map { NSRange(location: $0.location, length: $0.length) }
    }
}

/// Offline playback only. No microphone, network request or API key is used here.
@MainActor @Observable
final class GuidedLessonAudio {
    enum Mode: String, CaseIterable { case understand, repeatPhrase, shadowing }
    private(set) var paragraph: Int?
    private(set) var range: NSRange?
    private(set) var waiting = false
    private(set) var paused = false
    var message: String?
    var active: Bool { paragraph != nil }
    private var player: AVAudioPlayer?
    private var timing: GuidedWordTiming?
    private var task: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var token = UUID()
    private var ownsAudio = false

    func start(lesson: SpeakingLesson, paragraph value: SpeakingLesson.Paragraph, slow: Bool, mode: Mode, repeating: Bool) {
        stop(); message = nil
        do {
            let directory = "SpeakingLessons/\(lesson.id)-audio"
            let name = String(format: "%02d", value.number)
            guard let url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: directory),
                  let dataURL = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: directory) else {
                throw SpeakingLesson.Failure.missingResource
            }
            let words = try JSONDecoder().decode(GuidedWordTiming.self, from: Data(contentsOf: dataURL))
            try words.validate(expected: value.en)
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.enableRate = true
            audio.rate = slow ? 1 : Float(1 / 0.85)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true); ownsAudio = true
            audio.prepareToPlay(); player = audio; timing = words; paragraph = value.number
            let current = token
            task = Task { @MainActor [weak self] in
                guard let self else { return }
                repeat {
                    guard !Task.isCancelled, self.token == current else { return }
                    self.waiting = false; audio.currentTime = 0
                    guard audio.play() else { self.stop(); self.message = "Lesson audio could not start. Please try again."; return }
                    while !Task.isCancelled && self.token == current && (audio.isPlaying || self.paused) {
                        if !self.paused { self.range = words.range(at: audio.currentTime) }
                        try? await Task.sleep(for: .milliseconds(40))
                    }
                    guard !Task.isCancelled, self.token == current else { return }
                    self.range = nil
                    if repeating && mode != .understand {
                        self.waiting = true
                        // Listening/repeating leaves time to speak; shadowing follows the voice.
                        let gap = mode == .repeatPhrase ? max(2, audio.duration / Double(audio.rate)) : 0.7
                        try? await Task.sleep(for: .seconds(gap))
                    } else { break }
                } while !Task.isCancelled && self.token == current
                if self.token == current { self.stop() }
            }
        } catch {
            stop(); message = "Lesson audio could not start. Please try again."
        }
    }
    func togglePause() {
        guard active, !waiting, let player else { return }
        if paused {
            if player.play() { paused = false } else { stop() }
        } else { player.pause(); paused = true }
    }
    func stop() {
        token = UUID(); task?.cancel(); task = nil
        player?.stop(); player = nil; timing = nil; paragraph = nil; range = nil; waiting = false; paused = false
        if ownsAudio {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudio = false
        }
    }
    func observeInterruptions() {
        guard observers.isEmpty else { return }
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification, AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if name == AVAudioSession.interruptionNotification {
                    guard (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue else { return }
                }
                if name == AVAudioSession.routeChangeNotification {
                    let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
                    guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
                }
                Task { @MainActor [weak self] in self?.stop() }
            })
        }
    }
    func close() { stop(); observers.forEach(NotificationCenter.default.removeObserver); observers = [] }
}

struct GuidedLessonSupport: Decodable {
    let lesson: String
    let locale: String
    let strings: [String: String]
    static func load(lesson: SpeakingLesson, language: CaptureLanguage) -> Self? {
        guard language != .spanish, language != .english,
              let url = Bundle.main.url(forResource: "\(lesson.id)-support-\(language.code)", withExtension: "json", subdirectory: "SpeakingLessons"),
              let data = try? Data(contentsOf: url), let pack = try? JSONDecoder().decode(Self.self, from: data),
              pack.lesson == lesson.id, pack.locale == language.code,
              pack.strings.values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return nil }
        return pack
    }
    func text(_ key: String, fallback: String) -> String { strings[key] ?? fallback }
}
