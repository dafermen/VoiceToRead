import SwiftUI
import SwiftData
import UIKit
import AVFoundation

/// Raíz de presentación. Abre el almacén antes de crear la sesión y propaga el ciclo de vida.
/// Un error de apertura se muestra al usuario: no se borra la base ni se simula éxito en memoria.
@MainActor
struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var coordinator: SessionCoordinator?
    @State private var storageFailure = false
    @State private var selectedTab = 0
    @State private var homePath: [HomeDestination] = []

    var body: some View {
        Group {
            if let coordinator {
                TabView(selection: Binding(get: { selectedTab }, set: { tab in
                    // Returning to Home resets navigation, not the ongoing capture or its data.
                    if tab == 0 { homePath.removeAll() }
                    selectedTab = tab
                })) {
                    homeNavigation(coordinator: coordinator).tag(0)
                    .tabItem { Label { Text(verbatim: InterfaceLocalization.string(coordinator.settings.conversationHome || coordinator.settings.simpleMode ? "Home" : "Captions", language: coordinator.settings.interfaceLanguage)) } icon: { Image(systemName: "captions.bubble") } }
                    SessionLibraryView(coordinator: coordinator).tag(1)
                        .tabItem { Label { Text(verbatim: InterfaceLocalization.string(coordinator.settings.conversationHome ? "Saved" : "Sessions", language: coordinator.settings.interfaceLanguage)) } icon: { Image(systemName: "clock") } }
                    NavigationStack { SettingsView(settings: coordinator.settings, coordinator: coordinator) }.tag(2)
                        .tabItem { Label { Text(verbatim: InterfaceLocalization.string("Settings", language: coordinator.settings.interfaceLanguage)) } icon: { Image(systemName: "gear") } }
                }
                .safeAreaInset(edge: .bottom) {
                    if coordinator.automaticTranslationJob != nil || coordinator.automaticTranslationMessage != nil {
                        HStack {
                            if let job = coordinator.automaticTranslationJob {
                                ProgressView()
                                Text("Translating confirmed text…")
                                Text("\(coordinator.automaticTranslationProgress)/\(job.source.count)")
                            } else if let message = coordinator.automaticTranslationMessage {
                                Text(LocalizedStringKey(message)).lineLimit(3)
                                if message != "Translation saved" {
                                    Button("Retry translation") { coordinator.retryAutomaticTranslation() }
                                }
                            }
                            Button(uiKey(coordinator.automaticTranslationJob == nil ? "Dismiss" : "Cancel translation"), systemImage: "xmark") { coordinator.cancelAutomaticTranslation() }
                                .labelStyle(AccessibleControlLabelStyle()).frame(minWidth: 44, minHeight: 44)
                        }.font(.caption).padding(.horizontal).background(.regularMaterial)
                            .accessibilityIdentifier("automaticTranslationStatus")
                    }
                }
                .background {
                    if let job = coordinator.automaticTranslationJob {
                        TranslationRunner(job: job, progress: { value in
                            if coordinator.automaticTranslationJob?.id == job.id { coordinator.automaticTranslationProgress = value }
                        }) { result in coordinator.completeAutomaticTranslation(job, result: result) }.id(job.id)
                    }
                }
                .environment(coordinator.settings)
                .modelContainer(coordinator.repository.container)
                .preferredColorScheme(coordinator.settings.colorScheme)
                .environment(\.locale, coordinator.settings.interfaceLanguage.locale)
                .alert("Storage problem", isPresented: Binding(
                    get: { coordinator.storageMessage != nil },
                    set: { if !$0 { coordinator.storageMessage = nil } })) {
                        Button("OK") { coordinator.storageMessage = nil }
                    } message: { Text(LocalizedStringKey(coordinator.storageMessage ?? "")) }
            } else if storageFailure {
                ContentUnavailableView {
                    Label("Local storage unavailable", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved data has not been deleted. Free storage and try again.")
                } actions: {
                    Button("Retry") { openStorage() }
                }
            } else {
                ProgressView("Opening local sessions")
            }
        }
        .task { if coordinator == nil { openStorage() } }
        .onChange(of: scenePhase) { _, phase in
            // A language-download permission sheet can make the scene inactive.
            // Suspend only on actual backgrounding, not while Apple is requesting consent.
            if phase != .inactive { coordinator?.automaticTranslationForeground(phase == .active) }
            if phase == .background {
                UIApplication.shared.isIdleTimerDisabled = false
                if let coordinator, let identifier = coordinator.caption.prepareForBackground() {
                    Task { await coordinator.caption.cleanupBackground(identifier) }
                }
            } else if phase == .active {
                coordinator?.caption.foregrounded()
                if let coordinator {
                    do { try coordinator.repository.purgeExpiredTrash() }
                    catch { coordinator.storageMessage = "Expired sessions could not be removed. Please retry from Recently deleted." }
                }
            }
        }
    }

    private func homeNavigation(coordinator: SessionCoordinator) -> some View {
        NavigationStack(path: $homePath) {
            Group {
                if coordinator.settings.conversationHome { CommunicationHomeView(coordinator: coordinator) }
                else if coordinator.settings.simpleMode { SimpleHomeView(coordinator: coordinator) }
                else { LiveCaptionView(coordinator: coordinator) }
            }
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .listen: LiveCaptionView(coordinator: coordinator)
                case .sessions: SessionHistoryView(coordinator: coordinator)
                case .practice: PracticeSessionPicker(coordinator: coordinator)
                case .response: WrittenResponseView(coordinator: coordinator)
                case .preparation: OfflineReadinessView(coordinator: coordinator)
                }
            }
        }
    }

    private func openStorage() {
        do {
            #if DEBUG
            // Store screenshots use fictional saved text and an isolated in-memory library.
            // This branch is excluded from Release; it never starts the microphone or translation.
            if ProcessInfo.processInfo.arguments.contains("--store-screenshots") {
                let spanish = ProcessInfo.processInfo.arguments.contains("--store-spanish")
                let suite = "VoiceToRead.StoreScreenshots"
                let defaults = UserDefaults(suiteName: suite)!
                defaults.removePersistentDomain(forName: suite)
                let settings = AppSettings(defaults: defaults)
                settings.interfaceLanguage = spanish ? .spanish : .english
                settings.appearance = .light
                let repository = try TranscriptRepository(inMemory: true)
                let sample = try repository.create(title: spanish ? "Aprendemos juntos" : "Learning together",
                                                   language: spanish ? .spanish : .english)
                let paragraphs = spanish ? [
                    "Cada persona aprende a su propio ritmo. Podemos detenernos, leer de nuevo y continuar cuando estemos preparados.",
                    "Escuchar una frase corta y repetirla nos ayuda a practicar. No hace falta hacerlo perfecto para empezar.",
                    "Antes de compartir nuestras notas, revisamos las palabras y corregimos lo que sea necesario.",
                    "Conservemos las ideas que queremos recordar y hagamos espacio para nuevas preguntas."
                ] : [
                    "Everyone learns at their own pace. We can pause, read again and continue when we feel ready.",
                    "Listening to a short phrase and repeating it helps us practise. We do not need to be perfect to begin.",
                    "Before sharing our notes, we review the words and correct anything that needs attention.",
                    "Let us keep the ideas we want to remember and make room for new questions."
                ]
                let run = UUID()
                let segments = paragraphs.enumerated().map { index, text in
                    CaptionSegment(runID: run, start: Double(index * 15), end: Double((index + 1) * 15), text: text)
                }
                try repository.apply(.init(removedIDs: [], upserted: segments), to: sample)
                try repository.checkpoint(sample, duration: 60, ended: true)
                try repository.setFavorite(true, for: sample)
                try repository.toggleBookmark(segments[0], in: sample)
                coordinator = SessionCoordinator(repository: repository, settings: settings)
                storageFailure = false
                return
            }
            if ProcessInfo.processInfo.arguments.contains("--ui-test-review") {
                for key in ["conversationFirstLanguage", "conversationSecondLanguage", "frenchLanguageColor", "koreanLanguageColor", "japaneseLanguageColor", "chineseLanguageColor", "captureLanguage", "translationLanguage", "englishLanguageColor", "spanishLanguageColor", "conversationMode", "conversationTurnMode", "playbackAtMyPace", "playbackLanguagePreference", "playbackLanguageGap", "originalPlaybackSpeed", "translationSpeechSpeed"] {
                    UserDefaults.standard.removeObject(forKey: key)
                }
                UserDefaults.standard.set(ProcessInfo.processInfo.arguments.contains("--ui-test-communication"), forKey: "conversationHome")
                UserDefaults.standard.set(false, forKey: "conversationTranslationEnabled")
                UserDefaults.standard.set(ProcessInfo.processInfo.arguments.contains("--ui-test-simple"), forKey: "simpleMode")
                UserDefaults.standard.set(ProcessInfo.processInfo.arguments.contains("--ui-test-labels"), forKey: "showButtonNames")
                UserDefaults.standard.set(ProcessInfo.processInfo.arguments.contains("--ui-test-focus"), forKey: "focusedReading")
                let repository = try TranscriptRepository(inMemory: true)
                let spanishSample = ProcessInfo.processInfo.arguments.contains("--ui-test-spanish")
                let sample = try repository.create(title: "Review sample", language: spanishSample ? .spanish : .english)
                let run = UUID()
                var segments: [CaptionSegment] = []
                for index in 1...80 {
                    let text: String = index == 1 && ProcessInfo.processInfo.arguments.contains("--ui-test-long-paragraph")
                        ? "Start of long paragraph. " + String(repeating: "Take your time to read this sentence and understand the conversation. ", count: 40) + "End of long paragraph."
                        : index == 1
                        ? "Acmee makes captions useful. Acmee keeps words clear. Acmees stays unchanged."
                        : "Paragraph \(index). Reading, reviewing and sharing should be simple. Keep the original words safe while correcting a transcript."
                    segments.append(CaptionSegment(runID: run, start: Double(index), end: Double(index + 1), text: spanishSample ? "Hola mundo. Aprendemos juntos." : text))
                }
                try repository.apply(.init(removedIDs: [], upserted: segments), to: sample)
                try repository.checkpoint(sample, duration: 600, ended: true)
                try repository.toggleBookmark(segments[0], in: sample)
                try repository.toggleBookmark(segments[79], in: sample)
                if ProcessInfo.processInfo.arguments.contains("--ui-test-reviewed") {
                    var paragraphs = segments.map { ReviewParagraph(id: $0.id, text: $0.text) }
                    paragraphs[0].text = "Acme corrected draft."
                    try repository.saveCorrections(paragraphs, for: sample)
                }
                if ProcessInfo.processInfo.arguments.contains("--ui-test-media") {
                    let timed = segments.map { segment in
                        CaptionSegment(id: segment.id, runID: segment.runID, start: segment.start,
                            end: segment.end, text: segment.text, sessionTime: true)
                    }
                    try repository.apply(.init(removedIDs: [], upserted: timed), to: sample)
                    let url = try repository.prepareRecording(for: sample)
                    let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
                    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16000)!
                    buffer.frameLength = 16000
                    buffer.floatChannelData![0].initialize(repeating: 0, count: 16000)
                    let recorder = SessionAudioRecorder(url: url)
                    for _ in 0..<85 { recorder.append(CapturedAudio(buffer: buffer)) {} }
                    try recorder.finish()
                }
                if ProcessInfo.processInfo.arguments.contains("--ui-test-translation") {
                    let source = try repository.reviewedParagraphs(for: sample)
                    let spanish = source.enumerated().map { index, paragraph in
                        ReviewParagraph(id: paragraph.id, text: spanishSample ? "Hello world. We learn together." : index == 0 ? "Hola mundo. Aprendemos juntos." : "Párrafo \(index + 1). Leer y compartir debería ser sencillo.")
                    }
                    try repository.saveTranslation(TranslationSnapshot(source: source, generated: spanish, sourceLocale: spanishSample ? "es-ES" : nil), for: sample)
                    if ProcessInfo.processInfo.arguments.contains("--ui-test-translation-stale") {
                        var changed = source
                        changed[0].text = "The English transcript changed."
                        try repository.saveCorrections(changed, for: sample)
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--ui-test-library") {
                    _ = try repository.create(title: "Unfinished draft example", draft: true)
                    let deleted = try repository.create(title: "Deleted example")
                    try repository.checkpoint(deleted, duration: 1, ended: true)
                    try repository.moveToTrash(deleted)
                    let french = try repository.create(title: "French and Korean", language: .french, target: .korean)
                    let segment = CaptionSegment(runID: UUID(), start: 0, end: 3, text: "Bonjour. Nous apprenons ensemble.")
                    try repository.apply(.init(removedIDs: [], upserted: [segment]), to: french)
                    try repository.checkpoint(french, duration: 3, ended: true)
                    let source = try repository.reviewedParagraphs(for: french)
                    try repository.saveTranslation(TranslationSnapshot(source: source,
                        generated: [.init(id: segment.id, text: "안녕하세요. 우리는 함께 배웁니다.")],
                        sourceLocale: "fr-FR", targetLocale: "ko-KR"), for: french)
                }
                coordinator = SessionCoordinator(repository: repository)
                storageFailure = false
                return
            }
            if ProcessInfo.processInfo.arguments.contains("--ui-test-reader") {
                let defaults = UserDefaults(suiteName: "VoiceToRead.ReaderUITests")!
                defaults.removePersistentDomain(forName: "VoiceToRead.ReaderUITests")
                let settings = AppSettings(defaults: defaults)
                if ProcessInfo.processInfo.arguments.contains("--ui-test-live-translation") {
                    UserDefaults.standard.removeObject(forKey: "liveCaptionDisplay")
                    if ProcessInfo.processInfo.arguments.contains("--ui-test-spanish") { settings.captureLanguage = .spanish }
                }
                settings.conversationHome = ProcessInfo.processInfo.arguments.contains("--ui-test-communication")
                settings.showButtonNames = ProcessInfo.processInfo.arguments.contains("--ui-test-labels")
                settings.saveAudio = false
                coordinator = SessionCoordinator(repository: try TranscriptRepository(inMemory: true),
                    caption: CaptionViewModel(microphone: ReaderPreviewMicrophone(), speech: ReaderPreviewSpeech()),
                    settings: settings)
                storageFailure = false
                return
            }
            #endif
            let oldStore = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("VoiceToRead/Sessions.store")
            AppSettings.registerAudioDefault(existingInstallation: oldStore.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)
            let repository = try TranscriptRepository()
            coordinator = SessionCoordinator(repository: repository)
            do { try repository.purgeExpiredTrash() }
            catch { coordinator?.storageMessage = "Expired sessions could not be removed. Please retry from Recently deleted." }
            storageFailure = false
        } catch { storageFailure = true }
    }
}

