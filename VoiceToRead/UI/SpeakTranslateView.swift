import SwiftUI
import Observation

/// A pause is a heuristic, not a linguistic paragraph boundary. Require both stable
/// recognition and a quiet meter; always offer a manual finish button in noisy places.
struct ConversationPause {
    private var previous = ""
    private var changedAt: TimeInterval = 0
    private var voicedAt: TimeInterval = 0
    mutating func shouldFinish(text: String, level: Float, now: TimeInterval, delay: Double) -> Bool {
        if text != previous { previous = text; changedAt = now }
        if level > 0.2 { voicedAt = now }
        return delay > 0 && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            now - max(changedAt, voicedAt) >= delay
    }
}

/// A temporary turn, deliberately separate from recorded sessions. The microphone is
/// finalized before translation/speech. Tokens reject results after Cancel or backgrounding.
@MainActor @Observable
final class SpeakTranslateModel {
    enum Mode: String, CaseIterable { case automatic, byButton }
    enum Phase: Equatable { case ready, preparing, listening, finishing, translating, cancelling }
    let capture: CaptionViewModel
    let speaker: TranslationSpeechPlayer
    private(set) var phase: Phase = .ready
    private(set) var source = ""
    private(set) var translated = ""
    private(set) var job: TranslationJob?
    var message: String?
    private(set) var mode: Mode = .byButton
    private(set) var language: CaptureLanguage = .spanish
    var pauseSeconds: Double = 3
    // Capture the output policy when a job starts; late callbacks cannot start another turn.
    private var speakWhenComplete = false
    func selectMode(_ mode: Mode) {
        guard canEdit else { return }
        self.mode = mode
    }
    private var token = UUID()
    private var operation: Task<Void, Never>?
    private var monitor: Task<Void, Never>?
    private var detector = ConversationPause()
    private var listeningSince: TimeInterval = 0
    private let supported: () -> Bool
    var busy: Bool { phase != .ready }
    var canEdit: Bool { !busy && speaker.state == .idle }

