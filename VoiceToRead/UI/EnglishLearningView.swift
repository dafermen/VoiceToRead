import SwiftUI
import AVFoundation

/// Reproductor acotado a un fragmento. Su temporizador nunca controla el micrófono.
/// Cada salida/interrupción detiene el bucle; reanudar siempre requiere tocar Play.
@MainActor @Observable
final class PracticePlayer {
    private var player = SessionPlayer()
    private var timer: Task<Void, Never>?
    private var selected: String?
    var playing: Bool { player.playing }
    var duration: Double { player.duration }
    var paused: Bool { !playing && player.time > player.bounds.lowerBound && player.time < player.bounds.upperBound }
    var repeating = false
    var speed: TranslationSpeechSpeed = .normal { didSet { player.speed = speed } }
    var failure: String? { get { player.failure } set { player.failure = newValue } }
    func load(_ url: URL) throws { close(); player.load(url); player.speed = speed }
    func play(_ unit: LearningUnit) {
        guard let range = unit.audioRange(duration: duration) else { return }
        if selected != unit.id { player.select(range: range); selected = unit.id }
        player.toggle()
        timer?.cancel()
        timer = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                guard let self else { return }
                if self.player.interrupted { self.repeating = false; return }
                if !self.player.playing && self.player.time >= self.player.bounds.upperBound {
                    if self.repeating { self.player.toggle() } else { return }
                }
            }
        }
    }
    func pause() { timer?.cancel(); timer = nil; player.pause() }
    func stop() { pause(); selected = nil; player.seek(player.bounds.lowerBound) }
    func close() { timer?.cancel(); timer = nil; selected = nil; repeating = false; player.stop() }

}