@MainActor
struct LiveCaptionView: View {
    @Environment(\.dismiss) private var dismiss
    let coordinator: SessionCoordinator
    var showConversationShortcut = true
    var communicationLayout = false
    @State private var showingConversation = false
    @State private var showingResponse = false

    var body: some View {
        CaptionScreen(model: coordinator.caption, settings: coordinator.settings,
                      newSession: { await coordinator.newSession() },
                      saveSession: { _ = coordinator.saveCurrent(ended: true) },
                      saveAndNewSession: {
                          if coordinator.saveCurrent(ended: true) { await coordinator.newSession() }
                      },
                      discardSession: { await coordinator.discardCurrent() },
                      needsSessionDecision: coordinator.needsSessionDecision,
                      sessionTitle: Binding(get: { coordinator.sessionTitle }, set: { coordinator.sessionTitle = $0 }),
                      speakAndTranslate: showConversationShortcut ? { showingConversation = true } : nil,
                      canSpeakAndTranslate: !coordinator.caption.state.active && !coordinator.caption.state.busy &&
                          !coordinator.caption.preparationPending && coordinator.automaticTranslationJob == nil,
                      writeResponse: { showingResponse = true }, communicationLayout: communicationLayout)
            .sheet(isPresented: $showingResponse) {
                NavigationStack {
                    WrittenResponseView(coordinator: coordinator)
                        .toolbar { DoneToolbar { showingResponse = false } }
                }
            }
            .sheet(isPresented: $showingConversation) {
                SpeakTranslateView(settings: coordinator.settings)
            }
    }
}

