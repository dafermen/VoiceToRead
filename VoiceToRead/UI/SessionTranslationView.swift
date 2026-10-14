import SwiftUI
import AVFoundation
#if canImport(Translation)
import Translation
#endif

/// La vista mantiene una sola tarea por intento. Cerrar o cancelar desmonta el runner;
/// el UUID del intento impide que una respuesta tardía guarde datos tras la cancelación.
@MainActor
struct SessionTranslationView: View {
    let session: ConferenceSession
    let repository: TranscriptRepository
    var searchQuery = ""
    @Environment(\.dismiss) private var dismiss
    @State private var source: [ReviewParagraph] = []
    @State private var snapshot: TranslationSnapshot?
    @State private var mode: TranscriptLanguage = .spanish
    @State private var job: TranslationJob?
    @State private var progress = 0
    @State private var preparing = false
    @State private var exportTask: Task<Void, Never>?
    @State private var loaded = false
    @State private var audioDuration: Double?
    @State private var failure: String?
    @State private var editing = false
    @State private var playback: TranslationPlayback?
    @State private var previewKind = "txt"
    @State private var pendingExport: String?
    @State private var replacing = false
    @State private var exportMenu = false
    @State private var share: MediaShare?
    @State private var folder: URL?
    @State private var timings: [String: CaptionTiming] = [:]

