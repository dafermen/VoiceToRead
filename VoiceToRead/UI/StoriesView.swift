import SwiftUI
import UIKit

@MainActor
struct StoryLibraryView: View {
    @State private var store: StoryStore?
    @State private var failure: String?
    @State private var creating = false
    var body: some View {
        Group {
            if let store {
                List {
                    Section {
                        Text("Choose a story to read and listen. An adult can add stories and review their translations.")
                            .font(.subheadline)
                        Text("Stories stay on this device. No microphone or recording is used.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if store.stories.isEmpty {
                        ContentUnavailableView("No stories yet", systemImage: "book.closed", description: Text("Use + to add a story."))
                    }
                    ForEach(store.stories.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }) { story in
                        NavigationLink { StoryReaderView(store: store, storyID: story.id) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: story.title).font(.headline)
                                HStack {
                                    Text(story.sourceLanguage.pickerLabel)
                                    Image(systemName: "arrow.right").accessibilityHidden(true)
                                    Text(story.targetLanguage.pickerLabel)
                                }.font(.caption).foregroundStyle(.secondary)
                            }
                        }.accessibilityIdentifier("story-" + story.id.uuidString)
                    }
                }
                .toolbar {
                    HomeCircleToolbarItem {
                        HomeCircleAction(title: "New story", symbol: "plus") { creating = true }
                            .accessibilityIdentifier("newStory")
                    }
                }
                .sheet(isPresented: $creating) { StorySourceEditor(store: store) }
            } else {
                ContentUnavailableView {
                    Label("Story library unavailable", systemImage: "exclamationmark.triangle")
                } description: { Text(LocalizedStringKey(failure ?? "Opening stories…")) } actions: {
                    Button("Retry") { open() }
                }
            }
        }
        .navigationTitle("Stories").navigationBarTitleDisplayMode(.inline)
        .task { if store == nil { open() } }
    }
    private func open() {
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-test-stories") {
                let name = ProcessInfo.processInfo.environment["STORIES_TEST_ID"] ?? UUID().uuidString
                store = try StoryStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("Stories-UITests").appendingPathComponent(name))
            } else { store = try StoryStore() }
            #else
            store = try StoryStore()
            #endif
            failure = nil
        } catch { failure = error.localizedDescription }
    }
}

@MainActor
private struct StorySourceEditor: View {
    let store: StoryStore
    var previous: StoryDocument?
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var text: String
    @State private var source: CaptureLanguage
    @State private var target: CaptureLanguage
    @State private var failure: String?
    @State private var confirmingReset = false
    @State private var confirmingDiscard = false
    init(store: StoryStore, previous: StoryDocument? = nil) {
        self.store = store; self.previous = previous
        _title = State(initialValue: previous?.title ?? "")
        _text = State(initialValue: previous?.sourceText ?? "")
        _source = State(initialValue: previous?.sourceLanguage ?? .spanish)
        _target = State(initialValue: previous?.targetLanguage ?? .english)
    }
    private var dirty: Bool {
        title != (previous?.title ?? "") || text != (previous?.sourceText ?? "") ||
        source != (previous?.sourceLanguage ?? .spanish) || target != (previous?.targetLanguage ?? .english)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Story preparation · for adults") {
                    TextField("Story title", text: $title).accessibilityIdentifier("storyTitle")
                    LanguagePickerControl(title: "Source language", selection: $source, showRole: true)
                    LanguagePickerControl(title: "Translate to", selection: $target,
                        choices: CaptureLanguage.allCases.filter { $0 != source }, showRole: true)
                    Text("Write the story in the source language, with one paragraph per line. Review the translated story before a child listens.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Story text") {
                    TextEditor(text: $text).frame(minHeight: 260).accessibilityIdentifier("storySourceInput")
                }
                if let failure { Text(LocalizedStringKey(failure)).foregroundStyle(.red) }
            }
            .navigationTitle(uiKey(previous == nil ? "New story" : "Edit story")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if dirty { confirmingDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            let result = try StoryDocument.edited(title: title, text: text, source: source, target: target, previous: previous)
                            if let previous, previous.hasTranslations, !result.hasTranslations { confirmingReset = true }
                            else { save(result) }
                        } catch { failure = error.localizedDescription }
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || source == target)
                        .accessibilityIdentifier("saveStory")
                }
            }
            .onChange(of: source) { _, value in if value == target { target = value.defaultTarget } }
            .interactiveDismissDisabled(dirty)
            .confirmationDialog("Replace this story's translation?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Save changes", role: .destructive) {
                    do { save(try StoryDocument.edited(title: title, text: text, source: source, target: target, previous: previous)) }
                    catch { failure = error.localizedDescription }
                }
                Button("Cancel", role: .cancel) { }
            } message: { Text("Changing the original text or its language clears all translations and approvals for this story. Other stories stay unchanged.") }
            .confirmationDialog("Discard changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    private func save(_ value: StoryDocument) {
        do { try store.save(value, replacing: previous); dismiss() }
        catch { failure = error.localizedDescription }
    }
}

