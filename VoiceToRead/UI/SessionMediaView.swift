import SwiftUI
import AVFoundation
import SwiftData
import UniformTypeIdentifiers

@MainActor
struct CaptureOptionsView: View {
    @Bindable var model: CaptionViewModel
    @Bindable var settings: AppSettings
    var body: some View {
        Section {
            Toggle("Save audio with transcript", isOn: audioBinding)
                .accessibilityIdentifier("saveAudioToggle")
            Toggle("Reduce background noise", isOn: noiseBinding)
                .accessibilityIdentifier("noiseReductionToggle")
            Text("Filters new microphone audio for recording and captions. May soften distant voices or sound from speakers. Existing recordings are unchanged.")
                .font(.caption).foregroundStyle(.secondary)
            if !model.canChooseCaptureOptions {
                LabeledContent("Noise reduction in this session") {
                    Text(uiKey(model.reduceBackgroundNoise ? "On" : "Off"))
                }.accessibilityIdentifier("sessionNoiseReductionStatus")
            }
            Toggle("Continue in background", isOn: backgroundBinding)
                .accessibilityIdentifier("backgroundAudioToggle")
                .disabled(model.state.busy || model.preparationPending)
            if !model.canChooseCaptureOptions {
                Text("Audio saving and noise reduction changes apply to your next session. Background listening can change during this session.")
                    .font(.caption)
            }
        } header: { Text("Capture preferences") } footer: {
            Text("These choices are remembered for future sessions. Recording starts only when you tap the microphone. Audio stays on this device. Background listening keeps the microphone active when switching apps or locking the screen. Other apps' internal audio is not captured.")
        }
    }

    private var audioBinding: Binding<Bool> {
        Binding(get: { settings.saveAudio }, set: {
            settings.saveAudio = $0
            if model.canChooseCaptureOptions { model.saveAudio = $0 }
        })
    }
    private var noiseBinding: Binding<Bool> {
        Binding(get: { settings.reduceBackgroundNoise }, set: {
            settings.reduceBackgroundNoise = $0
            if model.canChooseCaptureOptions { model.reduceBackgroundNoise = $0 }
        })
    }
    private var backgroundBinding: Binding<Bool> {
        Binding(get: { settings.continueInBackground }, set: {
            settings.continueInBackground = $0
            model.continueInBackground = $0
        })
    }
}

/// Reproduce un intervalo de muestras, no un temporizador que corta tarde el siguiente párrafo.
/// El temporizador solo actualiza la pantalla; scheduleSegment limita el audio en el motor.
@MainActor
@Observable
final class SessionPlayer {
    var onFinish: (() -> Void)?
    var onInterrupted: (() -> Void)?
    private var engine = AVAudioEngine()
    private var node = AVAudioPlayerNode()
    private var tempo = AVAudioUnitTimePitch()
    private var ownsAudio = false
    private(set) var interrupted = false
    var speed: TranslationSpeechSpeed = .normal { didSet { tempo.rate = speed.playbackRate } }
    private var file: AVAudioFile?
    private var timer: Task<Void, Never>?
    private var interruption: NSObjectProtocol?
    private var routeObservers: [NSObjectProtocol] = []
    private var generation = UUID()
    private var anchor = 0.0
    private(set) var playing = false
    private(set) var time = 0.0
    private(set) var duration = 0.0
    private(set) var range: ClosedRange<Double>?
    var failure: String?
    var bounds: ClosedRange<Double> { range ?? 0...max(duration, 0.001) }

