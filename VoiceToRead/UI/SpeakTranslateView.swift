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
    enum AudioCard: Equatable { case original, translation }
    let capture: CaptionViewModel
    let speaker: TranslationSpeechPlayer
    private(set) var phase: Phase = .ready
    private(set) var source = ""
    private(set) var translated = ""
    private(set) var job: TranslationJob?
    var message: String?
    private(set) var mode: Mode = .byButton
    private(set) var language: CaptureLanguage = .spanish
    private(set) var target: CaptureLanguage = .english
    var pauseSeconds: Double = 3
    private let originalAudioID = UUID()
    private let translationAudioID = UUID()
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
    /// Clear only this temporary turn; the chosen direction and preferences stay intact.
    func newConversation() {
        guard canEdit else { return }
        token = UUID()
        source = ""; translated = ""; message = nil
        speaker.message = nil
    }

    /// Changing direction is explicit and never modifies the session capture preference.
    func selectLanguage(_ language: CaptureLanguage, target: CaptureLanguage? = nil) {
        guard canEdit else { return }
        let destination = target ?? language.defaultTarget
        guard destination != language else { return }
        if self.language != language || self.target != destination {
            self.target = destination
            self.language = language; source = ""; translated = ""; message = nil
        }
    }
    /// Preparation never opens the microphone or clears the visible conversation.
    /// Reset the ended temporary capture first so configureLanguage can select the actual model.
    func prepareSpeechModel(install: Bool = false) {
        guard canEdit, !capture.preparationPending else { return }
        let selected = language
        token = UUID(); let request = token
        phase = .preparing; message = nil
        let previous = operation
        operation = Task { [weak self] in
            await previous?.value
            guard let self, self.token == request else { return }
            await capture.reset()
            guard token == request else { return }
            capture.configureLanguage(selected)
            await capture.checkReadiness()
            guard token == request else { return }
            if install {
                if capture.readiness == .authorizationRequired { await capture.requestSpeechPermission() }
                guard token == request else { return }
                if capture.readiness == .missingAssets { await capture.installAssets() }
                guard token == request else { return }
            }
            phase = .ready
        }
    }

    func start(language: CaptureLanguage = .spanish, target: CaptureLanguage? = nil) {
        guard canEdit, !capture.preparationPending, supported() else { return }
        let destination = target ?? language.defaultTarget
        guard language != destination else { return }
        self.target = destination
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
            // Both automatic pauses and manual limits translate without starting audio.
            finish()
        } else if source.isEmpty && now - listeningSince >= 15 {
            cancel()
            message = "No speech detected. Choose a language to try again."
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
                message = "Review the text before translating. Recognition may be incomplete."
                return
            }
            source = final
            translate()
        }
    }
    func translate() {
        guard canEdit, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard supported() else { return }
        message = nil; translated = ""
        job = TranslationJob(plan: IncrementalTranslation(
            source: [ReviewParagraph(id: UUID(), text: source)], previous: nil, language: language, targetLanguage: target))
        phase = .translating
    }
    func complete(_ completed: TranslationJob, result: Result<[ReviewParagraph], Error>) {
        guard job?.id == completed.id, phase == .translating else { return }
        job = nil; phase = .ready
        do {
            let snapshot = try completed.plan.merging(result.get())
            translated = snapshot.translated.map(\.text).joined(separator: "\n")
        } catch {
            message = "Translation could not finish. Check language downloads and try translating again."
        }
    }
    func isPlaying(_ card: AudioCard) -> Bool {
        speaker.state != .idle && speaker.paragraphID == (card == .original ? originalAudioID : translationAudioID)
    }
    func togglePlayback(_ card: AudioCard) {
        guard !busy, !capture.state.active, !capture.state.busy, !capture.preparationPending else { return }
        if isPlaying(card) { speaker.stop(); return }
        let text = card == .original ? source : translated
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // start() stops the previous utterance and invalidates its callbacks first.
        speaker.start([ReviewParagraph(id: card == .original ? originalAudioID : translationAudioID, text: text)],
                      language: card == .original ? language : target, speed: .normal)
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
        Button { showing = true } label: { Label("Conversation", systemImage: "bubble.left.and.bubble.right") }
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
    let target: CaptureLanguage
    let text: String
}

