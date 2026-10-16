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
    private(set) var mode: Mode = .automatic
    var pauseSeconds: Double = 3
    // Snapshot the selected mode for each job; a late response cannot change its audio policy.
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
        self.capture = capture ?? CaptionViewModel()
        self.speaker = speaker ?? TranslationSpeechPlayer()
        self.supported = supported
        self.capture.configureLanguage(.spanish)
    }
    func edit(_ text: String) {
        guard canEdit else { return }
        source = String(text.prefix(4000)); translated = ""; message = nil
    }
    func start() {
        guard !busy, !capture.preparationPending, supported() else { return }
        speaker.stop(); message = nil; translated = ""; source = ""
        token = UUID(); let request = token
        phase = .preparing
        operation = Task { [weak self] in
            guard let self else { return }
            await capture.reset()
            guard token == request else { return }
            capture.configureLanguage(.spanish)
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
            message = "Listening was interrupted. Review the Spanish text, then translate or speak again."
            return
        }
        if detector.shouldFinish(text: source, level: capture.inputLevel, now: now, delay: mode == .automatic ? pauseSeconds : 0) ||
            now - listeningSince >= 60 || source.count >= 4000 {
            finish()
        } else if source.isEmpty && now - listeningSince >= 15 {
            cancel()
            message = "No speech detected. Tap Speak Spanish to try again."
        }
    }
    func finish() {
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
                message = "Review the Spanish text before translating. Recognition may be incomplete."
                return
            }
            source = final
            translate()
        }
    }
    func translate() {
        guard canEdit, supported(), !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        message = nil; translated = ""
        speakWhenComplete = mode == .automatic
        job = TranslationJob(plan: IncrementalTranslation(
            source: [ReviewParagraph(id: UUID(), text: source)], previous: nil, language: .spanish))
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
        speaker.start([ReviewParagraph(id: UUID(), text: translated)], language: .english, speed: .normal)
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
        Button { showing = true } label: { Label("Speak and translate", systemImage: "bubble.left.and.bubble.right.fill") }
            .accessibilityIdentifier("speakTranslateEntry")
            .disabled(coordinator.caption.state.active || coordinator.caption.state.busy ||
                      coordinator.caption.preparationPending || coordinator.automaticTranslationJob != nil)
            .sheet(isPresented: $showing) { SpeakTranslateView(settings: coordinator.settings) }
    }
}