    func load(_ url: URL) {
        stop(); failure = nil
        do {
            let file = try AVAudioFile(forReading: url)
            self.file = file
            duration = Double(file.length) / file.processingFormat.sampleRate
            engine = AVAudioEngine(); node = AVAudioPlayerNode(); tempo = AVAudioUnitTimePitch()
            tempo.rate = speed.playbackRate
            engine.attach(node)
            engine.attach(tempo)
            engine.connect(node, to: tempo, format: file.processingFormat)
            engine.connect(tempo, to: engine.mainMixerNode, format: file.processingFormat)
            interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                object: nil, queue: .main) { [weak self] notification in
                guard (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor [weak self] in self?.interrupt() }
            }
            for name in [AVAudioSession.routeChangeNotification, AVAudioSession.mediaServicesWereResetNotification] {
                routeObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    if name == AVAudioSession.routeChangeNotification {
                        guard (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
                    }
                    Task { @MainActor [weak self] in self?.interrupt() }
                })
            }
        } catch { failure = "This recording could not be opened. The transcript is still available." }
    }
    func select(range: ClosedRange<Double>?) {
        pause(); interrupted = false
        if let range {
            guard range.lowerBound.isFinite, range.upperBound.isFinite,
                  range.lowerBound >= 0, range.lowerBound < duration,
                  range.upperBound > range.lowerBound else { return }
            self.range = range.lowerBound...min(range.upperBound, duration)
            time = range.lowerBound
        } else { self.range = nil }
    }
    func toggle() {
        if playing { pause(); return }
        guard let file else { failure = "This recording could not be opened. The transcript is still available."; return }
        failure = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            ownsAudio = true; interrupted = false
            if time >= bounds.upperBound || time < bounds.lowerBound { time = bounds.lowerBound }
            let rate = file.processingFormat.sampleRate
            let first = AVAudioFramePosition(time * rate)
            let last = min(file.length, AVAudioFramePosition(bounds.upperBound * rate))
            guard last > first, last - first <= Int64(UInt32.max) else { throw RecordingFailure.unavailable }
            node.stop()
            let token = UUID(); generation = token
            anchor = time
            let end = bounds.upperBound
            node.scheduleSegment(file, startingFrame: first, frameCount: AVAudioFrameCount(last - first), at: nil,
                completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    self.pause(); self.time = end; self.onFinish?()
                }
            }
            engine.prepare()
            try engine.start()
            node.play(); playing = true
            timer = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(60)) } catch { return }
                    self?.updateTime()
                }
            }
        } catch { pause(); failure = "Audio playback could not start. Please try again." }
    }
    private func updateTime() {
        guard playing, let render = node.lastRenderTime, let position = node.playerTime(forNodeTime: render) else { return }
        time = min(bounds.upperBound, anchor + Double(position.sampleTime) / position.sampleRate)
    }
    func play(from value: Double) {
        guard value.isFinite, value >= bounds.lowerBound, value < bounds.upperBound else { return }
        seek(value)
        if !playing { toggle() }
    }
    func seek(_ value: Double) {
        guard value.isFinite else { return }
        let resume = playing
        pause()
        time = min(max(value, bounds.lowerBound), bounds.upperBound)
        // Scrubbing to the end leaves playback paused rather than unexpectedly restarting.
        if resume && time < bounds.upperBound { toggle() }
    }
    func interrupt() {
        guard playing else { return }
        pause(); interrupted = true; onInterrupted?()
    }
    func pause() {
        updateTime(); generation = UUID()
        timer?.cancel(); timer = nil
        node.stop(); engine.pause(); playing = false
        if ownsAudio {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudio = false
        }
    }
    func stop() {
        if let interruption { NotificationCenter.default.removeObserver(interruption) }
        interruption = nil
        routeObservers.forEach(NotificationCenter.default.removeObserver); routeObservers = []
        pause(); engine.stop(); file = nil; time = 0; duration = 0; range = nil; interrupted = false
    }
}

/// Un párrafo puede generar varios subtítulos breves. La lectura pausada conserva su rango completo.
struct PlaybackParagraph: Identifiable, Equatable {
    let id: UUID
    let text: String
    let start: Double
    let end: Double
    static func make(_ paragraphs: [ReviewParagraph], timings: [String: CaptionTiming], duration: Double) -> [Self] {
        guard duration.isFinite, duration > 0 else { return [] }
        return paragraphs.compactMap { paragraph in
            guard let timing = timings[paragraph.id.uuidString], timing.start.isFinite, timing.end.isFinite,
                  timing.start >= 0, timing.start < duration, timing.end > timing.start else { return nil }
            return Self(id: paragraph.id, text: paragraph.text, start: timing.start, end: min(timing.end, duration))
        }
    }
}

/// Each opening is a new presentation; paragraph IDs remain stable for saving corrections.
private struct ParagraphEditRequest: Identifiable {
    let id = UUID()
    let paragraph: ReviewParagraph
    let translation: Bool
}

