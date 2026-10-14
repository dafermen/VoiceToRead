import Foundation
import Observation

/// Une la sesión de pantalla con su persistencia, sin convertir la vista en una base de datos.
/// Sus callbacks guardan resultados finales y preparan audio solo cuando el usuario lo eligió.
@MainActor
@Observable
final class SessionCoordinator {
    let caption: CaptionViewModel
    let repository: TranscriptRepository
    private(set) var currentSession: ConferenceSession?
    var storageMessage: String?
    let settings: AppSettings
    private(set) var currentIsDraft = false
    var needsSessionDecision: Bool { currentIsDraft }
    private(set) var resolvingSession = false
    // A history rename is reflected unless the user has explicitly edited the pending name.
    private var suggestedTitle = SessionTitle.suggested()
    private var titleOverride: String?
    var sessionTitle: String {
        get { titleOverride ?? currentSession?.title ?? suggestedTitle }
        set { titleOverride = newValue }
    }
    @ObservationIgnored private var monitorTask: Task<Void, Never>?

    init(repository: TranscriptRepository, caption: CaptionViewModel? = nil, settings: AppSettings? = nil) {
        self.repository = repository
        self.caption = caption ?? CaptionViewModel()
        self.settings = settings ?? AppSettings()
        applyCapturePreferences()
        self.caption.onPrepareCapture = { [weak self] in self?.applyCapturePreferences() }
        self.caption.onWillStart = { [weak self] in
            guard let self else { return }
            self.applyCapturePreferences()
            let capacity = StorageReadiness.check(at: self.repository.storageURL)
            if let bytes = capacity.availableBytes, bytes < StorageReadiness.minimumBytes {
                throw StorageFailure.lowCapacity
            }
            if self.currentSession == nil {
                self.suggestedTitle = SessionTitle.suggested()
                self.currentSession = try self.repository.create(title: self.sessionTitle, draft: true, language: self.caption.language)
                self.currentIsDraft = true
            }
            if self.caption.saveAudio, !self.caption.recordingPrepared, let session = self.currentSession {
                try self.caption.prepareRecording(at: self.repository.prepareRecording(for: session))
            }
        }
        self.caption.onFinalized = { [weak self] change in
            guard let self, let session = self.currentSession else { return }
            do { try self.repository.apply(change, to: session) }
            catch {
                self.storageMessage = "Could not save captions. They remain visible in this session. Free storage and use Save Session before closing the app."
                Task { await self.caption.pause() }
            }
        }
        self.caption.onCheckpoint = { [weak self] duration in
            guard let self, let session = self.currentSession else { return }
            do { try self.repository.checkpoint(session, duration: duration, ended: false) }
            catch { self.storageMessage = "Could not save session time. Retry Save Session." }
        }
        self.caption.onRunStarted = { [weak self] in self?.monitorSession() }
        self.caption.onEnded = { [weak self] in
            guard let self else { return }
            self.monitorTask?.cancel()
            _ = self.checkpointCurrent(ended: true)
        }
    }

    func changeCaptureLanguage() async {
        guard caption.canChooseCaptureOptions else { return }
        applyCapturePreferences()
        await caption.checkReadiness()
    }

    /// Preferences choose the next recording. Audio remains fixed once capture has begun.
    private func applyCapturePreferences() {
        if caption.canChooseCaptureOptions {
            caption.saveAudio = settings.saveAudio
            caption.reduceBackgroundNoise = settings.reduceBackgroundNoise
            caption.configureLanguage(settings.captureLanguage)
        }
        caption.continueInBackground = settings.continueInBackground
    }

    @discardableResult
    private func checkpointCurrent(ended: Bool = false) -> Bool {
        guard currentSession != nil || caption.startedAt != nil || !caption.transcript.finalized.isEmpty else { return true }
        do {
            if currentSession == nil {
                currentSession = try repository.create(title: sessionTitle, draft: true, language: caption.language)
                currentIsDraft = true
            }
            guard let currentSession else { return false }
            try repository.apply(.init(removedIDs: [], upserted: caption.transcript.finalized), to: currentSession)
            try repository.checkpoint(currentSession, duration: caption.currentDuration(at: Date()), ended: ended)
            storageMessage = nil
            return true
        } catch {
            storageMessage = "Could not save the recovery draft. Keep the app open, free storage, and retry Save Session."
            return false
        }
    }

    /// Only an explicit Save promotes a draft. Stop and bookmarks merely checkpoint it.
    @discardableResult
    func saveCurrent(ended: Bool = false) -> Bool {
        guard caption.state == .ended, !caption.preparationPending,
              checkpointCurrent(ended: ended), let currentSession else { return false }
        do {
            try repository.rename(currentSession, title: SessionTitle.resolved(sessionTitle, at: currentSession.startedAt))
            try repository.publish(currentSession)
            currentIsDraft = false
            storageMessage = nil
            return true
        } catch {
            storageMessage = "Could not save this session to the library. The draft is still available."
            return false
        }
    }

    /// Stop closes the recorder before deletion. On failure, keep the draft visible for retry.
    func discardCurrent() async {
        guard !resolvingSession, !caption.state.busy, !caption.preparationPending else { return }
        resolvingSession = true
        defer { resolvingSession = false }
        await caption.stop()
        do {
            if let currentSession { try repository.delete(currentSession) }
            currentSession = nil
            currentIsDraft = false
            storageMessage = nil
            await newSession()
        } catch {
            storageMessage = "Could not discard this session. The draft remains available; please retry."
        }
    }

    func toggleBookmark(_ segment: CaptionSegment) {
        _ = checkpointCurrent(ended: caption.state == .ended)
        guard storageMessage == nil, let currentSession else { return }
        do { try repository.toggleBookmark(segment, in: currentSession) }
        catch { storageMessage = "Could not save the bookmark. Please try again." }
    }

    func newSession() async {
        guard !caption.state.active, !caption.state.busy, !caption.preparationPending, !needsSessionDecision else { return }
        monitorTask?.cancel()
        await caption.reset()
        applyCapturePreferences()
        currentSession = nil
        titleOverride = nil
        suggestedTitle = SessionTitle.suggested()
    }

    private func monitorSession() {
        monitorTask?.cancel()
        monitorTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard let self, self.caption.state == .listening else { return }
                let capacity = StorageReadiness.check(at: self.repository.storageURL)
                if let bytes = capacity.availableBytes, bytes < StorageReadiness.minimumBytes {
                    self.storageMessage = "Storage is low. Listening paused. Export sessions or free space before continuing."
                    await self.caption.pause()
                    return
                }
                if let session = self.currentSession {
                    do {
                        try self.repository.checkpoint(session, duration: self.caption.currentDuration(at: Date()), ended: false)
                    } catch {
                        self.storageMessage = "Session checkpoint could not be saved. Listening paused; retry Save Session."
                        await self.caption.pause()
                        return
                    }
                }
            }
        }
    }
}
