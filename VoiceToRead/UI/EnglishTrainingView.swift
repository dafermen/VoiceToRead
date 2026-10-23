import SwiftUI

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
                        Text("Create your Spanish phrases, review the English, then try saying each phrase from memory.")
                        Text("Trainings stay on this device. Round results are temporary.").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(store.trainings.sorted { $0.updatedAt > $1.updatedAt }) { training in
                        NavigationLink {
                            EnglishTrainingDetailView(store: store, trainingID: training.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(training.title).font(.headline)
                                Text("\(training.phrases.count) phrases").font(.caption).foregroundStyle(.secondary)
                            }
                        }.accessibilityIdentifier("englishTraining-" + training.id.uuidString)
                    }
                }
                .toolbar {
                    Button("New training", systemImage: "plus") { creating = true }
                        .accessibilityIdentifier("newEnglishTraining")
                }
                .sheet(isPresented: $creating) {
                    TrainingSourceEditor { training in try store.save(training) }
                }
            } else {
                ContentUnavailableView {
                    Label("English training unavailable", systemImage: "exclamationmark.triangle")
                } description: { Text(LocalizedStringKey(failure ?? "Opening trainings…")) } actions: {
                    Button("Retry") { openStore() }
                }
            }
        }
        .navigationTitle("Train English").navigationBarTitleDisplayMode(.inline)
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
    init(previous: EnglishTraining? = nil, save: @escaping (EnglishTraining) throws -> Void) {
        self.previous = previous; self.save = save
        _title = State(initialValue: previous?.title ?? "")
        _text = State(initialValue: previous?.phrases.map(\.spanish).joined(separator: "\n") ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Training name", text: $title).accessibilityIdentifier("trainingTitle")
                Section("Spanish · one phrase per line") {
                    TextEditor(text: $text).frame(minHeight: 250).accessibilityIdentifier("trainingSpanishInput")
                    Text("Editing a Spanish phrase clears only that phrase's English. Unchanged phrases keep their corrections.").font(.caption)
                }
                if let failure { Text(LocalizedStringKey(failure)).foregroundStyle(.red) }
            }
            .navigationTitle(uiKey(previous == nil ? "New training" : "Edit training"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try save(EnglishTraining.edited(title: title, text: text, previous: previous)); dismiss() }
                        catch { failure = error.localizedDescription }
                    }.accessibilityIdentifier("saveEnglishTraining")
                }
            }
        }
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
                Text("Review the English before practising. You can correct the automatic translation.")
                ForEach($phrases) { $phrase in
                    Section {
                        Text(phrase.spanish)
                        TextField("English response", text: $phrase.english, axis: .vertical)
                            .accessibilityIdentifier("trainingEnglish-" + phrase.id.uuidString)
                    }
                }
                if let failure { Text(LocalizedStringKey(failure)).foregroundStyle(.red) }
            }
            .navigationTitle("Review English").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try store.saveEnglish(training.id, source: training.source,
                                values: Dictionary(uniqueKeysWithValues: phrases.map { ($0.id, $0.english) }))
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
    var body: some View {
        Group {
            if let training {
                List {
                    Section {
                        Text("Spanish → English").font(.subheadline)
                        Button("Edit Spanish phrases", systemImage: "pencil") { editingSource = true }.disabled(job != nil)
                        Button("Prepare English", systemImage: "character.bubble") { translate(training) }
                            .disabled(job != nil || training.ready || !TranslationJob.supported)
                            .accessibilityIdentifier("prepareTrainingEnglish")
                        Button("Review English", systemImage: "text.badge.checkmark") { editingEnglish = true }
                            .disabled(job != nil).accessibilityIdentifier("reviewTrainingEnglish")
                        if !TranslationJob.supported { Text(LocalizedStringKey(TranslationFailure.unsupported.localizedDescription)).font(.caption) }
                        if let job {
                            ProgressView(value: Double(progress), total: Double(max(1, job.source.count)))
                            Button("Cancel translation") { self.job = nil }
                        }
                        if let failure { Text(LocalizedStringKey(failure)).foregroundStyle(.red) }
                        Text("Review the English before practising. You can correct the automatic translation.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Practice") {
                        NavigationLink {
                            TrainingPracticeView(store: store, trainingID: trainingID, phraseIDs: training.phrases.map(\.id))
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
                .sheet(isPresented: $editingSource) {
                    TrainingSourceEditor(previous: training) { updated in try store.save(updated) }
                }
                .sheet(isPresented: $editingEnglish) { TrainingEnglishEditor(store: store, training: training) }
            } else { Text("This training is no longer available.") }
        }
        .background {
            if let job {
                TranslationRunner(job: job, progress: { if self.job?.id == job.id { progress = $0 } }) { result in
                    guard self.job?.id == job.id else { return }
                    self.job = nil
                    do { try store.acceptTranslation(trainingID, source: job.source, responses: result.get()) }
                    catch { failure = error.localizedDescription }
                }.id(job.id)
            }
        }
        .onDisappear { job = nil }
    }
    private func translate(_ training: EnglishTraining) {
        let missing = training.phrases.filter { $0.english.isEmpty }.map { ReviewParagraph(id: $0.id, text: $0.spanish) }
        guard !missing.isEmpty else { return }
        failure = nil; progress = 0
        job = TranslationJob(plan: IncrementalTranslation(source: missing, previous: nil, language: .spanish, targetLanguage: .english))
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
    @State private var practice = PronunciationPractice(language: .english)
    @Environment(\.scenePhase) private var scenePhase
    init(store: EnglishTrainingStore, trainingID: UUID, phraseIDs: [UUID]) {
        self.store = store; self.trainingID = trainingID
        _round = State(initialValue: EnglishTrainingRound(phraseIDs: phraseIDs))
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
                    Text("Try saying this in English before revealing the response.").font(.subheadline)
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
        .navigationTitle("Train English").navigationBarTitleDisplayMode(.inline)
        .onAppear { practice.observeInterruptions() }
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
        .onChange(of: scenePhase) { _, phase in if phase == .background { practice.reset() } }
        .onDisappear { practice.close() }
    }
    private func move(to value: Int) {
        if let heard = practice.heard, let phrase = current {
            round.record(phraseID: phrase.id, expected: phrase.english, heard: heard)
        }
        practice.reset(); revealed = false; index = max(0, value)
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
            return result + Text(item.offset == 0 ? "" : " ") + word
        }
    }
}