@MainActor
struct SessionMediaView: View {
    let session: ConferenceSession
    let repository: TranscriptRepository
    let paragraphs: [ReviewParagraph]
    let hasCorrections: Bool
    var initialParagraphID: UUID? = nil
    var initialAudio: PlaybackAudio = .original
    var translatedCues: [SubtitleCue]? = nil
    var translationLanguage: String? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var compactPlayback: Bool { fullScreen || settings.focusedReading || verticalSizeClass == .compact }
    @State private var player = SessionPlayer()
    @State private var speech = TranslationSpeechPlayer()
    @State private var sequence = ParagraphPlayback()
    private var usesSequence: Bool { reading == .both || (reading == language.mode && audioURL == nil) }
    @State private var snapshot: TranslationSnapshot?
    @State private var listening: PlaybackAudio = .original
    @State private var originalStarted = false
    @State private var reading: TranscriptLanguage = .english
    @Environment(AppSettings.self) private var settings
    @AppStorage("translationSpeechSpeed") private var speed = TranslationSpeechSpeed.normal
    @AppStorage("originalPlaybackSpeed") private var originalSpeed = TranslationSpeechSpeed.normal
    @AppStorage("playbackLanguagePreference") private var savedLanguage = ""
    @AppStorage("playbackLanguageGap") private var languageGap = 0
    @State private var followingSpeech = true
    @State private var paragraphQuery = ""
    private var matchingPlaybackParagraphs: [(offset: Int, element: ReviewParagraph)] {
        Array(reviewed.enumerated()).filter { _, paragraph in
            audibleParagraphs.contains(where: { $0.id == paragraph.id }) &&
                (paragraphQuery.isEmpty || paragraph.text.localizedStandardContains(paragraphQuery) ||
                (currentTranslation && snapshot?.translated.first { $0.id == paragraph.id }?.text.localizedStandardContains(paragraphQuery) == true))
        }
    }
    private var speakingTranslation: Bool { usesSequence ? sequence.translated : listening == .translation }
    private var waitingForLanguage: Bool { usesSequence && sequence.waitingBetweenLanguages }
    private var highlightedCard: String { speakingTranslation ? "translation-card" : "original-card" }
    private var language: CaptureLanguage { CaptureLanguage(rawValue: session.language) ?? .english }
    private var target: CaptureLanguage { snapshot?.target ?? language.defaultTarget }
    private var currentTranslation: Bool { snapshot?.language == language && snapshot?.isCurrent(reviewed) == true }
    private var audibleParagraphs: [ReviewParagraph] {
        usesSequence ? reviewed : listening == .translation ? TranslationSpeechPlayer.paragraphs(snapshot: snapshot, source: reviewed) :
            reviewed.filter { paragraph in playbackParagraphs.contains { $0.id == paragraph.id } }
    }
    private var isPlaying: Bool { usesSequence ? sequence.state == .playing : listening == .original ? player.playing : speech.state == .speaking }
    private var finished: Bool { usesSequence ? sequence.state == .completed : listening == .original ? player.duration > 0 && player.time >= player.bounds.upperBound : speech.completedParagraphID != nil }
    private var primaryLabel: String {
        if isPlaying { return "Pause" }
        if finished { return "Listen again" }
        if usesSequence { return sequence.state == .paused ? "Resume" : "Play" }
        if listening == .translation { return speech.state == .paused ? "Resume" : "Play" }
        return originalStarted || player.interrupted ? "Resume" : "Play"
    }
    private var playbackStatus: String? {
        if usesSequence, let message = sequence.message { return message }
        if waitingForLanguage && isPlaying { return "Pause between languages" }
        if usesSequence && isPlaying { return sequence.translated ? "Playing translation" : "Playing original" }
        if player.interrupted && listening == .original { return "Playback interrupted. Tap Resume." }
        if listening == .translation, let message = speech.message { return message }
        if finished { return atMyPace ? "Paragraph finished" : "Playback finished" }
        if isPlaying { return "Playing" }
        return primaryLabel == "Resume" ? "Paused · tap Resume" : nil
    }
    @State private var audioURL: URL?
    @State private var cues: [SubtitleCue] = []
    @State private var showingPhrases = false
    @State private var deleting = false
    @State private var busy = false
    @State private var failure: String?
    @State private var export: MediaShare?
    @State private var folder: URL?
    @State private var exportTask: Task<Void, Never>?
    @State private var fullScreen = false
    @State private var showingOptions = false
    @State private var afterOptions: (() -> Void)?
    @State private var editing = false
    @State private var editingParagraph: ParagraphEditRequest?
    @State private var selectedParagraphID: UUID?
    @State private var playbackParagraphs: [PlaybackParagraph] = []
    @AppStorage("playbackAtMyPace") private var atMyPace = false
    @Query private var favorites: [SessionFavorite]
    private var protected: Bool { favorites.contains { $0.sessionID == session.id } }
    private var activeParagraphID: UUID? {
        if usesSequence { return sequence.paragraphID ?? selectedParagraphID }
        if listening == .translation { return speech.paragraphID ?? speech.completedParagraphID ?? selectedParagraphID }
        return atMyPace ? selectedParagraphID : currentCue?.paragraphID ?? selectedParagraphID
    }
    @State private var reviewed: [ReviewParagraph] = []
    @State private var edited = false
    @Environment(\.scenePhase) private var phase
    private var currentCue: SubtitleCue? {
        cues.first { $0.start <= player.time && player.time < $0.end } ??
            cues.last { $0.start <= player.time }
    }

