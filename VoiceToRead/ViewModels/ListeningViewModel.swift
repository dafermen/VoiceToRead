import Foundation
import Observation

@MainActor
@Observable
final class ListeningViewModel {
    private(set) var state: ListeningState = .idle
    private(set) var level: Float = 0
    private(set) var notice: String?
    @ObservationIgnored private let audio: any AudioCapturing
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var levelTask: Task<Void, Never>?
    @ObservationIgnored private var watchdogTask: Task<Void, Never>?
    @ObservationIgnored private var lastBufferAt = ContinuousClock.now
    @ObservationIgnored private var foreground = true

    init(audio: any AudioCapturing) {
        self.audio = audio
        audio.onFailure = { [weak self] failure in
            guard let self, self.state == .listening else { return }
            self.fail(failure)
        }
    }

    var showSettings: Bool {
        if case .error(.permissionDenied) = state { return true }
        return false
    }

    func start() async {
        guard foreground, state.canStart else { return }
        notice = nil
        let identifier = UUID()
        generation = identifier
        switch audio.permission {
        case .undetermined:
            state = .requestingPermission
            let granted = await audio.requestPermission()
            // Stop/background while the system prompt is open invalidates the intent.
            guard generation == identifier, foreground else { return }
            if Task.isCancelled { finish(); return }
            guard granted else { state = .error(.permissionDenied); return }
        case .denied:
            state = .error(.permissionDenied)
            return
        case .unavailable:
            state = .error(.permissionUnavailable)
            return
        case .granted: break
        }
        guard generation == identifier, foreground else { return }
        if Task.isCancelled { finish(); return }
        state = .starting
        do {
            let levels = try audio.start()
            state = .listening
            lastBufferAt = .now
            levelTask = Task { @MainActor [weak self] in
                for await value in levels {
                    guard !Task.isCancelled, let self,
                          self.generation == identifier, self.state == .listening else { return }
                    self.level = value
                    self.lastBufferAt = .now
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                }
                guard !Task.isCancelled, let self,
                      self.generation == identifier, self.state == .listening else { return }
                self.fail(.stalled)
            }
            watchdogTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    guard let self, self.generation == identifier, self.state == .listening else { return }
                    if self.lastBufferAt.duration(to: .now) > .seconds(5) {
                        self.fail(.stalled)
                        return
                    }
                }
            }
        } catch {
            fail((error as? CaptureFailure) ?? .engineFailure)
        }
    }

    func stop() {
        guard state.canStop else { return }
        finish()
    }

    func enteredBackground() {
        foreground = false
        if state.canStop {
            finish()
            notice = "Listening stopped in the background. Tap Start Listening to begin again."
        }
    }

    func enteredForeground() {
        foreground = true
        guard !state.canStop else { return }
        if audio.permission == .granted {
            switch state {
            case .error(.permissionDenied), .idle, .ready: state = .ready
            default: break
            }
        } else if audio.permission == .denied {
            state = .error(.permissionDenied)
        } else {
            state = .idle
        }
    }

    private func finish(failure: CaptureFailure? = nil) {
        generation = UUID()
        state = .stopping
        levelTask?.cancel()
        watchdogTask?.cancel()
        levelTask = nil
        watchdogTask = nil
        level = 0
        do {
            try audio.stop()
            state = failure.map(ListeningState.error) ?? .ready
        } catch {
            state = .error(.sessionFailure)
        }
    }

    private func fail(_ failure: CaptureFailure) {
        finish(failure: failure)
    }
}