@MainActor
struct SpeakTranslateView: View {
    let settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    @State private var model = SpeakTranslateModel()
    @AppStorage("conversationMode") private var savedMode = SpeakTranslateModel.Mode.automatic.rawValue
    @FocusState private var editing: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Spanish → English").font(.title2.bold())
                    Picker("Conversation mode", selection: Binding(get: { model.mode }, set: { model.selectMode($0) })) {
                        Text("Automatic").tag(SpeakTranslateModel.Mode.automatic)
                        Text("By button").tag(SpeakTranslateModel.Mode.byButton)
                    }.pickerStyle(.segmented).disabled(!model.canEdit)
                        .accessibilityIdentifier("conversationMode")
                    Text(uiKey(model.mode == .automatic
                        ? "Speak Spanish, pause, and hear the English translation. The microphone stays off while the phone speaks."
                        : "Tap the microphone to speak, then Finished speaking. Read both texts and tap Play English when you are ready. No need to hold the button."))
                    if !TranslationJob.supported {
                        Text(LocalizedStringKey(TranslationFailure.unsupported.localizedDescription)).foregroundStyle(.secondary)
                    }
                    Label(LocalizedStringKey(status), systemImage: model.phase == .listening ? "mic.fill" : "bubble.left.and.text.bubble.right")
                        .font(.headline).accessibilityIdentifier("conversationStatus")
                    GroupBox("Your Spanish message") {
                        if model.canEdit {
                            TextEditor(text: Binding(get: { model.source }, set: { model.edit($0) }))
                                .font(.system(size: settings.captionSize * textScale))
                                .frame(minHeight: 130).focused($editing)
                                .autocorrectionDisabled()
                                .accessibilityLabel("Your Spanish message")
                                .accessibilityIdentifier("conversationSource")
                        } else {
                            Text(model.source).font(.system(size: settings.captionSize * textScale))
                                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                                .textSelection(.enabled)
                        }
                    }
                    if !model.translated.isEmpty {
                        GroupBox("English translation") {
                            Text(model.translated).font(.system(size: settings.captionSize * textScale))
                                .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                                .accessibilityIdentifier("conversationTranslation")
                        }.background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                    if let message = model.message ?? model.speaker.message {
                        Label(LocalizedStringKey(message), systemImage: "info.circle").accessibilityIdentifier("conversationMessage")
                    }
                    if model.phase == .listening {
                        Button { model.finish() } label: { Label("Finished speaking", systemImage: "checkmark.circle.fill") }
                            .accessibilityIdentifier("conversationFinish")
                    } else if !model.busy && model.speaker.state == .idle {
                        Button { editing = false; model.start() } label: { Label("Speak Spanish", systemImage: "mic.fill") }
                            .disabled(!TranslationJob.supported || model.capture.preparationPending).accessibilityIdentifier("conversationStart")
                        Button { editing = false; model.translate() } label: {
                            Label(uiKey(model.mode == .automatic ? "Translate and speak" : "Translate message"), systemImage: "character.bubble")
                        }
                            .disabled(!TranslationJob.supported || model.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("conversationTranslate")
                        if !model.translated.isEmpty {
                            Button("Play English", systemImage: "speaker.wave.2.fill") { model.play() }
                                .accessibilityIdentifier("conversationPlay")
                        }
                    }
                    if model.busy || model.speaker.state != .idle {
                        Button("Cancel", systemImage: "stop.circle") { model.cancel() }
                            .disabled(model.phase == .cancelling)
                            .accessibilityIdentifier("conversationCancel")
                    }
                    if model.capture.readiness == .missingAssets && !model.busy {
                        Button("Install speech model") { Task { await model.capture.installAssets() } }
                            .disabled(model.capture.preparationPending)
                    }
                    if model.mode == .automatic {
                        Text("Finish after a pause").font(.headline)
                        Picker("Finish after a pause", selection: $model.pauseSeconds) {
                            Text("3 seconds").tag(3.0)
                            Text("5 seconds").tag(5.0)
                        }.disabled(model.busy)
                    }
                    Text("A pause is estimated from speech and sound. In noise, tap Finished speaking. Each turn lasts up to one minute. You can also type or correct your message.").font(.footnote)
                    Text("This conversation is temporary. No audio recording or session is saved. Check the translation before relying on it.").font(.footnote).foregroundStyle(.secondary)
                }.padding().buttonStyle(.borderedProminent).controlSize(.large)
            }
            .navigationTitle("Speak and translate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { DoneButton { model.cancel(); dismiss() } } }
        }
        .background {
            if let job = model.job {
                TranslationRunner(job: job, progress: { _ in }) { result in
                    model.complete(job, result: result)
                }.id(job.id)
            }
        }
        .task {
            model.selectMode(SpeakTranslateModel.Mode(rawValue: savedMode) ?? .automatic)
            model.speaker.observeInterruptions()
            await model.capture.checkReadiness()
        }
        .onChange(of: model.mode) { _, mode in savedMode = mode.rawValue }
        .onDisappear { model.cancel(); model.speaker.close() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.cancel() }
        }
    }
    private var status: String {
        if model.speaker.state != .idle { return "Speaking English — microphone off" }
        switch model.phase {
        case .ready:
            return model.mode == .byButton && !model.translated.isEmpty
                ? "Translation ready — tap Play English" : "Ready for your message"
        case .preparing: return "Preparing Spanish recognition…"
        case .listening: return "Listening in Spanish…"
        case .finishing: return "Finishing your message…"
        case .translating: return "Translating to English…"
        case .cancelling: return "Stopping…"
        }
    }
}