    var body: some View {
        NavigationStack {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollViewReader { proxy in
                        ScrollView { playbackLayout }
                            .onChange(of: selectedParagraphID) { _, _ in
                                if settings.focusedReading { proxy.scrollTo("playback-reader-top", anchor: .top) }
                            }
                    }
                } else { playbackLayout }
            }
            .navigationTitle("Audio & subtitles").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                DoneToolbar { dismiss() }
                ToolbarItem(placement: .topBarLeading) {
                    if !reviewed.isEmpty {
                        Button(uiKey(fullScreen ? "Exit full screen" : "Full screen"), systemImage: fullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                            fullScreen.toggle()
                        }.labelStyle(AccessibleControlLabelStyle())
                    }
                }
            }
            .sheet(isPresented: $editing) {
                TranscriptEditorView(originals: session.orderedCaptions.map { ReviewParagraph(id: $0.id, text: $0.text) },
                                     reviewed: reviewed) { updated in
                    try repository.saveCorrections(updated, for: session)
                    reviewed = updated
                    edited = true
                    try rebuildCues()
                }
            }
            .sheet(item: $editingParagraph, onDismiss: { editingParagraph = nil }) { request in
                ParagraphEditorView(paragraph: request.paragraph, savesImmediately: true,
                    translation: request.translation) { text in
                    try saveParagraph(request.paragraph, text: text, translation: request.translation)
                    // Clear the presenting item after a successful save so the same
                    // paragraph can open again, even when its stable UUID is unchanged.
                    editingParagraph = nil
                }
            }
            .task { reviewed = paragraphs; load(); if settings.focusedReading { atMyPace = true } }
            .onChange(of: settings.focusedReading) { _, enabled in if enabled { atMyPace = true } }
            .onChange(of: atMyPace) { _, _ in
                if settings.focusedReading && !atMyPace { settings.focusedReading = false }
                if let id = activeParagraphID ?? audibleParagraphs.first?.id { selectParagraph(id) }
            }
            .onChange(of: sequence.paragraphID) { _, id in if usesSequence, let id { selectedParagraphID = id } }
            .onChange(of: speech.paragraphID) { _, id in if let id { selectedParagraphID = id } }
            .onChange(of: player.time) { _, _ in
                if !usesSequence, listening == .original, !atMyPace, let id = currentCue?.paragraphID { selectedParagraphID = id }
            }
            .onChange(of: listening) { _, _ in
                let id = selectedParagraphID
                pausePlayback(); speech.stop()
                selectParagraph(id ?? audibleParagraphs.first?.id)
            }
            .onChange(of: reading) { _, value in
                listening = reading == target.mode ? .translation : .original
                selectParagraph(selectedParagraphID ?? reviewed.first?.id)
                do { try rebuildCues() } catch { failure = error.localizedDescription }
            }
            .onChange(of: speed) { _, value in
                sequence.stop()
                if listening == .translation { speech.stop() }
            }
            .onChange(of: originalSpeed) { _, value in sequence.stop(); player.pause(); player.speed = value }
            .onChange(of: languageGap) { _, _ in sequence.stop() }
            .onDisappear { sequence.close(); player.stop(); speech.close(); exportTask?.cancel(); cleanup() }
            .onChange(of: phase) { _, phase in if phase != .active { sequence.interrupt(); player.interrupt(); speech.interrupt() } }
            .sheet(isPresented: $showingPhrases) {
                NavigationStack {
                    List(matchingPlaybackParagraphs, id: \.element.id) { index, paragraph in
                        Button {
                            selectParagraph(paragraph.id); showingPhrases = false; togglePlayback()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Paragraph \(index + 1) of \(audibleParagraphs.count)").font(.caption)
                                Text(paragraph.text).foregroundStyle(.primary).lineLimit(3)
                                if let translated = snapshot?.translated.first(where: { $0.id == paragraph.id }), currentTranslation {
                                    Text(translated.text).foregroundStyle(.secondary).lineLimit(3)
                                }
                                Label("Listen from this paragraph", systemImage: "play.circle")
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("listenPlaybackParagraph-\(index)")
                    }.overlay { if matchingPlaybackParagraphs.isEmpty && !paragraphQuery.isEmpty { Text("No matching paragraphs") } }
                        .searchable(text: $paragraphQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search original or translation")
                        .navigationTitle("Paragraphs").navigationBarTitleDisplayMode(.inline)
                        .toolbar { DoneToolbar { showingPhrases = false } }
                }
            }
            .sheet(isPresented: $showingOptions, onDismiss: {
                let action = afterOptions; afterOptions = nil; action?()
            }) {
                NavigationStack {
                    playbackOptions
                        .navigationTitle("Playback options").navigationBarTitleDisplayMode(.inline)
                        .toolbar { DoneToolbar { showingOptions = false } }
                }
            }
            .confirmationDialog(uiKey("Delete the recording permanently? Your text and subtitles will stay."), isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete audio", role: .destructive) {
                    pausePlayback(); player.stop()
                    do { try repository.deleteAudio(for: session.id); audioURL = nil; try rebuildCues() }
                    catch { failure = error is SessionProtectionFailure ? error.localizedDescription : "Could not delete the recording. Please try again." }
                }
            }
            .sheet(item: $export, onDismiss: { cleanup() }) { item in MediaActivityView(urls: item.urls) }
            .alert("Audio & subtitles", isPresented: Binding(get: { failure != nil || player.failure != nil }, set: { if !$0 { failure = nil; player.failure = nil } })) {
                Button("OK") { failure = nil; player.failure = nil }
            } message: { Text(LocalizedStringKey(failure ?? player.failure ?? "")) }
        }
    }

    private var playbackLayout: some View {
        VStack(spacing: 8) {
            if !compactPlayback { sourceSelectors }
            if !compactPlayback { Picker("Playback mode", selection: $atMyPace) {
                Text("Continuous").tag(false)
                Text("At my pace").tag(true)
            }.pickerStyle(.segmented).accessibilityIdentifier("playbackModePicker") }
            reader.id("playback-reader-top")
            if busy { ProgressView("Preparing files…") }
            playbackProgress
            PlaybackTransport(playing: isPlaying, title: primaryLabel,
                previousEnabled: neighbor(-1) != nil, nextEnabled: neighbor(1) != nil,
                enabled: !audibleParagraphs.isEmpty,
                previous: { moveParagraph(-1) }, toggle: { togglePlayback() }, next: { moveParagraph(1) })
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())) {
                Spacer()
                Button { showingPhrases = true } label: {
                    Label("Paragraphs", systemImage: "list.bullet").labelStyle(AccessibleControlLabelStyle())
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }.accessibilityIdentifier("openParagraphList")
                Button { showingOptions = true } label: {
                    Label("Playback options", systemImage: "ellipsis.circle")
                        .frame(minHeight: 44).contentShape(Rectangle())
                }.labelStyle(AccessibleControlLabelStyle()).accessibilityIdentifier("playbackOptionsButton")
            }.font(.subheadline).frame(minHeight: 44)
        }
        .padding(.horizontal)
    }

    private var sourceSelectors: some View {
        HStack {
            Menu {
                PlaybackPreferenceControls()
            } label: {
                Label { Text("Reading speed") }
                    icon: { Image(systemName: "speedometer") }
                    .frame(minHeight: 44).contentShape(Rectangle())
            }.accessibilityIdentifier("playbackAudioMenu")
            Spacer()
            Menu {
                Picker("Read and listen", selection: Binding(get: { reading }, set: {
                    reading = $0; savedLanguage = PlaybackLanguagePreference(mode: $0, source: language).rawValue
                })) {
                    Text("Original").tag(language.mode)
                    if currentTranslation {
                        Text("Translation").tag(target.mode)
                        Text("Both").tag(TranscriptLanguage.both)
                    }
                }
            } label: {
                Label { Text(uiKey(reading == .both ? "Both" : reading == language.mode ? "Original" : "Translation")) } icon: { Image(systemName: "text.bubble") }
                    .frame(minHeight: 44).contentShape(Rectangle())
            }.accessibilityLabel("Read and listen")
                .accessibilityValue(Text(LocalizedStringKey(reading.rawValue)))
                .accessibilityIdentifier("playbackTextMenu")
        }.font(.subheadline).frame(minHeight: 44)
    }
    private var reader: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let id = activeParagraphID, let original = reviewed.first(where: { $0.id == id }) {
                            if reading == language.mode || reading == .both {
                                PlaybackTextCard(text: original.text, language: language, translated: false, settings: settings,
                                    identifier: "playbackCaption", speaking: isPlaying && !waitingForLanguage && !speakingTranslation,
                                    edit: { beginParagraphEdit(id, translation: false) })
                                    .id("original-card")
                            }
                            if reading != language.mode, let translated = snapshot?.translated.first(where: { $0.id == id }) {
                                PlaybackTextCard(text: translated.text, language: target, translated: true, settings: settings,
                                    identifier: reading == .both ? "playbackTranslationCaption" : "playbackCaption",
                                    speaking: isPlaying && !waitingForLanguage && speakingTranslation,
                                    edit: { beginParagraphEdit(id, translation: true) }).id("translation-card")
                            }
                        } else { Text("Choose a paragraph, then tap Play.").padding() }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
                }
                .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in followingSpeech = false })
                .onChange(of: highlightedCard) { _, card in if followingSpeech { proxy.scrollTo(card, anchor: .top) } }
                .onChange(of: activeParagraphID) { _, _ in if followingSpeech { proxy.scrollTo(highlightedCard, anchor: .top) } }
                .onChange(of: isPlaying) { _, playing in if playing && followingSpeech { proxy.scrollTo(highlightedCard, anchor: .top) } }
                if !followingSpeech {
                    Button("Follow audio", systemImage: "arrow.down.to.line") {
                        followingSpeech = true; proxy.scrollTo(highlightedCard, anchor: .top)
                    }.frame(minHeight: 44).accessibilityIdentifier("followPlaybackAudio")
                }
            }
        }.frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 320 : nil,
                maxHeight: dynamicTypeSize.isAccessibilitySize ? 400 : .infinity)
            .accessibilityIdentifier("playbackCaptionScroll")
    }
    private var playbackProgress: some View {
        VStack(spacing: 4) {
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())) {
                if let index = reviewed.firstIndex(where: { $0.id == activeParagraphID }) {
                    Text("Paragraph \(index + 1) of \(reviewed.count)").accessibilityIdentifier("playbackParagraphPosition")
                }
                Spacer()
                Text(LocalizedStringKey(reading.rawValue))
            }.font(.caption).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack { speedSummary }
                VStack(alignment: .leading) { speedSummary }
            }.font(.caption).foregroundStyle(.secondary)
            Text(uiKey(atMyPace ? "At my pace" : "Continuous")).font(.caption)
            if let playbackStatus {
                Text(LocalizedStringKey(playbackStatus)).font(.caption.weight(.semibold))
                    .accessibilityIdentifier("playbackStatus")
            }
            if !compactPlayback && reading != .both {
            VStack(spacing: 4) {
            if !usesSequence && listening == .original && audioURL != nil {
                Slider(value: Binding(get: { player.time }, set: { player.seek($0) }), in: player.bounds)
                    .accessibilityLabel("Playback position")
                HStack {
                    Text(SessionClock.format(player.time - player.bounds.lowerBound))
                    Spacer()
                    Text(SessionClock.format(player.bounds.upperBound - player.bounds.lowerBound))
                }.font(.caption).monospacedDigit()
            } else {
                // Speech has no reliable audio duration: never borrow timestamps from the recording.
                Text(uiKey(reading == language.mode ? "Generated voice · original text" : "Generated voice · translation only")).font(.caption).foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            }
            }.frame(height: 56)
            }
        }
    }
    @ViewBuilder private var speedSummary: some View {
        if reading == language.mode || reading == .both {
            Text("Original speed") + Text(": ") + Text(LocalizedStringKey(originalSpeed.rawValue))
        }
        if reading != language.mode { Text("Translation speed") + Text(": ") + Text(LocalizedStringKey(speed.rawValue)) }
    }
    private var playbackOptions: some View {
        @Bindable var settings = settings
        return List {
            Section {
                sourceSelectors
                Picker("Playback mode", selection: $atMyPace) {
                    Text("Continuous").tag(false)
                    Text("At my pace").tag(true)
                }
                Button("Listen by phrase", systemImage: "list.bullet") {
                    afterOptions = { showingPhrases = true }; showingOptions = false
                }.accessibilityIdentifier("phraseListButton")
                Button("Restart paragraph", systemImage: "arrow.counterclockwise") {
                    if let activeParagraphID { selectParagraph(activeParagraphID) }
                    showingOptions = false
                }
                Button("Edit transcript", systemImage: "pencil") {
                    pausePlayback(); speech.stop(); afterOptions = { editing = true }; showingOptions = false
                }.accessibilityIdentifier("editMediaTranscriptButton")
            }
            Section("Reading preferences") {
                Toggle("Focused reading", isOn: $settings.focusedReading)
                Toggle("Show button names", isOn: $settings.showButtonNames)
                Text("Focused reading keeps one paragraph visible. Use Previous or Next, then Play when you are ready.").font(.caption)
                CaptionSizeControl(size: $settings.captionSize)
                Text("For long paragraphs, choose At my pace to finish reading before moving on. You can also scroll the text.").font(.caption)
                Toggle("Bold captions", isOn: $settings.boldCaptions)
                Toggle("High contrast", isOn: $settings.highContrast)
                Toggle("Renglones de cuaderno", isOn: $settings.ruledPaper)
                    .accessibilityIdentifier("ruledPaperToggle")
            }
            if audioURL == nil {
                Text("No audio saved for this session. Enable Save audio before starting your next session.")
            }
            Section("Export") {
                if audioURL != nil {
                    Button("Share audio (M4A)", systemImage: "waveform") { requestExport(.audio) }
                    Button("Share audio + text + subtitles", systemImage: "square.and.arrow.up") { requestExport(.bundle) }
                }
                Button("Subtitles (SRT)") { requestExport(.srt) }.disabled(cues.isEmpty)
                Button("Subtitles (WebVTT)") { requestExport(.vtt) }.disabled(cues.isEmpty)
                if cues.isEmpty {
                    Text("No synchronized captions are available. Older sessions keep their text but do not contain audio timing.").font(.caption)
                }
                Text("Exports use the original recording timeline, not the generated voice.").font(.caption)
                if hasCorrections || edited {
                    Text("Corrections are included. Timing within edited paragraphs is estimated; preview before sharing.").font(.caption)
                }
            }.disabled(busy)
            if audioURL != nil {
                Section("Manage session") {
                    Button("Delete audio, keep text", role: .destructive) {
                        pausePlayback(); afterOptions = { deleting = true }; showingOptions = false
                    }
                    if protected { Text("Remove protection before deleting the session or its audio.").font(.caption) }
                }.disabled(busy || protected)
            }
        }.listStyle(.insetGrouped).accessibilityIdentifier("mediaActionsList")
    }
    private func requestExport(_ kind: ExportKind) {
        afterOptions = { prepareExport(kind: kind) }; showingOptions = false
    }
    private func load() {
        do {
            reviewed = try repository.reviewedParagraphs(for: session)
            snapshot = try repository.translation(for: session.id)?.decoded()
            if let url = try repository.audioURL(for: session.id), FileManager.default.fileExists(atPath: url.path) {
                audioURL = url; player.load(url); player.speed = originalSpeed
            }
            listening = initialAudio == .translation && currentTranslation ? .translation : audioURL != nil ? .original : .translation
            reading = translationLanguage.flatMap(TranscriptLanguage.init(rawValue:)) ??
                (listening == .translation ? target.mode : language.mode)
            if translationLanguage == nil, initialAudio == .original, let preference = PlaybackLanguagePreference(rawValue: savedLanguage) {
                reading = preference.mode(source: language, hasTranslation: currentTranslation, target: target)
            }
            if !currentTranslation { reading = language.mode }
            listening = reading == target.mode ? .translation : .original
            sequence.load(audioURL)
            try rebuildCues()
            selectParagraph(initialParagraphID ?? audibleParagraphs.first?.id ?? reviewed.first?.id)
            speech.observeInterruptions()
        } catch { failure = "Could not open session media. Your transcript is unchanged." }
    }
    private func rebuildCues() throws {
        snapshot = try repository.translation(for: session.id)?.decoded()
        let times = try repository.media(for: session.id)?.decodedTimings() ?? [:]
        playbackParagraphs = PlaybackParagraph.make(reviewed, timings: times, duration: player.duration)
        let generated: [SubtitleCue]
        if currentTranslation, let snapshot { generated = TranslatedSubtitles.cues(snapshot: snapshot, timings: times, mode: reading) }
        else { generated = SubtitleExport.cues(paragraphs: reviewed, timings: times) }
        cues = generated.filter { audioURL == nil || $0.start < player.duration }.map {
            SubtitleCue(id: $0.id, paragraphID: $0.paragraphID, start: $0.start,
                end: audioURL == nil ? $0.end : min($0.end, player.duration), text: $0.text)
        }
    }
    private func neighbor(_ offset: Int) -> ReviewParagraph? {
        guard let index = audibleParagraphs.firstIndex(where: { $0.id == activeParagraphID }),
              audibleParagraphs.indices.contains(index + offset) else { return nil }
        return audibleParagraphs[index + offset]
    }
    private func moveParagraph(_ offset: Int) {
        if let paragraph = neighbor(offset) { selectParagraph(paragraph.id) }
    }
    /// Navigation selects silently; only the central button starts sound, in either language.
    private func selectParagraph(_ id: UUID?) {
        sequence.stop(); sequence.message = nil; pausePlayback(); speech.stop(); speech.message = nil; selectedParagraphID = id; originalStarted = false
        if let paragraph = playbackParagraphs.first(where: { $0.id == id }) {
            player.select(range: atMyPace ? paragraph.start...paragraph.end : nil)
            player.seek(paragraph.start)
        }
    }
    private func pausePlayback() {
        sequence.pause(); player.pause()
        if speech.state == .speaking { speech.togglePause() }
    }
    private func togglePlayback() {
        if usesSequence {
            player.pause(); speech.stop()
            if sequence.state == .playing { sequence.pause(); return }
            if sequence.state == .paused { sequence.resume(); return }
            guard let index = reviewed.firstIndex(where: { $0.id == activeParagraphID }) else { return }
            let values = atMyPace ? [reviewed[index]] : Array(reviewed[index...])
            sequence.start(ParagraphAudioStep.make(source: values, translated: currentTranslation ? snapshot?.translated ?? [] : [],
                language: language, mode: reading, ranges: playbackParagraphs, target: target), speed: speed, originalSpeed: originalSpeed, gapSeconds: languageGap)
            return
        }
        sequence.stop()
        if listening == .original { speech.stop(); originalStarted = true; player.toggle(); return }
        player.pause()
        if speech.state != .idle { speech.togglePause(); return }
        guard let index = audibleParagraphs.firstIndex(where: { $0.id == activeParagraphID }) else { return }
        let values = atMyPace ? [audibleParagraphs[index]] : Array(audibleParagraphs[index...])
        speech.start(values, language: target, speed: speed)
    }
    private func beginParagraphEdit(_ id: UUID, translation: Bool) {
        sequence.stop(); pausePlayback(); speech.stop(); selectedParagraphID = id
        do {
            let paragraph: ReviewParagraph?
            if translation {
                paragraph = try repository.translation(for: session.id)?.decoded().translated.first { $0.id == id }
            } else { paragraph = reviewed.first { $0.id == id } }
            editingParagraph = paragraph.map { ParagraphEditRequest(paragraph: $0, translation: translation) }
        } catch { failure = error.localizedDescription }
    }
    /// Guardar corrige texto por UUID, conserva audio y selección, y nunca reinicia la reproducción.
    private func saveParagraph(_ paragraph: ReviewParagraph, text: String, translation: Bool) throws {
        if translation {
            guard var snapshot = try repository.translation(for: session.id)?.decoded(),
                  snapshot.translated.contains(paragraph) else { throw ReviewFailure.sessionChanged }
            snapshot.edits[paragraph.id.uuidString] = text
            try repository.saveTranslation(snapshot, for: session)
        } else {
            var updated = try repository.reviewedParagraphs(for: session)
            guard let index = updated.firstIndex(of: paragraph) else { throw ReviewFailure.sessionChanged }
            updated[index].text = text
            try repository.saveCorrections(updated, for: session)
            reviewed = updated
        }
        edited = true
        sequence.stop(); speech.stop()
        try rebuildCues()
        if !currentTranslation {
            reading = language.mode
            if audioURL != nil { listening = .original }
        }
    }

    private func cleanup() {
        if let folder { try? FileManager.default.removeItem(at: folder) }
        folder = nil
    }

    private enum ExportKind { case audio, bundle, srt, vtt }
    /// Prepara archivos en una carpeta temporal propia; cleanup los elimina tras compartir/cancelar.
    /// La elección del destino pertenece al usuario mediante la hoja nativa de iOS.
    private func prepareExport(kind: ExportKind) {
        guard !busy else { return }
        pausePlayback(); cleanup(); busy = true
        do { try rebuildCues() } catch { failure = error.localizedDescription; busy = false; return }
        exportTask = Task { @MainActor in
            defer { busy = false }
            do {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceToRead-Media-" + UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
                folder = directory
                var urls: [URL] = []
                if kind == .audio || kind == .bundle {
                    guard let audioURL else { throw RecordingFailure.unavailable }
                    let url = directory.appendingPathComponent("Recording.m4a")
                    try await RecordingExport.m4a(from: audioURL, to: url)
                    urls.append(url)
                }
                try Task.checkCancellation()
                if kind == .bundle {
                    let url = directory.appendingPathComponent("Transcript.txt")
                    try TranscriptReview.text(currentTranslation ? snapshot?.paragraphs(mode: reading) ?? reviewed : reviewed).write(to: url, atomically: true, encoding: .utf8)
                    urls.append(url)
                }
                let formats: [SubtitleFormat] = kind == .srt ? [.srt] : kind == .vtt ? [.vtt] : kind == .bundle && !cues.isEmpty ? [.srt, .vtt] : []
                for format in formats {
                    let url = directory.appendingPathComponent("Subtitles." + format.rawValue)
                    try SubtitleExport.render(cues, format: format).write(to: url, atomically: true, encoding: .utf8)
                    urls.append(url)
                }
                for url in urls {
                    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
                }
                export = MediaShare(urls: urls)
            } catch is CancellationError { cleanup() }
            catch { cleanup(); failure = "Files could not be prepared. Check storage and try again. The saved recording is unchanged." }
        }
    }
}

