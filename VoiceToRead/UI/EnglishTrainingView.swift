import SwiftUI
import AVFoundation
import Speech

@MainActor
struct EnglishTrainingLibraryView: View {
    @State private var store: EnglishTrainingStore?
    @State private var failure: String?
    @State private var creating = false
    var body: some View {
        Group {
            if let store {
                List {
                    Section {
                        Text("Choose the source and practice languages, write one phrase per line, then review the translations before practising.")
                        Text("Trainings stay on this device. Round results are temporary.").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(store.trainings.sorted { $0.updatedAt > $1.updatedAt }) { training in
                        NavigationLink {
                            EnglishTrainingDetailView(store: store, trainingID: training.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(training.title).font(.headline)
                                TrainingLanguagePair(training: training)
                                Text("\(training.phrases.count) phrases").font(.caption).foregroundStyle(.secondary)
                            }
                        }.accessibilityIdentifier("englishTraining-" + training.id.uuidString)
                    }
                }
                .toolbar {
                    HomeCircleToolbarItem {
                        HomeCircleAction(title: "New training", symbol: "plus") { creating = true }
                            .accessibilityIdentifier("newEnglishTraining")
                    }
                }
                .sheet(isPresented: $creating) {
                    TrainingSourceEditor { training in try store.save(training) }
                }
            } else {
                ContentUnavailableView {
                    Label("Training unavailable", systemImage: "exclamationmark.triangle")
                } description: { Text(LocalizedStringKey(failure ?? "Opening trainings…")) } actions: {
                    Button("Retry") { openStore() }
                }
            }
        }
        .navigationTitle("Training").navigationBarTitleDisplayMode(.inline)
        .task { if store == nil { openStore() } }
    }
    private func openStore() {
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-test-training") {
                let name = ProcessInfo.processInfo.environment["TRAINING_TEST_ID"] ?? UUID().uuidString
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("EnglishTraining-UITests").appendingPathComponent(name)
                store = try EnglishTrainingStore(directory: directory)
            } else { store = try EnglishTrainingStore() }
            #else
            store = try EnglishTrainingStore()
            #endif
            failure = nil
        }
        catch { failure = error.localizedDescription }
    }
}

@MainActor
private struct TrainingSourceEditor: View {
    var previous: EnglishTraining?
    let save: (EnglishTraining) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var text: String
    @State private var failure: String?
    @State private var sourceLanguage: CaptureLanguage
    @State private var targetLanguage: CaptureLanguage
    @State private var confirmingLanguages = false
    init(previous: EnglishTraining? = nil, save: @escaping (EnglishTraining) throws -> Void) {
        self.previous = previous; self.save = save
        _title = State(initialValue: previous?.title ?? "")
        _text = State(initialValue: previous?.phrases.map(\.spanish).joined(separator: "\n") ?? "")
        _sourceLanguage = State(initialValue: previous?.sourceLanguage ?? .spanish)
        _targetLanguage = State(initialValue: previous?.targetLanguage ?? .english)
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Training name", text: $title).accessibilityIdentifier("trainingTitle")
                Section("Languages") {
                    Picker("Source language", selection: $sourceLanguage) {
                        ForEach(CaptureLanguage.allCases, id: \.self) { Text($0.pickerLabel).tag($0) }
                    }.accessibilityIdentifier("trainingSourceLanguage")
                    Picker("Practice language", selection: $targetLanguage) {
                        ForEach(CaptureLanguage.allCases, id: \.self) { Text($0.pickerLabel).tag($0) }
                    }.accessibilityIdentifier("trainingTargetLanguage")
                    if sourceLanguage == targetLanguage { Text("Choose different source and practice languages.").foregroundStyle(.red) }
                    Text("Changing the source language does not convert your existing phrases. Review and edit them in the selected source language.").font(.caption)
                }
                Section("Source phrases · one phrase per line") {
                    Text("Write in \(sourceLanguage.name)").font(.caption)
                    TextEditor(text: $text).frame(minHeight: 250).accessibilityIdentifier("trainingSpanishInput")
                    Text("Editing a source phrase clears only its translation. Unchanged phrases keep their corrections unless you change languages.").font(.caption)
                }
                if let failure { Text(LocalizedStringKey(failure)).foregroundStyle(.red) }
            }
            .navigationTitle(uiKey(previous == nil ? "New training" : "Edit training"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let previous, previous.sourceLanguage != sourceLanguage || previous.targetLanguage != targetLanguage {
                            confirmingLanguages = true
                        } else { commit() }
                    }.disabled(sourceLanguage == targetLanguage).accessibilityIdentifier("saveEnglishTraining")
                }
            }
            .confirmationDialog("Change training languages?", isPresented: $confirmingLanguages, titleVisibility: .visible) {
                Button("Save and translate", role: .destructive) { commit() }.accessibilityIdentifier("confirmTrainingLanguages")
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Changing either language replaces all translations and corrections. Review your source phrases before continuing. They will be translated again after saving.")
            }
        }
    }
    private func commit() {
        do {
            try save(EnglishTraining.edited(title: title, text: text, previous: previous,
                sourceLanguage: sourceLanguage, targetLanguage: targetLanguage))
            dismiss()
        } catch { failure = error.localizedDescription }
    }
}

