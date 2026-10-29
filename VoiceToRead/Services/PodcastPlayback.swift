import Foundation
import AVFoundation
import Observation

@MainActor
protocol PodcastAudioOutput: AnyObject {
    var currentTime: TimeInterval { get }
    var rate: Float { get set }
    var onFinish: ((Bool) -> Void)? { get set }
    func play() -> Bool
    func pause()
    func stop()
}

@MainActor
private final class ApplePodcastAudioOutput: NSObject, PodcastAudioOutput, AVAudioPlayerDelegate {
    private let player: AVAudioPlayer
    var onFinish: ((Bool) -> Void)?
    var currentTime: TimeInterval { player.currentTime }
    var rate: Float { get { player.rate } set { player.rate = newValue } }
    init(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        super.init()
        player.enableRate = true; player.delegate = self; player.prepareToPlay()
    }
    func play() -> Bool { player.play() }
    func pause() { player.pause() }
    func stop() { player.stop() }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.onFinish?(flag) }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in self?.onFinish?(false) }
    }
}

/// Owns only bundled podcast audio. No microphone, network or developer key at runtime.
@MainActor @Observable
final class PodcastPlayback {
    enum State { case idle, playing, paused }
    let episode: PodcastEpisode
    private(set) var state: State = .idle
    private(set) var index = 0
    private(set) var position = 0.0
    private(set) var range: NSRange?
    private(set) var completed = false
    var message: String?
    var slow = true { didSet { output?.rate = rate } }
    var elapsed: Double { episode.segments.prefix(index).reduce(0) { $0 + $1.duration } + position }
    var progress: Double { episode.duration > 0 ? min(1, max(0, elapsed / episode.duration)) : 0 }
    private var rate: Float { slow ? 1 : Float(1 / episode.baseSpeed) }
    private var output: PodcastAudioOutput?
    private var timing: GuidedWordTiming?
    private var generation = UUID()
    private var ticker: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var ownsSession = false
    private let makeOutput: @MainActor (URL) throws -> PodcastAudioOutput
    private let activate: @MainActor () throws -> Void
    private let deactivate: @MainActor () -> Void

    init(episode: PodcastEpisode, makeOutput: (@MainActor (URL) throws -> PodcastAudioOutput)? = nil,
         activate: (@MainActor () throws -> Void)? = nil, deactivate: (@MainActor () -> Void)? = nil) {
        self.episode = episode
        self.makeOutput = makeOutput ?? { try ApplePodcastAudioOutput(url: $0) }
        self.activate = activate ?? {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
        }
        self.deactivate = deactivate ?? { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }
    func play() {
        if state == .playing { return }
        if state == .paused, let output {
            do {
                try ownSession()
                guard output.play() else { throw PodcastEpisode.Failure.invalidContent }
                state = .playing; startTicker()
            } catch { fail() }
        } else { startSegment(completed ? 0 : index) }
    }
    func pause() {
        guard state == .playing else { return }
        updatePosition(); output?.pause(); ticker?.cancel(); ticker = nil
        state = .paused; releaseSession()
    }
    func stop() {
        clearOutput(); releaseSession()
        state = .idle; index = 0; position = 0; range = nil; completed = false
    }
    func select(_ value: Int) {
        guard episode.segments.indices.contains(value) else { return }
        if state == .playing { startSegment(value) }
        else {
            clearOutput(); releaseSession(); index = value; position = 0
            state = .idle; range = nil; completed = false
        }
    }
    func startSegment(_ value: Int) {
        guard episode.segments.indices.contains(value) else { return }
        clearOutput(); message = nil; index = value; position = 0; range = nil; completed = false
        do {
            let segment = episode.segments[value]
            let words = try JSONDecoder().decode(GuidedWordTiming.self,
                from: Data(contentsOf: episode.resourceURL(number: segment.number, fileExtension: "json")))
            try words.validate(expected: segment.en)
            try ownSession()
            let audio = try makeOutput(episode.resourceURL(number: segment.number, fileExtension: "mp3"))
            let token = generation
            audio.onFinish = { [weak self] success in
                guard let self, self.generation == token, self.state == .playing else { return }
                if !success { self.fail(); return }
                if value + 1 < self.episode.segments.count { self.startSegment(value + 1) }
                else {
                    self.clearOutput(); self.releaseSession(); self.state = .idle
                    self.position = self.episode.segments[value].duration
                    self.range = nil; self.completed = true
                }
            }
            output = audio; timing = words; audio.rate = rate
            guard audio.play() else { throw PodcastEpisode.Failure.invalidContent }
            state = .playing; startTicker()
        } catch { fail() }
    }
    private func updatePosition() {
        guard let output, episode.segments.indices.contains(index) else { return }
        position = max(0, min(episode.segments[index].duration, output.currentTime))
        range = timing?.range(at: position)
    }
    private func startTicker() {
        ticker?.cancel(); let token = generation
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.generation == token, self.state == .playing else { return }
                self.updatePosition()
                do { try await Task.sleep(for: .milliseconds(40)) } catch { return }
            }
        }
    }
    private func clearOutput() {
        generation = UUID(); ticker?.cancel(); ticker = nil
        output?.onFinish = nil; output?.stop(); output = nil; timing = nil
    }
    private func ownSession() throws { if !ownsSession { try activate(); ownsSession = true } }
    private func releaseSession() { if ownsSession { deactivate(); ownsSession = false } }
    private func fail() {
        clearOutput(); releaseSession(); state = .idle; range = nil
        message = "Podcast audio could not start. Please try again."
    }
    func observeInterruptions() {
        guard observers.isEmpty else { return }
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification, AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                if name == AVAudioSession.interruptionNotification {
                    guard (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue else { return }
                }
                if name == AVAudioSession.routeChangeNotification {
                    guard (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
                }
                Task { @MainActor [weak self] in self?.pause() }
            })
        }
    }
    func close() { stop(); observers.forEach(NotificationCenter.default.removeObserver); observers = [] }
}
