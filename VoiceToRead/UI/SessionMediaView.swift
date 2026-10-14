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
    private var engine = AVAudioEngine()
    private var node = AVAudioPlayerNode()
    private var file: AVAudioFile?
    private var timer: Task<Void, Never>?
    private var interruption: NSObjectProtocol?
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
            engine = AVAudioEngine(); node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
            interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.pause() }
            }
        } catch { failure = "This recording could not be opened. The transcript is still available." }
    }
    func select(range: ClosedRange<Double>?) {
        pause()
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
        guard let file else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
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
                    self.pause(); self.time = end
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
    func pause() {
        updateTime(); generation = UUID()
        timer?.cancel(); timer = nil
        node.stop(); engine.pause(); playing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func stop() {
        if let interruption { NotificationCenter.default.removeObserver(interruption) }
        interruption = nil
        pause(); engine.stop(); file = nil; time = 0; duration = 0; range = nil
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

@MainActor
struct SessionMediaView: View {
    let session: ConferenceSession
    let repository: TranscriptRepository
    let paragraphs: [ReviewParagraph]
    let hasCorrections: Bool
    var initialParagraphID: UUID? = nil
    var translatedCues: [SubtitleCue]? = nil
    var translationLanguage: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var player = SessionPlayer()
    @State private var audioURL: URL?
    @State private var cues: [SubtitleCue] = []
    @State private var captions = true
    @State private var showingPhrases = false
    @State private var deleting = false
    @State private var busy = false
    @State private var failure: String?
    @State private var export: MediaShare?
    @State private var folder: URL?
    @State private var exportTask: Task<Void, Never>?
    @State private var fullScreen = false
    @State private var editing = false
    @State private var editingParagraph: ReviewParagraph?
    @State private var selectedParagraphID: UUID?
    @State private var playbackParagraphs: [PlaybackParagraph] = []
    @AppStorage("playbackAtMyPace") private var atMyPace = false
    @Query private var favorites: [SessionFavorite]
    private var protected: Bool { favorites.contains { $0.sessionID == session.id } }
    private var selectedParagraph: PlaybackParagraph? { playbackParagraphs.first { $0.id == selectedParagraphID } }
    private var activeParagraphID: UUID? { atMyPace ? selectedParagraphID : currentCue?.paragraphID ?? selectedParagraphID }
    private var captionText: String? { atMyPace ? selectedParagraph?.text : currentCue?.text }
    @State private var reviewed: [ReviewParagraph] = []
    @State private var edited = false
    @Environment(\.scenePhase) private var phase
    private var currentCue: SubtitleCue? { cues.first { $0.start <= player.time && player.time < $0.end } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if audioURL != nil {
                    if !fullScreen {
                    Picker("Playback mode", selection: $atMyPace) {
                        Text("Continuous").tag(false)
                        Text("At my pace").tag(true)
                    }.pickerStyle(.segmented).accessibilityIdentifier("playbackModePicker")
                    }
                    if captions {
                        ScrollView {
                        (captionText.map { Text(verbatim: $0) } ?? Text(uiKey(player.playing ? "…" : "Play to read synchronized captions")))
                            .font(.title2.weight(.medium)).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
                            .padding().background(.black, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white).accessibilityIdentifier("playbackCaption")
                        }.id(activeParagraphID)
                            .frame(maxHeight: fullScreen ? .infinity : 160)
                            .background(.black, in: RoundedRectangle(cornerRadius: 16))
                    }
                    if !fullScreen {
                    Slider(value: Binding(get: { player.time }, set: { player.seek($0) }),
                           in: player.bounds)
                        .accessibilityLabel("Playback position")
                        .accessibilityValue(SessionClock.format(player.time))
                    HStack {
                        Text(SessionClock.format(player.time)).monospacedDigit()
                        Spacer()
                        Text(SessionClock.format(atMyPace ? player.bounds.upperBound : player.duration)).monospacedDigit()
                    }.font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: fullScreen ? 20 : 28) {
                        if atMyPace {
                            Button("Repeat paragraph", systemImage: "arrow.counterclockwise") {
                                if let selectedParagraph { playParagraph(selectedParagraph) }
                            }.disabled(selectedParagraph == nil)
                                .accessibilityIdentifier("repeatParagraphButton")
                        } else {
                            Button("Back 10 seconds", systemImage: "gobackward.10") { player.seek(player.time - 10) }
                        }
                        Button(uiKey(player.playing ? "Pause" : "Play"), systemImage: player.playing ? "pause.fill" : "play.fill") { player.toggle() }
                            .accessibilityIdentifier("recordingPlayButton")
                            .disabled(atMyPace && selectedParagraph == nil)
                        if atMyPace {
                            Button("Next paragraph", systemImage: "forward.end.fill") { nextParagraph() }
                                .disabled(nextPlaybackParagraph == nil).accessibilityIdentifier("nextParagraphButton")
                        } else {
                            Button("Forward 10 seconds", systemImage: "goforward.10") { player.seek(player.time + 10) }
                        }
                        Button("Subtitles", systemImage: captions ? "captions.bubble.fill" : "captions.bubble") { captions.toggle() }
                            .accessibilityValue(uiKey(captions ? "On" : "Off"))
                        if fullScreen, let activeParagraphID {
                            Button("Correct paragraph", systemImage: "pencil") { beginParagraphEdit(activeParagraphID) }
                                .accessibilityIdentifier("editPlaybackParagraphButton")
                        }
                    }.labelStyle(.iconOnly).font(.title2).buttonStyle(PlaybackButtonStyle())
                        .frame(minHeight: 44)
                    if !fullScreen, let activeParagraphID {
                        Button(uiKey(translatedCues != nil && translationLanguage != sessionSourceLanguage ? "Edit translation" : "Correct paragraph"), systemImage: "pencil") {
                            beginParagraphEdit(activeParagraphID)
                        }.frame(minHeight: 44).accessibilityIdentifier("editPlaybackParagraphButton")
                    }
                }
                if !fullScreen {
                    List {
                        if audioURL == nil { Text("No audio saved for this session. Enable Save audio before starting your next session.") }
                        if translatedCues == nil {
                        Section {
                            Button("Edit transcript", systemImage: "pencil") { player.pause(); editing = true }
                                .accessibilityIdentifier("editMediaTranscriptButton")
                        }
                        }
                        if let translationLanguage {
                            Text(uiKey("Captions: \(translationLanguage). Audio remains in \(CaptureLanguage(rawValue: session.language)?.name ?? "English"). Timing within each paragraph is approximate.")).font(.caption)
                        }
                        if audioURL != nil && !cues.isEmpty {
                            Section {
                                if atMyPace {
                                    Text("One paragraph at a time. Repeat it or choose Next when you are ready.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Button(uiKey(showingPhrases ? "Hide phrases" : "Listen by phrase"),
                                       systemImage: showingPhrases ? "chevron.up" : "chevron.down") { showingPhrases.toggle() }
                                    .accessibilityValue(uiKey(showingPhrases ? "Expanded" : "Collapsed"))
                                    .accessibilityIdentifier("phraseListButton")
                                if showingPhrases {
                                ForEach(Array(playbackParagraphs.enumerated()), id: \.element.id) { index, paragraph in
                                    Button { playParagraph(paragraph) } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            (paragraph.text.isEmpty ? Text("Empty paragraph") : Text(verbatim: paragraph.text))
                                                .foregroundStyle(.primary)
                                            Label(SessionClock.format(paragraph.start), systemImage: "play.circle")
                                                .font(.caption)
                                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                                    }
                                    .listRowBackground(activeParagraphID == paragraph.id ? Color.accentColor.opacity(0.12) : Color.clear)
                                    .accessibilityHint(uiKey(atMyPace ? "Play only this paragraph" : "Listen from this paragraph"))
                                    .accessibilityIdentifier("listenPlaybackParagraph-\(index)")
                                }
                                }
                            }
                        }
                        Section("Export") {
                            if audioURL != nil {
                                Button("Share audio (M4A)", systemImage: "waveform") { prepareExport(kind: .audio) }
                                Button("Share audio + text + subtitles", systemImage: "square.and.arrow.up") { prepareExport(kind: .bundle) }
                            }
                            Button("Subtitles (SRT)") { prepareExport(kind: .srt) }.disabled(cues.isEmpty)
                            Button("Subtitles (WebVTT)") { prepareExport(kind: .vtt) }.disabled(cues.isEmpty)
                            if cues.isEmpty { Text("No synchronized captions are available. Older sessions keep their text but do not contain audio timing.").font(.caption) }
                            if hasCorrections || edited { Text("Corrections are included. Timing within edited paragraphs is estimated; preview before sharing.").font(.caption) }
                            Text("Pauses are removed from saved audio and subtitles. These files follow this session's recording, not the timeline of an external video.").font(.caption)
                        }.disabled(busy)
                        if audioURL != nil {
                            Section {
                                Button("Delete audio, keep text", role: .destructive) { player.pause(); deleting = true }
                                if protected { Text("Remove protection before deleting the session or its audio.").font(.caption) }
                            }.disabled(busy || protected)
                        }
                        if busy { HStack { ProgressView(); Text("Preparing files…") } }
                    }.listStyle(.insetGrouped).accessibilityIdentifier("mediaActionsList")
                }
            }
            .padding(.horizontal)
            .navigationTitle("Audio & subtitles").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    if audioURL != nil {
                        Button(uiKey(fullScreen ? "Exit full screen" : "Full screen"), systemImage: fullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                            captions = true; fullScreen.toggle()
                        }
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
            .sheet(item: $editingParagraph) { paragraph in
                ParagraphEditorView(paragraph: paragraph, savesImmediately: true,
                    translation: translatedCues != nil && translationLanguage != sessionSourceLanguage) { text in
                    try saveParagraph(paragraph, text: text)
                }
            }
            .task { reviewed = paragraphs; load() }
            .onChange(of: atMyPace) { _, _ in
                player.pause()
                if atMyPace {
                    let match = playbackParagraphs.first { $0.start <= player.time && player.time < $0.end }
                    if let paragraph = match ?? selectedParagraph ?? playbackParagraphs.first {
                        selectedParagraphID = paragraph.id
                        player.select(range: paragraph.start...paragraph.end)
                    }
                    showingPhrases = true
                } else { player.select(range: nil) }
            }
            .onDisappear { player.stop(); exportTask?.cancel(); cleanup() }
            .onChange(of: phase) { _, phase in if phase != .active { player.pause() } }
            .confirmationDialog(uiKey("Delete the recording permanently? Your text and subtitles will stay."), isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete audio", role: .destructive) {
                    player.stop()
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

    private func load() {
        do {
            if let url = try repository.audioURL(for: session.id), FileManager.default.fileExists(atPath: url.path) {
                audioURL = url; player.load(url)
            }
            try rebuildCues()
            if let paragraph = playbackParagraphs.first(where: { $0.id == initialParagraphID }) {
                showingPhrases = true
                playParagraph(paragraph)
            } else if atMyPace, let paragraph = playbackParagraphs.first {
                selectedParagraphID = paragraph.id
                player.select(range: paragraph.start...paragraph.end)
                showingPhrases = true
            }
        } catch { failure = "Could not open session media. Your transcript is unchanged." }
    }

    private func rebuildCues() throws {
        let times = try repository.media(for: session.id)?.decodedTimings() ?? [:]
        playbackParagraphs = PlaybackParagraph.make(reviewed, timings: times, duration: player.duration)
        var generated = SubtitleExport.cues(paragraphs: reviewed, timings: times)
        if translatedCues != nil, let mode = translationLanguage.flatMap(TranscriptLanguage.init(rawValue:)),
           let snapshot = try repository.translation(for: session.id)?.decoded() {
            reviewed = snapshot.paragraphs(mode: mode)
            playbackParagraphs = PlaybackParagraph.make(reviewed, timings: times, duration: player.duration)
            generated = TranslatedSubtitles.cues(snapshot: snapshot, timings: times, mode: mode)
        }
        // A failed recording may retain only a prefix. Never display captions past that prefix.
        if audioURL != nil, player.duration > 0 {
            cues = generated.compactMap { cue in
                guard cue.start < player.duration else { return nil }
                return SubtitleCue(id: cue.id, paragraphID: cue.paragraphID, start: cue.start,
                    end: min(cue.end, player.duration), text: cue.text)
            }
        } else { cues = generated }
    }

    private var sessionSourceLanguage: String { (CaptureLanguage(rawValue: session.language) ?? .english).mode.rawValue }
    private var nextPlaybackParagraph: PlaybackParagraph? {
        guard let index = playbackParagraphs.firstIndex(where: { $0.id == selectedParagraphID }),
              index + 1 < playbackParagraphs.count else { return nil }
        return playbackParagraphs[index + 1]
    }
    private func playParagraph(_ paragraph: PlaybackParagraph) {
        selectedParagraphID = paragraph.id
        player.select(range: atMyPace ? paragraph.start...paragraph.end : nil)
        player.play(from: paragraph.start)
    }
    private func nextParagraph() {
        if let next = nextPlaybackParagraph { playParagraph(next) }
    }
    private func beginParagraphEdit(_ id: UUID) {
        player.pause(); selectedParagraphID = id
        do {
            if translatedCues != nil && translationLanguage != sessionSourceLanguage {
                editingParagraph = try repository.translation(for: session.id)?.decoded().translated.first { $0.id == id }
            } else { editingParagraph = reviewed.first { $0.id == id } }
        } catch { failure = error.localizedDescription }
    }
    /// Guardar corrige texto por UUID, conserva audio y selección, y nunca reinicia la reproducción.
    private func saveParagraph(_ paragraph: ReviewParagraph, text: String) throws {
        if translatedCues != nil && translationLanguage != sessionSourceLanguage {
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
        try rebuildCues()
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
        player.pause(); cleanup(); busy = true
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
                    try TranscriptReview.text(reviewed).write(to: url, atomically: true, encoding: .utf8)
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}