struct MediaShare: Identifiable { let id = UUID(); let urls: [URL] }
struct MediaActivityView: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Codifica una copia M4A al compartir. El CAF original sigue siendo la fuente y no se modifica.
/// La cancelación se propaga al exportador; revisar su aislamiento antes de migrar a Swift 6.
enum RecordingExport {
    static func m4a(from source: URL, to destination: URL) async throws {
        guard let exporter = AVAssetExportSession(asset: AVURLAsset(url: source), presetName: AVAssetExportPresetAppleM4A) else {
            throw RecordingFailure.unavailable
        }
        exporter.outputURL = destination
        exporter.outputFileType = .m4a
        await withTaskCancellationHandler {
            await exporter.export()
        } onCancel: { exporter.cancelExport() }
        try Task.checkCancellation()
        guard exporter.status == .completed else { throw exporter.error ?? RecordingFailure.unavailable }
    }
}

private struct PlaybackButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.5 : 1) : 0.3)
    }
}

/// Shared transport: identical geometry, ordering and accessible names for every audio source.
enum PlaybackAudio: String { case original, translation }
struct PlaybackTransport: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let playing: Bool
    let title: String
    let previousEnabled: Bool
    let nextEnabled: Bool
    var enabled = true
    let previous: () -> Void
    let toggle: () -> Void
    let next: () -> Void
    var body: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))) {
            Button(action: previous) { transportLabel("Previous", symbol: "backward.end.fill") }
                .accessibilityLabel("Previous paragraph")
                .keyboardShortcut(.leftArrow, modifiers: .command)
                .disabled(!previousEnabled).accessibilityIdentifier("previousParagraphButton")
            Button(action: toggle) { transportLabel(title, symbol: playing ? "pause.fill" : "play.fill", prominent: true) }
                .accessibilityLabel(LocalizedStringKey(title))
                .disabled(!enabled).accessibilityIdentifier("recordingPlayButton")
            Button(action: next) { transportLabel("Next", symbol: "forward.end.fill") }
                .accessibilityLabel("Next paragraph")
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(!nextEnabled).accessibilityIdentifier("nextParagraphButton")
        }.buttonStyle(PlaybackButtonStyle()).frame(maxWidth: .infinity)
    }
    @Environment(AppSettings.self) private var settings

    /// The colored circle contains only the symbol; visible names have their own space below it.
    @MainActor private func transportLabel(_ title: String, symbol: String, prominent: Bool = false) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title2)
                .frame(width: 56, height: 56)
                .foregroundStyle(prominent ? Color.white : Color.accentColor)
                .background(prominent ? Color.accentColor : Color.clear, in: Circle())
                .accessibilityHidden(true)
            if settings.showButtonNames {
                Text(LocalizedStringKey(title)).font(.caption).accessibilityIdentifier("visibleControlName")
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity).contentShape(Rectangle())
    }
}
struct PlaybackTextCard: View {
    let text: String
    let language: CaptureLanguage
    let translated: Bool
    let settings: AppSettings
    var identifier = ""
    var speaking = false
    var edit: (() -> Void)? = nil
    @Environment(\.colorSchemeContrast) private var cardContrast
    @Environment(\.colorScheme) private var cardScheme
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(uiKey(translated ? "Translation \(language.name)" : "Original \(language.name)"))
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 8)
                if let edit {
                    Button(action: edit) {
                        Image(systemName: "pencil")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(uiKey(translated ? "Edit translation" : "Correct paragraph"))
                    .accessibilityIdentifier(translated ? "editPlaybackTranslationButton" : "editPlaybackOriginalButton")
                }
            }
            if speaking { Label("Listening now", systemImage: "speaker.wave.2.fill").font(.caption.weight(.bold)) }
            ReaderParagraph(text: text, points: settings.captionSize * textScale, spacing: settings.lineSpacing,
                            bold: settings.boldCaptions, ruled: settings.ruledPaper && !settings.highContrast)
                .textSelection(.enabled).accessibilityIdentifier(identifier)
        }.environment(\.colorScheme, settings.colorScheme ?? cardScheme)
         .modifier(LiveLanguageCard(color: settings.color(for: language), highContrast: settings.highContrast))
         .overlay(RoundedRectangle(cornerRadius: 12).stroke(speaking ? (settings.highContrast || cardContrast == .increased ? Color.primary : settings.color(for: language).accent) : .clear, lineWidth: 3))
    }
}

/// Equal-width entry buttons keep original/translation choices visually balanced.
struct PlaybackLaunchStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline).frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 6).background(Color.accentColor.opacity(configuration.isPressed ? 0.2 : 0.08),
                                            in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Shared controls persist locally for both the full player and inline listening.
struct PlaybackPreferenceControls: View {
    @AppStorage("originalPlaybackSpeed") private var original = TranslationSpeechSpeed.normal
    @AppStorage("translationSpeechSpeed") private var translation = TranslationSpeechSpeed.normal
    @AppStorage("playbackLanguageGap") private var gap = 0
    var body: some View {
        Section("Original speed") {
            Picker("Original speed", selection: $original) {
                ForEach(TranslationSpeechSpeed.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
            }
        }
        Section("Translation speed") {
            Picker("Translation speed", selection: $translation) {
                ForEach(TranslationSpeechSpeed.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
            }
        }
        Section("Pause between languages") {
            Picker("Pause between languages", selection: $gap) {
                Text("No pause").tag(0)
                Text("1 second").tag(1)
                Text("2 seconds").tag(2)
            }
        }
    }
}