    init(capture: CaptionViewModel? = nil, speaker: TranslationSpeechPlayer? = nil,
         supported: @escaping () -> Bool = { TranslationJob.supported }) {
        #if DEBUG
        if capture == nil && ProcessInfo.processInfo.arguments.contains("--ui-test-conversation") {
            self.capture = CaptionViewModel(microphone: ConversationPreviewMicrophone(), speech: ConversationPreviewSpeech())
            self.speaker = TranslationSpeechPlayer(output: ConversationPreviewOutput(), activate: {}, deactivate: {})
        } else {
            self.capture = capture ?? CaptionViewModel()
            self.speaker = speaker ?? TranslationSpeechPlayer()
        }
        #else
        self.capture = capture ?? CaptionViewModel()
        self.speaker = speaker ?? TranslationSpeechPlayer()
        #endif
        self.supported = supported
        self.capture.configureLanguage(.spanish)
    }
    func edit(_ text: String) {
        guard canEdit else { return }
        source = String(text.prefix(4000)); translated = ""; message = nil
    }
    /// Changing direction is explicit and never modifies the session capture preference.
    func selectLanguage(_ language: CaptureLanguage) {
        guard canEdit else { return }
        if self.language != language {
            self.language = language; source = ""; translated = ""; message = nil
        }
    }
    func start(language: CaptureLanguage = .spanish) {
        guard canEdit, !capture.preparationPending, supported() else { return }
        self.language = language
        speaker.stop(); message = nil; translated = ""; source = ""
        token = UUID(); let request = token
        phase = .preparing
        operation = Task { [weak self] in
            guard let self else { return }
            await capture.reset()
            guard token == request else { return }
            capture.configureLanguage(language)
            capture.foregrounded()
            await capture.checkReadiness()
            guard token == request else { return }
            if capture.readiness == .authorizationRequired { await capture.requestSpeechPermission() }
            guard token == request else { return }
            await capture.start()
            guard token == request else { return }
            guard capture.state == .listening else {
                phase = .ready
                if case .problem(let error) = capture.state { message = error }
                else { message = capture.readiness.description }
                return
            }
            phase = .listening; detector = ConversationPause()
            listeningSince = ProcessInfo.processInfo.systemUptime
            monitor = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                    guard let self, self.token == request, self.phase == .listening else { return }
                    self.poll(now: ProcessInfo.processInfo.systemUptime)
                }
            }
        }
    }
    func poll(now: TimeInterval) {
        guard phase == .listening else { return }
        source = ([capture.transcript.text] + capture.transcript.partial.map(\.text))
            .filter { !$0.isEmpty }.joined(separator: "\n")
        guard capture.state == .listening else {
            monitor?.cancel(); phase = .ready
            message = "Listening was interrupted. Review the text, then translate or start another turn."
            return
        }
        if detector.shouldFinish(text: source, level: capture.inputLevel, now: now, delay: mode == .automatic ? pauseSeconds : 0) ||
            now - listeningSince >= 60 || source.count >= 4000 {
            // A safety limit ends manual capture without speaking unexpectedly.
            finish(speakWhenDone: mode == .automatic)
        } else if source.isEmpty && now - listeningSince >= 15 {
            cancel()
            message = "No speech detected. Choose a language to try again."
        }
    }
    func finish(speakWhenDone: Bool = true) {
        guard phase == .listening else { return }
        monitor?.cancel(); phase = .finishing
        let request = token
        operation = Task { [weak self] in
            guard let self else { return }
            await capture.stop() // Releases input before any synthesized output starts.
            guard token == request else { return }
            let final = capture.transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
            phase = .ready
            guard capture.notice == nil, !final.isEmpty else {
                if !final.isEmpty { source = final }
                message = "Review the text before translating. Recognition may be incomplete."
                return
            }
            source = final
            translate(speakWhenDone: speakWhenDone)
        }
    }
    func translate(speakWhenDone: Bool = true) {
        guard canEdit, supported(), !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        message = nil; translated = ""
        speakWhenComplete = speakWhenDone
        job = TranslationJob(plan: IncrementalTranslation(
            source: [ReviewParagraph(id: UUID(), text: source)], previous: nil, language: language))
        phase = .translating
    }
    func complete(_ completed: TranslationJob, result: Result<[ReviewParagraph], Error>) {
        guard job?.id == completed.id, phase == .translating else { return }
        job = nil; phase = .ready
        do {
            let snapshot = try completed.plan.merging(result.get())
            translated = snapshot.translated.map(\.text).joined(separator: "\n")
            if speakWhenComplete { play() }
        } catch {
            message = "Translation could not finish. Check language downloads and try translating again."
        }
    }
    func play() {
        guard !busy, !translated.isEmpty else { return }
        speaker.start([ReviewParagraph(id: UUID(), text: translated)], language: language.opposite, speed: .normal)
    }
    /// Invalidate synchronously; then serialize cleanup after any in-flight finalization.
    func cancel() {
        guard phase != .cancelling else { return }
        token = UUID(); job = nil; monitor?.cancel(); monitor = nil
        speaker.stop(); phase = .cancelling
        _ = capture.prepareForBackground()
        let previous = operation
        operation = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await capture.reset()
            phase = .ready
        }
    }
}

@MainActor
struct SpeakTranslateEntry: View {
    let coordinator: SessionCoordinator
    @State private var showing = false
    var body: some View {
        Button { showing = true } label: { Label("Conversation", systemImage: "bubble.left.and.bubble.right.fill") }
            .accessibilityIdentifier("speakTranslateEntry")
            .disabled(coordinator.caption.state.active || coordinator.caption.state.busy ||
                      coordinator.caption.preparationPending || coordinator.automaticTranslationJob != nil)
            .sheet(isPresented: $showing) { SpeakTranslateView(settings: coordinator.settings) }
    }
}

/// A presentation has its own identity; editing never clears the visible turn until Apply.
private struct ConversationEdit: Identifiable {
    let id = UUID()
    let language: CaptureLanguage
    let text: String
}