@MainActor
private struct StoryReaderView: View {
    let store: StoryStore
    let storyID: UUID
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var narrator = StoryNarrator()
    @State private var translated = false
    @State private var slow = true
    @State private var editing = false
    @State private var reviewing = false
    @State private var options = false
    @State private var confirmingTranslation = false
    @State private var confirmingDelete = false
    @State private var job: TranslationJob?
    @State private var snapshot: StoryDocument?
    @State private var progress = 0
    @State private var failure: String?
    private var story: StoryDocument? { store.story(storyID) }
    var body: some View {
        Group {
            if let story {
                VStack(spacing: 0) {
                    CommunicationLanguagePair(symbol: "arrow.right") {
                        LanguagePickerControl(title: "Original language", selection: .constant(story.sourceLanguage),
                            choices: [story.sourceLanguage], showRole: true, stackedRole: true)
                            .disabled(true).accessibilityIdentifier("storyOriginalLanguage")
                    } right: {
                        LanguagePickerControl(title: "Translate to", selection: Binding(
                            get: { story.targetLanguage },
                            set: { target in
                                narrator.stop(); translated = false
                                do { try store.selectTarget(story, target: target) }
                                catch { failure = error.localizedDescription }
                            }),
                            choices: CaptureLanguage.allCases.filter { $0 != story.sourceLanguage },
                            showRole: true, stackedRole: true)
                            .disabled(job != nil).accessibilityIdentifier("storyTranslationTarget")
                    }.padding(.horizontal).padding(.top, 8).padding(.bottom, 8)
                    if story.translatedReady {
                        Picker("Reading language", selection: $translated) {
                            Text("Original").tag(false)
                            Text("Translation").tag(true)
                        }.pickerStyle(.segmented).disabled(job != nil)
                            .padding(.horizontal).padding(.bottom, 8)
                            .accessibilityIdentifier("storyReadingVersion")
                    }
                    preparation(story)
                    if let message = failure ?? narrator.message {
                        Text(LocalizedStringKey(message)).font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                    }
                    StoryReadingText(text: translated ? story.translatedText : story.sourceText,
                        spoken: narrator.progress.text == (translated ? story.translatedText : story.sourceText) ? narrator.progress.range : nil, following: narrator.state == .playing,
                        points: settings.captionSize, bold: settings.boldCaptions, spacing: settings.lineSpacing,
                        foreground: settings.readerPaper != .system && !settings.highContrast ? .black : .label)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ReaderSurface(settings: settings))
                    Divider()
                    controls(story)
                }
                .navigationTitle(story.title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button("Edit story", systemImage: "pencil") { narrator.stop(); editing = true }
                                .disabled(job != nil).accessibilityIdentifier("editStory")
                            Button(uiKey(story.translation == nil ? "Translate" : "Translate again"), systemImage: "character.bubble") {
                                requestTranslation(story)
                            }.disabled(job != nil || !TranslationJob.supported).accessibilityIdentifier("translateStory")
                            Button("Review translations", systemImage: "text.badge.checkmark") { narrator.stop(); reviewing = true }
                                .disabled(job != nil || story.translation == nil).accessibilityIdentifier("reviewStory")
                            Button("Reading options", systemImage: "textformat.size") { options = true }
                            Button(role: .destructive) { narrator.stop(); confirmingDelete = true } label: {
                                Label("Delete story", systemImage: "trash")
                            }.disabled(job != nil)
                        } label: { Label("Story options", systemImage: "ellipsis.circle").labelStyle(.iconOnly) }
                            .accessibilityIdentifier("storyOptions")
                    }
                }
                .sheet(isPresented: $editing) { StorySourceEditor(store: store, previous: story) }
                .sheet(isPresented: $reviewing) { StoryTranslationReview(store: store, story: story) }
                .sheet(isPresented: $options) {
                    NavigationStack {
                        Form { CaptionSizeControl(size: Binding(get: { settings.captionSize }, set: { settings.captionSize = $0 })) }
                            .navigationTitle("Reading options").toolbar { DoneToolbar { options = false } }
                    }
                }
                .confirmationDialog("Translate all phrases again?", isPresented: $confirmingTranslation, titleVisibility: .visible) {
                    Button("Replace translations", role: .destructive) { translate(story) }
                    Button("Cancel", role: .cancel) { }
                } message: { Text("Only the selected language's translation and corrections are replaced after translation succeeds. Other languages are kept. An adult must review the new version.") }
                .confirmationDialog("Delete this story?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete story", role: .destructive) {
                        do { try store.delete(story); dismiss() } catch { failure = error.localizedDescription }
                    }.accessibilityIdentifier("confirmDeleteStory")
                    Button("Cancel", role: .cancel) { }
                } message: { Text("This deletes only this story and its translation. Sessions and trainings are kept.") }
                .onChange(of: story) { _, _ in narrator.stop(); if !story.translatedReady { translated = false } }
            } else { Text("This story is no longer available.") }
        }
        .onChange(of: translated) { _, _ in narrator.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { narrator.stop() } }
        .onAppear { narrator.observeInterruptions() }
        .onDisappear { narrator.close(); job = nil; snapshot = nil }
        .background {
            if let job {
                TranslationRunner(job: job, progress: { if self.job?.id == job.id { progress = $0 } }) { result in
                    guard self.job?.id == job.id, let snapshot else { return }
                    self.job = nil; self.snapshot = nil
                    do { try store.acceptTranslation(snapshot, responses: result.get(), target: job.plan.target) }
                    catch { failure = error.localizedDescription }
                }.id(job.id)
            }
        }
    }
    /// Keep the next preparation step visible without hiding the original narration.
    private func preparation(_ story: StoryDocument) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let job {
                Text("Translating the story…")
                    .accessibilityIdentifier("storyPreparationStatus")
                HStack {
                    ProgressView(value: Double(progress), total: Double(max(1, job.source.count)))
                    Button("Cancel translation") { self.job = nil; snapshot = nil }
                        .frame(minHeight: 44).accessibilityIdentifier("storyCancelTranslation")
                }
            } else if story.translation == nil {
                Text("Choose the language you want to translate the story into, then press Translate.")
                    .accessibilityIdentifier("storyPreparationStatus")
                Button("Translate", systemImage: "character.bubble") { requestTranslation(story) }
                    .buttonStyle(.bordered).controlSize(.small).frame(minHeight: 44)
                    .disabled(!TranslationJob.supported).accessibilityIdentifier("storyTranslateAction")
            } else if !story.translatedReady {
                Text("Translation ready. An adult must review and approve it before listening.")
                    .accessibilityIdentifier("storyPreparationStatus")
                Button("Review and approve", systemImage: "text.badge.checkmark") { narrator.stop(); reviewing = true }
                    .buttonStyle(.bordered).controlSize(.small).frame(minHeight: 44)
                    .accessibilityIdentifier("storyReviewAction")
            } else {
                Text("All set. Select the reading language and press Play.")
                    .accessibilityIdentifier("storyPreparationStatus")
            }
        }
        .font(.caption).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal).padding(.bottom, 8)
    }
    private func requestTranslation(_ story: StoryDocument) {
        narrator.stop()
        if story.translation != nil { confirmingTranslation = true } else { translate(story) }
    }

    private func controls(_ story: StoryDocument) -> some View {
        VStack(spacing: 8) {
            Toggle("Slow reading", isOn: $slow).disabled(narrator.state != .idle).font(.subheadline)
                .accessibilityIdentifier("storySlowReading")
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))) {
                Button {
                    if narrator.state == .idle {
                        narrator.start(text: translated ? story.translatedText : story.sourceText,
                            language: translated ? story.targetLanguage : story.sourceLanguage, slow: slow)
                    } else { narrator.togglePause() }
                } label: {
                    Label(uiKey(narrator.state == .playing ? "Pause" : narrator.state == .paused ? "Resume" : "Play"),
                          systemImage: narrator.state == .playing ? "pause.fill" : "play.fill")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.borderedProminent)
                    .disabled(job != nil || (translated && !story.translatedReady)).accessibilityIdentifier("storyPlay")
                Button { narrator.stop() } label: {
                    Label("Stop", systemImage: "stop.fill").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.bordered).tint(.red)
                    .disabled(narrator.state == .idle).accessibilityIdentifier("storyStop")
            }
        }.padding(.horizontal, 16).padding(.vertical, 8).background(Color(uiColor: .systemBackground))
    }
    private func translate(_ story: StoryDocument) {
        guard TranslationJob.supported, job == nil else { return }
        let target = story.targetLanguage
        guard target != story.sourceLanguage else { return }
        failure = nil; progress = 0; snapshot = story
        job = TranslationJob(plan: IncrementalTranslation(source: story.paragraphs, previous: nil,
            language: story.sourceLanguage, targetLanguage: target))
    }
}