    private var language: CaptureLanguage { CaptureLanguage(rawValue: session.language) ?? .english }
    private var current: Bool { loaded && snapshot?.language == language && snapshot?.isCurrent(source) == true }
    private var displayed: [ReviewParagraph] {
        mode == language.mode ? source : current ? snapshot?.paragraphs(mode: mode) ?? [] : []
    }
    private var cues: [SubtitleCue] {
        guard let snapshot, current else { return [] }
        let generated = TranslatedSubtitles.cues(snapshot: snapshot, timings: timings, mode: mode)
        guard let audioDuration else { return generated }
        return generated.compactMap { cue in
            guard cue.start < audioDuration else { return nil }
            return SubtitleCue(id: cue.id, paragraphID: cue.paragraphID, start: cue.start,
                end: min(cue.end, audioDuration), text: cue.text)
        }
    }
    private var canTranslate: Bool {
        #if canImport(Translation)
        if #available(iOS 18.0, *) { return true }
        #endif
        return false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Reading language", selection: $mode) {
                    ForEach(TranscriptLanguage.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }.pickerStyle(.segmented).padding().accessibilityIdentifier("translationLanguagePicker")
                status.padding(.horizontal)
                ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(displayed.enumerated()), id: \.element.id) { index, paragraph in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(paragraph.text).font(.title2).textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityIdentifier("translatedParagraph-\(index)")
                                if audioDuration != nil && cues.contains(where: { $0.paragraphID == paragraph.id }) {
                                    Button("Listen to original", systemImage: "play.circle") {
                                        playback = TranslationPlayback(paragraphID: paragraph.id)
                                    }.font(.caption).disabled(job != nil || preparing)
                                        .accessibilityIdentifier("listenTranslated-\(index)")
                                }
                            }.id(paragraph.id)
                        }
                    }.padding()
                }
                .onChange(of: displayed) { _, values in
                    if !searchQuery.isEmpty, let match = values.first(where: { $0.text.localizedStandardContains(searchQuery) }) {
                        proxy.scrollTo(match.id, anchor: .top)
                    }
                }
                }
                Divider()
                controls.padding(.horizontal).frame(minHeight: 54)
            }
            .navigationTitle("Translation").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { job = nil; dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if current {
                        Button("Edit \(language.opposite.name)", systemImage: "pencil") { editing = true }
                            .disabled(job != nil || preparing).accessibilityIdentifier("editSpanishButton")
                    }
                }
            }
            .background {
                if let job {
                    TranslationRunner(job: job, progress: { if self.job?.id == job.id { progress = $0 } }) { result in
                        guard self.job?.id == job.id else { return }
                        self.job = nil
                        do {
                            let generated = try result.get()
                            let updated = try job.plan.merging(generated)
                            try repository.saveTranslation(updated, for: session)
                            snapshot = updated; mode = language.opposite.mode
                        } catch is CancellationError { }
                        catch { failure = error.localizedDescription }
                    }.id(job.id)
                }
            }
            .task { load() }
            .sheet(isPresented: $editing) {
                if let snapshot {
                    TranscriptEditorView(originals: snapshot.generated, reviewed: snapshot.translated,
                                         translation: true) { edited in
                        var updated = snapshot
                        guard edited.map(\.id) == snapshot.generated.map(\.id) else { throw TranslationFailure.incomplete }
                        updated.edits = Dictionary(uniqueKeysWithValues: zip(snapshot.generated, edited).compactMap {
                            $0.text == $1.text ? nil : ($0.id.uuidString, $1.text)
                        })
                        try repository.saveTranslation(updated, for: session)
                        self.snapshot = updated
                    }
                }
            }
            .sheet(item: $playback, onDismiss: { load() }) { selection in
                SessionMediaView(session: session, repository: repository, paragraphs: displayed,
                    hasCorrections: true, initialParagraphID: selection.paragraphID, translatedCues: mode == language.mode ? nil : cues, translationLanguage: mode == language.mode ? nil : mode.rawValue)
            }
            .sheet(item: $share, onDismiss: cleanup) { item in MediaActivityView(urls: item.urls) }
            .sheet(isPresented: $exportMenu, onDismiss: {
                if let kind = pendingExport { pendingExport = nil; export(kind: kind) }
            }) { exportPreview }
            .confirmationDialog(uiKey("Translate again? This replaces the saved translation and its edits."),
                                isPresented: $replacing, titleVisibility: .visible) {
                Button("Replace translation", role: .destructive) { start(replaceAll: true) }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Translation", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK") { failure = nil }
            } message: { Text(LocalizedStringKey(failure ?? "")) }
            .onDisappear { job = nil; exportTask?.cancel(); if share == nil { cleanup() } }
        }
    }

    @ViewBuilder private var status: some View {
        if preparing { ProgressView("Preparing file…") }
        if let job {
            HStack {
                ProgressView(value: Double(progress), total: Double(max(1, job.source.count)))
                Text("\(progress)/\(job.source.count)").font(.caption).monospacedDigit()
                Button("Cancel") { self.job = nil }
            }
            Text("Preparing languages or translating…").font(.caption).foregroundStyle(.secondary)
        } else if snapshot != nil && !current {
            Text("The source text changed. Update changed paragraphs to keep edits in unchanged paragraphs.")
                .font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("translationOutdated")
        } else if !current {
            Text("Translate \(language.name) into \(language.opposite.name). The original text and audio are kept.")
                .font(.callout).foregroundStyle(.secondary)
        }
        if !canTranslate {
            Text("Creating translations requires iOS 18 or later and a compatible app build. Saved translations can still be read, edited and exported.")
                .font(.caption).foregroundStyle(.secondary)
        } else if !current && job == nil {
            Text("Apple may ask to download English and Spanish first. Downloaded languages allow on-device translation without internet.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack {
            Button(uiKey(current ? "Translate again" : snapshot == nil ? "Translate to \(language.opposite.name)" : "Update changed paragraphs"), systemImage: "character.bubble") {
                if current { replacing = true } else { start() }
            }.disabled(!canTranslate || !loaded || source.allSatisfy { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } || job != nil || preparing)
                .accessibilityIdentifier("translateSpanishButton")
            Spacer()
            if current {
                Button("Audio & subtitles", systemImage: "captions.bubble") { playback = TranslationPlayback(paragraphID: nil) }
                    .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    .disabled(job != nil || preparing).accessibilityIdentifier("translatedMediaButton")
            }
            Button("Share", systemImage: "square.and.arrow.up") { exportMenu = true }
                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                .disabled(!loaded || displayed.isEmpty || job != nil || preparing)
                .accessibilityIdentifier("shareTranslationButton")

        }.font(.subheadline)
    }

    private var exportPreview: some View {
        NavigationStack {
            Form {
                Section("Before sharing") {
                    LabeledContent("Language") { Text(LocalizedStringKey(mode.rawValue)) }
                    LabeledContent("Translation") { Text(uiKey(mode == language.mode ? "Original \(language.name)" : current ? "Up to date" : "Needs update")) }
                    Picker("Format", selection: $previewKind) {
                        Text("TXT").tag("txt")
                        Text("PDF").tag("pdf")
                        if !cues.isEmpty {
                            Text("SRT").tag("srt")
                            Text("VTT").tag("vtt")
                        }
                    }.pickerStyle(.segmented).accessibilityIdentifier("translationExportFormat")
                    if previewKind == "srt" || previewKind == "vtt" {
                        Text("Timing is approximate. Audio remains in \(language.name).").font(.caption)
                    }
                }
                Section("Preview (first 800 characters)") {
                    Text(String((previewKind == "srt" || previewKind == "vtt"
                        ? SubtitleExport.render(cues, format: previewKind == "srt" ? .srt : .vtt)
                        : TranscriptReview.text(displayed)).prefix(800))).textSelection(.enabled)
                }
                Button("Share file", systemImage: "square.and.arrow.up") {
                    pendingExport = previewKind; exportMenu = false
                }.accessibilityIdentifier("confirmTranslationShare")
                Button("Copy text") { UIPasteboard.general.string = TranscriptReview.text(displayed); exportMenu = false }
            }
            .navigationTitle("Review & share").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { exportMenu = false } }
            .onAppear { if cues.isEmpty { previewKind = "txt" } }
        }
    }

    private func start(replaceAll: Bool = false) {
        guard canTranslate, job == nil else { return }
        progress = 0
        let plan = IncrementalTranslation(source: source, previous: replaceAll ? nil : snapshot, language: language)
        if plan.pending.isEmpty {
            do {
                let updated = try plan.merging([])
                try repository.saveTranslation(updated, for: session); snapshot = updated
            } catch { failure = error.localizedDescription }
        } else { job = TranslationJob(plan: plan) }
    }
    private func load() {
        do {
            source = try repository.reviewedParagraphs(for: session)
            snapshot = try repository.translation(for: session.id)?.decoded()
            timings = try repository.media(for: session.id)?.decodedTimings() ?? [:]
            if let url = try repository.audioURL(for: session.id), FileManager.default.fileExists(atPath: url.path) {
                if let audio = try? AVAudioFile(forReading: url) {
                    audioDuration = Double(audio.length) / audio.processingFormat.sampleRate
                }
            }
            if !loaded { mode = language.opposite.mode }
            loaded = true
        } catch { failure = "Could not load the saved text or translation. Reopen this session before trying again." }
    }
    private func cleanup() {
        if let folder { try? FileManager.default.removeItem(at: folder) }
        folder = nil
    }
    private func export(kind: String) {
        guard !preparing else { return }
        preparing = true
        // Congelar el contenido antes del await evita mezclar idiomas si cambia el selector.
        let text = kind == "srt" || kind == "vtt"
            ? SubtitleExport.render(cues, format: kind == "srt" ? .srt : .vtt)
            : TranscriptReview.text(displayed)
        let filename = TranscriptExport.filename(title: session.title) + "-" + mode.fileSuffix + "." + kind
        exportTask = Task { @MainActor in
            defer { preparing = false }
            do {
                cleanup()
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VoiceToRead-Translation-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
                folder = directory
                let data: Data
                if kind == "pdf" {
                    let rendering = Task.detached(priority: .userInitiated) {
                        try TranscriptPDF.render(text: text, emphasizeTitle: false)
                    }
                    data = try await withTaskCancellationHandler(operation: { try await rendering.value },
                        onCancel: { rendering.cancel() })
                } else { data = Data(text.utf8) }
                try Task.checkCancellation()
                let url = directory.appendingPathComponent(filename)
                try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                share = MediaShare(urls: [url])
            } catch is CancellationError { cleanup() }
            catch { cleanup(); failure = "Could not prepare this file. Your saved translation is unchanged." }
        }
    }

}