@MainActor
struct EnglishLearningView: View {
    let session: ConferenceSession
    let repository: TranscriptRepository
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var units: [LearningUnit] = []
    @State private var expressions: [LearningExpression] = []
    @State private var selected = 0
    @State private var savedOnly = false
    @State private var revealed = false
    @State private var player = PracticePlayer()
    @State private var editing: LearningUnit?
    @State private var translation = false
    @State private var pronunciation: LearningUnit?
    @State private var failure: String?
    private var language: CaptureLanguage { CaptureLanguage(rawValue: session.language) ?? .english }
    private var choices: [LearningUnit] { savedOnly ? expressions.map(\.unit) : units }
    private var current: LearningUnit? { choices.indices.contains(selected) ? choices[selected] : nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Practice collection", selection: $savedOnly) {
                        Text("Session phrases").tag(false)
                        Text("Saved expressions").tag(true)
                    }.pickerStyle(.segmented).accessibilityIdentifier("learningCollection")
                    if let unit = current {
                        Text("Paragraph \(selected + 1) of \(choices.count)").font(.caption)
                        Text(unit.english).font(.title2).textSelection(.enabled)
                            .accessibilityIdentifier("learningEnglish")
                        if unit.audioRange(duration: player.duration) != nil {
                            PlaybackTransport(playing: player.playing,
                                title: player.playing ? "Pause" : player.paused ? "Resume" : "Play",
                                previousEnabled: selected > 0, nextEnabled: selected + 1 < choices.count,
                                previous: { move(-1) }, toggle: {
                                    if player.playing { player.pause() } else { player.play(unit) }
                                }, next: { move(1) })
                            HStack {
                                Toggle("Repeat this phrase", isOn: $player.repeating)
                                    .accessibilityIdentifier("learningRepeat")
                                Picker("Reading speed", selection: $player.speed) {
                                    ForEach(TranslationSpeechSpeed.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                                }.pickerStyle(.menu).accessibilityIdentifier("learningSpeed")
                            }
                            Text("Listen, then say the phrase aloud. Playback uses the original audio; timing is approximate.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            PlaybackTransport(playing: false, title: "Play", previousEnabled: selected > 0,
                                nextEnabled: selected + 1 < choices.count, enabled: false,
                                previous: { move(-1) }, toggle: {}, next: { move(1) })
                            Text("No recorded audio for this phrase. You can still read, reveal the translation and save expressions.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button("Practicar pronunciación", systemImage: "mic.badge.plus") {
                            player.stop(); pronunciation = unit
                        }.buttonStyle(.bordered).accessibilityIdentifier("practicePronunciation")
                        if let spanish = unit.spanish, !spanish.isEmpty {
                            Button(uiKey(revealed ? "Hide translation" : "Reveal \(language.opposite.name)"), systemImage: "eye") { revealed.toggle() }
                                .accessibilityIdentifier("revealLearningSpanish")
                            if revealed {
                                Text(spanish).font(.title3).accessibilityIdentifier("learningSpanish")
                                Text("The translation is a study aid. Alignment within a phrase can be approximate.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("No current translation for this phrase.").font(.caption)
                            Button("Translate session", systemImage: "character.bubble") { player.stop(); translation = true }
                        }
                        if savedOnly {
                            DisclosureGroup("Original context (saved copy)") { Text(unit.context).textSelection(.enabled) }
                            Text("This copy does not change when you edit the transcript. Audio plays the surrounding phrase.")
                                .font(.caption).foregroundStyle(.secondary)
                            Button("Remove from learning", role: .destructive) { removeCurrent() }
                        } else {
                            Button("Save expression", systemImage: "bookmark.badge.plus") { player.stop(); editing = unit }
                                .accessibilityIdentifier("saveLearningExpression")
                        }
                    } else {
                        ContentUnavailableView(uiKey(savedOnly ? "No saved expressions" : "No phrases yet"),
                            systemImage: "book", description: Text("Save an expression from Session phrases to practice it here."))
                    }
                }.padding()
            }
            .navigationTitle("Practicar idioma").navigationBarTitleDisplayMode(.inline)
            .toolbar { DoneButton { dismiss() } }
            .task { load() }
            .sheet(item: $pronunciation) { unit in
                PronunciationPracticeView(text: unit.english, language: language)
            }
            .sheet(item: $editing) { unit in
                LearningExpressionEditor(unit: unit, language: language) { english, spanish in
                    try repository.saveLearningExpression(unit: unit, english: english, spanish: spanish, for: session)
                    expressions = try repository.learningExpressions(for: session.id)
                }
            }
            .sheet(isPresented: $translation, onDismiss: { load() }) {
                SessionTranslationView(session: session, repository: repository)
            }
            .onChange(of: savedOnly) { _, _ in selected = 0; revealed = false; player.stop() }
            .onChange(of: phase) { _, value in if value != .active { player.stop() } }
            .onDisappear { player.close() }
            .alert("Learning", isPresented: Binding(get: { failure != nil || player.failure != nil },
                set: { if !$0 { failure = nil; player.failure = nil } })) {
                Button("OK") { failure = nil; player.failure = nil }
            } message: { Text(LocalizedStringKey(failure ?? player.failure ?? "")) }
        }
    }
    private func load() {
        player.close()
        do {
            let source = try repository.reviewedParagraphs(for: session)
            units = LearningUnit.make(paragraphs: source,
                timings: try repository.media(for: session.id)?.decodedTimings() ?? [:],
                translation: try repository.translation(for: session.id)?.decoded())
            expressions = try repository.learningExpressions(for: session.id)
            if let url = try repository.audioURL(for: session.id), FileManager.default.fileExists(atPath: url.path) {
                do { try player.load(url) } catch { failure = "Audio could not be opened. Text practice remains available." }
            }
            selected = min(selected, max(0, choices.count - 1)); revealed = false
        } catch { failure = "Could not load this session. Close and reopen Learning." }
    }
    private func move(_ delta: Int) {
        player.stop(); revealed = false; selected = min(max(selected + delta, 0), max(0, choices.count - 1))
    }
    private func removeCurrent() {
        guard expressions.indices.contains(selected) else { return }
        do {
            player.stop()
            try repository.removeLearningExpression(expressions[selected])
            expressions = try repository.learningExpressions(for: session.id)
            selected = min(selected, max(0, expressions.count - 1)); revealed = false
        } catch { failure = "Could not remove this expression. Please retry." }
    }
}

private struct LearningExpressionEditor: View {
    let unit: LearningUnit
    var language: CaptureLanguage = .english
    let save: (String, String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var english = ""
    @State private var spanish = ""
    @State private var failure: String?
    private var valid: Bool {
        let value = english.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && value.count <= 500 && unit.english.localizedStandardContains(value)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("\(language.name) expression") {
                    TextField("Word or phrase from this fragment", text: $english, axis: .vertical)
                        .accessibilityIdentifier("learningExpressionEnglish")
                    Text("Keep the phrase or enter a word/expression from this fragment. Up to 500 characters.").font(.caption)
                }
                Section("\(language.opposite.name) note (optional)") {
                    TextField("Meaning in this context", text: $spanish, axis: .vertical)
                    Text("If you shorten the original, adjust this note to match it.").font(.caption)
                }
                Section("Original context") { Text(unit.context).textSelection(.enabled) }
                if let failure { Text(LocalizedStringKey(failure)).foregroundStyle(.red) }
            }
            .navigationTitle("Save expression").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try save(english, spanish); dismiss() }
                        catch { failure = "Could not save. Reopen the session if its text changed." }
                    }.disabled(!valid).accessibilityIdentifier("confirmLearningExpression")
                }
            }
            .onAppear { english = String(unit.english.prefix(500)); spanish = unit.spanish ?? "" }
        }
    }
}