private struct TrainingLanguagePair: View {
    let training: EnglishTraining
    var body: some View {
        HStack {
            Text(training.sourceLanguage.pickerLabel)
            Image(systemName: "arrow.right").accessibilityLabel("to")
            Text(training.targetLanguage.pickerLabel)
        }.font(.caption).foregroundStyle(.secondary)
    }
}

@MainActor
private struct TrainingEnglishEditor: View {
    let store: EnglishTrainingStore
    let training: EnglishTraining
    @Environment(\.dismiss) private var dismiss
    @State private var phrases: [EnglishTrainingPhrase]
    @State private var failure: String?
    init(store: EnglishTrainingStore, training: EnglishTraining) {
        self.store = store; self.training = training
        _phrases = State(initialValue: training.phrases)
    }
    var body: some View {
        NavigationStack {
            Form {
                TrainingLanguagePair(training: training)
                Text("Review the translations before practising. You can correct the automatic translation.")
                ForEach($phrases) { $phrase in
                    Section {
                        Text(phrase.spanish)
                        TextField("Translated response", text: $phrase.english, axis: .vertical)
                            .accessibilityIdentifier("trainingEnglish-" + phrase.id.uuidString)
                    }
                }
                if let failure { Text(LocalizedStringKey(failure)).foregroundStyle(.red) }
            }
            .navigationTitle("Review translations").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try store.saveEnglish(training.id, source: training.source,
                                values: Dictionary(uniqueKeysWithValues: phrases.map { ($0.id, $0.english) }),
                                language: training.sourceLanguage, targetLanguage: training.targetLanguage)
                            dismiss()
                        } catch { failure = error.localizedDescription }
                    }.accessibilityIdentifier("saveTrainingEnglish")
                }
            }
        }
    }
}