@MainActor
struct SpeakTranslateView: View {
    let settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let embedded: Bool
    @State private var model: SpeakTranslateModel
    init(settings: AppSettings, embedded: Bool = false, model: SpeakTranslateModel? = nil) {
        self.settings = settings; self.embedded = embedded
        _model = State(initialValue: model ?? SpeakTranslateModel())
    }
    // A new preference deliberately makes two-tap conversation the default for existing users too.
    @AppStorage("conversationTurnMode") private var savedMode = SpeakTranslateModel.Mode.byButton.rawValue
    @Environment(\.colorScheme) private var scheme
    @State private var showingOptions = false
    @State private var confirmNewConversation = false
    @State private var fullScreen = false
    @State private var editor: ConversationEdit?
    @AppStorage("conversationFirstLanguage") private var first: CaptureLanguage = .spanish
    @AppStorage("conversationSecondLanguage") private var second: CaptureLanguage = .english

    var body: some View {
        Group {
            if embedded { content }
            else { NavigationStack { content } }
        }
        .background {
            if let job = model.job {
                TranslationRunner(job: job, progress: { _ in }) { model.complete(job, result: $0) }.id(job.id)
            }
        }
        .task {
            if first == second { second = first.defaultTarget }
            if model.source.isEmpty { model.selectLanguage(first, target: second) }
            model.selectMode(SpeakTranslateModel.Mode(rawValue: savedMode) ?? .byButton)
            model.speaker.observeInterruptions()
            model.prepareSpeechModel()
        }
        .onChange(of: model.mode) { _, mode in savedMode = mode.rawValue }
        .onDisappear { model.cancel(); model.speaker.close() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.cancel() }
            else if phase == .active { model.prepareSpeechModel() }
        }
    }

    private var content: some View {
        Group {
            VStack(spacing: 0) {
                if !fullScreen {
                    pairControls.padding(.horizontal, 16).padding(.vertical, 8)
                }
                conversationBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if dynamicTypeSize.isAccessibilitySize && !fullScreen { turnControls }
                        if model.busy {
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
                        translationRetry
                        speechPreparation
                    }.padding()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("conversationReadingArea")
                    .background(ReaderSurface(settings: settings))
                    .environment(\.colorScheme, settings.readerPaper != .system && !settings.highContrast ? .light : (settings.colorScheme ?? scheme))
                if !fullScreen {
                Text("Temporary conversation · not saved").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
                if !dynamicTypeSize.isAccessibilitySize || fullScreen {
                    turnControls.padding(.horizontal).padding(.vertical, 8)
                        .frame(minHeight: fullScreen ? nil : 100).background(.bar)
                }
            }
        }
        .navigationTitle(uiKey(embedded ? "VoiceToRead" : "Conversation")).navigationBarTitleDisplayMode(.inline)
        .toolbar(fullScreen ? .hidden : .visible, for: .navigationBar)
        .toolbar(fullScreen ? .hidden : .visible, for: .tabBar)
        .statusBarHidden(fullScreen)
        .preference(key: CommunicationFullScreenKey.self, value: fullScreen)
        .modifier(HomeFullScreenSource(selection: $fullScreen, hosted: embedded, identifier: "conversationFullScreenButton"))
        .toolbar {
            if !embedded { DoneToolbar { model.cancel(); dismiss() } }
            ToolbarItem(placement: .topBarLeading) {
                Button("Reading options", systemImage: "ellipsis.circle") { showingOptions = true }
                    .disabled(!model.canEdit).labelStyle(AccessibleControlLabelStyle()).accessibilityIdentifier("conversationOptions")
            }
        }
        .sheet(isPresented: $showingOptions) { options }
        .confirmationDialog("Start a new conversation?", isPresented: $confirmNewConversation, titleVisibility: .visible) {
            Button("New conversation", role: .destructive) { model.newConversation() }
                .accessibilityIdentifier("confirmNewConversation")
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This clears the original and translation. Your languages and settings will stay unchanged.")
        }
        .sheet(item: $editor) { request in
            ConversationMessageEditor(request: request) { text in
                model.selectLanguage(request.language, target: request.target); model.edit(text); model.translate()
            }
        }
    }

    // Outside the reader ScrollView: actions and status stay visible while reading.
    private var conversationBar: some View {
        VStack(spacing: 0) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    expandedConversationBar
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            conversationStatus
                            conversationActions
                        }.fixedSize(horizontal: true, vertical: false)
                        expandedConversationBar
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 4)
            Divider()
        }.background(.bar).accessibilityIdentifier("conversationActionBar")
    }

    private var expandedConversationBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            conversationStatus
            conversationActions
        }
    }

    private var conversationStatus: some View {
        Label(status, systemImage: statusIcon)
            .font(.caption.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("conversationStatus")
    }

    private var conversationActions: some View {
        HStack(alignment: .center, spacing: 8) {
            NavigationLink { EnglishTrainingLibraryView() } label: {
                Label("Train", systemImage: "book.closed")
            }
            .labelStyle(InlinePreferenceLabelStyle()).font(.caption)
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
            .disabled(!model.canEdit || model.capture.preparationPending)
            .accessibilityLabel("Training").accessibilityIdentifier("englishTrainingEntry")
            Button {
                editor = ConversationEdit(language: first, target: second, text: "")
            } label: { Label("Write", systemImage: "keyboard") }
            .labelStyle(InlinePreferenceLabelStyle()).font(.caption)
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44).disabled(!model.canEdit)
            .accessibilityLabel("Write a reply").accessibilityIdentifier("conversationWriteReply")
            Button("New", systemImage: "plus.bubble") {
                if !model.source.isEmpty || !model.translated.isEmpty { confirmNewConversation = true }
                else { model.newConversation() }
            }.labelStyle(InlinePreferenceLabelStyle()).font(.caption)
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44).disabled(!model.canEdit)
            .accessibilityLabel("New conversation").accessibilityIdentifier("newConversationButton")
        }
    }

    @ViewBuilder private var speechPreparation: some View {
        let readiness = model.capture.readiness
        if readiness != .ready {
            VStack(alignment: .leading, spacing: 8) {
                Text("Speech model: \(model.capture.language.name)").font(.caption.weight(.semibold))
                if model.capture.preparationPending || model.phase == .preparing || readiness == .downloading {
                    ProgressView("Preparing selected speech model…")
                } else {
                    Text(LocalizedStringKey(readiness.description)).font(.caption).foregroundStyle(.secondary)
                }
                if readiness == .missingAssets || readiness == .authorizationRequired {
                    Button(uiKey(readiness == .authorizationRequired ? "Allow Speech Recognition" : "Install speech model"), systemImage: "arrow.down.circle") {
                        model.prepareSpeechModel(install: true)
                    }.labelStyle(InlinePreferenceLabelStyle()).frame(minWidth: 44, minHeight: 44)
                        .disabled(!model.canEdit || model.capture.preparationPending)
                        .accessibilityIdentifier("conversationInstallSpeechModel")
                    Text("Model installation needs Internet and may require additional storage.").font(.caption).foregroundStyle(.secondary)
                } else if model.canEdit {
                    Button("Refresh Checks", systemImage: "arrow.clockwise") { model.prepareSpeechModel() }
                        .labelStyle(InlinePreferenceLabelStyle()).frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("conversationRefreshSpeechModel")
                }
            }.accessibilityIdentifier("conversationSpeechPreparation")
        }
    }

    private var pairControls: some View {
        CommunicationLanguagePair(symbol: "arrow.left.arrow.right") {
            conversationPicker(left: true)
        } right: {
            conversationPicker(left: false)
        }.disabled(!model.canEdit || model.capture.preparationPending)
    }
    private func conversationPicker(left: Bool) -> some View {
        LanguagePickerControl(title: left ? "Me" : "Other person", selection: Binding(
            get: { left ? first : second }, set: { selected in
                // Selecting the other participant's language swaps the pair; never duplicate it.
                if left {
                    if selected == second { second = first }
                    first = selected
                } else {
                    if selected == first { first = second }
                    second = selected
                }
                model.selectLanguage(first, target: second)
                model.prepareSpeechModel()
            }), showRole: true, stackedRole: true).accessibilityIdentifier(left ? "conversationFirstLanguage" : "conversationSecondLanguage")
    }

    private var turnControls: some View {
        // Large accessibility text uses full-width rows in the scrollable content.
        // A fixed bottom bar at these sizes would hide the conversation entirely.
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            turnButton(first)
            turnButton(second)
            if !embedded && !fullScreen {
                Button("Full screen", systemImage: "arrow.up.left.and.arrow.down.right") { fullScreen = true }
                    .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("conversationFullScreenButton")
            }
            if fullScreen {
                Button("Reading options", systemImage: "ellipsis.circle") { showingOptions = true }
                    .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    .disabled(!model.canEdit).accessibilityIdentifier("conversationOptions")
                Button("Exit full screen", systemImage: "arrow.down.right.and.arrow.up.left") { fullScreen = false }
                    .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("conversationFullScreenButton")
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
    private func turnButton(_ language: CaptureLanguage) -> some View {
        let listening = model.phase == .listening && model.language == language
        let destination = language == first ? second : first
        return Button {
            if listening { model.finish() } else { model.start(language: language, target: destination) }
        } label: {
            VStack(spacing: 4) {
                Label {
                    if !settings.showButtonNames { Text(language.pickerLabel) }
                    else if listening { Text("Finish and translate") }
                    else { Text("Speak \(language.name)") }
                } icon: {
                    Image(systemName: listening ? "stop.fill" : "mic.fill")
                }.font(fullScreen ? .subheadline : .headline).labelStyle(.titleAndIcon)
                if !fullScreen && settings.showButtonNames {
                    Text(verbatim: language.name + " → " + destination.name)
                        .font(.caption)
                }
            }.multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6).frame(maxWidth: .infinity, minHeight: fullScreen ? 44 : 64, maxHeight: .infinity).contentShape(Rectangle())
        }.buttonStyle(LanguageButtonStyle(color: settings.color(for: language), highContrast: settings.highContrast))
            .disabled(!listening && (!model.canEdit || model.capture.preparationPending || !TranslationJob.supported))
            .accessibilityLabel(uiKey(listening ? "Finish and translate" : "Speak \(language.name)"))
            .accessibilityValue(Text(verbatim: language.name + " → " + destination.name))
            .accessibilityIdentifier(language == .spanish ? "conversationSpanishTurn" : language == .english ? "conversationEnglishTurn" : "conversationTurn-" + language.code)
    }
    @ViewBuilder private var messageCards: some View {
        if !model.source.isEmpty {
            PlaybackTextCard(text: model.source, language: model.language, translated: false,
                             settings: settings, identifier: "conversationSourceText", speaking: model.isPlaying(.original),
                             playback: { model.togglePlayback(.original) }, playbackEnabled: !model.busy,
                             playbackIdentifier: "conversationOriginalPlayback", showsSpeakingLabel: false)
        } else if !model.busy {
            CommunicationEmptyHint(title: "Choose who speaks to begin.")
        }
        if !model.translated.isEmpty {
            PlaybackTextCard(text: model.translated, language: model.target, translated: true,
                             settings: settings, identifier: "conversationTranslation", speaking: model.isPlaying(.translation),
                             playback: { model.togglePlayback(.translation) }, playbackEnabled: !model.busy,
                             playbackIdentifier: "conversationTranslationPlayback", showsSpeakingLabel: false)
        }
    }
    @ViewBuilder private var translationRetry: some View {
        if model.translated.isEmpty && !model.source.isEmpty && model.canEdit {
            Button { model.translate() } label: {
                Label("Translate", systemImage: "character.bubble")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.disabled(!TranslationJob.supported).labelStyle(AccessibleControlLabelStyle()).accessibilityIdentifier("conversationTranslate")
            .buttonStyle(.bordered).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
    private var options: some View {
        NavigationStack {
            Form {
                HomeReadingMenu(settings: settings)
                Section {
                    Picker("Conversation mode", selection: Binding(get: { model.mode }, set: { model.selectMode($0) })) {
                        Text("By button").tag(SpeakTranslateModel.Mode.byButton)
                        Text("Automatic").tag(SpeakTranslateModel.Mode.automatic)
                    }.pickerStyle(.segmented).accessibilityIdentifier("conversationMode")
                    Text("By button: choose a language, speak, then tap Finish to translate. Tap a card's play icon to listen. You do not need to hold the button.")
                    if model.mode == .automatic {
                        Picker("Finish after a pause", selection: $model.pauseSeconds) {
                            Text("3 seconds").tag(3.0)
                            Text("5 seconds").tag(5.0)
                        }
                        Text("Automatic: a quiet pause ends the turn and translates it. Audio plays only when you tap a card's play icon. You can also finish with the button.")
                    }
                }
                Section {
                    Text("Each turn lasts up to one minute. Review the text and tap a card's play icon when you want to listen.")
                    Text("This conversation is temporary. No audio recording or session is saved. Check the translation before relying on it.")
                }
            }.navigationTitle("Reading options").navigationBarTitleDisplayMode(.inline)
                .toolbar { DoneToolbar { showingOptions = false } }
        }
    }
    private var statusIcon: String {
        if model.speaker.state != .idle { return "speaker.wave.2.fill" }
        return model.phase == .listening ? "mic.fill" : "mic"
    }
    private var status: LocalizedStringKey {
        if model.speaker.state != .idle { return "Playing" }
        switch model.phase {
        case .ready: return "Ready"
        case .preparing: return "Preparing"
        case .listening: return "Listening"
        case .finishing: return "Finishing"
        case .translating: return "Translating"
        case .cancelling: return "Stopping"
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
                .navigationTitle("Write in \(request.language.name)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Translate") { apply(text); dismiss() }
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
    private var text: String { language == .spanish ? "Un vaso de agua, por favor." : language == .english ? "Would you like cold water?" : language.greeting }
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