@MainActor
struct SpeakTranslateView: View {
    let settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var model = SpeakTranslateModel()
    // A new preference deliberately makes two-tap conversation the default for existing users too.
    @AppStorage("conversationTurnMode") private var savedMode = SpeakTranslateModel.Mode.byButton.rawValue
    @State private var showingOptions = false
    @State private var editor: ConversationEdit?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose who speaks. Tap again to finish and play the translation.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Label(LocalizedStringKey(status), systemImage: statusIcon)
                        .font(.headline).accessibilityIdentifier("conversationStatus")
                    turnControls
                    if model.speaker.state != .idle {
                        Button("Stop audio", systemImage: "stop.circle.fill") { model.speaker.stop() }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .accessibilityIdentifier("conversationStopAudio")
                    } else if model.busy {
                        Button("Cancel", systemImage: "xmark.circle") { model.cancel() }
                            .disabled(model.phase == .cancelling).frame(minHeight: 44)
                            .accessibilityIdentifier("conversationCancel")
                    }
                    if let message = model.message ?? model.speaker.message {
                        Label(LocalizedStringKey(message), systemImage: "info.circle")
                            .accessibilityIdentifier("conversationMessage")
                    }
                    if !TranslationJob.supported {
                        Text(LocalizedStringKey(TranslationFailure.unsupported.localizedDescription))
                            .foregroundStyle(.secondary)
                    }
                    messageCards
                    secondaryActions
                    if model.capture.readiness == .missingAssets && model.canEdit {
                        Button("Install speech model") { Task { await model.capture.installAssets() } }
                            .disabled(model.capture.preparationPending)
                    }
                }.padding()
            }
            .navigationTitle("Conversation").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { DoneButton { model.cancel(); dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Conversation options", systemImage: "ellipsis.circle") { showingOptions = true }
                        .disabled(!model.canEdit).accessibilityIdentifier("conversationOptions")
                }
            }
            .sheet(isPresented: $showingOptions) { options }
            .sheet(item: $editor) { request in
                ConversationMessageEditor(request: request) { text in
                    model.selectLanguage(request.language); model.edit(text); model.translate()
                }
            }
        }
        .background {
            if let job = model.job {
                TranslationRunner(job: job, progress: { _ in }) { model.complete(job, result: $0) }.id(job.id)
            }
        }
        .task {
            model.selectMode(SpeakTranslateModel.Mode(rawValue: savedMode) ?? .byButton)
            model.speaker.observeInterruptions()
            await model.capture.checkReadiness()
        }
        .onChange(of: model.mode) { _, mode in savedMode = mode.rawValue }
        .onDisappear { model.cancel(); model.speaker.close() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { model.cancel() } }
    }

    private var turnControls: some View {
        (widthClass == .regular && !typeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 10))) {
            turnButton(.spanish)
            turnButton(.english)
        }
    }
    private func turnButton(_ language: CaptureLanguage) -> some View {
        let listening = model.phase == .listening && model.language == language
        return Button {
            if listening { model.finish() } else { model.start(language: language) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: listening ? "stop.fill" : "mic.fill").font(.title2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(uiKey(listening
                        ? (language == .spanish ? "Finish & play English" : "Finish & play Spanish")
                        : (language == .spanish ? "Speak Spanish" : "Speak English"))).font(.headline)
                    Text(verbatim: language == .spanish ? "Español → English" : "English → Español").font(.subheadline)
                }
                Spacer(minLength: 0)
            }.padding(.vertical, 6).frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(.borderedProminent).tint(language == .spanish ? .blue : .indigo)
            .disabled(!listening && (!model.canEdit || model.capture.preparationPending || !TranslationJob.supported))
            .accessibilityIdentifier(language == .spanish ? "conversationSpanishTurn" : "conversationEnglishTurn")
    }
    @ViewBuilder private var messageCards: some View {
        if !model.source.isEmpty {
            PlaybackTextCard(text: model.source, language: model.language, translated: false,
                             settings: settings, identifier: "conversationSourceText")
        } else if !model.busy {
            Text("Your last exchange will appear here in both languages.")
                .foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 100)
        }
        if !model.translated.isEmpty {
            PlaybackTextCard(text: model.translated, language: model.language.opposite, translated: true,
                             settings: settings, identifier: "conversationTranslation", speaking: model.speaker.state == .speaking)
        }
    }
    private var secondaryActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.translated.isEmpty {
                Button(uiKey(model.language == .spanish ? "Play English" : "Play Spanish"), systemImage: "speaker.wave.2.fill") { model.play() }
                    .disabled(!model.canEdit).frame(minHeight: 44).accessibilityIdentifier("conversationPlay")
            }
            if !model.source.isEmpty {
                if model.translated.isEmpty && model.canEdit {
                    Button("Translate and play", systemImage: "character.bubble") { model.translate() }
                        .disabled(!TranslationJob.supported).frame(minHeight: 44)
                        .accessibilityIdentifier("conversationTranslate")
                }
                Button("Correct message", systemImage: "pencil") {
                    editor = ConversationEdit(language: model.language, text: model.source)
                }.disabled(!model.canEdit).frame(minHeight: 44).accessibilityIdentifier("conversationCorrect")
            }
            Menu {
                Button("Write in Spanish") { editor = ConversationEdit(language: .spanish, text: "") }
                Button("Write in English") { editor = ConversationEdit(language: .english, text: "") }
            } label: { Label("Type instead", systemImage: "keyboard").frame(minHeight: 44) }
                .disabled(!model.canEdit || !TranslationJob.supported).accessibilityIdentifier("conversationType")
        }.buttonStyle(.bordered)
    }
    private var options: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Conversation mode", selection: Binding(get: { model.mode }, set: { model.selectMode($0) })) {
                        Text("By button").tag(SpeakTranslateModel.Mode.byButton)
                        Text("Automatic").tag(SpeakTranslateModel.Mode.automatic)
                    }.pickerStyle(.segmented).accessibilityIdentifier("conversationMode")
                    Text("By button: choose a language, speak, then tap Finish to translate and play. You do not need to hold the button.")
                    if model.mode == .automatic {
                        Picker("Finish after a pause", selection: $model.pauseSeconds) {
                            Text("3 seconds").tag(3.0)
                            Text("5 seconds").tag(5.0)
                        }
                        Text("Automatic: a quiet pause ends the turn and plays the translation. You can also finish with the button.")
                    }
                }
                Section {
                    Text("Each turn lasts up to one minute. At the manual time limit, review the text and tap Play before it speaks.")
                    Text("This conversation is temporary. No audio recording or session is saved. Check the translation before relying on it.")
                }
            }.navigationTitle("Conversation options").navigationBarTitleDisplayMode(.inline)
                .toolbar { DoneButton { showingOptions = false } }
        }
    }
    private var statusIcon: String {
        if model.speaker.state != .idle { return "speaker.wave.2.fill" }
        return model.phase == .listening ? "mic.fill" : "bubble.left.and.bubble.right"
    }
    private var status: String {
        if model.speaker.state != .idle {
            return model.language == .spanish ? "Speaking English — microphone off" : "Speaking Spanish — microphone off"
        }
        switch model.phase {
        case .ready: return "Ready for the next turn"
        case .preparing: return model.language == .spanish ? "Preparing Spanish recognition…" : "Preparing English recognition…"
        case .listening: return model.language == .spanish ? "Listening in Spanish…" : "Listening in English…"
        case .finishing: return "Finishing your message…"
        case .translating: return model.language == .spanish ? "Translating to English…" : "Translating to Spanish…"
        case .cancelling: return "Stopping…"
        }
    }
}