#if DEBUG
/// Deterministic input for UI regression tests; never compiled into TestFlight builds.
@MainActor
private final class ReaderPreviewMicrophone: AudioCapturing {
    func configureNoiseReduction(_ enabled: Bool) throws {}
    var permission: MicrophonePermission = ProcessInfo.processInfo.arguments.contains("--ui-test-preparation") ? .undetermined : .granted
    var onFailure: (@MainActor @Sendable (CaptureFailure) -> Void)?
    func requestPermission() async -> Bool { permission = .granted; return true }
    func start() throws -> AsyncStream<Float> { AsyncStream { $0.finish() } }
    func stop() throws {}
}

@MainActor
private final class ReaderPreviewSpeech: SpeechTranscribing {
    private var continuation: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation?
    private var producer: Task<Void, Never>?
    private var nextParagraph = 1
    private var interrupted = false
    private var needsModel = ProcessInfo.processInfo.arguments.contains("--ui-test-preparation")
    func readiness() async -> SpeechReadiness { needsModel ? .missingAssets : .ready }
    func installAssets() async throws { needsModel = false }
    func start() async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        let run = UUID()
        let stream = AsyncThrowingStream<TranscriptionUpdate, Error> { continuation = $0 }
        if nextParagraph == 1 {
            // Long reader tests need a scrollable history; session-flow tests need only a few phrases.
            let count = ProcessInfo.processInfo.arguments.contains("--ui-test-session-flow") ? 8 : 320
            for index in 1...count {
                continuation?.yield(.init(runID: run, start: Double(index), end: Double(index + 1),
                    text: ProcessInfo.processInfo.arguments.contains("--ui-test-spanish") ? "Párrafo \(index). Los subtítulos nos ayudan a seguir la conversación." : "Paragraph \(index). Clear captions make every conversation easier to follow.", isFinal: true))
            }
            nextParagraph = count + 1
        }
        producer = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                guard let self else { return }
                let index = self.nextParagraph
                self.continuation?.yield(.init(runID: run, start: Double(index), end: Double(index + 1),
                    text: ProcessInfo.processInfo.arguments.contains("--ui-test-spanish") ? "Párrafo \(index). Seguimos leyendo juntos mientras llegan nuevas palabras." : "Paragraph \(index). New captions keep arriving while you read.", isFinal: true))
                if ProcessInfo.processInfo.arguments.contains("--ui-test-interruption"), !self.interrupted {
                    self.interrupted = true
                    self.continuation?.finish(throwing: TranscriptionFailure.interrupted("Alarm interrupted the microphone."))
                    return
                }
                self.nextParagraph += 1
            }
        }
        return stream
    }
    func finish() async throws { producer?.cancel(); continuation?.finish() }
    func cancel() async { producer?.cancel(); continuation?.finish() }
}
#endif