@MainActor
private struct EnglishTrainingDetailView: View {
    let store: EnglishTrainingStore
    let trainingID: UUID
    @State private var editingSource = false
    @State private var editingEnglish = false
    @State private var job: TranslationJob?
    @State private var progress = 0
    @State private var failure: String?
    private var training: EnglishTraining? { store.training(trainingID) }
    @State private var replacementSnapshot: EnglishTraining?
    @State private var confirmingRetranslation = false
    @State private var translateAfterEditing = false
    var body: some View {
        Group {
            if let training {
                List {
                    Section {
                        TrainingLanguagePair(training: training)
                        Button("Edit phrases and languages", systemImage: "pencil") { editingSource = true }
                            .disabled(job != nil).accessibilityIdentifier("editTrainingSource")
                        Button("Prepare translations", systemImage: "character.bubble") { translate(training) }
                            .disabled(job != nil || training.ready || !TranslationJob.supported)
                            .accessibilityIdentifier("prepareTrainingEnglish")
                        Button("Translate again", systemImage: "arrow.clockwise") {
                            if training.phrases.contains(where: { !$0.english.isEmpty }) { confirmingRetranslation = true }
                            else { translate(training, replaceAll: true) }
                        }.disabled(job != nil || !TranslationJob.supported).accessibilityIdentifier("retranslateTraining")
                        Button("Review translations", systemImage: "text.badge.checkmark") { editingEnglish = true }
                            .disabled(job != nil).accessibilityIdentifier("reviewTrainingEnglish")
                        if !TranslationJob.supported { Text(LocalizedStringKey(TranslationFailure.unsupported.localizedDescription)).font(.caption) }
                        if let job {
                            ProgressView(value: Double(progress), total: Double(max(1, job.source.count)))
                            Button("Cancel translation") { self.job = nil; replacementSnapshot = nil }
                        }
                        if let failure { Text(LocalizedStringKey(failure)).foregroundStyle(.red) }
                        Text("Review the translations before practising. You can correct the automatic translation.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Practice") {
                        NavigationLink {
                            TrainingPracticeView(store: store, trainingID: trainingID, phraseIDs: training.phrases.map(\.id))
                                .id(training.updatedAt)
                        } label: { Label("Start practice", systemImage: "mic") }
                            .disabled(!training.ready || job != nil).accessibilityIdentifier("startEnglishTraining")
                    }
                    Section("Phrases") {
                        ForEach(training.phrases) { phrase in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(phrase.spanish)
                                if !phrase.english.isEmpty { Text(phrase.english).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                .navigationTitle(training.title).navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $editingSource, onDismiss: {
                    guard translateAfterEditing else { return }
                    translateAfterEditing = false
                    if let current = self.training { translate(current) }
                }) {
                    TrainingSourceEditor(previous: training) { updated in
                        try store.save(updated)
                        translateAfterEditing = updated.sourceLanguage != training.sourceLanguage || updated.targetLanguage != training.targetLanguage
                    }
                }
                .sheet(isPresented: $editingEnglish) { TrainingEnglishEditor(store: store, training: training) }
                .confirmationDialog("Translate all phrases again?", isPresented: $confirmingRetranslation, titleVisibility: .visible) {
                    Button("Replace translations", role: .destructive) { translate(training, replaceAll: true) }
                        .accessibilityIdentifier("confirmTrainingRetranslation")
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("All translations and manual corrections will be replaced only if translation finishes successfully. Your source phrases stay unchanged.")
                }
            } else { Text("This training is no longer available.") }
        }
        .background {
            if let job {
                TranslationRunner(job: job, progress: { if self.job?.id == job.id { progress = $0 } }) { result in
                    guard self.job?.id == job.id else { return }
                    let snapshot = replacementSnapshot
                    self.job = nil
                    replacementSnapshot = nil
                    do { try store.acceptTranslation(trainingID, source: job.source, responses: result.get(),
                        language: job.plan.language, targetLanguage: job.plan.target, replacing: snapshot) }
                    catch { failure = error.localizedDescription }
                }.id(job.id)
            }
        }
        .onDisappear { job = nil; replacementSnapshot = nil; translateAfterEditing = false }
    }
    private func translate(_ training: EnglishTraining, replaceAll: Bool = false) {
        guard TranslationJob.supported else { failure = TranslationFailure.unsupported.localizedDescription; return }
        let missing = training.phrases.filter { replaceAll || $0.english.isEmpty }.map { ReviewParagraph(id: $0.id, text: $0.spanish) }
        guard !missing.isEmpty else { return }
        failure = nil; progress = 0
        replacementSnapshot = replaceAll ? training : nil
        job = TranslationJob(plan: IncrementalTranslation(source: missing, previous: nil,
            language: training.sourceLanguage, targetLanguage: training.targetLanguage))
    }
}

@MainActor
private struct TrainingPracticeView: View {
    let store: EnglishTrainingStore
    let trainingID: UUID
    @State private var round: EnglishTrainingRound
    @State private var index = 0
    @State private var revealed = false
    @State private var slow = false
    @State private var practice: PronunciationPractice
    private let targetLanguage: CaptureLanguage
    @State private var localRecognitionAvailable = true
    @State private var voiceAvailable = true
    @Environment(\.scenePhase) private var scenePhase
    init(store: EnglishTrainingStore, trainingID: UUID, phraseIDs: [UUID]) {
        self.store = store; self.trainingID = trainingID
        _round = State(initialValue: EnglishTrainingRound(phraseIDs: phraseIDs))
        let language = store.training(trainingID)?.targetLanguage ?? .english
        targetLanguage = language
        _practice = State(initialValue: PronunciationPractice(language: language))
    }
    private var current: EnglishTrainingPhrase? {
        guard round.phraseIDs.indices.contains(index) else { return nil }
        return store.training(trainingID)?.phrases.first { $0.id == round.phraseIDs[index] }
    }
    private var busy: Bool { practice.activity == .recording || practice.activity == .permission || practice.activity == .checking }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let phrase = current {
                    Text("Phrase \(index + 1) of \(round.phraseIDs.count)").font(.caption).foregroundStyle(.secondary)
                    Text("Try saying this in \(targetLanguage.name) before revealing the response.").font(.subheadline)
                    if !voiceAvailable {
                        Text("No example voice is installed for the practice language. Check the voices in device Settings.").font(.caption).foregroundStyle(.secondary)
                    }
                    if !localRecognitionAvailable {
                        Text("Local recognition is unavailable for the practice language. You can still record, listen and compare; no automatic check will be counted.").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(phrase.spanish).font(.title2).textSelection(.enabled).accessibilityIdentifier("trainingPrompt")
                    HStack {
                        Button(uiKey(revealed ? "Hide response" : "Show response"), systemImage: "eye") { revealed.toggle() }
                            .disabled(busy).accessibilityIdentifier("revealTrainingResponse")
                        Button(uiKey(practice.activity == .example ? "Stop example" : "Listen to example"),
                               systemImage: practice.activity == .example ? "stop.circle" : "speaker.wave.2") {
                            if practice.activity == .example { practice.stopPlayback() }
                            else { revealed = true; practice.listen(phrase.english, slow: slow) }
                        }.disabled(busy)
                    }.labelStyle(InlinePreferenceLabelStyle()).frame(minHeight: 44)
                    Toggle("Slow example", isOn: $slow).disabled(busy)
                    if revealed {
                        Text(phrase.english).font(.title3).textSelection(.enabled).accessibilityIdentifier("trainingExpected")
                    }
                    if let message = practice.message { Text(LocalizedStringKey(message)).foregroundStyle(.secondary) }
                    if practice.needsSettings {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                    if practice.activity == .recording {
                        Text("\(Int(practice.elapsed)) / 15 seconds").monospacedDigit()
                        Button("Stop recording", systemImage: "stop.fill") { practice.finishRecording() }
                            .buttonStyle(.borderedProminent).accessibilityIdentifier("stopTrainingAttempt")
                    } else {
                        Button("Record my attempt", systemImage: "mic.fill") { Task { await practice.startRecording() } }
                            .buttonStyle(.borderedProminent).disabled(practice.activity != .idle)
                            .accessibilityIdentifier("recordTrainingAttempt")
                    }
                    if practice.activity == .checking { ProgressView("Checking recognized words…") }
                    if practice.activity == .permission { ProgressView("Waiting for microphone permission…") }
                    if practice.take != nil {
                        Button(uiKey(practice.activity == .playback ? "Stop attempt" : "Listen to my attempt"),
                               systemImage: practice.activity == .playback ? "stop.circle" : "play.circle") {
                            if practice.activity == .playback { practice.stopPlayback() }
                            else { practice.listenToTake() }
                        }.disabled(busy).accessibilityIdentifier("trainingAttemptPlayback")
                        if practice.heard == nil {
                            Button("Retry word recognition", systemImage: "arrow.clockwise") { Task { await practice.checkWords() } }.disabled(busy)
                        }
                    }
                    if let heard = practice.heard {
                        let comparison = TrainingComparison.compare(expected: phrase.english, heard: heard)
                        if PracticeRecognition.matches(heard, target: phrase.english) {
                            Label("The words match!", systemImage: "checkmark.circle.fill")
                                .font(.headline).foregroundStyle(.green).accessibilityIdentifier("trainingMatch")
                        } else {
                            Label("Review the underlined words and try again.", systemImage: "arrow.clockwise")
                                .font(.headline).accessibilityIdentifier("trainingDifference")
                        }
                        Text("What was understood").font(.headline)
                        differenceText(comparison.heard).font(.title3).textSelection(.enabled).accessibilityIdentifier("trainingHeard")
                        Text("Expected response").font(.headline)
                        differenceText(comparison.expected).font(.title3).textSelection(.enabled)
                        Text("Underlined words differ from recognition. Noise, recognition errors and other valid translations can explain differences. This is not a pronunciation score.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    HStack {
                        Button("Previous", systemImage: "backward.end") { move(to: index - 1) }.disabled(index == 0 || busy)
                        Spacer()
                        Button("Next", systemImage: "forward.end") { move(to: index + 1) }
                            .disabled(busy).accessibilityIdentifier("trainingNext")
                    }
                    Text("Your attempt is temporary. It is deleted when you repeat, change phrase, leave this screen or put the app in the background.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    roundSummary
                }
            }.padding()
        }
        .navigationTitle("Training").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            practice.observeInterruptions()
            refreshLanguageSupport()
        }
        .onChange(of: practice.take) { _, take in
            if take != nil, let phrase = current {
                round.clearResult(for: phrase.id)
                Task { await practice.checkWords() }
            }
        }
        .onChange(of: practice.heard) { _, heard in
            if let heard, let phrase = current {
                round.record(phraseID: phrase.id, expected: phrase.english, heard: heard)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { practice.reset() }
            else if phase == .active { refreshLanguageSupport() }
        }
        .onDisappear { practice.close() }
    }
    private func move(to value: Int) {
        if let heard = practice.heard, let phrase = current {
            round.record(phraseID: phrase.id, expected: phrase.english, heard: heard)
        }
        practice.reset(); revealed = false; index = max(0, value)
    }
    private func refreshLanguageSupport() {
        voiceAvailable = PlaybackVoicePreference.voice(for: targetLanguage) != nil
        localRecognitionAvailable = SFSpeechRecognizer(locale: Locale(identifier: targetLanguage.rawValue))?.supportsOnDeviceRecognition == true
    }
    private var roundSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Round complete").font(.title2).accessibilityIdentifier("trainingRoundSummary")
            Label { Text("\(round.matchedCount) matched") } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }.accessibilityIdentifier("trainingMatchedCount")
            Label { Text("\(round.differentIDs.count) with differences") } icon: {
                Image(systemName: "arrow.clockwise.circle")
            }.accessibilityIdentifier("trainingDifferentCount")
            Label { Text("\(round.unattemptedCount) without a recognized attempt") } icon: {
                Image(systemName: "minus.circle")
            }.accessibilityIdentifier("trainingUnattemptedCount")
            Text("Results describe recognized words, not pronunciation quality. Only this round is counted; results are not saved.")
                .font(.caption).foregroundStyle(.secondary)
            if !round.differentIDs.isEmpty {
                Text("Phrases with differences").font(.headline)
                ForEach(round.differentIDs, id: \.self) { id in
                    if let phrase = store.training(trainingID)?.phrases.first(where: { $0.id == id }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(phrase.spanish)
                            Text(phrase.english).foregroundStyle(.secondary)
                        }.accessibilityIdentifier("trainingDifference-" + id.uuidString)
                    }
                }
                Button("Review these phrases", systemImage: "arrow.clockwise") {
                    round = EnglishTrainingRound(phraseIDs: round.differentIDs)
                    move(to: 0)
                }.accessibilityIdentifier("trainingReviewDifferences")
            }
        }
    }
    private func differenceText(_ words: [TrainingComparison.Word]) -> Text {
        words.enumerated().reduce(Text("")) { result, item in
            let word = Text(item.element.text).underline(!item.element.matched)
            return result + Text(item.offset == 0 ? "" : item.element.separator) + word
        }
    }
}