private struct TranslationPlayback: Identifiable {
    let id = UUID()
    let paragraphID: UUID?
}

struct TranslationJob: Identifiable {
    let id = UUID()
    let plan: IncrementalTranslation
    let vocabulary: [PersonalVocabulary.Term]
    // Snapshot preferences once: a job must not mix dictionaries if settings change mid-translation.
    init(plan: IncrementalTranslation) {
        self.plan = plan
        vocabulary = PersonalVocabulary.saved(for: plan.language)
    }
    var source: [ReviewParagraph] { plan.pending }
}

@MainActor
struct TranslationRunner: View {
    let job: TranslationJob
    let progress: (Int) -> Void
    let finish: (Result<[ReviewParagraph], Error>) -> Void
    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-live-translation") {
            Color.clear.task {
                do {
                    try await Task.sleep(for: .milliseconds(400))
                    finish(.success(job.source.map { ReviewParagraph(id: $0.id,
                        text: job.plan.language == .english ? "Traducción de prueba. Leemos los dos idiomas juntos." : "Test translation. We read both languages together.") }))
                } catch { finish(.failure(error)) }
            }
        } else { productionRunner }
        #else
        productionRunner
        #endif
    }
    // A diferencia de body, una propiedad auxiliar no hereda el ViewBuilder del protocolo View.
    @ViewBuilder private var productionRunner: some View {
        #if canImport(Translation)
        if #available(iOS 18.0, *) {
            AppleTranslationRunner(job: job, progress: progress, finish: finish)
        } else { Color.clear.task { finish(.failure(TranslationFailure.unsupported)) } }
        #else
        Color.clear.task { finish(.failure(TranslationFailure.unsupported)) }
        #endif
    }
}