/// Value routes let the Home tab return to its menu without resetting SessionCoordinator.
enum HomeDestination: Hashable { case listen, sessions, practice, response, preparation }

/// New entry point; the meeting coordinator and ephemeral conversation remain independent.
/// The mode selector cannot switch owners while either audio workflow is active.
@MainActor
struct CommunicationHomeView: View {
    let coordinator: SessionCoordinator
    @State private var listening = false
    @State private var conversation = SpeakTranslateModel()
    private var audioBusy: Bool {
        !conversation.canEdit || coordinator.caption.state.active || coordinator.caption.state.busy || coordinator.caption.preparationPending
    }
    var body: some View {
        VStack(spacing: 0) {
            Picker("What would you like to do?", selection: $listening) {
                Text("Converse").tag(false)
                Text("Listen").tag(true)
            }.pickerStyle(.segmented).padding(.horizontal).padding(.vertical, 8)
                .disabled(audioBusy).accessibilityIdentifier("communicationMode")
            if listening {
                LiveCaptionView(coordinator: coordinator, showConversationShortcut: false, communicationLayout: true)
            } else {
                SpeakTranslateView(settings: coordinator.settings, embedded: true, model: conversation)
            }
        }
        .onAppear {
            if coordinator.caption.state.active || coordinator.caption.state.busy { listening = true }
        }
    }
}