@MainActor
private struct StoryTranslationReview: View {
    let store: StoryStore
    let story: StoryDocument
    @Environment(\.dismiss) private var dismiss
    @State private var values: [UUID: String]
    @State private var failure: String?
    @State private var confirmingDiscard = false
    init(store: StoryStore, story: StoryDocument) {
        self.store = store; self.story = story
        _values = State(initialValue: Dictionary(uniqueKeysWithValues: (story.translation?.translated ?? []).map { ($0.id, $0.text) }))
    }
    private var dirty: Bool { values != Dictionary(uniqueKeysWithValues: (story.translation?.translated ?? []).map { ($0.id, $0.text) }) }
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Review the meaning and language before a child listens. Save when the translated story is ready.") }
                ForEach(story.paragraphs) { paragraph in
                    Section {
                        Text(verbatim: paragraph.text).font(.subheadline).foregroundStyle(.secondary)
                        TextEditor(text: Binding(get: { values[paragraph.id] ?? "" }, set: { values[paragraph.id] = $0 }))
                            .frame(minHeight: 80).accessibilityLabel("Translated paragraph")
                    }
                }
                if let failure { Text(LocalizedStringKey(failure)).foregroundStyle(.red) }
            }
            .navigationTitle("Review translations").navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(dirty)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if dirty { confirmingDiscard = true } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Approve") { do { try store.review(story, corrections: values); dismiss() } catch { failure = error.localizedDescription } }
                        .disabled(story.paragraphs.contains { (values[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
                        .accessibilityIdentifier("saveStoryReview")
                }
            }
            .confirmationDialog("Discard changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}

/// One native scrolling text surface keeps the exact spoken range visible, including long paragraphs.
/// Highlight changes never replace the text, reflow its font, or move the caret.
private struct StoryReadingText: UIViewRepresentable {
    let text: String
    let spoken: NSRange?
    let following: Bool
    let points: Double
    let bold: Bool
    let spacing: Double
    let foreground: UIColor
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false; view.isSelectable = true; view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.accessibilityIdentifier = "storyReadingText"
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        let font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: UIFont.systemFont(ofSize: CGFloat(CaptionTextSize.clamped(points)), weight: bold ? .semibold : .regular),
            compatibleWith: view.traitCollection)
        let color = foreground.resolvedColor(with: view.traitCollection)
        let cache = context.coordinator
        if cache.text != text || cache.font != font || cache.spacing != spacing || cache.color != color {
            let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = CGFloat(spacing)
            view.attributedText = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
            cache.text = text; cache.font = font; cache.spacing = spacing; cache.color = color; cache.range = nil
        }
        let next = spoken.flatMap { Range($0, in: text) != nil && $0.length > 0 ? $0 : nil }
        if cache.range != next {
            view.textStorage.beginEditing()
            if let old = cache.range, NSMaxRange(old) <= view.textStorage.length {
                view.textStorage.removeAttribute(.backgroundColor, range: old)
                view.textStorage.addAttribute(.foregroundColor, value: color, range: old)
            }
            if let next {
                view.textStorage.addAttributes([.backgroundColor: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), .foregroundColor: UIColor.black], range: next)
            }
            view.textStorage.endEditing(); cache.range = next
            if following, let next { UIView.performWithoutAnimation { view.scrollRangeToVisible(next) } }
        } else if following && !cache.wasFollowing, let next {
            UIView.performWithoutAnimation { view.scrollRangeToVisible(next) }
        }
        cache.wasFollowing = following
    }
    final class Coordinator {
        var text: String?
        var font: UIFont?
        var spacing: Double?
        var color: UIColor?
        var range: NSRange?
        var wasFollowing = false
    }
}