#if canImport(Translation)
@available(iOS 18.0, *)
@MainActor
private struct AppleTranslationRunner: View {
    let job: TranslationJob
    let progress: (Int) -> Void
    let finish: (Result<[ReviewParagraph], Error>) -> Void
    var body: some View {
        Color.clear.translationTask(source: Locale.Language(identifier: job.plan.language.code), target: Locale.Language(identifier: job.plan.language.opposite.code)) { @MainActor translator in
            do {
                try await translator.prepareTranslation()
                var translated: [ReviewParagraph] = []
                // Procesar párrafos completos conserva contexto y permite cancelar entre solicitudes.
                for paragraph in job.source {
                    try Task.checkCancellation()
                    let text: String
                    if paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { text = "" }
                    else { text = try await PersonalVocabulary.translate(paragraph.text, terms: job.vocabulary) {
                        try await translator.translate($0).targetText
                    } }
                    translated.append(ReviewParagraph(id: paragraph.id, text: text))
                    progress(translated.count)
                }
                try Task.checkCancellation()
                finish(.success(translated))
            } catch { finish(.failure(error)) }
        }
    }
}
#endif


/// Panel experimental: captura y traducción tienen ciclos independientes. Un fallo de traducción
/// se muestra aquí sin detener el micrófono. Se procesa como máximo un lote de cuatro párrafos.
@MainActor
struct LiveSpanishView: View {
    let paragraphs: [ReviewParagraph]
    let fontSize: Double
    var language: CaptureLanguage = .english
    var display: LiveCaptionDisplay = .translation
    var provisionalText = ""
    var lineSpacing: Double = 4
    var bold = false
    var ruled = false
    var highContrast = false
    @Environment(\.scenePhase) private var phase
    @State private var buffer = LiveTranslationBuffer()
    @State private var job: TranslationJob?
    @State private var failure: String?
    @State private var follow = true
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(display == .both ? "\(language.name) → \(language.opposite.name)" : "\(language.opposite.name)").font(.caption)
                Spacer()
                Button(uiKey(follow ? "Following" : "Follow latest")) { follow.toggle() }.font(.caption)
                    .frame(minHeight: 44).accessibilityIdentifier("liveTranslationFollowButton")
            }.padding(.horizontal)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(buffer.source) { paragraph in
                            paragraphPair(paragraph).id(paragraph.id)
                        }
                        if display == .both && !provisionalText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Original \(language.name)").font(.caption.weight(.semibold))
                                Text("Live · may change").font(.caption).foregroundStyle(.secondary)
                                readerText(provisionalText)
                                    .accessibilityIdentifier("liveBilingualProvisional")
                            }.modifier(LiveLanguageCard(language: language, highContrast: highContrast))
                        }
                        Color.clear.frame(height: 1).id("translationBottom")
                    }.padding()
                }
                .accessibilityIdentifier("liveTranslationReader")
                .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { value in
                    if value.translation.height > 10 { follow = false }
                })
                .onChange(of: buffer.translated) { _, _ in scrollIfFollowing(proxy) }
                .onChange(of: paragraphs) { _, _ in scrollIfFollowing(proxy) }
                .onChange(of: provisionalText) { _, _ in scrollIfFollowing(proxy) }
                .onChange(of: display) { _, _ in scrollIfFollowing(proxy) }
                .onChange(of: follow) { _, _ in scrollIfFollowing(proxy) }
            }
            if let failure {
                Text(LocalizedStringKey(failure)).font(.caption).padding(.horizontal)
                Button("Retry translation") { self.failure = nil; schedule() }
            } else {
                Text(uiKey(job == nil ? "Live preview is not saved. Translate the saved session to export." : "Translating confirmed text…"))
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            }
        }
        .background {
            if let job {
                TranslationRunner(job: job, progress: { _ in }) { result in
                    guard self.job?.id == job.id else { return }
                    self.job = nil
                    do { try buffer.accept(result.get(), for: job.source); schedule() }
                    catch is CancellationError { }
                    catch { failure = error.localizedDescription }
                }.id(job.id)
            }
        }
        .onAppear { buffer.synchronize(paragraphs); schedule() }
        .onChange(of: paragraphs) { _, values in
            buffer.synchronize(values)
            if values.isEmpty { job = nil; failure = nil }
            schedule()
        }
        .onChange(of: phase) { _, state in
            if state == .active { schedule() } else { job = nil }
        }
        .onDisappear { job = nil }
    }
    // El UUID enlaza ambos textos. Cambiar la presentación no reinicia la cola ni el micrófono.
    private func paragraphPair(_ paragraph: ReviewParagraph) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if display == .both || buffer.translated[paragraph.id] == nil {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original \(language.name)").font(.caption.weight(.semibold))
                    readerText(paragraph.text)
                        .accessibilityIdentifier("liveOriginal-" + paragraph.id.uuidString)
                }.modifier(LiveLanguageCard(language: language, highContrast: highContrast, enabled: display == .both))
            }
            if let translated = buffer.translated[paragraph.id] {
                VStack(alignment: .leading, spacing: 4) {
                    if display == .both {
                        Text("Translation \(language.opposite.name)").font(.caption.weight(.semibold))
                    }
                    readerText(translated)
                        .accessibilityIdentifier("liveTranslated-" + paragraph.id.uuidString)
                }.modifier(LiveLanguageCard(language: language.opposite, highContrast: highContrast, enabled: display == .both))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if display == .both {
                        Text("Translation \(language.opposite.name)").font(.caption.weight(.semibold))
                    }
                    Text("Waiting for translation…").font(.caption).foregroundStyle(.secondary)
                }.modifier(LiveLanguageCard(language: language.opposite, highContrast: highContrast, enabled: display == .both))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
    }
    private func readerText(_ text: String) -> some View {
        ReaderParagraph(text: text, points: fontSize, spacing: lineSpacing, bold: bold, ruled: ruled)
    }
    private func scrollIfFollowing(_ proxy: ScrollViewProxy) {
        if follow { proxy.scrollTo("translationBottom", anchor: .bottom) }
    }
    private func schedule() {
        guard phase == .active, job == nil, failure == nil, !buffer.pending.isEmpty else { return }
        job = TranslationJob(plan: IncrementalTranslation(source: buffer.pending, previous: nil, language: language))
    }
}