@MainActor
private struct ConversationMessageEditor: View {
    let request: ConversationEdit
    let apply: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var focused: Bool
    init(request: ConversationEdit, apply: @escaping (String) -> Void) {
        self.request = request; self.apply = apply; _text = State(initialValue: request.text)
    }
    var body: some View {
        NavigationStack {
            TextEditor(text: $text).font(.title2).padding().focused($focused)
                .autocorrectionDisabled().accessibilityLabel("Message")
                .accessibilityIdentifier("conversationSource")
                .onChange(of: text) { _, value in if value.count > 4000 { text = String(value.prefix(4000)) } }
                .navigationTitle(uiKey(request.language == .spanish ? "Write in Spanish" : "Write in English"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Translate and play") { apply(text); dismiss() }
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("conversationApply")
                    }
                }.task { focused = true }
        }.interactiveDismissDisabled(text != request.text)
    }
}

#if DEBUG
// Explicit simulator fixture: no real microphone or synthesized speech; never included in Release.
@MainActor private final class ConversationPreviewMicrophone: AudioCapturing {
    var permission: MicrophonePermission = .granted
    var onFailure: (@MainActor @Sendable (CaptureFailure) -> Void)?
    func requestPermission() async -> Bool { true }
    func start() throws -> AsyncStream<Float> { AsyncStream { $0.finish() } }
    func stop() throws {}
}
@MainActor private final class ConversationPreviewSpeech: SpeechTranscribing {
    private var language: CaptureLanguage = .spanish
    private var run = UUID()
    private var output: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation?
    private var text: String { language == .spanish ? "Un vaso de agua, por favor." : "Would you like cold water?" }
    func configure(language: CaptureLanguage) { self.language = language }
    func readiness() async -> SpeechReadiness { .ready }
    func installAssets() async throws {}
    func start() async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        run = UUID()
        let stream = AsyncThrowingStream<TranscriptionUpdate, Error>.makeStream()
        output = stream.continuation
        output?.yield(.init(runID: run, start: 0, end: 2, text: text, isFinal: false))
        return stream.stream
    }
    func finish() async throws {
        output?.yield(.init(runID: run, start: 0, end: 2, text: text, isFinal: true)); output?.finish()
    }
    func cancel() async { output?.finish() }
}
@MainActor private final class ConversationPreviewOutput: TranslationSpeechOutput {
    var onFinish: ((UUID) -> Void)?
    func speak(_ text: String, language: CaptureLanguage, rate: Float, token: UUID) throws {}
    func pause() -> Bool { true }
    func resume() -> Bool { true }
    func stop() {}
}
#endif