/// El color pertenece al idioma, no al rol original/traducción: inglés siempre azul,
/// español siempre verde. Las etiquetas siguen distinguiéndolos sin depender del color.
/// El modifier conserva el texto seleccionable, sus renglones y los elementos de VoiceOver.
private struct LiveLanguageCard: ViewModifier {
    let language: CaptureLanguage
    let highContrast: Bool
    var enabled = true
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    private var strongContrast: Bool { highContrast || contrast == .increased }
    private var accent: Color { language == .english ? .blue : .green }
    private var fill: Color {
        if strongContrast { return scheme == .dark ? .black : .white }
        if scheme == .dark {
            return language == .english
                ? Color(red: 0.08, green: 0.16, blue: 0.24)
                : Color(red: 0.08, green: 0.20, blue: 0.15)
        }
        return language == .english
            ? Color(red: 0.89, green: 0.95, blue: 1)
            : Color(red: 0.90, green: 0.97, blue: 0.91)
    }

    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fill)
                        .shadow(color: .black.opacity(strongContrast ? 0 : 0.12), radius: 3, x: 0, y: 2)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(strongContrast ? Color.primary : accent.opacity(0.4), lineWidth: strongContrast ? 2 : 1)
                        }
                        .accessibilityHidden(true)
                }
        } else {
            content
        }
    }
}
